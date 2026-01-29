import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_pages/core/services/speech_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Silence Timer Logic', () {
    test('timer should only reset when transcription changes', () async {
      // Simulate the logic from voice_input_sheet.dart
      String lastTranscription = '';
      int timerResetCount = 0;

      void resetSilenceTimer(String newTranscription) {
        final transcriptionChanged = newTranscription != lastTranscription;
        lastTranscription = newTranscription;

        if (transcriptionChanged) {
          timerResetCount++;
        }
      }

      // First transcription - should reset timer
      resetSilenceTimer('hello');
      expect(timerResetCount, 1);

      // Same transcription - should NOT reset timer
      resetSilenceTimer('hello');
      expect(timerResetCount, 1);

      // Different transcription - should reset timer
      resetSilenceTimer('hello world');
      expect(timerResetCount, 2);

      // Same again - should NOT reset
      resetSilenceTimer('hello world');
      expect(timerResetCount, 2);

      // New word - should reset
      resetSilenceTimer('hello world test');
      expect(timerResetCount, 3);
    });

    test('timer fires after silence period with no transcription change', () async {
      // Simulate the silence detection
      const silenceTimeout = Duration(milliseconds: 100); // Short for testing
      bool timerFired = false;
      Timer? silenceTimer;

      void startTimer() {
        silenceTimer?.cancel();
        silenceTimer = Timer(silenceTimeout, () {
          timerFired = true;
        });
      }

      // Start timer (simulating first transcription)
      startTimer();
      expect(timerFired, false);

      // Wait less than timeout
      await Future.delayed(const Duration(milliseconds: 50));
      expect(timerFired, false);

      // Wait for timeout to complete
      await Future.delayed(const Duration(milliseconds: 100));
      expect(timerFired, true);

      silenceTimer?.cancel();
    });

    test('timer reset prevents firing', () async {
      const silenceTimeout = Duration(milliseconds: 100);
      bool timerFired = false;
      Timer? silenceTimer;

      void startTimer() {
        silenceTimer?.cancel();
        silenceTimer = Timer(silenceTimeout, () {
          timerFired = true;
        });
      }

      // Start timer
      startTimer();

      // Wait 50ms then reset
      await Future.delayed(const Duration(milliseconds: 50));
      startTimer(); // Reset

      // Wait another 50ms (total 100ms from start, but only 50ms from reset)
      await Future.delayed(const Duration(milliseconds: 50));
      expect(timerFired, false); // Should not have fired yet

      // Wait for reset timer to complete
      await Future.delayed(const Duration(milliseconds: 60));
      expect(timerFired, true);

      silenceTimer?.cancel();
    });
  });

  late SpeechService speechService;

  setUp(() {
    // Mock the method channel to prevent native calls
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.pdfpages.speech'),
      (MethodCall methodCall) async {
        return null;
      },
    );
    speechService = SpeechService();
  });

  tearDown(() {
    speechService.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('com.pdfpages.speech'),
      null,
    );
  });

  group('Voice Command Parsing - Home Context', () {
    test('parses "find document" as openFilePicker', () {
      final result = speechService.parseVoiceCommand(
        'find document',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.openFilePicker);
    });

    test('parses "open file" as openFilePicker', () {
      final result = speechService.parseVoiceCommand(
        'open file',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.openFilePicker);
    });

    test('parses "open quarterly report" as openRecentByName', () {
      final result = speechService.parseVoiceCommand(
        'open quarterly report',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.openRecentByName);
      expect(result.searchQuery, 'quarterly report');
    });

    test('parses "settings" as openSettings', () {
      final result = speechService.parseVoiceCommand(
        'settings',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.openSettings);
    });

    test('parses "help" as showHelp', () {
      final result = speechService.parseVoiceCommand(
        'help',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.showHelp);
    });

    test('parses "cancel" as cancel', () {
      final result = speechService.parseVoiceCommand(
        'cancel',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.cancel);
    });

    test('unrecognized command returns unrecognized', () {
      final result = speechService.parseVoiceCommand(
        'random gibberish',
        10,
        context: VoiceContext.home,
      );
      expect(result.type, VoiceCommandType.unrecognized);
    });
  });

  group('Voice Command Parsing - PageGrid Context', () {
    test('parses "all pages" as selectPages with all pages', () {
      final result = speechService.parseVoiceCommand(
        'all pages',
        5,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {1, 2, 3, 4, 5});
    });

    test('parses "pages 1 to 3" as selectPages range', () {
      final result = speechService.parseVoiceCommand(
        'pages 1 to 3',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {1, 2, 3});
    });

    test('parses "pages 2 through 5" as selectPages range', () {
      final result = speechService.parseVoiceCommand(
        'pages 2 through 5',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {2, 3, 4, 5});
    });

    test('parses "odd pages" as selectPages odd', () {
      final result = speechService.parseVoiceCommand(
        'odd pages',
        6,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {1, 3, 5});
    });

    test('parses "even pages" as selectPages even', () {
      final result = speechService.parseVoiceCommand(
        'even pages',
        6,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {2, 4, 6});
    });

    test('parses "first page" as selectPages first', () {
      final result = speechService.parseVoiceCommand(
        'first page',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {1});
    });

    test('parses "last page" as selectPages last', () {
      final result = speechService.parseVoiceCommand(
        'last page',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {10});
    });

    test('parses "clear" as clearSelection', () {
      final result = speechService.parseVoiceCommand(
        'clear',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.clearSelection);
    });

    test('parses "invert" as invertSelection', () {
      final result = speechService.parseVoiceCommand(
        'invert',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.invertSelection);
    });

    test('parses "extract" as extract', () {
      final result = speechService.parseVoiceCommand(
        'extract',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.extract);
    });

    test('parses "save as monthly report" as extractWithName', () {
      final result = speechService.parseVoiceCommand(
        'save as monthly report',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.extractWithName);
      expect(result.customName, 'monthly report');
    });

    test('parses "go to page 5" as goToPage', () {
      final result = speechService.parseVoiceCommand(
        'go to page 5',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.goToPage);
      expect(result.targetPage, 5);
    });

    test('parses "add page 3" as addPages', () {
      final result = speechService.parseVoiceCommand(
        'add page 3',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.addPages);
      expect(result.pages, {3});
    });

    test('parses "remove page 2" as removePages', () {
      final result = speechService.parseVoiceCommand(
        'remove page 2',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.removePages);
      expect(result.pages, {2});
    });

    test('parses "close" as closeDocument', () {
      final result = speechService.parseVoiceCommand(
        'close',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.closeDocument);
    });

    test('respects page count limits', () {
      final result = speechService.parseVoiceCommand(
        'pages 1 to 100',
        5,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      // Should clamp to available pages
      expect(result.pages, {1, 2, 3, 4, 5});
    });
  });

  group('Number word parsing', () {
    test('parses "pages one to three"', () {
      final result = speechService.parseVoiceCommand(
        'pages one to three',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {1, 2, 3});
    });

    test('parses "page five"', () {
      final result = speechService.parseVoiceCommand(
        'page five',
        10,
        context: VoiceContext.pageGrid,
      );
      expect(result.type, VoiceCommandType.selectPages);
      expect(result.pages, {5});
    });
  });
}
