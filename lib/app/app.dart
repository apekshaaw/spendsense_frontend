import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/app_strings.dart';
import '../core/navigation/app_navigator.dart'; // ✅ ADD THIS
import 'routes.dart';

import '../features/profile/presentation/view_model/profile_view_model.dart';
import '../features/profile/presentation/view_model/profile_state.dart';

class SpendSenseApp extends StatelessWidget {
  const SpendSenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileViewModel, ProfileState>(
      builder: (context, state) {
        final darkMode = state.profile?.darkMode ?? false;

        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,

          navigatorKey: appNavigatorKey, // ✅ THIS IS THE MAIN FIX

          theme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.light,
            fontFamily: 'Inter',
            scaffoldBackgroundColor: AppColors.background,
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: Colors.black,
            ),
          ),

          darkTheme: ThemeData(
            useMaterial3: false,
            brightness: Brightness.dark,
            fontFamily: 'Inter',
            primaryColor: AppColors.primary,
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Brightness.dark,
            ),
            appBarTheme: const AppBarTheme(
              elevation: 0,
            ),
          ),

          themeMode: darkMode ? ThemeMode.dark : ThemeMode.light,

          initialRoute: AppRoutes.splash,
          onGenerateRoute: AppRoutes.onGenerateRoute,
        );
      },
    );
  }
}
