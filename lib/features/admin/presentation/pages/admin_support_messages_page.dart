import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../domain/admin_rules.dart';
import '../admin_page.dart';
import '../widgets/admin_widgets.dart';

class AdminSupportMessagesPage extends AdminPage {
  const AdminSupportMessagesPage({
    super.key,
    required super.repository,
    required super.onLogout,
    required super.active,
    required super.refreshVersion,
    required super.onChanged,
  });
  @override
  State<AdminSupportMessagesPage> createState() =>
      _AdminSupportMessagesPageState();
}

class _AdminSupportMessagesPageState
    extends
        AdminPageState<AdminSupportMessagesPage, List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> loadData() async {
    return repository.fetchSupportMessages();
  }

  @override
  Widget buildContent(BuildContext context) => _SupportMessagesTab(
    messages: data!,
    onViewOrders: _showSupportOrdersDialog,
  );

  Future<void> _showSupportOrdersDialog(Map<String, dynamic> message) async {
    try {
      final bookings = await repository.fetchBookings();
      if (!mounted) return;
      final orders = supportOrdersForUser(bookings, message['userId']);
      final size = MediaQuery.sizeOf(context);
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('${message['userName'] ?? '用户'} · 关联订单'),
          content: SizedBox(
            width: min(900, size.width - 80),
            height: min(520, size.height - 180),
            child: orders.isEmpty
                ? const Center(child: Text('该用户暂无关联订单'))
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('订单号')),
                          DataColumn(label: Text('商家姓名')),
                          DataColumn(label: Text('下单时间')),
                          DataColumn(label: Text('订单状态')),
                        ],
                        rows: [
                          for (final order in orders)
                            DataRow(
                              cells: [
                                DataCell(
                                  Text(
                                    order.orderNo.isEmpty
                                        ? order.id
                                        : order.orderNo,
                                  ),
                                ),
                                DataCell(Text(order.salonName)),
                                DataCell(
                                  Text(
                                    DateFormat(
                                      'yyyy-MM-dd HH:mm',
                                    ).format(order.createdAt),
                                  ),
                                ),
                                DataCell(Text(order.statusLabel)),
                              ],
                            ),
                        ],
                      ),
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
    } catch (error) {
      showError(error);
    }
  }
}

class _SupportMessagesTab extends StatelessWidget {
  const _SupportMessagesTab({
    required this.messages,
    required this.onViewOrders,
  });

  final List<Map<String, dynamic>> messages;
  final ValueChanged<Map<String, dynamic>> onViewOrders;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const Center(child: Text('暂无客服消息'));
    }
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          decoration: adminPanelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 72,
              dataRowMaxHeight: 140,
              columns: const [
                DataColumn(label: Text('用户')),
                DataColumn(label: Text('问题描述')),
                DataColumn(label: Text('联系方式')),
                DataColumn(label: Text('提交时间')),
                DataColumn(label: Text('关联订单')),
              ],
              rows: [
                for (final message in messages)
                  DataRow(
                    cells: [
                      DataCell(Text(message['userName']?.toString() ?? '-')),
                      DataCell(
                        SizedBox(
                          width: 420,
                          child: Text(message['problem']?.toString() ?? '-'),
                        ),
                      ),
                      DataCell(Text(message['contact']?.toString() ?? '-')),
                      DataCell(Text(adminItemTime(message['createdAt']))),
                      DataCell(
                        TextButton(
                          onPressed: () => onViewOrders(message),
                          child: const Text('关联订单'),
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
