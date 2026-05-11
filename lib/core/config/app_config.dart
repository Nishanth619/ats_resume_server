import 'dart:io';

class AppConfig {
  static const backendUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://ats-resume-server.onrender.com',
  );

  static const bypassAtsLimits = bool.fromEnvironment(
    'BYPASS_ATS_LIMITS',
    defaultValue: false,
  );

  static const revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
  );
  static const revenueCatIosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');

  static const admobAndroidRewarded = String.fromEnvironment(
    'ADMOB_ANDROID_REWARDED',
    defaultValue: 'ca-app-pub-4025737666505759/3890566160',
  );
  static const admobIosRewarded = String.fromEnvironment(
    'ADMOB_IOS_REWARDED',
    defaultValue: 'ca-app-pub-3940256099942544/1712485313',
  );
  static const admobAndroidBanner = String.fromEnvironment(
    'ADMOB_ANDROID_BANNER',
    defaultValue: 'ca-app-pub-4025737666505759/4264531294',
  );
  static const admobIosBanner = String.fromEnvironment(
    'ADMOB_IOS_BANNER',
    defaultValue: 'ca-app-pub-3940256099942544/2934735716',
  );
  static const admobAndroidInterstitial = String.fromEnvironment(
    'ADMOB_ANDROID_INTERSTITIAL',
    defaultValue: 'ca-app-pub-4025737666505759/4072959602',
  );
  static const admobIosInterstitial = String.fromEnvironment(
    'ADMOB_IOS_INTERSTITIAL',
    defaultValue: 'ca-app-pub-3940256099942544/4411468910',
  );

  static String get revenueCatKey {
    if (Platform.isAndroid) return revenueCatAndroidKey;
    if (Platform.isIOS) return revenueCatIosKey;
    return '';
  }
}
