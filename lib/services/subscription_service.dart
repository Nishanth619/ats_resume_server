import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firestore_service.dart';

// ─── Subscription Provider ─────────────────────────────────────────────────
// State: true = Pro, false = Free.
// Reads plan from Firestore (UserModel) as source of truth.
// purchasePro() writes plan:'pro' to Firestore, making it immediately live.
//
// ⚠️  PRODUCTION SWITCH:
//   When you have a RevenueCat / Play Billing account:
//   1. Add purchases_flutter to pubspec.yaml
//   2. In purchasePro(), call Purchases.purchasePackage(package) FIRST.
//   3. On success, THEN call _setPlanInFirestore(uid, 'pro') to persist.
// ──────────────────────────────────────────────────────────────────────────

final subscriptionProvider =
    NotifierProvider<SubscriptionNotifier, bool>(SubscriptionNotifier.new);

class SubscriptionNotifier extends Notifier<bool> {
  @override
  bool build() => false; // default: free

  /// Called from auth flow once we know the user's plan from Firestore.
  void setFromUserModel(String plan) {
    state = plan == 'pro';
  }

  /// Grants Pro access and persists it to Firestore.
  /// In production: call your payment SDK first, then call this on success.
  Future<bool> purchasePro({required String uid}) async {
    try {
      // ── STEP 1: In production, initiate payment here ──
      // final success = await _realPaymentFlow();
      // if (!success) return false;

      // ── STEP 2: Write to Firestore (source of truth) ──
      await _setPlanInFirestore(uid, 'pro');

      state = true;
      return true;
    } catch (e) {
      debugPrint('[Subscription] purchasePro failed: $e');
      return false;
    }
  }

  /// Restores a previously purchased Pro plan from Firestore.
  Future<void> restorePurchases({required String uid}) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final plan = (doc.data()?['plan'] ?? 'free') as String;
      state = plan == 'pro';
    } catch (e) {
      debugPrint('[Subscription] restorePurchases failed: $e');
    }
  }

  /// Revokes Pro (admin / refund use case).
  Future<void> revokePro({required String uid}) async {
    await _setPlanInFirestore(uid, 'free');
    state = false;
  }

  Future<void> _setPlanInFirestore(String uid, String plan) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set({'plan': plan}, SetOptions(merge: true));
  }
}

// ─── Convenience re-export so call sites don't need to change ─────────────
final firestoreServiceRef = firestoreServiceProvider;
