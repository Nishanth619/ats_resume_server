import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../core/config/app_config.dart';
import 'firestore_service.dart';

/// Entitlement ID configured in the RevenueCat dashboard.
const _kProEntitlement = 'Nishanth aradhya Pro';

// ─── Subscription State ───────────────────────────────────────────────────────

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, bool>(SubscriptionNotifier.new);

class SubscriptionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Sync plan from Firestore on sign-in / user doc change.
  void setFromUserModel(String plan) {
    state = plan == 'pro';
  }

  /// Present RevenueCat Native Paywall if user is not already Pro.
  Future<void> presentPaywall({required String uid}) async {
    final key = AppConfig.revenueCatKey;
    debugPrint('[Subscription] presentPaywall called. key empty=${key.isEmpty}');
    if (key.isEmpty) return;

    try {
      // Use presentPaywall (not IfNeeded) so it always shows even when
      // RevenueCat offerings are still propagating from Google Play.
      final result = await RevenueCatUI.presentPaywall();
      debugPrint('[Subscription] Paywall result: $result');
      if (result == PaywallResult.purchased || result == PaywallResult.restored) {
        final customerInfo = await Purchases.getCustomerInfo();
        final isPro = customerInfo.entitlements.all[_kProEntitlement]?.isActive == true;
        state = isPro;
        if (isPro) {
          try {
            await ref.read(firestoreServiceProvider).updateUser(uid, {'plan': 'pro'});
          } catch (e) {
            debugPrint('[Subscription] Firestore plan sync failed: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('[Subscription] Paywall error: $e');
    }
  }

  /// Present RevenueCat Customer Center to manage subscription.
  Future<void> presentCustomerCenter({required String uid}) async {
    try {
      await RevenueCatUI.presentCustomerCenter();
      // Re-fetch info after returning from customer center
      final customerInfo = await Purchases.getCustomerInfo();
      final isPro = customerInfo.entitlements.all[_kProEntitlement]?.isActive == true;
      state = isPro;
      try {
        await ref.read(firestoreServiceProvider).updateUser(uid, {'plan': isPro ? 'pro' : 'free'});
      } catch (e) {
        debugPrint('[Subscription] Firestore plan sync failed: $e');
      }
    } catch (e) {
      debugPrint('[Subscription] Customer Center error: $e');
    }
  }

  /// Restore Purchases via RevenueCat, fallback to Firestore.
  Future<RestoreResult> restorePurchases({required String uid}) async {
    try {
      final key = AppConfig.revenueCatKey;
      if (key.isNotEmpty) {
        final info = await Purchases.restorePurchases();
        final isPro =
            info.entitlements.all[_kProEntitlement]?.isActive == true;
        state = isPro;
        if (isPro) {
          await ref
              .read(firestoreServiceProvider)
              .updateUser(uid, {'plan': 'pro'});
          return RestoreResult.restored;
        }
        return RestoreResult.nothingToRestore;
      }
    } catch (e) {
      debugPrint('[Subscription] RevenueCat restore failed: $e');
    }

    // Fallback to Firestore plan field
    try {
      final doc = await ref.read(firestoreServiceProvider).getUser(uid);
      final isPro = (doc?.plan ?? 'free') == 'pro';
      state = isPro;
      return isPro ? RestoreResult.restored : RestoreResult.nothingToRestore;
    } catch (e) {
      debugPrint('[Subscription] Firestore restore failed: $e');
      return RestoreResult.error;
    }
  }

  /// Revoke Pro (admin / testing only).
  Future<void> revokePro({required String uid}) async {
    await ref
        .read(firestoreServiceProvider)
        .updateUser(uid, {'plan': 'free'});
    state = false;
  }
}

// ─── Result Enums ─────────────────────────────────────────────────────────────

/// Restore result — still used by the settings screen Restore Purchases tile.
enum RestoreResult {
  restored,
  nothingToRestore,
  error,
}

// ─── RevenueCat SDK Init ──────────────────────────────────────────────────────

/// Initialise RevenueCat SDK once at app start. Call from main() before runApp().
Future<void> initRevenueCat() async {
  final key = AppConfig.revenueCatKey;
  if (key.isEmpty) {
    debugPrint(
      '[RevenueCat] Key not set — skipping initialisation. '
      'Pass REVENUECAT_ANDROID_KEY via --dart-define.',
    );
    return;
  }

  try {
    if (Platform.isAndroid || Platform.isIOS) {
      await Purchases.configure(PurchasesConfiguration(key));
      debugPrint('[RevenueCat] SDK initialised successfully.');
    }
  } catch (e) {
    debugPrint('[RevenueCat] Initialisation failed: $e');
  }
}
