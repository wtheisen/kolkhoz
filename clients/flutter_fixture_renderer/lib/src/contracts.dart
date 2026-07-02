class TableViewModel {
  const TableViewModel({
    required this.contractVersion,
    required this.viewer,
    required this.table,
    required this.panels,
    required this.legalActions,
  });

  factory TableViewModel.fromJson(Map<String, Object?> json) {
    return TableViewModel(
      contractVersion: json['contractVersion'] as int,
      viewer: Viewer.fromJson(json['viewer']! as Map<String, Object?>),
      table: TableState.fromJson(json['table']! as Map<String, Object?>),
      panels: Panels.fromJson(json['panels']! as Map<String, Object?>),
      legalActions: _list(
        json['legalActions'],
      ).map(LegalAction.fromJson).toList(),
    );
  }

  final int contractVersion;
  final Viewer viewer;
  final TableState table;
  final Panels panels;
  final List<LegalAction> legalActions;
}

class Viewer {
  const Viewer({
    required this.seatID,
    required this.isOnline,
    required this.connection,
  });

  factory Viewer.fromJson(Map<String, Object?> json) {
    return Viewer(
      seatID: json['seatID'] as int?,
      isOnline: json['isOnline'] as bool,
      connection: json['connection'] as String? ?? 'offline',
    );
  }

  final int? seatID;
  final bool isOnline;
  final String connection;
}

class TableState {
  const TableState({
    required this.year,
    required this.phase,
    required this.phasePrompt,
    required this.currentPlayerID,
    required this.trump,
    required this.isFamine,
    required this.trickCount,
    required this.maxTricks,
    required this.seats,
    required this.jobs,
    required this.trick,
    required this.lastTrick,
    required this.scoreboard,
  });

  factory TableState.fromJson(Map<String, Object?> json) {
    return TableState(
      year: json['year'] as int,
      phase: json['phase'] as String,
      phasePrompt: Prompt.fromJson(
        json['phasePrompt']! as Map<String, Object?>,
      ),
      currentPlayerID: json['currentPlayerID'] as int,
      trump: json['trump'] as String?,
      isFamine: json['isFamine'] as bool,
      trickCount: json['trickCount'] as int,
      maxTricks: json['maxTricks'] as int,
      seats: _list(json['seats']).map(Seat.fromJson).toList(),
      jobs: _list(json['jobs']).map(Job.fromJson).toList(),
      trick: Trick.fromJson(json['trick']! as Map<String, Object?>),
      lastTrick: Trick.fromJson(json['lastTrick']! as Map<String, Object?>),
      scoreboard: _list(json['scoreboard']).map(Score.fromJson).toList(),
    );
  }

  final int year;
  final String phase;
  final Prompt phasePrompt;
  final int currentPlayerID;
  final String? trump;
  final bool isFamine;
  final int trickCount;
  final int maxTricks;
  final List<Seat> seats;
  final List<Job> jobs;
  final Trick trick;
  final Trick lastTrick;
  final List<Score> scoreboard;
}

class Prompt {
  const Prompt({required this.title, required this.body, required this.tone});

  factory Prompt.fromJson(Map<String, Object?> json) {
    return Prompt(
      title: json['title'] as String,
      body: json['body'] as String,
      tone: json['tone'] as String,
    );
  }

  final String title;
  final String body;
  final String tone;
}

class Seat {
  const Seat({
    required this.id,
    required this.name,
    required this.controller,
    required this.isViewer,
    required this.isCurrentTurn,
    required this.isBrigadeLeader,
    required this.hand,
    required this.hiddenHandCount,
    required this.plot,
    required this.medals,
    required this.visibleScore,
  });

  factory Seat.fromJson(Map<String, Object?> json) {
    return Seat(
      id: json['id'] as int,
      name: json['name'] as String,
      controller: json['controller'] as String,
      isViewer: json['isViewer'] as bool,
      isCurrentTurn: json['isCurrentTurn'] as bool,
      isBrigadeLeader: json['isBrigadeLeader'] as bool,
      hand: _list(json['hand']).map(ContractCard.fromJson).toList(),
      hiddenHandCount: json['hiddenHandCount'] as int,
      plot: PlotState.fromJson(json['plot']! as Map<String, Object?>),
      medals: json['medals'] as int,
      visibleScore: json['visibleScore'] as int,
    );
  }

  final int id;
  final String name;
  final String controller;
  final bool isViewer;
  final bool isCurrentTurn;
  final bool isBrigadeLeader;
  final List<ContractCard> hand;
  final int hiddenHandCount;
  final PlotState plot;
  final int medals;
  final int visibleScore;
}

class PlotState {
  const PlotState({
    required this.revealed,
    required this.hidden,
    required this.hiddenCount,
  });

  factory PlotState.fromJson(Map<String, Object?> json) {
    return PlotState(
      revealed: _list(json['revealed']).map(ContractCard.fromJson).toList(),
      hidden: _list(json['hidden']).map(ContractCard.fromJson).toList(),
      hiddenCount: json['hiddenCount'] as int,
    );
  }

  final List<ContractCard> revealed;
  final List<ContractCard> hidden;
  final int hiddenCount;
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

  factory Job.fromJson(Map<String, Object?> json) {
    final reward = json['reward'];
    return Job(
      suit: json['suit'] as String,
      hours: json['hours'] as int,
      requiredHours: json['requiredHours'] as int,
      claimed: json['claimed'] as bool,
      reward: reward == null
          ? null
          : ContractCard.fromJson(reward as Map<String, Object?>),
      assignedCards: _list(
        json['assignedCards'],
      ).map(ContractCard.fromJson).toList(),
      validAssignmentTarget: json['validAssignmentTarget'] as bool,
      highlighted: json['highlighted'] as bool? ?? false,
    );
  }

  final String suit;
  final int hours;
  final int requiredHours;
  final bool claimed;
  final ContractCard? reward;
  final List<ContractCard> assignedCards;
  final bool validAssignmentTarget;
  final bool highlighted;
}

class Trick {
  const Trick({required this.plays, required this.winnerSeatID});

  factory Trick.fromJson(Map<String, Object?> json) {
    return Trick(
      plays: _list(json['plays']).map(TrickPlay.fromJson).toList(),
      winnerSeatID: json['winnerSeatID'] as int?,
    );
  }

  final List<TrickPlay> plays;
  final int? winnerSeatID;
}

class TrickPlay {
  const TrickPlay({required this.seatID, required this.card});

  factory TrickPlay.fromJson(Map<String, Object?> json) {
    return TrickPlay(
      seatID: json['seatID'] as int,
      card: ContractCard.fromJson(json['card']! as Map<String, Object?>),
    );
  }

  final int seatID;
  final ContractCard card;
}

class Score {
  const Score({
    required this.seatID,
    required this.visibleScore,
    required this.finalScore,
  });

  factory Score.fromJson(Map<String, Object?> json) {
    return Score(
      seatID: json['seatID'] as int,
      visibleScore: json['visibleScore'] as int,
      finalScore: json['finalScore'] as int?,
    );
  }

  final int seatID;
  final int visibleScore;
  final int? finalScore;
}

class ContractCard {
  const ContractCard({
    required this.id,
    required this.suit,
    required this.value,
    required this.rank,
    required this.visible,
    required this.selected,
    required this.disabled,
    required this.highlighted,
    required this.pending,
  });

  factory ContractCard.fromJson(Map<String, Object?> json) {
    return ContractCard(
      id: json['id'] as String,
      suit: json['suit'] as String,
      value: json['value'] as int,
      rank: json['rank'] as String,
      visible: json['visible'] as bool,
      selected: json['selected'] as bool? ?? false,
      disabled: json['disabled'] as bool? ?? false,
      highlighted: json['highlighted'] as bool? ?? false,
      pending: json['pending'] as bool? ?? false,
    );
  }

  final String id;
  final String suit;
  final int value;
  final String rank;
  final bool visible;
  final bool selected;
  final bool disabled;
  final bool highlighted;
  final bool pending;
}

class Panels {
  const Panels({
    required this.active,
    required this.available,
    required this.rightInfo,
  });

  factory Panels.fromJson(Map<String, Object?> json) {
    return Panels(
      active: json['active'] as String,
      available: (json['available']! as List<Object?>).cast<String>(),
      rightInfo: RightInfo.fromJson(json['rightInfo']! as Map<String, Object?>),
    );
  }

  final String active;
  final List<String> available;
  final RightInfo rightInfo;
}

class RightInfo {
  const RightInfo({
    required this.mode,
    required this.title,
    required this.sections,
  });

  factory RightInfo.fromJson(Map<String, Object?> json) {
    return RightInfo(
      mode: json['mode'] as String,
      title: json['title'] as String,
      sections: _list(json['sections']).map(InfoSection.fromJson).toList(),
    );
  }

  final String mode;
  final String title;
  final List<InfoSection> sections;
}

class InfoSection {
  const InfoSection({required this.title, required this.body});

  factory InfoSection.fromJson(Map<String, Object?> json) {
    return InfoSection(
      title: json['title'] as String,
      body: json['body'] as String,
    );
  }

  final String title;
  final String body;
}

class LegalAction {
  const LegalAction({
    required this.id,
    required this.kind,
    required this.label,
    required this.targets,
    required this.enabled,
  });

  factory LegalAction.fromJson(Map<String, Object?> json) {
    return LegalAction(
      id: json['id'] as String,
      kind: json['kind'] as String,
      label: json['label'] as String? ?? json['kind'] as String,
      targets: (json['targets'] as List<Object?>? ?? const []).cast<String>(),
      enabled: json['enabled'] as bool,
    );
  }

  final String id;
  final String kind;
  final String label;
  final List<String> targets;
  final bool enabled;
}

Iterable<Map<String, Object?>> _list(Object? value) {
  return (value! as List<Object?>).cast<Map<String, Object?>>();
}
