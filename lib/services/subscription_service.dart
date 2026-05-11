import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/config/app_config.dart';
import 'firestore_service.dart';

/// Entitlement ID configured in the RevenueCat dashboard.
const _kProEntitlement = 'pro';

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, bool>(SubscriptionNotifier.new);

class SubscriptionNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  // ── Sync plan from Firestore on sign-in ────────────────────────────────────
  void setFromUserModel(String plan) {
    state = plan == 'pro';
  }

  // ── Purchase Pro ──────────────────────────────────────────────────────────
  Future<bool> purchasePro({required String uid}) async {
    final key = AppConfig.revenueCatKey;
    if (key.isEmpty) {
      debugPrint('[Subscription] RevenueCat key not set — cannot purchase.');
      return false;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || current.availablePackages.isEmpty) {
        debugPrint('[Subscription] No offerings available.');
        return false;
      }

      // Use the first package (typically monthly or lifetime)
      final package = current.availablePackages.first;
      // In purchases_flutter v8+, purchasePackage returns CustomerInfo directly
      final customerInfo = await Purchases.purchasePackage(package);
      final isPro =
          customerInfo.entitlements.all[_kProEntitlement]?.isActive == true;
      state = isPro;

      // Mirror plan in Firestore so the backend rate-limit check stays in sync
      if (isPro) {
        try {
          await ref
              .read(firestoreServiceProvider)
              .updateUser(uid, {'plan': 'pro'});
        } catch (e) {
          debugPrint('[Subscription] Firestore plan sync failed: $e');
        }
      }
      return isPro;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('[Subscription] User cancelled purchase.');
        return false;
      }
      debugPrint('[Subscription] Purchase error: $e');
      rethrow;
    } catch (e) {
      debugPrint('[Subscription] Unexpected purchase error: $e');
      rethrow;
    }
  }

  // ── Restore Purchases ─────────────────────────────────────────────────────
  Future<void> restorePurchases({required String uid}) async {
    try {
      final key = AppConfig.revenueCatKey;
      if (key.isNotEmpty) {
        final info = await Purchases.restorePurchases();
        final isPro =
            info.entitlements.all[_kProEntitlement]?.isActive == true;
        state = isPro;

        // Mirror in Firestore
        if (isPro) {
          await ref
              .read(firestoreServiceProvider)
              .updateUser(uid, {'plan': 'pro'});
        }
        return;
      }
    } catch (e) {
      debugPrint('[Subscription] RevenueCat restore failed: $e');
    }

    // Fallback to Firestore plan field
    try {
      final doc = await ref.read(firestoreServiceProvider).getUser(uid);
      state = (doc?.plan ?? 'free') == 'pro';
    } catch (e) {
      debugPrint('[Subscription] Firestore restore failed: $e');
    }
  }

  // ── Revoke Pro (admin / testing) ──────────────────────────────────────────
  Future<void> revokePro({required String uid}) async {
    await ref
        .read(firestoreServiceProvider)
        .updateUser(uid, {'plan': 'free'});
    state = false;
  }
}

/// Helper: initialise RevenueCat SDK once at app start.
/// Call this from main() before runApp().
Future<void> initRevenueCat() async {
  final key = AppConfig.revenueCatKey;
  if (key.isEmpty) {
    debugPrint(
      '[RevenueCat] Key not set — skipping initialisation. '
      'Pass REVENUECAT_ANDROID_KEY / REVENUECAT_IOS_KEY via --dart-define.',
    );
    return;
  }

  try {
    // Only configure on real devices; skip on web/desktop
    if (Platform.isAndroid || Platform.isIOS) {
      await Purchases.configure(PurchasesConfiguration(key));
      debugPrint('[RevenueCat] SDK initialised successfully.');
    }
  } catch (e) {
    debugPrint('[RevenueCat] Initialisation failed: $e');
  }
}

final subscriptionPriceProvider = Provider<String?>((ref) => null);
final firestoreServiceRef = firestoreServiceProvider;
