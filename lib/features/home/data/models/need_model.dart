class NeedModel {
  final String id;
  final String name;
  final double price;
  final String? notes;
  final DateTime? createdAt;

  NeedModel({
    required this.id,
    required this.name,
    required this.price,
    this.notes,
    this.createdAt,
  });

  factory NeedModel.fromJson(Map<String, dynamic> json) {
    return NeedModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      notes: json['notes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
