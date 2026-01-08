// lib/features/profile/data/models/profile_model.dart
class ProfileModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String avatarUrl; // base64 or url
  final bool darkMode;

  ProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.avatarUrl,
    required this.darkMode,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json["_id"] ?? json["id"] ?? "").toString(),
      name: (json["name"] ?? "").toString(),
      email: (json["email"] ?? "").toString(),
      phone: (json["phone"] ?? "").toString(),
      avatarUrl: (json["avatarUrl"] ?? "").toString(),
      darkMode: (json["darkMode"] ?? false) == true,
    );
  }

  Map<String, dynamic> toJson() => {
        "_id": id,
        "name": name,
        "email": email,
        "phone": phone,
        "avatarUrl": avatarUrl,
        "darkMode": darkMode,
      };

  ProfileModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    bool? darkMode,
  }) {
    return ProfileModel(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      darkMode: darkMode ?? this.darkMode,
    );
  }
}
