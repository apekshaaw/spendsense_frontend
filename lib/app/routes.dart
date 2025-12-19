import 'package:flutter/material.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/add_goal_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/needs_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/wants_view.dart';

import '../features/splash/presentation/view/splash_view.dart';
import '../features/auth/presentation/view/welcome_view.dart';
import '../features/auth/presentation/view/login_view.dart';
import '../features/auth/presentation/view/register_view.dart';
import '../features/auth/presentation/view/forgot_password_view.dart';
import '../features/auth/presentation/view/reset_password_view.dart';
import '../features/home/presentation/view/home_view.dart';

class AppRoutes {
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  static const String wants = '/wants';
  static const String needs = '/needs';
  static const String addGoal = '/add-goal';

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

      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordView());

      case resetPassword:
        final emailArg = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => ResetPasswordView(email: emailArg),
        );

      case wants:
        return MaterialPageRoute(builder: (_) => const WantsView());

      case needs:
        return MaterialPageRoute(builder: (_) => const NeedsView());

      case addGoal:
        return MaterialPageRoute(builder: (_) => const AddGoalView());

      default:
        return MaterialPageRoute(builder: (_) => const SplashView());
    }
  }
}
