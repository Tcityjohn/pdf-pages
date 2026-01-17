import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

/// Bottom sheet widget that appears after successful PDF extraction
/// Allows user to share or save the extracted PDF file
class ExportSheet extends StatelessWidget {
  final String extractedFilePath;
  final Set<int>? selectedPages;
  final VoidCallback? onDone;

  const ExportSheet({
    super.key,
    required this.extractedFilePath,
    this.selectedPages,
    this.onDone,
  });

  /// Generate a user-friendly filename for display
  String _generateDisplayName(Set<int>? selectedPages) {
    if (selectedPages == null || selectedPages.isEmpty) {
      return 'PDF_Pages_extracted.pdf';
    }

    final sortedPages = selectedPages.toList()..sort();

    if (sortedPages.length == 1) {
      return 'PDF_Page_${sortedPages.first}.pdf';
    } else if (sortedPages.length <= 3) {
      return 'PDF_Pages_${sortedPages.join('_')}.pdf';
    } else {
      return 'PDF_Pages_${sortedPages.first}-${sortedPages.last}.pdf';
    }
  }

  /// Share the PDF using iOS share sheet
  Future<void> _sharePdf() async {
    try {
      await Share.shareXFiles(
        [XFile(extractedFilePath)],
        text: 'PDF Pages extraction',
        subject: 'Extracted PDF Pages',
      );
    } catch (e) {
      debugPrint('Error sharing PDF: $e');
    }
  }

  /// Save the PDF to Files app using iOS document picker
  Future<void> _savePdf(BuildContext context) async {
    try {
      // Read file bytes for saveFile method
      final file = File(extractedFilePath);
      final bytes = await file.readAsBytes();

      // Generate user-friendly filename for save dialog
      final displayName = _generateDisplayName(selectedPages);

      String? savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF',
        fileName: displayName,
        bytes: bytes,
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (savedPath != null) {
        debugPrint('PDF saved to: $savedPath');
        // Could show a success toast here in the future
      }
    } catch (e) {
      debugPrint('Error saving PDF: $e');
      // Show error dialog
      if (context.mounted) {
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Save Error'),
            content: Text('Failed to save PDF: ${e.toString()}'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Handle Done button - return to home screen
  void _handleDone(BuildContext context) {
    // Close the bottom sheet first
    Navigator.of(context).pop();

    // Navigate back to home screen
    Navigator.of(context).popUntil((route) => route.isFirst);

    // Call optional callback
    onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final displayName = _generateDisplayName(selectedPages);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sheet handle
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0), // Outline color
                borderRadius: BorderRadius.circular(2),
              ),
              margin: const EdgeInsets.only(bottom: 20),
            ),

            // Success icon (80x80 green circle with checkmark)
            Container(
              width: 80,
              height: 80,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: const BoxDecoration(
                color: Color(0xFFE8F5E9), // Success container
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.check,
                  size: 48,
                  color: Color(0xFF4CAF50), // Success color
                ),
              ),
            ),

            // Title: "PDF Created!"
            const Text(
              'PDF Created!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF212121), // On-surface
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 8),

            // Filename
            Text(
              displayName,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF757575), // On-surface-variant
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 28),

            // Share button (filled primary red with share icon)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sharePdf,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935), // Primary
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Save to Files button (outlined primary red with folder icon)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _savePdf(context),
                icon: const Icon(Icons.folder),
                label: const Text('Save to Files'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFE53935), // Primary
                  side: const BorderSide(
                    color: Color(0xFFE53935), // Primary
                    width: 1,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Done button (text button, gray color)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _handleDone(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF757575), // On-surface-variant
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}