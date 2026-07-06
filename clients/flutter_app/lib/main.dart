import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'src/kolkhoz_app.dart';

final _semanticsHandles = <SemanticsHandle>[];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  _semanticsHandles.add(SemanticsBinding.instance.ensureSemantics());
  runApp(const KolkhozApp());
}
