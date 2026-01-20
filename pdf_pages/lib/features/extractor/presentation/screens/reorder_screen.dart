import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../providers/page_order_provider.dart';

/// Screen for reordering selected pages before export
class ReorderScreen extends ConsumerStatefulWidget {
  final PdfService pdfService;
  final List<int> initialOrder;

  const ReorderScreen({
    super.key,
    required this.pdfService,
    required this.initialOrder,
  });

  @override
  ConsumerState<ReorderScreen> createState() => _ReorderScreenState();
}

class _ReorderScreenState extends ConsumerState<ReorderScreen> {
  final Map<int, Uint8List> _thumbnailCache = {};
  final Set<int> _loadingThumbnails = {};

  @override
  void initState() {
    super.initState();
    // Initialize order provider with current selection
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pageOrderProvider.notifier).setCustomOrder(widget.initialOrder);
    });
    _loadThumbnails();
  }

  Future<void> _loadThumbnails() async {
    for (final pageNumber in widget.initialOrder) {
      if (!mounted) break;
      if (_thumbnailCache.containsKey(pageNumber)) continue;

      setState(() => _loadingThumbnails.add(pageNumber));

      try {
        final bytes = await widget.pdfService.generateThumbnail(pageNumber);
        if (mounted) {
          setState(() {
            _thumbnailCache[pageNumber] = bytes;
            _loadingThumbnails.remove(pageNumber);
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _loadingThumbnails.remove(pageNumber));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentOrder = ref.watch(pageOrderProvider) ?? widget.initialOrder;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () {
            // Cancel - discard changes
            ref.read(pageOrderProvider.notifier).clearCustomOrder();
            Navigator.of(context).pop(false);
          },
        ),
        title: const Text(
          'Reorder Pages',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          // Reset button
          TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              final sorted = List<int>.from(widget.initialOrder)..sort();
              ref.read(pageOrderProvider.notifier).setCustomOrder(sorted);
            },
            child: const Text(
              'Reset',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.primaryPale.withOpacity(0.3),
            child: Row(
              children: [
                Icon(
                  Icons.drag_indicator,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Drag pages to reorder them for export',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Reorderable list
          Expanded(
            child: ReorderableListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: currentOrder.length,
              onReorder: (oldIndex, newIndex) {
                HapticFeedback.mediumImpact();
                ref.read(pageOrderProvider.notifier).reorder(oldIndex, newIndex);
              },
              proxyDecorator: (child, index, animation) {
                return AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    final scale = Tween<double>(begin: 1.0, end: 1.05)
                        .animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ))
                        .value;
                    return Transform.scale(
                      scale: scale,
                      child: Material(
                        elevation: 8,
                        borderRadius: BorderRadius.circular(12),
                        child: child,
                      ),
                    );
                  },
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final pageNumber = currentOrder[index];
                final thumbnail = _thumbnailCache[pageNumber];
                final isLoading = _loadingThumbnails.contains(pageNumber);

                return _PageReorderTile(
                  key: ValueKey(pageNumber),
                  pageNumber: pageNumber,
                  orderIndex: index + 1,
                  thumbnail: thumbnail,
                  isLoading: isLoading,
                );
              },
            ),
          ),

          // Bottom action bar
          Container(
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
                  color: Colors.black.withOpacity(0.06),
                  width: 1,
                ),
              ),
            ),
            child: AppButton(
              label: 'Done',
              icon: Icons.check,
              onPressed: () {
                HapticFeedback.mediumImpact();
                Navigator.of(context).pop(true);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual tile for a page in the reorder list
class _PageReorderTile extends StatelessWidget {
  final int pageNumber;
  final int orderIndex;
  final Uint8List? thumbnail;
  final bool isLoading;

  const _PageReorderTile({
    super.key,
    required this.pageNumber,
    required this.orderIndex,
    this.thumbnail,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Drag handle
          Container(
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.drag_handle,
              color: AppColors.textSecondary,
              size: 24,
            ),
          ),

          // Thumbnail
          Container(
            width: 48,
            height: 68,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: _buildThumbnailContent(),
            ),
          ),

          const SizedBox(width: 12),

          // Page info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Page $pageNumber',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Position $orderIndex',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Order badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryPale,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$orderIndex',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnailContent() {
    if (isLoading) {
      return Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
      );
    }

    final thumbnailData = thumbnail;
    if (thumbnailData != null) {
      return Image.memory(
        thumbnailData,
        fit: BoxFit.cover,
      );
    }

    return const Center(
      child: Icon(
        Icons.picture_as_pdf,
        size: 20,
        color: Color(0xFF757575),
      ),
    );
  }
}
