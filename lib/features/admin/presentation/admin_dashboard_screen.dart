import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../booking/domain/booking_order.dart';
import '../../merchant/data/image_upload_picker.dart';
import '../data/admin_repository.dart';

({
  double total,
  double unfinished,
  double canceled,
  double result,
  int unfinishedCount,
  int canceledCount,
  int resultCount,
})
calculateOrderAccounting(Iterable<BookingOrder> orders) {
  final orderList = orders.toList();
  final unfinishedOrders = orderList
      .where((order) => {'pending', 'accepted'}.contains(order.status))
      .toList();
  final canceledOrders = orderList
      .where((order) => {'canceled', 'rejected'}.contains(order.status))
      .toList();
  final total = orderList.fold<double>(
    0,
    (sum, order) => sum + _bookingAmount(order),
  );
  final unfinished = unfinishedOrders.fold<double>(
    0,
    (sum, order) => sum + _bookingAmount(order),
  );
  final canceled = canceledOrders.fold<double>(
    0,
    (sum, order) => sum + _bookingAmount(order),
  );
  return (
    total: total,
    unfinished: unfinished,
    canceled: canceled,
    result: total - unfinished - canceled,
    unfinishedCount: unfinishedOrders.length,
    canceledCount: canceledOrders.length,
    resultCount:
        orderList.length - unfinishedOrders.length - canceledOrders.length,
  );
}

double _bookingAmount(BookingOrder order) => order.couponId.isNotEmpty
    ? order.payableAmountFen / 100
    : double.tryParse(order.servicePrice.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;

bool isAbnormalAccountingOrder(BookingOrder order, [DateTime? now]) =>
    {'pending', 'accepted'}.contains(order.status) &&
    order.startTime.isBefore(now ?? DateTime.now());

int? pendingOrderOverdueHours(BookingOrder order, [DateTime? now]) {
  if (order.status != 'pending') return null;
  final elapsed = (now ?? DateTime.now()).difference(order.createdAt);
  return elapsed > const Duration(hours: 1) ? elapsed.inHours : null;
}

bool isAuditedReviewStatus(dynamic status) =>
    status == 'approved' || status == 'rejected';

String avatarReviewStatusLabel(dynamic status) => switch (status) {
  'pending' => '待审核',
  'approved' => '已通过',
  'rejected' => '已驳回',
  _ => '未提交',
};

DateTime campaignDayStart(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime campaignDayEnd(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

List<BookingOrder> supportOrdersForUser(
  Iterable<BookingOrder> orders,
  dynamic userId,
) {
  final normalized = userId?.toString().replaceFirst(RegExp(r'^user-'), '');
  if (normalized == null || normalized.isEmpty) return [];
  return orders
      .where(
        (order) =>
            order.userId.replaceFirst(RegExp(r'^user-'), '') == normalized,
      )
      .toList();
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminRepository _repository = AdminRepository();

  bool _isLoading = true;
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _merchants = [];
  List<Map<String, dynamic>> _users = [];
  List<BookingOrder> _bookings = [];
  List<Map<String, dynamic>> _userImages = [];
  List<Map<String, dynamic>> _supportMessages = [];
  Map<String, dynamic> _ad = {};
  Map<String, dynamic> _couponCampaign = {};

  @override
  void initState() {
    super.initState();
    _load(showLoading: true);
  }

  Future<void> _load({bool showLoading = false}) async {
    if (showLoading) setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _repository.fetchOverview(),
        _repository.fetchMerchants(),
        _repository.fetchUsers(),
        _repository.fetchBookings(),
        _repository.fetchUserImages(),
        _repository.fetchAd(),
        _repository.fetchSupportMessages(),
        _repository.fetchCouponCampaign(),
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _merchants = results[1] as List<Map<String, dynamic>>;
        _users = results[2] as List<Map<String, dynamic>>;
        _bookings = results[3] as List<BookingOrder>;
        _userImages = results[4] as List<Map<String, dynamic>>;
        _ad = results[5] as Map<String, dynamic>;
        _supportMessages = results[6] as List<Map<String, dynamic>>;
        _couponCampaign = results[7] as Map<String, dynamic>;
      });
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        widget.onLogout();
        return;
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_saveError(error))));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_saveError(error))));
      }
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 8,
      child: Scaffold(
        backgroundColor: AppTheme.bgCream,
        appBar: AppBar(
          title: const Text('后台管理'),
          backgroundColor: AppTheme.white,
          foregroundColor: AppTheme.textDark,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: '刷新',
              onPressed: _load,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: '退出',
              onPressed: widget.onLogout,
              icon: const Icon(Icons.logout),
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.dashboard_outlined), text: '概览'),
              Tab(icon: Icon(Icons.storefront_outlined), text: '商家账号'),
              Tab(icon: Icon(Icons.people_outline), text: '客户端用户'),
              Tab(icon: Icon(Icons.rate_review_outlined), text: '评论管理'),
              Tab(icon: Icon(Icons.report_outlined), text: '投诉管理'),
              Tab(icon: Icon(Icons.support_agent_outlined), text: '客服消息'),
              Tab(icon: Icon(Icons.campaign_outlined), text: '广告位'),
              Tab(icon: Icon(Icons.local_activity_outlined), text: '活动管理'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryPink),
              )
            : TabBarView(
                children: [
                  _OverviewTab(overview: _overview),
                  _MerchantsTab(
                    merchants: _merchants,
                    onCreate: _showCreateMerchantDialog,
                    onEdit: _showEditMerchantDialog,
                    onReviewLicense: _reviewMerchantLicense,
                    onReviewContent: _reviewMerchantContent,
                    onTogglePublish: _toggleMerchantPublishStatus,
                    onViewLicense: _showLicenseDialog,
                    onViewContent: _showContentDialog,
                    onViewOrders: _showMerchantOrdersDialog,
                  ),
                  _UsersTab(users: _users, onReviewAvatar: _reviewUserAvatar),
                  _ReviewsTab(items: _userImages, onAction: _manageReview),
                  _ComplaintsTab(items: _userImages, users: _users),
                  _SupportMessagesTab(
                    messages: _supportMessages,
                    onViewOrders: _showSupportOrdersDialog,
                  ),
                  _AdTab(config: _ad, onSave: _saveAd),
                  _CouponCampaignTab(
                    data: _couponCampaign,
                    onSave: _saveCouponCampaign,
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _saveCouponCampaign(Map<String, dynamic> campaign) async {
    try {
      final result = await _repository.saveCouponCampaign(campaign);
      if (!mounted) return;
      setState(() => _couponCampaign = result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('活动配置已保存')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveError(error))));
    }
  }

  Future<void> _showSupportOrdersDialog(Map<String, dynamic> message) async {
    final orders = supportOrdersForUser(_bookings, message['userId']);
    final size = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${message['userName'] ?? '用户'} · 关联订单'),
        content: SizedBox(
          width: min(900, size.width - 80),
          height: min(520, size.height - 180),
          child: orders.isEmpty
              ? const Center(child: Text('该用户暂无关联订单'))
              : SingleChildScrollView(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('订单号')),
                        DataColumn(label: Text('商家姓名')),
                        DataColumn(label: Text('下单时间')),
                        DataColumn(label: Text('订单状态')),
                      ],
                      rows: [
                        for (final order in orders)
                          DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  order.orderNo.isEmpty
                                      ? order.id
                                      : order.orderNo,
                                ),
                              ),
                              DataCell(Text(order.salonName)),
                              DataCell(
                                Text(
                                  DateFormat(
                                    'yyyy-MM-dd HH:mm',
                                  ).format(order.createdAt),
                                ),
                              ),
                              DataCell(Text(order.statusLabel)),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMerchantOrdersDialog(Map<String, dynamic> merchant) async {
    final size = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(8),
        child: SizedBox(
          width: min(1500, size.width - 16),
          height: min(820, size.height - 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${merchant['displayName'] ?? merchant['username'] ?? ''} · 当月订单',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: '关闭',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _BookingsTab(
                  bookings: _bookings,
                  merchants: _merchants,
                  users: _users,
                  initialSalonId: merchant['salonId']?.toString(),
                  initialMonth: DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateMerchantDialog() async {
    await _showMerchantDialog();
  }

  Future<Map<String, dynamic>> _saveAd({
    required String imageUrl,
    required String link,
    required bool enabled,
    PickedImage? image,
  }) async {
    final saved = await _repository.saveAd(
      imageUrl: imageUrl,
      link: link,
      enabled: enabled,
      fileName: image?.fileName,
      base64Data: image?.base64Data,
    );
    if (mounted) setState(() => _ad = saved);
    return saved;
  }

  Future<void> _manageReview(Map<String, dynamic> item, String action) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除评论'),
          content: const Text('删除后不可恢复，确定继续吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('删除'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    try {
      await _repository.manageUserImage(
        bookingId: item['bookingId'].toString(),
        type: item['type'].toString(),
        action: action,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      if (error is DioException && error.response?.statusCode == 401) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveError(error))));
    }
  }

  Future<void> _showEditMerchantDialog(Map<String, dynamic> merchant) async {
    await _showMerchantDialog(merchant: merchant);
  }

  Future<void> _reviewMerchantLicense(
    Map<String, dynamic> merchant,
    bool approve,
  ) async {
    String reason = '';
    if (!approve) {
      final controller = TextEditingController();
      reason =
          await showDialog<String>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('驳回营业执照'),
              content: TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '驳回原因'),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, ''),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(context, controller.text.trim()),
                  child: const Text('确认驳回'),
                ),
              ],
            ),
          ) ??
          '';
      controller.dispose();
      if (reason.isEmpty) return;
    }

    try {
      await _repository.reviewMerchantLicense(
        id: merchant['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('审核失败，请确认商家已提交营业执照')));
    }
  }

  Future<void> _toggleMerchantPublishStatus(
    Map<String, dynamic> merchant,
  ) async {
    final currentlyOnline = merchant['publishStatus'] == 'online';
    try {
      await _repository.updateMerchantPublishStatus(
        id: merchant['id'].toString(),
        online: !currentlyOnline,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveError(error))));
    }
  }

  Future<void> _reviewMerchantContent(
    Map<String, dynamic> merchant,
    bool approve,
  ) async {
    final reason = approve ? '' : await _rejectReason('驳回店铺内容');
    if (!approve && reason.isEmpty) return;
    try {
      await _repository.reviewMerchantContent(
        id: merchant['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveError(error))));
    }
  }

  Future<void> _reviewUserAvatar(
    Map<String, dynamic> user,
    bool approve,
  ) async {
    final reason = approve ? '' : await _rejectReason('驳回用户头像');
    if (!approve && reason.isEmpty) return;
    try {
      await _repository.reviewUserAvatar(
        id: user['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(approve ? '头像已通过' : '头像已驳回')));
    } catch (error) {
      if (!mounted) return;
      if (error is DioException && error.response?.statusCode == 401) {
        widget.onLogout();
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveError(error))));
    }
  }

  Future<String> _rejectReason(String title) async {
    final controller = TextEditingController();
    final reason =
        await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(labelText: '驳回原因'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, ''),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, controller.text.trim()),
                child: const Text('确认驳回'),
              ),
            ],
          ),
        ) ??
        '';
    controller.dispose();
    return reason;
  }

  Future<void> _showLicenseDialog(Map<String, dynamic> merchant) async {
    final documents = [
      ('营业执照', merchant['licenseUrl']?.toString() ?? ''),
      ('法人身份证人像面', merchant['legalPersonIdFrontUrl']?.toString() ?? ''),
      ('法人身份证国徽面', merchant['legalPersonIdBackUrl']?.toString() ?? ''),
      ('地址证明', merchant['addressProofUrl']?.toString() ?? ''),
    ];
    if (documents.every((document) => document.$2.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商家尚未提交资质材料')));
      return;
    }

    final size = MediaQuery.sizeOf(context);
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${merchant['displayName']} 资质材料'),
        content: SizedBox(
          width: min(1000, size.width - 48),
          height: min(680, size.height - 160),
          child: GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: size.width >= 900 ? 2 : 1,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.45,
            ),
            itemCount: documents.length,
            itemBuilder: (context, index) => _QualificationDocumentPreview(
              title: documents[index].$1,
              imageUrl: documents[index].$2,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showContentDialog(Map<String, dynamic> merchant) async {
    final salon = Map<String, dynamic>.from((merchant['salon'] as Map?) ?? {});
    final images =
        [
              salon['image'],
              ...((salon['promoImages'] as List?) ?? const []),
              for (final service in (salon['services'] as List?) ?? const [])
                if (service is Map) service['imageUrl'],
              for (final staff in (salon['staff'] as List?) ?? const [])
                if (staff is Map) staff['imageUrl'],
            ]
            .map((item) => item?.toString().trim() ?? '')
            .where((url) => url.startsWith('http'))
            .toSet()
            .toList();

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${merchant['displayName']} 店铺内容'),
        content: SizedBox(
          width: 640,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _ContentLine('店铺名称', salon['name']),
                _ContentLine('地址', salon['address']),
                _ContentLine('短介绍', salon['description']),
                _ContentLine('关于我们', salon['fullDescription']),
                for (final service in (salon['services'] as List?) ?? const [])
                  if (service is Map)
                    _ContentLine(
                      '套餐',
                      '${service['name'] ?? ''} ${service['note'] ?? ''}',
                    ),
                for (final staff in (salon['staff'] as List?) ?? const [])
                  if (staff is Map)
                    _ContentLine(
                      '理发师',
                      '${staff['name'] ?? ''} ${staff['bio'] ?? ''}',
                    ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final url in images)
                      Image.network(
                        url,
                        width: 120,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const SizedBox(
                              width: 120,
                              height: 90,
                              child: Center(child: Icon(Icons.broken_image)),
                            ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _showMerchantDialog({Map<String, dynamic>? merchant}) async {
    final isEditing = merchant != null;
    final salon = Map<String, dynamic>.from(
      (merchant?['salon'] as Map?) ?? const {},
    );
    final usernameController = TextEditingController(
      text: merchant?['username']?.toString() ?? _randomMerchantUsername(),
    );
    final salonIdController = TextEditingController(
      text: merchant?['salonId']?.toString() ?? _randomDigits(6),
    );
    final depositController = TextEditingController(
      text: _merchantDeposit(merchant ?? const {}),
    );
    final passwordController = TextEditingController(
      text: isEditing ? '' : '123456',
    );
    final selectedTags = ((salon['tags'] as List?) ?? const [])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final availableTags = <String>{...selectedTags};
    final customTagController = TextEditingController();

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? '编辑商家账号' : '新增商家账号'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: usernameController,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: '登录账号'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: salonIdController,
                    maxLength: 100,
                    decoration: const InputDecoration(labelText: '店铺ID'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: depositController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '保证金'),
                  ),
                  const SizedBox(height: 12),
                  const Text('店铺标签（最多勾选5个）'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in availableTags)
                        InputChip(
                          label: Text(tag),
                          selected: selectedTags.contains(tag),
                          onSelected:
                              selectedTags.contains(tag) ||
                                  selectedTags.length < 5
                              ? (selected) => setDialogState(() {
                                  if (selected) {
                                    selectedTags.add(tag);
                                  } else {
                                    selectedTags.remove(tag);
                                  }
                                })
                              : null,
                          onDeleted: () => setDialogState(() {
                            availableTags.remove(tag);
                            selectedTags.remove(tag);
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: customTagController,
                          maxLength: 20,
                          decoration: const InputDecoration(
                            labelText: '自定义标签',
                            hintText: '输入后点击添加',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        tooltip: '添加并勾选',
                        onPressed: selectedTags.length < 5
                            ? () {
                                final tag = customTagController.text.trim();
                                if (tag.isEmpty || tag.runes.length > 20) {
                                  return;
                                }
                                setDialogState(() {
                                  availableTags.add(tag);
                                  selectedTags.add(tag);
                                  customTagController.clear();
                                });
                              }
                            : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    maxLength: 128,
                    decoration: InputDecoration(
                      labelText: isEditing ? '重置密码（可不填）' : '初始密码',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  if (!_isValidDeposit(depositController.text)) {
                    throw Exception('保证金必须是非负数字');
                  }
                  final tags = selectedTags.toList();
                  if (isEditing) {
                    await _repository.updateMerchant(
                      id: merchant['id'].toString(),
                      username: usernameController.text.trim(),
                      displayName: usernameController.text.trim(),
                      salonId: salonIdController.text.trim(),
                      deposit: depositController.text.trim(),
                      tags: tags,
                      password: passwordController.text,
                    );
                  } else {
                    await _repository.createMerchant(
                      username: usernameController.text.trim(),
                      displayName: usernameController.text.trim(),
                      salonId: salonIdController.text.trim(),
                      deposit: depositController.text.trim(),
                      tags: tags,
                      password: passwordController.text,
                    );
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(_saveError(error))));
                }
              },
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );

    usernameController.dispose();
    salonIdController.dispose();
    depositController.dispose();
    customTagController.dispose();
    passwordController.dispose();

    if (saved == true) await _load();
  }

  bool _isValidDeposit(String value) {
    final deposit = value.trim();
    if (deposit.isEmpty) return true;
    final number = num.tryParse(deposit.replaceAll(RegExp(r'[^0-9.-]'), ''));
    return number != null && number >= 0;
  }

  String _saveError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'].toString();
      }
    }
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty ? '保存失败，请检查账号、密码或保证金' : message;
  }
}

String _merchantDeposit(Map<String, dynamic> merchant) {
  return (merchant['deposit'] ??
          merchant['depositAmount'] ??
          merchant['guaranteeDeposit'] ??
          '')
      .toString();
}

final _random = Random.secure();

String _randomMerchantUsername() => 'merchant${_randomDigits(6)}';

String _randomDigits(int length) {
  return List.generate(length, (_) => _random.nextInt(10)).join();
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.overview});

  final Map<String, dynamic> overview;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('商家账号', overview['merchantCount']),
      ('客户端用户', overview['clientCount']),
      ('店铺数量', overview['salonCount']),
      ('全部订单', overview['bookingCount']),
      ('待处理订单', overview['pendingCount']),
      ('预约成功订单', overview['acceptedCount']),
    ];

    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: MediaQuery.of(context).size.width > 760 ? 3 : 2,
      childAspectRatio: 1.8,
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      children: [
        for (final item in items)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(item.$1, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text(
                  '${item.$2 ?? 0}',
                  style: const TextStyle(
                    color: AppTheme.textDark,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _QualificationDocumentPreview extends StatelessWidget {
  const _QualificationDocumentPreview({
    required this.title,
    required this.imageUrl,
  });

  final String title;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: imageUrl.isEmpty
                ? const Center(child: Text('未上传'))
                : Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Center(child: Icon(Icons.broken_image, size: 48)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MerchantsTab extends StatelessWidget {
  const _MerchantsTab({
    required this.merchants,
    required this.onCreate,
    required this.onEdit,
    required this.onReviewLicense,
    required this.onReviewContent,
    required this.onTogglePublish,
    required this.onViewLicense,
    required this.onViewContent,
    required this.onViewOrders,
  });

  final List<Map<String, dynamic>> merchants;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final void Function(Map<String, dynamic> merchant, bool approve)
  onReviewLicense;
  final void Function(Map<String, dynamic> merchant, bool approve)
  onReviewContent;
  final ValueChanged<Map<String, dynamic>> onTogglePublish;
  final ValueChanged<Map<String, dynamic>> onViewLicense;
  final ValueChanged<Map<String, dynamic>> onViewContent;
  final ValueChanged<Map<String, dynamic>> onViewOrders;

  @override
  Widget build(BuildContext context) {
    bool approved(Map<String, dynamic> merchant) =>
        merchant['licenseStatus'] == 'approved' &&
        merchant['contentReviewStatus'] == 'approved';

    final pending = merchants.where((merchant) => !approved(merchant)).toList();
    final online = merchants
        .where(
          (merchant) =>
              approved(merchant) && merchant['publishStatus'] == 'online',
        )
        .toList();
    final offline = merchants
        .where(
          (merchant) =>
              approved(merchant) && merchant['publishStatus'] != 'online',
        )
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(text: '已上架'),
                      Tab(text: '待审核'),
                      Tab(text: '未上架'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onCreate,
                  icon: const Icon(Icons.add),
                  label: const Text('新增商家账号'),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMerchantList(online),
                _buildMerchantList(pending),
                _buildMerchantList(offline),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantList(List<Map<String, dynamic>> items) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final merchant in items) _buildMerchantCard(merchant),
        if (items.isEmpty) const Text('暂无商家账号'),
      ],
    );
  }

  Widget _buildMerchantCard(Map<String, dynamic> merchant) {
    final licenseApproved = merchant['licenseStatus'] == 'approved';
    final contentApproved = merchant['contentReviewStatus'] == 'approved';
    final salon = Map<String, dynamic>.from(
      (merchant['salon'] as Map?) ?? const {},
    );
    final salonAddress = salon['address']?.toString().trim() ?? '';
    final salonPhone = salon['phone']?.toString().trim() ?? '';
    final salonTags = ((salon['tags'] as List?) ?? const [])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .join('、');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: AppTheme.primaryPink.withValues(alpha: 0.16),
                child: const Icon(
                  Icons.storefront,
                  color: AppTheme.primaryPink,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant['displayName']?.toString() ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '账号：${merchant['username']}  店铺ID：${merchant['salonId']}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '店铺：${merchant['salonName'] ?? '-'}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '标签：${salonTags.isEmpty ? '-' : salonTags}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '地址：${salonAddress.isEmpty ? '-' : salonAddress}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '联系方式：${salonPhone.isEmpty ? '-' : salonPhone}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '保证金：${_merchantDeposit(merchant)}',
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: '编辑账号',
                onPressed: () => onEdit(merchant),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SmallChip(
                label: _licenseStatusLabel(
                  merchant['licenseStatus']?.toString(),
                ),
              ),
              _SmallChip(
                label: merchant['publishStatus'] == 'online' ? '已上架' : '未上架',
              ),
              _SmallChip(
                label: _contentStatusLabel(
                  merchant['contentReviewStatus']?.toString(),
                ),
              ),
              if ((merchant['licenseRejectReason']?.toString() ?? '')
                  .isNotEmpty)
                _SmallChip(label: '驳回：${merchant['licenseRejectReason']}'),
              if ((merchant['contentRejectReason']?.toString() ?? '')
                  .isNotEmpty)
                _SmallChip(label: '内容驳回：${merchant['contentRejectReason']}'),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => onViewOrders(merchant),
                icon: const Icon(Icons.calculate_outlined),
                label: const Text('核算'),
              ),
              OutlinedButton.icon(
                onPressed: () => onViewLicense(merchant),
                icon: const Icon(Icons.image_outlined),
                label: const Text('查看资质'),
              ),
              OutlinedButton.icon(
                onPressed: licenseApproved
                    ? null
                    : () => onReviewLicense(merchant, true),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('资质通过'),
              ),
              OutlinedButton.icon(
                onPressed: () => onReviewLicense(merchant, false),
                icon: const Icon(Icons.block_outlined),
                label: const Text('驳回'),
              ),
              OutlinedButton.icon(
                onPressed: () => onViewContent(merchant),
                icon: const Icon(Icons.preview_outlined),
                label: const Text('查看内容'),
              ),
              OutlinedButton.icon(
                onPressed: contentApproved
                    ? null
                    : () => onReviewContent(merchant, true),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('内容通过'),
              ),
              OutlinedButton.icon(
                onPressed: () => onReviewContent(merchant, false),
                icon: const Icon(Icons.report_gmailerrorred_outlined),
                label: const Text('内容驳回'),
              ),
              FilledButton.icon(
                onPressed: () => onTogglePublish(merchant),
                icon: Icon(
                  merchant['publishStatus'] == 'online'
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                ),
                label: Text(
                  merchant['publishStatus'] == 'online' ? '下架' : '上架',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _licenseStatusLabel(String? status) {
    return switch (status) {
      'pending' => '执照待审核',
      'approved' => '执照已通过',
      'rejected' => '执照已驳回',
      _ => '执照未提交',
    };
  }

  String _contentStatusLabel(String? status) {
    return switch (status) {
      'approved' => '内容已通过',
      'rejected' => '内容已驳回',
      _ => '内容待审核',
    };
  }

  String _merchantDeposit(Map<String, dynamic> merchant) {
    final deposit =
        merchant['deposit'] ??
        merchant['depositAmount'] ??
        merchant['guaranteeDeposit'];
    return deposit == null || deposit.toString().isEmpty
        ? '-'
        : deposit.toString();
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.accentBeige),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}

class _ContentLine extends StatelessWidget {
  const _ContentLine(this.label, this.value);

  final String label;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    final text = value?.toString().trim() ?? '';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label：${text.isEmpty ? '-' : text}'),
    );
  }
}

typedef _SaveAd =
    Future<Map<String, dynamic>> Function({
      required String imageUrl,
      required String link,
      required bool enabled,
      PickedImage? image,
    });

class _AdTab extends StatefulWidget {
  const _AdTab({required this.config, required this.onSave});

  final Map<String, dynamic> config;
  final _SaveAd onSave;

  @override
  State<_AdTab> createState() => _AdTabState();
}

class _AdTabState extends State<_AdTab> {
  late final TextEditingController _linkController;
  PickedImage? _image;
  late String _imageUrl;
  late bool _enabled;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _imageUrl = widget.config['imageUrl']?.toString() ?? '';
    _enabled = widget.config['enabled'] != false;
    _linkController = TextEditingController(
      text: widget.config['link']?.toString() ?? '/pages/ad/ad',
    );
  }

  @override
  void didUpdateWidget(covariant _AdTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config == widget.config) return;
    _imageUrl = widget.config['imageUrl']?.toString() ?? '';
    _enabled = widget.config['enabled'] != false;
    _linkController.text = widget.config['link']?.toString() ?? '/pages/ad/ad';
  }

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final image = await pickImageForUpload();
      if (image != null && mounted) setState(() => _image = image);
    } catch (error) {
      if (mounted) _showMessage('$error');
    }
  }

  Future<void> _save() async {
    final link = _linkController.text.trim();
    if (!link.startsWith('/pages/')) {
      _showMessage('跳转链接必须是 /pages/... 小程序页面路径');
      return;
    }
    if (_enabled && _image == null && _imageUrl.isEmpty) {
      _showMessage('请先上传广告图片');
      return;
    }

    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(
        imageUrl: _imageUrl,
        link: link,
        enabled: _enabled,
        image: _image,
      );
      if (!mounted) return;
      setState(() {
        _image = null;
        _imageUrl = saved['imageUrl']?.toString() ?? '';
      });
      _showMessage('广告位已保存');
    } catch (error) {
      if (!mounted) return;
      final data = error is DioException ? error.response?.data : null;
      _showMessage(
        data is Map && data['message'] != null
            ? data['message'].toString()
            : '保存失败：$error',
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: _panelDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('顶部广告位', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text('用于小程序首页和店铺详情页，建议上传约 5:1 的横幅图片。'),
                const SizedBox(height: 20),
                if (_imageUrl.isNotEmpty)
                  AspectRatio(
                    aspectRatio: 5,
                    child: Image.network(
                      _imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Center(
                        child: Icon(Icons.broken_image_outlined, size: 48),
                      ),
                    ),
                  ),
                if (_imageUrl.isNotEmpty) const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _saving ? null : _pickImage,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(_image == null ? '选择广告图片' : '重新选择图片'),
                ),
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${_image!.fileName} · ${_image!.width}×${_image!.height}',
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: '点击后跳转链接',
                    hintText: '/pages/ad/ad',
                    helperText: '填写小程序内部页面路径，可带查询参数',
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('显示广告位'),
                  value: _enabled,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _enabled = value),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(_saving ? '保存中...' : '保存广告位'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CouponCampaignTab extends StatefulWidget {
  const _CouponCampaignTab({required this.data, required this.onSave});

  final Map<String, dynamic> data;
  final Future<void> Function(Map<String, dynamic>) onSave;

  @override
  State<_CouponCampaignTab> createState() => _CouponCampaignTabState();
}

class _CouponCampaignTabState extends State<_CouponCampaignTab> {
  late final List<TextEditingController> _minimumControllers;
  late final List<TextEditingController> _discountControllers;
  late final List<TextEditingController> _titleControllers;
  late final List<TextEditingController> _descriptionControllers;
  PickedImage? _promotionImage;
  String _promotionImageUrl = '';
  bool _enabled = false;
  bool _saving = false;
  DateTime? _registrationStartAt;
  DateTime? _registrationEndAt;

  Map<String, dynamic> get _campaign =>
      Map<String, dynamic>.from(widget.data['campaign'] as Map? ?? {});

  @override
  void initState() {
    super.initState();
    _minimumControllers = List.generate(2, (_) => TextEditingController());
    _discountControllers = List.generate(2, (_) => TextEditingController());
    _titleControllers = List.generate(2, (_) => TextEditingController());
    _descriptionControllers = List.generate(2, (_) => TextEditingController());
    _applyData();
  }

  @override
  void didUpdateWidget(covariant _CouponCampaignTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _applyData();
  }

  void _applyData() {
    final campaign = _campaign;
    _enabled = campaign['enabled'] == true;
    _promotionImage = null;
    _promotionImageUrl = campaign['promotionImageUrl']?.toString() ?? '';
    final registrationStartAt = _date(campaign['registrationStartAt']);
    final registrationEndAt = _date(campaign['registrationEndAt']);
    _registrationStartAt = registrationStartAt == null
        ? null
        : campaignDayStart(registrationStartAt);
    _registrationEndAt = registrationEndAt == null
        ? null
        : campaignDayStart(
            registrationEndAt.subtract(const Duration(microseconds: 1)),
          );
    final coupons = (campaign['coupons'] as List? ?? const []);
    for (var i = 0; i < 2; i++) {
      final coupon = i < coupons.length
          ? Map<String, dynamic>.from(coupons[i] as Map)
          : <String, dynamic>{};
      _minimumControllers[i].text = _yuan(coupon['minimumSpendFen']);
      _discountControllers[i].text = _yuan(coupon['discountFen']);
      _titleControllers[i].text = coupon['title']?.toString() ?? '';
      _descriptionControllers[i].text = coupon['description']?.toString() ?? '';
    }
  }

  DateTime? _date(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString())?.toLocal();

  String _yuan(dynamic fen) {
    final value = (fen as num?)?.toInt() ?? 0;
    return value % 100 == 0
        ? '${value ~/ 100}'
        : (value / 100).toStringAsFixed(2);
  }

  @override
  void dispose() {
    for (final controller in [
      ..._minimumControllers,
      ..._discountControllers,
      ..._titleControllers,
      ..._descriptionControllers,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5, 12, 31),
    );
  }

  Future<void> _pickPromotionImage() async {
    try {
      final image = await pickImageForUpload();
      if (image != null && mounted) {
        setState(() => _promotionImage = image);
      }
    } catch (error) {
      if (mounted) _message('$error');
    }
  }

  Future<void> _save() async {
    if ([_registrationStartAt, _registrationEndAt].contains(null)) {
      _message('请完整设置活动日期');
      return;
    }
    if (_enabled && _promotionImage == null && _promotionImageUrl.isEmpty) {
      _message('请先上传首页推广图');
      return;
    }
    final coupons = <Map<String, dynamic>>[];
    for (var i = 0; i < 2; i++) {
      final minimum = double.tryParse(_minimumControllers[i].text.trim());
      final discount = double.tryParse(_discountControllers[i].text.trim());
      if (minimum == null || discount == null) {
        _message('请输入有效的优惠券金额');
        return;
      }
      coupons.add({
        'key': i == 0 ? '99-20' : '199-30',
        'minimumSpendFen': (minimum * 100).round(),
        'discountFen': (discount * 100).round(),
        'title': _titleControllers[i].text.trim(),
        'description': _descriptionControllers[i].text.trim(),
      });
    }

    setState(() => _saving = true);
    try {
      await widget.onSave({
        'enabled': _enabled,
        'registrationStartAt': campaignDayStart(
          _registrationStartAt!,
        ).toUtc().toIso8601String(),
        'registrationEndAt': campaignDayEnd(
          _registrationEndAt!,
        ).toUtc().toIso8601String(),
        'promotionImageUrl': _promotionImageUrl,
        'promotionImageFileName': _promotionImage?.fileName,
        'promotionImageData': _promotionImage?.base64Data,
        'coupons': coupons,
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final stats = Map<String, dynamic>.from(widget.data['stats'] as Map? ?? {});
    final typeStats = (stats['coupons'] as List? ?? const [])
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '新用户赠券',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const Text('活动期间的新用户获得两张待领取优惠券，优惠券有效期与活动日期一致。'),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('开启活动'),
                      value: _enabled,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _enabled = value),
                    ),
                    const Divider(),
                    Text(
                      '首页推广图',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text('活动开启后显示在客户端首页右下角，建议上传正方形图片。'),
                    const SizedBox(height: 12),
                    if (_promotionImageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          _promotionImageUrl,
                          width: 140,
                          height: 140,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const SizedBox.square(
                            dimension: 140,
                            child: Center(
                              child: Icon(
                                Icons.broken_image_outlined,
                                size: 48,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_promotionImageUrl.isNotEmpty)
                      const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _saving ? null : _pickPromotionImage,
                      icon: const Icon(Icons.upload_outlined),
                      label: Text(
                        _promotionImage == null ? '选择推广图片' : '重新选择图片',
                      ),
                    ),
                    if (_promotionImage != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${_promotionImage!.fileName} · '
                          '${_promotionImage!.width}×${_promotionImage!.height}',
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Divider(),
                    _dateButton(
                      '活动开始',
                      _registrationStartAt,
                      (value) => _registrationStartAt = value,
                    ),
                    _dateButton(
                      '活动结束',
                      _registrationEndAt,
                      (value) => _registrationEndAt = value,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < 2; i++) _couponEditor(i),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? '保存中...' : '保存活动配置'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: _panelDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('领取统计', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Text(
                      '符合用户 ${stats['eligibleUserCount'] ?? 0} 人 · '
                      '发放 ${stats['grantedCouponCount'] ?? 0} 张 · '
                      '已领取 ${stats['claimedCouponCount'] ?? 0} 张',
                    ),
                    const SizedBox(height: 8),
                    for (final item in typeStats)
                      Text(
                        '${item['type']}：发放 ${item['grantedCount'] ?? 0} 张，'
                        '领取 ${item['claimedCount'] ?? 0} 张',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dateButton(
    String label,
    DateTime? value,
    void Function(DateTime) assign,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      subtitle: Text(
        value == null ? '未设置' : DateFormat('yyyy-MM-dd').format(value),
      ),
      trailing: const Icon(Icons.edit_calendar_outlined),
      onTap: _saving
          ? null
          : () async {
              final picked = await _pickDate(value);
              if (picked != null && mounted) setState(() => assign(picked));
            },
    );
  }

  Widget _couponEditor(int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.bgCream,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            index == 0 ? '优惠券一' : '优惠券二',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minimumControllers[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '满多少元'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _discountControllers[index],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: '减多少元'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleControllers[index],
            decoration: const InputDecoration(labelText: '标题'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionControllers[index],
            decoration: const InputDecoration(labelText: '说明文本'),
          ),
        ],
      ),
    );
  }
}

class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({required this.items, required this.onAction});

  final List<Map<String, dynamic>> items;
  final void Function(Map<String, dynamic> item, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final reviews = items
        .where(
          (item) =>
              item['type'] == 'review' ||
              item['type'] == 'reviewEdit' ||
              item['type'] == 'reviewReply',
        )
        .toList();
    final pending = reviews
        .where((item) => !isAuditedReviewStatus(item['status']))
        .toList();
    final approved = reviews
        .where((item) => item['status'] == 'approved')
        .toList();
    final rejected = reviews
        .where((item) => item['status'] == 'rejected')
        .toList();

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const Material(
            color: AppTheme.white,
            child: TabBar(
              labelColor: AppTheme.primaryPink,
              unselectedLabelColor: AppTheme.textDark,
              indicatorColor: AppTheme.primaryPink,
              tabs: [
                Tab(text: '待审核'),
                Tab(text: '已审核'),
                Tab(text: '已驳回'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildReviewTable(pending, '暂无待审核评论'),
                _buildReviewTable(approved, '暂无已审核评论'),
                _buildReviewTable(rejected, '暂无已驳回评论'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTable(
    List<Map<String, dynamic>> reviews,
    String emptyText,
  ) {
    if (reviews.isEmpty) return Center(child: Text(emptyText));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: _panelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 76,
              dataRowMaxHeight: 120,
              columns: const [
                DataColumn(label: Text('类型')),
                DataColumn(label: Text('用户名')),
                DataColumn(label: Text('评论内容')),
                DataColumn(label: Text('图片')),
                DataColumn(label: Text('评论时间')),
                DataColumn(label: Text('关联商家')),
                DataColumn(label: Text('状态')),
                DataColumn(label: Text('操作')),
              ],
              rows: [
                for (final item in reviews)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(switch (item['type']) {
                          'reviewReply' => '商家回复',
                          'reviewEdit' => '评价修改',
                          _ => '用户评论',
                        }),
                      ),
                      DataCell(Text(item['userName']?.toString() ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(item['content']?.toString() ?? '-'),
                        ),
                      ),
                      DataCell(_ImageThumbnails(item: item)),
                      DataCell(Text(_itemTime(item['createdAt']))),
                      DataCell(Text(item['salonName']?.toString() ?? '-')),
                      DataCell(
                        _ReviewStatus(status: item['status']?.toString()),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item['status'] != 'approved')
                              FilledButton(
                                onPressed: () => onAction(item, 'approve'),
                                child: const Text('审核通过'),
                              ),
                            if (item['status'] == 'pending')
                              const SizedBox(width: 8),
                            if (item['status'] != 'rejected')
                              OutlinedButton(
                                onPressed: () => onAction(item, 'reject'),
                                child: const Text('驳回'),
                              ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => onAction(item, 'delete'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red,
                              ),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewStatus extends StatelessWidget {
  const _ReviewStatus({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'approved' => ('已通过', Colors.green),
      'rejected' => ('已驳回', Colors.red),
      _ => ('待审核', Colors.orange),
    };
    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}

class _ComplaintsTab extends StatelessWidget {
  const _ComplaintsTab({required this.items, required this.users});

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> users;

  @override
  Widget build(BuildContext context) {
    final complaints = items
        .where((item) => item['type'] == 'complaint')
        .toList();
    if (complaints.isEmpty) {
      return const Center(child: Text('暂无用户投诉'));
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: _panelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 76,
              dataRowMaxHeight: 120,
              columns: const [
                DataColumn(label: Text('用户名')),
                DataColumn(label: Text('订单号')),
                DataColumn(label: Text('投诉内容')),
                DataColumn(label: Text('图片')),
                DataColumn(label: Text('投诉时间')),
                DataColumn(label: Text('关联商家')),
                DataColumn(label: Text('用户电话')),
              ],
              rows: [
                for (final item in complaints)
                  DataRow(
                    cells: [
                      DataCell(Text(item['userName']?.toString() ?? '-')),
                      DataCell(Text(item['bookingId']?.toString() ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(item['content']?.toString() ?? '-'),
                        ),
                      ),
                      DataCell(_ImageThumbnails(item: item)),
                      DataCell(Text(_itemTime(item['createdAt']))),
                      DataCell(Text(item['salonName']?.toString() ?? '-')),
                      DataCell(Text(_userPhone(item['userId']))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _userPhone(dynamic userId) {
    final id = userId?.toString().replaceFirst(RegExp(r'^user-'), '') ?? '';
    for (final user in users) {
      if (user['id']?.toString() == id) {
        final phone = user['phone']?.toString() ?? '';
        return phone.isEmpty ? '-' : phone;
      }
    }
    return '-';
  }
}

class _SupportMessagesTab extends StatelessWidget {
  const _SupportMessagesTab({
    required this.messages,
    required this.onViewOrders,
  });

  final List<Map<String, dynamic>> messages;
  final ValueChanged<Map<String, dynamic>> onViewOrders;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('暂无客服消息'));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: _panelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 72,
              dataRowMaxHeight: 140,
              columns: const [
                DataColumn(label: Text('用户')),
                DataColumn(label: Text('问题描述')),
                DataColumn(label: Text('联系方式')),
                DataColumn(label: Text('提交时间')),
                DataColumn(label: Text('关联订单')),
              ],
              rows: [
                for (final message in messages)
                  DataRow(
                    cells: [
                      DataCell(Text(message['userName']?.toString() ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 420,
                          child: Text(message['problem']?.toString() ?? '-'),
                        ),
                      ),
                      DataCell(Text(message['contact']?.toString() ?? '-')),
                      DataCell(Text(_itemTime(message['createdAt']))),
                      DataCell(
                        TextButton(
                          onPressed: () => onViewOrders(message),
                          child: const Text('关联订单'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

String _itemTime(dynamic value) {
  final time = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return time == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(time);
}

class _ImageThumbnails extends StatelessWidget {
  const _ImageThumbnails({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final urls = ((item['imageUrls'] as List?) ?? const [])
        .map((url) => url.toString())
        .where((url) => url.isNotEmpty)
        .toList();
    if (urls.isEmpty) return const Text('-');

    return SizedBox(
      width: 170,
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final url in urls)
            InkWell(
              onTap: () => _showPreview(context, url),
              borderRadius: BorderRadius.circular(6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  url,
                  width: 48,
                  height: 48,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showPreview(BuildContext context, String url) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: Stack(
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Padding(
                    padding: EdgeInsets.all(48),
                    child: Icon(Icons.broken_image, size: 64),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton.filled(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.users, required this.onReviewAvatar});

  final List<Map<String, dynamic>> users;
  final void Function(Map<String, dynamic> user, bool approve) onReviewAvatar;

  @override
  Widget build(BuildContext context) {
    final pending = users
        .where((user) => user['avatarReviewStatus'] == 'pending')
        .toList();
    final approved = users
        .where((user) => user['avatarReviewStatus'] == 'approved')
        .toList();
    final rejected = users
        .where((user) => user['avatarReviewStatus'] == 'rejected')
        .toList();
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Material(
            color: AppTheme.white,
            child: TabBar(
              isScrollable: true,
              labelColor: AppTheme.primaryPink,
              unselectedLabelColor: AppTheme.textDark,
              indicatorColor: AppTheme.primaryPink,
              tabs: [
                Tab(text: '待审核 (${pending.length})'),
                Tab(text: '全部 (${users.length})'),
                Tab(text: '已通过 (${approved.length})'),
                Tab(text: '已驳回 (${rejected.length})'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _userTable(pending, '暂无待审核头像'),
                _userTable(users, '暂无用户'),
                _userTable(approved, '暂无已通过头像'),
                _userTable(rejected, '暂无已驳回头像'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _userTable(List<Map<String, dynamic>> items, String emptyText) {
    if (items.isEmpty) return Center(child: Text(emptyText));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: _panelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 76,
              dataRowMaxHeight: 110,
              columns: const [
                DataColumn(label: Text('当前头像')),
                DataColumn(label: Text('用户')),
                DataColumn(label: Text('待审头像')),
                DataColumn(label: Text('审核状态')),
                DataColumn(label: Text('提交时间')),
                DataColumn(label: Text('驳回原因')),
                DataColumn(label: Text('操作')),
              ],
              rows: [for (final user in items) _userRow(user)],
            ),
          ),
        ),
      ],
    );
  }

  DataRow _userRow(Map<String, dynamic> user) {
    final pending = user['avatarReviewStatus'] == 'pending';
    return DataRow(
      cells: [
        DataCell(_avatar(user['avatarUrl']?.toString() ?? '')),
        DataCell(
          SizedBox(
            width: 210,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['displayName']?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('账号：${user['account'] ?? '-'}'),
                Text('ID：${user['id'] ?? '-'}'),
              ],
            ),
          ),
        ),
        DataCell(
          _ImageThumbnails(
            item: {
              'imageUrls': [user['pendingAvatarUrl']?.toString() ?? ''],
            },
          ),
        ),
        DataCell(_AvatarReviewStatus(status: user['avatarReviewStatus'])),
        DataCell(Text(_itemTime(user['avatarSubmittedAt']))),
        DataCell(
          SizedBox(
            width: 180,
            child: Text(user['avatarRejectReason']?.toString() ?? '-'),
          ),
        ),
        DataCell(
          pending
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FilledButton(
                      onPressed: () => onReviewAvatar(user, true),
                      child: const Text('通过'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => onReviewAvatar(user, false),
                      child: const Text('驳回'),
                    ),
                  ],
                )
              : const Text('-'),
        ),
      ],
    );
  }

  Widget _avatar(String url) => url.isEmpty
      ? const CircleAvatar(child: Icon(Icons.person_outline))
      : CircleAvatar(
          backgroundImage: NetworkImage(url),
          onBackgroundImageError: (_, _) {},
        );
}

class _AvatarReviewStatus extends StatelessWidget {
  const _AvatarReviewStatus({required this.status});

  final dynamic status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'pending' => Colors.orange,
      'approved' => Colors.green,
      'rejected' => Colors.red,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(avatarReviewStatusLabel(status)),
      labelStyle: TextStyle(color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
    );
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({
    required this.bookings,
    required this.merchants,
    required this.users,
    this.initialSalonId,
    this.initialMonth,
  });

  final List<BookingOrder> bookings;
  final List<Map<String, dynamic>> merchants;
  final List<Map<String, dynamic>> users;
  final String? initialSalonId;
  final DateTime? initialMonth;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String? _selectedSalonId;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedSalonId = widget.initialSalonId;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final merchants = _merchantOptions();
    final salonIds = merchants.map((merchant) => merchant.$3).toSet();
    if (!salonIds.contains(_selectedSalonId)) {
      _selectedSalonId = salonIds.isEmpty ? null : salonIds.first;
    }
    final months = _months(widget.bookings);
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.isEmpty ? null : months.first;
    }

    final selectedMonth = _selectedMonth;
    final orders = widget.bookings.where((order) {
      final sameMerchant =
          _selectedSalonId == null || order.salonId == _selectedSalonId;
      final completedAt = _completedAt(order);
      final sameMonth =
          selectedMonth == null || _isSameMonth(completedAt, selectedMonth);
      return sameMerchant && sameMonth;
    }).toList();
    final accounting = calculateOrderAccounting(orders);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Autocomplete<(String, String, String)>(
          displayStringForOption: _merchantLabel,
          initialValue: TextEditingValue(
            text: _merchantLabel(
              merchants.firstWhere(
                (merchant) => merchant.$3 == _selectedSalonId,
                orElse: () => ('', '', ''),
              ),
            ),
          ),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return merchants;
            return merchants.where((merchant) {
              return merchant.$1.toLowerCase().contains(query) ||
                  merchant.$2.toLowerCase().contains(query);
            });
          },
          onSelected: (merchant) =>
              setState(() => _selectedSalonId = merchant.$3),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: '搜索商家',
                  hintText: '输入商家账号或店铺名称',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<DateTime>(
            value: _selectedMonth,
            hint: const Text('选择月份'),
            items: [
              for (final month in months)
                DropdownMenuItem(
                  value: month,
                  child: Text(DateFormat('yyyy年MM月').format(month)),
                ),
            ],
            onChanged: (value) => setState(() => _selectedMonth = value),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: _panelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('序号'), numeric: true),
                DataColumn(label: Text('订单编号')),
                DataColumn(label: Text('用户信息')),
                DataColumn(label: Text('下单时间')),
                DataColumn(label: Text('订单状态')),
                DataColumn(label: Text('订单交易额'), numeric: true),
                DataColumn(label: Text('佣金'), numeric: true),
              ],
              rows: [
                for (final (index, order) in orders.indexed)
                  DataRow(
                    cells: [
                      DataCell(_orderText(order, '${index + 1}')),
                      DataCell(_orderNumber(order)),
                      DataCell(_orderText(order, _userContact(order))),
                      DataCell(
                        _orderText(
                          order,
                          _dateTimeFormatter.format(order.createdAt),
                        ),
                      ),
                      DataCell(_orderText(order, _orderStatus(order))),
                      DataCell(
                        _orderText(order, _money(_bookingAmount(order))),
                      ),
                      DataCell(
                        _orderText(order, _money(_bookingAmount(order) * 0.05)),
                      ),
                    ],
                  ),
                _accountingRow('总订单额', accounting.total),
                _accountingRow(
                  '未完成订单额',
                  accounting.unfinished,
                  count: accounting.unfinishedCount,
                  deduction: true,
                  color: Colors.amber.shade800,
                ),
                _accountingRow(
                  '已取消订单额',
                  accounting.canceled,
                  count: accounting.canceledCount,
                  deduction: true,
                  color: Colors.red,
                ),
                _accountingRow(
                  '核算结果',
                  accounting.result,
                  count: accounting.resultCount,
                  bold: true,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
        if (orders.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('当前商家本月暂无订单'),
          ),
      ],
    );
  }

  static final _dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm');
  static final _moneyFormatter = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  List<(String, String, String)> _merchantOptions() {
    final options = <String, (String, String, String)>{
      for (final merchant in widget.merchants)
        if ((merchant['salonId']?.toString() ?? '').isNotEmpty)
          merchant['salonId'].toString(): (
            merchant['username']?.toString() ?? '',
            (merchant['salonName']?.toString() ?? '').isEmpty
                ? merchant['salonId'].toString()
                : merchant['salonName'].toString(),
            merchant['salonId'].toString(),
          ),
    };
    for (final order in widget.bookings) {
      if (order.salonId.isNotEmpty) {
        options.putIfAbsent(
          order.salonId,
          () => ('', order.salonName, order.salonId),
        );
      }
    }
    final merchants = options.values.toList()
      ..sort((a, b) => _merchantLabel(a).compareTo(_merchantLabel(b)));
    return merchants;
  }

  String _merchantLabel((String, String, String) merchant) =>
      merchant.$1.isEmpty ? merchant.$2 : '${merchant.$1} · ${merchant.$2}';

  List<DateTime> _months(List<BookingOrder> orders) {
    final months = {
      ?widget.initialMonth,
      for (final order in orders)
        DateTime(_completedAt(order).year, _completedAt(order).month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime _completedAt(BookingOrder order) =>
      order.completedAt ?? order.updatedAt;

  DataRow _accountingRow(
    String label,
    double amount, {
    int? count,
    bool deduction = false,
    bool bold = false,
    Color? color,
  }) {
    final style = TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.bold : null,
    );
    final value = deduction ? '-${_money(amount)}' : _money(amount);
    return DataRow(
      cells: [
        const DataCell(Text('')),
        DataCell(Text(count == null ? label : '$label（$count单）', style: style)),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(Text(value, style: style)),
        DataCell(
          Text(
            deduction ? '-${_money(amount * 0.05)}' : _money(amount * 0.05),
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _orderText(BookingOrder order, String text) {
    final color = switch (order.status) {
      'canceled' || 'rejected' => Colors.red,
      'pending' || 'accepted' => Colors.amber.shade800,
      'completed' => Colors.blue,
      _ => null,
    };
    return Text(text, style: TextStyle(color: color));
  }

  Widget _orderNumber(BookingOrder order) {
    if (!isAbnormalAccountingOrder(order)) {
      return _orderText(order, order.orderNo);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '异常订单：已超过预约时间但仍未完成',
          child: Icon(
            Icons.error_outline,
            size: 18,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 6),
        _orderText(order, order.orderNo),
      ],
    );
  }

  String _userContact(BookingOrder order) {
    final userId = order.userId.replaceFirst(RegExp(r'^user-'), '');
    for (final user in widget.users) {
      if (user['id']?.toString() == userId) {
        final phone = user['phone']?.toString() ?? '';
        return '${order.userName}\n${phone.isEmpty ? '-' : phone}';
      }
    }
    return '${order.userName}\n-';
  }

  String _orderStatus(BookingOrder order) {
    final overdueHours = pendingOrderOverdueHours(order);
    if (overdueHours != null) {
      return '${order.statusLabel}（逾期$overdueHours小时未处理）';
    }
    if (order.status != 'canceled') return order.statusLabel;
    final canceledBy = order.canceledBy.isNotEmpty
        ? order.canceledBy
        : order.merchantMessage.contains('用户已取消')
        ? 'user'
        : 'merchant';
    return '${order.statusLabel}（${canceledBy == 'user' ? '用户取消' : '商家取消'}）';
  }

  String _money(double value) => _moneyFormatter.format(value);
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppTheme.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppTheme.accentBeige),
  );
}
