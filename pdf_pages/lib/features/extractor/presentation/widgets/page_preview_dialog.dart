import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/widgets/shared_ui.dart';

/// Full-screen dialog showing a 2x resolution preview of a PDF page
/// Triggered by long-press on a thumbnail
class PagePreviewDialog extends StatelessWidget {
  final int pageNumber;
  final int totalPages;
  final Uint8List? previewImage;
  final bool isLoading;
  final bool isCurrentlySelected;
  final VoidCallback onSelect;
  final VoidCallback onCancel;

  const PagePreviewDialog({
    super.key,
    required this.pageNumber,
    required this.totalPages,
    this.previewImage,
    this.isLoading = false,
    required this.isCurrentlySelected,
    required this.onSelect,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.of(context).pop();
        onCancel();
      },
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: GestureDetector(
                onTap: () {}, // Prevent tap from closing dialog
                child: Container(
                  margin: const EdgeInsets.all(32),
                  constraints: const BoxConstraints(
                    maxWidth: 340,
                    maxHeight: 560,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.25),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Preview image
                      Flexible(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20),
                          ),
                          child: AspectRatio(
                            aspectRatio: 0.707, // A4 aspect ratio
                            child: _buildPreviewContent(),
                          ),
                        ),
                      ),

                      // Page number label
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Page $pageNumber of $totalPages',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(context).pop();
                                  onCancel();
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.textSecondary,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  Navigator.of(context).pop();
                                  onSelect();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.textPrimary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  isCurrentlySelected ? 'Deselect' : 'Select',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewContent() {
    if (isLoading) {
      return Container(
        color: const Color(0xFFF5F5F5),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final imageData = previewImage;
    if (imageData != null) {
      return Image.memory(
        imageData,
        fit: BoxFit.cover,
      );
    }

    return Container(
      color: const Color(0xFFF5F5F5),
      child: const Center(
        child: Icon(
          Icons.picture_as_pdf,
          size: 48,
          color: Color(0xFF757575),
        ),
      ),
    );
  }
}
