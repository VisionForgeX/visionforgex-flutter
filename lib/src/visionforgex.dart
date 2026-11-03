import 'dart:async';

import 'package:flutter/services.dart';

import 'types.dart';

const String _channelName = 'com.visionforgex.sdk/methods';
const String _eventsName = 'com.visionforgex.sdk/events';

/// The VisionForgeX SDK. Start it once, as early as you can (before `runApp`, after
/// `WidgetsFlutterBinding.ensureInitialized()`):
///
/// ```dart
/// await VisionForgeX.initialize('vfx_…your app key…');
/// ```
///
/// Then show ads by placement name, as set on apps.visionforgex.com. Everything else (what each placement requests,
/// how often, when it may show, floors, consent, experiments) is decided by the platform.
class VisionForgeX {
  VisionForgeX._();

  /// This plugin's version.
  static const String version = '1.0.0';

  static MethodChannel _channel = const MethodChannel(_channelName);
  static EventChannel _events = const EventChannel(_eventsName);
  static Stream<Map<Object?, Object?>>? _stream;
  static int _showId = 0;

  /// Replaces the channels. Tests only.
  static void setChannelsForTesting(MethodChannel methods, EventChannel events) {
    _channel = methods;
    _events = events;
    _stream = null;
  }

  static Stream<Map<Object?, Object?>> get _all => _stream ??= _events.receiveBroadcastStream().map((e) => Map<Object?, Object?>.from(e as Map)).asBroadcastStream();

  /// Starts the SDK: its settings are fetched (the last ones used meanwhile), consent asked where the law needs it
  /// (Google's form), and the placements that preload begin loading. Completes when the SDK is ready or has found out
  /// why it is not. Calling it again does nothing new.
  static Future<VfxStatus> initialize(String appKey, {VfxOptions options = const VfxOptions()}) async {
    _all; // listen from the start, so no event is missed
    final r = await _channel.invokeMethod<Map<Object?, Object?>>('initialize', {'appKey': appKey, 'options': options.toMap()});
    return VfxStatus.fromMap(r ?? const {});
  }

  /// True once the SDK has settings that allow ads and consent allows requests.
  static Future<bool> isReady() async => (await _channel.invokeMethod<bool>('isReady')) ?? false;

  /// An interstitial placement.
  static VfxFullScreen interstitial(String placement) => VfxFullScreen._(placement, VfxFormat.interstitial);

  /// A rewarded placement.
  static VfxFullScreen rewarded(String placement) => VfxFullScreen._(placement, VfxFormat.rewarded);

  /// A rewarded interstitial placement.
  static VfxFullScreen rewardedInterstitial(String placement) => VfxFullScreen._(placement, VfxFormat.rewardedInterstitial);

  /// An app open placement (shown by itself when the platform turns that on; or call show()).
  static VfxFullScreen appOpen(String placement) => VfxFullScreen._(placement, VfxFormat.appOpen);

  /// Loads every placement that preloads (only needed with `VfxOptions(autoPreload: false)`).
  static Future<void> preloadAll() => _channel.invokeMethod<void>('preloadAll');

  /// A key-value of the app's own added to every request (e.g. "level" → "12"), for targeting and reports in Ad Manager.
  /// Keys: lowercase letters, digits and _, at most 20; "vfx_" is ours. Null removes it.
  static Future<void> setKeyValue(String key, String? value) => _channel.invokeMethod<void>('setKeyValue', {'key': key, 'value': value});

  /// Whether the app must offer a "Privacy options" button (users in the EEA, UK, Switzerland, some US states).
  static Future<bool> isPrivacyOptionsRequired() async => (await _channel.invokeMethod<bool>('isPrivacyOptionsRequired')) ?? false;

  /// Opens Google's privacy options form, from the app's "Privacy options" button. Completes with an error message, or null.
  static Future<String?> showPrivacyOptions() => _channel.invokeMethod<String>('showPrivacyOptions');

  /// Mutes video ads (the app's own sound setting).
  static Future<void> setMuted(bool muted) => _channel.invokeMethod<void>('setMuted', {'muted': muted});

  /// Google's ad inspector, for checking a live build.
  static Future<void> openAdInspector() => _channel.invokeMethod<void>('openAdInspector');

  /// Where the settings came from: "platform", "cache", "testing", or "none".
  static Future<String> settingsSource() async => (await _channel.invokeMethod<String>('settingsSource')) ?? 'none';

  /// Sends the events waiting now (they are sent by themselves too).
  static Future<void> flush() => _channel.invokeMethod<void>('flush');

  /// Every ad event as it happens.
  static Stream<VfxEvent> get events => _all.where((e) => e['kind'] == 'event').map(VfxEvent.fromMap);

  /// What each impression earned, for the app's own analytics.
  static Stream<VfxRevenue> get revenue => _all.where((e) => e['kind'] == 'revenue').map(VfxRevenue.fromMap);

  static int _nextShowId() => ++_showId;
  static Stream<Map<Object?, Object?>> _showEvents(int id) => _all.where((e) => e['kind'] == 'show' && e['id'] == id);
}

/// One full-screen placement: `VisionForgeX.interstitial('level_complete')`.
class VfxFullScreen {
  VfxFullScreen._(this.placement, this.format);

  final String placement;
  final VfxFormat format;

  Map<String, Object?> get _args => {'placement': placement, 'format': format.wire};

  /// An ad is loaded and fresh, so [show] will show it (if the pacing allows).
  Future<bool> isReady() async => (await VisionForgeX._channel.invokeMethod<bool>('fullScreenReady', _args)) ?? false;

  /// Loads one if none is waiting (placements that preload do this by themselves).
  Future<void> load() => VisionForgeX._channel.invokeMethod<void>('load', _args);

  /// Shows it if one is ready and the pacing allows. Completes when the ad has been closed, or at once with the reason
  /// nothing was shown; the app carries on either way. Safe to call at every opportunity: the platform's pacing decides.
  ///
  /// [onReward] (rewarded formats): the user earned the reward, before the ad is closed.
  Future<VfxShowResult> show({void Function(String type, int amount)? onReward, void Function()? onShown, void Function()? onClicked}) async {
    final id = VisionForgeX._nextShowId();
    final sub = VisionForgeX._showEvents(id).listen((e) {
      switch (e['event']) {
        case 'shown':
          onShown?.call();
          break;
        case 'clicked':
          onClicked?.call();
          break;
        case 'reward':
          onReward?.call((e['type'] as String?) ?? '', (e['amount'] as num?)?.toInt() ?? 0);
          break;
      }
    });
    try {
      final r = await VisionForgeX._channel.invokeMethod<Map<Object?, Object?>>('show', {..._args, 'id': id});
      await Future<void>.delayed(Duration.zero); // let a reward event that raced the answer be delivered
      return VfxShowResult(shown: r?['shown'] == true, reason: r?['reason'] as String?);
    } finally {
      await sub.cancel();
    }
  }
}
