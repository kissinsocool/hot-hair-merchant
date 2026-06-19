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
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
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
      if (mounted) setState(() => _isLoading = false);
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
                    onTogglePublish: _toggleMerchantPublishStatus,
                    onViewLicense: _showLicenseDialog,
                  ),
                  _UsersTab(users: _users),
                  _BookingsTab(bookings: _bookings),
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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('上架失败，营业执照审核通过后才能上架')));
    }
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

  Future<void> _showMerchantDialog({Map<String, dynamic>? merchant}) async {
    final usernameController = TextEditingController(
      text: merchant?['username']?.toString() ?? '',
    );
    final displayNameController = TextEditingController(
      text: merchant?['displayName']?.toString() ?? '',
    );
    final salonIdController = TextEditingController(
      text: merchant?['salonId']?.toString() ?? '1',
    );
    final passwordController = TextEditingController();
    final isEditing = merchant != null;

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
                controller: displayNameController,
                decoration: const InputDecoration(labelText: '显示名称'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: salonIdController,
                decoration: const InputDecoration(labelText: '店铺ID'),
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
                if (isEditing) {
                  await _repository.updateMerchant(
                    id: merchant['id'].toString(),
                    username: usernameController.text.trim(),
                    displayName: displayNameController.text.trim(),
                    salonId: salonIdController.text.trim(),
                    password: passwordController.text,
                  );
                } else {
                  await _repository.createMerchant(
                    username: usernameController.text.trim(),
                    displayName: displayNameController.text.trim(),
                    salonId: salonIdController.text.trim(),
                    password: passwordController.text,
                  );
                }
                if (context.mounted) Navigator.pop(context, true);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('保存失败，请检查账号或密码')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );

    usernameController.dispose();
    displayNameController.dispose();
    salonIdController.dispose();
    passwordController.dispose();

    if (saved == true) await _load();
  }
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
    required this.onTogglePublish,
    required this.onViewLicense,
  });

  final List<Map<String, dynamic>> merchants;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final void Function(Map<String, dynamic> merchant, bool approve)
  onReviewLicense;
  final ValueChanged<Map<String, dynamic>> onTogglePublish;
  final ValueChanged<Map<String, dynamic>> onViewLicense;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: const Text('新增商家账号'),
          ),
        ),
        const SizedBox(height: 12),
        for (final merchant in merchants)
          Container(
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
                      backgroundColor: AppTheme.primaryPink.withValues(
                        alpha: 0.16,
                      ),
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
                      label: merchant['publishStatus'] == 'online'
                          ? '已上架'
                          : '已下架',
                    ),
                    if ((merchant['licenseRejectReason']?.toString() ?? '')
                        .isNotEmpty)
                      _SmallChip(
                        label: '驳回：${merchant['licenseRejectReason']}',
                      ),
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
                      label: const Text('查看执照'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onReviewLicense(merchant, true),
                      icon: const Icon(Icons.verified_outlined),
                      label: const Text('审核通过'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => onReviewLicense(merchant, false),
                      icon: const Icon(Icons.block_outlined),
                      label: const Text('驳回'),
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
          ),
      ],
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

class _BookingsTab extends StatelessWidget {
  const _BookingsTab({required this.bookings});

  final List<BookingOrder> bookings;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('yyyy-MM-dd HH:mm');
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final order in bookings)
          _DataTile(
            icon: Icons.receipt_long_outlined,
            title: '${order.userName} · ${order.serviceName}',
            subtitle:
                '${formatter.format(order.startTime)}  ${order.staffName}  ${order.statusLabel}',
          ),
      ],
    );
  }
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
