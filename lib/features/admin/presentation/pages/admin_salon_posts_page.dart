import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminSalonPostsPage extends AdminPage {
  const AdminSalonPostsPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminSalonPostsPage> createState() => _AdminSalonPostsPageState();
}

class _AdminSalonPostsPageState
    extends AdminPageState<AdminSalonPostsPage, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> loadData() async {
    return repository.fetchSalonPosts();
  }

  @override
  Widget buildContent(BuildContext context) =>
      _SalonPostsTab(posts: data!, onAction: _manageSalonPost);

  Future<void> _manageSalonPost(
    Map<String, dynamic> post,
    String action,
  ) async {
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('删除动态'),
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
      await repository.manageSalonPost(
        id: post['id'].toString(),
        action: action,
      );
      await refreshAfterMutation();
    } catch (error) {
      showError(error);
    }
  }
}

class _SalonPostsTab extends StatelessWidget {
  const _SalonPostsTab({required this.posts, required this.onAction});

  final List<Map<String, dynamic>> posts;
  final void Function(Map<String, dynamic> post, String action) onAction;

  @override
  Widget build(BuildContext context) {
    final pending = posts
        .where((post) => !isAuditedReviewStatus(post['reviewStatus']))
        .toList();
    final approved = posts
        .where((post) => post['reviewStatus'] == 'approved')
        .toList();
    final rejected = posts
        .where((post) => post['reviewStatus'] == 'rejected')
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
                _buildTable(pending, '暂无待审核动态'),
                _buildTable(approved, '暂无已审核动态'),
                _buildTable(rejected, '暂无已驳回动态'),
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
              dataRowMaxHeight: 140,
              columns: const [
                DataColumn(label: Text('投稿人')),
                DataColumn(label: Text('动态内容')),
                DataColumn(label: Text('图片')),
                DataColumn(label: Text('发布时间')),
                DataColumn(label: Text('关联商家')),
                DataColumn(label: Text('状态')),
                DataColumn(label: Text('操作')),
              ],
              rows: [
                for (final post in rows)
                  DataRow(
                    cells: [
                      DataCell(Text(post['authorName']?.toString() ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 280,
                          child: Text(post['content']?.toString() ?? '-'),
                        ),
                      ),
                      DataCell(AdminImageThumbnails(item: post)),
                      DataCell(Text(adminItemTime(post['createdAt']))),
                      DataCell(Text(post['salonName']?.toString() ?? '-')),
                      DataCell(
                        AdminReviewStatus(
                          status: post['reviewStatus']?.toString(),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (post['reviewStatus'] != 'approved')
                              FilledButton(
                                onPressed: () => onAction(post, 'approve'),
                                child: const Text('审核通过'),
                              ),
                            if (post['reviewStatus'] == 'pending')
                              const SizedBox(width: 8),
                            if (post['reviewStatus'] != 'rejected')
                              OutlinedButton(
                                onPressed: () => onAction(post, 'reject'),
                                child: const Text('驳回'),
                              ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () => onAction(post, 'delete'),
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
