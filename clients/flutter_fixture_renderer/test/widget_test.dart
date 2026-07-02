import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_fixture_renderer/src/fixture_app.dart';
import 'package:kolkhoz_fixture_renderer/src/fixture_repository.dart';

void main() {
  testWidgets('renders all shared fixture tabs', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      FixtureRendererApp(repository: FixtureRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kolkhoz fixtures'), findsOneWidget);
    expect(find.text('planning trump selection'), findsOneWidget);
    expect(find.text('assignment pending'), findsOneWidget);
    expect(find.text('online redacted swap'), findsOneWidget);
    expect(find.text('SET TRUMP'), findsOneWidget);

    await tester.tap(find.text('assignment pending'));
    await tester.pumpAndSettle();
    expect(find.text('Assign work'), findsOneWidget);

    await tester.tap(find.text('online redacted swap'));
    await tester.pumpAndSettle();
    expect(find.text('Swap one card'), findsOneWidget);
    expect(find.text('Online: connected'), findsOneWidget);
  });
}
