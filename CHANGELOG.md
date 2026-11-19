# Changelog

## 1.0.1 (19 Nov 2026)
On the native SDKs **1.3.0** (Android `vfx-ads-nextgen`/`vfx-ads` 1.3.0 from JitPack; iOS pod `VisionForgeX` 1.3.0, the
podspec now needs `~> 1.3`, so the app's Podfile line moves to `:tag => '1.3.0'`). What it adds: when VisionForgeX
switches it on for the app, each impression's revenue goes to AppsFlyer (6.15+) or Adjust if the app has it, with no Dart
to write. The Dart API is unchanged; an app that has neither tool behaves exactly as with 1.0.0.

## 1.0.0 (15 Nov 2026)
On the native SDKs 1.2.0. **Android runs on Google's GMA Next-Gen SDK by default** (Google's preferred Android SDK);
`visionforgexEngine=gma` in the app's `android/gradle.properties` keeps Google Mobile Ads 25.x instead (retired by Google
on 30 Jun 2028). The app's Dart code is the same either way. iOS: Google Mobile Ads 13 (needs Xcode 16). compileSdk 35.
The package is named `visionforgex_flutter` (import `package:visionforgex_flutter/visionforgex_flutter.dart`): a Flutter plugin named `visionforgex` made CocoaPods refuse it beside the native `VisionForgeX` pod (framework names that differ only in case).
First version. A thin bridge over the VisionForgeX SDKs: Android 1.0.2 (JitPack) and iOS 1.0.0 (CocoaPods). Every decision is made by the platform.
- `VisionForgeX.initialize`, `interstitial`, `rewarded`, `rewardedInterstitial`, `appOpen` with `show()` returning why nothing was shown, `setKeyValue`, consent (`isPrivacyOptionsRequired`, `showPrivacyOptions`), `events` and `revenue` streams, `VfxBanner` widget.
- Not in 1.0.0: native ads, the debug panel.
- Written without a Flutter or Dart toolchain: the first CI run is the first analyze, test and build.
