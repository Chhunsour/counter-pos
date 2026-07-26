import 'package:backend_test_dashboard/models/backend_test_item.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the backend record contract', () {
    final item = BackendTestItem.fromJson({
      'id': 7,
      'title': 'Write test',
      'description': 'Checks inserts',
      'status': 'active',
      'created_at': '2026-07-26T10:30:00Z',
      'image_name': 'coffee.png',
      'image_data': 'data:image/png;base64,aGVsbG8=',
    });

    expect(item.id, 7);
    expect(item.createdAt.isUtc, isTrue);
    expect(item.toWriteJson(), {
      'title': 'Write test',
      'description': 'Checks inserts',
      'status': 'active',
      'image_name': 'coffee.png',
      'image_data': 'data:image/png;base64,aGVsbG8=',
    });
    expect(item.imageName, 'coffee.png');
    expect(item.imageBytes, [104, 101, 108, 108, 111]);
  });

  test('reads a migration-free price from product details', () {
    final item = BackendTestItem.fromJson({
      'id': 8,
      'title': 'Iced latte',
      'description': r'$4.50 · Iced · 16 oz',
      'status': 'active',
      'created_at': '2026-07-26T10:30:00Z',
    });

    expect(item.productPrice, 4.5);
  });

  test('rejects incomplete backend records', () {
    expect(
      () => BackendTestItem.fromJson({'id': 7}),
      throwsFormatException,
    );
  });
}
