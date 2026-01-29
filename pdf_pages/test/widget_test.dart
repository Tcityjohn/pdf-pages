import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_pages/main.dart';

void main() {
  testWidgets('Home page displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify the home page UI elements are present (updated for new design)
    expect(find.text('Select a PDF'), findsOneWidget);
    expect(find.text('Extract Pages'), findsOneWidget);
    expect(find.text('Select PDF'), findsOneWidget);
  });
}
