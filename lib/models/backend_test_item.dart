import 'dart:convert';
import 'dart:typed_data';

class BackendTestItem {
  const BackendTestItem({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.createdAt,
    this.imageName,
    this.imageData,
  });

  final Object id;
  final String title;
  final String description;
  final String status;
  final DateTime createdAt;
  final String? imageName;
  final String? imageData;

  factory BackendTestItem.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final title = json['title'];
    final description = json['description'];
    final status = json['status'];
    final createdAt = json['created_at'];
    final imageName = json['image_name'];
    final imageData = json['image_data'];

    if (id == null ||
        title is! String ||
        description is! String ||
        status is! String ||
        createdAt is! String ||
        (imageName != null && imageName is! String) ||
        (imageData != null && imageData is! String)) {
      throw const FormatException(
        'A record has missing or invalid fields.',
      );
    }

    return BackendTestItem(
      id: id,
      title: title,
      description: description,
      status: status,
      createdAt: DateTime.parse(createdAt),
      imageName: imageName as String?,
      imageData: imageData as String?,
    );
  }

  Map<String, dynamic> toWriteJson() => {
        'title': title,
        'description': description,
        'status': status,
        'image_name': imageName,
        'image_data': imageData,
      };

  BackendTestItem copyWith({
    required String title,
    required String description,
    required String status,
    required String? imageName,
    required String? imageData,
  }) {
    return BackendTestItem(
      id: id,
      title: title,
      description: description,
      status: status,
      createdAt: createdAt,
      imageName: imageName,
      imageData: imageData,
    );
  }

  Uint8List? get imageBytes {
    final value = imageData;
    if (value == null || !value.startsWith('data:image/')) return null;
    final marker = value.indexOf(';base64,');
    if (marker < 0) return null;
    try {
      return base64Decode(value.substring(marker + 8));
    } on FormatException {
      return null;
    }
  }

  /// Temporary migration-free price convention: the first number in the
  /// description is the product price, e.g. "$4.50 · Iced coffee".
  double get productPrice {
    final match = RegExp(r'\d+(?:\.\d{1,2})?').firstMatch(description);
    return double.tryParse(match?.group(0) ?? '') ?? 0;
  }
}
