import 'package:shared_preferences/shared_preferences.dart';
import '../error/failure.dart';

class AuthHeaders {
  static Future<Map<String, String>> json() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null || token.isEmpty) {
      throw Failure('Not authorized, no token. Please log in again.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
