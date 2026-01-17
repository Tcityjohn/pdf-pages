# PDF Pages Build Prompt 3: Usage Limits & Premium
## Day 2 Morning (3-4 hours)

---

## Context for Claude

The extraction functionality is complete. Now we add usage tracking (3 free extractions per month) and RevenueCat integration for premium unlimited access.

---

## Task: Add usage limits and RevenueCat premium

### Step 1: Create Usage Service

**lib/core/services/usage_service.dart:**

```dart
import 'package:shared_preferences/shared_preferences.dart';

class UsageService {
  static const _keyExtractionCount = 'extraction_count';
  static const _keyLastResetMonth = 'last_reset_month';
  static const int freeMonthlyLimit = 3;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _checkMonthReset();
  }

  Future<void> _checkMonthReset() async {
    final now = DateTime.now();
    final currentMonth = '${now.year}-${now.month}';
    final lastResetMonth = _prefs?.getString(_keyLastResetMonth);

    if (lastResetMonth != currentMonth) {
      // New month - reset counter
      await _prefs?.setInt(_keyExtractionCount, 0);
      await _prefs?.setString(_keyLastResetMonth, currentMonth);
    }
  }

  int getExtractionCount() {
    return _prefs?.getInt(_keyExtractionCount) ?? 0;
  }

  int getRemainingExtractions() {
    final used = getExtractionCount();
    return (freeMonthlyLimit - used).clamp(0, freeMonthlyLimit);
  }

  bool canExtract() {
    return getRemainingExtractions() > 0;
  }

  Future<void> recordExtraction() async {
    final current = getExtractionCount();
    await _prefs?.setInt(_keyExtractionCount, current + 1);
  }

  String getResetDateString() {
    final now = DateTime.now();
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final daysUntilReset = nextMonth.difference(now).inDays;

    if (daysUntilReset == 0) {
      return 'tomorrow';
    } else if (daysUntilReset == 1) {
      return 'in 1 day';
    } else {
      return 'in $daysUntilReset days';
    }
  }
}
```

### Step 2: Create Purchase Service

**lib/core/services/purchase_service.dart:**

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

class PurchaseService {
  // TODO: Replace with your RevenueCat API keys
  static const _iosApiKey = 'appl_YOUR_IOS_KEY';
  static const _androidApiKey = 'goog_YOUR_ANDROID_KEY';

  static const entitlementId = 'premium';
  static const productId = 'premium_annual';

  final _isPremiumController = StreamController<bool>.broadcast();
  Stream<bool> get isPremiumStream => _isPremiumController.stream;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Offering? _currentOffering;
  Offering? get currentOffering => _currentOffering;

  Future<void> init() async {
    try {
      await Purchases.setLogLevel(LogLevel.debug);

      final configuration = PurchasesConfiguration(
        defaultTargetPlatform == TargetPlatform.iOS
            ? _iosApiKey
            : _androidApiKey,
      );

      await Purchases.configure(configuration);

      // Listen to customer info updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updatePremiumStatus(customerInfo);
      });

      // Check initial status
      final customerInfo = await Purchases.getCustomerInfo();
      _updatePremiumStatus(customerInfo);

      // Load offerings
      await _loadOfferings();
    } catch (e) {
      debugPrint('RevenueCat init error: $e');
    }
  }

  void _updatePremiumStatus(CustomerInfo customerInfo) {
    final hasEntitlement =
        customerInfo.entitlements.active.containsKey(entitlementId);

    if (hasEntitlement != _isPremium) {
      _isPremium = hasEntitlement;
      _isPremiumController.add(_isPremium);
    }
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      _currentOffering = offerings.current;
    } catch (e) {
      debugPrint('Error loading offerings: $e');
    }
  }

  Future<bool> purchasePremium() async {
    if (_currentOffering == null) {
      await _loadOfferings();
    }

    final package = _currentOffering?.availablePackages.firstWhere(
      (p) => p.storeProduct.identifier == productId,
      orElse: () => _currentOffering!.availablePackages.first,
    );

    if (package == null) {
      debugPrint('No package available');
      return false;
    }

    try {
      final result = await Purchases.purchasePackage(package);
      return result.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      return customerInfo.entitlements.active.containsKey(entitlementId);
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  String? getPriceString() {
    final package = _currentOffering?.availablePackages.firstWhere(
      (p) => p.storeProduct.identifier == productId,
      orElse: () => _currentOffering!.availablePackages.first,
    );

    return package?.storeProduct.priceString;
  }

  void dispose() {
    _isPremiumController.close();
  }
}
```

### Step 3: Update App Providers

Update **lib/core/providers/app_providers.dart** - add usage and purchase providers:

```dart
// Add these imports at the top
import '../services/usage_service.dart';
import '../services/purchase_service.dart';

// Add these providers

// Usage service
final usageServiceProvider = Provider<UsageService>((ref) {
  return UsageService();
});

// Purchase service
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final service = PurchaseService();
  ref.onDispose(() => service.dispose());
  return service;
});

// Premium status (updates from RevenueCat)
final isPremiumProvider = StreamProvider<bool>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  return purchaseService.isPremiumStream;
});

// Synchronous premium check
final isPremiumSyncProvider = StateProvider<bool>((ref) {
  final purchaseService = ref.watch(purchaseServiceProvider);
  return purchaseService.isPremium;
});

// Remaining extractions
final remainingExtractionsProvider = Provider<int>((ref) {
  final isPremium = ref.watch(isPremiumSyncProvider);
  if (isPremium) return -1; // Unlimited

  final usageService = ref.watch(usageServiceProvider);
  return usageService.getRemainingExtractions();
});

// Can extract check
final canExtractProvider = Provider<bool>((ref) {
  final isPremium = ref.watch(isPremiumSyncProvider);
  if (isPremium) return true;

  final usageService = ref.watch(usageServiceProvider);
  return usageService.canExtract();
});
```

### Step 4: Create Paywall Widget

**lib/shared/widgets/paywall.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';

class Paywall extends ConsumerStatefulWidget {
  final VoidCallback? onPurchased;

  const Paywall({super.key, this.onPurchased});

  @override
  ConsumerState<Paywall> createState() => _PaywallState();
}

class _PaywallState extends ConsumerState<Paywall> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final purchaseService = ref.watch(purchaseServiceProvider);
    final usageService = ref.watch(usageServiceProvider);
    final priceString = purchaseService.getPriceString() ?? '\$9.99/year';

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.workspace_premium,
              size: 48,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Upgrade to Premium',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'You\'ve used your ${UsageService.freeMonthlyLimit} free extractions this month.\nUpgrade for unlimited access!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),

          const SizedBox(height: 24),

          // Features list
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _FeatureRow(
                  icon: Icons.all_inclusive,
                  text: 'Unlimited extractions',
                ),
                const SizedBox(height: 12),
                _FeatureRow(
                  icon: Icons.lock_outline,
                  text: 'Privacy first - all local',
                ),
                const SizedBox(height: 12),
                _FeatureRow(
                  icon: Icons.favorite_outline,
                  text: 'Support indie development',
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Price
          Text(
            priceString,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),

          Text(
            'per year',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),

          const SizedBox(height: 24),

          // Purchase button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isLoading ? null : _purchase,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Upgrade Now'),
            ),
          ),

          const SizedBox(height: 12),

          // Restore purchases
          TextButton(
            onPressed: _isLoading ? null : _restore,
            child: const Text('Restore Purchases'),
          ),

          const SizedBox(height: 8),

          // Reset info
          Text(
            'Free extractions reset ${usageService.getResetDateString()}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _purchase() async {
    setState(() => _isLoading = true);

    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final success = await purchaseService.purchasePremium();

      if (success) {
        ref.read(isPremiumSyncProvider.notifier).state = true;
        widget.onPurchased?.call();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Welcome to Premium! 🎉')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _restore() async {
    setState(() => _isLoading = true);

    try {
      final purchaseService = ref.read(purchaseServiceProvider);
      final success = await purchaseService.restorePurchases();

      if (success) {
        ref.read(isPremiumSyncProvider.notifier).state = true;
        widget.onPurchased?.call();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchases restored! 🎉')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No purchases to restore')),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
```

### Step 5: Create Usage Banner Widget

**lib/shared/widgets/usage_banner.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/app_providers.dart';
import '../../core/services/usage_service.dart';
import 'paywall.dart';

class UsageBanner extends ConsumerWidget {
  const UsageBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(isPremiumSyncProvider);
    final remaining = ref.watch(remainingExtractionsProvider);
    final theme = Theme.of(context);

    if (isPremium) {
      // Premium badge
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.tertiary,
            ],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.workspace_premium,
              size: 16,
              color: theme.colorScheme.onPrimary,
            ),
            const SizedBox(width: 6),
            Text(
              'Premium',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      );
    }

    // Free tier usage indicator
    final isLow = remaining <= 1;
    final isEmpty = remaining == 0;

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const Paywall(),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isEmpty
              ? theme.colorScheme.errorContainer
              : isLow
                  ? theme.colorScheme.tertiaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isEmpty
                ? theme.colorScheme.error
                : theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            // Usage dots
            Row(
              children: List.generate(
                UsageService.freeMonthlyLimit,
                (index) {
                  final isUsed = index >= remaining;
                  return Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isUsed
                          ? theme.colorScheme.outline.withOpacity(0.3)
                          : theme.colorScheme.primary,
                    ),
                  );
                },
              ),
            ),

            const SizedBox(width: 8),

            Expanded(
              child: Text(
                isEmpty
                    ? 'No free extractions left'
                    : '$remaining free extraction${remaining == 1 ? '' : 's'} left',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isEmpty
                      ? theme.colorScheme.onErrorContainer
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),

            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ],
        ),
      ),
    );
  }
}
```

### Step 6: Update Main App Initialization

**lib/main.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/usage_service.dart';
import 'core/services/purchase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final usageService = UsageService();
  await usageService.init();

  final purchaseService = PurchaseService();
  await purchaseService.init();

  runApp(
    ProviderScope(
      overrides: [
        // Pre-initialize services
      ],
      child: PdfPagesApp(
        usageService: usageService,
        purchaseService: purchaseService,
      ),
    ),
  );
}
```

**lib/app.dart:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/providers/app_providers.dart';
import 'core/services/usage_service.dart';
import 'core/services/purchase_service.dart';
import 'features/extractor/presentation/screens/home_screen.dart';

class PdfPagesApp extends StatelessWidget {
  final UsageService usageService;
  final PurchaseService purchaseService;

  const PdfPagesApp({
    super.key,
    required this.usageService,
    required this.purchaseService,
  });

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        usageServiceProvider.overrideWithValue(usageService),
        purchaseServiceProvider.overrideWithValue(purchaseService),
        isPremiumSyncProvider.overrideWith((ref) => purchaseService.isPremium),
      ],
      child: MaterialApp(
        title: 'PDF Pages',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE53935),
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
      ),
    );
  }
}
```

### Step 7: Update Extractor Screen with Usage Check

Update the extraction flow in **extractor_screen.dart** to check usage:

```dart
// Update _extractPages method

Future<void> _extractPages(BuildContext context, WidgetRef ref) async {
  // Check if can extract
  final canExtract = ref.read(canExtractProvider);
  final isPremium = ref.read(isPremiumSyncProvider);

  if (!canExtract && !isPremium) {
    // Show paywall
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Paywall(
        onPurchased: () {
          // Retry extraction after purchase
          _extractPages(context, ref);
        },
      ),
    );
    return;
  }

  final document = ref.read(currentDocumentProvider);
  final selectedPages = ref.read(selectedPagesProvider);

  if (document == null || selectedPages.isEmpty) return;

  // Generate output filename
  final baseName = document.name.replaceAll('.pdf', '');
  final pageList = _formatPageList(selectedPages);
  final outputName = '${baseName}_pages_$pageList.pdf';

  final outputPath = await ref.read(extractionNotifierProvider.notifier).extractPages(
    sourcePath: document.path,
    pageIndices: selectedPages,
    outputName: outputName,
  );

  if (outputPath != null) {
    // Record usage (only for free users)
    if (!isPremium) {
      await ref.read(usageServiceProvider).recordExtraction();
      // Force refresh of remaining extractions
      ref.invalidate(remainingExtractionsProvider);
    }

    if (context.mounted) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => ExportSheet(
          filePath: outputPath,
          fileName: outputName,
        ),
      );
    }
  }
}
```

### Step 8: Add Usage Banner to Home Screen

Update **home_screen.dart** to show usage:

```dart
// Add import
import '../../../../shared/widgets/usage_banner.dart';

// In the build method, add after the privacy badge and before the button:
const SizedBox(height: 24),
const UsageBanner(),
const SizedBox(height: 24),
```

---

## Expected Outcome

1. ✅ Usage tracking - 3 free extractions per month
2. ✅ Monthly reset of free extractions
3. ✅ RevenueCat integration for premium
4. ✅ Paywall with feature list and pricing
5. ✅ Restore purchases functionality
6. ✅ Usage banner showing remaining extractions
7. ✅ Premium badge for subscribers
8. ✅ Extraction blocked when limit reached

**Test:**
```bash
flutter run
```

Test the free tier by extracting 3 times, then verify the paywall appears. Test purchase flow in sandbox.

---

## RevenueCat Setup Checklist

1. Create project "PDF Pages" at app.revenuecat.com
2. Add iOS app (bundle: `com.quickhitter.pdfpages`)
3. Add Android app (package: `com.quickhitter.pdfpages`)
4. Create subscription:
   - ID: `premium_annual`
   - Duration: 1 year
   - Price: $9.99
5. Create entitlement: `premium`
6. Copy API keys to `purchase_service.dart`

---

## Next Prompt

Prompt 4 will handle edge cases, App Store assets, and submission.
