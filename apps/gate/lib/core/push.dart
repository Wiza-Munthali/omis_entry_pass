import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'env.dart';

/// Push notifications for approvers (new and escalated requests).
abstract class PushService {
  /// Asks permission, reports the device token (now and when it rotates) and calls
  /// [onOpen] with a request id when a notification is tapped.
  Future<void> start({
    required void Function(String token) onToken,
    required void Function(String passId) onOpen,
  });
  Future<void> stop();
}

/// Used when Firebase is not configured: everything else works, without push.
class NoPushService implements PushService {
  @override
  Future<void> start({
    required void Function(String token) onToken,
    required void Function(String passId) onOpen,
  }) async {}

  @override
  Future<void> stop() async {}
}

class FirebasePushService implements PushService {
  final _local = FlutterLocalNotificationsPlugin();
  final _subs = <StreamSubscription<Object?>>[];
  bool _initialised = false;

  static const _channel = AndroidNotificationChannel(
    'approvals',
    'Visitor requests',
    description: 'New and waiting visitor requests',
    importance: Importance.high,
  );

  Future<void> _init(void Function(String passId) onOpen) async {
    if (_initialised) return;
    await Firebase.initializeApp(
      options: FirebaseOptions(
        apiKey: Env.firebaseApiKey,
        appId: defaultTargetPlatform == TargetPlatform.iOS
            ? Env.firebaseIosAppId
            : Env.firebaseAndroidAppId,
        messagingSenderId: Env.firebaseMessagingSenderId,
        projectId: Env.firebaseProjectId,
      ),
    );
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
      onDidReceiveNotificationResponse: (r) {
        if (r.payload != null && r.payload!.isNotEmpty) onOpen(r.payload!);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
    // iOS shows notifications itself while the app is open.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(alert: true, sound: true);
    _initialised = true;
  }

  @override
  Future<void> start({
    required void Function(String token) onToken,
    required void Function(String passId) onOpen,
  }) async {
    try {
      await _init(onOpen);
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();

      // onRegistered delivers the device token now and again whenever it rotates.
      _subs.add(messaging.onRegistered.listen(onToken));
      await messaging.register();

      // Android does not show notifications while the app is open, so show them here.
      _subs.add(
        FirebaseMessaging.onMessage.listen((m) {
          final n = m.notification;
          if (n == null || defaultTargetPlatform != TargetPlatform.android) {
            return;
          }
          _local.show(
            id: m.hashCode,
            title: n.title,
            body: n.body,
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _channel.id,
                _channel.name,
                channelDescription: _channel.description,
                importance: Importance.high,
                priority: Priority.high,
              ),
            ),
            payload: m.data['pass_id'] as String?,
          );
        }),
      );

      void open(RemoteMessage m) {
        final id = m.data['pass_id'];
        if (id is String && id.isNotEmpty) onOpen(id);
      }

      _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(open));
      final initial = await messaging.getInitialMessage();
      if (initial != null) open(initial);
    } catch (e) {
      debugPrint('Push not available: $e');
    }
  }

  @override
  Future<void> stop() async {
    for (final s in _subs) {
      await s.cancel();
    }
    _subs.clear();
    if (_initialised) {
      try {
        await FirebaseMessaging.instance.unregister();
      } catch (_) {}
    }
  }
}
