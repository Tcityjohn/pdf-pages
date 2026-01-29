import 'package:flutter/material.dart';

/// Brand colors for PDF Pages app
class AppColors {
  static const primary = Color(0xFFE63946);
  static const primaryLight = Color(0xFFEF6B6B);
  static const primaryPale = Color(0xFFF9C4C8);
  static const textPrimary = Color(0xFF1a1a1a);
  static const textSecondary = Color(0x99000000); // 60% black
  static const success = Color(0xFF4CAF50);
  static const successContainer = Color(0xFFE8F5E9);
}

/// Gradient scaffold wrapper for Soft Minimal design system
class GradientScaffold extends StatelessWidget {
  final Widget child;
  final List<Color>? colors;
  final List<double>? stops;
  final PreferredSizeWidget? appBar;

  const GradientScaffold({
    super.key,
    required this.child,
    this.colors,
    this.stops,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: appBar,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors ??
                const [
                  AppColors.primary,
                  AppColors.primaryLight,
                  AppColors.primaryPale,
                  Colors.white,
                ],
            stops: stops ?? const [0.0, 0.3, 0.6, 1.0],
          ),
        ),
        child: child,
      ),
    );
  }
}

/// Black pill button for primary CTAs in Soft Minimal design
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
  });

  @override
  Widget build(BuildContext context) {
    final button = ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.textPrimary.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
        elevation: 0,
      ),
      child: isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
    );

    if (fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }
    return button;
  }
}

/// Compact black pill button for toolbar actions
class AppButtonCompact extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const AppButtonCompact({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.textPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.textPrimary.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        elevation: 0,
        minimumSize: const Size(0, 36),
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          : icon != null
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
    );
  }
}

/// 64x64 Voice FAB button for primary voice input
/// Used on both Home and PageGrid screens as THE primary interface
class VoiceActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isListening;
  final bool isProcessing;

  const VoiceActionButton({
    super.key,
    required this.onPressed,
    this.isListening = false,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: isListening ? AppColors.primary : AppColors.textPrimary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isListening ? AppColors.primary : AppColors.textPrimary)
                  .withValues(alpha: 0.4),
              blurRadius: isListening ? 20 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: isProcessing
              ? const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Icon(
                  isListening ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 28,
                ),
        ),
      ),
    );
  }
}
