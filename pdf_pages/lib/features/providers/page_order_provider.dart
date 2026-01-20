import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider for managing custom page order for extraction
/// When null, pages are extracted in ascending order
/// When set, pages are extracted in the specified custom order
final pageOrderProvider = StateNotifierProvider<PageOrderNotifier, List<int>?>((ref) {
  return PageOrderNotifier();
});

class PageOrderNotifier extends StateNotifier<List<int>?> {
  PageOrderNotifier() : super(null);

  /// Set custom order from a set of selected pages (initializes order)
  void initializeFromSelection(Set<int> selectedPages) {
    state = selectedPages.toList()..sort();
  }

  /// Set a specific custom order
  void setCustomOrder(List<int> order) {
    state = List<int>.from(order);
  }

  /// Clear custom order (revert to default ascending)
  void clearCustomOrder() {
    state = null;
  }

  /// Reorder pages by moving item from oldIndex to newIndex
  void reorder(int oldIndex, int newIndex) {
    if (state == null) return;

    final List<int> newOrder = List<int>.from(state!);

    // Adjust newIndex for removal offset
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = newOrder.removeAt(oldIndex);
    newOrder.insert(newIndex, item);

    state = newOrder;
  }

  /// Check if current order differs from default ascending order
  bool get hasCustomOrder {
    if (state == null) return false;
    final sorted = List<int>.from(state!)..sort();
    for (int i = 0; i < state!.length; i++) {
      if (state![i] != sorted[i]) return true;
    }
    return false;
  }

  /// Get the pages in current order (custom or sorted)
  List<int> getOrderedPages(Set<int> selectedPages) {
    if (state != null && state!.toSet().containsAll(selectedPages) && selectedPages.containsAll(state!.toSet())) {
      return state!;
    }
    // Fallback to sorted if custom order doesn't match selection
    return selectedPages.toList()..sort();
  }
}
