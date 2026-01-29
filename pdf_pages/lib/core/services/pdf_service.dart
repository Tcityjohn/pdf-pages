import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' hide PdfDocument;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';

/// Service for loading and managing PDF documents
/// Uses pdfx package which provides 1-indexed page numbers
class PdfService {
  PdfDocument? _currentDocument;

  /// Gets the currently loaded document (if any)
  /// Returns null if no document is loaded
  PdfDocument? get currentDocument => _currentDocument;

  /// Loads a PDF from the given file path
  /// Returns the number of pages in the document
  /// Throws [PdfLoadException] if the PDF is invalid, corrupted, or encrypted
  Future<int> loadPdf(String filePath) async {
    try {
      // Close any previously loaded document
      await closeDocument();

      // Load the PDF document
      _currentDocument = await PdfDocument.openFile(filePath);

      // Get page count
      final pageCount = _currentDocument!.pagesCount;

      if (pageCount <= 0) {
        throw PdfLoadException('PDF has no pages');
      }

      return pageCount;
    } catch (e) {
      // Handle any errors (encrypted, corrupted, file not found, permissions, etc.)
      _currentDocument = null;

      // Check if it's a common PDF error
      final errorMessage = e.toString().toLowerCase();
      if (errorMessage.contains('password') || errorMessage.contains('encrypted')) {
        throw PdfLoadException('This PDF is password-protected');
      } else if (errorMessage.contains('corrupted') || errorMessage.contains('invalid')) {
        throw PdfLoadException('This PDF is corrupted or invalid');
      } else {
        throw PdfLoadException('Failed to load PDF: ${e.toString()}');
      }
    }
  }

  /// Closes the currently loaded document and frees memory
  /// Safe to call even if no document is loaded
  Future<void> closeDocument() async {
    if (_currentDocument != null) {
      // Note: PdfDocument doesn't have an explicit close method
      // Setting to null allows garbage collection
      _currentDocument = null;
    }
  }

  /// Returns true if a document is currently loaded
  bool get hasDocument => _currentDocument != null;

  /// Generates a thumbnail for the given page number (1-indexed)
  /// Returns PNG bytes at 150px width
  /// Throws [PdfLoadException] if no document is loaded
  Future<Uint8List> generateThumbnail(int pageNumber) async {
    if (_currentDocument == null) {
      throw PdfLoadException('No document loaded');
    }

    final page = await _currentDocument!.getPage(pageNumber);
    try {
      // Render at 150px width, ~1.4 aspect ratio for A4
      final pageImage = await page.render(
        width: 150,
        height: 212,
        format: PdfPageImageFormat.png,
      );
      return pageImage!.bytes;
    } finally {
      await page.close(); // Always close to free memory
    }
  }

  /// Generates a larger preview thumbnail for the given page number (1-indexed)
  /// Returns PNG bytes at 300px width (2x resolution for preview dialog)
  /// Throws [PdfLoadException] if no document is loaded
  Future<Uint8List> generatePreviewThumbnail(int pageNumber) async {
    if (_currentDocument == null) {
      throw PdfLoadException('No document loaded');
    }

    final page = await _currentDocument!.getPage(pageNumber);
    try {
      // Render at 2x: 300x424 for crisp preview
      final pageImage = await page.render(
        width: 300,
        height: 424,
        format: PdfPageImageFormat.png,
      );
      return pageImage!.bytes;
    } finally {
      await page.close(); // Always close to free memory
    }
  }

  /// Extracts selected pages into a new PDF document
  /// [pageNumbers] - Set of 1-indexed page numbers to extract
  /// [customOrder] - Optional list specifying the order of pages (if null, ascending order is used)
  /// [customFileName] - Optional custom filename for the output (without .pdf extension)
  /// [onProgress] - Optional callback for progress updates (current, total)
  /// Returns the file path of the created PDF in the temp directory
  /// Throws [PdfLoadException] if extraction fails
  Future<String> extractPages(
    Set<int> pageNumbers, {
    List<int>? customOrder,
    String? customFileName,
    void Function(int current, int total)? onProgress,
  }) async {
    if (_currentDocument == null) {
      throw PdfLoadException('No document loaded');
    }

    if (pageNumbers.isEmpty) {
      throw PdfLoadException('No pages selected for extraction');
    }

    try {
      // Use custom order if provided and valid, otherwise sort ascending
      final List<int> sortedPages;
      if (customOrder != null &&
          customOrder.toSet().containsAll(pageNumbers) &&
          pageNumbers.containsAll(customOrder.toSet())) {
        sortedPages = customOrder;
      } else {
        sortedPages = pageNumbers.toList()..sort();
      }

      // Create new PDF document using the pdf package
      final pdf = pw.Document();

      // Process pages one at a time for memory efficiency
      for (int i = 0; i < sortedPages.length; i++) {
        final pageNumber = sortedPages[i];

        // Report progress
        onProgress?.call(i + 1, sortedPages.length);

        // Render page at 2x quality for crisp output
        // Using 300x424 for ~1.4 aspect ratio (A4)
        final page = await _currentDocument!.getPage(pageNumber);
        try {
          final pageImage = await page.render(
            width: 300,
            height: 424,
            format: PdfPageImageFormat.png,
          );

          if (pageImage == null || pageImage.bytes.isEmpty) {
            throw PdfLoadException('Failed to render page $pageNumber');
          }

          // Create memory image from rendered bytes
          final memoryImage = pw.MemoryImage(pageImage.bytes);

          // Add page to new PDF
          pdf.addPage(
            pw.Page(
              pageFormat: PdfPageFormat.a4,
              build: (context) => pw.Center(
                child: pw.Image(memoryImage),
              ),
            ),
          );
        } finally {
          await page.close(); // Free memory after each page
        }
      }

      // Save to temp directory with custom or timestamp-based filename
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = customFileName != null
          ? '${customFileName.replaceAll(RegExp(r'[^\w\s-]'), '')}.pdf'
          : 'extracted_$timestamp.pdf';
      final outputPath = '${tempDir.path}/$fileName';

      final file = File(outputPath);
      await file.writeAsBytes(await pdf.save());

      return outputPath;
    } catch (e) {
      if (e is PdfLoadException) {
        rethrow;
      }
      throw PdfLoadException('Failed to extract pages: ${e.toString()}');
    }
  }
}

/// Exception thrown when a PDF cannot be loaded
class PdfLoadException implements Exception {
  final String message;

  PdfLoadException(this.message);

  @override
  String toString() => message;
}
