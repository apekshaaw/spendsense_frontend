class WantModel {
  final String id;
  final String name;
  final double price;
  final String? notes;
  final String status; // pending | purchased | skipped
  final DateTime? remindAt;
  final DateTime? createdAt;

  WantModel({
    required this.id,
    required this.name,
    required this.price,
    this.notes,
    required this.status,
    this.remindAt,
    this.createdAt,
  });

  factory WantModel.fromJson(Map<String, dynamic> json) {
    return WantModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      notes: json['notes']?.toString(),
      status: (json['status'] ?? 'pending').toString(),
      remindAt: json['remindAt'] != null
          ? DateTime.tryParse(json['remindAt'].toString())
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}
