import 'package:shared_preferences/shared_preferences.dart';

/// Service for tracking free tier usage (3 extractions per month)
/// Uses SharedPreferences to persist usage data across app sessions
class UsageService {
  static const String _extractionCountKey = 'extraction_count';
  static const String _lastResetMonthKey = 'last_reset_month';
  static const int _freeExtractionsPerMonth = 3;

  SharedPreferences? _prefs;

  /// Initialize the service by loading SharedPreferences
  /// Must be called before using other methods
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkAndResetMonthly();
  }

  /// Checks if a new month has started and resets the counter if needed
  /// Called automatically during initialization and before usage checks
  Future<void> _checkAndResetMonthly() async {
    if (_prefs == null) return;

    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    final lastResetMonth = _prefs!.getString(_lastResetMonthKey);

    if (lastResetMonth != currentMonth) {
      // New month detected - reset counter
      await _prefs!.setInt(_extractionCountKey, 0);
      await _prefs!.setString(_lastResetMonthKey, currentMonth);
    }
  }

  /// Returns the current month's extraction count
  /// Returns 0 if no extractions have been made this month
  Future<int> getExtractionCount() async {
    if (_prefs == null) {
      throw UsageServiceException('UsageService not initialized');
    }

    await _checkAndResetMonthly();
    return _prefs!.getInt(_extractionCountKey) ?? 0;
  }

  /// Returns the number of remaining free extractions this month
  /// Returns 0 if the limit has been reached
  Future<int> getRemainingExtractions() async {
    final count = await getExtractionCount();
    final remaining = _freeExtractionsPerMonth - count;
    return remaining > 0 ? remaining : 0;
  }

  /// Returns true if the user can perform another extraction
  /// Returns false if the free limit (3 per month) has been reached
  Future<bool> canExtract() async {
    final count = await getExtractionCount();
    return count < _freeExtractionsPerMonth;
  }

  /// Records a new extraction, incrementing the current month's counter
  /// Should be called after a successful PDF extraction
  /// Throws [UsageServiceException] if the service is not initialized
  Future<void> recordExtraction() async {
    if (_prefs == null) {
      throw UsageServiceException('UsageService not initialized');
    }

    await _checkAndResetMonthly();
    final currentCount = await getExtractionCount();
    await _prefs!.setInt(_extractionCountKey, currentCount + 1);
  }

  /// Gets the current month string for display purposes
  /// Returns format 'YYYY-MM' (e.g., '2026-01')
  String getCurrentMonth() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  /// Gets the next reset date for display purposes
  /// Returns the first day of next month
  DateTime getNextResetDate() {
    final now = DateTime.now();
    if (now.month == 12) {
      return DateTime(now.year + 1, 1, 1);
    } else {
      return DateTime(now.year, now.month + 1, 1);
    }
  }
}

/// Exception thrown when the UsageService encounters an error
class UsageServiceException implements Exception {
  final String message;

  UsageServiceException(this.message);

  @override
  String toString() => message;
}