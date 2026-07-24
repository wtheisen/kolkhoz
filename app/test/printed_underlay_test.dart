import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';
import 'package:kolkhoz_app/src/app/views/shared/printed_underlay.dart';

void main() {
  testWidgets('underlays scale across reusable control sizes', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Column(
          children: [
            SizedBox(
              width: 120,
              height: 40,
              child: PrintedUnderlay(child: Text('SMALL')),
            ),
            SizedBox(
              width: 320,
              height: 56,
              child: PrintedUnderlay(
                tone: PrintedUnderlayTone.primary,
                focused: true,
                child: Text('PRIMARY'),
              ),
            ),
            SizedBox(
              width: 600,
              height: 80,
              child: PrintedUnderlay(
                tone: PrintedUnderlayTone.disabled,
                child: Text('DISABLED'),
              ),
            ),
          ],
        ),
      ),
    );
    final context = tester.element(find.byType(PrintedUnderlay).first);
    await tester.runAsync(() async {
      await Future.wait([
        ChromeImageCache.load(
          context,
          'assets/art/field_plan/ledger/underlays/ledger-neutral.png',
        ),
        ChromeImageCache.load(
          context,
          'assets/art/field_plan/ledger/underlays/ledger-primary.png',
        ),
      ]);
    });
    await tester.pumpAndSettle();
    expect(find.text('SMALL'), findsOneWidget);
    expect(find.text('PRIMARY'), findsOneWidget);
    expect(find.text('DISABLED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
