import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminReviewsPage extends AdminPage {
  const AdminReviewsPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminReviewsPage> createState() => _AdminReviewsPageState();
}

class _AdminReviewsPageState
    extends AdminPageState<AdminReviewsPage, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> loadData() async {
    return repository.fetchUserImages();
  }

  @override
  Widget buildContent(BuildContext context) =>
      _ReviewsTab(items: data!, onAction: _manageReview);

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
      await repository.manageUserImage(
        bookingId: item['bookingId'].toString(),
        type: item['type'].toString(),
        action: action,
      );
      await refreshAfterMutation();
    } catch (error) {
      showError(error);
    }
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
          decoration: adminPanelDecoration(),
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
                      DataCell(AdminImageThumbnails(item: item)),
                      DataCell(Text(adminItemTime(item['createdAt']))),
                      DataCell(Text(item['salonName']?.toString() ?? '-')),
                      DataCell(
                        AdminReviewStatus(status: item['status']?.toString()),
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
