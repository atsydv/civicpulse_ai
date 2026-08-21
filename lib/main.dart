import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import './core/services/app_data_service.dart';
import './theme/app_theme.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clear cached users so new seed citizens appear on fresh install
  final prefs = await SharedPreferences.getInstance();
  // Reset users to pick up new seed citizens (only if version changed)
  const int dataVersion = 2;
  final storedVersion = prefs.getInt('data_version') ?? 0;
  if (storedVersion < dataVersion) {
    await prefs.remove('users');
    await prefs.remove('tickets');
    await prefs.setInt('data_version', dataVersion);
  }

  await AppDataService.instance.init();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'CivicPulse AI',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          routerConfig: appRouter,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(1.0)),
              child: child!,
            );
          },
        );
      },
    );
  }
}
