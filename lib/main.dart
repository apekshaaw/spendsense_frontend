import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'app/app.dart';
import 'core/notifications/local_notifications_service.dart';
import 'features/profile/presentation/view_model/profile_event.dart';
import 'features/profile/presentation/view_model/profile_view_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LocalNotificationsService.init();

  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ProfileViewModel()..add(LoadProfile())),
      ],
      child: const SpendSenseApp(),
    ),
  );

  WidgetsBinding.instance.addPostFrameCallback((_) {
    LocalNotificationsService.showPendingPopupIfAny();
  });
}
