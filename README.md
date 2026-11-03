# VisionForgeX for Flutter

Ads for Flutter apps monetized with [VisionForgeX](https://apps.visionforgex.com): Google Ad Manager demand (Google Ad
Exchange) through your VisionForgeX account. A thin plugin over the native VisionForgeX SDKs; **every decision**
(pacing, floors, refresh, preloading, consent, experiments) is made on the platform and changes without an app update.

## Add it

`pubspec.yaml`:

```yaml
dependencies:
  visionforgex_flutter: ^1.0.0
```

**Android**: in `android/app/src/main/AndroidManifest.xml`, inside `<application>`, the App ID shown on your app's page
on VisionForgeX (minSdk 24):

```xml
<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="ca-app-pub-…~…"/>
```

**iOS**: in `ios/Runner/Info.plist` (iOS 13 or later):

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-…~…</string>
```

plus Google's SKAdNetwork identifiers (list on Google's site). In `ios/Podfile`, Google's ad SDK is a static library, so
change `use_frameworks!` to `use_frameworks! :linkage => :static`. Then run `cd ios && pod install`.

## Start it and show ads

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VisionForgeX.initialize('vfx_…your app key…');
  runApp(const MyApp());
}

// at a natural pause: call at every one; the platform decides whether an ad shows now
final r = await VisionForgeX.interstitial('level_complete').show();   // r.shown, r.reason

// rewarded
await VisionForgeX.rewarded('extra_life').show(onReward: (type, amount) => giveReward());

// a banner
const VfxBanner(placement: 'home_banner')
```

The key and the placement names are on your app's page on VisionForgeX. App open ads show by themselves on return to
the app when the platform turns that on.

## Test before you have an account

```dart
await VisionForgeX.initialize('demo', options: const VfxOptions(googleDemoAds: true));
```

Placements: `banner`, `collapsible_banner`, `interstitial`, `rewarded`, `rewarded_interstitial`, `app_open`. See `example/`.

## Privacy options, revenue, events

```dart
if (await VisionForgeX.isPrivacyOptionsRequired()) await VisionForgeX.showPrivacyOptions();
VisionForgeX.revenue.listen((r) { /* r.valueMicros, r.currency → Firebase, AppsFlyer, Adjust */ });
VisionForgeX.events.listen((e) { /* req, fill, nofill, show, click, close, fail, reward, paid, capped */ });
```

## Status

1.0.0 is written but has not yet been through its first CI run. Native ads are not in this version.
