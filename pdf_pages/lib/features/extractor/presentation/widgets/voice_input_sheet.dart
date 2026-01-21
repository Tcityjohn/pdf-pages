import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/widgets/shared_ui.dart';

/// Compact floating bar for voice-based page selection
/// Doesn't block view of the PDF grid
class VoiceInputBar extends StatefulWidget {
  final SpeechService speechService;
  final int pageCount;
  final void Function(Set<int> pages) onPagesSelected;
  final VoidCallback onDismiss;

  const VoiceInputBar({
    super.key,
    required this.speechService,
    required this.pageCount,
    required this.onPagesSelected,
    required this.onDismiss,
  });

  @override
  State<VoiceInputBar> createState() => _VoiceInputBarState();
}

class _VoiceInputBarState extends State<VoiceInputBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  StreamSubscription<String>? _transcriptionSub;
  StreamSubscription<SpeechState>? _stateSub;

  String _transcription = '';
  Set<int>? _parsedPages;
  SpeechState _state = SpeechState.idle;
  bool _permissionGranted = false;
  bool _isAvailable = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkAvailabilityAndPermission();
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
    _transcriptionSub = widget.speechService.transcriptionStream.listen((text) {
      setState(() {
        _transcription = text;
        _parsedPages = widget.speechService.parseVoiceCommand(text, widget.pageCount);
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

  void _confirmSelection() {
    final pages = _parsedPages;
    if (pages != null && pages.isNotEmpty) {
      HapticFeedback.mediumImpact();
      widget.onPagesSelected(pages);
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
                      Text(
                        _transcription.isEmpty
                            ? (_state == SpeechState.listening
                                ? 'Listening...'
                                : 'Tap mic & say "pages 1 to 5"')
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
                      if (_parsedPages != null && _parsedPages!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${_parsedPages!.length} page${_parsedPages!.length == 1 ? '' : 's'} recognized',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.success,
                          ),
                        ),
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

                // Confirm button (only when pages recognized)
                if (_parsedPages != null && _parsedPages!.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  ElevatedButton(
                    onPressed: _confirmSelection,
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
                      'Select',
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

/// Legacy bottom sheet - kept for reference but replaced by VoiceInputBar
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
    // Redirect to use the new bar instead
    return Container();
  }
}
