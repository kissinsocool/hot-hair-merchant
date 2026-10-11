import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../booking/domain/booking_order.dart';
import '../../domain/admin_rules.dart';
import 'admin_widgets.dart';

class AdminBookingsView extends StatefulWidget {
  const AdminBookingsView({
    super.key,
    required this.bookings,
    required this.merchants,
    required this.users,
    this.initialSalonId,
    this.initialMonth,
  });

  final List<BookingOrder> bookings;
  final List<Map<String, dynamic>> merchants;
  final List<Map<String, dynamic>> users;
  final String? initialSalonId;
  final DateTime? initialMonth;

  @override
  State<AdminBookingsView> createState() => AdminBookingsViewState();
}

class AdminBookingsViewState extends State<AdminBookingsView> {
  String? _selectedSalonId;
  DateTime? _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedSalonId = widget.initialSalonId;
    _selectedMonth = widget.initialMonth;
  }

  @override
  Widget build(BuildContext context) {
    final merchants = _merchantOptions();
    final salonIds = merchants.map((merchant) => merchant.$3).toSet();
    if (!salonIds.contains(_selectedSalonId)) {
      _selectedSalonId = salonIds.isEmpty ? null : salonIds.first;
    }
    final months = _months(widget.bookings);
    if (!months.contains(_selectedMonth)) {
      _selectedMonth = months.isEmpty ? null : months.first;
    }

    final selectedMonth = _selectedMonth;
    final orders = widget.bookings.where((order) {
      final sameMerchant =
          _selectedSalonId == null || order.salonId == _selectedSalonId;
      final completedAt = _completedAt(order);
      final sameMonth =
          selectedMonth == null || _isSameMonth(completedAt, selectedMonth);
      return sameMerchant && sameMonth;
    }).toList();
    final accounting = calculateOrderAccounting(orders);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Autocomplete<(String, String, String)>(
          displayStringForOption: _merchantLabel,
          initialValue: TextEditingValue(
            text: _merchantLabel(
              merchants.firstWhere(
                (merchant) => merchant.$3 == _selectedSalonId,
                orElse: () => ('', '', ''),
              ),
            ),
          ),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return merchants;
            return merchants.where((merchant) {
              return merchant.$1.toLowerCase().contains(query) ||
                  merchant.$2.toLowerCase().contains(query);
            });
          },
          onSelected: (merchant) =>
              setState(() => _selectedSalonId = merchant.$3),
          fieldViewBuilder:
              (context, controller, focusNode, onFieldSubmitted) => TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: '搜索商家',
                  hintText: '输入商家账号或店铺名称',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: DropdownButton<DateTime>(
            value: _selectedMonth,
            hint: const Text('选择月份'),
            items: [
              for (final month in months)
                DropdownMenuItem(
                  value: month,
                  child: Text(DateFormat('yyyy年MM月').format(month)),
                ),
            ],
            onChanged: (value) => setState(() => _selectedMonth = value),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: adminPanelDecoration(),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              dataRowMinHeight: 56,
              dataRowMaxHeight: 72,
              columns: const [
                DataColumn(label: Text('序号'), numeric: true),
                DataColumn(label: Text('订单编号')),
                DataColumn(label: Text('用户信息')),
                DataColumn(label: Text('下单时间')),
                DataColumn(label: Text('订单状态')),
                DataColumn(label: Text('订单交易额'), numeric: true),
                DataColumn(label: Text('佣金'), numeric: true),
              ],
              rows: [
                for (final (index, order) in orders.indexed)
                  DataRow(
                    cells: [
                      DataCell(_orderText(order, '${index + 1}')),
                      DataCell(_orderNumber(order)),
                      DataCell(_orderText(order, _userContact(order))),
                      DataCell(
                        _orderText(
                          order,
                          _dateTimeFormatter.format(order.createdAt),
                        ),
                      ),
                      DataCell(_orderText(order, _orderStatus(order))),
                      DataCell(_orderText(order, _money(bookingAmount(order)))),
                      DataCell(
                        _orderText(order, _money(bookingAmount(order) * 0.05)),
                      ),
                    ],
                  ),
                _accountingRow('总订单额', accounting.total),
                _accountingRow(
                  '未完成订单额',
                  accounting.unfinished,
                  count: accounting.unfinishedCount,
                  deduction: true,
                  color: Colors.amber.shade800,
                ),
                _accountingRow(
                  '已取消订单额',
                  accounting.canceled,
                  count: accounting.canceledCount,
                  deduction: true,
                  color: Colors.red,
                ),
                _accountingRow(
                  '核算结果',
                  accounting.result,
                  count: accounting.resultCount,
                  bold: true,
                  color: Colors.green,
                ),
              ],
            ),
          ),
        ),
        if (orders.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: Text('当前商家本月暂无订单'),
          ),
      ],
    );
  }

  static final _dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm');
  static final _moneyFormatter = NumberFormat.currency(
    locale: 'ja_JP',
    symbol: '¥',
    decimalDigits: 0,
  );

  List<(String, String, String)> _merchantOptions() {
    final options = <String, (String, String, String)>{
      for (final merchant in widget.merchants)
        if ((merchant['salonId']?.toString() ?? '').isNotEmpty)
          merchant['salonId'].toString(): (
            merchant['username']?.toString() ?? '',
            (merchant['salonName']?.toString() ?? '').isEmpty
                ? merchant['salonId'].toString()
                : merchant['salonName'].toString(),
            merchant['salonId'].toString(),
          ),
    };
    for (final order in widget.bookings) {
      if (order.salonId.isNotEmpty) {
        options.putIfAbsent(
          order.salonId,
          () => ('', order.salonName, order.salonId),
        );
      }
    }
    final merchants = options.values.toList()
      ..sort((a, b) => _merchantLabel(a).compareTo(_merchantLabel(b)));
    return merchants;
  }

  String _merchantLabel((String, String, String) merchant) =>
      merchant.$1.isEmpty ? merchant.$2 : '${merchant.$1} · ${merchant.$2}';

  List<DateTime> _months(List<BookingOrder> orders) {
    final months = {
      ?widget.initialMonth,
      for (final order in orders)
        DateTime(_completedAt(order).year, _completedAt(order).month),
    }.toList()..sort((a, b) => b.compareTo(a));
    return months;
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  DateTime _completedAt(BookingOrder order) =>
      order.completedAt ?? order.updatedAt;

  DataRow _accountingRow(
    String label,
    double amount, {
    int? count,
    bool deduction = false,
    bool bold = false,
    Color? color,
  }) {
    final style = TextStyle(
      color: color,
      fontWeight: bold ? FontWeight.bold : null,
    );
    final value = deduction ? '-${_money(amount)}' : _money(amount);
    return DataRow(
      cells: [
        const DataCell(Text('')),
        DataCell(Text(count == null ? label : '$label（$count单）', style: style)),
        const DataCell(Text('')),
        const DataCell(Text('')),
        const DataCell(Text('')),
        DataCell(Text(value, style: style)),
        DataCell(
          Text(
            deduction ? '-${_money(amount * 0.05)}' : _money(amount * 0.05),
            style: style,
          ),
        ),
      ],
    );
  }

  Widget _orderText(BookingOrder order, String text) {
    final color = switch (order.status) {
      'canceled' || 'rejected' => Colors.red,
      'pending' || 'accepted' => Colors.amber.shade800,
      'completed' => Colors.blue,
      _ => null,
    };
    return Text(text, style: TextStyle(color: color));
  }

  Widget _orderNumber(BookingOrder order) {
    if (!isAbnormalAccountingOrder(order)) {
      return _orderText(order, order.orderNo);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: '异常订单：已超过预约时间但仍未完成',
          child: Icon(
            Icons.error_outline,
            size: 18,
            color: Colors.red.shade700,
          ),
        ),
        const SizedBox(width: 6),
        _orderText(order, order.orderNo),
      ],
    );
  }

  String _userContact(BookingOrder order) {
    final userId = order.userId.replaceFirst(RegExp(r'^user-'), '');
    for (final user in widget.users) {
      if (user['id']?.toString() == userId) {
        final phone = user['phone']?.toString() ?? '';
        return '${order.userName}\n${phone.isEmpty ? '-' : phone}';
      }
    }
    return '${order.userName}\n-';
  }

  String _orderStatus(BookingOrder order) {
    final overdueHours = pendingOrderOverdueHours(order);
    if (overdueHours != null) {
      return '${order.statusLabel}（逾期$overdueHours小时未处理）';
    }
    if (order.status != 'canceled') return order.statusLabel;
    final canceledBy = order.canceledBy.isNotEmpty
        ? order.canceledBy
        : order.merchantMessage.contains('用户已取消')
        ? 'user'
        : 'merchant';
    return '${order.statusLabel}（${canceledBy == 'user' ? '用户取消' : '商家取消'}）';
  }

  String _money(double value) => _moneyFormatter.format(value);
}
