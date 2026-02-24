import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart' show Package;
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/analytics_service.dart';

/// Bottom sheet paywall shown when free tier is exhausted
class PaywallSheet extends StatefulWidget {
  final int daysUntilReset;
  final VoidCallback? onPurchaseComplete;
  final VoidCallback? onDismiss;

  const PaywallSheet({
    super.key,
    required this.daysUntilReset,
    this.onPurchaseComplete,
    this.onDismiss,
  });

  @override
  State<PaywallSheet> createState() => _PaywallSheetState();
}

enum _PlanType { annual, lifetime }

class _PaywallSheetState extends State<PaywallSheet> {
  bool _isLoading = false;
  bool _isRestoring = false;
  _PlanType _selectedPlan = _PlanType.annual;
  String _annualPrice = '\$4.99';
  String _lifetimePrice = '\$9.99';
  Package? _annualPackage;
  Package? _lifetimePackage;

  @override
  void initState() {
    super.initState();
    _loadPrices();
    AnalyticsService.trackScreenViewed('paywall');
  }

  Future<void> _loadPrices() async {
    final annualPrice = await PurchaseService.getAnnualPriceString();
    final lifetimePrice = await PurchaseService.getLifetimePriceString();
    final annualPkg = await PurchaseService.getAnnualPackage();
    final lifetimePkg = await PurchaseService.getLifetimePackage();
    if (mounted) {
      setState(() {
        _annualPrice = annualPrice;
        _lifetimePrice = lifetimePrice;
        _annualPackage = annualPkg;
        _lifetimePackage = lifetimePkg;
      });
    }
  }

  Future<void> _handlePurchase() async {
    final package = _selectedPlan == _PlanType.annual
        ? _annualPackage
        : _lifetimePackage;
    if (package == null) return;

    setState(() => _isLoading = true);
    AnalyticsService.trackPurchaseInitiated();

    final result = await PurchaseService.purchasePackage(package);

    if (mounted) {
      setState(() => _isLoading = false);

      switch (result) {
        case PurchaseResult.success:
          AnalyticsService.trackPurchaseCompleted();
          widget.onPurchaseComplete?.call();
          Navigator.of(context).pop(true);
        case PurchaseResult.cancelled:
          // User cancelled — do nothing, let them stay on the paywall
          break;
        case PurchaseResult.unavailable:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchases are not available on this device. Check your account settings.')),
          );
        case PurchaseResult.error:
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Something went wrong. Please try again.')),
          );
      }
    }
  }

  Future<void> _handleRestore() async {
    setState(() => _isRestoring = true);

    final success = await PurchaseService.restorePurchases();
    AnalyticsService.trackRestorePurchases(success: success);

    if (mounted) {
      setState(() => _isRestoring = false);

      if (success) {
        widget.onPurchaseComplete?.call();
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase restored successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No previous purchase found.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Sheet handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    margin: const EdgeInsets.only(bottom: 20),
                  ),

                  // Premium icon (shield with checkmark)
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryPale,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.verified_user,
                        size: 48,
                        color: AppColors.primary,
                      ),
                    ),
                  ),

                  // Title
                  const Text(
                    'Upgrade to Premium',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 8),

                  // Subtitle
                  Text(
                    'You\'ve used your 3 free extractions this month.\nUpgrade for unlimited access!',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 24),

                  // Features box
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFEEEEEE),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _FeatureRow(
                          icon: Icons.all_inclusive,
                          text: 'Unlimited extractions',
                        ),
                        const SizedBox(height: 8),
                        _FeatureRow(
                          icon: Icons.lock,
                          text: 'Privacy first - all local',
                        ),
                        const SizedBox(height: 8),
                        _FeatureRow(
                          icon: Icons.favorite,
                          text: 'Support indie development',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Plan selection
                  Row(
                    children: [
                      Expanded(
                        child: _PlanOption(
                          label: 'Annual',
                          price: _annualPrice,
                          detail: 'per year',
                          trial: '7-day free trial',
                          selected: _selectedPlan == _PlanType.annual,
                          onTap: () => setState(() => _selectedPlan = _PlanType.annual),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlanOption(
                          label: 'Lifetime',
                          price: _lifetimePrice,
                          detail: 'one-time',
                          trial: 'Best value',
                          selected: _selectedPlan == _PlanType.lifetime,
                          onTap: () => setState(() => _selectedPlan = _PlanType.lifetime),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Upgrade button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _selectedPlan == _PlanType.annual
                                  ? 'Start Free Trial'
                                  : 'Buy Lifetime Access',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Restore purchases button
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: _isRestoring ? null : _handleRestore,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: _isRestoring
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                              ),
                            )
                          : const Text(
                              'Restore Purchases',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Legal links (required by App Store guideline 3.1.2)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://www.apple.com/legal/internet-services/itunes/dev/stdeula/'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          'Terms of Use',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '|',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => launchUrl(
                          Uri.parse('https://tcityjohn.github.io/pdf-pages/privacy'),
                          mode: LaunchMode.externalApplication,
                        ),
                        child: Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  // Reset info
                  Text(
                    'Free extractions reset in ${widget.daysUntilReset} days',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _FeatureRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanOption extends StatelessWidget {
  final String label;
  final String price;
  final String detail;
  final String trial;
  final bool selected;
  final VoidCallback onTap;

  const _PlanOption({
    required this.label,
    required this.price,
    required this.detail,
    required this.trial,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryPale : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFDDDDDD),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              price,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
            Text(
              detail,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : const Color(0xFFEEEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trial,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? AppColors.primary : AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
