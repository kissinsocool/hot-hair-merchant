import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/theme/app_theme.dart';
import 'package:hot_pepper_merchant/features/booking/data/order_repository.dart';
import 'package:hot_pepper_merchant/features/booking/domain/booking_order.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_orders_screen.dart';

class FakeOrderRepository extends OrderRepository {
  @override
  Future<List<BookingOrder>> fetchMerchantBookings({String? status}) async {
    return [];
  }
}

void main() {
  testWidgets('renders merchant orders home screen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MerchantOrdersScreen(
          repository: FakeOrderRepository(),
          enableRealtime: false,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('商家订单'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    expect(find.text('暂无订单'), findsOneWidget);
  });
}
