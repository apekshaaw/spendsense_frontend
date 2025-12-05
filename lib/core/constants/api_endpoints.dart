class ApiEndpoints {
  ApiEndpoints._();

  // ANDROID EMULATOR (Node running on your laptop on port 5000)
  static const String baseUrl = 'http://10.0.2.2:5000';

  static const String login = '$baseUrl/api/auth/login';
  static const String register = '$baseUrl/api/auth/signup';
}
