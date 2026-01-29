import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'speech_service.dart';
import 'recents_service.dart';
import '../../../features/providers/selection_provider.dart';

/// Callback types for voice command actions
typedef VoidAsyncCallback = Future<void> Function();
typedef FileOpenCallback = Future<void> Function(String path);
typedef ExtractCallback = Future<void> Function({String? customName});
typedef ScrollToPageCallback = void Function(int pageNumber);

/// Result of handling a voice command
class VoiceCommandHandlerResult {
  final bool success;
  final String feedback;
  final bool shouldDismiss;

  const VoiceCommandHandlerResult({
    required this.success,
    required this.feedback,
    this.shouldDismiss = false,
  });
}

/// Handles voice commands and routes them to appropriate actions
/// Provides feedback strings for UI display
class VoiceCommandHandler {
  final WidgetRef ref;
  final int pageCount;
  final VoiceContext context;
  final RecentsService? recentsService;

  // Callbacks for various actions
  final VoidAsyncCallback? onOpenFilePicker;
  final FileOpenCallback? onOpenRecentFile;
  final VoidCallback? onCloseDocument;
  final VoidCallback? onOpenSettings;
  final VoidCallback? onShowHelp;
  final VoidCallback? onShowPaywall;
  final ExtractCallback? onExtract;
  final ScrollToPageCallback? onScrollToPage;
  final VoidCallback? onCancel;

  VoiceCommandHandler({
    required this.ref,
    required this.pageCount,
    required this.context,
    this.recentsService,
    this.onOpenFilePicker,
    this.onOpenRecentFile,
    this.onCloseDocument,
    this.onOpenSettings,
    this.onShowHelp,
    this.onShowPaywall,
    this.onExtract,
    this.onScrollToPage,
    this.onCancel,
  });

  /// Handle a voice command result and return feedback
  Future<VoiceCommandHandlerResult> handle(VoiceCommandResult command) async {
    switch (command.type) {
      // === Flow control ===
      case VoiceCommandType.cancel:
        onCancel?.call();
        return const VoiceCommandHandlerResult(
          success: true,
          feedback: 'Cancelled',
          shouldDismiss: true,
        );

      // === Navigation (both screens) ===
      case VoiceCommandType.openSettings:
        onOpenSettings?.call();
        return const VoiceCommandHandlerResult(
          success: true,
          feedback: 'Opening settings',
          shouldDismiss: true,
        );

      case VoiceCommandType.showHelp:
        onShowHelp?.call();
        return const VoiceCommandHandlerResult(
          success: true,
          feedback: 'Showing help',
          shouldDismiss: true,
        );

      case VoiceCommandType.showPaywall:
        onShowPaywall?.call();
        return const VoiceCommandHandlerResult(
          success: true,
          feedback: 'Opening premium',
          shouldDismiss: true,
        );

      // === Home screen commands ===
      case VoiceCommandType.openFilePicker:
        if (onOpenFilePicker != null) {
          await onOpenFilePicker!();
          return const VoiceCommandHandlerResult(
            success: true,
            feedback: 'Opening file picker',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Cannot open file picker here',
        );

      case VoiceCommandType.openRecentByName:
        if (recentsService != null && command.searchQuery != null) {
          final match = recentsService!.findBestMatch(command.searchQuery!);
          if (match != null) {
            if (onOpenRecentFile != null) {
              await onOpenRecentFile!(match.path);
              return VoiceCommandHandlerResult(
                success: true,
                feedback: 'Opening "${match.name}"',
                shouldDismiss: true,
              );
            }
          } else {
            return VoiceCommandHandlerResult(
              success: false,
              feedback: 'No recent file matching "${command.searchQuery}"',
            );
          }
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'No recent files found',
        );

      // === Page Grid commands ===
      case VoiceCommandType.closeDocument:
        onCloseDocument?.call();
        return const VoiceCommandHandlerResult(
          success: true,
          feedback: 'Closing document',
          shouldDismiss: true,
        );

      case VoiceCommandType.selectPages:
        if (command.pages != null && command.pages!.isNotEmpty) {
          ref.read(selectedPagesProvider.notifier).setSelection(command.pages!);
          final count = command.pages!.length;
          return VoiceCommandHandlerResult(
            success: true,
            feedback: 'Selected $count page${count == 1 ? '' : 's'}',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Could not parse page selection',
        );

      case VoiceCommandType.clearSelection:
        ref.read(selectedPagesProvider.notifier).clearSelection();
        return const VoiceCommandHandlerResult(
          success: true,
          feedback: 'Selection cleared',
          shouldDismiss: true,
        );

      case VoiceCommandType.invertSelection:
        ref.read(selectedPagesProvider.notifier).invertSelection(pageCount);
        final newCount = ref.read(selectedPagesProvider).length;
        return VoiceCommandHandlerResult(
          success: true,
          feedback: 'Selection inverted ($newCount pages)',
          shouldDismiss: true,
        );

      case VoiceCommandType.addPages:
        if (command.pages != null && command.pages!.isNotEmpty) {
          final currentSelection = ref.read(selectedPagesProvider);
          final newSelection = {...currentSelection, ...command.pages!};
          ref.read(selectedPagesProvider.notifier).setSelection(newSelection);
          final added = command.pages!.length;
          return VoiceCommandHandlerResult(
            success: true,
            feedback: 'Added $added page${added == 1 ? '' : 's'}',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Could not parse pages to add',
        );

      case VoiceCommandType.removePages:
        if (command.pages != null && command.pages!.isNotEmpty) {
          final currentSelection = ref.read(selectedPagesProvider);
          final newSelection = currentSelection.difference(command.pages!);
          ref.read(selectedPagesProvider.notifier).setSelection(newSelection);
          final removed = command.pages!.length;
          return VoiceCommandHandlerResult(
            success: true,
            feedback: 'Removed $removed page${removed == 1 ? '' : 's'}',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Could not parse pages to remove',
        );

      case VoiceCommandType.extract:
        final selectedPages = ref.read(selectedPagesProvider);
        if (selectedPages.isEmpty) {
          return const VoiceCommandHandlerResult(
            success: false,
            feedback: 'No pages selected to extract',
          );
        }
        if (onExtract != null) {
          await onExtract!();
          return VoiceCommandHandlerResult(
            success: true,
            feedback: 'Extracting ${selectedPages.length} pages',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Cannot extract here',
        );

      case VoiceCommandType.extractWithName:
        final selectedPages = ref.read(selectedPagesProvider);
        if (selectedPages.isEmpty) {
          return const VoiceCommandHandlerResult(
            success: false,
            feedback: 'No pages selected to extract',
          );
        }
        if (onExtract != null && command.customName != null) {
          await onExtract!(customName: command.customName);
          return VoiceCommandHandlerResult(
            success: true,
            feedback: 'Extracting as "${command.customName}"',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Cannot extract here',
        );

      case VoiceCommandType.goToPage:
        if (command.targetPage != null && onScrollToPage != null) {
          onScrollToPage!(command.targetPage!);
          return VoiceCommandHandlerResult(
            success: true,
            feedback: 'Going to page ${command.targetPage}',
            shouldDismiss: true,
          );
        }
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Invalid page number',
        );

      case VoiceCommandType.unrecognized:
        return const VoiceCommandHandlerResult(
          success: false,
          feedback: 'Command not recognized',
        );
    }
  }

  /// Get hint text for the current context
  String getHintText() {
    if (context == VoiceContext.home) {
      return 'Try "find document" or "open [name]"';
    } else {
      return 'Try "pages 1 to 5" or "odd pages"';
    }
  }

  /// Get available commands for help display
  static List<String> getAvailableCommands(VoiceContext context) {
    if (context == VoiceContext.home) {
      return [
        '"Find document" - Open file picker',
        '"Open [name]" - Open recent file',
        '"Settings" - Open settings',
        '"Help" - Show commands',
      ];
    } else {
      return [
        '"All pages" / "Odd" / "Even"',
        '"Pages 1 to 5" / "1 through 5"',
        '"First page" / "Last page"',
        '"Add page 3" / "Remove page 5"',
        '"Clear" / "Invert"',
        '"Extract" / "Save as [name]"',
        '"Go to page 5"',
        '"Close" / "Settings" / "Help"',
      ];
    }
  }
}
