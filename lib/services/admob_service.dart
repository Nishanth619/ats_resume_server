import 'dart:async';
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

/// AdMob error codes (LoadAdError.code):
///   0 = Internal error
///   1 = Invalid request
///   2 = Network error  ← DNS/connection blocked → count toward ad-block
///   3 = No fill        ← AdMob has nothing to serve
class AdMobService {
  RewardedAd?     _rewarded;
  InterstitialAd? _interstitial;
  bool            _rewardedLoaded = false;
  int             _attempts       = 0;

  // ── Ad-block detection ────────────────────────────────────────────────────
  int _consecutiveNetworkFailures = 0;
  static const int _blockThreshold = 3;

  /// True when 3+ consecutive network-error (code 2) failures have occurred.
  /// Indicates private DNS / ad-blocker / Pi-hole / VPN filter.
  bool get isAdBlocked => _consecutiveNetworkFailures >= _blockThreshold;

  // ── Ad unit IDs ───────────────────────────────────────────────────────────
  static String get _rewardedId => Platform.isAndroid
      ? AppConfig.admobAndroidRewarded
      : AppConfig.admobIosRewarded;

  static String get _interstitialId => Platform.isAndroid
      ? AppConfig.admobAndroidInterstitial
      : AppConfig.admobIosInterstitial;

  // ── Load rewarded ad ──────────────────────────────────────────────────────
  Future<void> loadRewardedAd() async {
    await RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewarded                   = ad;
          _rewardedLoaded             = true;
          _attempts                   = 0;
          _consecutiveNetworkFailures = 0; // success resets counter
        },
        onAdFailedToLoad: (err) {
          _rewardedLoaded = false;
          _rewarded       = null;
          _attempts++;

          if (err.code == 2) {
            // Network error — DNS/connection blocked
            _consecutiveNetworkFailures++;
            debugPrint('[AdMob] Network error #$_consecutiveNetworkFailures '
                '(code ${err.code}): ${err.message}');
          } else {
            // No-fill (3) or config error (0/1) — AdMob's side, NOT blocking
            // Reset so we never falsely flag as ad-blocked due to AdMob issues
            _consecutiveNetworkFailures = 0;
            debugPrint('[AdMob] Non-blocking failure '
                '(code ${err.code}): ${err.message}');
          }

          // Auto-retry up to 3 times
          if (_attempts < 3) {
            Future.delayed(const Duration(seconds: 3), loadRewardedAd);
          }
        },
      ),
    );
  }

  // ── Show rewarded ad and await reward ─────────────────────────────────────
  /// Shows the rewarded ad and waits for it to close.
  ///
  /// Returns `true` ONLY if [onUserEarnedReward] fired — meaning the user
  /// actually watched the ad to completion.
  ///
  /// Returns `false` for every other case:
  ///   - Ad not loaded (no fill / blocker)
  ///   - Ad dismissed before reward (user skipped)
  ///   - Ad failed to show
  ///
  /// This is the OctaVPN pattern: only `onUserEarnedReward` unlocks features.
  Future<bool> showRewardedAdAndWait() async {
    if (!_rewardedLoaded || _rewarded == null) {
      return false; // no ad available — do NOT give free access
    }

    final completer = Completer<bool>();
    bool rewarded = false;

    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded       = null;
        _rewardedLoaded = false;
        loadRewardedAd(); // preload next ad
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded       = null;
        _rewardedLoaded = false;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _rewarded!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true; // only set on actual reward
      },
    );

    // Wait for dismiss callback (max 60s safety timeout)
    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
  }

  // ── Legacy showRewardedAd (used by download_screen) ───────────────────────
  /// Returns `true` only if reward was earned.
  Future<bool> showRewardedAd() async {
    if (!_rewardedLoaded || _rewarded == null) return false;

    final completer = Completer<bool>();
    bool rewarded = false;

    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded       = null;
        _rewardedLoaded = false;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(rewarded);
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded       = null;
        _rewardedLoaded = false;
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    await _rewarded!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
      },
    );

    return completer.future.timeout(
      const Duration(seconds: 60),
      onTimeout: () => false,
    );
  }

  // ── Interstitial ──────────────────────────────────────────────────────────
  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial               = ad;
          _consecutiveNetworkFailures = 0;
        },
        onAdFailedToLoad: (err) {
          _interstitial = null;
          if (err.code == 2) _consecutiveNetworkFailures++;
        },
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
