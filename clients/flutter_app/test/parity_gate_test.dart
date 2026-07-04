import 'dart:ffi';

import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/game_constants.dart';
import 'package:kolkhoz_app/src/game_ui_state.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';
import 'package:kolkhoz_app/src/online_table_projection.dart';
import 'package:kolkhoz_app/src/render_model.dart';
import 'package:kolkhoz_app/src/saved_game_store.dart';
import 'package:kolkhoz_app/src/table_view_projection.dart';

void main() {
  test('fixed opening seed projects the canonical Flutter table state', () {
    withEngine(seed: 20260703, variants: KolkhozGameVariants.kolkhoz, (
      bridge,
      engine,
    ) {
      final model = project(bridge, engine);

      expect(
        openingFingerprint(model),
        '''
year=1 phase=trick current=0 trump=wheat viewer=0 privacy=none
seats=0:human:hand=beet-8,potato-9,sunflower-10,sunflower-6,wheat-10:hidden=0:score=0|1:heuristicAI:hand=beet-11,beet-12,beet-6,beet-9,sunflower-12:hidden=5:score=0|2:heuristicAI:hand=potato-7,potato-8,sunflower-13,sunflower-8,sunflower-9:hidden=5:score=0|3:heuristicAI:hand=potato-11,wheat-12,wheat-13,wheat-9:hidden=4:score=0
jobs=beet:beet-2:0:false|potato:potato-2:0:false|sunflower:sunflower-3:0:false|wheat:wheat-1:0:false
actions=playCard:0:wheat-10
'''
            .trim(),
      );
    });
  });

  test('manual apply leaves automatic AI turns for explicit engine steps', () {
    withEngine(seed: 20260703, variants: KolkhozGameVariants.kolkhoz, (
      bridge,
      engine,
    ) {
      var model = project(bridge, engine);
      final initialTrickCount = model.table.trick.plays.length;
      final action = deterministicAction(model);
      final cAction = cEngineAction(action.engineAction);
      expect(cAction, isNotNull);

      expect(bridge.applyManual(engine, cAction!), 0);
      model = project(bridge, engine);
      expect(model.table.trick.plays.length, initialTrickCount + 1);
      expect(model.table.currentPlayerID, 1);
      expect(model.legalActions, isEmpty);

      expect(bridge.stepAutomatic(engine), 1);
      model = project(bridge, engine);
      expect(model.table.trick.plays.length, initialTrickCount + 2);
      expect(model.table.currentPlayerID, 2);
    });
  });

  test(
    'deterministic Flutter action policy reaches game over through C engine',
    () {
      withEngine(seed: 404, variants: KolkhozGameVariants.kolkhoz, (
        bridge,
        engine,
      ) {
        var model = project(bridge, engine);
        final phaseVisits = <String>{model.table.phase};
        var appliedActions = 0;

        while (model.table.phase != phaseGameOver && appliedActions < 400) {
          final action = deterministicAction(model);
          final cAction = cEngineAction(action.engineAction);
          expect(cAction, isNotNull);
          expect(bridge.apply(engine, cAction!), 0);
          appliedActions += 1;
          model = project(bridge, engine);
          phaseVisits.add(model.table.phase);
        }

        expect(model.table.phase, phaseGameOver);
        expect(phaseVisits, containsAll([phasePlanning, phaseTrick]));
        expect(
          gameOverFingerprint(model, appliedActions),
          '''
actions=44 winner=1
scores=0:visible=0:final=41|1:visible=17:final=42|2:visible=4:final=10|3:visible=11:final=19
exiled=1:beet-3,sunflower-5|2:beet-1,beet-12,potato-1,potato-6,potato-7|3:beet-10,beet-5,beet-6|4:beet-13,beet-4,sunflower-2,sunflower-6,sunflower-7|5:beet-2,beet-8,potato-11,potato-13,potato-5
'''
              .trim(),
        );
      });
    },
  );

  test('36-card orden variant projects stacked plot rewards', () {
    withEngine(seed: 711, variants: KolkhozGameVariants.littleKolkhoz, (
      bridge,
      engine,
    ) {
      var model = project(bridge, engine);
      var appliedActions = 0;

      while (!hasAnyPlotStack(model) &&
          model.table.phase != phaseGameOver &&
          appliedActions < 200) {
        final action = deterministicAction(model);
        final cAction = cEngineAction(action.engineAction);
        expect(cAction, isNotNull);
        expect(bridge.apply(engine, cAction!), 0);
        appliedActions += 1;
        model = project(bridge, engine);
      }

      expect(hasAnyPlotStack(model), isTrue);
      expect(
        stackFingerprint(model, appliedActions),
        '''
actions=2
stacks=2:0:revealed=beet-6:hidden=beet-11,sunflower-10,sunflower-6,wheat-11,wheat-12,wheat-8,wheat-9
'''
            .trim(),
      );
    });
  });

  test('saved action log restores the same non-planning table projection', () {
    withEngine(seed: 909, variants: KolkhozGameVariants.kolkhoz, (
      bridge,
      engine,
    ) {
      var model = project(bridge, engine);
      final actions = <EngineAction>[];

      while (model.table.phase == phasePlanning || actions.length < 3) {
        final action = deterministicAction(model);
        final cAction = cEngineAction(action.engineAction);
        expect(cAction, isNotNull);
        expect(bridge.apply(engine, cAction!), 0);
        actions.add(action.engineAction);
        model = project(bridge, engine);
      }

      final payload = KolkhozSavedGamePayload(
        seed: 909,
        variants: KolkhozGameVariants.kolkhoz,
        controllers: fixtureControllers,
        actions: actions,
      );
      final restored = KolkhozSavedGamePayload.fromJson(payload.toJson());
      withRestoredEngine(bridge, restored, (restoredEngine) {
        final restoredModel = project(bridge, restoredEngine);
        expect(restoredModel.table.phase, isNot(phasePlanning));
        expect(openingFingerprint(restoredModel), openingFingerprint(model));
      });
    });
  });

  test('camp style fixture captures northern requisition projection', () {
    withEngine(seed: 5150, variants: KolkhozGameVariants.campStyle, (
      bridge,
      engine,
    ) {
      final result = runToGameOver(bridge, engine);

      expect(result.phaseVisits, contains(phaseRequisition));
      expect(
        variantFingerprint(result.model, result.appliedActions),
        '''
actions=54 winner=0
scores=0:visible=0:final=17|1:visible=0:final=0|2:visible=0:final=0|3:visible=0:final=12
exiled=1:beet-10,potato-11,potato-7|2:beet-8,potato-10,potato-6,sunflower-8|3:beet-11,beet-13,sunflower-13|4:beet-7,potato-12,potato-13,potato-9|5:beet-9,potato-8,sunflower-12
claimed=wheat
visible=0:0:0|1:0:2|2:0:0|3:0:1
'''
            .trim(),
      );
    });
  });

  test(
    'medals and accumulated jobs fixture captures final scoring projection',
    () {
      const variants = KolkhozGameVariants(
        nomenclature: false,
        medalsCount: true,
        accumulateJobs: true,
      );
      withEngine(seed: 6262, variants: variants, (bridge, engine) {
        final result = runToGameOver(bridge, engine);

        expect(result.model.table.phase, phaseGameOver);
        expect(
          variantFingerprint(result.model, result.appliedActions),
          '''
actions=39 winner=2
scores=0:visible=5:final=20|1:visible=17:final=17|2:visible=12:final=27|3:visible=3:final=16
exiled=1:beet-11,potato-10,potato-12|2:potato-7,sunflower-13|3:beet-13,beet-6,beet-9|4:beet-12,potato-13,potato-8|5:beet-8,potato-11,potato-6,sunflower-9
claimed=wheat
visible=0:5:1|1:17:2|2:12:0|3:3:0
'''
              .trim(),
        );
      });
    },
  );

  test(
    'online redacted snapshot projects remote seats, stacks, and legal actions',
    () {
      final model = OnlineTableProjection(
        update: onlineFixtureUpdate(),
        playerID: 1,
        legalActions: const [
          OnlineEngineAction(
            kind: kcActionPlayCard,
            playerID: 1,
            card: OnlineEngineCard(suit: 0, value: 9),
          ),
        ],
      ).project();

      expect(
        onlineProjectionFingerprint(model),
        '''
viewer=1 phase=trick current=1 trump=wheat
seats=0:remoteHuman:hand=:hidden=0:stacks=0:score=8|1:human:hand=beet-11,wheat-9:hidden=0:stacks=1:score=21|2:heuristicAI:hand=:hidden=0:stacks=0:score=0|3:heuristicAI:hand=:hidden=0:stacks=0:score=0
jobs=beet:none:0:false|potato:none:0:false|sunflower:none:40:true|wheat:wheat-1:12:false
actions=playCard:1:wheat-9
'''
            .trim(),
      );
    },
  );
}

const fixtureControllers = [
  KolkhozPlayerController.human,
  KolkhozPlayerController.heuristicAI,
  KolkhozPlayerController.heuristicAI,
  KolkhozPlayerController.heuristicAI,
];

void withEngine(
  void Function(KolkhozCEngineBridge bridge, Pointer<KCEngine> engine) body, {
  required int seed,
  required KolkhozGameVariants variants,
}) {
  final bridge = KolkhozCEngineBridge();
  final engine = bridge.newEngine(
    seed: seed,
    variants: variants,
    controllers: const [...fixtureControllers],
  );
  try {
    body(bridge, engine);
  } finally {
    bridge.freeEngine(engine);
  }
}

TableViewModel project(KolkhozCEngineBridge bridge, Pointer<KCEngine> engine) {
  return TableViewProjection(
    bridge: bridge,
    engine: engine,
    controllers: const [...fixtureControllers],
    uiState: const GameUiState(),
  ).project();
}

void withRestoredEngine(
  KolkhozCEngineBridge bridge,
  KolkhozSavedGamePayload payload,
  void Function(Pointer<KCEngine> engine) body,
) {
  final engine = bridge.newEngine(
    seed: payload.seed,
    variants: payload.variants,
    controllers: payload.controllers,
  );
  try {
    for (final action in payload.actions) {
      final cAction = cEngineAction(action);
      expect(cAction, isNotNull);
      expect(bridge.apply(engine, cAction!), 0);
    }
    body(engine);
  } finally {
    bridge.freeEngine(engine);
  }
}

FixtureRunResult runToGameOver(
  KolkhozCEngineBridge bridge,
  Pointer<KCEngine> engine,
) {
  var model = project(bridge, engine);
  final phaseVisits = <String>{model.table.phase};
  var appliedActions = 0;

  while (model.table.phase != phaseGameOver && appliedActions < 500) {
    final action = deterministicAction(model);
    final cAction = cEngineAction(action.engineAction);
    expect(cAction, isNotNull);
    expect(bridge.apply(engine, cAction!), 0);
    appliedActions += 1;
    model = project(bridge, engine);
    phaseVisits.add(model.table.phase);
  }

  expect(model.table.phase, phaseGameOver);
  return FixtureRunResult(
    model: model,
    phaseVisits: phaseVisits,
    appliedActions: appliedActions,
  );
}

class FixtureRunResult {
  const FixtureRunResult({
    required this.model,
    required this.phaseVisits,
    required this.appliedActions,
  });

  final TableViewModel model;
  final Set<String> phaseVisits;
  final int appliedActions;
}

String openingFingerprint(TableViewModel model) {
  return [
    'year=${model.table.year} phase=${model.table.phase} current=${model.table.currentPlayerID} trump=${model.table.trump} viewer=${model.viewer.seatID} privacy=${model.viewer.privacyMode}',
    'seats=${model.table.seats.map(seatOpeningFingerprint).join('|')}',
    'jobs=${model.table.jobs.map(jobFingerprint).toList()..sort()}'
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll(', ', '|'),
    'actions=${model.legalActions.map(actionFingerprint).toList()..sort()}'
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll(', ', '|'),
  ].join('\n');
}

String seatOpeningFingerprint(Seat seat) {
  return [
    seat.id,
    seat.controller,
    'hand=${cardIDs(seat.hand).join(',')}',
    'hidden=${seat.hiddenHandCount}',
    'score=${seat.visibleScore}',
  ].join(':');
}

String jobFingerprint(Job job) {
  return [job.suit, job.reward?.id ?? 'none', job.hours, job.claimed].join(':');
}

String actionFingerprint(LegalAction action) {
  final engineAction = action.engineAction;
  return [
    action.kind,
    engineAction.playerID,
    engineAction.suit ??
        engineAction.card?.id ??
        engineAction.handCard?.id ??
        'none',
  ].join(':');
}

LegalAction deterministicAction(TableViewModel model) {
  final actions = [...model.legalActions]..sort(compareActionForFixture);
  expect(actions, isNotEmpty);
  return actions.first;
}

int compareActionForFixture(LegalAction left, LegalAction right) {
  final leftPriority = actionPriority(left);
  final rightPriority = actionPriority(right);
  if (leftPriority != rightPriority) {
    return leftPriority.compareTo(rightPriority);
  }
  return actionFingerprint(left).compareTo(actionFingerprint(right));
}

int actionPriority(LegalAction action) {
  return switch (action.kind) {
    actionSubmitAssignments => 0,
    actionContinueAfterRequisition => 0,
    actionConfirmSwap => 0,
    actionSetTrump => 1,
    actionPlayCard => 1,
    actionAssign => 1,
    actionSwap => 2,
    actionUndoSwap => 3,
    _ => 4,
  };
}

String gameOverFingerprint(TableViewModel model, int appliedActions) {
  return [
    'actions=$appliedActions winner=${model.table.gameResult?.winnerSeatID}',
    'scores=${model.table.scoreboard.map(scoreFingerprint).join('|')}',
    'exiled=${model.table.exiledByYear.entries.where((entry) => entry.value.isNotEmpty).map((entry) => '${entry.key}:${cardIDs(entry.value).join(',')}').join('|')}',
  ].join('\n');
}

String variantFingerprint(TableViewModel model, int appliedActions) {
  return [
    gameOverFingerprint(model, appliedActions),
    'claimed=${model.table.jobs.where((job) => job.claimed).map((job) => job.suit).join(',')}',
    'visible=${model.table.seats.map((seat) => '${seat.id}:${seat.visibleScore}:${seat.medals}').join('|')}',
  ].join('\n');
}

String scoreFingerprint(Score score) {
  return [
    score.seatID,
    'visible=${score.visibleScore}',
    'final=${score.finalScore}',
  ].join(':');
}

bool hasAnyPlotStack(TableViewModel model) {
  return model.table.seats.any((seat) => seat.plot.stacks.isNotEmpty);
}

String stackFingerprint(TableViewModel model, int appliedActions) {
  final stacks = <String>[];
  for (final seat in model.table.seats) {
    for (var index = 0; index < seat.plot.stacks.length; index += 1) {
      final stack = seat.plot.stacks[index];
      stacks.add(
        '${seat.id}:$index:revealed=${cardIDs(stack.revealed).join(',')}:hidden=${cardIDs(stack.hidden).join(',')}',
      );
    }
  }
  return ['actions=$appliedActions', 'stacks=${stacks.join('|')}'].join('\n');
}

List<String> cardIDs(List<TableCard> cards) {
  return cards.map((card) => card.id).toList()..sort();
}

String onlineProjectionFingerprint(TableViewModel model) {
  return [
    'viewer=${model.viewer.seatID} phase=${model.table.phase} current=${model.table.currentPlayerID} trump=${model.table.trump}',
    'seats=${model.table.seats.map((seat) => '${seat.id}:${seat.controller}:hand=${cardIDs(seat.hand).join(',')}:hidden=${seat.hiddenHandCount}:stacks=${seat.plot.stacks.length}:score=${seat.visibleScore}').join('|')}',
    'jobs=${model.table.jobs.map(jobFingerprint).toList()..sort()}'
        .replaceAll('[', '')
        .replaceAll(']', '')
        .replaceAll(', ', '|'),
    'actions=${model.legalActions.map(actionFingerprint).join('|')}',
  ].join('\n');
}

OnlineSessionUpdate onlineFixtureUpdate() {
  return const OnlineSessionUpdate(
    sessionID: 'fixture',
    viewerID: 1,
    actionLogCount: 7,
    variants: KolkhozGameVariants.littleKolkhoz,
    controllers: [
      KolkhozPlayerController.human,
      KolkhozPlayerController.human,
      KolkhozPlayerController.heuristicAI,
      KolkhozPlayerController.heuristicAI,
    ],
    snapshot: OnlineEngineSnapshot(
      year: 2,
      phase: kcPhaseTrick,
      currentPlayer: 1,
      waitingPlayer: 1,
      waitingForExternalAction: true,
      lead: 1,
      trumpSelector: 0,
      trump: 0,
      trickCount: 1,
      isFamine: false,
      players: [
        OnlinePlayerSnapshot(
          id: 0,
          hand: [],
          revealedPlot: [OnlineEngineCard(suit: 2, value: 8)],
          hiddenPlot: [],
          medals: 0,
          bankedMedals: 1,
          brigadeLeader: false,
          wonTrickThisYear: false,
          stacks: [],
        ),
        OnlinePlayerSnapshot(
          id: 1,
          hand: [
            OnlineEngineCard(suit: 0, value: 9),
            OnlineEngineCard(suit: 3, value: 11),
          ],
          revealedPlot: [OnlineEngineCard(suit: 1, value: 7)],
          hiddenPlot: [OnlineEngineCard(suit: 2, value: 10)],
          medals: 1,
          bankedMedals: 0,
          brigadeLeader: true,
          wonTrickThisYear: true,
          stacks: [
            OnlinePlotStackSnapshot(
              revealed: [OnlineEngineCard(suit: 0, value: 6)],
              hidden: [OnlineEngineCard(suit: 1, value: 8)],
            ),
          ],
        ),
        OnlinePlayerSnapshot(
          id: 2,
          hand: [],
          revealedPlot: [],
          hiddenPlot: [],
          medals: 0,
          bankedMedals: 0,
          brigadeLeader: false,
          wonTrickThisYear: false,
          stacks: [],
        ),
        OnlinePlayerSnapshot(
          id: 3,
          hand: [],
          revealedPlot: [],
          hiddenPlot: [],
          medals: 0,
          bankedMedals: 0,
          brigadeLeader: false,
          wonTrickThisYear: false,
          stacks: [],
        ),
      ],
      jobPiles: [],
      revealedJobs: [
        OnlineSuitCardsSnapshot(
          suit: 0,
          cards: [OnlineEngineCard(suit: 0, value: 1)],
        ),
      ],
      claimedJobs: [1],
      workHours: [
        OnlineSuitValueSnapshot(suit: 0, value: 12),
        OnlineSuitValueSnapshot(suit: 1, value: 40),
      ],
      jobBuckets: [
        OnlineSuitCardsSnapshot(
          suit: 1,
          cards: [OnlineEngineCard(suit: 3, value: 12)],
        ),
      ],
      accumulatedJobCards: [],
      currentTrick: [
        OnlineTrickPlaySnapshot(
          playerID: 0,
          card: OnlineEngineCard(suit: 0, value: 7),
        ),
      ],
      lastTrick: [],
      lastWinner: -1,
      exiled: [],
      pendingAssignments: [],
      requisitionEvents: [],
      scores: [
        OnlineScoreSnapshot(playerID: 0, visibleScore: 8, finalScore: 18),
        OnlineScoreSnapshot(playerID: 1, visibleScore: 21, finalScore: 31),
        OnlineScoreSnapshot(playerID: 2, visibleScore: 0, finalScore: 0),
        OnlineScoreSnapshot(playerID: 3, visibleScore: 0, finalScore: 0),
      ],
      winnerID: -1,
      swapConfirmed: [],
      swapCount: [],
    ),
  );
}
