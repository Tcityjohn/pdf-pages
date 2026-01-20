import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../providers/selection_provider.dart';

/// Enum representing preset selection types
enum PresetType {
  first('First', Icons.first_page),
  last('Last', Icons.last_page),
  odd('Odd', Icons.format_list_numbered),
  even('Even', Icons.format_list_numbered_rtl),
  first3('First 3', Icons.looks_3),
  last3('Last 3', Icons.looks_3);

  final String label;
  final IconData icon;
  const PresetType(this.label, this.icon);
}

/// Computes the set of pages for a given preset type
Set<int> computePresetPages(PresetType preset, int pageCount) {
  switch (preset) {
    case PresetType.first:
      return pageCount >= 1 ? {1} : {};
    case PresetType.last:
      return pageCount >= 1 ? {pageCount} : {};
    case PresetType.odd:
      return {for (int i = 1; i <= pageCount; i += 2) i};
    case PresetType.even:
      return {for (int i = 2; i <= pageCount; i += 2) i};
    case PresetType.first3:
      final count = pageCount.clamp(0, 3);
      return {for (int i = 1; i <= count; i++) i};
    case PresetType.last3:
      final start = (pageCount - 2).clamp(1, pageCount);
      return {for (int i = start; i <= pageCount; i++) i};
  }
}

/// Horizontally scrollable bar of preset selection chips
class PresetChipsBar extends ConsumerWidget {
  final int pageCount;

  const PresetChipsBar({
    super.key,
    required this.pageCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPages = ref.watch(selectedPagesProvider);

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withOpacity(0.06),
            width: 1,
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: PresetType.values.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final preset = PresetType.values[index];
          final presetPages = computePresetPages(preset, pageCount);

          // Check if this preset matches current selection
          final isActive = selectedPages.isNotEmpty &&
              selectedPages.length == presetPages.length &&
              selectedPages.containsAll(presetPages);

          // Check if preset is available (has pages to select)
          final isAvailable = presetPages.isNotEmpty;

          return _PresetChip(
            preset: preset,
            isActive: isActive,
            isAvailable: isAvailable,
            onTap: isAvailable
                ? () {
                    HapticFeedback.lightImpact();
                    ref.read(selectedPagesProvider.notifier).setSelection(presetPages);
                  }
                : null,
          );
        },
      ),
    );
  }
}

/// Individual preset chip widget
class _PresetChip extends StatelessWidget {
  final PresetType preset;
  final bool isActive;
  final bool isAvailable;
  final VoidCallback? onTap;

  const _PresetChip({
    required this.preset,
    required this.isActive,
    required this.isAvailable,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.primary
              : isAvailable
                  ? AppColors.primaryPale.withOpacity(0.5)
                  : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : isAvailable
                    ? AppColors.primaryPale
                    : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              preset.icon,
              size: 14,
              color: isActive
                  ? Colors.white
                  : isAvailable
                      ? AppColors.primary
                      : Colors.grey,
            ),
            const SizedBox(width: 4),
            Text(
              preset.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? Colors.white
                    : isAvailable
                        ? AppColors.textPrimary
                        : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
