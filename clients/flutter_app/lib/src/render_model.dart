import 'game_ui_state.dart';

class TableViewModel {
  const TableViewModel({
    required this.viewer,
    required this.table,
    required this.panels,
    required this.selection,
    required this.legalActions,
  });

  final Viewer viewer;
  final TableState table;
  final Panels panels;
  final SelectionState selection;
  final List<LegalAction> legalActions;
}

class Viewer {
  const Viewer({required this.seatID, required this.privacyMode});

  final int? seatID;
  final String privacyMode;
}

class TableState {
  const TableState({
    required this.year,
    required this.phase,
    required this.phasePrompt,
    required this.currentPlayerID,
    required this.trump,
    required this.isFamine,
    required this.maxTricks,
    required this.seats,
    required this.jobs,
    required this.trick,
    required this.lastTrick,
    required this.requisitionEvents,
    required this.exiledByYear,
    required this.scoreboard,
    required this.gameResult,
  });

  final int year;
  final String phase;
  final Prompt phasePrompt;
  final int currentPlayerID;
  final String? trump;
  final bool isFamine;
  final int maxTricks;
  final List<Seat> seats;
  final List<Job> jobs;
  final Trick trick;
  final Trick lastTrick;
  final List<RequisitionEvent> requisitionEvents;
  final Map<int, List<TableCard>> exiledByYear;
  final List<Score> scoreboard;
  final GameResult? gameResult;
}

class Prompt {
  const Prompt({required this.title, required this.body});

  final String title;
  final String body;
}

class Seat {
  const Seat({
    required this.id,
    required this.name,
    required this.controller,
    required this.portraitAsset,
    required this.isViewer,
    required this.isCurrentTurn,
    required this.isBrigadeLeader,
    required this.hand,
    required this.hiddenHandCount,
    required this.plot,
    required this.medals,
    required this.visibleScore,
    this.statusText = '',
  });

  final int id;
  final String name;
  final String controller;
  final String portraitAsset;
  final bool isViewer;
  final bool isCurrentTurn;
  final bool isBrigadeLeader;
  final List<TableCard> hand;
  final int hiddenHandCount;
  final PlotState plot;
  final int medals;
  final int visibleScore;
  final String statusText;
}

class PlotState {
  const PlotState({
    required this.revealed,
    required this.hidden,
    required this.stacks,
  });

  final List<TableCard> revealed;
  final List<TableCard> hidden;
  final List<PlotStackState> stacks;
}

class PlotStackState {
  const PlotStackState({required this.revealed, required this.hidden});

  final List<TableCard> revealed;
  final List<TableCard> hidden;
}

class Job {
  const Job({
    required this.suit,
    required this.hours,
    required this.requiredHours,
    required this.claimed,
    required this.reward,
    required this.assignedCards,
    required this.validAssignmentTarget,
    required this.highlighted,
  });

  final String suit;
  final int hours;
  final int requiredHours;
  final bool claimed;
  final TableCard? reward;
  final List<TableCard> assignedCards;
  final bool validAssignmentTarget;
  final bool highlighted;
}

class Trick {
  const Trick({required this.plays, required this.winnerSeatID});

  final List<TrickPlay> plays;
  final int? winnerSeatID;
}

class TrickPlay {
  const TrickPlay({required this.seatID, required this.card});

  final int seatID;
  final TableCard card;
}

class RequisitionEvent {
  const RequisitionEvent({
    required this.seatID,
    required this.suit,
    required this.card,
    required this.message,
  });

  final int? seatID;
  final String suit;
  final TableCard? card;
  final String message;
}

class Score {
  const Score({
    required this.seatID,
    required this.visibleScore,
    required this.finalScore,
  });

  final int seatID;
  final int visibleScore;
  final int? finalScore;
}

class GameResult {
  const GameResult({required this.winnerSeatID, required this.scores});

  final int winnerSeatID;
  final List<Score> scores;
}

class TableCard {
  const TableCard({
    required this.id,
    required this.suit,
    required this.value,
    required this.rank,
    required this.selected,
    required this.highlighted,
    required this.pending,
    this.assignmentRound,
    this.nomenclature = false,
  });

  final String id;
  final String suit;
  final int value;
  final String rank;
  final bool selected;
  final bool highlighted;
  final bool pending;
  final int? assignmentRound;
  final bool nomenclature;
}

class Panels {
  const Panels({required this.active, required this.available});

  final String active;
  final List<String> available;
}

class LegalAction {
  const LegalAction({
    required this.kind,
    required this.label,
    required this.engineAction,
  });

  final String kind;
  final String label;
  final EngineAction engineAction;
}

class EngineAction {
  const EngineAction({
    required this.kind,
    required this.playerID,
    this.suit,
    this.card,
    this.handCard,
    this.plotCard,
    this.plotZone,
    this.targetSuit,
  });

  final String kind;
  final int playerID;
  final String? suit;
  final EngineCard? card;
  final EngineCard? handCard;
  final EngineCard? plotCard;
  final String? plotZone;
  final String? targetSuit;
}

class EngineCard {
  const EngineCard({required this.suit, required this.value});

  final String suit;
  final int value;

  String get id => '$suit-$value';
}
