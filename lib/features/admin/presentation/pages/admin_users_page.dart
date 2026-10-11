import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminUsersPage extends AdminPage {
  const AdminUsersPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState
    extends AdminPageState<AdminUsersPage, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> loadData() async {
    return repository.fetchUsers();
  }

  @override
  Widget buildContent(BuildContext context) =>
      _UsersTab(users: data!, onReviewAvatar: _reviewUserAvatar);

  Future<void> _reviewUserAvatar(
    Map<String, dynamic> user,
    bool approve,
  ) async {
    final reason = approve ? '' : await rejectReason('驳回用户头像');
    if (!approve && reason.isEmpty) return;
    try {
      await repository.reviewUserAvatar(
        id: user['id'].toString(),
        approve: approve,
        reason: reason,
      );
      await refreshAfterMutation();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(approve ? '头像已通过' : '头像已驳回')));
    } catch (error) {
      showError(error);
    }
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
          decoration: adminPanelDecoration(),
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
          AdminImageThumbnails(
            item: {
              'imageUrls': [user['pendingAvatarUrl']?.toString() ?? ''],
            },
          ),
        ),
        DataCell(_AvatarReviewStatus(status: user['avatarReviewStatus'])),
        DataCell(Text(adminItemTime(user['avatarSubmittedAt']))),
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
