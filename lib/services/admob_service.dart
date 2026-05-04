import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final adServiceProvider = Provider<AdMobService>((ref) =>
  AdMobService()..loadRewardedAd()..loadInterstitialAd());
  
final bannerAdProvider = Provider<Widget?>((ref) {
  final svc = ref.watch(adServiceProvider);
  return svc.buildBannerWidget();
});

class AdMobService {
  RewardedAd? _rewarded;
  BannerAd? _banner;
  InterstitialAd? _interstitial;
  bool _rewardedLoaded = false;
  int _attempts = 0;

  static String get _rewardedId => Platform.isAndroid
      ? (const bool.fromEnvironment('dart.vm.product')
          ? (dotenv.env['ADMOB_ANDROID_REWARDED'] ?? 'ca-app-pub-3940256099942544/5224354917')
          : 'ca-app-pub-3940256099942544/5224354917')
      : (const bool.fromEnvironment('dart.vm.product')
          ? (dotenv.env['ADMOB_IOS_REWARDED'] ?? 'ca-app-pub-3940256099942544/1712485313')
          : 'ca-app-pub-3940256099942544/1712485313');
          
  static String get _bannerId => Platform.isAndroid
      ? (const bool.fromEnvironment('dart.vm.product') ? (dotenv.env['ADMOB_ANDROID_BANNER'] ?? 'ca-app-pub-3940256099942544/6300978111') : 'ca-app-pub-3940256099942544/6300978111') 
      : (const bool.fromEnvironment('dart.vm.product') ? (dotenv.env['ADMOB_IOS_BANNER'] ?? 'ca-app-pub-3940256099942544/2934735716') : 'ca-app-pub-3940256099942544/2934735716');
      
  static String get _interstitialId => Platform.isAndroid
      ? (const bool.fromEnvironment('dart.vm.product') ? (dotenv.env['ADMOB_ANDROID_INTERSTITIAL'] ?? 'ca-app-pub-3940256099942544/1033173712') : 'ca-app-pub-3940256099942544/1033173712') 
      : (const bool.fromEnvironment('dart.vm.product') ? (dotenv.env['ADMOB_IOS_INTERSTITIAL'] ?? 'ca-app-pub-3940256099942544/4411468910') : 'ca-app-pub-3940256099942544/4411468910');

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(adUnitId: _rewardedId, request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
            onAdLoaded: (ad) { _rewarded = ad; _rewardedLoaded = true; _attempts = 0; },
            onAdFailedToLoad: (err) {
              _rewardedLoaded = false; _rewarded = null; _attempts++;
              if (_attempts < 3) Future.delayed(const Duration(seconds: 3), loadRewardedAd);
            }));
  }

  Future<bool> showRewardedAd({required VoidCallback onRewarded, required VoidCallback onFailed}) async {
    if (!_rewardedLoaded || _rewarded == null) { onFailed(); return false; }
    bool rewarded = false;
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose(); _rewarded = null; _rewardedLoaded = false;
          loadRewardedAd(); 
          if (!rewarded) onFailed(); 
        },
        onAdFailedToShowFullScreenContent: (ad, err) {
          ad.dispose(); _rewarded = null; _rewardedLoaded = false; onFailed();
        });
    await _rewarded!.show(onUserEarnedReward: (_, __) { rewarded = true; onRewarded(); });
    return true;
  }

  Future<void> loadBannerAd() async {
    _banner = BannerAd(adUnitId: _bannerId, size: AdSize.banner,
        request: const AdRequest(), listener: BannerAdListener());
    await _banner!.load();
  }

  Widget? buildBannerWidget() {
    if (_banner == null) { loadBannerAd(); return null; }
    return SizedBox(height: _banner!.size.height.toDouble(),
        child: AdWidget(ad: _banner!));
  }

  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(adUnitId: _interstitialId, request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
            onAdLoaded: (ad) => _interstitial = ad,
            onAdFailedToLoad: (_) => _interstitial = null));
  }

  Future<void> showInterstitialAd() async {
    await _interstitial?.show();
    _interstitial = null;
    loadInterstitialAd();
  }

  bool get isRewardedReady => _rewardedLoaded && _rewarded != null;
}
