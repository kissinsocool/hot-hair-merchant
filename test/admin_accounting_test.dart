import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';

void main() {
  test('campaign dates cover the complete selected days', () {
    final date = DateTime(2026, 7, 31, 18, 30);

    expect(campaignDayStart(date), DateTime(2026, 7, 31));
    expect(campaignDayEnd(date), DateTime(2026, 8));
  });

  test('only overdue unfinished accounting orders are abnormal', () {
    final now = DateTime(2026, 7, 28, 12);

    expect(isAbnormalAccountingOrder(_order('pending'), now), isTrue);
    expect(isAbnormalAccountingOrder(_order('accepted'), now), isTrue);
    expect(isAbnormalAccountingOrder(_order('completed'), now), isFalse);
    expect(
      isAbnormalAccountingOrder(
        _order('accepted', startTime: now.add(const Duration(minutes: 1))),
        now,
      ),
      isFalse,
    );
  });

  test('shows whole overdue hours only for pending orders after one hour', () {
    final createdAt = DateTime(2026, 8, 5, 10);
    final pending = _order('pending', createdAt: createdAt);

    expect(
      pendingOrderOverdueHours(
        pending,
        createdAt.add(const Duration(hours: 1)),
      ),
      isNull,
    );
    expect(
      pendingOrderOverdueHours(
        pending,
        createdAt.add(const Duration(hours: 2, minutes: 30)),
      ),
      2,
    );
    expect(
      pendingOrderOverdueHours(
        _order('accepted', createdAt: createdAt),
        createdAt.add(const Duration(hours: 3)),
      ),
      isNull,
    );
  });
}

BookingOrder _order(String status, {DateTime? startTime, DateTime? createdAt}) {
  final time = startTime ?? DateTime(2026, 7, 28, 11, 59);
  return BookingOrder(
    id: status,
    userId: 'user-1',
    userName: '测试用户',
    salonName: '测试门店',
    staffId: 'staff-1',
    staffName: '测试发型师',
    serviceName: '剪发',
    servicePrice: '¥100',
    serviceDuration: '30分钟',
    startTime: time,
    status: status,
    statusLabel: status,
    userMessage: '',
    merchantMessage: '',
    createdAt: createdAt ?? time,
    updatedAt: time,
  );
}
