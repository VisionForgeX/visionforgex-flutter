import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:visionforgex_flutter/visionforgex_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const methods = MethodChannel('com.visionforgex.sdk/methods');
  const events = EventChannel('com.visionforgex.sdk/events');
  final calls = <MethodCall>[];
  MockStreamHandlerEventSink? sink;
  Object? Function(MethodCall)? answer;

  setUp(() {
    calls.clear();
    sink = null;
    answer = null;
    VisionForgeX.setChannelsForTesting(methods, events);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(methods, (call) async {
      calls.add(call);
      return answer?.call(call);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      events,
      MockStreamHandler.inline(onListen: (args, s) => sink = s, onCancel: (args) => sink = null),
    );
  });

  test('initialize sends the key and the options, and reads the status', () async {
    answer = (c) => {'ready': true, 'reason': '', 'fromCache': true};
    final st = await VisionForgeX.initialize('vfx_key', options: const VfxOptions(autoPreload: false, logLevel: VfxLogLevel.debug));
    expect(st.ready, isTrue);
    expect(st.fromCache, isTrue);
    expect(calls.single.method, 'initialize');
    final a = calls.single.arguments as Map;
    expect(a['appKey'], 'vfx_key');
    expect((a['options'] as Map)['autoPreload'], false);
    expect((a['options'] as Map)['logLevel'], 'debug');
  });

  test('show says why nothing was shown', () async {
    answer = (c) => {'shown': false, 'reason': 'interval'};
    final r = await VisionForgeX.interstitial('level_complete').show();
    expect(r.shown, isFalse);
    expect(r.reason, 'interval');
    final a = calls.single.arguments as Map;
    expect(a['placement'], 'level_complete');
    expect(a['format'], 'interstitial');
  });

  test('a reward that arrives while the ad is showing reaches the app, once, and the call completes when it closes', () async {
    await VisionForgeX.initialize('k').catchError((_) => const VfxStatus(ready: false, reason: '', fromCache: false));
    final closed = Completer<Map<String, Object?>>();
    answer = (c) {
      if (c.method == 'show') return closed.future;
      return {'ready': true, 'reason': '', 'fromCache': false};
    };
    final rewards = <String>[];
    final f = VisionForgeX.rewarded('extra_life').show(onReward: (t, n) => rewards.add('$t:$n'));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final id = (calls.firstWhere((c) => c.method == 'show').arguments as Map)['id'];
    sink?.success({'kind': 'show', 'id': id, 'event': 'reward', 'type': 'coins', 'amount': 5});
    sink?.success({'kind': 'show', 'id': id + 1000, 'event': 'reward', 'type': 'other', 'amount': 1}); // another call's
    await Future<void>.delayed(const Duration(milliseconds: 20));
    closed.complete({'shown': true, 'reason': null});
    final r = await f;
    expect(rewards, ['coins:5']);
    expect(r.shown, isTrue);
  });

  test('revenue and events come through as typed values', () async {
    answer = (c) => {'ready': true, 'reason': '', 'fromCache': false};
    await VisionForgeX.initialize('k');
    final rev = VisionForgeX.revenue.first;
    final ev = VisionForgeX.events.first;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    sink?.success({'kind': 'revenue', 'placement': 'lv', 'format': 'interstitial', 'valueMicros': 4210, 'currency': 'USD', 'precision': 'PRECISE', 'source': 'Google AdMob'});
    sink?.success({'kind': 'event', 'type': 'fill', 'placement': 'lv', 'format': 'interstitial', 'time': 1, 'details': {'tier': 1}});
    final r = await rev;
    expect(r.valueMicros, 4210);
    expect(r.value, closeTo(0.00421, 1e-9));
    expect(r.format, VfxFormat.interstitial);
    final e = await ev;
    expect(e.type, 'fill');
    expect(e.details['tier'], 1);
  });

  test('the small calls go to the native side with their arguments', () async {
    answer = (c) => c.method == 'isReady' ? true : null;
    expect(await VisionForgeX.isReady(), isTrue);
    await VisionForgeX.setKeyValue('level', '12');
    await VisionForgeX.setMuted(true);
    expect(calls.map((c) => c.method), ['isReady', 'setKeyValue', 'setMuted']);
    expect((calls[1].arguments as Map)['key'], 'level');
  });

  test('formats read from the wire', () {
    expect(VfxFormat.fromWire('rewarded_interstitial'), VfxFormat.rewardedInterstitial);
    expect(VfxFormat.fromWire('video'), isNull);
  });
}
