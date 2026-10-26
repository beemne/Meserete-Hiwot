import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/providers.dart';
import 'local_notifications.dart';
import '../features/chat/chat_screens.dart' show activeChat;

/// Background handler: data/notification messages are displayed by the OS; nothing else to do.
@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {}

/// Firebase Cloud Messaging on the device. Server credentials never live in the app —
/// only google-services.json (client config). If Firebase is not configured the app keeps
/// working with in-app notifications only.
class PushService {
  PushService(this._ref);
  final Ref _ref;
  bool available = false;
  String? _token;
  final _taps = StreamController<Map<String, dynamic>>.broadcast();
  final _received = StreamController<RemoteMessage>.broadcast();
  StreamSubscription<String>? _refreshSub;

  /// Deep-link data of tapped push notifications.
  Stream<Map<String, dynamic>> get taps => _taps.stream;

  /// Messages received while the app is in the foreground.
  Stream<RemoteMessage> get received => _received.stream;

  Future<void> init() async {
    try {
      await Firebase.initializeApp();
      available = true;
    } catch (e) {
      debugPrint('Firebase not configured — push disabled ($e)');
      return;
    }
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);
    FirebaseMessaging.onMessage.listen((m) {
      _received.add(m);
      final n = m.notification;
      // A chat message for the conversation already on screen: it appears there by itself.
      final chatKey = m.data['type'] == 'chat' ? '${m.data['department_id']}|${m.data['thread']}' : null;
      if (n != null && (chatKey == null || chatKey != activeChat.value)) {
        final channel = m.data['channel'] as String? ?? Channels.defaultId;
        final nid = int.tryParse('${m.data['notification_id'] ?? ''}');
        unawaited(_ref.read(localNotificationsProvider).show(
              id: m.messageId.hashCode & 0x3fffffff,
              title: n.title ?? '',
              body: n.body ?? '',
              channel: channel,
              payload: _payload(m.data),
              tag: nid == null ? null : LocalNotifications.messageTag(nid),
            ));
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((m) => _taps.add(m.data));
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) Future.delayed(const Duration(milliseconds: 600), () => _taps.add(initial.data));
  }

  static String _payload(Map<String, dynamic> d) =>
      'n:${d['notification_id'] ?? ''}|${d['entity_type'] ?? ''}:${d['entity_id'] ?? ''}';

  /// Register this device's token for the signed-in user (and on every refresh).
  Future<void> registerForUser() async {
    if (!available) return;
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      _token = await messaging.getToken();
      if (_token != null) await _ref.read(accountRepositoryProvider).registerFcmToken(_token!, Platform.isIOS ? 'ios' : 'android');
      await _refreshSub?.cancel();
      _refreshSub = messaging.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(_ref.read(accountRepositoryProvider).registerFcmToken(t, Platform.isIOS ? 'ios' : 'android').catchError((_) {}));
      });
    } catch (e) {
      debugPrint('FCM registration failed: $e');
    }
  }

  /// Called on sign-out: the token is invalidated server-side and deleted locally.
  Future<void> unregister() async {
    if (!available) return;
    await _refreshSub?.cancel();
    try {
      if (_token != null) await _ref.read(accountRepositoryProvider).removeFcmToken(_token!);
      await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    _token = null;
  }
}

final pushServiceProvider = Provider<PushService>((ref) => PushService(ref));
