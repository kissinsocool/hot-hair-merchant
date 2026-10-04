import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../booking/domain/booking_order.dart';

enum OrderDateFilter { all, month, day }

List<BookingOrder> filterAdminOrders(
  Iterable<BookingOrder> orders, {
  required OrderDateFilter dateFilter,
  DateTime? selectedDate,
  String shopQuery = '',
  String? status,
}) {
  final query = shopQuery.trim().toLowerCase();
  return orders.where((order) {
    final date = order.createdAt;
    final matchesDate = switch (dateFilter) {
      OrderDateFilter.all => true,
      OrderDateFilter.month =>
        selectedDate != null &&
            date.year == selectedDate.year &&
            date.month == selectedDate.month,
      OrderDateFilter.day =>
        selectedDate != null &&
            date.year == selectedDate.year &&
            date.month == selectedDate.month &&
            date.day == selectedDate.day,
    };
    return matchesDate &&
        order.salonName.toLowerCase().contains(query) &&
        (status == null || order.status == status);
  }).toList();
}

class AdminOrdersSummaryScreen extends StatefulWidget {
  const AdminOrdersSummaryScreen({
    super.key,
    required this.orders,
    required this.merchants,
    required this.users,
  });

  final List<BookingOrder> orders;
  final List<Map<String, dynamic>> merchants;
  final List<Map<String, dynamic>> users;

  @override
  State<AdminOrdersSummaryScreen> createState() =>
      _AdminOrdersSummaryScreenState();
}

class _AdminOrdersSummaryScreenState extends State<AdminOrdersSummaryScreen> {
  OrderDateFilter _dateFilter = OrderDateFilter.all;
  DateTime? _selectedDate;
  String _shopQuery = '';
  String _selectedStatus = 'all';

  static final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');
  static final _monthFormat = DateFormat('yyyy年MM月');

  @override
  Widget build(BuildContext context) {
    final months = {
      for (final order in widget.orders)
        DateTime(order.createdAt.year, order.createdAt.month),
    }.toList()..sort((a, b) => b.compareTo(a));
    final orders = filterAdminOrders(
      widget.orders,
      dateFilter: _dateFilter,
      selectedDate: _selectedDate,
      shopQuery: _shopQuery,
      status: _selectedStatus == 'all' ? null : _selectedStatus,
    );
    final merchantsBySalonId = {
      for (final merchant in widget.merchants)
        merchant['salonId']?.toString() ?? '': merchant,
    };
    final phonesByUserId = {
      for (final user in widget.users)
        user['id']?.toString() ?? '': user['phone']?.toString() ?? '',
    };

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(title: const Text('订单汇总')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: TextField(
                  decoration: const InputDecoration(
                    labelText: '查找店铺订单',
                    hintText: '输入店铺名称',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (value) => setState(() => _shopQuery = value),
                ),
              ),
              SegmentedButton<OrderDateFilter>(
                segments: const [
                  ButtonSegment(value: OrderDateFilter.all, label: Text('全部')),
                  ButtonSegment(
                    value: OrderDateFilter.month,
                    label: Text('按月'),
                  ),
                  ButtonSegment(value: OrderDateFilter.day, label: Text('按日')),
                ],
                selected: {_dateFilter},
                onSelectionChanged: (value) => setState(() {
                  _dateFilter = value.first;
                  _selectedDate = _dateFilter == OrderDateFilter.month
                      ? (months.isEmpty ? null : months.first)
                      : _dateFilter == OrderDateFilter.day
                      ? DateTime.now()
                      : null;
                }),
              ),
              if (_dateFilter == OrderDateFilter.month)
                DropdownButton<DateTime>(
                  value: _selectedDate,
                  hint: const Text('选择月份'),
                  items: [
                    for (final month in months)
                      DropdownMenuItem(
                        value: month,
                        child: Text(_monthFormat.format(month)),
                      ),
                  ],
                  onChanged: (value) => setState(() => _selectedDate = value),
                ),
              if (_dateFilter == OrderDateFilter.day)
                OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    _selectedDate == null
                        ? '选择日期'
                        : DateFormat('yyyy-MM-dd').format(_selectedDate!),
                  ),
                ),
              DropdownButton<String>(
                value: _selectedStatus,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部状态')),
                  DropdownMenuItem(value: 'pending', child: Text('待确认')),
                  DropdownMenuItem(value: 'canceled', child: Text('已取消')),
                  DropdownMenuItem(value: 'completed', child: Text('已完成')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _selectedStatus = value);
                },
              ),
              Text('共 ${orders.length} 单'),
            ],
          ),
          const SizedBox(height: 16),
          if (orders.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('暂无符合条件的订单'),
              ),
            )
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  dataRowMinHeight: 68,
                  dataRowMaxHeight: 96,
                  columns: const [
                    DataColumn(label: Text('用户名称')),
                    DataColumn(label: Text('用户电话')),
                    DataColumn(label: Text('下单时间')),
                    DataColumn(label: Text('订单状态')),
                    DataColumn(label: Text('商家信息')),
                    DataColumn(label: Text('套餐名称')),
                    DataColumn(label: Text('价格')),
                    DataColumn(label: Text('优惠券信息')),
                  ],
                  rows: [
                    for (final order in orders)
                      _row(
                        order,
                        merchantsBySalonId[order.salonId],
                        phonesByUserId[order.userId.replaceFirst(
                          RegExp(r'^user-'),
                          '',
                        )],
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  DataRow _row(
    BookingOrder order,
    Map<String, dynamic>? merchant,
    String? userPhone,
  ) {
    final salon = merchant?['salon'] as Map? ?? const {};
    final phone = order.userPhone.isNotEmpty
        ? order.userPhone
        : userPhone ?? '';
    final salonName = order.salonName.isNotEmpty
        ? order.salonName
        : salon['name']?.toString() ?? '';
    final salonPhone = salon['phone']?.toString() ?? '';
    final salonAddress = salon['address']?.toString() ?? '';
    final coupon = order.couponTitle.isNotEmpty ? order.couponTitle : '优惠券';
    final hasCoupon =
        order.couponId.isNotEmpty ||
        order.couponTitle.isNotEmpty ||
        order.couponCode.isNotEmpty;
    final couponCode = order.couponCode.isEmpty
        ? ''
        : '\n券码：${order.couponCode}';
    return DataRow(
      cells: [
        DataCell(Text(_orDash(order.userName))),
        DataCell(Text(_orDash(phone))),
        DataCell(Text(_dateTimeFormat.format(order.createdAt))),
        DataCell(Text(_orDash(order.statusLabel))),
        DataCell(
          SizedBox(
            width: 240,
            child: Text(
              '${_orDash(salonName)}\n电话：${_orDash(salonPhone)}\n地址：${_orDash(salonAddress)}',
            ),
          ),
        ),
        DataCell(Text(_orDash(order.serviceName))),
        DataCell(Text(_orDash(order.servicePrice))),
        DataCell(
          Text(
            hasCoupon
                ? '$coupon$couponCode\n优惠 ¥${_yuan(order.couponDiscountFen)} · 实付 ¥${_yuan(order.payableAmountFen)}'
                : '未使用',
          ),
        ),
      ],
    );
  }

  String _orDash(String value) => value.trim().isEmpty ? '-' : value;

  String _yuan(int fen) => (fen / 100).toStringAsFixed(fen % 100 == 0 ? 0 : 2);
}
