import 'dart:async';
import 'package:flutter/services.dart';

/// Service for Siri Shortcuts integration
/// Handles donating shortcuts and receiving Siri intent callbacks
class SiriService {
  static const _channel = MethodChannel('com.pdfpages.siri');

  final StreamController<SiriIntent> _intentController =
      StreamController<SiriIntent>.broadcast();

  /// Stream of Siri intents received from Shortcuts
  Stream<SiriIntent> get intentStream => _intentController.stream;

  SiriService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onSiriIntent':
        final args = call.arguments as Map<dynamic, dynamic>;
        final pageSelection = args['pageSelection'] as int?;
        if (pageSelection != null) {
          _intentController.add(SiriIntent(
            pageSelection: PageSelectionType.fromValue(pageSelection),
          ));
        }
        break;
    }
  }

  /// Check if Siri Shortcuts are available on this device
  Future<bool> isAvailable() async {
    try {
      final result = await _channel.invokeMethod<bool>('isAvailable');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Donate a shortcut for the given selection type
  /// This makes the action appear in Siri Suggestions and Shortcuts app
  Future<bool> donateShortcut(PageSelectionType selectionType) async {
    try {
      final result = await _channel.invokeMethod<bool>('donateShortcut', {
        'selectionType': selectionType.displayName,
      });
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Donate a shortcut after a successful extraction
  Future<void> donateAfterExtraction(Set<int> extractedPages, int totalPages) async {
    // Determine what type of extraction was done
    PageSelectionType? type;

    if (extractedPages.length == 1) {
      if (extractedPages.first == 1) {
        type = PageSelectionType.first;
      } else if (extractedPages.first == totalPages) {
        type = PageSelectionType.last;
      }
    } else if (extractedPages.length == totalPages) {
      type = PageSelectionType.all;
    } else {
      // Check for odd/even
      final oddPages = {for (int i = 1; i <= totalPages; i += 2) i};
      final evenPages = {for (int i = 2; i <= totalPages; i += 2) i};

      if (extractedPages.length == oddPages.length &&
          extractedPages.containsAll(oddPages)) {
        type = PageSelectionType.odd;
      } else if (extractedPages.length == evenPages.length &&
          extractedPages.containsAll(evenPages)) {
        type = PageSelectionType.even;
      }
    }

    if (type != null) {
      await donateShortcut(type);
    }
  }

  void dispose() {
    _intentController.close();
  }
}

/// Represents a Siri intent received from Shortcuts
class SiriIntent {
  final PageSelectionType pageSelection;

  SiriIntent({required this.pageSelection});
}

/// Page selection types for Siri Shortcuts
enum PageSelectionType {
  unknown(0, 'Unknown'),
  first(1, 'first page'),
  last(2, 'last page'),
  odd(3, 'odd pages'),
  even(4, 'even pages'),
  all(5, 'all pages');

  final int value;
  final String displayName;

  const PageSelectionType(this.value, this.displayName);

  static PageSelectionType fromValue(int value) {
    return PageSelectionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PageSelectionType.unknown,
    );
  }
}
