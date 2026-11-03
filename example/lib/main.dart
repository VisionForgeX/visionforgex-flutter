import 'package:flutter/material.dart';
import 'package:visionforgex/visionforgex.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Google's demo ad units: always fill with test ads, nothing is sent anywhere. In a real app: VisionForgeX.initialize('vfx_…').
  await VisionForgeX.initialize('demo', options: const VfxOptions(googleDemoAds: true));
  runApp(const MaterialApp(home: Demo()));
}

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  String _log = 'ready';

  Future<void> _interstitial() async {
    final r = await VisionForgeX.interstitial('interstitial').show();
    setState(() => _log = r.toString());
  }

  Future<void> _rewarded() async {
    final r = await VisionForgeX.rewarded('rewarded').show(onReward: (type, amount) => setState(() => _log = 'reward $amount $type'));
    if (!r.shown) setState(() => _log = r.toString());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('VisionForgeX demo')),
        body: Column(children: [
          Padding(padding: const EdgeInsets.all(16), child: Text(_log)),
          ElevatedButton(onPressed: _interstitial, child: const Text('Interstitial')),
          ElevatedButton(onPressed: _rewarded, child: const Text('Rewarded')),
          const Spacer(),
          const VfxBanner(placement: 'banner'),
        ]),
      );
}
