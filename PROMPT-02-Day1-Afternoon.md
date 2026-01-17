# PDF Pages Build Prompt 2: Selection Controls & Extraction Logic
## Day 1 Afternoon (3-4 hours)

---

## Context for Claude

The basic PDF loading and thumbnail grid are complete. Now we add advanced selection controls and implement the actual page extraction functionality.

---

## Task: Add selection controls and extraction logic

### Step 1: Create Range Selection Dialog

**lib/features/extractor/presentation/widgets/range_dialog.dart:**

```dart
import 'package:flutter/material.dart';

class RangeDialog extends StatefulWidget {
  final int maxPages;
  final Set<int> currentSelection;

  const RangeDialog({
    super.key,
    required this.maxPages,
    required this.currentSelection,
  });

  @override
  State<RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<RangeDialog> {
  late TextEditingController _controller;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Set<int>? _parseRange(String input) {
    final result = <int>{};

    // Remove spaces
    input = input.replaceAll(' ', '');

    if (input.isEmpty) return null;

    // Split by comma
    final parts = input.split(',');

    for (final part in parts) {
      if (part.contains('-')) {
        // Range like "1-5"
        final rangeParts = part.split('-');
        if (rangeParts.length != 2) return null;

        final start = int.tryParse(rangeParts[0]);
        final end = int.tryParse(rangeParts[1]);

        if (start == null || end == null) return null;
        if (start < 1 || end > widget.maxPages || start > end) return null;

        for (int i = start; i <= end; i++) {
          result.add(i - 1); // Convert to 0-indexed
        }
      } else {
        // Single page like "3"
        final page = int.tryParse(part);
        if (page == null || page < 1 || page > widget.maxPages) return null;
        result.add(page - 1); // Convert to 0-indexed
      }
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Select Pages'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter page numbers or ranges:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: InputDecoration(
              hintText: 'e.g., 1-5, 8, 11-15',
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            autofocus: true,
            onChanged: (value) {
              if (_errorText != null) {
                setState(() => _errorText = null);
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            'Total pages: ${widget.maxPages}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final parsed = _parseRange(_controller.text);
            if (parsed == null) {
              setState(() {
                _errorText = 'Invalid format. Use: 1-5, 8, 11-15';
              });
              return;
            }
            Navigator.pop(context, parsed);
          },
          child: const Text('Select'),
        ),
      ],
    );
  }
}
```

### Step 2: Create Selection Controls Widget

**lib/features/extractor/presentation/widgets/selection_controls.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import 'range_dialog.dart';

class SelectionControls extends ConsumerWidget {
  const SelectionControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(currentDocumentProvider);
    final selectedPages = ref.watch(selectedPagesProvider);
    final theme = Theme.of(context);

    if (document == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Page count
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              '${document.pageCount} pages',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),

          if (selectedPages.isNotEmpty) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${selectedPages.length} selected',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onTertiaryContainer,
                ),
              ),
            ),
          ],

          const Spacer(),

          // Range select button
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Select range',
            onPressed: () async {
              final result = await showDialog<Set<int>>(
                context: context,
                builder: (_) => RangeDialog(
                  maxPages: document.pageCount,
                  currentSelection: selectedPages,
                ),
              );

              if (result != null) {
                ref.read(selectedPagesProvider.notifier).state = result;
              }
            },
          ),

          // Select all
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: () {
              ref.read(selectedPagesProvider.notifier).state =
                  Set.from(List.generate(document.pageCount, (i) => i));
            },
          ),

          // Clear selection
          IconButton(
            icon: const Icon(Icons.deselect),
            tooltip: 'Clear selection',
            onPressed: selectedPages.isEmpty
                ? null
                : () {
                    ref.read(selectedPagesProvider.notifier).state = {};
                  },
          ),

          // Invert selection
          IconButton(
            icon: const Icon(Icons.flip),
            tooltip: 'Invert selection',
            onPressed: () {
              final allPages = Set.from(
                List.generate(document.pageCount, (i) => i),
              );
              final inverted = allPages.difference(selectedPages);
              ref.read(selectedPagesProvider.notifier).state = inverted;
            },
          ),
        ],
      ),
    );
  }
}
```

### Step 3: Create Page Thumbnail Widget

**lib/features/extractor/presentation/widgets/page_thumbnail.dart:**

```dart
import 'dart:typed_data';
import 'package:flutter/material.dart';

class PageThumbnail extends StatelessWidget {
  final int pageIndex;
  final Uint8List? thumbnail;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const PageThumbnail({
    super.key,
    required this.pageIndex,
    required this.thumbnail,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? theme.colorScheme.primary
                : theme.colorScheme.outline.withOpacity(0.2),
            width: isSelected ? 3 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            // Thumbnail or loading placeholder
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: thumbnail != null
                    ? Image.memory(
                        thumbnail!,
                        fit: BoxFit.cover,
                      )
                    : Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
              ),
            ),

            // Selection indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 150),
              top: isSelected ? 6 : -20,
              left: 6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: isSelected ? 1 : 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check,
                    size: 16,
                    color: theme.colorScheme.onPrimary,
                  ),
                ),
              ),
            ),

            // Page number badge
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${pageIndex + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 4: Add Extraction Provider

Update **lib/core/providers/app_providers.dart** - add extraction state:

```dart
// Add these providers to the existing file

// Extraction state
final isExtractingProvider = StateProvider<bool>((ref) => false);
final extractionProgressProvider = StateProvider<double>((ref) => 0);

// Extraction notifier
final extractionNotifierProvider =
    StateNotifierProvider<ExtractionNotifier, ExtractionState>((ref) {
  return ExtractionNotifier(ref.read(pdfServiceProvider));
});

class ExtractionState {
  final bool isExtracting;
  final double progress;
  final String? outputPath;
  final String? error;

  const ExtractionState({
    this.isExtracting = false,
    this.progress = 0,
    this.outputPath,
    this.error,
  });

  ExtractionState copyWith({
    bool? isExtracting,
    double? progress,
    String? outputPath,
    String? error,
  }) =>
      ExtractionState(
        isExtracting: isExtracting ?? this.isExtracting,
        progress: progress ?? this.progress,
        outputPath: outputPath ?? this.outputPath,
        error: error ?? this.error,
      );
}

class ExtractionNotifier extends StateNotifier<ExtractionState> {
  final PdfService _pdfService;

  ExtractionNotifier(this._pdfService) : super(const ExtractionState());

  Future<String?> extractPages({
    required String sourcePath,
    required Set<int> pageIndices,
    required String outputName,
  }) async {
    state = const ExtractionState(isExtracting: true, progress: 0);

    try {
      final file = await _pdfService.extractPages(
        sourcePath,
        pageIndices,
        outputName,
      );

      if (file != null) {
        state = ExtractionState(
          isExtracting: false,
          progress: 1,
          outputPath: file.path,
        );
        return file.path;
      } else {
        state = const ExtractionState(
          isExtracting: false,
          error: 'Failed to extract pages',
        );
        return null;
      }
    } catch (e) {
      state = ExtractionState(
        isExtracting: false,
        error: e.toString(),
      );
      return null;
    }
  }

  void reset() {
    state = const ExtractionState();
  }
}
```

### Step 5: Create Export Bottom Sheet

**lib/features/extractor/presentation/widgets/export_sheet.dart:**

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

class ExportSheet extends StatelessWidget {
  final String filePath;
  final String fileName;

  const ExportSheet({
    super.key,
    required this.filePath,
    required this.fileName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check,
              size: 48,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'PDF Created!',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            fileName,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 24),

          // Share button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await Share.shareXFiles(
                  [XFile(filePath)],
                  subject: fileName,
                );
              },
              icon: const Icon(Icons.share),
              label: const Text('Share'),
            ),
          ),

          const SizedBox(height: 12),

          // Save to Files button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                // On iOS, sharing to Files app
                // On Android, sharing allows saving
                await Share.shareXFiles(
                  [XFile(filePath)],
                  subject: fileName,
                );
              },
              icon: const Icon(Icons.folder),
              label: const Text('Save to Files'),
            ),
          ),

          const SizedBox(height: 12),

          // Done button
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context); // Also pop extractor screen
              },
              child: const Text('Done'),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
```

### Step 6: Update Extractor Screen

**lib/features/extractor/presentation/screens/extractor_screen.dart:**

Replace with updated version:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import '../widgets/page_thumbnail.dart';
import '../widgets/selection_controls.dart';
import '../widgets/export_sheet.dart';

class ExtractorScreen extends ConsumerWidget {
  const ExtractorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(currentDocumentProvider);
    final selectedPages = ref.watch(selectedPagesProvider);
    final extractionState = ref.watch(extractionNotifierProvider);
    final theme = Theme.of(context);

    if (document == null) {
      return const Scaffold(
        body: Center(child: Text('No document loaded')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          document.name,
          overflow: TextOverflow.ellipsis,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            ref.read(currentDocumentProvider.notifier).clear();
            ref.read(selectedPagesProvider.notifier).state = {};
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Selection controls
          const SelectionControls(),

          // Page grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: document.pageCount,
              itemBuilder: (context, index) {
                final isSelected = selectedPages.contains(index);
                final thumbnail = document.thumbnails[index];

                return PageThumbnail(
                  pageIndex: index,
                  thumbnail: thumbnail,
                  isSelected: isSelected,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final current = ref.read(selectedPagesProvider);
                    if (current.contains(index)) {
                      ref.read(selectedPagesProvider.notifier).state =
                          Set.from(current)..remove(index);
                    } else {
                      ref.read(selectedPagesProvider.notifier).state =
                          Set.from(current)..add(index);
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    // Show page preview dialog
                    _showPagePreview(context, ref, index);
                  },
                );
              },
            ),
          ),
        ],
      ),

      // Extract FAB
      floatingActionButton: selectedPages.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: extractionState.isExtracting
                  ? null
                  : () => _extractPages(context, ref),
              icon: extractionState.isExtracting
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    )
                  : const Icon(Icons.download),
              label: Text(
                extractionState.isExtracting
                    ? 'Extracting...'
                    : 'Extract ${selectedPages.length} ${selectedPages.length == 1 ? "page" : "pages"}',
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  void _showPagePreview(BuildContext context, WidgetRef ref, int index) {
    final document = ref.read(currentDocumentProvider);
    if (document == null) return;

    final thumbnail = document.thumbnails[index];
    if (thumbnail == null) return;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              title: Text('Page ${index + 1}'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.memory(thumbnail),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _extractPages(BuildContext context, WidgetRef ref) async {
    final document = ref.read(currentDocumentProvider);
    final selectedPages = ref.read(selectedPagesProvider);

    if (document == null || selectedPages.isEmpty) return;

    // Generate output filename
    final baseName = document.name.replaceAll('.pdf', '');
    final pageList = _formatPageList(selectedPages);
    final outputName = '${baseName}_pages_$pageList.pdf';

    final outputPath = await ref.read(extractionNotifierProvider.notifier).extractPages(
      sourcePath: document.path,
      pageIndices: selectedPages,
      outputName: outputName,
    );

    if (outputPath != null && context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ExportSheet(
          filePath: outputPath,
          fileName: outputName,
        ),
      );
    }
  }

  String _formatPageList(Set<int> pages) {
    if (pages.isEmpty) return '';

    final sorted = pages.toList()..sort();

    // For simple cases, just list pages
    if (sorted.length <= 3) {
      return sorted.map((p) => p + 1).join('-');
    }

    // For ranges, simplify
    final first = sorted.first + 1;
    final last = sorted.last + 1;

    // Check if it's a continuous range
    bool isContinuous = true;
    for (int i = 1; i < sorted.length; i++) {
      if (sorted[i] - sorted[i - 1] != 1) {
        isContinuous = false;
        break;
      }
    }

    if (isContinuous) {
      return '$first-$last';
    } else {
      return '${sorted.length}pages';
    }
  }
}
```

### Step 7: Update PDF Service for better extraction

Update **lib/core/services/pdf_service.dart** to improve extraction:

```dart
// Add this improved extraction method

Future<File?> extractPagesOptimized(
  String sourcePath,
  Set<int> pageIndices,
  String outputName, {
  void Function(int current, int total)? onProgress,
}) async {
  try {
    final sourceDoc = await PdfDocument.openFile(sourcePath);
    final pdf = pw.Document();
    final sortedIndices = pageIndices.toList()..sort();
    final total = sortedIndices.length;

    for (int i = 0; i < total; i++) {
      final index = sortedIndices[i];
      final page = await sourceDoc.getPage(index + 1);

      // Render at source resolution for quality
      final scale = 2.0; // Higher = better quality
      final image = await page.render(
        width: (page.width * scale).toInt(),
        height: (page.height * scale).toInt(),
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );

      if (image?.bytes != null) {
        final pdfImage = pw.MemoryImage(image!.bytes);
        pdf.addPage(
          pw.Page(
            pageFormat: PdfPageFormat(page.width, page.height),
            margin: pw.EdgeInsets.zero,
            build: (context) => pw.Center(
              child: pw.Image(pdfImage, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      await page.close();
      onProgress?.call(i + 1, total);
    }

    await sourceDoc.close();

    // Save output
    final tempDir = await getTemporaryDirectory();
    final outputPath = '${tempDir.path}/$outputName';
    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(await pdf.save());

    return outputFile;
  } catch (e) {
    print('Error extracting pages: $e');
    return null;
  }
}
```

---

## Expected Outcome

1. ✅ Range selection dialog (e.g., "1-5, 8, 11-15")
2. ✅ Selection controls (select all, clear, invert)
3. ✅ Beautiful animated page thumbnails
4. ✅ Page preview on long-press
5. ✅ Extraction with progress indication
6. ✅ Export/share bottom sheet
7. ✅ Haptic feedback on interactions

**Test:**
```bash
flutter run
```

Open a PDF, select various pages using tap and range dialog, extract, and share the result.

---

## Next Prompt

Prompt 3 will add usage tracking, RevenueCat premium, and the paywall.
