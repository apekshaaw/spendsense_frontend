// lib/app/routes.dart
import 'package:flutter/material.dart';

// ── Auth views ──────────────────────────────────────────────────────────────
import 'package:spendsense_frontend/features/auth/presentation/view/forgot_password_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/login_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/register_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/reset_password_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/welcome_view.dart';

// ── Home (wants / needs / goals) ───────────────────────────────────────────
import 'package:spendsense_frontend/features/home/presentation/view/add_goal_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/goal_details_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/home_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/needs_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/wants_view.dart';

// ✅ NEW: view-all
import 'package:spendsense_frontend/features/home/presentation/view/all_needs_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/all_wants_view.dart';

// ── Profile ────────────────────────────────────────────────────────────────
import 'package:spendsense_frontend/features/profile/presentation/view/edit_profile_view.dart';
import 'package:spendsense_frontend/features/profile/presentation/view/profile_view.dart';

// ── Splash ─────────────────────────────────────────────────────────────────
import 'package:spendsense_frontend/features/splash/presentation/view/splash_view.dart';

class AppRoutes {
  // core
  static const String splash = '/';
  static const String welcome = '/welcome';
  static const String login = '/login';
  static const String register = '/register';

  // auth / password
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';

  // home
  static const String home = '/home';
  static const String wants = '/wants';
  static const String needs = '/needs';
  static const String addGoal = '/add-goal';
  static const String goalDetails = '/goal-details';

  // ✅ new view-all routes
  static const String allWants = '/all-wants';
  static const String allNeeds = '/all-needs';

  // profile
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ── Core ──────────────────────────────────────────────────────────────
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashView());

      case welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeView());

      case login:
        return MaterialPageRoute(builder: (_) => const LoginView());

      case register:
        return MaterialPageRoute(builder: (_) => const RegisterView());

      // ── Auth / password ──────────────────────────────────────────────────
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordView());

      case resetPassword:
        final email = settings.arguments as String? ?? '';
        return MaterialPageRoute(
          builder: (_) => ResetPasswordView(email: email),
        );

      // ── Home ─────────────────────────────────────────────────────────────
      case home:
        return MaterialPageRoute(builder: (_) => const HomeView());

      case wants:
        return MaterialPageRoute(builder: (_) => const WantsView());

      case needs:
        return MaterialPageRoute(builder: (_) => const NeedsView());

      case addGoal:
        return MaterialPageRoute(builder: (_) => const AddGoalView());

      // ✅ new view-all
      case allWants:
        return MaterialPageRoute(builder: (_) => const AllWantsView());

      case allNeeds:
        return MaterialPageRoute(builder: (_) => const AllNeedsView());

      case goalDetails:
        final args = settings.arguments as Map<String, dynamic>?;

        final String goalId = (args?['goalId'] ?? '').toString();
        final String name = (args?['name'] ?? '').toString();
        final double targetAmount =
            (args?['targetAmount'] as num?)?.toDouble() ?? 0;
        final double currentAmount =
            (args?['currentAmount'] as num?)?.toDouble() ?? 0;

        // ✅ include notes too
        final String? notes = args?['notes']?.toString();

        return MaterialPageRoute(
          builder: (_) => GoalDetailsView(
            goalId: goalId,
            name: name,
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            notes: notes,
          ),
        );

      // ── Profile ──────────────────────────────────────────────────────────
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileView());

      case editProfile:
        return MaterialPageRoute(builder: (_) => const EditProfileView());

      default:
        return MaterialPageRoute(builder: (_) => const SplashView());
    }
  }
}
