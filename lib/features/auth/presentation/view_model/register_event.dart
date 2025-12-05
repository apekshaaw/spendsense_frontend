abstract class RegisterEvent {}

class RegisterSubmitted extends RegisterEvent {
  final String name;
  final String email;
  final String password;
  final String confirmPassword;

  RegisterSubmitted({
    required this.name,
    required this.email,
    required this.password,
    required this.confirmPassword,
  });
}

class RegisterReset extends RegisterEvent {}
