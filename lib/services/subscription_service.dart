import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../core/config/app_config.dart';
import 'firestore_service.dart';

/// Entitlement ID configured in the RevenueCat dashboard.
const _kProEntitlement = 'pro';

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

  /// Purchase Pro via RevenueCat.
  Future<PurchaseResult> purchasePro({required String uid}) async {
    final key = AppConfig.revenueCatKey;
    if (key.isEmpty) {
      return PurchaseResult.billingUnavailable;
    }

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null || current.availablePackages.isEmpty) {
        return PurchaseResult.noOfferings;
      }

      // Prefer annual if available, else monthly, else first.
      final package = current.availablePackages.firstWhere(
        (p) => p.packageType == PackageType.annual,
        orElse: () => current.availablePackages.firstWhere(
          (p) => p.packageType == PackageType.monthly,
          orElse: () => current.availablePackages.first,
        ),
      );

      final customerInfo = await Purchases.purchasePackage(package);
      final isPro =
          customerInfo.entitlements.all[_kProEntitlement]?.isActive == true;
      state = isPro;

      if (isPro) {
        try {
          await ref
              .read(firestoreServiceProvider)
              .updateUser(uid, {'plan': 'pro'});
        } catch (e) {
          debugPrint('[Subscription] Firestore plan sync failed: $e');
        }
        return PurchaseResult.success;
      }
      return PurchaseResult.notEntitled;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        return PurchaseResult.cancelled;
      }
      debugPrint('[Subscription] Purchase error: $e');
      return PurchaseResult.error;
    } catch (e) {
      debugPrint('[Subscription] Unexpected purchase error: $e');
      return PurchaseResult.error;
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

enum PurchaseResult {
  success,
  cancelled,
  billingUnavailable,
  noOfferings,
  notEntitled,
  error,
}

enum RestoreResult {
  restored,
  nothingToRestore,
  error,
}

// ─── Offerings / Price Providers ─────────────────────────────────────────────

/// Fetches the current RevenueCat offerings. Returns null if billing is
/// unavailable or no offerings are configured yet.
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  final key = AppConfig.revenueCatKey;
  if (key.isEmpty) return null;
  try {
    return await Purchases.getOfferings();
  } catch (e) {
    debugPrint('[Subscription] Failed to fetch offerings: $e');
    return null;
  }
});

/// Provides the first available package from the current offering.
final activePackageProvider = FutureProvider<Package?>((ref) async {
  final offerings = await ref.watch(offeringsProvider.future);
  if (offerings == null) return null;
  final current = offerings.current;
  if (current == null || current.availablePackages.isEmpty) return null;
  // Prefer monthly for display, then annual, then first
  return current.availablePackages.firstWhere(
    (p) => p.packageType == PackageType.monthly,
    orElse: () => current.availablePackages.first,
  );
});

/// Returns a human-readable price string, e.g. "₹99 / month"
/// Returns null if billing is unavailable.
final subscriptionPriceProvider = FutureProvider<String?>((ref) async {
  final pkg = await ref.watch(activePackageProvider.future);
  if (pkg == null) return null;
  final product = pkg.storeProduct;
  final period = pkg.packageType == PackageType.annual
      ? '/ year'
      : pkg.packageType == PackageType.monthly
          ? '/ month'
          : '';
  return '${product.priceString} $period'.trim();
});

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
