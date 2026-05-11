import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'core/app.dart';
import 'services/subscription_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase ───────────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp();
    FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (e) {
    debugPrint('Firebase not initialized: $e');
  }

  // ── Google Mobile Ads ─────────────────────────────────────────────────────
  try {
    await MobileAds.instance.initialize();
  } catch (e) {
    debugPrint('MobileAds not initialized: $e');
  }

  // ── RevenueCat ────────────────────────────────────────────────────────────
  await initRevenueCat();

  runApp(const ProviderScope(child: ATSResumeApp()));
}
