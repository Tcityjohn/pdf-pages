# PDF Pages Build Prompt 1: Project Setup & PDF Loading
## Day 1 Morning (3-4 hours)

---

## Context for Claude

You are building a cross-platform PDF page extractor using Flutter. Users can open a PDF, select specific pages, and create a new PDF with just those pages. All processing is local - no cloud uploads.

**Target platforms:** iOS and Android
**Revenue model:** Free (3 extractions/month), $9.99/year unlimited
**Key differentiator:** Privacy (offline), simplicity (one purpose), affordable

---

## Task: Create the Flutter project with PDF loading and thumbnail generation

### Step 1: Create the Flutter Project

```bash
flutter create --org com.quickhitter pdf_pages
cd pdf_pages
```

### Step 2: Set up dependencies

Update `pubspec.yaml`:

```yaml
name: pdf_pages
description: Extract pages from PDF documents
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.9
  pdfx: ^2.6.0
  pdf: ^3.10.8
  file_picker: ^8.0.0
  share_plus: ^7.2.2
  path_provider: ^2.1.2
  purchases_flutter: ^6.29.0
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
```

### Step 3: Configure platform permissions

**iOS - ios/Runner/Info.plist:**
```xml
<key>UISupportsDocumentBrowser</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>PDF Document</string>
        <key>LSHandlerRank</key>
        <string>Default</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.adobe.pdf</string>
        </array>
    </dict>
</array>
```

**Android - android/app/src/main/AndroidManifest.xml:**
Add inside `<application>`:
```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.fileprovider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/file_paths" />
</provider>
```

**android/app/src/main/res/xml/file_paths.xml:**
```xml
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <cache-path name="cache" path="." />
    <files-path name="files" path="." />
</paths>
```

### Step 4: Create project structure

```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── models/
│   │   └── pdf_document.dart
│   ├── services/
│   │   ├── pdf_service.dart
│   │   ├── usage_service.dart
│   │   └── purchase_service.dart
│   └── providers/
│       └── app_providers.dart
├── features/
│   └── extractor/
│       └── presentation/
│           ├── screens/
│           │   ├── home_screen.dart
│           │   └── extractor_screen.dart
│           └── widgets/
│               ├── page_thumbnail.dart
│               └── selection_controls.dart
└── shared/
    └── widgets/
        └── paywall.dart
```

### Step 5: Create PDF Document model

**lib/core/models/pdf_document.dart:**

```dart
import 'dart:typed_data';

class PdfDocumentModel {
  final String name;
  final String path;
  final int pageCount;
  final Map<int, Uint8List?> thumbnails;

  PdfDocumentModel({
    required this.name,
    required this.path,
    required this.pageCount,
    this.thumbnails = const {},
  });

  PdfDocumentModel copyWith({
    String? name,
    String? path,
    int? pageCount,
    Map<int, Uint8List?>? thumbnails,
  }) =>
      PdfDocumentModel(
        name: name ?? this.name,
        path: path ?? this.path,
        pageCount: pageCount ?? this.pageCount,
        thumbnails: thumbnails ?? this.thumbnails,
      );
}
```

### Step 6: Create PDF Service

**lib/core/services/pdf_service.dart:**

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:pdfx/pdfx.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/pdf_document.dart';

class PdfService {
  PdfDocument? _document;

  Future<PdfDocumentModel?> pickAndLoadPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) return null;

      final file = result.files.first;
      if (file.path == null) return null;

      return await loadPdf(file.path!, file.name);
    } catch (e) {
      print('Error picking PDF: $e');
      return null;
    }
  }

  Future<PdfDocumentModel?> loadPdf(String path, String name) async {
    try {
      _document?.close();
      _document = await PdfDocument.openFile(path);

      return PdfDocumentModel(
        name: name,
        path: path,
        pageCount: _document!.pagesCount,
      );
    } catch (e) {
      print('Error loading PDF: $e');
      return null;
    }
  }

  Future<Uint8List?> generateThumbnail(int pageIndex, {int width = 150}) async {
    if (_document == null) return null;

    try {
      final page = await _document!.getPage(pageIndex + 1); // 1-indexed
      final image = await page.render(
        width: width,
        height: (width * 1.4).toInt(), // Approximate A4 ratio
        format: PdfPageImageFormat.png,
        backgroundColor: '#FFFFFF',
      );
      await page.close();
      return image?.bytes;
    } catch (e) {
      print('Error generating thumbnail for page $pageIndex: $e');
      return null;
    }
  }

  Future<Map<int, Uint8List?>> generateAllThumbnails(int pageCount) async {
    final thumbnails = <int, Uint8List?>{};

    for (int i = 0; i < pageCount; i++) {
      thumbnails[i] = await generateThumbnail(i);
    }

    return thumbnails;
  }

  Future<File?> extractPages(
    String sourcePath,
    Set<int> pageIndices,
    String outputName,
  ) async {
    try {
      // Load source PDF
      final sourceDoc = await PdfDocument.openFile(sourcePath);

      // Create new PDF document
      final pdf = pw.Document();

      // Get sorted page indices
      final sortedIndices = pageIndices.toList()..sort();

      // For each selected page, render and add to new document
      for (final index in sortedIndices) {
        final page = await sourceDoc.getPage(index + 1);

        // Render at high quality
        final image = await page.render(
          width: page.width.toInt() * 2,
          height: page.height.toInt() * 2,
          format: PdfPageImageFormat.png,
        );

        if (image?.bytes != null) {
          final pdfImage = pw.MemoryImage(image!.bytes);
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                page.width,
                page.height,
              ),
              build: (context) => pw.Image(pdfImage, fit: pw.BoxFit.contain),
            ),
          );
        }

        await page.close();
      }

      await sourceDoc.close();

      // Save to temp directory
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

  void close() {
    _document?.close();
    _document = null;
  }
}
```

### Step 7: Create Riverpod providers

**lib/core/providers/app_providers.dart:**

```dart
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/pdf_document.dart';
import '../services/pdf_service.dart';

// PDF Service
final pdfServiceProvider = Provider<PdfService>((ref) {
  final service = PdfService();
  ref.onDispose(() => service.close());
  return service;
});

// Current document
final currentDocumentProvider =
    StateNotifierProvider<DocumentNotifier, PdfDocumentModel?>((ref) {
  return DocumentNotifier(ref.read(pdfServiceProvider));
});

class DocumentNotifier extends StateNotifier<PdfDocumentModel?> {
  final PdfService _pdfService;

  DocumentNotifier(this._pdfService) : super(null);

  Future<bool> pickAndLoad() async {
    final doc = await _pdfService.pickAndLoadPdf();
    if (doc != null) {
      state = doc;
      // Start generating thumbnails
      _generateThumbnails(doc.pageCount);
      return true;
    }
    return false;
  }

  Future<void> _generateThumbnails(int pageCount) async {
    for (int i = 0; i < pageCount; i++) {
      final thumbnail = await _pdfService.generateThumbnail(i);
      if (state != null) {
        final newThumbnails = Map<int, Uint8List?>.from(state!.thumbnails);
        newThumbnails[i] = thumbnail;
        state = state!.copyWith(thumbnails: newThumbnails);
      }
    }
  }

  void clear() {
    _pdfService.close();
    state = null;
  }
}

// Selected pages
final selectedPagesProvider = StateProvider<Set<int>>((ref) => {});

// Loading state
final isLoadingProvider = StateProvider<bool>((ref) => false);

// Premium status
final isPremiumProvider = StateProvider<bool>((ref) => false);
```

### Step 8: Create Home Screen

**lib/features/extractor/presentation/screens/home_screen.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';
import 'extractor_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isLoading = ref.watch(isLoadingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Pages'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.picture_as_pdf,
                  size: 64,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Extract PDF Pages',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              Text(
                'Select specific pages from any PDF\nand save them as a new document',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),

              const SizedBox(height: 12),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.lock,
                      size: 16,
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Your documents never leave your device',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Select PDF button
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          ref.read(isLoadingProvider.notifier).state = true;
                          ref.read(selectedPagesProvider.notifier).state = {};

                          final success = await ref
                              .read(currentDocumentProvider.notifier)
                              .pickAndLoad();

                          ref.read(isLoadingProvider.notifier).state = false;

                          if (success && context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ExtractorScreen(),
                              ),
                            );
                          }
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.folder_open),
                  label: Text(isLoading ? 'Loading...' : 'Select PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

### Step 9: Create placeholder Extractor Screen

**lib/features/extractor/presentation/screens/extractor_screen.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/app_providers.dart';

class ExtractorScreen extends ConsumerWidget {
  const ExtractorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final document = ref.watch(currentDocumentProvider);
    final selectedPages = ref.watch(selectedPagesProvider);
    final theme = Theme.of(context);

    if (document == null) {
      return const Scaffold(
        body: Center(child: Text('No document loaded')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(document.name, overflow: TextOverflow.ellipsis),
        actions: [
          TextButton(
            onPressed: selectedPages.isEmpty ? null : () {
              // TODO: Extract pages
            },
            child: Text('Extract (${selectedPages.length})'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Selection info bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Row(
              children: [
                Text(
                  '${document.pageCount} pages',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    // Select all
                    ref.read(selectedPagesProvider.notifier).state =
                        Set.from(List.generate(document.pageCount, (i) => i));
                  },
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: selectedPages.isEmpty
                      ? null
                      : () {
                          ref.read(selectedPagesProvider.notifier).state = {};
                        },
                  child: const Text('Clear'),
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
                childAspectRatio: 0.7,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: document.pageCount,
              itemBuilder: (context, index) {
                final isSelected = selectedPages.contains(index);
                final thumbnail = document.thumbnails[index];

                return GestureDetector(
                  onTap: () {
                    final current = ref.read(selectedPagesProvider);
                    if (current.contains(index)) {
                      ref.read(selectedPagesProvider.notifier).state =
                          Set.from(current)..remove(index);
                    } else {
                      ref.read(selectedPagesProvider.notifier).state =
                          Set.from(current)..add(index);
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                      border: isSelected
                          ? Border.all(
                              color: theme.colorScheme.primary,
                              width: 3,
                            )
                          : null,
                    ),
                    child: Stack(
                      children: [
                        // Thumbnail or placeholder
                        if (thumbnail != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.memory(
                              thumbnail,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          )
                        else
                          const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),

                        // Page number
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),

                        // Selection checkbox
                        if (isSelected)
                          Positioned(
                            top: 4,
                            left: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 16,
                                color: theme.colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

### Step 10: Create main app entry

**lib/main.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: PdfPagesApp(),
    ),
  );
}
```

**lib/app.dart:**

```dart
import 'package:flutter/material.dart';
import 'features/extractor/presentation/screens/home_screen.dart';

class PdfPagesApp extends StatelessWidget {
  const PdfPagesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Pages',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935), // PDF red
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}
```

---

## Expected Outcome

1. ✅ Flutter project with PDF dependencies
2. ✅ File picker for selecting PDFs
3. ✅ PDF loading and page counting
4. ✅ Thumbnail generation for each page
5. ✅ Basic page grid with selection
6. ✅ Privacy-focused messaging

**Test:**
```bash
flutter run
```

Select a PDF from your device. You should see thumbnails generating for each page. Tap pages to select/deselect.

---

## Next Prompt

Prompt 2 will add extraction logic, range selection, and export/share.
