import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>? ?? json;

    return UserModel(
      id: userJson['id']?.toString() ?? userJson['_id']?.toString() ?? '',
      name: userJson['name'] ?? '',
      email: userJson['email'] ?? '',
      token: json['token'] ?? '',
    );
  }
}
