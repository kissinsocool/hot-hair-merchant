import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/image/image_upload_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminCouponCampaignPage extends AdminPage {
  const AdminCouponCampaignPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminCouponCampaignPage> createState() =>
      _AdminCouponCampaignPageState();
}

class _AdminCouponCampaignPageState
    extends AdminPageState<AdminCouponCampaignPage, Map<String, dynamic>> {
  @override
  Future<Map<String, dynamic>> loadData() async {
    return repository.fetchCouponCampaign();
  }

  @override
  Widget buildContent(BuildContext context) =>
      _CouponCampaignTab(data: data!, onSave: _saveCouponCampaign);

  Future<void> _saveCouponCampaign(Map<String, dynamic> campaign) async {
    try {
      final result = await repository.saveCouponCampaign(campaign);
      if (!mounted) return;
      updateData(result);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('活动配置已保存')));
    } catch (error) {
      showError(error);
    }
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
                decoration: adminPanelDecoration(),
                child: Material(
                  type: MaterialType.transparency,
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
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: adminPanelDecoration(),
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
