import 'dart:async';
import 'dart:convert';
import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kolkhoz_app/src/animation_speed.dart';
import 'package:kolkhoz_app/src/app_settings.dart';
import 'package:kolkhoz_app/src/app_text.dart';
import 'package:kolkhoz_app/src/assignment_display.dart';
import 'package:kolkhoz_app/src/board_view.dart';
import 'package:kolkhoz_app/src/board/game_log_panel.dart';
import 'package:kolkhoz_app/src/card_art_display.dart';
import 'package:kolkhoz_app/src/card_display.dart';
import 'package:kolkhoz_app/src/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/controller_display.dart';
import 'package:kolkhoz_app/src/design_tokens.dart';
import 'package:kolkhoz_app/src/engine_action_projection.dart';
import 'package:kolkhoz_app/src/game_constants.dart';
import 'package:kolkhoz_app/src/game_lobby.dart';
import 'package:kolkhoz_app/src/game_sound.dart';
import 'package:kolkhoz_app/src/game_ui_state.dart';
import 'package:kolkhoz_app/src/kolkhoz_app.dart';
import 'package:kolkhoz_app/src/live_game_store.dart';
import 'package:kolkhoz_app/src/online_game_models.dart';
import 'package:kolkhoz_app/src/online_game_client.dart';
import 'package:kolkhoz_app/src/online_table_projection.dart';
import 'package:kolkhoz_app/src/pixel_text.dart';
import 'package:kolkhoz_app/src/player_ai_heuristic.dart';
import 'package:kolkhoz_app/src/player_ai_neural.dart';
import 'package:kolkhoz_app/src/player_human.dart';
import 'package:kolkhoz_app/src/player_server.dart';
import 'package:kolkhoz_app/src/policy_model.dart';
import 'package:kolkhoz_app/src/player_profile_panel.dart';
import 'package:kolkhoz_app/src/player_identity.dart';
import 'package:kolkhoz_app/src/player.dart';
import 'package:kolkhoz_app/src/plot_display.dart';
import 'package:kolkhoz_app/src/render_model.dart';
import 'package:kolkhoz_app/src/rule_content.dart';
import 'package:kolkhoz_app/src/saved_game_store.dart';
import 'package:kolkhoz_app/src/table_display.dart';
import 'package:kolkhoz_app/src/table_projection_helpers.dart';
import 'package:kolkhoz_app/src/tutorial_display.dart';

part 'widget/store_online_tests.dart';
part 'widget/board_tests.dart';
part 'widget/lobby_profile_tests.dart';
part 'widget/tutorial_layout_tests.dart';

Finder findAppText(String text, {bool skipOffstage = true}) {
  return find.byWidgetPredicate(
    (widget) =>
        (widget is Text && widget.data == text) ||
        (widget is PixelText && widget.text == text) ||
        (widget is EditableText && widget.controller.text == text),
    skipOffstage: skipOffstage,
  );
}

void main() {
  registerStoreAndOnlineTests();
  registerBoardTests();
  registerLobbyAndProfileTests();
  registerTutorialAndLayoutTests();
}

CEngineActionValue swapAction({
  EngineCardValue handCard = const EngineCardValue(suit: 0, value: 7),
  EngineCardValue plotCard = const EngineCardValue(suit: 3, value: 10),
  int plotZone = 0,
}) {
  return CEngineActionValue(
    kind: kcActionSwap,
    playerID: 0,
    suit: -1,
    card: const EngineCardValue(suit: -1, value: 0),
    handCard: handCard,
    plotCard: plotCard,
    plotZone: plotZone,
    targetSuit: -1,
  );
}

CEngineActionValue playAction({
  int playerID = 0,
  EngineCardValue card = const EngineCardValue(suit: 0, value: 7),
}) {
  return CEngineActionValue(
    kind: kcActionPlayCard,
    playerID: playerID,
    suit: -1,
    card: card,
    handCard: const EngineCardValue(suit: -1, value: 0),
    plotCard: const EngineCardValue(suit: -1, value: 0),
    plotZone: -1,
    targetSuit: -1,
  );
}

TableViewModel runtimeModel() {
  final seats = [
    testSeat(id: 0, name: 'You', isViewer: true, isCurrentTurn: true),
    testSeat(id: 1, name: 'Bot 1'),
    testSeat(id: 2, name: 'Bot 2'),
    testSeat(id: 3, name: 'Bot 3'),
  ];
  return TableViewModel(
    viewer: const Viewer(seatID: 0, privacyMode: viewerPrivacyNone),
    table: TableState(
      year: 1,
      phase: phaseTrick,
      phasePrompt: const Prompt(
        title: 'Play',
        body: 'Play a card to the current trick.',
      ),
      currentPlayerID: 0,
      trump: 'wheat',
      isFamine: false,
      maxTricks: 4,
      seats: seats,
      jobs: const [
        Job(
          suit: 'wheat',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
        Job(
          suit: 'sunflower',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
        Job(
          suit: 'potato',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
        Job(
          suit: 'beet',
          hours: 0,
          requiredHours: jobRequiredHours,
          claimed: false,
          reward: null,
          assignedCards: [],
          validAssignmentTarget: false,
          highlighted: false,
        ),
      ],
      trick: const Trick(plays: [], winnerSeatID: null),
      lastTrick: const Trick(plays: [], winnerSeatID: null),
      requisitionEvents: const [],
      exiledByYear: {
        for (var year = 1; year <= finalGameYear; year++) year: const [],
      },
      scoreboard: [
        for (var seatID = 0; seatID < kolkhozPlayerCount; seatID++)
          Score(seatID: seatID, visibleScore: 0, finalScore: null),
      ],
      gameResult: null,
    ),
    panels: const Panels(active: panelBrigade, available: availableGamePanels),
    selection: const SelectionState(
      handCardID: null,
      plotCardID: null,
      plotZone: null,
      assignmentCardID: null,
    ),
    legalActions: [],
  );
}

TableViewModel assignmentModel({required String? selectedCardID}) {
  return runtimeModelWith(
    phase: phaseAssignment,
    selection: SelectionState.empty.copyWith(
      assignmentCardID: selectedCardID,
      clearAssignmentCardID: selectedCardID == null,
    ),
    jobs: const [
      Job(
        suit: 'wheat',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: true,
        highlighted: false,
      ),
      Job(
        suit: 'sunflower',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: true,
        highlighted: false,
      ),
      Job(
        suit: 'potato',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: false,
        highlighted: false,
      ),
      Job(
        suit: 'beet',
        hours: 0,
        requiredHours: jobRequiredHours,
        claimed: false,
        reward: null,
        assignedCards: [],
        validAssignmentTarget: false,
        highlighted: false,
      ),
    ],
    legalActions: [
      testLegalAction(
        kind: actionAssign,
        label: 'Assign',
        engineAction: const EngineAction(
          kind: actionAssign,
          playerID: 0,
          card: EngineCard(suit: 'wheat', value: 9),
          targetSuit: 'wheat',
        ),
      ),
      testLegalAction(
        kind: actionAssign,
        label: 'Assign',
        engineAction: const EngineAction(
          kind: actionAssign,
          playerID: 0,
          card: EngineCard(suit: 'wheat', value: 9),
          targetSuit: 'sunflower',
        ),
      ),
    ],
  );
}

TableViewModel runtimeModelWith({
  required String phase,
  required SelectionState selection,
  required List<Job> jobs,
  int? year,
  GameResult? gameResult,
  int? currentPlayerID,
  List<Seat>? seats,
  Trick? trick,
  Trick? lastTrick,
  List<RequisitionEvent>? requisitionEvents,
  Map<int, List<TableCard>>? exiledByYear,
  List<LegalAction>? legalActions,
}) {
  final base = runtimeModel();
  return TableViewModel(
    viewer: base.viewer,
    table: TableState(
      year: year ?? base.table.year,
      phase: phase,
      phasePrompt: base.table.phasePrompt,
      currentPlayerID: currentPlayerID ?? base.table.currentPlayerID,
      trump: base.table.trump,
      isFamine: base.table.isFamine,
      maxTricks: base.table.maxTricks,
      seats: seats ?? base.table.seats,
      jobs: jobs,
      trick: trick ?? base.table.trick,
      lastTrick: lastTrick ?? base.table.lastTrick,
      requisitionEvents: requisitionEvents ?? base.table.requisitionEvents,
      exiledByYear: exiledByYear ?? base.table.exiledByYear,
      scoreboard: base.table.scoreboard,
      gameResult: gameResult ?? base.table.gameResult,
    ),
    panels: base.panels,
    selection: selection,
    legalActions: legalActions ?? base.legalActions,
  );
}

Seat seatWithHand(Seat seat, List<TableCard> hand) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: seat.plot,
    medals: seat.medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

Seat seatWithMedals(Seat seat, int medals) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: seat.hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: seat.plot,
    medals: medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

Seat seatWithController(Seat seat, {required String controller}) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: seat.hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: seat.plot,
    medals: seat.medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

TableViewModel runtimeModelWithSelectedHandCard() {
  return runtimeModelWith(
    phase: phaseTrick,
    selection: const SelectionState(
      handCardID: 'wheat-9',
      plotCardID: null,
      plotZone: null,
      assignmentCardID: null,
    ),
    jobs: runtimeModel().table.jobs,
  );
}

TableViewModel runtimeModelWithTrickPlay() {
  return runtimeModelWith(
    phase: phaseTrick,
    selection: SelectionState.empty,
    jobs: runtimeModel().table.jobs,
    lastTrick: const Trick(
      plays: [
        TrickPlay(
          seatID: 0,
          card: TableCard(
            id: 'wheat-9',
            suit: 'wheat',
            value: 9,
            rank: '9',
            selected: false,
            highlighted: false,
            pending: false,
          ),
        ),
      ],
      winnerSeatID: null,
    ),
  );
}

Seat testSeat({
  required int id,
  required String name,
  String? controller,
  bool isViewer = false,
  bool isCurrentTurn = false,
}) {
  return Seat(
    id: id,
    name: name,
    controller:
        controller ?? (id == 0 ? controllerHuman : controllerHeuristicAI),
    portraitAsset: 'worker${id + 1}',
    isViewer: isViewer,
    isCurrentTurn: isCurrentTurn,
    isBrigadeLeader: false,
    hand: id == 0
        ? const [
            TableCard(
              id: 'wheat-11',
              suit: 'wheat',
              value: 11,
              rank: 'J',
              selected: false,
              highlighted: false,
              pending: false,
            ),
          ]
        : const [],
    hiddenHandCount: id == 0 ? 0 : 1,
    plot: const PlotState(revealed: [], hidden: [], stacks: []),
    medals: 0,
    visibleScore: 0,
  );
}

Seat seatWithPlot(Seat seat, PlotState plot) {
  return Seat(
    id: seat.id,
    name: seat.name,
    controller: seat.controller,
    portraitAsset: seat.portraitAsset,
    isViewer: seat.isViewer,
    isCurrentTurn: seat.isCurrentTurn,
    isBrigadeLeader: seat.isBrigadeLeader,
    hand: seat.hand,
    hiddenHandCount: seat.hiddenHandCount,
    plot: plot,
    medals: seat.medals,
    visibleScore: seat.visibleScore,
    statusText: seat.statusText,
  );
}

TableCard testCard({
  required String id,
  required String suit,
  required int value,
  String? rank,
  bool pending = false,
  int? assignmentRound,
  bool nomenclature = false,
  int? ownerSeatID,
}) {
  return TableCard(
    id: id,
    suit: suit,
    value: value,
    rank: rank ?? '$value',
    selected: false,
    highlighted: false,
    pending: pending,
    assignmentRound: assignmentRound,
    nomenclature: nomenclature,
    ownerSeatID: ownerSeatID,
  );
}

LegalAction testLegalAction({
  required String kind,
  required String label,
  EngineAction? engineAction,
}) {
  return LegalAction(
    kind: kind,
    label: label,
    engineAction: engineAction ?? EngineAction(kind: kind, playerID: 0),
  );
}

Finder findAssetImage(String assetName) {
  return find.byWidgetPredicate(
    (widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == assetName,
  );
}

class _CardMotionTestBoard extends StatelessWidget {
  const _CardMotionTestBoard({required this.model});

  final TableViewModel model;

  @override
  Widget build(BuildContext context) {
    final hand = model.table.seats[0].hand;
    final trick = model.table.trick.plays.isNotEmpty
        ? model.table.trick.plays
        : model.table.lastTrick.plays;
    final handCard = hand.isEmpty ? null : hand.first;
    final trickPlay = trick.isEmpty ? null : trick.first;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: 24,
          top: 208,
          child: MotionTrackedRegion(
            motionKey: playerCardMotionSourceKey(2),
            child: const SizedBox(width: 96, height: 42),
          ),
        ),
        for (final (index, job) in model.table.jobs.indexed)
          Positioned(
            left: 150 + index * 45,
            top: 24,
            child: MotionTrackedRegion(
              motionKey: jobGaugeMotionTargetKey(job.suit),
              child: const SizedBox(width: 40, height: 40),
            ),
          ),
        if (handCard != null)
          Positioned(
            left: 24,
            top: 24,
            child: GameCard(
              card: handCard,
              tokens: defaultDesignTokens,
              trump: model.table.trump,
              sizeOverride: defaultDesignTokens.card.small,
            ),
          ),
        if (trickPlay != null)
          Positioned(
            left: 260,
            top: 96,
            child: GameCard(
              card: trickPlay.card,
              tokens: defaultDesignTokens,
              trump: model.table.trump,
              sizeOverride: defaultDesignTokens.card.small,
            ),
          ),
      ],
    );
  }
}

class _RequisitionMotionTestBoard extends StatelessWidget {
  const _RequisitionMotionTestBoard();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: 260,
          top: 120,
          child: MotionTrackedRegion(
            motionKey: plotCardMotionSourceKey(0),
            child: const SizedBox(width: 120, height: 100),
          ),
        ),
        Positioned(
          left: 18,
          top: 24,
          child: MotionTrackedRegion(
            motionKey: northCardMotionTargetKey,
            child: const SizedBox(width: 44, height: 44),
          ),
        ),
      ],
    );
  }
}

Map<String, Object?> onlineUpdateJson({int viewerID = 0}) {
  return {
    'sessionID': '11111111-1111-1111-1111-111111111111',
    'inviteCode': 'ABCDE',
    'viewerID': viewerID,
    'actionLogCount': 0,
    'isViewerTurn': true,
    'legalActions': [
      const OnlineEngineAction(
        kind: kcActionSetTrump,
        playerID: 0,
        suit: 0,
      ).toJson(),
    ],
    'variants': variantsToJson(KolkhozGameVariants.kolkhoz),
    'controllers': ['human', 'human', 'heuristicAI', 'neuralAI'],
    'snapshot': {
      'year': 1,
      'phase': kcPhasePlanning,
      'currentPlayer': 0,
      'waitingPlayer': 0,
      'waitingForExternalAction': true,
      'lead': 0,
      'trumpSelector': 0,
      'trump': -1,
      'trickCount': 0,
      'isFamine': false,
      'players': [
        onlinePlayerJson(
          id: 0,
          hand: [onlineCardJson(0, 13)],
          hiddenPlot: [onlineCardJson(1, 7)],
        ),
        onlinePlayerJson(id: 1),
        onlinePlayerJson(id: 2),
        onlinePlayerJson(id: 3),
      ],
      'jobPiles': onlineSuitCardsJson(),
      'revealedJobs': onlineSuitCardsJson(
        cardsBySuit: {
          0: [onlineCardJson(0, 9)],
        },
      ),
      'claimedJobs': <int>[],
      'workHours': [
        for (var suit = 0; suit < 4; suit++) {'suit': suit, 'value': 0},
      ],
      'jobBuckets': onlineSuitCardsJson(),
      'accumulatedJobCards': onlineSuitCardsJson(),
      'currentTrick': <Object?>[],
      'lastTrick': <Object?>[],
      'lastWinner': -1,
      'exiled': onlineSuitCardsJson(count: 6),
      'pendingAssignments': <Object?>[],
      'requisitionEvents': <Object?>[],
      'scores': [
        for (var playerID = 0; playerID < kolkhozPlayerCount; playerID++)
          {
            'playerID': playerID,
            'visibleScore': playerID,
            'finalScore': playerID,
          },
      ],
      'winnerID': -1,
      'swapConfirmed': <int>[],
      'swapCount': <int>[],
    },
  };
}

Map<String, Object?> onlinePlayerJson({
  required int id,
  List<Map<String, Object?>> hand = const [],
  List<Map<String, Object?>> revealedPlot = const [],
  List<Map<String, Object?>> hiddenPlot = const [],
}) {
  return {
    'id': id,
    'hand': hand,
    'revealedPlot': revealedPlot,
    'hiddenPlot': hiddenPlot,
    'medals': 0,
    'bankedMedals': 0,
    'brigadeLeader': id == 0,
    'wonTrickThisYear': false,
    'stacks': <Object?>[],
  };
}

List<Map<String, Object?>> onlineSuitCardsJson({
  int count = 4,
  Map<int, List<Map<String, Object?>>> cardsBySuit = const {},
}) {
  return [
    for (var suit = 0; suit < count; suit++)
      {'suit': suit, 'cards': cardsBySuit[suit] ?? <Object?>[]},
  ];
}

Map<String, Object?> onlineCardJson(int suit, int value) {
  return {'suit': suit, 'value': value};
}

class FakeOnlineRequestRecord {
  FakeOnlineRequestRecord({
    required this.method,
    required this.uri,
    required this.body,
    required this.headers,
  });

  final String method;
  final Uri uri;
  final String body;
  final Map<String, List<Object>> headers;

  String get route => '$method ${uri.path}';
}

class FakeOnlineHttpClient implements HttpClient {
  final requests = <FakeOnlineRequestRecord>[];

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    return FakeOnlineHttpClientRequest(this, method, url);
  }

  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    requests.add(
      FakeOnlineRequestRecord(
        method: method,
        uri: uri,
        body: body,
        headers: headers,
      ),
    );
    if (method == 'POST' && uri.path == '/sessions') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'inviteCode': 'ABCDE',
        'playerID': 0,
        'seatToken': 'seat-token-0',
        'update': onlineUpdateJson(),
      });
    }
    if (method == 'POST' && uri.path == '/sessions/matchmake') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'inviteCode': 'ABCDE',
        'playerID': 1,
        'seatToken': 'seat-token-1',
        'update': onlineUpdateJson(viewerID: 1),
      });
    }
    if (method == 'POST' && uri.path == '/presence') {
      return FakeOnlineHttpClientResponse.json({
        'service': {
          'activeSessions': 1,
          'activeSeats': 3,
          'connectedHumanSeats': 1,
          'profiledBotSeats': 15,
          'citizensOnline': 16,
        },
      });
    }
    if (method == 'GET' && uri.path == '/sessions') {
      return FakeOnlineHttpClientResponse.json([
        {
          'sessionID': '11111111-1111-1111-1111-111111111111',
          'inviteCode': 'ABCDE',
          'openSeats': [1],
          'occupiedSeats': [0],
          'controllers': ['human', 'human', 'heuristicAI', 'heuristicAI'],
          'playerProfiles': [
            {
              'playerID': 0,
              'userID': '11111111-1111-1111-1111-111111111111',
              'displayName': 'Mira',
              'avatarURL': 'worker3',
              'stats': {'online_games': 4, 'online_wins': 2},
            },
          ],
          'actionLogCount': 0,
          'createdAt': 1.0,
          'expiresAt': 3601.0,
        },
        {
          'sessionID': '22222222-2222-2222-2222-222222222222',
          'inviteCode': 'FGHIJ',
          'openSeats': [2],
          'occupiedSeats': [0, 1],
          'controllers': ['human', 'human', 'human', 'heuristicAI'],
          'playerProfiles': [
            {
              'playerID': 0,
              'userID': '22222222-2222-2222-2222-222222222222',
              'displayName': 'Oleg',
              'avatarURL': 'worker2',
              'stats': {'online_games': 1, 'online_wins': 0},
            },
          ],
          'ranked': false,
          'actionLogCount': 3,
          'createdAt': 2.0,
          'expiresAt': 3602.0,
        },
      ]);
    }
    if (method == 'GET' && uri.path == '/comrades') {
      return FakeOnlineHttpClientResponse.json({
        'userID': 'current-user',
        'comradeCode': 'SELF',
        'comrades': [
          {
            'userID': '11111111-1111-1111-1111-111111111111',
            'displayName': 'Mira',
            'avatarURL': 'worker3',
            'comradeCode': 'MIRA',
            'stats': {'online_games': 4, 'online_wins': 2},
          },
        ],
      });
    }
    if (method == 'GET' && uri.path == '/leaderboard') {
      return FakeOnlineHttpClientResponse.json({
        'players': [
          {
            'userID': 'leader-user',
            'displayName': 'Leader',
            'rank': 1,
            'inGame': true,
            'isComrade': true,
            'stats': {'online_games': 8, 'online_wins': 6},
          },
        ],
      });
    }
    if (method == 'GET' && uri.path == '/results/recent') {
      return FakeOnlineHttpClientResponse.json({
        'games': [
          {
            'sessionID': 'recent-game',
            'playerID': 0,
            'score': 123,
            'rank': 1,
            'won': true,
            'ranked': true,
            'completedAt': 1000.0,
          },
        ],
      });
    }
    if (method == 'GET' && uri.path == '/profiles/profile-user') {
      return FakeOnlineHttpClientResponse.json({
        'userID': 'profile-user',
        'displayName': 'Profile',
        'rank': 4,
        'stats': {'online_games': 5, 'online_wins': 3},
      });
    }
    if (method == 'GET' && uri.path == '/metrics') {
      return FakeOnlineHttpClientResponse.json({
        'service': {
          'activeSessions': 1,
          'activeSeats': 3,
          'connectedHumanSeats': 1,
          'profiledBotSeats': 15,
          'citizensOnline': 16,
        },
      });
    }
    if (method == 'GET' &&
        uri.path == '/sessions/11111111-1111-1111-1111-111111111111') {
      return FakeOnlineHttpClientResponse.json({
        'sessionID': '11111111-1111-1111-1111-111111111111',
        'inviteCode': 'ABCDE',
        'openSeats': <int>[],
        'occupiedSeats': [0, 1],
        'controllers': ['human', 'human', 'heuristicAI', 'heuristicAI'],
        'playerProfiles': [
          {
            'playerID': 0,
            'userID': '11111111-1111-1111-1111-111111111111',
            'displayName': 'Mira',
            'avatarURL': 'worker3',
            'stats': {'online_games': 4, 'online_wins': 2},
          },
        ],
        'actionLogCount': 0,
        'createdAt': 1.0,
        'expiresAt': 3601.0,
      });
    }
    if (method == 'GET' &&
        uri.path ==
            '/sessions/11111111-1111-1111-1111-111111111111/players/0/actions') {
      return FakeOnlineHttpClientResponse.json([
        const OnlineEngineAction(
          kind: kcActionSetTrump,
          playerID: 0,
          suit: 0,
        ).toJson(),
      ]);
    }
    if (method == 'POST' &&
        uri.path == '/sessions/11111111-1111-1111-1111-111111111111/actions') {
      return FakeOnlineHttpClientResponse.json(onlineUpdateJson());
    }
    return FakeOnlineHttpClientResponse.json({'error': 'missing'}, status: 404);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class EmptySessionsFakeOnlineHttpClient extends FakeOnlineHttpClient {
  @override
  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    if (method == 'GET' && uri.path == '/sessions') {
      requests.add(
        FakeOnlineRequestRecord(
          method: method,
          uri: uri,
          body: body,
          headers: headers,
        ),
      );
      return FakeOnlineHttpClientResponse.json([]);
    }
    return super.route(method, uri, body, headers);
  }
}

class TournamentFakeOnlineHttpClient extends EmptySessionsFakeOnlineHttpClient {
  bool joined = false;

  Map<String, Object?> tournamentJson() {
    final now = DateTime.now().millisecondsSinceEpoch / 1000;
    return {
      'available': true,
      'tournamentID': 'weekly-1',
      'startsAt': now + 900,
      'joinOpensAt': now - 60,
      'joinClosesAt': now + 900,
      'status': 'enrollment',
      'roundNumber': 0,
      'totalRounds': 4,
      'joined': joined,
      'forfeited': false,
      'entrantCount': joined ? 5 : 4,
      'standings': <Object?>[],
      'table': null,
    };
  }

  @override
  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    if (uri.path == '/tournaments/weekly' ||
        uri.path == '/tournaments/weekly/join') {
      requests.add(
        FakeOnlineRequestRecord(
          method: method,
          uri: uri,
          body: body,
          headers: headers,
        ),
      );
      if (method == 'POST') {
        joined = true;
      }
      return FakeOnlineHttpClientResponse.json(tournamentJson());
    }
    return super.route(method, uri, body, headers);
  }
}

class BannedSessionsFakeOnlineHttpClient extends FakeOnlineHttpClient {
  @override
  FakeOnlineHttpClientResponse route(
    String method,
    Uri uri,
    String body,
    Map<String, List<Object>> headers,
  ) {
    if (method == 'GET' && uri.path == '/sessions') {
      requests.add(
        FakeOnlineRequestRecord(
          method: method,
          uri: uri,
          body: body,
          headers: headers,
        ),
      );
      return FakeOnlineHttpClientResponse.json({
        'error': 'account sent north',
      }, status: 403);
    }
    return super.route(method, uri, body, headers);
  }
}

class FakeOnlineHttpClientRequest implements HttpClientRequest {
  FakeOnlineHttpClientRequest(this.client, this.method, this.uri);

  final FakeOnlineHttpClient client;
  @override
  final String method;
  @override
  final Uri uri;
  final buffer = StringBuffer();
  int _contentLength = -1;

  @override
  final HttpHeaders headers = FakeOnlineHttpHeaders();

  @override
  int get contentLength => _contentLength;

  @override
  set contentLength(int value) {
    _contentLength = value;
  }

  @override
  void add(List<int> data) {
    buffer.write(utf8.decode(data));
  }

  @override
  void write(Object? object) {
    buffer.write(object);
  }

  @override
  Future<HttpClientResponse> close() async {
    return client.route(
      method,
      uri,
      buffer.toString(),
      (headers as FakeOnlineHttpHeaders).values,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOnlineHttpHeaders implements HttpHeaders {
  final values = <String, List<Object>>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    values[name] = [value];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOnlineHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  FakeOnlineHttpClientResponse(this.body, {required this.statusCode});

  factory FakeOnlineHttpClientResponse.json(Object? json, {int status = 200}) {
    return FakeOnlineHttpClientResponse(
      utf8.encode(jsonEncode(json)),
      statusCode: status,
    );
  }

  final List<int> body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.fromIterable([body]).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
