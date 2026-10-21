import 'package:flutter/material.dart';

import '../../../../core/network/api_client.dart';

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
          ({
            List<Map<String, dynamic>> items,
            List<Map<String, dynamic>> users,
            List<Map<String, dynamic>> appeals,
          })
        > {
  @override
  Future<
    ({
      List<Map<String, dynamic>> items,
      List<Map<String, dynamic>> users,
      List<Map<String, dynamic>> appeals,
    })
  >
  loadData() async {
    final results = await Future.wait([
      repository.fetchUserImages(),
      repository.fetchUsers(),
      repository.fetchBookingAppeals(),
    ]);
    return (items: results[0], users: results[1], appeals: results[2]);
  }

  @override
  Widget buildContent(BuildContext context) => _ComplaintsTab(
    items: data!.items,
    users: data!.users,
    appeals: data!.appeals,
    onHandle: _handleAppeal,
  );
  Future<void> _handleAppeal(Map<String, dynamic> appeal) async {
    final form = GlobalKey<FormState>();
    var response = '';
    String? decision;
    var saving = false;
    String? error;
    final handled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          canPop: !saving,
          child: AlertDialog(
            title: Text('处理订单申诉 · ${appeal['bookingId']}'),
            content: SizedBox(
              width: 460,
              child: SingleChildScrollView(
                child: Form(
                  key: form,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '申诉类型：${appeal['reason'] == 'no_show' ? '用户未到店' : '其他情况'}',
                      ),
                      const SizedBox(height: 12),
                      Text(appeal['description']?.toString() ?? ''),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: decision,
                        decoration: const InputDecoration(labelText: '审核结果'),
                        items: const [
                          DropdownMenuItem(
                            value: 'approved',
                            child: Text('审核通过'),
                          ),
                          DropdownMenuItem(
                            value: 'rejected',
                            child: Text('未通过'),
                          ),
                        ],
                        onChanged: saving ? null : (value) => decision = value,
                        validator: (value) => value == null ? '请选择审核结果' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        enabled: !saving,
                        minLines: 3,
                        maxLines: 6,
                        maxLength: 2000,
                        decoration: const InputDecoration(labelText: '处理意见'),
                        onChanged: (value) => response = value,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? '请填写处理意见'
                            : null,
                      ),
                      if (error != null)
                        Text(
                          error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!form.currentState!.validate()) return;
                        setDialogState(() {
                          saving = true;
                          error = null;
                        });
                        try {
                          await repository.handleBookingAppeal(
                            appeal['bookingId'].toString(),
                            response.trim(),
                            decision: decision!,
                          );
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext, true);
                          }
                        } catch (e) {
                          if (isUnauthorized(e)) {
                            if (dialogContext.mounted) {
                              Navigator.pop(dialogContext);
                            }
                            if (mounted) widget.onLogout();
                            return;
                          }
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              saving = false;
                              error = userFacingApiError(e);
                            });
                          }
                        }
                      },
                child: Text(saving ? '提交中…' : '提交处理意见'),
              ),
            ],
          ),
        ),
      ),
    );
    if (handled == true && mounted) await refreshAfterMutation();
  }
}

class _ComplaintsTab extends StatelessWidget {
  const _ComplaintsTab({
    required this.items,
    required this.users,
    required this.appeals,
    required this.onHandle,
  });

  final List<Map<String, dynamic>> items;
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> appeals;
  final ValueChanged<Map<String, dynamic>> onHandle;

  @override
  Widget build(BuildContext context) {
    final complaints = items
        .where((item) => item['type'] == 'complaint')
        .toList();

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: '用户投诉'),
              Tab(text: '商家申诉'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (complaints.isEmpty)
                      const Text('暂无用户投诉')
                    else
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
                                    DataCell(
                                      Text(item['userName']?.toString() ?? '-'),
                                    ),
                                    DataCell(
                                      Text(
                                        item['bookingId']?.toString() ?? '-',
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 280,
                                        child: Text(
                                          item['content']?.toString() ?? '-',
                                        ),
                                      ),
                                    ),
                                    DataCell(AdminImageThumbnails(item: item)),
                                    DataCell(
                                      Text(adminItemTime(item['createdAt'])),
                                    ),
                                    DataCell(
                                      Text(
                                        item['salonName']?.toString() ?? '-',
                                      ),
                                    ),
                                    DataCell(Text(_userPhone(item['userId']))),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    if (appeals.isEmpty)
                      const Text('暂无商家订单申诉')
                    else
                      Container(
                        decoration: adminPanelDecoration(),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            dataRowMinHeight: 76,
                            dataRowMaxHeight: 140,
                            columns: const [
                              DataColumn(label: Text('订单号')),
                              DataColumn(label: Text('关联商家')),
                              DataColumn(label: Text('用户')),
                              DataColumn(label: Text('申诉类型')),
                              DataColumn(label: Text('情况说明')),
                              DataColumn(label: Text('提交时间')),
                              DataColumn(label: Text('审核结果')),
                              DataColumn(label: Text('处理意见')),
                              DataColumn(label: Text('操作')),
                            ],
                            rows: [
                              for (final appeal in appeals)
                                DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        appeal['bookingId']?.toString() ?? '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        appeal['salonName']?.toString() ?? '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        appeal['userName']?.toString() ?? '-',
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        appeal['reason'] == 'no_show'
                                            ? '用户未到店'
                                            : '其他情况',
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 280,
                                        child: SingleChildScrollView(
                                          child: Text(
                                            appeal['description']?.toString() ??
                                                '',
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        adminItemTime(appeal['submittedAt']),
                                      ),
                                    ),
                                    DataCell(
                                      Text(switch (appeal['decision']) {
                                        'approved' => '审核通过',
                                        'rejected' => '未通过',
                                        _ =>
                                          appeal['status'] == 'handled'
                                              ? '已处理'
                                              : '待审核',
                                      }),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 280,
                                        child: SingleChildScrollView(
                                          child: Text(
                                            appeal['response']?.toString() ??
                                                '待处理',
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      appeal['status'] == 'handled'
                                          ? const Text('已处理')
                                          : TextButton(
                                              onPressed: () => onHandle(appeal),
                                              child: const Text('处理申诉'),
                                            ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
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
