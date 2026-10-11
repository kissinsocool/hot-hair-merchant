import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminServicePromotionsPage extends AdminPage {
  const AdminServicePromotionsPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminServicePromotionsPage> createState() =>
      _AdminServicePromotionsPageState();
}

class _AdminServicePromotionsPageState
    extends
        AdminPageState<AdminServicePromotionsPage, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> loadData() async {
    return repository.fetchMerchants();
  }

  @override
  Widget buildContent(BuildContext context) => _ServicePromotionsTab(
    merchants: data!,
    onAction: _reviewServicePromotion,
  );

  Future<void> _reviewServicePromotion(
    Map<String, dynamic> service,
    bool approve,
  ) async {
    final reason = approve ? '' : await rejectReason('驳回套餐推广');
    if (!approve && reason.isEmpty) return;
    try {
      await repository.reviewServicePromotion(
        merchantId: service['merchantId'].toString(),
        serviceId: service['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await refreshAfterMutation();
    } catch (error) {
      showError(error);
    }
  }
}

class _ServicePromotionsTab extends StatelessWidget {
  const _ServicePromotionsTab({
    required this.merchants,
    required this.onAction,
  });

  final List<Map<String, dynamic>> merchants;
  final void Function(Map<String, dynamic> service, bool approve) onAction;

  @override
  Widget build(BuildContext context) {
    final rows = servicePromotionRows(merchants);
    final pending = rows
        .where((item) => item['promotionReviewStatus'] == 'pending')
        .toList();
    final approved = rows
        .where((item) => item['promotionReviewStatus'] == 'approved')
        .toList();
    final rejected = rows
        .where((item) => item['promotionReviewStatus'] == 'rejected')
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
                _buildTable(pending, '暂无待审核套餐推广'),
                _buildTable(approved, '暂无已审核套餐推广'),
                _buildTable(rejected, '暂无已驳回套餐推广'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Map<String, dynamic>> rows, String emptyText) {
    if (rows.isEmpty) return Center(child: Text(emptyText));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: adminPanelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 76,
              dataRowMaxHeight: 130,
              columns: const [
                DataColumn(label: Text('店铺')),
                DataColumn(label: Text('套餐名称')),
                DataColumn(label: Text('标签')),
                DataColumn(label: Text('价格')),
                DataColumn(label: Text('图片')),
                DataColumn(label: Text('审核时间')),
                DataColumn(label: Text('状态')),
                DataColumn(label: Text('操作')),
              ],
              rows: [
                for (final item in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(item['salonName']?.toString() ?? '-')),
                      DataCell(Text(item['name']?.toString() ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 180,
                          child: Text(
                            ((item['tags'] as List?) ?? const []).join('、'),
                          ),
                        ),
                      ),
                      DataCell(Text(_servicePrice(item['priceFen']))),
                      DataCell(AdminImageThumbnails(item: item)),
                      DataCell(
                        Text(adminItemTime(item['promotionReviewedAt'])),
                      ),
                      DataCell(
                        AdminReviewStatus(
                          status: item['promotionReviewStatus']?.toString(),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (item['promotionReviewStatus'] != 'approved')
                              FilledButton(
                                onPressed: () => onAction(item, true),
                                child: const Text('审核通过'),
                              ),
                            if (item['promotionReviewStatus'] !=
                                'rejected') ...[
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => onAction(item, false),
                                child: const Text('驳回'),
                              ),
                            ],
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

  String _servicePrice(dynamic value) {
    final fen = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (fen == null) return '-';
    final yuan = fen / 100;
    return '¥${yuan == yuan.roundToDouble() ? yuan.toInt() : yuan.toStringAsFixed(2)}';
  }
}
