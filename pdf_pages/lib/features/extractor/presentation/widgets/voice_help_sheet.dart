import 'package:flutter/material.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/voice_command_handler.dart';

/// Bottom sheet showing available voice commands for the current context
class VoiceHelpSheet extends StatelessWidget {
  final VoiceContext context;

  const VoiceHelpSheet({
    super.key,
    required this.context,
  });

  static Future<void> show(BuildContext context, VoiceContext voiceContext) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VoiceHelpSheet(context: voiceContext),
    );
  }

  @override
  Widget build(BuildContext context) {
    final commands = VoiceCommandHandler.getAvailableCommands(this.context);
    final title = this.context == VoiceContext.home
        ? 'Home Screen Commands'
        : 'Page Selection Commands';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryPale,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const Text(
                          'Tap the mic and say any command',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Commands list
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final command in commands) ...[
                      _CommandRow(command: command),
                      if (command != commands.last)
                        const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),

            // Pro tip
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primaryPale.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Say "cancel" or "stop" at any time to dismiss',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final String command;

  const _CommandRow({required this.command});

  @override
  Widget build(BuildContext context) {
    // Parse command into quoted part and description
    final quoteStart = command.indexOf('"');
    final quoteEnd = command.lastIndexOf('"');

    String quotedPart = '';
    String description = command;

    if (quoteStart >= 0 && quoteEnd > quoteStart) {
      quotedPart = command.substring(quoteStart, quoteEnd + 1);
      description = command.substring(quoteEnd + 1).trim();
      if (description.startsWith('-')) {
        description = description.substring(1).trim();
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.textPrimary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.keyboard_voice,
            size: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (quotedPart.isNotEmpty)
                Text(
                  quotedPart,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              if (description.isNotEmpty)
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
