import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Analytics service that sends events to Supabase analytics_events table.
/// Silently fails on all errors — analytics never crashes the app.
class AnalyticsService {
  static const String _appId = 'voice-pdf-extractor';
  static const int _batchSize = 10;
  static const Duration _flushInterval = Duration(seconds: 30);

  static bool _initialized = false;
  static String _sessionId = '';
  static String _deviceType = '';
  static String _osVersion = '';
  static String _appVersion = '';
  static String _currentScreen = 'home';
  static String _previousScreen = '';
  static DateTime _sessionStart = DateTime.now();

  static final List<Map<String, dynamic>> _eventQueue = [];
  static Timer? _flushTimer;

  /// Initialize analytics — call once at app startup
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      _sessionId = _generateUuid();
      _sessionStart = DateTime.now();
      await _loadDeviceInfo();
      _startFlushTimer();
      _initialized = true;
    } catch (e) {
      debugPrint('Analytics init error: $e');
    }
  }

  /// UUID v4 generator (avoids extra dependency)
  static String _generateUuid() {
    final rng = Random();
    final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<void> _loadDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final packageInfo = await PackageInfo.fromPlatform();
      _appVersion = packageInfo.version;

      if (Platform.isIOS) {
        final ios = await deviceInfo.iosInfo;
        _deviceType = ios.utsname.machine;
        _osVersion = 'iOS ${ios.systemVersion}';
      } else if (Platform.isAndroid) {
        final android = await deviceInfo.androidInfo;
        _deviceType = '${android.manufacturer} ${android.model}';
        _osVersion = 'Android ${android.version.release}';
      }
    } catch (e) {
      debugPrint('Device info error: $e');
      _deviceType = 'unknown';
      _osVersion = 'unknown';
      _appVersion = '1.0.0';
    }
  }

  static void _startFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => flush());
  }

  /// Set current screen name for auto-tagging events
  static void setScreen(String screenName) {
    _previousScreen = _currentScreen;
    _currentScreen = screenName;
  }

  /// Get session duration in seconds
  static int get sessionDurationSeconds =>
      DateTime.now().difference(_sessionStart).inSeconds;

  /// Start a new session (e.g., after 30+ min inactive)
  static void startNewSession() {
    _sessionId = _generateUuid();
    _sessionStart = DateTime.now();
  }

  // ── Core tracking method ──────────────────────────────────────

  /// Track an event. Silently fails on errors.
  static void trackEvent(String eventName, {Map<String, dynamic>? metadata}) {
    if (!_initialized) return;

    try {
      String? userId;
      try {
        userId = Supabase.instance.client.auth.currentUser?.id;
      } catch (_) {}

      final event = {
        'app_id': _appId,
        'event_name': eventName,
        'user_id': userId,
        'session_id': _sessionId,
        'device_type': _deviceType,
        'os_version': _osVersion,
        'app_version': _appVersion,
        'screen_name': _currentScreen,
        'metadata': metadata ?? {},
      };

      _eventQueue.add(event);

      if (_eventQueue.length >= _batchSize) {
        flush();
      }
    } catch (e) {
      debugPrint('Analytics trackEvent error: $e');
    }
  }

  /// Flush queued events to Supabase
  static Future<void> flush() async {
    if (_eventQueue.isEmpty) return;

    final batch = List<Map<String, dynamic>>.from(_eventQueue);
    _eventQueue.clear();

    try {
      await Supabase.instance.client
          .from('analytics_events')
          .insert(batch);
    } catch (e) {
      debugPrint('Analytics flush error: $e');
      // Don't re-queue on failure — drop silently
    }
  }

  /// Dispose — flush remaining events
  static Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }

  // ── Convenience methods (preserving existing API) ─────────────

  static void trackPdfOpened({required int pageCount}) {
    trackEvent('pdf_opened', metadata: {'page_count': pageCount});
  }

  static void trackPagesSelected({
    required int selectedCount,
    required int totalPages,
  }) {
    trackEvent('pages_selected', metadata: {
      'selected_count': selectedCount,
      'total_pages': totalPages,
      'selection_ratio': totalPages > 0 ? selectedCount / totalPages : 0,
    });
  }

  static void trackExtractionCompleted({required int pageCount}) {
    trackEvent('feature_used', metadata: {
      'feature_name': 'extraction',
      'page_count': pageCount,
    });
  }

  static void trackPaywallShown({required String reason}) {
    trackEvent('paywall_viewed', metadata: {'source': reason});
  }

  static void trackShare() {
    trackEvent('button_tapped', metadata: {
      'button_id': 'share_pdf',
      'screen_name': _currentScreen,
    });
  }

  static void trackSaveToFiles() {
    trackEvent('button_tapped', metadata: {
      'button_id': 'save_to_files',
      'screen_name': _currentScreen,
    });
  }

  static void trackVoiceInputUsed({required int pagesSelected}) {
    trackEvent('feature_used', metadata: {
      'feature_name': 'voice_input',
      'pages_selected': pagesSelected,
    });
  }

  static void trackRangeDialogUsed({required int pagesSelected}) {
    trackEvent('feature_used', metadata: {
      'feature_name': 'range_dialog',
      'pages_selected': pagesSelected,
    });
  }

  static void trackPurchaseInitiated() {
    trackEvent('purchase_started', metadata: {
      'source': _currentScreen,
    });
  }

  static void trackPurchaseCompleted() {
    trackEvent('purchase_completed');
  }

  static void trackRestorePurchases({required bool success}) {
    trackEvent('feature_used', metadata: {
      'feature_name': 'restore_purchases',
      'success': success,
    });
  }

  static void trackScreenViewed(String screenName) {
    setScreen(screenName);
    trackEvent('screen_viewed', metadata: {
      'screen_name': screenName,
      'previous_screen': _previousScreen,
    });
  }

  static void trackErrorDisplayed({
    required String errorType,
    required String context,
  }) {
    trackEvent('error_displayed', metadata: {
      'error_type': errorType,
      'context': context,
    });
  }

  static void trackButtonTapped({
    required String buttonId,
    String? screenName,
  }) {
    trackEvent('button_tapped', metadata: {
      'button_id': buttonId,
      'screen_name': screenName ?? _currentScreen,
    });
  }

  static void trackFlowStarted(String flowName) {
    trackEvent('flow_started', metadata: {'flow_name': flowName});
  }

  static void trackFlowStepCompleted({
    required String flowName,
    required int step,
    required String stepName,
  }) {
    trackEvent('flow_step_completed', metadata: {
      'flow_name': flowName,
      'step': step,
      'step_name': stepName,
    });
  }

  static void trackFlowCompleted({
    required String flowName,
    required int totalDurationSeconds,
  }) {
    trackEvent('flow_completed', metadata: {
      'flow_name': flowName,
      'total_duration_seconds': totalDurationSeconds,
    });
  }

  static void trackFlowAbandoned({
    required String flowName,
    required int lastStep,
    required String stepName,
  }) {
    trackEvent('flow_abandoned', metadata: {
      'flow_name': flowName,
      'last_step': lastStep,
      'step_name': stepName,
    });
  }

  static void trackSettingChanged({
    required String settingName,
    required dynamic value,
  }) {
    trackEvent('feature_used', metadata: {
      'feature_name': 'setting_changed',
      'setting_name': settingName,
      'value': value.toString(),
    });
  }
}
