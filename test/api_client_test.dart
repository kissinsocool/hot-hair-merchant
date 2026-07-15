import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_merchant/core/network/api_client.dart';

void main() {
  test('pagination stops at the reported total', () {
    expect(hasMorePages(100, 100, 100, 250), isTrue);
    expect(hasMorePages(250, 50, 100, 250), isFalse);
    expect(hasMorePages(100, 100, 100, null), isTrue);
    expect(hasMorePages(50, 50, 100, null), isFalse);
  });
}
