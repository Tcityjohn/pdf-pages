import 'dart:async';
import 'package:flutter/services.dart';

/// Voice command types for the PDF Pages app
enum VoiceCommandType {
  // Document operations (Home screen)
  openFilePicker,
  openRecentByName,
  closeDocument,

  // Selection operations (Page grid)
  selectPages,
  clearSelection,
  invertSelection,
  addPages,
  removePages,

  // Extraction
  extract,
  extractWithName,

  // Navigation
  goToPage,
  openSettings,
  showHelp,
  showPaywall,

  // Flow control
  cancel,
  unrecognized,
}

/// Result of parsing a voice command
class VoiceCommandResult {
  final VoiceCommandType type;
  final Set<int>? pages;
  final String? searchQuery;
  final String? customName;
  final int? targetPage;

  const VoiceCommandResult({
    required this.type,
    this.pages,
    this.searchQuery,
    this.customName,
    this.targetPage,
  });

  @override
  String toString() =>
      'VoiceCommandResult(type: $type, pages: $pages, searchQuery: $searchQuery, customName: $customName, targetPage: $targetPage)';
}

/// Context for voice command parsing (which screen we're on)
enum VoiceContext {
  home,
  pageGrid,
}

/// Service for voice-based page selection using iOS Speech framework
/// Uses MethodChannel to communicate with native iOS code
class SpeechService {
  static const _channel = MethodChannel('com.pdfpages.speech');

  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<SpeechState> _stateController =
      StreamController<SpeechState>.broadcast();

  bool _isListening = false;

  /// Stream of transcription updates during listening
  Stream<String> get transcriptionStream => _transcriptionController.stream;

  /// Stream of speech recognition state changes
  Stream<SpeechState> get stateStream => _stateController.stream;

  /// Whether speech recognition is currently active
  bool get isListening => _isListening;

  SpeechService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handle callbacks from native code
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onTranscription':
        final text = call.arguments as String;
        _transcriptionController.add(text);
        break;
      case 'onStateChange':
        final state = call.arguments as String;
        _stateController.add(SpeechState.fromString(state));
        break;
      case 'onError':
        _stateController.add(SpeechState.error);
        _isListening = false;
        break;
    }
  }

  /// Request speech recognition permission
  /// Returns true if permission granted
  Future<bool> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Check if speech recognition is available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Start listening for speech input
  Future<bool> startListening() async {
    if (_isListening) return true;

    try {
      final result = await _channel.invokeMethod<bool>('startListening');
      _isListening = result ?? false;
      if (_isListening) {
        _stateController.add(SpeechState.listening);
      }
      return _isListening;
    } on PlatformException {
      _isListening = false;
      return false;
    }
  }

  /// Stop listening and get final result
  Future<void> stopListening() async {
    if (!_isListening) return;

    try {
      await _channel.invokeMethod<void>('stopListening');
    } on PlatformException {
      // Ignore errors
    } finally {
      _isListening = false;
      _stateController.add(SpeechState.idle);
    }
  }

  /// Parse voice command into a structured result based on context
  VoiceCommandResult parseVoiceCommand(
    String text,
    int pageCount, {
    VoiceContext context = VoiceContext.pageGrid,
  }) {
    final normalizedText = text.toLowerCase().trim();

    // === Flow control commands (both contexts) ===
    if (_matchesAny(normalizedText, ['cancel', 'stop', 'nevermind', 'never mind'])) {
      return const VoiceCommandResult(type: VoiceCommandType.cancel);
    }

    // === Navigation commands (both contexts) ===
    if (_matchesAny(normalizedText, ['settings', 'open settings', 'go to settings'])) {
      return const VoiceCommandResult(type: VoiceCommandType.openSettings);
    }

    if (_matchesAny(normalizedText, ['help', 'show help', 'what can i say', 'commands'])) {
      return const VoiceCommandResult(type: VoiceCommandType.showHelp);
    }

    if (_matchesAny(normalizedText, ['upgrade', 'premium', 'go premium', 'unlock'])) {
      return const VoiceCommandResult(type: VoiceCommandType.showPaywall);
    }

    // === Home screen commands ===
    if (context == VoiceContext.home) {
      // "find document", "open file", "pick file", "select pdf"
      if (_matchesAny(normalizedText, [
        'find document',
        'find a document',
        'open file',
        'open a file',
        'pick file',
        'pick a file',
        'select pdf',
        'select a pdf',
        'choose file',
        'choose a file',
        'browse',
        'browse files',
      ])) {
        return const VoiceCommandResult(type: VoiceCommandType.openFilePicker);
      }

      // "open [name]" - search recents
      final openMatch = RegExp(r'^open\s+(.+)$').firstMatch(normalizedText);
      if (openMatch != null) {
        final searchQuery = openMatch.group(1)?.trim();
        if (searchQuery != null && searchQuery.isNotEmpty) {
          return VoiceCommandResult(
            type: VoiceCommandType.openRecentByName,
            searchQuery: searchQuery,
          );
        }
      }

      // Fallback for home - if nothing matched, it's unrecognized
      return const VoiceCommandResult(type: VoiceCommandType.unrecognized);
    }

    // === Page Grid commands ===

    // Close/back navigation
    if (_matchesAny(normalizedText, ['close', 'go back', 'back', 'exit', 'done'])) {
      // "done" without selection context means close; with selection means extract
      // We'll handle this context-aware in the handler
      if (normalizedText == 'done') {
        return const VoiceCommandResult(type: VoiceCommandType.extract);
      }
      return const VoiceCommandResult(type: VoiceCommandType.closeDocument);
    }

    // === Extraction commands ===
    // "save as [name]", "extract and rename [name]", "name it [name]"
    final saveAsMatch = RegExp(
      r'(?:save\s+as|extract\s+(?:and\s+)?(?:rename|name)|name\s+it|call\s+it)\s+(.+)',
    ).firstMatch(normalizedText);
    if (saveAsMatch != null) {
      final customName = saveAsMatch.group(1)?.trim();
      if (customName != null && customName.isNotEmpty) {
        return VoiceCommandResult(
          type: VoiceCommandType.extractWithName,
          customName: customName,
        );
      }
    }

    // "extract" / "extract pages"
    if (_matchesAny(normalizedText, ['extract', 'extract pages', 'save', 'export'])) {
      return const VoiceCommandResult(type: VoiceCommandType.extract);
    }

    // === Selection manipulation ===
    // Clear selection
    if (_matchesAny(normalizedText, ['clear', 'clear selection', 'deselect', 'deselect all', 'unselect', 'unselect all'])) {
      return const VoiceCommandResult(type: VoiceCommandType.clearSelection);
    }

    // Invert selection
    if (_matchesAny(normalizedText, ['invert', 'invert selection', 'flip', 'flip selection', 'opposite'])) {
      return const VoiceCommandResult(type: VoiceCommandType.invertSelection);
    }

    // === Go to page ===
    final goToMatch = RegExp(r'go\s+to\s+(?:page\s+)?(\w+)').firstMatch(normalizedText);
    if (goToMatch != null) {
      final pageNum = _parseNumber(goToMatch.group(1)!);
      if (pageNum != null && pageNum >= 1 && pageNum <= pageCount) {
        return VoiceCommandResult(
          type: VoiceCommandType.goToPage,
          targetPage: pageNum,
        );
      }
    }

    // === Add/Remove pages ===
    // "add page 3", "add pages 3 and 5"
    final addMatch = RegExp(r'^add\s+(?:page[s]?\s+)?(.+)$').firstMatch(normalizedText);
    if (addMatch != null) {
      final pages = _parsePageList(addMatch.group(1)!, pageCount);
      if (pages != null && pages.isNotEmpty) {
        return VoiceCommandResult(type: VoiceCommandType.addPages, pages: pages);
      }
    }

    // "remove page 3", "remove pages 3 and 5"
    final removeMatch = RegExp(r'^remove\s+(?:page[s]?\s+)?(.+)$').firstMatch(normalizedText);
    if (removeMatch != null) {
      final pages = _parsePageList(removeMatch.group(1)!, pageCount);
      if (pages != null && pages.isNotEmpty) {
        return VoiceCommandResult(type: VoiceCommandType.removePages, pages: pages);
      }
    }

    // === Page selection patterns ===
    final pages = _parsePageSelection(normalizedText, pageCount);
    if (pages != null && pages.isNotEmpty) {
      return VoiceCommandResult(type: VoiceCommandType.selectPages, pages: pages);
    }

    return const VoiceCommandResult(type: VoiceCommandType.unrecognized);
  }

  /// Legacy method for backwards compatibility - parses page numbers only
  Set<int>? parseVoiceCommandLegacy(String text, int pageCount) {
    final result = parseVoiceCommand(text, pageCount, context: VoiceContext.pageGrid);
    if (result.type == VoiceCommandType.selectPages ||
        result.type == VoiceCommandType.addPages ||
        result.type == VoiceCommandType.removePages) {
      return result.pages;
    }
    return null;
  }

  /// Check if text matches any of the given patterns
  bool _matchesAny(String text, List<String> patterns) {
    for (final pattern in patterns) {
      if (text == pattern || text.startsWith('$pattern ') || text.endsWith(' $pattern')) {
        return true;
      }
    }
    return false;
  }

  /// Parse a page list like "3 and 5" or "3, 5, 7"
  Set<int>? _parsePageList(String text, int pageCount) {
    final cleanedText = text
        .replaceAll('and', ' ')
        .replaceAll(',', ' ')
        .trim();

    final Set<int> result = {};
    final words = cleanedText.split(RegExp(r'\s+'));
    for (final word in words) {
      final num = _parseNumber(word);
      if (num != null && num >= 1 && num <= pageCount) {
        result.add(num);
      }
    }
    return result.isEmpty ? null : result;
  }

  /// Parse page selection patterns (all, odd, even, ranges, lists)
  Set<int>? _parsePageSelection(String text, int pageCount) {
    // Handle "all pages" or "all"
    if (text.contains('all')) {
      // Check for "select all" - this means all pages
      if (text.contains('select all') || text == 'all' || text == 'all pages') {
        return {for (int i = 1; i <= pageCount; i++) i};
      }
    }

    // Handle "odd pages" or "odd"
    if (text.contains('odd')) {
      return {for (int i = 1; i <= pageCount; i += 2) i};
    }

    // Handle "even pages" or "even"
    if (text.contains('even')) {
      return {for (int i = 2; i <= pageCount; i += 2) i};
    }

    // Handle "first" or "first page" (just one page)
    if (text == 'first' || text == 'first page') {
      return pageCount >= 1 ? {1} : {};
    }

    // Handle "last" or "last page" (just one page)
    if (text == 'last' || text == 'last page') {
      return pageCount >= 1 ? {pageCount} : {};
    }

    // Handle ranges: "X through Y", "X to Y", "X thru Y", "X - Y"
    // Patterns: "pages 1 to 5", "1 through 5", "pages 1-5"
    final rangePatterns = [
      RegExp(r'(?:pages?\s+)?(\w+)\s+(?:through|to|thru)\s+(\w+)'),
      RegExp(r'(?:pages?\s+)?(\d+)\s*[-–]\s*(\d+)'),
    ];

    for (final pattern in rangePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final start = _parseNumber(match.group(1)!);
        final end = _parseNumber(match.group(2)!);
        if (start != null && end != null && start <= end) {
          return {
            for (int i = start.clamp(1, pageCount); i <= end.clamp(1, pageCount); i++) i
          };
        }
      }
    }

    // Handle comma-separated or space-separated lists: "1, 3, 5" or "1 3 5"
    // Also handles "pages 1 3 and 5" or "page 1 and 3"
    final cleanedText = text
        .replaceAll(RegExp(r'page[s]?'), '')
        .replaceAll('and', ' ')
        .replaceAll(',', ' ')
        .trim();

    final Set<int> result = {};
    final words = cleanedText.split(RegExp(r'\s+'));
    for (final word in words) {
      final num = _parseNumber(word);
      if (num != null && num >= 1 && num <= pageCount) {
        result.add(num);
      }
    }

    if (result.isNotEmpty) {
      return result;
    }

    return null;
  }

  /// Convert number word to integer
  int? _parseNumber(String text) {
    // Try direct parsing first
    final direct = int.tryParse(text);
    if (direct != null) return direct;

    // Number words mapping
    const numberWords = {
      'one': 1,
      'first': 1,
      'two': 2,
      'second': 2,
      'three': 3,
      'third': 3,
      'four': 4,
      'fourth': 4,
      'five': 5,
      'fifth': 5,
      'six': 6,
      'sixth': 6,
      'seven': 7,
      'seventh': 7,
      'eight': 8,
      'eighth': 8,
      'nine': 9,
      'ninth': 9,
      'ten': 10,
      'tenth': 10,
      'eleven': 11,
      'eleventh': 11,
      'twelve': 12,
      'twelfth': 12,
      'thirteen': 13,
      'fourteen': 14,
      'fifteen': 15,
      'sixteen': 16,
      'seventeen': 17,
      'eighteen': 18,
      'nineteen': 19,
      'twenty': 20,
    };

    return numberWords[text.toLowerCase()];
  }

  /// Dispose of resources
  void dispose() {
    stopListening();
    _transcriptionController.close();
    _stateController.close();
  }
}

/// Represents the current state of speech recognition
enum SpeechState {
  idle,
  listening,
  processing,
  error;

  static SpeechState fromString(String value) {
    switch (value) {
      case 'listening':
        return SpeechState.listening;
      case 'processing':
        return SpeechState.processing;
      case 'error':
        return SpeechState.error;
      default:
        return SpeechState.idle;
    }
  }
}
