import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/widgets/shared_ui.dart';

/// Bottom sheet for voice-based page selection
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

class _VoiceInputSheetState extends State<VoiceInputSheet>
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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
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
      Navigator.of(context).pop();
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
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          const SizedBox(height: 24),

          // Title
          const Text(
            'Voice Selection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),

          const SizedBox(height: 8),

          // Instructions
          Text(
            _getInstructionText(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: 32),

          // Microphone button with pulse animation
          if (_permissionGranted && _isAvailable) ...[
            GestureDetector(
              onTap: () {
                if (_state == SpeechState.listening) {
                  _stopListening();
                } else {
                  _startListening();
                }
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _state == SpeechState.listening
                        ? _pulseAnimation.value
                        : 1.0,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: _state == SpeechState.listening
                            ? AppColors.primary
                            : AppColors.primaryPale,
                        shape: BoxShape.circle,
                        boxShadow: _state == SpeechState.listening
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.4),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        _state == SpeechState.listening
                            ? Icons.mic
                            : Icons.mic_none,
                        color: _state == SpeechState.listening
                            ? Colors.white
                            : AppColors.primary,
                        size: 36,
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 24),

            // Transcription display
            Container(
              constraints: const BoxConstraints(minHeight: 60),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: _transcription.isEmpty
                  ? Text(
                      _state == SpeechState.listening
                          ? 'Listening...'
                          : 'Tap microphone to start',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : Text(
                      _transcription,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
            ),

            const SizedBox(height: 16),

            // Parsed result preview
            if (_parsedPages != null && _parsedPages!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_parsedPages!.length} page${_parsedPages!.length == 1 ? '' : 's'} recognized',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Example commands
            _buildExampleCommands(),

            const SizedBox(height: 24),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _parsedPages != null && _parsedPages!.isNotEmpty
                        ? _confirmSelection
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.textPrimary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Select Pages',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Permission denied or unavailable
            Icon(
              _isAvailable ? Icons.mic_off : Icons.error_outline,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              _isAvailable
                  ? 'Microphone permission required'
                  : 'Speech recognition not available',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Close',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ],
      ),
    );
  }

  String _getInstructionText() {
    if (!_isAvailable) {
      return 'Speech recognition is not available on this device';
    }
    if (!_permissionGranted) {
      return 'Please grant microphone access to use voice selection';
    }
    return 'Say commands like "pages 1 through 5" or "odd pages"';
  }

  Widget _buildExampleCommands() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        _buildExampleChip('page 3'),
        _buildExampleChip('pages 1 to 5'),
        _buildExampleChip('odd pages'),
        _buildExampleChip('last page'),
      ],
    );
  }

  Widget _buildExampleChip(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryPale.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryPale),
      ),
      child: Text(
        '"$text"',
        style: TextStyle(
          fontSize: 12,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
