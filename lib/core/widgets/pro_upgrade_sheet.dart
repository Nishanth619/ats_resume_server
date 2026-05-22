import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/subscription_service.dart';
import '../constants/app_colors.dart';
import 'shared_widgets.dart';

/// Shows a bottom sheet paywall that supports the full RevenueCat purchase
/// flow. Gracefully degrades to "billing unavailable" when the key is not set.
Future<void> showProUpgradeSheet(BuildContext context, WidgetRef ref) {
  final uid = ref.read(authStateProvider).value?.uid ?? '';
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ProUpgradeSheet(uid: uid),
  );
}

class _ProUpgradeSheet extends ConsumerStatefulWidget {
  final String uid;
  const _ProUpgradeSheet({required this.uid});

  @override
  ConsumerState<_ProUpgradeSheet> createState() => _ProUpgradeSheetState();
}

class _ProUpgradeSheetState extends ConsumerState<_ProUpgradeSheet> {
  bool _loading = false;
  String? _error;

  static const _benefits = [
    (Icons.analytics_outlined, 'Unlimited ATS Checks', 'Free: 5/day'),
    (Icons.auto_fix_high_rounded, 'Unlimited AI Tailoring', 'Free: 5/day'),
    (Icons.mail_outline_rounded, 'Unlimited Cover Letters', 'Free: 5/day'),
    (Icons.picture_as_pdf_rounded, 'All Premium Templates', 'Unlock all Pro designs'),
    (Icons.description_outlined, 'DOCX Word Export', 'Free: PDF only'),
  ];

  Future<void> _purchase() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(subscriptionProvider.notifier)
        .purchasePro(uid: widget.uid);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case PurchaseResult.success:
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('🎉 Welcome to Pro! All features unlocked.'),
            backgroundColor: AppColors.scoreGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case PurchaseResult.cancelled:
        break; // user dismissed, no error needed
      case PurchaseResult.billingUnavailable:
        setState(() => _error =
            'Billing is not configured yet. Please check back soon.');
      case PurchaseResult.noOfferings:
        setState(() => _error =
            'No subscription plans found. Please try again later.');
      case PurchaseResult.notEntitled:
        setState(() => _error =
            'Purchase completed but entitlement not found. Try restoring purchases.');
      case PurchaseResult.error:
        setState(() => _error = 'Purchase failed. Please try again.');
    }
  }

  Future<void> _restore() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(subscriptionProvider.notifier)
        .restorePurchases(uid: widget.uid);
    if (!mounted) return;
    setState(() => _loading = false);

    switch (result) {
      case RestoreResult.restored:
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Pro subscription restored!'),
            backgroundColor: AppColors.scoreGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      case RestoreResult.nothingToRestore:
        setState(() => _error = 'No previous purchases found for this account.');
      case RestoreResult.error:
        setState(() => _error = 'Restore failed. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceAsync = ref.watch(subscriptionPriceProvider);

    return Container(
      decoration: BoxDecoration(
        color: context.appColors.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: context.appColors.border),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: context.appColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Crown icon
            Center(
              child: Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.accentGold,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGold.withValues(alpha: 0.4),
                      blurRadius: 28, offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white, size: 40,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Upgrade to Pro',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.appColors.textPrimary,
                fontSize: 24, fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),

            // Price
            priceAsync.when(
              data: (price) => Text(
                price ?? 'Billing unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: price != null
                      ? AppColors.accentGold
                      : context.appColors.textMuted,
                  fontSize: 16, fontWeight: FontWeight.w700,
                ),
              ),
              loading: () => Center(
                child: SizedBox(
                  height: 16, width: 80,
                  child: LinearProgressIndicator(
                    color: AppColors.accentGold,
                    backgroundColor: AppColors.accentGold.withValues(alpha: 0.1),
                  ),
                ),
              ),
              error: (_, __) => Text(
                'Price unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appColors.textMuted, fontSize: 14),
              ),
            ),
            const SizedBox(height: 24),

            // Benefits
            ...List.generate(_benefits.length, (i) {
              final (icon, title, sub) = _benefits[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, color: AppColors.accentGold, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title,
                            style: TextStyle(
                              color: context.appColors.textPrimary,
                              fontWeight: FontWeight.w600, fontSize: 14,
                            )),
                          Text(sub,
                            style: TextStyle(
                              color: context.appColors.textMuted, fontSize: 12,
                            )),
                        ],
                      ),
                    ),
                    const Icon(Icons.check_circle_rounded,
                        color: AppColors.scoreGreen, size: 18),
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Purchase button
            priceAsync.when(
              data: (price) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                onPressed: price == null ? null : (_loading ? null : _purchase),
                child: _loading
                    ? const SizedBox(
                        height: 20, width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2,
                        ),
                      )
                    : Text(
                        price == null ? 'Billing Unavailable' : 'Subscribe — $price',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16,
                        ),
                      ),
              ),
              loading: () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: null,
                child: const SizedBox(
                  height: 20, width: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2,
                  ),
                ),
              ),
              error: (_, __) => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: null,
                child: const Text('Unavailable',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 10),

            // Restore purchases
            TextButton(
              onPressed: _loading ? null : _restore,
              child: Text(
                'Restore Purchases',
                style: TextStyle(
                  color: context.appColors.textSecondary,
                  fontWeight: FontWeight.w600, fontSize: 13,
                ),
              ),
            ),

            // Close
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Not now',
                style: TextStyle(
                  color: context.appColors.textMuted,
                  fontWeight: FontWeight.w500, fontSize: 13,
                ),
              ),
            ),

            const SizedBox(height: 4),
            Text(
              'Subscriptions are managed by Google Play.\nCancel anytime in Play Store.',
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appColors.textMuted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}
