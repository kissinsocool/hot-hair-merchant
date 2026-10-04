import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/page_width.dart';
import '../../booking/data/booking_update_stream.dart';
import '../../booking/data/order_repository.dart';
import '../../booking/domain/booking_order.dart';
import '../data/merchant_salon_repository.dart';

enum _RescheduleAction { previous }

const merchantOrderStatusTabs = <(String, Set<String>, Color)>[
  ('新预约待接单', {'pending'}, Colors.red),
  ('已接单', {'accepted', 'completed'}, Colors.orange),
  ('已取消', {'canceled', 'rejected'}, Colors.grey),
];

bool isMerchantOrderVisible(
  BookingOrder order,
  DateTime? selectedDate,
  String selectedStaffId, {
  bool byMonth = false,
}) {
  if (selectedStaffId.isNotEmpty && order.staffId != selectedStaffId) {
    return false;
  }
  if (order.status == 'pending' || selectedDate == null) return true;
  return byMonth
      ? order.startTime.year == selectedDate.year &&
            order.startTime.month == selectedDate.month
      : DateUtils.isSameDay(order.startTime, selectedDate);
}

bool isBookingSlotEnabled(
  Map<String, dynamic> slot,
  BookingOrder order,
  DateTime date,
) {
  final slotTime = DateTime.tryParse(slot['startTime']?.toString() ?? '');
  if (slotTime == null || !slotTime.isAfter(DateTime.now())) return false;
  if (slot['isAvailable'] == true) return true;
  return slotTime.year == order.startTime.year &&
      slotTime.month == order.startTime.month &&
      slotTime.day == order.startTime.day &&
      slotTime.hour == order.startTime.hour &&
      slotTime.minute == order.startTime.minute &&
      date.year == order.startTime.year &&
      date.month == order.startTime.month &&
      date.day == order.startTime.day;
}

class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({
    super.key,
    this.repository,
    this.enableRealtime = const bool.fromEnvironment(
      'ENABLE_REALTIME',
      defaultValue: true,
    ),
  });

  final OrderRepository? repository;
  final bool enableRealtime;

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  late final OrderRepository _repository =
      widget.repository ?? OrderRepository();
  final MerchantSalonRepository _salonRepository = MerchantSalonRepository();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  final DateFormat _filterDateFormat = DateFormat('yyyy-MM-dd');
  StreamSubscription<Map<String, dynamic>>? _bookingUpdateSubscription;
  bool _isLoading = true;
  bool _isUpdating = false;
  String _errorMessage = '';
  DateTime? _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _filterByMonth = false;
  String _selectedStaffId = '';
  int _selectedStatusTab = 0;
  List<BookingOrder> _orders = [];
  List<Map<String, dynamic>> _staffOptions = [];

  @override
  void initState() {
    super.initState();
    _loadOrders();
    if (!widget.enableRealtime) return;

    BookingUpdateStream.instance.start();
    _bookingUpdateSubscription = BookingUpdateStream.instance.stream.listen((
      event,
    ) {
      if (event['event'] == 'booking.created' ||
          event['event'] == 'booking.updated') {
        _loadOrders(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _bookingUpdateSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });
    }

    try {
      final results = await Future.wait([
        _repository.fetchMerchantBookings(),
        _salonRepository.fetchSalon(),
      ]);
      final orders = results[0] as List<BookingOrder>;
      final salon = Map<String, dynamic>.from(results[1] as Map);
      final staff = (salon['staff'] as List<dynamic>? ?? [])
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _staffOptions = staff;
        if (_selectedStaffId.isNotEmpty &&
            !staff.any((item) => item['id']?.toString() == _selectedStaffId)) {
          _selectedStaffId = '';
        }
        _isLoading = false;
        _errorMessage = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = userFacingApiError(e, fallback: '订单加载失败，请稍后重试');
        _isLoading = false;
      });
    }
  }

  Future<void> _updateOrder(BookingOrder order, bool accept) async {
    if (accept &&
        (order.isNoPreference ||
            order.staffId.isEmpty ||
            order.staffName == '无需指定')) {
      final assignedStaffId = await _showAssignStaffDialog(order);
      if (assignedStaffId == null) return;
      await _updateOrderStatus(
        order,
        action: 'accept',
        assignedStaffId: assignedStaffId,
        successMessage: '已指定理发师并接单，用户将收到预约成功消息',
      );
      return;
    }

    await _updateOrderStatus(
      order,
      action: accept ? 'accept' : 'reject',
      reason: accept ? '' : '该时间段暂不可预约',
      successMessage: accept ? '已接单，用户将收到预约成功消息' : '已拒单，用户将收到拒绝消息',
    );
  }

  Future<void> _updateOrderStatus(
    BookingOrder order, {
    required String action,
    required String successMessage,
    String reason = '',
    String assignedStaffId = '',
    DateTime? startTime,
  }) async {
    setState(() => _isUpdating = true);
    try {
      await _repository.updateMerchantBookingStatus(
        order.id,
        action: action,
        reason: reason,
        assignedStaffId: assignedStaffId,
        startTime: startTime,
      );
      await _loadOrders(silent: true);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(userFacingApiError(e))));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _rescheduleOrder(BookingOrder order) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var date = order.startTime.isBefore(today) ? today : order.startTime;
    while (true) {
      if (!mounted) return;
      final pickedDate = await showDatePicker(
        context: context,
        locale: const Locale('zh', 'CN'),
        initialDate: date,
        firstDate: today,
        lastDate: DateTime(today.year + 2, 12, 31),
        helpText: '变更预约日期',
        cancelText: '取消',
        confirmText: '下一步',
      );
      if (pickedDate == null || !mounted) return;
      date = pickedDate;

      List<Map<String, dynamic>> slots;
      setState(() => _isUpdating = true);
      try {
        slots = await _repository.fetchStaffSlots(
          order.staffId.isEmpty ? '__no_preference__' : order.staffId,
          date,
          salonId: order.salonId,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFacingApiError(e, fallback: '可用时间加载失败，请稍后重试')),
          ),
        );
        return;
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
      if (!mounted) return;

      final result = await _showAvailableTimePicker(slots, order, date);
      if (result == _RescheduleAction.previous) continue;
      if (result is! TimeOfDay || !mounted) return;

      final startTime = DateTime(
        date.year,
        date.month,
        date.day,
        result.hour,
        result.minute,
      );
      if (!startTime.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('请选择未来的预约时间')));
        return;
      }
      if (startTime.isAtSameMomentAs(order.startTime)) return;

      await _updateOrderStatus(
        order,
        action: 'reschedule',
        startTime: startTime,
        successMessage: '预约时间已变更，用户将收到改期消息',
      );
      return;
    }
  }

  Future<Object?> _showAvailableTimePicker(
    List<Map<String, dynamic>> slots,
    BookingOrder order,
    DateTime date,
  ) {
    final initialMinutes = order.startTime.hour * 60 + order.startTime.minute;
    final enabledMinutes = slots
        .where((slot) => isBookingSlotEnabled(slot, order, date))
        .map((slot) {
          final parts = slot['time'].toString().split(':');
          return int.parse(parts[0]) * 60 + int.parse(parts[1]);
        })
        .toSet();
    int? selectedMinutes = enabledMinutes.contains(initialMinutes)
        ? initialMinutes
        : enabledMinutes.isEmpty
        ? null
        : enabledMinutes.first;

    return showDialog<Object>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('变更预约时间'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: selectedMinutes,
                decoration: const InputDecoration(labelText: '可用时间段'),
                items: [
                  for (final slot in slots)
                    DropdownMenuItem(
                      value: () {
                        final parts = slot['time'].toString().split(':');
                        return int.parse(parts[0]) * 60 + int.parse(parts[1]);
                      }(),
                      enabled: isBookingSlotEnabled(slot, order, date),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(slot['time'].toString()),
                          if (!isBookingSlotEnabled(slot, order, date))
                            Text(
                              slot['reason']?.toString() ?? '不可预约',
                              style: const TextStyle(color: Colors.grey),
                            ),
                        ],
                      ),
                    ),
                ],
                onChanged: (value) =>
                    selectedMinutes = value ?? selectedMinutes,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(
                      dialogContext,
                      _RescheduleAction.previous,
                    ),
                    child: const Text('上一步'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: selectedMinutes == null
                        ? null
                        : () => Navigator.pop(
                            dialogContext,
                            TimeOfDay(
                              hour: selectedMinutes! ~/ 60,
                              minute: selectedMinutes! % 60,
                            ),
                          ),
                    child: const Text('确定'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showReviewDialog(BookingOrder order) async {
    final review = order.review;
    if (review == null) return;

    final pageContext = context;
    final reply = review['merchantReply'];
    final pendingReply = review['pendingMerchantReply'];
    final publicReply = reply is Map
        ? reply['content']?.toString() ?? ''
        : reply?.toString() ?? '';
    final pendingReplyText = pendingReply is Map
        ? pendingReply['content']?.toString() ?? ''
        : '';
    final pendingReplyStatus = pendingReply is Map
        ? pendingReply['reviewStatus']?.toString() ?? 'pending'
        : '';
    final existingReply = pendingReplyText.isNotEmpty
        ? pendingReplyText
        : publicReply;
    final replyController = TextEditingController(text: existingReply);
    var isSubmitting = false;
    var submitted = false;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final rating = review['rating']?.toString() ?? '-';
          final comment = review['comment']?.toString() ?? '';
          final images = (review['imageUrls'] as List? ?? [])
              .map((item) => item.toString())
              .where((item) => item.isNotEmpty)
              .toList();

          return AlertDialog(
            title: const Text('客户评价'),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber),
                        const SizedBox(width: 6),
                        Text(
                          '$rating 星',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          review['date']?.toString() ?? '',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(comment, style: const TextStyle(height: 1.4)),
                    if (images.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 86,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (context, index) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              images[index],
                              width: 86,
                              height: 86,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    width: 86,
                                    height: 86,
                                    color: AppTheme.bgCream,
                                    child: const Icon(Icons.broken_image),
                                  ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    if (pendingReplyText.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: pendingReplyStatus == 'rejected'
                              ? Colors.red.withValues(alpha: 0.08)
                              : Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          pendingReplyStatus == 'rejected'
                              ? '该回复已被驳回，请修改后重新提交'
                              : '该回复正在审核中，通过后将公开展示',
                          style: TextStyle(
                            color: pendingReplyStatus == 'rejected'
                                ? Colors.red
                                : Colors.orange[800],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: replyController,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: '商家回复',
                        hintText: '感谢您的评价，期待再次为您服务',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(context),
                child: const Text('关闭'),
              ),
              FilledButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final replyText = replyController.text.trim();
                        if (replyText.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('请输入回复内容')),
                          );
                          return;
                        }
                        setDialogState(() => isSubmitting = true);
                        try {
                          await _repository.replyToReview(
                            order.id,
                            reply: replyText,
                          );
                          await _loadOrders(silent: true);
                          if (!pageContext.mounted) return;
                          ScaffoldMessenger.of(pageContext).showSnackBar(
                            const SnackBar(content: Text('回复已提交，审核通过后将公开展示')),
                          );
                          submitted = true;
                          if (context.mounted) Navigator.pop(context);
                          return;
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                userFacingApiError(e, fallback: '回复失败，请稍后重试'),
                              ),
                            ),
                          );
                        } finally {
                          if (!submitted && context.mounted) {
                            setDialogState(() => isSubmitting = false);
                          }
                        }
                      },
                child: Text(isSubmitting ? '提交中...' : '提交回复'),
              ),
            ],
          );
        },
      ),
    );

    replyController.dispose();
  }

  Future<String?> _showAssignStaffDialog(BookingOrder order) async {
    final availableStaffOptions = availableStaffForOrder(
      _staffOptions,
      _orders,
      order,
    );
    if (_staffOptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先在店铺资料中添加理发师')));
      return null;
    }
    if (availableStaffOptions.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('该时段暂无空闲理发师')));
      return null;
    }

    String? selectedStaffId;
    return showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryPink.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.content_cut,
                              color: AppTheme.primaryPink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '指定理发师',
                                  style: TextStyle(
                                    color: AppTheme.textDark,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${order.userName} · ${order.serviceName}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: '关闭',
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Flexible(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 420),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: availableStaffOptions.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final staff = availableStaffOptions[index];
                              final staffId = staff['id']?.toString() ?? '';
                              final selected = selectedStaffId == staffId;
                              return _AssignStaffOptionCard(
                                staff: staff,
                                selected: selected,
                                onTap: () => setDialogState(
                                  () => selectedStaffId = staffId,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('取消'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: selectedStaffId == null
                                  ? null
                                  : () =>
                                        Navigator.pop(context, selectedStaffId),
                              icon: const Icon(Icons.check),
                              label: const Text('确认接单'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lastBookingDate = today.add(const Duration(days: 6));
    final firstHistoryDate = DateTime(today.year - 1, today.month, today.day);
    final initialDate =
        _selectedDate != null &&
            !_selectedDate!.isBefore(firstHistoryDate) &&
            !_selectedDate!.isAfter(lastBookingDate)
        ? _selectedDate!
        : today;
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstHistoryDate,
      lastDate: lastBookingDate,
      helpText: '选择订单日期',
      cancelText: '取消',
      confirmText: '确定',
    );

    if (pickedDate == null || !mounted) return;
    setState(() => _selectedDate = pickedDate);
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    var firstMonth = DateTime(now.year - 1, now.month);
    var lastMonth = DateTime(now.year, now.month, now.day + 6);
    lastMonth = DateTime(lastMonth.year, lastMonth.month);
    for (final order in _orders) {
      final month = DateTime(order.startTime.year, order.startTime.month);
      if (month.isBefore(firstMonth)) firstMonth = month;
      if (month.isAfter(lastMonth)) lastMonth = month;
    }
    final selected = _selectedDate ?? now;
    var month = DateTime(selected.year, selected.month);
    if (month.isBefore(firstMonth) || month.isAfter(lastMonth)) {
      month = DateTime(now.year, now.month);
    }
    var displayedYear = month.year;
    final pickedMonth = await showDialog<DateTime>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final canShowPreviousYear = displayedYear > firstMonth.year;
          final canShowNextYear = displayedYear < lastMonth.year;
          return AlertDialog(
            title: const Text('选择订单月份'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: '上一年',
                        onPressed: canShowPreviousYear
                            ? () => setDialogState(() => displayedYear--)
                            : null,
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          '$displayedYear年',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        tooltip: '下一年',
                        onPressed: canShowNextYear
                            ? () => setDialogState(() => displayedYear++)
                            : null,
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.8,
                        ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      final value = DateTime(displayedYear, index + 1);
                      final enabled =
                          !value.isBefore(firstMonth) &&
                          !value.isAfter(lastMonth);
                      final selected = DateUtils.isSameMonth(value, month);
                      return OutlinedButton(
                        key: ValueKey(
                          'order-month-${value.year}-${value.month}',
                        ),
                        onPressed: enabled
                            ? () => setDialogState(() => month = value)
                            : null,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          backgroundColor: selected
                              ? AppTheme.primaryPink
                              : AppTheme.white,
                          foregroundColor: selected
                              ? Colors.white
                              : AppTheme.textDark,
                          disabledBackgroundColor: Colors.grey.shade100,
                          disabledForegroundColor: Colors.grey.shade400,
                          side: BorderSide(
                            color: selected
                                ? AppTheme.primaryPink
                                : AppTheme.accentBeige,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text('${index + 1}月'),
                      );
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, month),
                child: const Text('确定'),
              ),
            ],
          );
        },
      ),
    );
    if (pickedMonth == null || !mounted) return;
    setState(() => _selectedDate = pickedMonth);
  }

  void _showAllOrders() {
    setState(() => _selectedDate = null);
  }

  @override
  Widget build(BuildContext context) {
    final scopedOrders = _orders
        .where(
          (order) => isMerchantOrderVisible(
            order,
            _selectedDate,
            _selectedStaffId,
            byMonth: _filterByMonth,
          ),
        )
        .toList();
    final statusCounts = [
      for (final tab in merchantOrderStatusTabs)
        scopedOrders.where((order) => tab.$2.contains(order.status)).length,
    ];
    final filteredOrders = scopedOrders
        .where(
          (order) => merchantOrderStatusTabs[_selectedStatusTab].$2.contains(
            order.status,
          ),
        )
        .toList();
    final pendingCount = scopedOrders
        .where((order) => order.status == 'pending')
        .length;

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: const Text(
          '商家订单',
          style: TextStyle(
            color: AppTheme.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppTheme.textDark),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _isLoading ? null : _loadOrders,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryPink,
        onRefresh: _loadOrders,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 20),
          children: [
            PageWidth(child: _buildSummary(pendingCount)),
            const SizedBox(height: 12),
            PageWidth(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final dateFilter = _buildDateFilter(scopedOrders.length);
                  final staffFilter = _buildStaffFilter();
                  if (constraints.maxWidth < 700) {
                    return Column(
                      children: [
                        dateFilter,
                        const SizedBox(height: 12),
                        staffFilter,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: dateFilter),
                      const SizedBox(width: 12),
                      Expanded(child: staffFilter),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            PageWidth(child: _buildStatusTabs(statusCounts)),
            const SizedBox(height: 18),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primaryPink),
                ),
              )
            else if (_errorMessage.isNotEmpty)
              PageWidth(child: _buildEmptyState('订单加载失败', _errorMessage))
            else if (filteredOrders.isEmpty)
              PageWidth(
                child: _buildEmptyState(
                  '暂无${merchantOrderStatusTabs[_selectedStatusTab].$1}订单',
                  '可切换日期或月份、理发师或订单状态查看其他订单',
                ),
              )
            else
              ...filteredOrders.map(
                (order) => PageWidth(child: _buildOrderCard(order)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(int pendingCount) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: AppTheme.primaryPink,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '新预约待接单 $pendingCount 单',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text('页面会自动刷新新预约申请', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilter(int visibleCount) {
    final hasSelectedDate = _selectedDate != null;
    final date = _selectedDate ?? DateUtils.dateOnly(DateTime.now());
    final label = hasSelectedDate
        ? (_filterByMonth ? DateFormat('yyyy年MM月') : _filterDateFormat).format(
            date,
          )
        : '全部订单';
    final subtitle = hasSelectedDate
        ? '新预约待接单及${_filterByMonth ? '当月' : '当天'}订单 $visibleCount 单'
        : '显示全部 $visibleCount 单订单';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (final byMonth in [false, true])
                ChoiceChip(
                  label: Text(byMonth ? '按月' : '按日'),
                  selected: _filterByMonth == byMonth,
                  onSelected: (_) => setState(() {
                    _filterByMonth = byMonth;
                    _selectedDate ??= DateUtils.dateOnly(DateTime.now());
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today,
                  color: Colors.blue,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ),
              IconButton(
                tooltip: _filterByMonth ? '选择月份' : '选择日期',
                onPressed: _filterByMonth ? _pickMonth : _pickDate,
                icon: const Icon(Icons.edit_calendar),
                color: AppTheme.primaryPink,
              ),
              if (hasSelectedDate)
                IconButton(
                  tooltip: '显示全部订单',
                  onPressed: _showAllOrders,
                  icon: const Icon(Icons.close),
                  color: Colors.grey[600],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffFilter() {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryPink.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.person_outline,
              color: AppTheme.primaryPink,
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButton<String>(
              value: _selectedStaffId,
              isExpanded: true,
              underline: const SizedBox.shrink(),
              items: [
                const DropdownMenuItem(value: '', child: Text('全部理发师')),
                for (final staff in _staffOptions)
                  DropdownMenuItem(
                    value: staff['id']?.toString() ?? '',
                    child: Text(
                      staff['name']?.toString() ?? '未命名理发师',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) =>
                  setState(() => _selectedStaffId = value ?? ''),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusTabs(List<int> statusCounts) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: DefaultTabController(
        length: merchantOrderStatusTabs.length,
        initialIndex: _selectedStatusTab,
        child: TabBar(
          onTap: (index) => setState(() => _selectedStatusTab = index),
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: AppTheme.primaryPink.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(7),
          ),
          dividerColor: Colors.transparent,
          labelColor: AppTheme.textDark,
          unselectedLabelColor: Colors.grey[600],
          tabs: [
            for (var i = 0; i < merchantOrderStatusTabs.length; i++)
              Tab(
                child: Text(
                  '${merchantOrderStatusTabs[i].$1}（${statusCounts[i]}）',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: merchantOrderStatusTabs[i].$3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BookingOrder order) {
    final isPending = order.status == 'pending';
    final isAccepted = order.status == 'accepted';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPending ? AppTheme.primaryPink : AppTheme.accentBeige,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  order.serviceName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
              ),
              _buildStatusChip(order.status, order.statusLabel),
            ],
          ),
          const SizedBox(height: 12),
          _buildInfoRow(Icons.confirmation_number, '订单号 ${order.orderNo}'),
          _buildInfoRow(
            Icons.person,
            '${order.userName} 预约 ${order.staffName}',
          ),
          if (order.userPhone.isNotEmpty)
            _buildInfoRow(Icons.phone_outlined, '联系电话 ${order.userPhone}'),
          _buildInfoRow(Icons.schedule, _dateFormat.format(order.startTime)),
          _buildInfoRow(
            Icons.payments,
            '${order.servicePrice} / ${order.serviceDuration}',
          ),
          if (order.merchantMessage.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              order.merchantMessage,
              style: TextStyle(color: Colors.grey[700], height: 1.35),
            ),
          ],
          if (order.reviewed && order.review != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _showReviewDialog(order),
                icon: const Icon(Icons.rate_review_outlined, size: 18),
                label: const Text('查看评价'),
              ),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : () => _rescheduleOrder(order),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('预约变更'),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updateOrder(order, false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('拒单', overflow: TextOverflow.ellipsis),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _updateOrder(order, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('接单', overflow: TextOverflow.ellipsis),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
              ],
            ),
          ] else if (isAccepted) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating ? null : () => _rescheduleOrder(order),
                icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                label: const Text('更改预约日期'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isUpdating
                    ? null
                    : () => _updateOrderStatus(
                        order,
                        action: 'cancel',
                        reason: '商家取消预约',
                        successMessage: '已取消预约，用户将收到取消消息',
                      ),
                icon: const Icon(Icons.event_busy, size: 18),
                label: const Text('取消预约'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Icon(icon, size: 17, color: Colors.grey[500]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status, String label) {
    final color = switch (status) {
      'accepted' => Colors.green,
      'completed' => Colors.blue,
      'canceled' => Colors.grey,
      'rejected' => Colors.redAccent,
      _ => Colors.orange,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        status == 'pending' ? '新预约待接单' : label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 70),
      child: Column(
        children: [
          Icon(Icons.inbox, size: 54, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AssignStaffOptionCard extends StatelessWidget {
  const _AssignStaffOptionCard({
    required this.staff,
    required this.selected,
    required this.onTap,
  });

  final Map<String, dynamic> staff;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = staff['name']?.toString() ?? '未命名理发师';
    final role = staff['role']?.toString() ?? '';
    final imageUrl = staff['imageUrl']?.toString() ?? '';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.primaryPink.withValues(alpha: 0.10)
                : AppTheme.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppTheme.primaryPink : AppTheme.accentBeige,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 62,
                  height: 62,
                  color: AppTheme.bgCream,
                  child: imageUrl.isEmpty
                      ? const Icon(
                          Icons.person_outline,
                          color: AppTheme.primaryPink,
                          size: 30,
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person_outline),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textDark,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (role.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: selected
                    ? const Icon(
                        Icons.check_circle,
                        key: ValueKey('selected'),
                        color: AppTheme.primaryPink,
                        size: 28,
                      )
                    : Icon(
                        Icons.radio_button_unchecked,
                        key: const ValueKey('unselected'),
                        color: Colors.grey[350],
                        size: 28,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

List<Map<String, dynamic>> availableStaffForOrder(
  List<Map<String, dynamic>> staffOptions,
  List<BookingOrder> orders,
  BookingOrder order,
) {
  final busyStaffIds = orders
      .where(
        (item) =>
            item.id != order.id &&
            (item.status == 'pending' || item.status == 'accepted') &&
            item.startTime.isAtSameMomentAs(order.startTime),
      )
      .map((item) => item.staffId)
      .where((id) => id.isNotEmpty)
      .toSet();

  return staffOptions
      .where((staff) => !busyStaffIds.contains(staff['id']?.toString() ?? ''))
      .toList();
}
