import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// Result of a purchase attempt
enum PurchaseResult { success, cancelled, error, unavailable }

/// Service for managing premium subscriptions via RevenueCat
class PurchaseService {
  static const String _apiKey = 'appl_MtWeucoFhDIikFoUCfHMLPuaFId';
  static const String _entitlementId = 'premium';

  static bool _initialized = false;
  static final ValueNotifier<bool> isPremiumNotifier = ValueNotifier(false);

  /// Initialize RevenueCat SDK - call once at app startup
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration configuration = PurchasesConfiguration(_apiKey);
      await Purchases.configure(configuration);

      _initialized = true;

      // Check initial premium status
      await _updatePremiumStatus();

      // Listen for changes
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _checkEntitlement(customerInfo);
      });
    } catch (e) {
      debugPrint('RevenueCat initialization error: $e');
    }
  }

  /// Update premium status from current customer info
  static Future<void> _updatePremiumStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _checkEntitlement(customerInfo);
    } catch (e) {
      debugPrint('Error getting customer info: $e');
    }
  }

  /// Check if customer has premium entitlement
  static void _checkEntitlement(CustomerInfo customerInfo) {
    final isPremium = customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
    isPremiumNotifier.value = isPremium;
    debugPrint('Premium status: $isPremium');
  }

  /// Get current premium status
  static bool get isPremium => isPremiumNotifier.value;

  /// Get available packages for purchase
  static Future<List<Package>> getPackages() async {
    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current != null) {
        return current.availablePackages;
      }
    } catch (e) {
      debugPrint('Error getting offerings: $e');
    }
    return [];
  }

  /// Get the annual package specifically
  static Future<Package?> getAnnualPackage() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current?.annual;
    } catch (e) {
      debugPrint('Error getting annual package: $e');
      return null;
    }
  }

  /// Get price string for display
  static Future<String> getPriceString() async {
    try {
      final package = await getAnnualPackage();
      if (package != null) {
        return package.storeProduct.priceString;
      }
    } catch (e) {
      debugPrint('Error getting price: $e');
    }
    return '\$9.99/year'; // Fallback
  }

  /// Purchase premium subscription
  static Future<PurchaseResult> purchasePremium() async {
    try {
      // Check if device can make purchases
      final canPurchase = await canMakePurchases();
      if (!canPurchase) {
        debugPrint('Device cannot make purchases');
        return PurchaseResult.unavailable;
      }

      final package = await getAnnualPackage();
      if (package == null) {
        debugPrint('No annual package available');
        return PurchaseResult.unavailable;
      }

      final result = await Purchases.purchase(PurchaseParams.package(package));
      final customerInfo = result.customerInfo;
      final isPremium = customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
      isPremiumNotifier.value = isPremium;
      return isPremium ? PurchaseResult.success : PurchaseResult.error;
    } on PlatformException catch (e) {
      // RevenueCat throws PlatformException; error code 1 = user cancelled
      final errorCode = PurchasesErrorHelper.getErrorCode(e);
      if (errorCode == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('Purchase cancelled by user');
        return PurchaseResult.cancelled;
      }
      debugPrint('Purchase error: $errorCode - ${e.message}');
      return PurchaseResult.error;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return PurchaseResult.error;
    }
  }

  /// Restore previous purchases
  static Future<bool> restorePurchases() async {
    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPremium = customerInfo.entitlements.all[_entitlementId]?.isActive ?? false;
      isPremiumNotifier.value = isPremium;
      return isPremium;
    } catch (e) {
      debugPrint('Restore error: $e');
      return false;
    }
  }

  /// Check if user can make purchases
  static Future<bool> canMakePurchases() async {
    try {
      return await Purchases.canMakePayments();
    } catch (e) {
      return false;
    }
  }
}
