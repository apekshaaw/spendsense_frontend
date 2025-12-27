class GoalEntryModel {
  final double amount;
  final String type; // saved | spent
  final String? note;
  final DateTime? createdAt;

  GoalEntryModel({
    required this.amount,
    required this.type,
    this.note,
    this.createdAt,
  });

  factory GoalEntryModel.fromJson(Map<String, dynamic> json) {
    return GoalEntryModel(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      type: (json['type'] ?? '').toString(),
      note: json['note']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
    );
  }
}

class GoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final double currentAmount;
  final String? notes;
  final List<GoalEntryModel> entries;

  GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.currentAmount,
    this.notes,
    required this.entries,
  });

  factory GoalModel.fromJson(Map<String, dynamic> json) {
    final entriesRaw = (json['entries'] as List?) ?? [];
    return GoalModel(
      id: (json['_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
      currentAmount: (json['currentAmount'] as num?)?.toDouble() ?? 0,
      notes: json['notes']?.toString(),
      entries: entriesRaw
          .whereType<Map>()
          .map((e) => GoalEntryModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}
