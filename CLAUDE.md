# Working on the VisionForgeX plugin for Flutter

A thin plugin over the native VisionForgeX SDKs (`VisionForgeX/visionforgex-android-sdk`, `VisionForgeX/visionforgex-ios-sdk`).
This repository is **public** and holds only what runs inside an app. It makes **no decision**: pacing, floors, refresh,
consent tags and experiments all live on the platform (private repository `VisionForgeX/visionforgex-apps`) and arrive
through the native SDKs. If a feature needs a decision, it is built there, not here.

## Rules
- **Push after every change**, with a CHANGELOG line; tag releases (`1.0.0`); `flutter pub publish` is the owner's step.
- Keep the Dart API compatible within a major version. Mirror the native SDKs' names and the reason strings of
  `docs/PROTOCOL.md` (in the native repositories).
- The channel names and map keys are a contract between `lib/src/visionforgex.dart`, the Kotlin and the Swift plugin:
  change all three together.
- **Test what you change.** CI runs `flutter analyze`, `flutter test`, and builds the example for Android and iOS.
  Never report a pass you did not watch: Claude's workspace has no Flutter, Dart, Swift or Xcode, so code written
  there is "not compiled" until CI is green.
- Publisher-facing wording says VisionForgeX and support@visionforgex.com.
