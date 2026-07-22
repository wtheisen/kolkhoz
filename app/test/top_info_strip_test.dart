import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/game_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

void main() {
  testWidgets('top info score keeps a three-digit value inside its cell', (
    tester,
  ) async {
    const cellKey = Key('score-cell');

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: SizedBox(
            key: cellKey,
            width: 92,
            child: TopInfoCell(
              icon: 'icon-plot.png',
              value: '125',
              tokens: defaultDesignTokens,
              height: 48,
              iconSize: 30.4,
              contentSpacing: 6,
            ),
          ),
        ),
      ),
    );

    final cell = tester.getRect(find.byKey(cellKey));
    final score = tester.getRect(find.byType(PixelText));

    expect(score.left, greaterThanOrEqualTo(cell.left));
    expect(score.right, lessThanOrEqualTo(cell.right));
  });

  testWidgets('completed job keeps its suit beside the checkmark', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: JobGauge(
          job: Job(
            suit: 'potato',
            hours: 40,
            requiredHours: 40,
            claimed: true,
            reward: null,
            assignedCards: [],
            validAssignmentTarget: false,
            highlighted: false,
          ),
          highlighted: false,
          width: 101,
          height: 38,
          tokens: defaultDesignTokens,
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('job-gauge-completed-suit-potato')),
      findsOneWidget,
    );
    final check = tester.widget<Image>(find.byType(Image).first);
    expect(
      (check.image as AssetImage).assetName,
      'assets/ui/Icons/icon-check.png',
    );
  });

  testWidgets('job gauge marks every Nomenklatura effect in its pile', (
    tester,
  ) async {
    const cards = [
      TableCard(
        id: 'wheat-11',
        suit: 'wheat',
        value: 11,
        rank: 'J',
        selected: false,
        highlighted: false,
        pending: false,
        nomenclature: true,
      ),
      TableCard(
        id: 'wheat-12',
        suit: 'wheat',
        value: 12,
        rank: 'Q',
        selected: false,
        highlighted: false,
        pending: false,
        nomenclature: true,
      ),
      TableCard(
        id: 'wheat-13',
        suit: 'wheat',
        value: 13,
        rank: 'K',
        selected: false,
        highlighted: false,
        pending: false,
        nomenclature: true,
      ),
    ];

    await tester.pumpWidget(
      const MaterialApp(
        home: JobGauge(
          job: Job(
            suit: 'wheat',
            hours: 36,
            requiredHours: 40,
            claimed: false,
            reward: null,
            assignedCards: cards,
            validAssignmentTarget: false,
            highlighted: false,
          ),
          highlighted: false,
          width: 140,
          height: 38,
          tokens: defaultDesignTokens,
        ),
      ),
    );

    for (final value in [11, 12, 13]) {
      expect(
        find.byKey(ValueKey('job-gauge-nomenklatura-$value-wheat')),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });
}
