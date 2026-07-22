import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/game/views/plots/plots_view.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_state_models.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

void main() {
  test('online snapshots preserve redacted opponent cellar counts', () {
    final player = OnlinePlayerSnapshot.fromJson({
      'id': 1,
      'hand': <Object?>[],
      'revealedPlot': <Object?>[],
      'hiddenPlot': <Object?>[],
      'hiddenPlotCount': 3,
      'medals': 0,
      'bankedMedals': 0,
      'brigadeLeader': false,
      'wonTrickThisYear': false,
      'stacks': [
        {
          'revealed': [
            {'suit': 0, 'value': 8},
          ],
          'hidden': <Object?>[],
          'hiddenCount': 2,
        },
      ],
    });

    expect(player.effectiveHiddenPlotCount, 3);
    expect(player.stacks.single.effectiveHiddenCount, 2);
  });

  testWidgets('opponent plot shows stacked cards and redacted cellar backs', (
    tester,
  ) async {
    const stackedCard = TableCard(
      id: 'wheat-8',
      suit: 'wheat',
      value: 8,
      rank: '8',
      selected: false,
      highlighted: false,
      pending: false,
      assignmentRound: null,
      nomenclature: false,
    );
    const seat = Seat(
      id: 1,
      name: 'Opponent',
      controller: 'remoteHuman',
      portraitAsset: 'worker2',
      isViewer: false,
      isCurrentTurn: false,
      isBrigadeLeader: false,
      hand: [],
      hiddenHandCount: 0,
      plot: PlotState(
        revealed: [],
        hidden: [],
        hiddenCardCount: 3,
        stacks: [
          PlotStackState(
            revealed: [stackedCard],
            hidden: [],
            hiddenCardCount: 2,
          ),
        ],
      ),
      medals: 0,
      visibleScore: 8,
    );
    final metrics = PlotPanelMetrics.fromSize(
      const Size(900, 300),
      defaultDesignTokens,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 900,
          height: 300,
          child: OpponentPlotPanel(
            seat: seat,
            metrics: metrics,
            tokens: defaultDesignTokens,
            exiledCardIDs: const {},
            hiddenExiledCardIDs: const {},
          ),
        ),
      ),
    );

    expect(find.byType(GameCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('opponent-hidden-card-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('opponent-hidden-card-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
