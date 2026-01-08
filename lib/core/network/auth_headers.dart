import '../error/failure.dart';
import 'token_storage.dart';

class AuthHeaders {
  static Future<Map<String, String>> json() async {
    final token = await TokenStorage.read();

    if (token == null || token.isEmpty) {
      throw Failure('Not authorized, no token. Please log in again.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
