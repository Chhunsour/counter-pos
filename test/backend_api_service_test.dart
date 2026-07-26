import 'dart:convert';

import 'package:backend_test_dashboard/config/env_config.dart';
import 'package:backend_test_dashboard/services/backend_api_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final config = EnvConfig(
    backendUri: Uri.parse('https://example.test'),
    anonKey: 'test-anon-key',
  );

  test('keeps the custom gateway path in the records endpoint', () {
    final gatewayConfig = EnvConfig(
      backendUri: Uri.parse('https://example.test/api/gw/tmk_project'),
      anonKey: 'test-anon-key',
    );

    expect(
      gatewayConfig.recordsUri.toString(),
      'https://example.test/api/gw/tmk_project/rest/v1/backend_test_items',
    );
  });

  test('sends both API authorization headers', () async {
    final service = BackendApiService(
      config,
      client: MockClient((request) async {
        expect(request.headers['apikey'], config.anonKey);
        expect(request.headers['authorization'], 'Bearer ${config.anonKey}');
        return http.Response('[]', 200);
      }),
    );

    await service.fetchItems();
    service.close();
  });

  test('sends product image, barcode, and category data', () async {
    final service = BackendApiService(
      config,
      client: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'title': 'Coffee',
          'description': 'Large',
          'status': 'active',
          'image_name': 'coffee.png',
          'image_data': 'data:image/png;base64,aGVsbG8=',
          'barcode': '2345678901234',
          'category_id': 3,
        });
        return http.Response('', 201);
      }),
    );

    await service.createItem(
      title: 'Coffee',
      description: 'Large',
      status: 'active',
      imageName: 'coffee.png',
      imageData: 'data:image/png;base64,aGVsbG8=',
      barcode: '2345678901234',
      categoryId: 3,
    );
    service.close();
  });

  test('preserves status code and backend error message', () async {
    final service = BackendApiService(
      config,
      client: MockClient(
        (_) async => http.Response('{"message":"Invalid API key"}', 401),
      ),
    );

    expect(
      service.fetchItems(),
      throwsA(
        isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having((error) => error.message, 'message', 'Invalid API key')
            .having(
              (error) => error.type,
              'type',
              ApiErrorType.authorization,
            ),
      ),
    );
    service.close();
  });
}
