/// Out-of-app notifications WITHOUT Firebase.
///
/// A `workmanager` periodic task wakes roughly every 15 minutes, asks the
/// backend how many notifications are unread, and raises a local notification
/// through `flutter_local_notifications` when that number has grown since the
/// last check. To the user it behaves like a push; mechanically it is a poll,
/// so there is no FCM project, no server key and no cloud configuration.
///
/// Trade-offs worth stating in the report:
///   * Latency is bounded by the poll interval — Android enforces a 15 minute
///     floor on periodic work, so a notification can lag the event by that much.
///   * Doze and battery optimisation can defer the task further.
///   * It only runs while the user is signed in; the JWT is read from storage,
///     so a signed-out device polls nothing.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'transport_api_client.dart';

/// Unique name for the registered periodic task.
const String kUnreadPollTask = 'carthage.unreadNotificationPoll';

/// Android's minimum periodic interval. Requesting less is silently clamped.
const Duration kPollInterval = Duration(minutes: 15);

const String _channelId = 'carthage_transfer';
const String _channelName = 'Carthage Transfer';
const String _channelDescription = 'Booking updates and account activity.';

/// SharedPreferences keys. The token key mirrors AuthService — the background
/// isolate has no access to that singleton's memory, so it re-reads storage.
const String _prefsTokenKey = 'auth_token';
const String _prefsLastSeenKey = 'notif_last_seen_count';

const int _notificationId = 1001;

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  /// Routes a notification tap. Set by main() so the service stays free of
  /// navigation concerns.
  static void Function()? onOpenNotifications;

  /// Prepares the plugin and registers the background poll.
  ///
  /// Safe to call more than once. Never throws: notifications are a nicety,
  /// and a device that refuses them must not stop the app from starting.
  Future<void> init() async {
    if (_ready) return;
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwinInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: darwinInit),
        onDidReceiveNotificationResponse: (_) => onOpenNotifications?.call(),
      );

      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.high,
          ));

      await Workmanager().initialize(callbackDispatcher);
      _ready = true;
    } catch (e) {
      debugPrint('[notifications] init failed: $e');
    }
  }

  /// Starts the periodic poll. Call once the user is signed in — polling
  /// without a token just burns wakeups.
  Future<void> start() async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await Workmanager().registerPeriodicTask(
        kUnreadPollTask,
        kUnreadPollTask,
        frequency: kPollInterval,
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    } catch (e) {
      debugPrint('[notifications] could not register poll: $e');
    }
  }

  /// Asks the OS for permission to post notifications.
  ///
  /// Android 13+ requires POST_NOTIFICATIONS at runtime. Call this from the
  /// notifications screen rather than at cold start, so the prompt has context.
  Future<bool> requestPermission() async {
    if (!_ready) await init();
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, badge: true) ?? false;
      }
    } catch (e) {
      debugPrint('[notifications] permission request failed: $e');
    }
    return false;
  }

  /// Stops polling and clears the baseline. Call on sign-out so a logged-out
  /// device stays quiet and the next user does not inherit a stale count.
  Future<void> stop() async {
    try {
      await Workmanager().cancelByUniqueName(kUnreadPollTask);
      await _plugin.cancel(_notificationId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsLastSeenKey);
    } catch (e) {
      debugPrint('[notifications] stop failed: $e');
    }
  }

  /// Raises a notification immediately — used by the background task, and
  /// available for testing the channel without waiting for a poll.
  Future<void> show({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_ready) await init();
    try {
      await _plugin.show(
        _notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        payload: payload,
      );
    } catch (e) {
      debugPrint('[notifications] show failed: $e');
    }
  }
}

/// Entry point Workmanager invokes in a background isolate.
///
/// A background isolate shares no state with the UI isolate, so everything it
/// needs — the JWT, the last-seen count, an HTTP client, its own plugin
/// instance — is re-created here from storage.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task != kUnreadPollTask) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_prefsTokenKey);
      // Signed out — nothing to poll for. Returning true keeps the task
      // scheduled so it resumes working after the next sign-in.
      if (token == null || token.isEmpty) return true;

      final unread = await _fetchUnreadCount(token);
      if (unread == null) return false; // network failure — let it retry

      final lastSeen = prefs.getInt(_prefsLastSeenKey) ?? 0;
      // Only announce growth. Without this the same backlog would be
      // re-announced every 15 minutes.
      if (unread > lastSeen) {
        await _showFromBackground(unread);
      }
      await prefs.setInt(_prefsLastSeenKey, unread);
      return true;
    } catch (e) {
      debugPrint('[notifications] poll failed: $e');
      return false;
    }
  });
}

Future<int?> _fetchUnreadCount(String token) async {
  try {
    final uri = Uri.parse(
        '${TransportApiClient.defaultBaseUrl}/notifications/unread-count');
    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) return null;
    final body = jsonDecode(res.body);
    return (body is Map && body['unread'] is num)
        ? (body['unread'] as num).toInt()
        : null;
  } catch (_) {
    return null;
  }
}

Future<void> _showFromBackground(int count) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(const InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    ),
  ));
  await plugin.show(
    _notificationId,
    'Carthage Transfer',
    count == 1 ? '1 new notification' : '$count new notifications',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    ),
  );
}
