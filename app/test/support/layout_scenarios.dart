import 'package:kolkhoz_app/src/game_constants.dart';
import 'package:kolkhoz_app/src/game_ui_state.dart';
import 'package:kolkhoz_app/src/render_model.dart';

class LayoutScenario {
  const LayoutScenario(this.name, this.model, {this.gameLogActions = const []});

  final String name;
  final TableViewModel model;
  final List<EngineAction> gameLogActions;
}

final layoutScenarios = <LayoutScenario>[
  LayoutScenario(
    'planning_brigade',
    _model(
      phase: phasePlanning,
      panel: panelBrigade,
      year: 1,
      prompt: const Prompt(
        title: 'Choose trump',
        body: 'Choose the crop suit that will be trump this year.',
      ),
      legalActions: [
        for (final suit in displaySuitOrder)
          LegalAction(
            kind: actionSetTrump,
            label: 'Choose $suit',
            engineAction: EngineAction(
              kind: actionSetTrump,
              playerID: 0,
              suit: suit,
            ),
          ),
      ],
    ),
  ),
  LayoutScenario(
    'swap_plot',
    _model(
      phase: phaseSwap,
      panel: panelPlot,
      year: 3,
      selection: const SelectionState(
        handCardID: 'wheat-11',
        plotCardID: 'beet-10',
        plotZone: plotZoneRevealed,
        assignmentCardID: null,
      ),
      prompt: const Prompt(
        title: 'Exchange',
        body: 'Exchange one hand card with a card from your plot.',
      ),
      legalActions: const [
        LegalAction(
          kind: actionSwap,
          label: 'Exchange cards',
          engineAction: EngineAction(
            kind: actionSwap,
            playerID: 0,
            handCard: EngineCard(suit: 'wheat', value: 11),
            plotCard: EngineCard(suit: 'beet', value: 10),
            plotZone: plotZoneRevealed,
          ),
        ),
        LegalAction(
          kind: actionConfirmSwap,
          label: 'Confirm',
          engineAction: EngineAction(kind: actionConfirmSwap, playerID: 0),
        ),
      ],
    ),
  ),
  LayoutScenario(
    'trick_brigade',
    _model(
      phase: phaseTrick,
      panel: panelBrigade,
      year: 2,
      currentPlayerID: 3,
      prompt: const Prompt(
        title: 'Play a card',
        body: 'Follow the lead suit if you can.',
      ),
      trick: Trick(
        plays: [
          TrickPlay(seatID: 1, card: _card('sunflower', 12)),
          TrickPlay(seatID: 2, card: _card('sunflower', 8)),
        ],
        winnerSeatID: null,
      ),
    ),
  ),
  LayoutScenario(
    'assignment_jobs',
    _model(
      phase: phaseAssignment,
      panel: panelJobs,
      year: 4,
      currentPlayerID: 0,
      selection: const SelectionState(
        handCardID: null,
        plotCardID: null,
        plotZone: null,
        assignmentCardID: 'wheat-13',
      ),
      prompt: const Prompt(
        title: 'Assign work',
        body: 'Assign every captured worker to a crop job.',
      ),
      lastTrick: Trick(
        plays: [
          TrickPlay(seatID: 0, card: _card('wheat', 13, selected: true)),
          TrickPlay(seatID: 1, card: _card('wheat', 9)),
          TrickPlay(seatID: 2, card: _card('beet', 12)),
          TrickPlay(seatID: 3, card: _card('wrecker', 14)),
        ],
        winnerSeatID: 0,
      ),
      jobs: _assignmentJobs,
      legalActions: const [
        LegalAction(
          kind: actionAssign,
          label: 'Assign to wheat',
          engineAction: EngineAction(
            kind: actionAssign,
            playerID: 0,
            card: EngineCard(suit: 'wheat', value: 13),
            targetSuit: 'wheat',
          ),
        ),
        LegalAction(
          kind: actionAssign,
          label: 'Assign to beet',
          engineAction: EngineAction(
            kind: actionAssign,
            playerID: 0,
            card: EngineCard(suit: 'wheat', value: 13),
            targetSuit: 'beet',
          ),
        ),
      ],
    ),
  ),
  LayoutScenario(
    'requisition_plot',
    _model(
      phase: phaseRequisition,
      panel: panelPlot,
      year: 4,
      prompt: const Prompt(
        title: 'Requisition',
        body: 'Failed work quotas have consequences.',
      ),
      requisitionEvents: [
        RequisitionEvent(
          seatID: 0,
          suit: 'beet',
          card: _card('beet', 10),
          message: 'Your beet worker was sent north.',
        ),
        RequisitionEvent(
          seatID: 2,
          suit: 'sunflower',
          card: _card('sunflower', 8),
          message: 'Bot 2 lost a sunflower worker.',
        ),
      ],
      exiledByYear: {
        1: [_card('potato', 7)],
        2: [_card('wheat', 9), _card('beet', 6)],
        3: const [],
        4: [_card('beet', 10), _card('sunflower', 8)],
        5: const [],
      },
      legalActions: const [
        LegalAction(
          kind: actionContinueAfterRequisition,
          label: 'Continue',
          engineAction: EngineAction(
            kind: actionContinueAfterRequisition,
            playerID: 0,
          ),
        ),
      ],
    ),
  ),
  LayoutScenario(
    'sent_north_history',
    _model(
      phase: phaseTrick,
      panel: panelNorth,
      year: 5,
      famine: true,
      trump: null,
      maxTricks: 3,
      prompt: const Prompt(
        title: 'Famine',
        body: 'There is no trump in the final year.',
      ),
      exiledByYear: {
        1: [_card('potato', 7)],
        2: [_card('wheat', 9), _card('beet', 6)],
        3: [_card('sunflower', 11)],
        4: [_card('beet', 10), _card('wrecker', 14)],
        5: const [],
      },
    ),
  ),
  LayoutScenario(
    'game_log',
    _model(
      phase: phaseTrick,
      panel: panelLog,
      year: 3,
      prompt: const Prompt(
        title: 'Play a card',
        body: 'Review the game so far.',
      ),
    ),
    gameLogActions: const [
      EngineAction(kind: actionSetTrump, playerID: 0, suit: 'wheat'),
      EngineAction(
        kind: actionPlayCard,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 11),
      ),
      EngineAction(
        kind: actionPlayCard,
        playerID: 1,
        card: EngineCard(suit: 'wheat', value: 9),
      ),
      EngineAction(
        kind: actionAssign,
        playerID: 0,
        card: EngineCard(suit: 'wheat', value: 11),
        targetSuit: 'wheat',
      ),
      EngineAction(kind: actionSubmitAssignments, playerID: 0),
      EngineAction(kind: actionContinueAfterRequisition, playerID: 0),
      EngineAction(kind: actionSetTrump, playerID: 2, suit: 'beet'),
      EngineAction(
        kind: actionSwap,
        playerID: 0,
        handCard: EngineCard(suit: 'potato', value: 10),
        plotCard: EngineCard(suit: 'beet', value: 8),
        plotZone: plotZoneRevealed,
      ),
      EngineAction(kind: actionConfirmSwap, playerID: 0),
      EngineAction(
        kind: actionPlayCard,
        playerID: 2,
        card: EngineCard(suit: 'beet', value: 12),
      ),
    ],
  ),
  LayoutScenario(
    'game_over',
    _model(
      phase: phaseGameOver,
      panel: panelPlot,
      year: 5,
      famine: true,
      trump: null,
      maxTricks: 3,
      prompt: const Prompt(
        title: 'Game over',
        body: 'The final harvest has been counted.',
      ),
      scores: const [
        Score(seatID: 0, visibleScore: 58, finalScore: 71),
        Score(seatID: 1, visibleScore: 43, finalScore: 55),
        Score(seatID: 2, visibleScore: 62, finalScore: 79),
        Score(seatID: 3, visibleScore: 49, finalScore: 63),
      ],
      gameResult: const GameResult(
        winnerSeatID: 2,
        scores: [
          Score(seatID: 0, visibleScore: 58, finalScore: 71),
          Score(seatID: 1, visibleScore: 43, finalScore: 55),
          Score(seatID: 2, visibleScore: 62, finalScore: 79),
          Score(seatID: 3, visibleScore: 49, finalScore: 63),
        ],
      ),
    ),
  ),
];

TableViewModel _model({
  required String phase,
  required String panel,
  required int year,
  Prompt prompt = const Prompt(title: 'Play', body: 'Play a card.'),
  int currentPlayerID = 0,
  String? trump = 'wheat',
  bool famine = false,
  int maxTricks = 4,
  SelectionState selection = SelectionState.empty,
  Trick trick = const Trick(plays: [], winnerSeatID: null),
  Trick lastTrick = const Trick(plays: [], winnerSeatID: null),
  List<Job>? jobs,
  List<RequisitionEvent> requisitionEvents = const [],
  Map<int, List<TableCard>>? exiledByYear,
  List<Score>? scores,
  GameResult? gameResult,
  List<LegalAction> legalActions = const [],
}) {
  final scoreboard =
      scores ??
      const [
        Score(seatID: 0, visibleScore: 18, finalScore: null),
        Score(seatID: 1, visibleScore: 13, finalScore: null),
        Score(seatID: 2, visibleScore: 22, finalScore: null),
        Score(seatID: 3, visibleScore: 16, finalScore: null),
      ];
  return TableViewModel(
    viewer: const Viewer(seatID: 0, privacyMode: viewerPrivacyNone),
    table: TableState(
      year: year,
      phase: phase,
      phasePrompt: prompt,
      currentPlayerID: currentPlayerID,
      trump: trump,
      isFamine: famine,
      maxTricks: maxTricks,
      seats: _seats(currentPlayerID),
      jobs: jobs ?? _jobs,
      trick: trick,
      lastTrick: lastTrick,
      requisitionEvents: requisitionEvents,
      exiledByYear:
          exiledByYear ??
          {for (var year = 1; year <= finalGameYear; year++) year: const []},
      scoreboard: scoreboard,
      gameResult: gameResult,
    ),
    panels: Panels(active: panel, available: availableGamePanels),
    selection: selection,
    legalActions: legalActions,
  );
}

List<Seat> _seats(int currentPlayerID) => [
  Seat(
    id: 0,
    name: 'Nadia',
    controller: controllerHuman,
    portraitAsset: 'worker1',
    isViewer: true,
    isCurrentTurn: currentPlayerID == 0,
    isBrigadeLeader: currentPlayerID == 0,
    hand: [
      _card('wheat', 11, highlighted: true),
      _card('sunflower', 7, highlighted: true),
      _card('potato', 10),
      _card('beet', 6),
      _card('wrecker', 14, highlighted: true),
    ],
    hiddenHandCount: 0,
    plot: PlotState(
      revealed: [_card('beet', 10, highlighted: true), _card('wheat', 8)],
      hidden: [_card('potato', 6), _card('sunflower', 9)],
      stacks: [
        PlotStackState(
          revealed: [_card('wheat', 4)],
          hidden: [_card('wheat', 12)],
        ),
      ],
    ),
    medals: 2,
    visibleScore: 18,
  ),
  _opponent(1, 'Boris', 'worker2', currentPlayerID, 1, 13),
  _opponent(2, 'Irina', 'worker3', currentPlayerID, 3, 22),
  _opponent(3, 'Mikhail', 'worker4', currentPlayerID, 0, 16),
];

Seat _opponent(
  int id,
  String name,
  String portrait,
  int currentPlayerID,
  int medals,
  int score,
) => Seat(
  id: id,
  name: name,
  controller: controllerHeuristicAI,
  portraitAsset: portrait,
  isViewer: false,
  isCurrentTurn: currentPlayerID == id,
  isBrigadeLeader: currentPlayerID == id,
  hand: const [],
  hiddenHandCount: 5,
  plot: PlotState(
    revealed: [_card(displaySuitOrder[id - 1], 6 + id)],
    hidden: [_card(displaySuitOrder[id], 9 + id)],
    stacks: const [],
  ),
  medals: medals,
  visibleScore: score,
);

final _jobs = <Job>[
  Job(
    suit: 'wheat',
    hours: 34,
    requiredHours: jobRequiredHours,
    claimed: false,
    reward: _card('wheat', 4),
    assignedCards: [
      _card('wheat', 11, assignmentRound: 1),
      _card('wheat', 10, assignmentRound: 2),
    ],
    validAssignmentTarget: false,
    highlighted: false,
  ),
  Job(
    suit: 'sunflower',
    hours: 41,
    requiredHours: jobRequiredHours,
    claimed: true,
    reward: _card('sunflower', 5),
    assignedCards: [
      _card('sunflower', 13, assignmentRound: 1),
      _card('sunflower', 12, assignmentRound: 2),
    ],
    validAssignmentTarget: false,
    highlighted: false,
  ),
  Job(
    suit: 'potato',
    hours: 18,
    requiredHours: jobRequiredHours,
    claimed: false,
    reward: _card('potato', 3),
    assignedCards: [_card('potato', 8, assignmentRound: 1)],
    validAssignmentTarget: false,
    highlighted: false,
  ),
  Job(
    suit: 'beet',
    hours: 27,
    requiredHours: jobRequiredHours,
    claimed: false,
    reward: _card('beet', 2),
    assignedCards: [_card('beet', 9, assignmentRound: 1)],
    validAssignmentTarget: false,
    highlighted: false,
  ),
];

TableViewModel fieldPlanFourCardTrickModel() => _model(
  phase: phaseTrick,
  panel: panelBrigade,
  year: 2,
  currentPlayerID: 0,
  prompt: const Prompt(
    title: 'Trick complete',
    body: 'Four cards shown for field-plan calibration.',
  ),
  trick: Trick(
    plays: [
      TrickPlay(seatID: 1, card: _card('wheat', 12)),
      TrickPlay(seatID: 2, card: _card('sunflower', 8)),
      TrickPlay(seatID: 3, card: _card('potato', 10)),
      TrickPlay(seatID: 0, card: _card('beet', 6)),
    ],
    winnerSeatID: 1,
  ),
);

final _assignmentJobs = [
  for (final job in _jobs)
    Job(
      suit: job.suit,
      hours: job.hours,
      requiredHours: job.requiredHours,
      claimed: job.claimed,
      reward: job.reward,
      assignedCards: job.assignedCards,
      validAssignmentTarget: job.suit == 'wheat' || job.suit == 'beet',
      highlighted: job.suit == 'wheat',
    ),
];

TableCard _card(
  String suit,
  int value, {
  bool selected = false,
  bool highlighted = false,
  bool pending = false,
  int? assignmentRound,
}) => TableCard(
  id: '$suit-$value',
  suit: suit,
  value: value,
  rank: switch (value) {
    11 => 'J',
    12 => 'Q',
    13 => 'K',
    14 => 'S',
    _ => '$value',
  },
  selected: selected,
  highlighted: highlighted,
  pending: pending,
  assignmentRound: assignmentRound,
);
