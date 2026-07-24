import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';

void main() {
  testWidgets('art assets render their field-plan source', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ArtAssetImage(
          asset: ArtAssetRef(fieldPlanPath: 'assets/ui/Icons/icon-check.png'),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName ==
                'assets/ui/Icons/icon-check.png',
      ),
      findsOneWidget,
    );
  });
}
