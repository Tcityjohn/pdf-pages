# PDF Pages Build Prompt 4: Edge Cases & App Store Submission
## Day 2 Afternoon (3-4 hours)

---

## Context for Claude

The app is functionally complete with extraction, usage limits, and premium. Now we handle edge cases and prepare for store submission.

---

## Task: Handle edge cases and prepare for submission

### Step 1: Handle Encrypted/Protected PDFs

Update **lib/core/services/pdf_service.dart** to detect encrypted PDFs:

```dart
// Add this method to PdfService class

Future<PdfLoadResult> loadPdfSafe(String path, String name) async {
  try {
    _document?.close();
    _document = await PdfDocument.openFile(path);

    // Check if document loaded successfully
    if (_document == null) {
      return PdfLoadResult.error('Could not open PDF');
    }

    // Check page count (protected PDFs often fail here)
    final pageCount = _document!.pagesCount;
    if (pageCount == 0) {
      return PdfLoadResult.error('PDF has no pages');
    }

    // Try to render first page (catches encryption issues)
    try {
      final testPage = await _document!.getPage(1);
      final testRender = await testPage.render(
        width: 100,
        height: 100,
        format: PdfPageImageFormat.png,
      );
      await testPage.close();

      if (testRender == null || testRender.bytes.isEmpty) {
        return PdfLoadResult.error(
          'This PDF appears to be password-protected or corrupted',
        );
      }
    } catch (e) {
      return PdfLoadResult.error(
        'Cannot read PDF pages. The file may be encrypted.',
      );
    }

    return PdfLoadResult.success(
      PdfDocumentModel(
        name: name,
        path: path,
        pageCount: pageCount,
      ),
    );
  } catch (e) {
    if (e.toString().contains('password') ||
        e.toString().contains('encrypted')) {
      return PdfLoadResult.error(
        'This PDF is password-protected. Please remove the password first.',
      );
    }
    return PdfLoadResult.error('Error loading PDF: ${e.toString()}');
  }
}

// Add this class
class PdfLoadResult {
  final PdfDocumentModel? document;
  final String? error;
  final bool isSuccess;

  PdfLoadResult._({this.document, this.error, required this.isSuccess});

  factory PdfLoadResult.success(PdfDocumentModel document) =>
      PdfLoadResult._(document: document, isSuccess: true);

  factory PdfLoadResult.error(String message) =>
      PdfLoadResult._(error: message, isSuccess: false);
}
```

### Step 2: Add Error Handling UI

**lib/shared/widgets/error_dialog.dart:**

```dart
import 'package:flutter/material.dart';

class ErrorDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorDialog({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onRetry,
  }) {
    return showDialog(
      context: context,
      builder: (_) => ErrorDialog(
        title: title,
        message: message,
        onRetry: onRetry,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      icon: Icon(
        Icons.error_outline,
        color: theme.colorScheme.error,
        size: 48,
      ),
      title: Text(title),
      content: Text(
        message,
        textAlign: TextAlign.center,
      ),
      actions: [
        if (onRetry != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onRetry!();
            },
            child: const Text('Try Again'),
          ),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
```

### Step 3: Handle Large PDFs

Update extraction to show progress for large PDFs:

**lib/features/extractor/presentation/widgets/extraction_progress_dialog.dart:**

```dart
import 'package:flutter/material.dart';

class ExtractionProgressDialog extends StatelessWidget {
  final int currentPage;
  final int totalPages;

  const ExtractionProgressDialog({
    super.key,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = currentPage / totalPages;

    return AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(value: progress),
          const SizedBox(height: 24),
          Text(
            'Extracting pages...',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Page $currentPage of $totalPages',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(value: progress),
        ],
      ),
    );
  }
}
```

### Step 4: Add Settings Screen

**lib/features/settings/presentation/screens/settings_screen.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/providers/app_providers.dart';
import '../../../../shared/widgets/paywall.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPremium = ref.watch(isPremiumSyncProvider);
    final remaining = ref.watch(remainingExtractionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Premium status
          if (isPremium)
            _buildTile(
              context,
              icon: Icons.workspace_premium,
              iconColor: theme.colorScheme.primary,
              title: 'Premium Active',
              subtitle: 'Unlimited extractions',
            )
          else
            _buildTile(
              context,
              icon: Icons.workspace_premium,
              iconColor: theme.colorScheme.primary,
              title: 'Upgrade to Premium',
              subtitle: '$remaining free extractions remaining',
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => const Paywall(),
                );
              },
            ),

          const Divider(),

          // Restore purchases
          _buildTile(
            context,
            icon: Icons.restore,
            title: 'Restore Purchases',
            onTap: () async {
              final purchaseService = ref.read(purchaseServiceProvider);
              final success = await purchaseService.restorePurchases();

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Purchases restored!'
                          : 'No purchases to restore',
                    ),
                  ),
                );
              }
            },
          ),

          const Divider(),

          // Privacy policy
          _buildTile(
            context,
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            onTap: () {
              launchUrl(
                Uri.parse('https://yourusername.github.io/pdfpages-privacy'),
              );
            },
          ),

          // Terms of use
          _buildTile(
            context,
            icon: Icons.description_outlined,
            title: 'Terms of Use',
            onTap: () {
              launchUrl(
                Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
              );
            },
          ),

          const Divider(),

          // About
          _buildTile(
            context,
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Version 1.0.0',
          ),

          // Privacy note
          Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              '🔒 Your PDFs never leave your device.\nAll processing happens locally.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: onTap != null
          ? Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            )
          : null,
      onTap: onTap,
    );
  }
}
```

### Step 5: Update Home Screen with Settings

Add settings button to **home_screen.dart**:

```dart
// Update AppBar
appBar: AppBar(
  title: const Text('PDF Pages'),
  centerTitle: true,
  actions: [
    IconButton(
      icon: const Icon(Icons.settings_outlined),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
      },
    ),
  ],
),
```

### Step 6: App Icon

**Design concept:** PDF document with extraction/selection indicator

**AI Prompt:**
> "App icon for a PDF page extractor app, minimal flat design, PDF document icon with corner folded and extraction arrow, red gradient background (#E53935), white icon, modern iOS style, 1024x1024"

**flutter_launcher_icons config - pubspec.yaml:**
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1

flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/app_icon.png"
  adaptive_icon_background: "#E53935"
  adaptive_icon_foreground: "assets/icon/app_icon_foreground.png"
```

Run:
```bash
flutter pub run flutter_launcher_icons
```

### Step 7: App Store Metadata

**App Name (30 chars):**
```
PDF Pages - Extract & Split
```

**Subtitle (30 chars):**
```
Select Pages, Create New PDF
```

**Keywords (100 chars, iOS):**
```
pdf,extract,pages,split,merge,document,editor,select,privacy,offline,local,converter,reader,file
```

**Short Description (80 chars, Google Play):**
```
Extract specific pages from any PDF. All processing happens on your device.
```

**Full Description:**
```
PDF Pages lets you extract specific pages from any PDF and save them as a new document. All processing happens locally on your device - your documents never leave your phone.

🔒 PRIVACY FIRST

Unlike web-based PDF tools, PDF Pages processes everything on your device. Your confidential documents, contracts, and personal files stay private. No uploads, no cloud, no tracking.

📄 SIMPLE PAGE EXTRACTION

1. Open any PDF
2. Tap to select pages (or use range selection: "1-5, 8, 11-15")
3. Extract and share

That's it. No complicated menus, no confusing options.

✨ FEATURES

• Visual page thumbnails
• Tap to select individual pages
• Range selection (e.g., "1-5, 8, 11-15")
• Select all / Clear / Invert selection
• Preview pages before extracting
• Share extracted PDF directly
• Save to Files
• Works completely offline
• Dark mode support

🆓 FREE TIER

• 3 extractions per month
• All features included
• No ads

⭐ PREMIUM ($9.99/year)

• Unlimited extractions
• Support indie development

Perfect for:
✓ Extracting specific pages from long documents
✓ Splitting multi-page PDFs
✓ Creating document subsets
✓ Removing unwanted pages
✓ Privacy-conscious users

Your documents. Your device. Your privacy.
```

### Step 8: Screenshot Concepts

1. **Hero: Page Selection**
   - Grid of thumbnails with some selected
   - Headline: "Select Any Pages"

2. **Privacy Focus**
   - Lock icon with "Local Processing" badge
   - Headline: "Never Leaves Your Device"

3. **Range Selection**
   - Range dialog showing "1-5, 8, 11-15"
   - Headline: "Quick Range Selection"

4. **Export Success**
   - Export bottom sheet with share options
   - Headline: "Share Instantly"

5. **Simple & Clean**
   - Home screen with PDF icon
   - Headline: "One Purpose, Done Well"

### Step 9: RevenueCat Setup

1. Create project "PDF Pages"
2. Add iOS app (bundle: `com.quickhitter.pdfpages`)
3. Add Android app (package: `com.quickhitter.pdfpages`)
4. Create subscription:
   - ID: `premium_annual`
   - Duration: 1 year
   - Price: $9.99
5. Create entitlement: `premium`
6. Copy API keys to `purchase_service.dart`

### Step 10: Store Setup

**App Store Connect:**
- Category: Productivity (primary), Utilities (secondary)
- Age Rating: 4+
- Privacy: Data Not Collected

**Google Play:**
- Category: Productivity
- Content Rating: Everyone
- Data Safety: No data collected

### Step 11: Build & Submit

**Android:**
```bash
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ipa --release
```

### Step 12: Pre-Launch Checklist

**Functionality:**
- [ ] PDF loading works for various file sizes
- [ ] Encrypted PDF shows helpful error
- [ ] Thumbnails generate correctly
- [ ] Page selection works (tap, range, select all)
- [ ] Extraction creates valid PDF
- [ ] Share/export works
- [ ] Usage tracking counts correctly
- [ ] Paywall appears when limit reached
- [ ] Purchase flow works (sandbox)
- [ ] Restore purchases works
- [ ] Settings screen complete

**Store Assets:**
- [ ] App icon generated for all sizes
- [ ] Screenshots captured (5 concepts × 2 sizes)
- [ ] Description finalized
- [ ] Privacy policy URL live
- [ ] Subscription configured in both stores
- [ ] RevenueCat API keys are production

---

## Privacy Policy

Host at `https://yourusername.github.io/pdfpages-privacy`:

```markdown
# Privacy Policy for PDF Pages

Last updated: [DATE]

## Overview

PDF Pages is a PDF page extraction app that prioritizes your privacy.

## Data Collection

**We do not collect any data.**

All PDF processing happens locally on your device. Your documents are never uploaded to any server. We don't track what files you open, what pages you extract, or any other usage data.

## Local Storage

The app stores:
- Your extraction count (to enforce free tier limits)
- Premium purchase status (synced via RevenueCat)

This data stays on your device.

## Third-Party Services

**RevenueCat**: Processes in-app purchases securely. RevenueCat does not have access to your PDF files. See RevenueCat's Privacy Policy for details.

## Your Documents

Your PDF files:
- Are processed entirely on your device
- Are never uploaded anywhere
- Are never shared with us or third parties
- Remain completely private

## Children's Privacy

This app does not collect information from anyone, including children under 13.

## Contact

Questions? Contact [your-email@example.com]
```

---

## Congratulations! 🎉

You've built a privacy-focused PDF page extractor. The key differentiator is local processing - users who care about document privacy will appreciate that their files never leave their device.

**Post-launch:**
- Monitor reviews for feature requests
- Consider adding: PDF merging, page rotation, compression
- Apple Watch quick-extract if requested

---

*Created: January 2026*
