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
}

/// Exception thrown when a PDF cannot be loaded
class PdfLoadException implements Exception {
  final String message;

  PdfLoadException(this.message);

  @override
  String toString() => message;
}
