import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A banner for one placement: adaptive to the width it is given (Google's anchored adaptive size), refreshed as the
/// platform says only while seen, collapsible when the platform says so. It loads by itself once on screen.
///
/// ```dart
/// const VfxBanner(placement: 'home_banner')
/// ```
///
/// [height] is the room reserved for it (an anchored adaptive banner is 50–90 logical pixels tall).
class VfxBanner extends StatelessWidget {
  const VfxBanner({super.key, required this.placement, this.height = 60});

  final String placement;
  final double height;

  static const String viewType = 'com.visionforgex.sdk/banner';

  @override
  Widget build(BuildContext context) {
    final params = <String, Object?>{'placement': placement};
    Widget view;
    if (kIsWeb) {
      return const SizedBox.shrink();
    } else if (Platform.isAndroid) {
      view = AndroidView(viewType: viewType, creationParams: params, creationParamsCodec: const StandardMessageCodec());
    } else if (Platform.isIOS) {
      view = UiKitView(viewType: viewType, creationParams: params, creationParamsCodec: const StandardMessageCodec());
    } else {
      return const SizedBox.shrink();
    }
    return SizedBox(height: height, width: double.infinity, child: view);
  }
}
