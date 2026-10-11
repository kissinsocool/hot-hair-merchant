import 'package:flutter/material.dart';

import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminComplaintsPage extends AdminPage {
  const AdminComplaintsPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminComplaintsPage> createState() => _AdminComplaintsPageState();
}

class _AdminComplaintsPageState
    extends
        AdminPageState<
          AdminComplaintsPage,
          ({List<Map<String, dynamic>> items, List<Map<String, dynamic>> users})
        > {
  @override
  Future<({List<Map<String, dynamic>> items, List<Map<String, dynamic>> users})>
  loadData() async {
    final results = await Future.wait([
      repository.fetchUserImages(),
      repository.fetchUsers(),
    ]);
    return (items: results[0], users: results[1]);
  }

  @override
  Widget buildContent(BuildContext context) =>
      _ComplaintsTab(items: data!.items, users: data!.users);
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
          decoration: adminPanelDecoration(),
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
                      DataCell(AdminImageThumbnails(item: item)),
                      DataCell(Text(adminItemTime(item['createdAt']))),
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
