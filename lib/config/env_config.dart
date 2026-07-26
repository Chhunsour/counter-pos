import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  const EnvConfig({required this.backendUri, required this.anonKey});

  final Uri backendUri;
  final String anonKey;

  factory EnvConfig.fromDotEnv() {
    final rawUrl = dotenv.env['BACKEND_URL']?.trim() ?? '';
    final anonKey = dotenv.env['ANON_KEY']?.trim() ?? '';

    if (rawUrl.isEmpty || rawUrl == 'https://your-backend-url.com') {
      throw const FormatException(
        'BACKEND_URL is missing. Add it to the project .env file.',
      );
    }
    if (anonKey.isEmpty || anonKey == 'your-anon-key') {
      throw const FormatException(
        'ANON_KEY is missing. Add it to the project .env file.',
      );
    }

    final uri = Uri.tryParse(rawUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      throw const FormatException('BACKEND_URL must be a valid absolute URL.');
    }
    if (uri.scheme != 'https' && uri.scheme != 'http') {
      throw const FormatException('BACKEND_URL must use HTTP or HTTPS.');
    }

    return EnvConfig(
      backendUri: Uri.parse(rawUrl.replaceFirst(RegExp(r'/$'), '')),
      anonKey: anonKey,
    );
  }

  Uri get recordsUri => Uri.parse('$backendUri/rest/v1/backend_test_items');
  Uri get categoriesUri => Uri.parse('$backendUri/rest/v1/pos_categories');

  String get maskedKey {
    if (anonKey.length < 8) return '••••';
    return '${anonKey.substring(0, 4)}…${anonKey.substring(anonKey.length - 4)}';
  }
}
