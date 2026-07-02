import 'package:flutter/material.dart';

import 'src/fixture_app.dart';
import 'src/fixture_repository.dart';

void main() {
  runApp(FixtureRendererApp(repository: FixtureRepository()));
}
