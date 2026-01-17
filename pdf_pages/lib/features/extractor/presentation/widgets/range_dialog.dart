import 'package:flutter/material.dart';

/// Dialog widget for selecting pages by entering ranges like '1-5, 8, 11-15'
class RangeSelectionDialog extends StatefulWidget {
  /// Total number of pages in the PDF
  final int pageCount;

  /// Callback when user confirms the selection
  final Function(Set<int>) onConfirm;

  const RangeSelectionDialog({
    super.key,
    required this.pageCount,
    required this.onConfirm,
  });

  @override
  State<RangeSelectionDialog> createState() => _RangeSelectionDialogState();
}

class _RangeSelectionDialogState extends State<RangeSelectionDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;
  bool _isValid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Parse the input string and return a set of valid page numbers
  Set<int> _parsePageRange(String input) {
    final result = <int>{};

    if (input.trim().isEmpty) {
      return result;
    }

    // Split by comma
    final parts = input.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty);

    for (final part in parts) {
      if (part.contains('-')) {
        // Range: "1-5"
        final rangeParts = part.split('-');
        if (rangeParts.length == 2) {
          final start = int.tryParse(rangeParts[0].trim());
          final end = int.tryParse(rangeParts[1].trim());
          if (start != null && end != null && start <= end && start > 0) {
            for (int i = start; i <= end; i++) {
              if (i >= 1 && i <= widget.pageCount) {
                result.add(i);
              }
            }
          } else {
            // Invalid range
            throw FormatException('Invalid range: $part');
          }
        } else {
          // Invalid format
          throw FormatException('Invalid format: $part');
        }
      } else {
        // Single page: "8"
        final page = int.tryParse(part);
        if (page != null && page >= 1 && page <= widget.pageCount) {
          result.add(page);
        } else if (page != null) {
          throw FormatException('Page $page is out of range (1-${widget.pageCount})');
        } else {
          throw FormatException('Invalid page number: $part');
        }
      }
    }

    return result;
  }

  /// Validate the current input
  void _validateInput() {
    final input = _controller.text;

    if (input.trim().isEmpty) {
      setState(() {
        _errorText = null;
        _isValid = false;
      });
      return;
    }

    try {
      final pages = _parsePageRange(input);
      setState(() {
        _errorText = null;
        _isValid = pages.isNotEmpty;
      });
    } catch (e) {
      setState(() {
        _errorText = e.toString().replaceFirst('FormatException: ', '');
        _isValid = false;
      });
    }
  }

  void _onConfirm() {
    if (_isValid) {
      final pages = _parsePageRange(_controller.text);
      widget.onConfirm(pages);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      contentPadding: EdgeInsets.zero,
      content: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Dialog content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  const Text(
                    'Select Pages',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subtitle
                  const Text(
                    'Enter page numbers or ranges:',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Input field
                  TextField(
                    controller: _controller,
                    onChanged: (_) => _validateInput(),
                    decoration: InputDecoration(
                      hintText: 'e.g., 1-5, 8, 11-15',
                      hintStyle: const TextStyle(
                        color: Color(0xFF757575),
                      ),
                      errorText: _errorText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE53935),
                          width: 1,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Helper text
                  Text(
                    'Total pages: ${widget.pageCount}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF757575),
                    ),
                  ),
                ],
              ),
            ),

            // Dialog actions
            Padding(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Cancel button
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFE53935),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Select button
                  FilledButton(
                    onPressed: _isValid ? _onConfirm : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      disabledBackgroundColor: const Color(0xFFE0E0E0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                    ),
                    child: const Text(
                      'Select',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}