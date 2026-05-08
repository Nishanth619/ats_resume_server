import 'package:shared_preferences/shared_preferences.dart';

enum AiFeature {
  atsCheck,
  autoTailor,
  coverLetter,
  improveBullet,
}

class UsageTracker {
  static const _prefix = 'usage_';

  static const limits = {
    AiFeature.atsCheck: 5,
    AiFeature.autoTailor: 5,
    AiFeature.coverLetter: 5,
    AiFeature.improveBullet: 5,
  };

  static String _key(AiFeature feature, String uid) =>
      '${_prefix}${feature.name}_$uid';

  static Future<int> getUsageCount(AiFeature feature, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(feature, uid)) ?? 0;
  }

  static Future<int> incrementUsage(AiFeature feature, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _key(feature, uid);
    final count = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, count);
    return count;
  }

  static Future<void> resetUsage(AiFeature feature, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(feature, uid));
  }

  static int getLimit(AiFeature feature) => limits[feature] ?? 5;
}
