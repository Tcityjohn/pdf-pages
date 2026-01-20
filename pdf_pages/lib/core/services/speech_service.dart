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

    // Handle "all pages"
    if (normalizedText.contains('all page')) {
      return {for (int i = 1; i <= pageCount; i++) i};
    }

    // Handle "odd pages"
    if (normalizedText.contains('odd page')) {
      return {for (int i = 1; i <= pageCount; i += 2) i};
    }

    // Handle "even pages"
    if (normalizedText.contains('even page')) {
      return {for (int i = 2; i <= pageCount; i += 2) i};
    }

    // Handle "first page"
    if (normalizedText.contains('first page')) {
      return pageCount >= 1 ? {1} : {};
    }

    // Handle "last page"
    if (normalizedText.contains('last page')) {
      return pageCount >= 1 ? {pageCount} : {};
    }

    // Handle "pages X through Y" or "pages X to Y"
    final rangePattern = RegExp(r'page[s]?\s+(\w+)\s+(?:through|to|thru)\s+(\w+)');
    final rangeMatch = rangePattern.firstMatch(normalizedText);
    if (rangeMatch != null) {
      final start = _parseNumber(rangeMatch.group(1)!);
      final end = _parseNumber(rangeMatch.group(2)!);
      if (start != null && end != null && start <= end) {
        return {for (int i = start.clamp(1, pageCount); i <= end.clamp(1, pageCount); i++) i};
      }
    }

    // Handle "page X" or "page number X"
    final singlePattern = RegExp(r'page\s*(?:number)?\s*(\w+)');
    final singleMatch = singlePattern.firstMatch(normalizedText);
    if (singleMatch != null) {
      final pageNum = _parseNumber(singleMatch.group(1)!);
      if (pageNum != null && pageNum >= 1 && pageNum <= pageCount) {
        return {pageNum};
      }
    }

    // Handle just a number
    final justNumber = _parseNumber(normalizedText);
    if (justNumber != null && justNumber >= 1 && justNumber <= pageCount) {
      return {justNumber};
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
