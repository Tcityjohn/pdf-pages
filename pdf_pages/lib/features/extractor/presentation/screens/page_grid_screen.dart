import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/usage_service.dart';
import '../../../../core/services/recents_service.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../providers/selection_provider.dart';
import '../../../providers/page_order_provider.dart';
import '../widgets/range_dialog.dart';
import 'reorder_screen.dart';
import '../widgets/export_sheet.dart';
import '../widgets/preset_chips.dart';
import '../widgets/page_preview_dialog.dart';
import '../widgets/voice_input_sheet.dart';
import '../widgets/paywall_sheet.dart';
import '../widgets/voice_help_sheet.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../core/services/siri_service.dart';
import '../../../../core/services/analytics_service.dart';

/// Screen that displays PDF pages in a 3-column grid with thumbnails
/// Users can view all pages from the loaded PDF document
class PageGridScreen extends ConsumerStatefulWidget {
  final PdfService pdfService;
  final UsageService usageService;
  final RecentsService? recentsService;
  final String documentName;
  final int pageCount;

  const PageGridScreen({
    super.key,
    required this.pdfService,
    required this.usageService,
    this.recentsService,
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

  // Track voice input bar visibility
  bool _showVoiceInput = false;

  // Speech service for voice page selection
  late final SpeechService _speechService;

  // Siri service for shortcuts
  late final SiriService _siriService;

  // ScrollController for go-to-page navigation
  late final ScrollController _scrollController;

  // Custom filename for extraction (from voice command)
  String? _customFileName;

  @override
  void initState() {
    super.initState();
    _speechService = SpeechService();
    _siriService = SiriService();
    _scrollController = ScrollController();
    // Start loading thumbnails progressively
    _loadThumbnailsProgressively();
  }

  @override
  void dispose() {
    _speechService.dispose();
    _siriService.dispose();
    _scrollController.dispose();
    super.dispose();
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
  Future<void> _extractPages({String? customName}) async {
    final selectedPages = ref.read(selectedPagesProvider);
    if (selectedPages.isEmpty) return;

    // Check usage limits before proceeding
    try {
      final canExtract = await widget.usageService.canExtract();
      if (!canExtract) {
        // Track paywall shown
        AnalyticsService.trackPaywallShown(reason: 'free_limit_reached');
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
      // Get custom order if set
      final customOrder = ref.read(pageOrderProvider);

      final extractedPath = await widget.pdfService.extractPages(
        selectedPages,
        customOrder: customOrder,
        customFileName: customName ?? _customFileName,
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

      // Track extraction analytics
      AnalyticsService.trackExtractionCompleted(pageCount: selectedPages.length);

      // Donate Siri Shortcut for this type of extraction
      try {
        await _siriService.donateAfterExtraction(selectedPages, widget.pageCount);
      } catch (e) {
        debugPrint('Error donating Siri shortcut: $e');
        // Don't fail the extraction if Siri donation fails
      }

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _customFileName = null; // Reset custom filename
        });
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

  /// Show paywall when usage limit is reached
  Future<void> _showUsageLimitDialog() async {
    final nextReset = widget.usageService.getNextResetDate();
    final now = DateTime.now();
    final daysUntilReset = nextReset.difference(now).inDays;

    if (mounted) {
      final purchased = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => PaywallSheet(
          daysUntilReset: daysUntilReset,
        ),
      );

      // If user purchased, try extraction again
      if (purchased == true && mounted) {
        _extractPages();
      }
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

  /// Show the reorder screen for dragging pages
  Future<void> _showReorderScreen() async {
    final selectedPages = ref.read(selectedPagesProvider);
    if (selectedPages.length < 2) return;

    // Initialize order from current selection (sorted or existing custom order)
    final currentOrder = ref.read(pageOrderProvider);
    final initialOrder = currentOrder != null &&
            currentOrder.toSet().containsAll(selectedPages) &&
            selectedPages.containsAll(currentOrder.toSet())
        ? currentOrder
        : (selectedPages.toList()..sort());

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ReorderScreen(
          pdfService: widget.pdfService,
          initialOrder: initialOrder,
        ),
      ),
    );

    // If cancelled (false or null), clear custom order
    if (result != true) {
      ref.read(pageOrderProvider.notifier).clearCustomOrder();
    }
  }

  /// Toggle the voice input bar
  void _toggleVoiceInput() {
    setState(() {
      _showVoiceInput = !_showVoiceInput;
    });
  }

  /// Scroll to a specific page in the grid
  void _scrollToPage(int pageNumber) {
    // Calculate row index (0-indexed)
    final rowIndex = (pageNumber - 1) ~/ 3;
    // Estimate row height including spacing
    const rowHeight = 180.0; // Approximate height based on aspect ratio
    final offset = rowIndex * rowHeight;

    _scrollController.animateTo(
      offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Show the help sheet
  void _showHelpSheet() {
    VoiceHelpSheet.show(context, VoiceContext.pageGrid);
  }

  /// Show the paywall/premium sheet
  void _showPaywall() {
    _showUsageLimitDialog();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: Consumer(
        builder: (context, ref, child) {
          final selectedPages = ref.watch(selectedPagesProvider);
          if (selectedPages.isEmpty) return const SizedBox.shrink();

          return Container(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(
                  color: Colors.black.withValues(alpha: 0.06),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Reorder button - only when 2+ pages selected
                if (selectedPages.length >= 2) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showReorderScreen,
                      icon: const Icon(Icons.reorder),
                      label: const Text('Reorder'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                // Extract button
                Expanded(
                  flex: selectedPages.length >= 2 ? 1 : 1,
                  child: AppButton(
                    label: _isExtracting
                        ? 'Extracting...'
                        : 'Extract ${selectedPages.length} Page${selectedPages.length == 1 ? '' : 's'}',
                    icon: _isExtracting ? null : Icons.file_download,
                    onPressed: !_isExtracting ? () => _extractPages() : null,
                    isLoading: _isExtracting,
                  ),
                ),
              ],
            ),
          );
        },
      ),
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
            color: Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Selection bar - simplified styling (removed mic button)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.black.withValues(alpha: 0.06),
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

                  ],
                ),
              ),

              // Preset selection chips
              PresetChipsBar(pageCount: widget.pageCount),

              // Page grid
              Expanded(
                child: GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 160),
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
                      pdfService: widget.pdfService,
                      totalPages: widget.pageCount,
                    );
                  },
                ),
              ),
            ],
          ),

          // Voice input floating bar
          if (_showVoiceInput)
            Positioned(
              left: 0,
              right: 0,
              bottom: 80, // Above the FAB
              child: VoiceInputBar(
                speechService: _speechService,
                pageCount: widget.pageCount,
                context: VoiceContext.pageGrid,
                recentsService: widget.recentsService,
                onDismiss: () => setState(() => _showVoiceInput = false),
                onPagesSelected: (pages) {
                  ref.read(selectedPagesProvider.notifier).setSelection(pages);
                },
                onCloseDocument: () => Navigator.of(context).pop(),
                onExtract: _extractPages,
                onScrollToPage: _scrollToPage,
                onShowHelp: _showHelpSheet,
                onShowPaywall: _showPaywall,
              ),
            ),

          // Voice FAB - bottom right
          Positioned(
            right: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
            child: VoiceActionButton(
              onPressed: _toggleVoiceInput,
              isListening: _showVoiceInput,
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
  final PdfService pdfService;
  final int totalPages;

  const _PageThumbnailWidget({
    required this.pageNumber,
    required this.thumbnail,
    required this.isLoading,
    required this.pdfService,
    required this.totalPages,
  });

  /// Show the page preview dialog on long press
  Future<void> _showPreviewDialog(BuildContext context, WidgetRef ref) async {
    HapticFeedback.heavyImpact();

    // Show dialog with loading state first
    Uint8List? previewImage;
    bool isLoadingPreview = true;
    final isCurrentlySelected = ref.read(selectedPagesProvider).contains(pageNumber);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Load preview image if not loaded yet
            if (isLoadingPreview && previewImage == null) {
              pdfService.generatePreviewThumbnail(pageNumber).then((bytes) {
                if (context.mounted) {
                  setDialogState(() {
                    previewImage = bytes;
                    isLoadingPreview = false;
                  });
                }
              }).catchError((e) {
                if (context.mounted) {
                  setDialogState(() {
                    isLoadingPreview = false;
                  });
                }
              });
            }

            return PagePreviewDialog(
              pageNumber: pageNumber,
              totalPages: totalPages,
              previewImage: previewImage,
              isLoading: isLoadingPreview,
              isCurrentlySelected: isCurrentlySelected,
              onSelect: () {
                ref.read(selectedPagesProvider.notifier).togglePage(pageNumber);
              },
              onCancel: () {
                // No action needed on cancel
              },
            );
          },
        );
      },
    );
  }

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
      onLongPress: () => _showPreviewDialog(context, ref),
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
