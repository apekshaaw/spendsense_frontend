import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'app/app.dart';
import 'features/profile/presentation/view_model/profile_view_model.dart';
import 'features/profile/presentation/view_model/profile_event.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => ProfileViewModel()..add(LoadProfile()),
        ),
      ],
      child: const SpendSenseApp(),
    ),
  );
}
