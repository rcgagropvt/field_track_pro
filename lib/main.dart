import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'core/services/tracking_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive for local storage
  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('offline_queue');

  // Initialize Supabase
  await Supabase.initialize(
    // ⚠️ REPLACE THESE WITH YOUR SUPABASE CREDENTIALS
    url: 'https://wruxzfvpnhzihmboggyu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndydXh6ZnZwbmh6aWhtYm9nZ3l1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjQ1NTQsImV4cCI6MjA5MTA0MDU1NH0.PZQEJTgm_kTFcZLUAyIlqkwIFApOc4FXkPBua4F-tbE',
  );
  await TrackingService.initialize(); // ← ONLY NEW LINE

  // Set system UI
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  runApp(const ProviderScope(child: FieldTrackProApp()));
}

class FieldTrackProApp extends ConsumerWidget {
  const FieldTrackProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'FieldTrack Pro',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
