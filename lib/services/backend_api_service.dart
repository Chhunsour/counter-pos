import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/env_config.dart';
import '../models/backend_test_item.dart';
import '../models/pos_category.dart';

enum ApiErrorType { network, timeout, authorization, api, json, server }

class ApiException implements Exception {
  const ApiException(
    this.message, {
    required this.type,
    this.statusCode,
    this.elapsed,
  });

  final String message;
  final ApiErrorType type;
  final int? statusCode;
  final Duration? elapsed;

  @override
  String toString() {
    final code = statusCode == null ? '' : 'HTTP $statusCode: ';
    return '$code$message';
  }
}

class ConnectionResult {
  const ConnectionResult({
    required this.statusCode,
    required this.elapsed,
    required this.message,
  });

  final int statusCode;
  final Duration elapsed;
  final String message;
}

class BackendApiService {
  BackendApiService(
    this.config, {
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final EnvConfig config;
  final http.Client _client;
  final Duration timeout;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'apikey': config.anonKey,
        'Authorization': 'Bearer ${config.anonKey}',
      };

  Future<ConnectionResult> testConnection() async {
    final uri = config.recordsUri.replace(
      queryParameters: {'select': 'id', 'limit': '1'},
    );
    final stopwatch = Stopwatch()..start();
    try {
      final response =
          await _request(() => _client.get(uri, headers: _headers));
      stopwatch.stop();
      _ensureSuccess(response, const {200});
      return ConnectionResult(
        statusCode: response.statusCode,
        elapsed: stopwatch.elapsed,
        message: 'Backend responded successfully.',
      );
    } on ApiException catch (error) {
      stopwatch.stop();
      throw ApiException(
        error.message,
        type: error.type,
        statusCode: error.statusCode,
        elapsed: stopwatch.elapsed,
      );
    }
  }

  Future<List<BackendTestItem>> fetchItems() async {
    final uri = config.recordsUri.replace(
      queryParameters: {'select': '*', 'order': 'created_at.desc'},
    );
    final response = await _request(() => _client.get(uri, headers: _headers));
    _ensureSuccess(response, const {200});

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Expected a JSON array.');
      }
      return decoded
          .map((value) => BackendTestItem.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
    } on FormatException catch (error) {
      throw ApiException(
        'Invalid JSON response: ${error.message}',
        type: ApiErrorType.json,
        statusCode: response.statusCode,
      );
    } on TypeError {
      throw ApiException(
        'Invalid JSON response: each record must be an object.',
        type: ApiErrorType.json,
        statusCode: response.statusCode,
      );
    }
  }

  Future<List<PosCategory>> fetchCategories() async {
    final uri = config.categoriesUri.replace(
      queryParameters: {'select': '*', 'order': 'name.asc'},
    );
    final response = await _request(() => _client.get(uri, headers: _headers));
    _ensureSuccess(response, const {200});

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Expected a JSON array.');
      }
      return decoded
          .map((value) => PosCategory.fromJson(
                Map<String, dynamic>.from(value as Map),
              ))
          .toList();
    } on FormatException catch (error) {
      throw ApiException(
        'Invalid category response: ${error.message}',
        type: ApiErrorType.json,
        statusCode: response.statusCode,
      );
    } on TypeError {
      throw ApiException(
        'Invalid category response: each category must be an object.',
        type: ApiErrorType.json,
        statusCode: response.statusCode,
      );
    }
  }

  Future<void> createItem({
    required String title,
    required String description,
    required String status,
    required String? imageName,
    required String? imageData,
    required String? barcode,
    required Object? categoryId,
  }) async {
    final response = await _request(
      () => _client.post(
        config.recordsUri,
        headers: {..._headers, 'Prefer': 'return=minimal'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'status': status,
          'image_name': imageName,
          'image_data': imageData,
          if (barcode != null) 'barcode': barcode,
          if (categoryId != null) 'category_id': categoryId,
        }),
      ),
    );
    _ensureSuccess(response, const {200, 201, 204});
  }

  Future<void> createCategory(String name) async {
    final response = await _request(
      () => _client.post(
        config.categoriesUri,
        headers: {..._headers, 'Prefer': 'return=minimal'},
        body: jsonEncode({'name': name}),
      ),
    );
    _ensureSuccess(response, const {200, 201, 204});
  }

  Future<void> updateItem(BackendTestItem item) async {
    final uri = config.recordsUri.replace(
      queryParameters: {'id': 'eq.${item.id}'},
    );
    final response = await _request(
      () => _client.patch(
        uri,
        headers: {..._headers, 'Prefer': 'return=minimal'},
        body: jsonEncode(item.toWriteJson()),
      ),
    );
    _ensureSuccess(response, const {200, 204});
  }

  Future<void> deleteItem(Object id) async {
    final uri = config.recordsUri.replace(
      queryParameters: {'id': 'eq.$id'},
    );
    final response =
        await _request(() => _client.delete(uri, headers: _headers));
    _ensureSuccess(response, const {200, 204});
  }

  Future<http.Response> _request(
    Future<http.Response> Function() send,
  ) async {
    _log('Requesting ${config.recordsUri} with key ${config.maskedKey}');
    try {
      final response = await send().timeout(timeout);
      _log('Response HTTP ${response.statusCode}');
      return response;
    } on TimeoutException {
      throw ApiException(
        'Request timed out after ${timeout.inSeconds} seconds.',
        type: ApiErrorType.timeout,
      );
    } on http.ClientException catch (error) {
      throw ApiException(
        'Network error: ${error.message}',
        type: ApiErrorType.network,
      );
    } catch (error) {
      throw ApiException(
        'Network error: $error',
        type: ApiErrorType.network,
      );
    }
  }

  void _ensureSuccess(http.Response response, Set<int> acceptedCodes) {
    if (acceptedCodes.contains(response.statusCode)) return;

    final message = _backendMessage(response.body);
    final type = switch (response.statusCode) {
      401 || 403 => ApiErrorType.authorization,
      >= 500 => ApiErrorType.server,
      _ => ApiErrorType.api,
    };
    throw ApiException(
      message,
      type: type,
      statusCode: response.statusCode,
    );
  }

  String _backendMessage(String body) {
    if (body.trim().isEmpty) return 'The backend returned an empty error.';
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final parts = [
          decoded['message'],
          decoded['error_description'],
          decoded['details'],
          decoded['hint'],
          decoded['code'],
        ]
            .whereType<Object>()
            .map((value) => value.toString())
            .where((v) => v.isNotEmpty)
            .join(
              ' · ',
            );
        if (parts.isNotEmpty) return parts;
      }
    } on FormatException {
      // The exact plain-text response is more useful than hiding it.
    }
    return body;
  }

  void _log(String message) {
    if (kDebugMode) debugPrint('[Backend API] $message');
  }

  void close() => _client.close();
}
