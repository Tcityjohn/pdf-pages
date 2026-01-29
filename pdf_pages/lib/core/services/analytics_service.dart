import 'package:posthog_flutter/posthog_flutter.dart';

/// Analytics service wrapping PostHog for event tracking
class AnalyticsService {
  static const String _apiKey = 'phc_CN2G4I039vFq7xwvumAc0TEzQhg8MdaqG5sWeqjIPBi';
  static const String _host = 'https://us.i.posthog.com';

  static bool _initialized = false;

  /// Initialize PostHog SDK - call once at app startup
  static Future<void> initialize() async {
    if (_initialized) return;

    final config = PostHogConfig(_apiKey);
    config.host = _host;
    config.captureApplicationLifecycleEvents = true;
    config.debug = false;

    await Posthog().setup(config);
    _initialized = true;
  }

  /// Track when a PDF is opened
  static Future<void> trackPdfOpened({
    required int pageCount,
  }) async {
    await Posthog().capture(
      eventName: 'pdf_opened',
      properties: {
        'page_count': pageCount,
      },
    );
  }

  /// Track when pages are selected (called on extraction)
  static Future<void> trackPagesSelected({
    required int selectedCount,
    required int totalPages,
  }) async {
    await Posthog().capture(
      eventName: 'pages_selected',
      properties: {
        'selected_count': selectedCount,
        'total_pages': totalPages,
        'selection_ratio': selectedCount / totalPages,
      },
    );
  }

  /// Track successful extraction
  static Future<void> trackExtractionCompleted({
    required int pageCount,
  }) async {
    await Posthog().capture(
      eventName: 'extraction_completed',
      properties: {
        'page_count': pageCount,
      },
    );
  }

  /// Track when paywall is shown
  static Future<void> trackPaywallShown({
    required String reason,
  }) async {
    await Posthog().capture(
      eventName: 'paywall_shown',
      properties: {
        'reason': reason,
      },
    );
  }

  /// Track share action
  static Future<void> trackShare() async {
    await Posthog().capture(eventName: 'pdf_shared');
  }

  /// Track save to files action
  static Future<void> trackSaveToFiles() async {
    await Posthog().capture(eventName: 'pdf_saved_to_files');
  }

  /// Track voice input used
  static Future<void> trackVoiceInputUsed({
    required int pagesSelected,
  }) async {
    await Posthog().capture(
      eventName: 'voice_input_used',
      properties: {
        'pages_selected': pagesSelected,
      },
    );
  }

  /// Track range dialog used
  static Future<void> trackRangeDialogUsed({
    required int pagesSelected,
  }) async {
    await Posthog().capture(
      eventName: 'range_dialog_used',
      properties: {
        'pages_selected': pagesSelected,
      },
    );
  }

  /// Track premium purchase initiated
  static Future<void> trackPurchaseInitiated() async {
    await Posthog().capture(eventName: 'purchase_initiated');
  }

  /// Track premium purchase completed
  static Future<void> trackPurchaseCompleted() async {
    await Posthog().capture(eventName: 'purchase_completed');
  }

  /// Track restore purchases
  static Future<void> trackRestorePurchases({
    required bool success,
  }) async {
    await Posthog().capture(
      eventName: 'restore_purchases',
      properties: {
        'success': success,
      },
    );
  }

  /// Identify user (for premium users)
  static Future<void> identifyUser({
    required String oddsUserId,
    bool isPremium = false,
  }) async {
    await Posthog().identify(
      userId: oddsUserId,
      userProperties: {
        'is_premium': isPremium,
      },
    );
  }

  /// Reset user identity (on logout/reset)
  static Future<void> reset() async {
    await Posthog().reset();
  }
}
