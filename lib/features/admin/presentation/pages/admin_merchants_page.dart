import 'dart:math';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../booking/domain/booking_order.dart';
import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_bookings_view.dart';
import '../widgets/admin_widgets.dart';

class AdminMerchantsPage extends AdminPage {
  const AdminMerchantsPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminMerchantsPage> createState() => _AdminMerchantsPageState();
}

class _AdminMerchantsPageState
    extends AdminPageState<AdminMerchantsPage, List<Map<String, dynamic>>> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _merchants => data!;
  @override
  Future<List<Map<String, dynamic>>> loadData() async {
    return repository.fetchMerchants();
  }

  @override
  Widget buildContent(BuildContext context) => _MerchantsTab(
    merchants: _merchants,
    searchController: _searchController,
    onSearchChanged: () => setState(() {}),
    onCreate: _showCreateMerchantDialog,
    onEdit: _showEditMerchantDialog,
    onDelete: _deleteMerchant,
    onReviewLicense: _reviewMerchantLicense,
    onReviewContent: _reviewMerchantContent,
    onTogglePublish: _toggleMerchantPublishStatus,
    onViewLicense: _showLicenseDialog,
    onViewContent: _showContentDialog,
    onViewOrders: _showMerchantOrdersDialog,
  );

  Future<void> _showMerchantOrdersDialog(Map<String, dynamic> merchant) async {
    try {
      final results = await Future.wait([
        repository.fetchBookings(),
        repository.fetchUsers(),
      ]);
      if (!mounted) return;
      final bookings = results[0] as List<BookingOrder>;
      final users = results[1] as List<Map<String, dynamic>>;
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
                  child: AdminBookingsView(
                    bookings: bookings,
                    merchants: _merchants,
                    users: users,
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
    } catch (error) {
      showError(error);
    }
  }

  Future<void> _showCreateMerchantDialog() async {
    await _showMerchantDialog();
  }

  Future<void> _showEditMerchantDialog(Map<String, dynamic> merchant) async {
    await _showMerchantDialog(merchant: merchant);
  }

  Future<void> _deleteMerchant(Map<String, dynamic> merchant) async {
    final username = merchant['username']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除商家账号'),
        content: Text('确定删除账号“$username”吗？店铺资料不会删除，此操作不可恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await repository.deleteMerchant(merchant['id'].toString());
      await refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商家账号已删除')));
    } catch (error) {
      showError(error);
    }
  }

  Future<void> _reviewMerchantLicense(
    Map<String, dynamic> merchant,
    bool approve,
  ) async {
    final reason = approve ? '' : await rejectReason('驳回营业执照');
    if (!approve && reason.isEmpty) return;
    try {
      await repository.reviewMerchantLicense(
        id: merchant['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await refreshAfterMutation();
    } catch (error) {
      showError(error, fallback: '审核失败，请确认商家已提交营业执照');
    }
  }

  Future<void> _toggleMerchantPublishStatus(
    Map<String, dynamic> merchant,
  ) async {
    final currentlyOnline = merchant['publishStatus'] == 'online';
    try {
      await repository.updateMerchantPublishStatus(
        id: merchant['id'].toString(),
        online: !currentlyOnline,
      );
      await refreshAfterMutation();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> _reviewMerchantContent(
    Map<String, dynamic> merchant,
    bool approve,
  ) async {
    final reason = approve ? '' : await rejectReason('驳回店铺内容');
    if (!approve && reason.isEmpty) return;
    try {
      await repository.reviewMerchantContent(
        id: merchant['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await refreshAfterMutation();
    } catch (error) {
      showError(error);
    }
  }

  Future<void> _showLicenseDialog(Map<String, dynamic> merchant) async {
    final documents = [('营业执照', merchant['licenseUrl']?.toString() ?? '')];
    if (documents.every((document) => document.$2.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('商家尚未提交营业执照')));
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
                if (service is Map)
                  ...((service['imageUrls'] as List?) ?? [service['imageUrl']]),
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
    final List<String> businessDistricts;
    try {
      businessDistricts = await repository.fetchBusinessDistricts();
    } catch (error) {
      showError(error, fallback: '商圈加载失败，请重试');
      return;
    }
    if (!mounted) return;

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
    var businessDistrict = salon['businessDistrict']?.toString() ?? '';
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
                  DropdownButtonFormField<String>(
                    initialValue: businessDistrict,
                    decoration: const InputDecoration(labelText: '商圈'),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('未设置')),
                      for (final district in {
                        ...businessDistricts,
                        if (businessDistrict.isNotEmpty) businessDistrict,
                      })
                        DropdownMenuItem(
                          value: district,
                          child: Text(district),
                        ),
                    ],
                    onChanged: (value) => businessDistrict = value ?? '',
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
                    await repository.updateMerchant(
                      id: merchant['id'].toString(),
                      username: usernameController.text.trim(),
                      displayName: usernameController.text.trim(),
                      salonId: salonIdController.text.trim(),
                      deposit: depositController.text.trim(),
                      tags: tags,
                      businessDistrict: businessDistrict,
                      password: passwordController.text,
                    );
                  } else {
                    await repository.createMerchant(
                      username: usernameController.text.trim(),
                      displayName: usernameController.text.trim(),
                      salonId: salonIdController.text.trim(),
                      deposit: depositController.text.trim(),
                      tags: tags,
                      businessDistrict: businessDistrict,
                      password: passwordController.text,
                    );
                  }
                  if (context.mounted) Navigator.pop(context, true);
                } catch (error) {
                  showError(error);
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

    if (saved == true) await refreshAfterMutation();
  }

  bool _isValidDeposit(String value) {
    final deposit = value.trim();
    if (deposit.isEmpty) return true;
    final number = num.tryParse(deposit.replaceAll(RegExp(r'[^0-9.-]'), ''));
    return number != null && number >= 0;
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
      decoration: adminPanelDecoration(),
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
    required this.searchController,
    required this.onSearchChanged,
    required this.onCreate,
    required this.onEdit,
    required this.onDelete,
    required this.onReviewLicense,
    required this.onReviewContent,
    required this.onTogglePublish,
    required this.onViewLicense,
    required this.onViewContent,
    required this.onViewOrders,
  });

  final List<Map<String, dynamic>> merchants;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onCreate;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<Map<String, dynamic>> onDelete;
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
    final query = searchController.text.trim().toLowerCase();
    final filtered = merchants.where(
      (merchant) =>
          query.isEmpty ||
          [
            merchant['displayName'],
            merchant['salonName'],
            (merchant['salon'] as Map?)?['name'],
          ].any(
            (name) => (name?.toString() ?? '').toLowerCase().contains(query),
          ),
    );
    bool approved(Map<String, dynamic> merchant) =>
        merchant['licenseStatus'] == 'approved' &&
        merchant['contentReviewStatus'] == 'approved';

    final pending = sortMerchantsByContentSubmission(
      filtered.where((merchant) => !approved(merchant)),
    );
    final online = filtered
        .where(
          (merchant) =>
              approved(merchant) && merchant['publishStatus'] == 'online',
        )
        .toList();
    final offline = filtered
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
            padding: const EdgeInsets.only(top: 16),
            child: FractionallySizedBox(
              widthFactor: 0.8,
              child: TextField(
                controller: searchController,
                onChanged: (_) => onSearchChanged(),
                decoration: InputDecoration(
                  hintText: '按商家名称搜索',
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                  isDense: true,
                  suffixIcon: searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '清空搜索',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            searchController.clear();
                            onSearchChanged();
                          },
                        ),
                ),
              ),
            ),
          ),
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
        if (items.isEmpty)
          Text(searchController.text.trim().isEmpty ? '暂无商家账号' : '未找到匹配的商家'),
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
    final contentSubmissionText = merchantContentSubmissionText(merchant);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: adminPanelDecoration(),
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
                      '商圈：${(salon['businessDistrict']?.toString() ?? '').isEmpty ? '-' : salon['businessDistrict']}',
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
                    if (contentSubmissionText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        contentSubmissionText,
                        style: const TextStyle(
                          color: AppTheme.primaryPink,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
              OutlinedButton.icon(
                onPressed: () => onDelete(merchant),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除账号'),
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
