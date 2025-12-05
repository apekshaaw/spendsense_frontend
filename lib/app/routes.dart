import 'package:flutter/material.dart';

import '../features/splash/presentation/view/splash_view.dart';
import '../features/auth/presentation/view/welcome_view.dart';
import '../features/auth/presentation/view/login_view.dart';
import '../features/auth/presentation/view/register_view.dart';
import '../features/home/presentation/view/home_view.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashView());
      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeView());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginView());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterView());
      case home:
        return MaterialPageRoute(builder: (_) => const HomeView());
      default:
        return MaterialPageRoute(builder: (_) => const SplashView());
    }
  }
}
