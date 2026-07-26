class PosCategory {
  const PosCategory({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final Object id;
  final String name;
  final DateTime createdAt;

  factory PosCategory.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final createdAt = json['created_at'];
    if (id == null || name is! String || createdAt is! String) {
      throw const FormatException('A category has missing or invalid fields.');
    }
    return PosCategory(
      id: id,
      name: name,
      createdAt: DateTime.parse(createdAt),
    );
  }
}
