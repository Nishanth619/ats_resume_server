import 'package:cloud_firestore/cloud_firestore.dart';

enum AiFeature {
  atsCheck,
  autoTailor,
  coverLetter,
  improveBullet,
}

/// Cloud-backed daily usage tracker.
///
/// All counts are stored in Firestore so they:
///   1. Survive app uninstall / reinstall.
///   2. Auto-reset every UTC calendar day (date is embedded in the doc key).
///
/// For features that the backend enforces (atsCheck, coverLetter), the server
/// already writes to these collections via its own transactions.  The client
/// only *reads* those — never writes — to avoid double-counting.
///
/// For features with client-only enforcement (autoTailor, improveBullet),
/// the client both reads and writes.
class UsageTracker {
  static const limits = {
    AiFeature.atsCheck: 5,
    AiFeature.autoTailor: 5,
    AiFeature.coverLetter: 5,
    AiFeature.improveBullet: 5,
  };

  /// Features whose counters are managed by the backend server.
  /// The client never increments these — it only reads them for display.
  static const _serverManaged = {
    AiFeature.atsCheck,
    AiFeature.coverLetter,
  };

  /// Today's date in UTC (yyyy-MM-dd).
  static String get _today =>
      DateTime.now().toUtc().toIso8601String().split('T')[0];

  /// Firestore collection for each feature — matches the server naming.
  static String _collection(AiFeature feature) {
    switch (feature) {
      case AiFeature.atsCheck:
        return 'ats_limits';
      case AiFeature.coverLetter:
        return 'cover_limits';
      case AiFeature.autoTailor:
        return 'tailor_limits';
      case AiFeature.improveBullet:
        return 'bullet_limits';
    }
  }

  static String _docId(String uid) => '${uid}_$_today';

  // ── Read ──────────────────────────────────────────────────────────────────

  /// Returns today's usage count from Firestore. Returns 0 on any error
  /// (fail-open: display "full quota" so the server is the real gatekeeper).
  static Future<int> getUsageCount(AiFeature feature, String uid) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(_collection(feature))
          .doc(_docId(uid))
          .get(const GetOptions(source: Source.serverAndCache));
      return (doc.data()?['count'] as int?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  // ── Write ─────────────────────────────────────────────────────────────────

  /// Increments the counter for client-managed features (autoTailor,
  /// improveBullet). For server-managed features (atsCheck, coverLetter)
  /// this is a deliberate no-op — the server's transaction already counted it.
  static Future<int> incrementUsage(AiFeature feature, String uid) async {
    if (_serverManaged.contains(feature)) {
      // Server already wrote the increment inside its own Firestore transaction.
      // Just return the current count from Firestore (which now includes the
      // server's increment) so the caller gets an accurate value.
      return getUsageCount(feature, uid);
    }

    // Client-managed: use a transaction so concurrent requests don't race.
    try {
      final ref = FirebaseFirestore.instance
          .collection(_collection(feature))
          .doc(_docId(uid));
      final newCount = await FirebaseFirestore.instance.runTransaction((txn) async {
        final doc = await txn.get(ref);
        final next = ((doc.data()?['count'] as int?) ?? 0) + 1;
        txn.set(ref, {'count': next, 'uid': uid, 'date': _today},
            SetOptions(merge: true));
        return next;
      });
      return newCount;
    } catch (_) {
      return 0;
    }
  }

  // ── Admin / Testing ───────────────────────────────────────────────────────

  static Future<void> resetUsage(AiFeature feature, String uid) async {
    try {
      await FirebaseFirestore.instance
          .collection(_collection(feature))
          .doc(_docId(uid))
          .delete();
    } catch (_) {}
  }

  static int getLimit(AiFeature feature) => limits[feature] ?? 5;
}
