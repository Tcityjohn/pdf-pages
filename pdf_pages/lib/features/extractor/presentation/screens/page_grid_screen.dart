// Removing unnecessary import
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../providers/selection_provider.dart';

/// Screen that displays PDF pages in a 3-column grid with thumbnails
/// Users can view all pages from the loaded PDF document
class PageGridScreen extends ConsumerStatefulWidget {
  final PdfService pdfService;
  final String documentName;
  final int pageCount;

  const PageGridScreen({
    super.key,
    required this.pdfService,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          _getTruncatedFileName(widget.documentName),
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE0E0E0), // Outline color
          ),
        ),
      ),
      body: Column(
        children: [
          // Selection bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFFEEEEEE), // Surface container high
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE0E0E0), // Outline
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Page count badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFCDD2), // Primary container
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    '${widget.pageCount} pages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFC62828), // Primary dark
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
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE3F2FD), // Tertiary container
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            '${selectedPages.length} selected',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1565C0), // Dark blue for badge text
                            ),
                          ),
                        )
                      : const SizedBox.shrink();
                  },
                ),

                const Spacer(),
                // TODO: Selection control buttons will be added in PDF-009 and PDF-010
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
          color: const Color(0xFFF5F5F5), // Surface container
          borderRadius: BorderRadius.circular(8),
          border: isSelected
            ? Border.all(
                color: const Color(0xFFE53935), // Primary color
                width: 3,
                style: BorderStyle.solid,
              )
            : Border.all(
                color: const Color(0xFFE0E0E0), // Outline
                width: 1,
              ),
          boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFE53935).withValues(alpha: 76),
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
                const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFFE53935),
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
                    decoration: BoxDecoration(
                      color: const Color(0xFFE53935), // Primary color
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
