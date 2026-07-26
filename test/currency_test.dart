import 'package:backend_test_dashboard/utils/currency.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converts existing dollar prices to formatted riel', () {
    expect(formatDualCurrency(4.50, 4100), r'$4.50 · 18,450 ៛');
    expect(formatDualCurrency(4.50, 4100, showRiel: false), r'$4.50');
  });
}
