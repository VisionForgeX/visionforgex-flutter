# Changelog

## 1.0.0 (not released)
First version. A thin bridge over the VisionForgeX SDKs: Android 1.0.2 (JitPack) and iOS 1.0.0 (CocoaPods). Every decision is made by the platform.
- `VisionForgeX.initialize`, `interstitial`, `rewarded`, `rewardedInterstitial`, `appOpen` with `show()` returning why nothing was shown, `setKeyValue`, consent (`isPrivacyOptionsRequired`, `showPrivacyOptions`), `events` and `revenue` streams, `VfxBanner` widget.
- Not in 1.0.0: native ads, the debug panel.
- Written without a Flutter or Dart toolchain: the first CI run is the first analyze, test and build.
