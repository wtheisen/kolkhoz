import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> kolkhozFirebaseBackgroundHandler(RemoteMessage message) async {
  await initializeKolkhozFirebase();
}

Future<bool> initializeKolkhozFirebase() async {
  if (!Platform.isIOS) {
    return false;
  }
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }
    FirebaseMessaging.onBackgroundMessage(kolkhozFirebaseBackgroundHandler);
    return true;
  } catch (_) {
    // Firebase is optional until the production plist is installed.
    return false;
  }
}

class KolkhozPushPayload {
  const KolkhozPushPayload({
    required this.type,
    this.sessionID,
    this.title,
    this.body,
  });

  final String type;
  final String? sessionID;
  final String? title;
  final String? body;

  factory KolkhozPushPayload.fromMessage(RemoteMessage message) {
    return KolkhozPushPayload(
      type: message.data['type'] ?? '',
      sessionID: message.data['sessionID'],
      title: message.notification?.title,
      body: message.notification?.body,
    );
  }
}

class KolkhozPushNotifications {
  KolkhozPushNotifications({
    required this.installationID,
    required this.registerInstallation,
    required this.deleteInstallation,
    required this.isSignedIn,
    required this.onForegroundMessage,
    required this.onOpenMessage,
  });

  final String installationID;
  final Future<void> Function({
    required String installationID,
    required String platform,
    required String token,
  })
  registerInstallation;
  final Future<void> Function(String installationID) deleteInstallation;
  final bool Function() isSignedIn;
  final void Function(KolkhozPushPayload payload) onForegroundMessage;
  final Future<void> Function(KolkhozPushPayload payload) onOpenMessage;

  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || !await initializeKolkhozFirebase()) {
      return;
    }
    _initialized = true;
    _foreground = FirebaseMessaging.onMessage.listen((message) {
      onForegroundMessage(KolkhozPushPayload.fromMessage(message));
    });
    _opened = FirebaseMessaging.onMessageOpenedApp.listen((message) {
      unawaited(onOpenMessage(KolkhozPushPayload.fromMessage(message)));
    });
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      unawaited(onOpenMessage(KolkhozPushPayload.fromMessage(initial)));
    }
    _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (isSignedIn()) {
        unawaited(_register(token));
      }
    });
  }

  Future<bool> requestPermissionAndRegister() async {
    await initialize();
    if (!_initialized || !isSignedIn()) {
      return false;
    }
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    String? apnsToken;
    for (var attempt = 0; attempt < 10 && apnsToken == null; attempt++) {
      apnsToken = await FirebaseMessaging.instance.getAPNSToken();
      if (apnsToken == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }
    if (apnsToken == null) {
      return false;
    }
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    await _register(token);
    return true;
  }

  Future<void> _register(String token) async {
    try {
      await registerInstallation(
        installationID: installationID,
        platform: 'ios',
        token: token,
      );
    } catch (_) {
      // Token registration is best effort and will retry on next sign-in/refresh.
    }
  }

  Future<void> unregister() async {
    if (!_initialized) {
      return;
    }
    try {
      await deleteInstallation(installationID);
    } catch (_) {
      // Sign-out must not be blocked by an unavailable notification service.
    }
  }

  Future<void> dispose() async {
    await _tokenRefresh?.cancel();
    await _foreground?.cancel();
    await _opened?.cancel();
  }
}
