class ApiEndpoints {
  static const String baseUrl = "http://10.0.2.2:5001"; // emulator

  static const String login = "$baseUrl/api/auth/login";
  static const String register = "$baseUrl/api/auth/register";

  static const String wants = "$baseUrl/api/wants";
  static const String goals = "$baseUrl/api/goals";
  static const String needs = "$baseUrl/api/needs";
}
