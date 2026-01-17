import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing selected PDF page numbers
/// Uses 1-indexed page numbers to match pdfx convention
final selectedPagesProvider = StateNotifierProvider<SelectedPagesNotifier, Set<int>>((ref) {
  return SelectedPagesNotifier();
});

class SelectedPagesNotifier extends StateNotifier<Set<int>> {
  SelectedPagesNotifier() : super({});

  /// Toggle selection of a page number
  /// Adds page if not selected, removes if already selected
  void togglePage(int pageNumber) {
    state = Set<int>.from(state);
    if (state.contains(pageNumber)) {
      state.remove(pageNumber);
    } else {
      state.add(pageNumber);
    }
  }

  /// Clear all selected pages
  void clearSelection() {
    state = {};
  }

  /// Select all pages up to a given maximum
  void selectAll(int maxPages) {
    state = Set<int>.from(List.generate(maxPages, (index) => index + 1));
  }

  /// Invert current selection (0-indexed)
  void invertSelection(int maxPages) {
    final allPages = Set.from(List.generate(maxPages, (index) => index + 1));
    state = Set<int>.from(allPages.difference(state));
  }
}