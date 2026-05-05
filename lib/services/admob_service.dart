import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../core/config/app_config.dart';

final adServiceProvider = Provider<AdMobService>(
  (ref) => AdMobService()
    ..loadRewardedAd()
    ..loadInterstitialAd(),
);

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
      ? AppConfig.admobAndroidRewarded
      : AppConfig.admobIosRewarded;

  static String get _bannerId => Platform.isAndroid
      ? AppConfig.admobAndroidBanner
      : AppConfig.admobIosBanner;

  static String get _interstitialId => Platform.isAndroid
      ? AppConfig.admobAndroidInterstitial
      : AppConfig.admobIosInterstitial;

  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded = ad;
          _rewardedLoaded = true;
          _attempts = 0;
        },
        onAdFailedToLoad: (err) {
          _rewardedLoaded = false;
          _rewarded = null;
          _attempts++;
          if (_attempts < 3) {
            Future.delayed(const Duration(seconds: 3), loadRewardedAd);
          }
        },
      ),
    );
  }

  Future<bool> showRewardedAd({
    required VoidCallback onRewarded,
    required VoidCallback onFailed,
  }) async {
    if (!_rewardedLoaded || _rewarded == null) {
      onFailed();
      return false;
    }
    bool rewarded = false;
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded = null;
        _rewardedLoaded = false;
        loadRewardedAd();
        if (!rewarded) onFailed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded = null;
        _rewardedLoaded = false;
        onFailed();
      },
    );
    await _rewarded!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
        onRewarded();
      },
    );
    return true;
  }

  Future<void> loadBannerAd() async {
    _banner = BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(),
    );
    await _banner!.load();
  }

  Widget? buildBannerWidget() {
    if (_banner == null) {
      loadBannerAd();
      return null;
    }
    return SizedBox(
      height: _banner!.size.height.toDouble(),
      child: AdWidget(ad: _banner!),
    );
  }

  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitial = ad,
        onAdFailedToLoad: (_) => _interstitial = null,
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    await _interstitial?.show();
    _interstitial = null;
    loadInterstitialAd();
  }

  bool get isRewardedReady => _rewardedLoaded && _rewarded != null;
}
