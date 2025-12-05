import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:spendsense_frontend/features/splash/presentation/view_model/splash_event.dart';
import 'package:spendsense_frontend/features/splash/presentation/view_model/splash_state.dart';
import 'package:spendsense_frontend/features/splash/presentation/view_model/splash_view_model.dart';

import '../../../../app/routes.dart';
import '../../../../core/constants/app_colors.dart';

/// Public widget used in routes.dart
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SplashViewModel()..add(SplashStarted()),
      child: const _SplashBody(),
    );
  }
}

/// Internal body widget for the gradient + logo
class _SplashBody extends StatelessWidget {
  const _SplashBody();

  @override
  Widget build(BuildContext context) {
    return BlocListener<SplashViewModel, SplashState>(
      listener: (context, state) {
        if (state.status == SplashStatus.goToWelcome) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
        } else if (state.status == SplashStatus.goToDashboard) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        }
      },
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.gradientTop, AppColors.gradientBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
            child: Image.asset(
              'assets/images/spendsense_logo_white.png',
              height: 140,
            ),
          ),
        ),
      ),
    );
  }
}
