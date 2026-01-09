import 'package:flutter/material.dart';

import 'package:spendsense_frontend/features/auth/presentation/view/forgot_password_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/login_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/register_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/reset_password_view.dart';
import 'package:spendsense_frontend/features/auth/presentation/view/welcome_view.dart';

import 'package:spendsense_frontend/features/home/presentation/view/add_goal_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/goal_details_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/home_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/needs_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/wants_view.dart';

import 'package:spendsense_frontend/features/home/presentation/view/all_needs_view.dart';
import 'package:spendsense_frontend/features/home/presentation/view/all_wants_view.dart';

import 'package:spendsense_frontend/features/profile/presentation/view/edit_profile_view.dart';
import 'package:spendsense_frontend/features/profile/presentation/view/profile_view.dart';
import 'package:spendsense_frontend/features/profile/presentation/view/settings_view.dart';
import 'package:spendsense_frontend/features/profile/presentation/view/change_password_view.dart';
import 'package:spendsense_frontend/features/profile/presentation/view/delete_account_view.dart';

import 'package:spendsense_frontend/features/splash/presentation/view/splash_view.dart';
import 'package:spendsense_frontend/features/stats/presentation/view/goal_progress_view.dart';
import 'package:spendsense_frontend/features/stats/presentation/view/stats_view.dart';

import '../features/alerts/presentation/view/alerts_view.dart';

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
  static const String goalProgress = '/goal-progress';

  // stats + alerts
  static const String stats = '/stats';
  static const String alerts = '/alerts';

  // ✅ view-all routes
  static const String allWants = '/all-wants';
  static const String allNeeds = '/all-needs';

  // profile
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';

  // ✅ settings (inside profile feature)
  static const String settings = '/profile-settings';
  static const String changePassword = '/profile-change-password';
  static const String deleteAccount = '/profile-delete-account';

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

      // ── Stats ────────────────────────────────────────────────────────────
      case stats:
        return MaterialPageRoute(builder: (_) => const StatsView());

      case goalProgress:
        return MaterialPageRoute(builder: (_) => const GoalProgressView());

      // ✅ Alerts (NEW)
      case alerts:
        return MaterialPageRoute(builder: (_) => const AlertsView());

      // ✅ view-all
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

      // ── Profile Settings ─────────────────────────────────────────────────
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsView());

      case AppRoutes.changePassword:
        return MaterialPageRoute(builder: (_) => const ChangePasswordView());

      case AppRoutes.deleteAccount:
        return MaterialPageRoute(builder: (_) => const DeleteAccountView());

      default:
        return MaterialPageRoute(builder: (_) => const SplashView());
    }
  }
}
