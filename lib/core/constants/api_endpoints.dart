// lib/core/constants/api_endpoints.dart

class ApiEndpoints {
  static const String baseUrl = "http://10.0.2.2:5001"; // emulator

  // auth
  static const String login = "$baseUrl/api/auth/login";
  static const String register = "$baseUrl/api/auth/signup";
  static const String resetPassword = "$baseUrl/api/auth/reset-password";

  static const String profile = "$baseUrl/api/auth/me";
  static const String updateProfile = "$baseUrl/api/auth/me";

  // ✅ settings
  static const String verifyPassword = "$baseUrl/api/auth/verify-password";
  static const String changePassword = "$baseUrl/api/auth/change-password";
  static const String deleteAccount = "$baseUrl/api/auth/delete-account";

  // resources
  static const String wants = "$baseUrl/api/wants";
  static const String goals = "$baseUrl/api/goals";
  static const String needs = "$baseUrl/api/needs";
}
