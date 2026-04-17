import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';
import 'core/services/tracking_service.dart';
import 'core/services/offline_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  await Hive.openBox('settings');
  await Hive.openBox('offline_queue');

  await Supabase.initialize(
    url: 'https://wruxzfvpnhzihmboggyu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndydXh6ZnZwbmh6aWhtYm9nZ3l1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjQ1NTQsImV4cCI6MjA5MTA0MDU1NH0.PZQEJTgm_kTFcZLUAyIlqkwIFApOc4FXkPBua4F-tbE',
  );

  await TrackingService.initialize();

  // Auto-sync on reconnection. connectivity_plus v5 emits List<ConnectivityResult>,
  // v4 emits a single ConnectivityResult — handle both to avoid runtime cast errors.
  Connectivity().onConnectivityChanged.listen((dynamic result) async {
    final bool isOnline;
    if (result is List) {
      isOnline = (result as List).any((r) => r != ConnectivityResult.none);
    } else {
      isOnline = result != ConnectivityResult.none;
    }
    if (isOnline) {
      final pending = await OfflineQueueService.pendingCount();
      if (pending > 0) {
        debugPrint('Connection restored — syncing $pending offline record(s)...');
        final r = await OfflineQueueService.sync();
        debugPrint(
            'Auto-sync: ${r.synced} synced, ${r.failed} failed, ${r.conflicts} conflicts');
      }
    }
  });

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  runApp(const ProviderScope(child: FieldTrackProApp()));
}

class FieldTrackProApp extends ConsumerWidget {
  const FieldTrackProApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Vartmaan Pulse',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      initialRoute: AppRouter.splash,
      onGenerateRoute: AppRouter.generateRoute,
    );
  }
}
