import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/features/merchant/presentation/merchant_salon_screen.dart';

void main() {
  test(
    'original prices and discount round to cents without inverse calculation',
    () {
      final service = <String, dynamic>{
        'priceFen': 28000,
        'discountTenths': 90,
      };
      normalizeServicePricing(service);
      expect(service['originalPriceFen'], 28000);
      expect(service['priceFen'], 25200);
      normalizeServicePricing(service);
      expect(service['priceFen'], 25200);
      service['originalPriceFen'] = 19950;
      service['discountTenths'] = 1;
      updateServicePrice(service);
      expect(service['priceFen'], 200);
      service['discountTenths'] = null;
      updateServicePrice(service);
      expect(service['priceFen'], 19950);
    },
  );

  test('discount input has one decimal', () {
    expect(parseDiscountTenths('6.0'), 60);
    expect(parseDiscountTenths('6.5'), 65);
    expect(parseDiscountTenths('6'), 60);
    expect(parseDiscountTenths('0.1'), 1);
    expect(parseDiscountTenths('10.0'), 100);
    for (final value in ['', '0', '0.0', '10.1', '6.55', '-1', 'abc']) {
      expect(parseDiscountTenths(value), isNull, reason: value);
    }
    expect(parsePriceFen('1964'), 196400);
  });
}
