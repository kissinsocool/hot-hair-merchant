import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../booking/domain/booking_order.dart';
import '../data/admin_repository.dart';

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
      ]);
      if (!mounted) return;
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _merchants = results[1] as List<Map<String, dynamic>>;
        _users = results[2] as List<Map<String, dynamic>>;
        _bookings = results[3] as List<BookingOrder>;
      });
    } finally {
      if (showLoading && mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
              Tab(icon: Icon(Icons.receipt_long_outlined), text: '订单'),
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
                  ),
                  _UsersTab(users: _users),
                  _BookingsTab(bookings: _bookings, merchants: _merchants),
                ],
              ),
      ),
    );
  }

  Future<void> _showCreateMerchantDialog() async {
    await _showMerchantDialog();
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
    final licenseUrl = merchant['licenseUrl']?.toString() ?? '';
    if (licenseUrl.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商家尚未提交营业执照')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${merchant['displayName']} 营业执照'),
        content: SizedBox(
          width: 520,
          child: Image.network(
            licenseUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => const SizedBox(
              height: 240,
              child: Center(child: Icon(Icons.broken_image)),
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
                _ContentLine('电话', salon['phone']),
                _ContentLine('短介绍', salon['description']),
                _ContentLine('关于我们', salon['fullDescription']),
                for (final service in (salon['services'] as List?) ?? const [])
                  if (service is Map)
                    _ContentLine(
                      '套餐',
                      '${service['name'] ?? ''} ${service['price'] ?? ''} ${service['note'] ?? ''}',
                    ),
                for (final staff in (salon['staff'] as List?) ?? const [])
                  if (staff is Map)
                    _ContentLine(
                      '理发师',
                      '${staff['name'] ?? ''} ${staff['role'] ?? ''} ${staff['bio'] ?? ''}',
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

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? '编辑商家账号' : '新增商家账号'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(labelText: '登录账号'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salonIdController,
                decoration: const InputDecoration(labelText: '店铺ID'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: depositController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '保证金'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: isEditing ? '重置密码（可不填）' : '初始密码',
                ),
              ),
            ],
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
                if (isEditing) {
                  await _repository.updateMerchant(
                    id: merchant['id'].toString(),
                    username: usernameController.text.trim(),
                    displayName: usernameController.text.trim(),
                    salonId: salonIdController.text.trim(),
                    deposit: depositController.text.trim(),
                    password: passwordController.text,
                  );
                } else {
                  await _repository.createMerchant(
                    username: usernameController.text.trim(),
                    displayName: usernameController.text.trim(),
                    salonId: salonIdController.text.trim(),
                    deposit: depositController.text.trim(),
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
    );

    usernameController.dispose();
    salonIdController.dispose();
    depositController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final pending = merchants
        .where(
          (merchant) =>
              merchant['licenseStatus'] == 'pending' ||
              merchant['contentReviewStatus'] == 'pending',
        )
        .toList();
    final online = merchants
        .where(
          (merchant) =>
              merchant['licenseStatus'] != 'pending' &&
              merchant['contentReviewStatus'] != 'pending' &&
              merchant['publishStatus'] == 'online',
        )
        .toList();
    final offline = merchants
        .where(
          (merchant) =>
              merchant['licenseStatus'] != 'pending' &&
              merchant['contentReviewStatus'] != 'pending' &&
              merchant['publishStatus'] != 'online',
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
                      Tab(text: '待审核'),
                      Tab(text: '已上架'),
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
                _buildMerchantList(pending),
                _buildMerchantList(online),
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
                onPressed: () => onViewLicense(merchant),
                icon: const Icon(Icons.image_outlined),
                label: const Text('查看资质'),
              ),
              OutlinedButton.icon(
                onPressed: () => onReviewLicense(merchant, true),
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
                onPressed: () => onReviewContent(merchant, true),
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

class _UsersTab extends StatelessWidget {
  const _UsersTab({required this.users});

  final List<Map<String, dynamic>> users;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final user in users)
          _DataTile(
            icon: Icons.person_outline,
            title: user['displayName']?.toString() ?? '',
            subtitle: '账号：${user['account']}  ID：${user['id']}',
          ),
      ],
    );
  }
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({required this.bookings, required this.merchants});

  final List<BookingOrder> bookings;
  final List<Map<String, dynamic>> merchants;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String? _selectedMerchant;
  DateTime? _selectedMonth;

  @override
  Widget build(BuildContext context) {
    final merchants = _merchantOptions();
    final merchantNames = merchants.map((merchant) => merchant.$2).toSet();
    if (!merchantNames.contains(_selectedMerchant)) {
      _selectedMerchant = merchantNames.isEmpty ? null : merchantNames.first;
    }
    final months = _months(widget.bookings);
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.isEmpty ? null : months.first;
    }

    final selectedMonth = _selectedMonth;
    final orders = widget.bookings.where((order) {
      final sameMerchant =
          _selectedMerchant == null || order.salonName == _selectedMerchant;
      final completedAt = _completedAt(order);
      final sameMonth =
          selectedMonth == null || _isSameMonth(completedAt, selectedMonth);
      return sameMerchant && sameMonth;
    }).toList();
    final amountTotal = orders.fold<double>(
      0,
      (total, order) => total + _amount(order.servicePrice),
    );
    final commissionTotal = amountTotal * 0.05;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Autocomplete<(String, String)>(
          displayStringForOption: _merchantLabel,
          initialValue: TextEditingValue(
            text: _merchantLabel(
              merchants.firstWhere(
                (merchant) => merchant.$2 == _selectedMerchant,
                orElse: () => ('', ''),
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
              setState(() => _selectedMerchant = merchant.$2),
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
              columns: const [
                DataColumn(label: Text('订单编号')),
                DataColumn(label: Text('完成日期')),
                DataColumn(label: Text('订单交易额'), numeric: true),
                DataColumn(label: Text('佣金'), numeric: true),
              ],
              rows: [
                for (final order in orders)
                  DataRow(
                    cells: [
                      DataCell(Text(order.orderNo)),
                      DataCell(
                        Text(_dateFormatter.format(_completedAt(order))),
                      ),
                      DataCell(Text(_money(_amount(order.servicePrice)))),
                      DataCell(
                        Text(_money(_amount(order.servicePrice) * 0.05)),
                      ),
                    ],
                  ),
                DataRow(
                  cells: [
                    const DataCell(Text('汇总')),
                    const DataCell(Text('')),
                    DataCell(Text(_money(amountTotal))),
                    DataCell(Text(_money(commissionTotal))),
                  ],
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

  static final _dateFormatter = DateFormat('yyyy-MM-dd');
  static final _moneyFormatter = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  List<(String, String)> _merchantOptions() {
    final options = <String, (String, String)>{
      for (final merchant in widget.merchants)
        if ((merchant['salonName']?.toString() ?? '').isNotEmpty)
          merchant['salonName'].toString(): (
            merchant['username']?.toString() ?? '',
            merchant['salonName'].toString(),
          ),
    };
    for (final order in widget.bookings) {
      options.putIfAbsent(order.salonName, () => ('', order.salonName));
    }
    final merchants = options.values.toList()
      ..sort((a, b) => _merchantLabel(a).compareTo(_merchantLabel(b)));
    return merchants;
  }

  String _merchantLabel((String, String) merchant) =>
      merchant.$1.isEmpty ? merchant.$2 : '${merchant.$1} · ${merchant.$2}';

  List<DateTime> _months(List<BookingOrder> orders) {
    final months = {
      for (final order in orders)
        DateTime(_completedAt(order).year, _completedAt(order).month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  double _amount(String price) {
    return double.tryParse(price.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
  }

  DateTime _completedAt(BookingOrder order) =>
      order.completedAt ?? order.updatedAt;

  String _money(double value) => _moneyFormatter.format(value);
}

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: _panelDecoration(),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primaryPink.withValues(alpha: 0.16),
          child: Icon(icon, color: AppTheme.primaryPink),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
      ),
    );
  }
}

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: AppTheme.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: AppTheme.accentBeige),
  );
}
