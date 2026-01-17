import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_pages/main.dart';

void main() {
  testWidgets('Home page displays correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify the home page UI elements are present
    expect(find.text('Extract PDF Pages'), findsOneWidget);
    expect(find.text('Select a PDF to extract specific pages'), findsOneWidget);
    expect(find.text('Select PDF'), findsOneWidget);
    expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
  });
}
