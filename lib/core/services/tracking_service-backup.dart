import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart'; // ← removed duplicate
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';

class TrackingService {
  static const notificationChannelId = 'fieldtrack_tracking';
  static const notificationId = 888;

  static Future<void> initialize() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'FieldTrack Location Service',
      description: 'Tracks your location while on field duty',
      importance: Importance.low,
    );

    final notificationsPlugin = FlutterLocalNotificationsPlugin();
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onServiceStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'FieldTrack Pro',
        initialNotificationContent: 'Location tracking active',
        foregroundServiceNotificationId: notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(autoStart: false),
    );
  }

  static Future<void> startTracking() async {
    final service = FlutterBackgroundService();
    await service.startService();
  }

  static Future<void> stopTracking() async {
    final service = FlutterBackgroundService();
    service.invoke('stop');
  }

  // ← FIXED: was always returning false
  static Future<bool> isRunning() async {
    return await FlutterBackgroundService().isRunning();
  }
}

// Runs in a SEPARATE ISOLATE — no BuildContext, no UI, no SupabaseService
@pragma('vm:entry-point')
void _onServiceStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // Initialize Hive before using it in this isolate
  await Hive.initFlutter(); // ← ADDED

  // Initialize Supabase in this isolate separately
  await Supabase.initialize(
    url: 'https://wruxzfvpnhzihmboggyu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndydXh6ZnZwbmh6aWhtYm9nZ3l1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU0NjQ1NTQsImV4cCI6MjA5MTA0MDU1NH0.PZQEJTgm_kTFcZLUAyIlqkwIFApOc4FXkPBua4F-tbE',
  );

  final supabase = Supabase.instance.client;
  DateTime? lastSave; // ← RENAMED: no leading _

  service.on('stop').listen((_) {
    service.stopSelf();
  });

  // Update notification every 30 seconds
  Timer.periodic(const Duration(seconds: 30), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        final now = DateTime.now();
        service.setForegroundNotificationInfo(
          title: 'FieldTrack Pro — Active',
          content:
              'Tracking: ${now.hour}:${now.minute.toString().padLeft(2, '0')}',
        );
      }
    }
  });

  // GPS stream — throttled to once per 30s regardless of distanceFilter
  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 50,
    ),
  ).listen((position) async {
    final now = DateTime.now();
    if (lastSave != null && now.difference(lastSave!).inSeconds < 30) return;
    lastSave = now;

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      await supabase.from('location_tracks').insert({
        'user_id': user.id,
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,
        'speed': position.speed,
        'recorded_at': now.toIso8601String(),
      });
    } catch (e) {
      // Save to Hive for offline retry
      try {
        final box = await Hive.openBox('offline_queue');
        await box.add({
          'type': 'location',
          'lat': position.latitude,
          'lng': position.longitude,
          'timestamp': now.toIso8601String(),
        });
      } catch (_) {}
    }
  });
}
