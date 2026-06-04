import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';
import 'subscription_service.dart';
import 'admob_service.dart';

// ── Result enum ───────────────────────────────────────────────────────────────
enum AdGateResult {
  /// Pro user — skip ad entirely, proceed immediately.
  allowed,

  /// Ad loaded and ready — caller must call showRewardedAdAndWait()
  /// and gate on the bool it returns.
  showAd,

  /// Active ad blocker / private DNS detected (3+ network errors).
  /// Ad-block dialog has already been shown. Feature must be blocked.
  adBlocked,

  /// AdMob could not fill an ad (no inventory, outage, pending app approval).
  /// Feature must be blocked with a "try again" message.
  noFill,
}

/// Central gate for all ad-gated features.
///
/// Usage:
/// ```dart
/// final gate = await AdBlockGuard.check(context, ref);
/// switch (gate) {
///   case AdGateResult.allowed:
///     // Pro user — proceed
///   case AdGateResult.showAd:
///     final watched = await adSvc.showRewardedAdAndWait();
///     if (!watched) { showSkippedSnackbar(); return; }
///     // proceed
///   case AdGateResult.adBlocked:
///     return; // dialog already shown
///   case AdGateResult.noFill:
///     showNoFillSnackbar(); return;
/// }
/// ```
class AdBlockGuard {
  AdBlockGuard._();

  static Future<AdGateResult> check(BuildContext context, WidgetRef ref) async {
    // ── 1. Pro users bypass everything ───────────────────────────────────────
    final isPro = ref.read(subscriptionProvider);
    if (isPro) return AdGateResult.allowed;

    final adSvc = ref.read(adServiceProvider);

    // ── 2. Ad already loaded and ready → go straight to showAd ───────────────
    if (adSvc.isRewardedReady) return AdGateResult.showAd;

    // ── 3. Need to load — attempt with extended wait ──────────────────────────
    // We wait 8 seconds (not 5) to cover slow silent-drop DNS timeouts.
    // Private DNS like NextDNS / AdGuard silently drops packets without
    // NXDOMAIN, so AdMob's SDK may take 6–10s before calling onAdFailedToLoad.
    // During the wait the auto-retry inside loadRewardedAd() also fires.
    await adSvc.loadRewardedAd();
    await Future.delayed(const Duration(seconds: 8));

    // ── 4. Check result after wait ─────────────────────────────────────────────
    if (!context.mounted) return AdGateResult.noFill;

    if (adSvc.isRewardedReady) return AdGateResult.showAd;

    if (adSvc.isAdBlocked) {
      _showAdBlockDialog(context, ref);
      return AdGateResult.adBlocked;
    }

    // ── 5. No fill (AdMob's problem, not user's) ───────────────────────────────
    // We do NOT bypass here. If we returned allowed on no-fill, we would also
    // bypass when DNS is still timing out (indistinguishable). Block and tell
    // the user to try again.
    return AdGateResult.noFill;
  }

  // ── Snackbar helpers (call at feature sites) ──────────────────────────────
  static void showSkippedSnackbar(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚠️ You need to watch the full ad to unlock this feature.'),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 4),
      ),
    );
  }

  static void showNoFillSnackbar(BuildContext context) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ad not available right now — please try again in a moment, '
          'or upgrade to Pro for ad-free access.',
        ),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 5),
      ),
    );
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  static void _showAdBlockDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _AdBlockDialog(ref: ref),
    );
  }
}

// ─── Dialog ───────────────────────────────────────────────────────────────────
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
          border: Border.all(color: AppColors.error.withValues(alpha: 0.4), width: 1.5),
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
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.block_rounded, color: AppColors.error, size: 36),
            ),
            const SizedBox(height: 20),
            const Text(
              'Ad Blocker Detected',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'We detected that ad requests are being blocked on your device '
              '— likely via a private DNS, VPN filter, or ad-blocker app.\n\n'
              'ATS.ai is free because short ads cover the AI costs. '
              'Without ads we cannot offer free features.\n\n'
              'Please disable your ad blocker, or upgrade to Pro for '
              'unlimited ad-free access.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13, height: 1.6,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            const SizedBox(height: 28),
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
                    ref.read(subscriptionProvider.notifier).presentPaywall(uid: uid);
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'Upgrade to Pro — Remove All Ads',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.error.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text(
                  'Dismiss',
                  style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
