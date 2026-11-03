/// The ad formats, as the platform names them.
enum VfxFormat {
  banner('banner'),
  interstitial('interstitial'),
  rewarded('rewarded'),
  rewardedInterstitial('rewarded_interstitial'),
  appOpen('app_open'),
  native('native');

  const VfxFormat(this.wire);
  final String wire;

  static VfxFormat? fromWire(String? s) {
    for (final f in VfxFormat.values) {
      if (f.wire == s) return f;
    }
    return null;
  }
}

/// How much the SDK writes to the console.
enum VfxLogLevel { none, error, warn, info, debug }

/// Options for [VisionForgeX.initialize]. Everything that decides revenue comes from the platform; these are only
/// for building and testing the app.
class VfxOptions {
  const VfxOptions({
    this.testDeviceIds = const [],
    this.logLevel,
    this.consentDebugEea = false,
    this.consentTestDeviceHashedIds = const [],
    this.baseUrl,
    this.autoPreload = true,
    this.googleDemoAds = false,
    this.settingsForTesting,
  });

  /// Google test devices: their ads are test ads (the console prints the ID on the first request).
  final List<String> testDeviceIds;

  /// Console output; null: as the platform says.
  final VfxLogLevel? logLevel;

  /// Show the consent form as if the device were in the EEA (testing only).
  final bool consentDebugEea;
  final List<String> consentTestDeviceHashedIds;

  /// The platform's address; only for testing against another server.
  final String? baseUrl;

  /// Start loading as soon as the settings arrive (true), or only when asked.
  final bool autoPreload;

  /// Testing only: every format on Google's own demo ad units (nothing is sent anywhere). Never in a release.
  final bool googleDemoAds;

  /// Testing only: these settings (the protocol's JSON) instead of the platform's.
  final String? settingsForTesting;

  Map<String, Object?> toMap() => {
        'testDeviceIds': testDeviceIds,
        'logLevel': logLevel?.name,
        'consentDebugEea': consentDebugEea,
        'consentTestDeviceHashedIds': consentTestDeviceHashedIds,
        'baseUrl': baseUrl,
        'autoPreload': autoPreload,
        'googleDemoAds': googleDemoAds,
        'settingsForTesting': settingsForTesting,
      };
}

/// What [VisionForgeX.initialize] found out.
class VfxStatus {
  const VfxStatus({required this.ready, required this.reason, required this.fromCache});

  /// Ads may be shown: settings received, the app enabled, consent allows requests.
  final bool ready;

  /// Why not, when [ready] is false.
  final String reason;

  /// Settings came from the cache (the platform was not reached).
  final bool fromCache;

  factory VfxStatus.fromMap(Map<Object?, Object?> m) => VfxStatus(
        ready: m['ready'] == true,
        reason: (m['reason'] as String?) ?? '',
        fromCache: m['fromCache'] == true,
      );
}

/// What happened to one `show()` call.
class VfxShowResult {
  const VfxShowResult({required this.shown, this.reason});

  /// An ad was shown (and has been closed by now).
  final bool shown;

  /// When nothing was shown: "not_ready", "paused", "consent", "interval", "session", "hour", "day", "grace",
  /// "nth", "gap", "showing", "failed", "no_activity", "unknown_placement".
  final String? reason;

  @override
  String toString() => shown ? 'VfxShowResult(shown)' : 'VfxShowResult(not shown: $reason)';
}

/// Every ad event as it happens (for the app's own analytics). [type] is one of the protocol's: req, fill, nofill,
/// show, click, close, fail, reward, paid, capped.
class VfxEvent {
  const VfxEvent({required this.type, required this.placement, required this.format, required this.details, required this.time});

  final String type;
  final String placement;
  final VfxFormat? format;

  /// The rest: tier, ms, err, why, src, and for "paid" v (micros), cur, prec.
  final Map<String, Object?> details;
  final int time;

  factory VfxEvent.fromMap(Map<Object?, Object?> m) => VfxEvent(
        type: (m['type'] as String?) ?? '',
        placement: (m['placement'] as String?) ?? '',
        format: VfxFormat.fromWire(m['format'] as String?),
        details: {for (final e in ((m['details'] as Map?) ?? const {}).entries) e.key.toString(): e.value},
        time: (m['time'] as num?)?.toInt() ?? 0,
      );
}

/// What one impression earned, as Google reported it (its paid event): for Firebase, AppsFlyer, Adjust…
class VfxRevenue {
  const VfxRevenue({required this.placement, required this.format, required this.valueMicros, required this.currency, required this.precision, this.source});

  final String placement;
  final VfxFormat? format;

  /// Micros: 1,000,000 = one unit of [currency].
  final int valueMicros;
  final String currency;
  final String precision;
  final String? source;

  double get value => valueMicros / 1000000.0;

  factory VfxRevenue.fromMap(Map<Object?, Object?> m) => VfxRevenue(
        placement: (m['placement'] as String?) ?? '',
        format: VfxFormat.fromWire(m['format'] as String?),
        valueMicros: (m['valueMicros'] as num?)?.toInt() ?? 0,
        currency: (m['currency'] as String?) ?? '',
        precision: (m['precision'] as String?) ?? '',
        source: m['source'] as String?,
      );
}
