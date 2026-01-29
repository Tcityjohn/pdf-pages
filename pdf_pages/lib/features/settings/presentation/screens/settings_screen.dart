import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/widgets/shared_ui.dart';
import '../../../../core/services/purchase_service.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../extractor/presentation/widgets/paywall_sheet.dart';

/// Settings screen with premium status, restore purchases, and legal links
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isRestoring = false;

  Future<void> _restorePurchases() async {
    setState(() => _isRestoring = true);

    final success = await PurchaseService.restorePurchases();
    AnalyticsService.trackRestorePurchases(success: success);

    if (mounted) {
      setState(() => _isRestoring = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Purchase restored successfully!'
                : 'No previous purchase found.',
          ),
        ),
      );
    }
  }

  Future<void> _openPrivacyPolicy() async {
    // TODO: Replace with actual privacy policy URL
    final url = Uri.parse('https://example.com/privacy');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openTermsOfUse() async {
    // Apple's standard EULA
    final url = Uri.parse(
      'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _showPaywall() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const PaywallSheet(daysUntilReset: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: const Color(0xFFE0E0E0),
          ),
        ),
      ),
      body: ListView(
        children: [
          // Premium Status
          ValueListenableBuilder<bool>(
            valueListenable: PurchaseService.isPremiumNotifier,
            builder: (context, isPremium, child) {
              return _SettingsListItem(
                icon: Icons.verified_user,
                iconColor: AppColors.primary,
                title: isPremium
                    ? const _PremiumBadge()
                    : const Text(
                        'Upgrade to Premium',
                        style: TextStyle(
                          fontSize: 16,
                          color: AppColors.textPrimary,
                        ),
                      ),
                subtitle: isPremium
                    ? 'Unlimited extractions'
                    : 'Get unlimited extractions',
                onTap: isPremium ? null : _showPaywall,
                showArrow: !isPremium,
              );
            },
          ),

          const _Divider(),

          // Restore Purchases
          _SettingsListItem(
            icon: Icons.refresh,
            title: const Text(
              'Restore Purchases',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: _isRestoring ? null : _restorePurchases,
            trailing: _isRestoring
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
          ),

          const _Divider(),

          // Privacy Policy
          _SettingsListItem(
            icon: Icons.shield_outlined,
            title: const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: _openPrivacyPolicy,
          ),

          // Terms of Use
          _SettingsListItem(
            icon: Icons.description_outlined,
            title: const Text(
              'Terms of Use',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            onTap: _openTermsOfUse,
          ),

          const _Divider(),

          // About
          _SettingsListItem(
            icon: Icons.info_outline,
            title: const Text(
              'About',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textPrimary,
              ),
            ),
            subtitle: 'Version 1.0.0',
            showArrow: false,
          ),

          // Footer note
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Your PDFs never leave your device.\nAll processing happens locally.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF757575),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsListItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Widget title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool showArrow;

  const _SettingsListItem({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.showArrow = true,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 24,
          color: iconColor ?? const Color(0xFF757575),
        ),
      ),
      title: title,
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF757575),
              ),
            )
          : null,
      trailing: trailing ??
          (showArrow && onTap != null
              ? const Icon(
                  Icons.chevron_right,
                  color: Color(0xFF757575),
                )
              : null),
      onTap: onTap,
    );
  }
}

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFFFF7043)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: Colors.white),
          SizedBox(width: 4),
          Text(
            'Premium',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Divider(height: 1, color: Color(0xFFE0E0E0)),
    );
  }
}
