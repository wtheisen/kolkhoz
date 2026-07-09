import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'src/kolkhoz_app.dart';

final _semanticsHandles = <SemanticsHandle>[];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _lockMobileLandscape();
  _semanticsHandles.add(SemanticsBinding.instance.ensureSemantics());
  runApp(const KolkhozApp());
}

Future<void> _lockMobileLandscape() async {
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
      break;
  }
}
