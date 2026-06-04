import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'subscription_service.dart';
import 'admob_service.dart';

/// Gate that checks whether a free user can access a gated feature.
///
/// Three possible outcomes:
///
///   1. **Pro user** → allowed immediately, no ad needed.
///
///   2. **Free user, AdMob has no fill / app not approved yet** → allowed
///      gracefully (the feature works without showing an ad).
///      This covers: AdMob not yet approving the app, no ad fill in the user's
///      region, temporary AdMob outages, misconfigured ad unit IDs.
///
///   3. **Free user, active ad blocker / private DNS detected** → BLOCKED.
///      Shows the [_AdBlockDialog] and returns false.
///      This covers: private DNS (NextDNS, 1.1.1.1 Family, AdGuard DNS),
///      network-level blockers (Pi-hole, AdGuard Home), VPN ad filters.
///
/// The distinction is made using AdMob error codes:
///   code 2 = network error (DNS/connection blocked)  → counts as blocking
///   code 3 = no fill (AdMob's problem)               → graceful bypass
///   code 0/1 = internal/config error                 → graceful bypass
class AdBlockGuard {
  AdBlockGuard._();

  static Future<bool> check(BuildContext context, WidgetRef ref) async {
    // Pro users always get through.
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return true;

    final adSvc = ref.read(adServiceProvider);

    // If the service doesn't have a fresh signal yet, attempt one ad load.
    if (!adSvc.isRewardedReady && !adSvc.isAdBlocked) {
      await adSvc.loadRewardedAd();
      // Give it up to 5 seconds to load or fail.
      await Future.delayed(const Duration(seconds: 5));
    }

    // ── Case: active ad blocker (repeated network failures) ──────────────────
    if (adSvc.isAdBlocked) {
      if (context.mounted) _showAdBlockDialog(context, ref);
      return false;
    }

    // ── Case: AdMob has no fill / app not approved / outage ─────────────────
    // isAdBlocked is false but the ad still didn't load → no-fill situation.
    // We allow the feature through — this is AdMob's problem, not the user's.
    // The feature will work without an ad being shown.
    return true;
  }

  static void _showAdBlockDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdBlockDialog(ref: ref),
    );
  }
}

// ─── Dialog Widget ────────────────────────────────────────────────────────────
class _AdBlockDialog extends StatelessWidget {
  final WidgetRef ref;
  const _AdBlockDialog({required this.ref});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1F2E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.error.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.block_rounded,
                color: AppColors.error,
                size: 36,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            const Text(
              'Ad Blocker Detected',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              'We detected that ad requests are being blocked on your '
              'device — likely via a private DNS, VPN filter, or '
              'ad-blocker app.\n\n'
              'ATS.ai is free because short ads cover the AI costs. '
              'Without ads we cannot offer free features.\n\n'
              'Please disable your ad blocker, or upgrade to Pro for '
              'unlimited ad-free access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.6,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 28),

            // Upgrade to Pro button
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.goldGradient,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    final uid = ref.read(userDataProvider).value?.uid ?? '';
                    ref
                        .read(subscriptionProvider.notifier)
                        .presentPaywall(uid: uid);
                  },
                  icon: const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  label: const Text(
                    'Upgrade to Pro — Remove All Ads',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Dismiss
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: AppColors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
