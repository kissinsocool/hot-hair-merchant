import 'package:intl/intl.dart';

import '../../booking/domain/booking_order.dart';

({
  double total,
  double unfinished,
  double canceled,
  double result,
  int unfinishedCount,
  int canceledCount,
  int resultCount,
})
calculateOrderAccounting(Iterable<BookingOrder> orders) {
  final orderList = orders.toList();
  final unfinishedOrders = orderList
      .where((order) => {'pending', 'accepted'}.contains(order.status))
      .toList();
  final canceledOrders = orderList
      .where((order) => {'canceled', 'rejected'}.contains(order.status))
      .toList();
  final total = orderList.fold<double>(
    0,
    (sum, order) => sum + bookingAmount(order),
  );
  final unfinished = unfinishedOrders.fold<double>(
    0,
    (sum, order) => sum + bookingAmount(order),
  );
  final canceled = canceledOrders.fold<double>(
    0,
    (sum, order) => sum + bookingAmount(order),
  );
  return (
    total: total,
    unfinished: unfinished,
    canceled: canceled,
    result: total - unfinished - canceled,
    unfinishedCount: unfinishedOrders.length,
    canceledCount: canceledOrders.length,
    resultCount:
        orderList.length - unfinishedOrders.length - canceledOrders.length,
  );
}

double bookingAmount(BookingOrder order) => order.couponId.isNotEmpty
    ? order.payableAmountFen / 100
    : double.tryParse(order.servicePrice.replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;

bool isAbnormalAccountingOrder(BookingOrder order, [DateTime? now]) =>
    {'pending', 'accepted'}.contains(order.status) &&
    order.startTime.isBefore(now ?? DateTime.now());

int? pendingOrderOverdueHours(BookingOrder order, [DateTime? now]) {
  if (order.status != 'pending') return null;
  final elapsed = (now ?? DateTime.now()).difference(order.createdAt);
  return elapsed > const Duration(hours: 1) ? elapsed.inHours : null;
}

bool isAuditedReviewStatus(dynamic status) =>
    status == 'approved' || status == 'rejected';

List<Map<String, dynamic>> sortMerchantsByContentSubmission(
  Iterable<Map<String, dynamic>> merchants,
) {
  DateTime? submittedAt(Map<String, dynamic> merchant) {
    return DateTime.tryParse(merchant['contentSubmittedAt']?.toString() ?? '');
  }

  final sorted = merchants.toList();
  sorted.sort((a, b) {
    final aTime = submittedAt(a);
    final bTime = submittedAt(b);
    if (aTime == null) return bTime == null ? 0 : 1;
    if (bTime == null) return -1;
    return bTime.compareTo(aTime);
  });
  return sorted;
}

String merchantContentSubmissionText(Map<String, dynamic> merchant) {
  final time = adminItemTime(merchant['contentSubmittedAt']);
  return time == '-' ? '最后一次内容提交时间：暂无记录' : '最后一次内容提交时间：$time';
}

List<Map<String, dynamic>> servicePromotionRows(
  Iterable<Map<String, dynamic>> merchants,
) => [
  for (final merchant in merchants)
    for (final service
        in ((merchant['salon'] as Map?)?['services'] as List?) ?? const [])
      if (service is Map &&
          const {
            'pending',
            'approved',
            'rejected',
          }.contains(service['promotionReviewStatus']))
        {
          ...Map<String, dynamic>.from(service),
          'merchantId': merchant['id'],
          'salonName':
              (merchant['salon'] as Map?)?['name'] ?? merchant['salonName'],
        },
];

String avatarReviewStatusLabel(dynamic status) => switch (status) {
  'pending' => '待审核',
  'approved' => '已通过',
  'rejected' => '已驳回',
  _ => '未提交',
};

DateTime campaignDayStart(DateTime date) =>
    DateTime(date.year, date.month, date.day);

DateTime campaignDayEnd(DateTime date) =>
    DateTime(date.year, date.month, date.day + 1);

List<BookingOrder> supportOrdersForUser(
  Iterable<BookingOrder> orders,
  dynamic userId,
) {
  final normalized = userId?.toString().replaceFirst(RegExp(r'^user-'), '');
  if (normalized == null || normalized.isEmpty) return [];
  return orders
      .where(
        (order) =>
            order.userId.replaceFirst(RegExp(r'^user-'), '') == normalized,
      )
      .toList();
}

String adminItemTime(dynamic value) {
  final time = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
  return time == null ? '-' : DateFormat('yyyy-MM-dd HH:mm').format(time);
}
