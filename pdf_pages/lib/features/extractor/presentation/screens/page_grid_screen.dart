import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/usage_service.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../providers/selection_provider.dart';
import '../widgets/range_dialog.dart';
import '../widgets/export_sheet.dart';

/// Screen that displays PDF pages in a 3-column grid with thumbnails
/// Users can view all pages from the loaded PDF document
class PageGridScreen extends ConsumerStatefulWidget {
  final PdfService pdfService;
  final UsageService usageService;
  final String documentName;
  final int pageCount;

  const PageGridScreen({
    super.key,
    required this.pdfService,
    required this.usageService,
    required this.documentName,
    required this.pageCount,
  });

  @override
  ConsumerState<PageGridScreen> createState() => _PageGridScreenState();
}

class _PageGridScreenState extends ConsumerState<PageGridScreen> {
  // Cache for generated thumbnails (1-indexed page number -> thumbnail bytes)
  final Map<int, Uint8List> _thumbnailCache = {};

  // Track which thumbnails are currently loading
  final Set<int> _loadingThumbnails = {};

  // Track extraction state
  bool _isExtracting = false;

  @override
  void initState() {
    super.initState();
    // Start loading thumbnails progressively
    _loadThumbnailsProgressively();
  }

  /// Load thumbnails progressively to avoid blocking the UI
  Future<void> _loadThumbnailsProgressively() async {
    for (int pageNumber = 1; pageNumber <= widget.pageCount; pageNumber++) {
      // Check if widget is still mounted
      if (!mounted) break;

      // Skip if already loaded or loading
      if (_thumbnailCache.containsKey(pageNumber) ||
          _loadingThumbnails.contains(pageNumber)) {
        continue;
      }

      // Mark as loading
      setState(() {
        _loadingThumbnails.add(pageNumber);
      });

      try {
        // Generate thumbnail
        final thumbnailBytes =
            await widget.pdfService.generateThumbnail(pageNumber);

        if (mounted) {
          setState(() {
            _thumbnailCache[pageNumber] = thumbnailBytes;
            _loadingThumbnails.remove(pageNumber);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loadingThumbnails.remove(pageNumber);
          });
        }
        debugPrint('Error generating thumbnail for page $pageNumber: $e');
      }

      // Small delay to avoid overwhelming the UI thread
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  String _getTruncatedFileName(String fullPath) {
    // Extract filename from path
    final parts = fullPath.split('/');
    final fileName = parts.isNotEmpty ? parts.last : fullPath;

    // Remove .pdf extension if present
    if (fileName.toLowerCase().endsWith('.pdf')) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  /// Show the range selection dialog
  void _showRangeDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return RangeSelectionDialog(
          pageCount: widget.pageCount,
          onConfirm: (Set<int> selectedPages) {
            // Replace current selection with parsed pages
            ref.read(selectedPagesProvider.notifier).setSelection(selectedPages);
          },
        );
      },
    );
  }

  /// Extract selected pages to new PDF
  Future<void> _extractPages() async {
    final selectedPages = ref.read(selectedPagesProvider);
    if (selectedPages.isEmpty) return;

    // Check usage limits before proceeding
    try {
      final canExtract = await widget.usageService.canExtract();
      if (!canExtract) {
        // Show limit reached dialog
        if (mounted) {
          await _showUsageLimitDialog();
        }
        return;
      }
    } catch (e) {
      debugPrint('Error checking usage limits: $e');
      // Continue with extraction if usage service fails
    }

    setState(() => _isExtracting = true);

    try {
      final extractedPath = await widget.pdfService.extractPages(
        selectedPages,
        onProgress: (current, total) {
          // Progress callback - could show progress dialog in future
          debugPrint('Extracting page $current of $total');
        },
      );

      // Record the successful extraction
      try {
        await widget.usageService.recordExtraction();
      } catch (e) {
        debugPrint('Error recording extraction: $e');
        // Don't fail the extraction if usage tracking fails
      }

      if (mounted) {
        setState(() => _isExtracting = false);
        await _showExportSheet(extractedPath);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExtracting = false);
        // Show error dialog
        showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Export Error'),
            content: Text('Failed to create PDF: ${e.toString()}'),
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

  /// Show dialog when usage limit is reached
  Future<void> _showUsageLimitDialog() async {
    final remaining = await widget.usageService.getRemainingExtractions();
    final nextReset = widget.usageService.getNextResetDate();
    final resetDateStr = '${nextReset.month}/${nextReset.day}/${nextReset.year}';

    if (mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Extraction Limit Reached'),
          content: Text(
            'You have used all $remaining free extractions this month. Your limit will reset on $resetDateStr.\n\nUpgrade to Premium for unlimited extractions.',
          ),
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

  /// Show the export bottom sheet after successful extraction
  Future<void> _showExportSheet(String extractedFilePath) async {
    final selectedPages = ref.read(selectedPagesProvider);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: false, // Require user to explicitly choose an action
      enableDrag: false, // Disable drag to dismiss
      builder: (context) => ExportSheet(
        extractedFilePath: extractedFilePath,
        selectedPages: selectedPages,
        onDone: () {
          // Optional callback when done is pressed
          debugPrint('Export sheet dismissed');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          _getTruncatedFileName(widget.documentName),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.black.withOpacity(0.06),
          ),
        ),
      ),
      body: Column(
        children: [
          // Selection bar - simplified styling
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              border: Border(
                bottom: BorderSide(
                  color: Colors.black.withOpacity(0.06),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Page count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPale,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${widget.pageCount} pages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Selected count badge
                Consumer(
                  builder: (context, ref, child) {
                    final selectedPages = ref.watch(selectedPagesProvider);
                    return selectedPages.isNotEmpty
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${selectedPages.length} selected',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1565C0),
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                  },
                ),

                const Spacer(),

                // Filter/range selection button
                IconButton(
                  onPressed: () => _showRangeDialog(),
                  icon: const Icon(Icons.filter_list),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Select page range',
                ),

                // Selection control buttons
                const SizedBox(width: 4),

                // Select All button
                IconButton(
                  onPressed: () {
                    ref.read(selectedPagesProvider.notifier).selectAll(widget.pageCount);
                  },
                  icon: const Icon(Icons.select_all),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Select all pages',
                ),

                // Clear selection button
                Consumer(
                  builder: (context, ref, child) {
                    final selectedPages = ref.watch(selectedPagesProvider);
                    return IconButton(
                      onPressed: selectedPages.isNotEmpty
                        ? () {
                            ref.read(selectedPagesProvider.notifier).clearSelection();
                          }
                        : null, // Disabled when no selection
                      icon: const Icon(Icons.deselect),
                      iconSize: 20,
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                      tooltip: 'Clear selection',
                    );
                  },
                ),

                // Invert selection button
                IconButton(
                  onPressed: () {
                    ref.read(selectedPagesProvider.notifier).invertSelection(widget.pageCount);
                  },
                  icon: const Icon(Icons.flip_to_back),
                  iconSize: 20,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(
                    minWidth: 36,
                    minHeight: 36,
                  ),
                  tooltip: 'Invert selection',
                ),

                const SizedBox(width: 8),

                // Extract button - black pill style
                Consumer(
                  builder: (context, ref, child) {
                    final selectedPages = ref.watch(selectedPagesProvider);
                    return AppButtonCompact(
                      label: _isExtracting ? 'Extracting...' : 'Extract',
                      icon: _isExtracting ? null : Icons.file_download,
                      onPressed: selectedPages.isNotEmpty && !_isExtracting
                          ? _extractPages
                          : null,
                      isLoading: _isExtracting,
                    );
                  },
                ),
              ],
            ),
          ),

          // Page grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.7, // ~1.4 aspect ratio inverted
              ),
              itemCount: widget.pageCount,
              itemBuilder: (context, index) {
                final pageNumber = index + 1; // 1-indexed
                final isLoading = _loadingThumbnails.contains(pageNumber);
                final thumbnail = _thumbnailCache[pageNumber];

                return _PageThumbnailWidget(
                  pageNumber: pageNumber,
                  thumbnail: thumbnail,
                  isLoading: isLoading,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying a single page thumbnail
class _PageThumbnailWidget extends ConsumerWidget {
  final int pageNumber;
  final Uint8List? thumbnail;
  final bool isLoading;

  const _PageThumbnailWidget({
    required this.pageNumber,
    required this.thumbnail,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thumbnailData = thumbnail; // Local variable for null promotion
    final selectedPages = ref.watch(selectedPagesProvider);
    final isSelected = selectedPages.contains(pageNumber);

    return GestureDetector(
      onTap: () {
        // Perform haptic feedback
        HapticFeedback.lightImpact();

        // Toggle page selection
        ref.read(selectedPagesProvider.notifier).togglePage(pageNumber);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: isSelected
            ? Border.all(
                color: AppColors.primary,
                width: 3,
                style: BorderStyle.solid,
              )
            : Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 76),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            children: [
              // Thumbnail or loading indicator
              if (thumbnailData != null)
                Positioned.fill(
                  child: Image.memory(
                    thumbnailData,
                    fit: BoxFit.cover,
                  ),
                )
              else if (isLoading)
                Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                )
              else
                // Placeholder if loading hasn't started
                const Center(
                  child: Icon(
                    Icons.picture_as_pdf,
                    size: 32,
                    color: Color(0xFF757575),
                  ),
                ),

              // Page number badge in bottom-right corner
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 180),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$pageNumber',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // Selection checkmark badge
              if (isSelected)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
