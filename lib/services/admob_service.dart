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

/// AdMob error codes from the Google Mobile Ads SDK.
///
/// These are the standard codes returned in [LoadAdError.code]:
///   0 = Internal error           → not user's fault, bypass gracefully
///   1 = Invalid request          → app config issue, bypass gracefully
///   2 = Network error            → DNS/network blocked, count toward ad-blocker
///   3 = No fill                  → AdMob has no ads to serve, bypass gracefully
///
/// We ONLY count code 2 (network errors) toward the ad-block detection
/// threshold. This ensures users are never blocked due to:
///   - AdMob having no fill for their region/device
///   - AdMob not yet approving the app
///   - Temporary AdMob outages
///   - Misconfigured ad unit IDs
class AdMobService {
  RewardedAd?     _rewarded;
  InterstitialAd? _interstitial;
  bool            _rewardedLoaded = false;
  int             _attempts       = 0;

  // ── Ad-block detection ────────────────────────────────────────────────────
  /// Count of consecutive NETWORK errors (error code 2) only.
  /// No-fill (3), internal (0), invalid (1) are NOT counted.
  int _consecutiveNetworkFailures = 0;

  /// After this many consecutive network failures, we flag as ad-blocked.
  static const int _blockThreshold = 3;

  /// Returns true ONLY when we detect the device is actively blocking
  /// ad network requests (private DNS, ad blocker app, VPN filter, Pi-hole).
  ///
  /// Returns false for all other ad failures (no fill, internal, config).
  bool get isAdBlocked => _consecutiveNetworkFailures >= _blockThreshold;

  /// Returns true when AdMob simply has no ads to serve (no fill).
  /// In this case we allow the feature through gracefully — it's AdMob's issue.
  bool get hasNoFill => !_rewardedLoaded && !isAdBlocked;

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
          _rewarded                  = ad;
          _rewardedLoaded            = true;
          _attempts                  = 0;
          _consecutiveNetworkFailures = 0; // success resets the counter
        },
        onAdFailedToLoad: (err) {
          _rewardedLoaded = false;
          _rewarded       = null;
          _attempts++;

          // Only code 2 (network error) indicates ad blocking.
          // code 3 = no fill  → AdMob has nothing to serve, NOT blocking.
          // code 0/1 = config → app issue, NOT blocking.
          if (err.code == 2) {
            _consecutiveNetworkFailures++;
            debugPrint('[AdMob] Network error #$_consecutiveNetworkFailures '
                '(code ${err.code}): ${err.message}');
          } else {
            // For no-fill and other errors: reset the blocker counter
            // because these prove the DNS/network is NOT blocking ad servers.
            _consecutiveNetworkFailures = 0;
            debugPrint('[AdMob] Non-blocking failure '
                '(code ${err.code}): ${err.message}');
          }

          if (_attempts < 3) {
            Future.delayed(const Duration(seconds: 3), loadRewardedAd);
          }
        },
      ),
    );
  }

  // ── Show rewarded ad (fire-and-forget) ───────────────────────────────────
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
        _rewarded       = null;
        _rewardedLoaded = false;
        loadRewardedAd();
        if (!rewarded) onFailed();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded       = null;
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

  // ── Load interstitial ─────────────────────────────────────────────────────
  Future<void> loadInterstitialAd() async {
    await InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitial = ad;
          _consecutiveNetworkFailures = 0; // interstitial success also resets
        },
        onAdFailedToLoad: (err) {
          _interstitial = null;
          if (err.code == 2) _consecutiveNetworkFailures++;
          // No-fill/config errors on interstitial do NOT count as blocking
        },
      ),
    );
  }

  Future<void> showInterstitialAd() async {
    await _interstitial?.show();
    _interstitial = null;
    loadInterstitialAd();
  }

  // ── Show rewarded ad and await completion ─────────────────────────────────
  Future<void> showRewardedAdAndWait({
    required VoidCallback onAdWatched,
    required VoidCallback onAdFailed,
  }) async {
    if (!_rewardedLoaded || _rewarded == null) {
      onAdFailed();
      return;
    }
    final completer = Completer<void>();
    bool rewarded = false;
    _rewarded!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded       = null;
        _rewardedLoaded = false;
        loadRewardedAd();
        if (rewarded) {
          onAdWatched();
        } else {
          onAdFailed();
        }
        if (!completer.isCompleted) completer.complete();
      },
      onAdFailedToShowFullScreenContent: (ad, err) {
        ad.dispose();
        _rewarded       = null;
        _rewardedLoaded = false;
        onAdFailed();
        loadRewardedAd();
        if (!completer.isCompleted) completer.complete();
      },
    );
    await _rewarded!.show(
      onUserEarnedReward: (ad, reward) {
        rewarded = true;
      },
    );
    await completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {},
    );
  }

  bool get isRewardedReady => _rewardedLoaded && _rewarded != null;
}
