import 'dart:async';
import 'package:flutter/services.dart';

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

  /// Parse voice command text into a set of page numbers
  /// Returns null if the command couldn't be parsed
  Set<int>? parseVoiceCommand(String text, int pageCount) {
    final normalizedText = text.toLowerCase().trim();
    final Set<int> result = {};

    // Handle "all pages" or "all"
    if (normalizedText.contains('all')) {
      return {for (int i = 1; i <= pageCount; i++) i};
    }

    // Handle "odd pages" or "odd"
    if (normalizedText.contains('odd')) {
      return {for (int i = 1; i <= pageCount; i += 2) i};
    }

    // Handle "even pages" or "even"
    if (normalizedText.contains('even')) {
      return {for (int i = 2; i <= pageCount; i += 2) i};
    }

    // Handle "first" or "first page"
    if (normalizedText.contains('first')) {
      return pageCount >= 1 ? {1} : {};
    }

    // Handle "last" or "last page"
    if (normalizedText.contains('last')) {
      return pageCount >= 1 ? {pageCount} : {};
    }

    // Handle ranges: "X through Y", "X to Y", "X thru Y", "X - Y"
    // More flexible - doesn't require "page" prefix
    final rangePatterns = [
      RegExp(r'(\w+)\s+(?:through|to|thru)\s+(\w+)'),
      RegExp(r'(\d+)\s*[-–]\s*(\d+)'),
    ];

    for (final pattern in rangePatterns) {
      final match = pattern.firstMatch(normalizedText);
      if (match != null) {
        final start = _parseNumber(match.group(1)!);
        final end = _parseNumber(match.group(2)!);
        if (start != null && end != null && start <= end) {
          return {for (int i = start.clamp(1, pageCount); i <= end.clamp(1, pageCount); i++) i};
        }
      }
    }

    // Handle comma-separated or space-separated lists: "1, 3, 5" or "1 3 5"
    // Also handles "pages 1 3 and 5" or "page 1 and 3"
    final cleanedText = normalizedText
        .replaceAll(RegExp(r'page[s]?'), '')
        .replaceAll('and', ' ')
        .replaceAll(',', ' ')
        .trim();

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
      'one': 1, 'first': 1,
      'two': 2, 'second': 2,
      'three': 3, 'third': 3,
      'four': 4, 'fourth': 4,
      'five': 5, 'fifth': 5,
      'six': 6, 'sixth': 6,
      'seven': 7, 'seventh': 7,
      'eight': 8, 'eighth': 8,
      'nine': 9, 'ninth': 9,
      'ten': 10, 'tenth': 10,
      'eleven': 11, 'eleventh': 11,
      'twelve': 12, 'twelfth': 12,
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
