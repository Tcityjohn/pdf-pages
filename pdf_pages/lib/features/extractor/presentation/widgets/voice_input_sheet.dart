import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/voice_command_handler.dart';
import '../../../../core/services/recents_service.dart';
import '../../../../core/widgets/shared_ui.dart';

/// Compact floating bar for voice-based commands
/// Works on both Home and PageGrid screens
class VoiceInputBar extends ConsumerStatefulWidget {
  final SpeechService speechService;
  final int pageCount;
  final VoiceContext context;
  final RecentsService? recentsService;

  // Callbacks for home screen
  final VoidCallback? onOpenFilePicker;
  final Future<void> Function(String path)? onOpenRecentFile;

  // Callbacks for page grid screen
  final void Function(Set<int> pages)? onPagesSelected;
  final VoidCallback? onCloseDocument;
  final Future<void> Function({String? customName})? onExtract;
  final void Function(int pageNumber)? onScrollToPage;

  // Common callbacks
  final VoidCallback? onOpenSettings;
  final VoidCallback? onShowHelp;
  final VoidCallback? onShowPaywall;
  final VoidCallback onDismiss;

  const VoiceInputBar({
    super.key,
    required this.speechService,
    required this.pageCount,
    required this.context,
    required this.onDismiss,
    this.recentsService,
    this.onOpenFilePicker,
    this.onOpenRecentFile,
    this.onPagesSelected,
    this.onCloseDocument,
    this.onExtract,
    this.onScrollToPage,
    this.onOpenSettings,
    this.onShowHelp,
    this.onShowPaywall,
  });

  @override
  ConsumerState<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends ConsumerState<VoiceInputBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  StreamSubscription<String>? _transcriptionSub;
  StreamSubscription<SpeechState>? _stateSub;

  String _transcription = '';
  VoiceCommandResult? _parsedCommand;
  SpeechState _state = SpeechState.idle;
  bool _permissionGranted = false;
  bool _isAvailable = false;
  String? _feedbackMessage;
  bool _feedbackSuccess = true;

  late VoiceCommandHandler _commandHandler;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _checkAvailabilityAndPermission();
  }

  void _initCommandHandler() {
    _commandHandler = VoiceCommandHandler(
      ref: ref,
      pageCount: widget.pageCount,
      context: widget.context,
      recentsService: widget.recentsService,
      onOpenFilePicker: widget.onOpenFilePicker != null
          ? () async {
              widget.onOpenFilePicker!();
            }
          : null,
      onOpenRecentFile: widget.onOpenRecentFile,
      onCloseDocument: widget.onCloseDocument,
      onOpenSettings: widget.onOpenSettings,
      onShowHelp: widget.onShowHelp,
      onShowPaywall: widget.onShowPaywall,
      onExtract: widget.onExtract,
      onScrollToPage: widget.onScrollToPage,
      onCancel: widget.onDismiss,
    );
  }

  Future<void> _checkAvailabilityAndPermission() async {
    final available = await widget.speechService.isAvailable();
    setState(() => _isAvailable = available);

    if (available) {
      final granted = await widget.speechService.requestPermission();
      setState(() => _permissionGranted = granted);

      if (granted) {
        _setupListeners();
        _startListening();
      }
    }
  }

  void _setupListeners() {
    _transcriptionSub =
        widget.speechService.transcriptionStream.listen((text) {
      setState(() {
        _transcription = text;
        _parsedCommand = widget.speechService.parseVoiceCommand(
          text,
          widget.pageCount,
          context: widget.context,
        );
        _feedbackMessage = null; // Clear feedback when new transcription comes
      });
    });

    _stateSub = widget.speechService.stateStream.listen((state) {
      setState(() => _state = state);
      if (state == SpeechState.listening) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    });
  }

  Future<void> _startListening() async {
    HapticFeedback.mediumImpact();
    await widget.speechService.startListening();
  }

  Future<void> _stopListening() async {
    await widget.speechService.stopListening();
  }

  Future<void> _executeCommand() async {
    final command = _parsedCommand;
    if (command == null || command.type == VoiceCommandType.unrecognized) {
      setState(() {
        _feedbackMessage = 'Command not recognized';
        _feedbackSuccess = false;
      });
      return;
    }

    _initCommandHandler();

    HapticFeedback.mediumImpact();
    final result = await _commandHandler.handle(command);

    setState(() {
      _feedbackMessage = result.feedback;
      _feedbackSuccess = result.success;
    });

    if (result.shouldDismiss) {
      // Small delay to show feedback before dismissing
      await Future.delayed(const Duration(milliseconds: 500));
      widget.onDismiss();
    }
  }

  @override
  void dispose() {
    _transcriptionSub?.cancel();
    _stateSub?.cancel();
    _pulseController.dispose();
    widget.speechService.stopListening();
    super.dispose();
  }

  String _getHintText() {
    if (widget.context == VoiceContext.home) {
      return 'Say "find document" or "open [name]"';
    } else {
      return 'Say "pages 1 to 5" or "all pages"';
    }
  }

  String _getCommandPreview() {
    final command = _parsedCommand;
    if (command == null) return '';

    switch (command.type) {
      case VoiceCommandType.selectPages:
        final count = command.pages?.length ?? 0;
        return '$count page${count == 1 ? '' : 's'} recognized';
      case VoiceCommandType.addPages:
        final count = command.pages?.length ?? 0;
        return 'Add $count page${count == 1 ? '' : 's'}';
      case VoiceCommandType.removePages:
        final count = command.pages?.length ?? 0;
        return 'Remove $count page${count == 1 ? '' : 's'}';
      case VoiceCommandType.openFilePicker:
        return 'Open file picker';
      case VoiceCommandType.openRecentByName:
        return 'Search: "${command.searchQuery}"';
      case VoiceCommandType.extract:
        return 'Extract selected pages';
      case VoiceCommandType.extractWithName:
        return 'Extract as "${command.customName}"';
      case VoiceCommandType.clearSelection:
        return 'Clear selection';
      case VoiceCommandType.invertSelection:
        return 'Invert selection';
      case VoiceCommandType.goToPage:
        return 'Go to page ${command.targetPage}';
      case VoiceCommandType.closeDocument:
        return 'Close document';
      case VoiceCommandType.openSettings:
        return 'Open settings';
      case VoiceCommandType.showHelp:
        return 'Show help';
      case VoiceCommandType.showPaywall:
        return 'Show premium';
      case VoiceCommandType.cancel:
        return 'Cancel';
      case VoiceCommandType.unrecognized:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    if (!_isAvailable || !_permissionGranted) {
      return Container(
        margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              _isAvailable ? Icons.mic_off : Icons.error_outline,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isAvailable
                    ? 'Microphone permission required'
                    : 'Speech not available',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            IconButton(
              onPressed: widget.onDismiss,
              icon: const Icon(Icons.close),
              iconSize: 20,
            ),
          ],
        ),
      );
    }

    final commandPreview = _getCommandPreview();
    final hasValidCommand = _parsedCommand != null &&
        _parsedCommand!.type != VoiceCommandType.unrecognized;

    return Container(
      margin: EdgeInsets.fromLTRB(12, 0, 12, 12 + bottomPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main bar with mic, transcription, and actions
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
            child: Row(
              children: [
                // Mic/Stop button - shows STOP when listening
                GestureDetector(
                  onTap: () {
                    if (_state == SpeechState.listening) {
                      _stopListening();
                    } else {
                      _startListening();
                    }
                  },
                  child: _state == SpeechState.listening
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Stop',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.primaryPale,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic_none,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                ),

                const SizedBox(width: 12),

                // Transcription area
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Feedback message (if any)
                      if (_feedbackMessage != null) ...[
                        Text(
                          _feedbackMessage!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _feedbackSuccess
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ] else ...[
                        Text(
                          _transcription.isEmpty
                              ? (_state == SpeechState.listening
                                  ? 'Listening...'
                                  : _getHintText())
                              : _transcription,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _transcription.isEmpty
                                ? FontWeight.normal
                                : FontWeight.w500,
                            color: _transcription.isEmpty
                                ? AppColors.textSecondary
                                : AppColors.textPrimary,
                            fontStyle: _transcription.isEmpty
                                ? FontStyle.italic
                                : FontStyle.normal,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (commandPreview.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            commandPreview,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: hasValidCommand
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Close button
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                ),

                // Execute button (only when valid command recognized)
                if (hasValidCommand) ...[
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _executeCommand,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Go',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Legacy compatibility - kept for reference
class VoiceInputSheet extends StatefulWidget {
  final SpeechService speechService;
  final int pageCount;
  final void Function(Set<int> pages) onPagesSelected;

  const VoiceInputSheet({
    super.key,
    required this.speechService,
    required this.pageCount,
    required this.onPagesSelected,
  });

  @override
  State<VoiceInputSheet> createState() => _VoiceInputSheetState();
}

class _VoiceInputSheetState extends State<VoiceInputSheet> {
  @override
  Widget build(BuildContext context) {
    return Container();
  }
}
