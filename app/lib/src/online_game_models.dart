import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'app_settings.dart';
import 'render_model.dart';
import 'saved_game_store.dart';

class OnlineEngineCard {
  const OnlineEngineCard({
    required this.suit,
    required this.value,
    this.assignmentRound,
  });

  final int suit;
  final int value;
  final int? assignmentRound;

  bool get isValid =>
      (suit >= 0 && suit < 4 && value > 0) || (suit == 4 && value == 14);

  EngineCardValue get valueObject => EngineCardValue(suit: suit, value: value);

  Map<String, Object?> toJson() => {'suit': suit, 'value': value};

  static OnlineEngineCard fromJson(Map<String, Object?> json) {
    return OnlineEngineCard(
      suit: json['suit'] as int,
      value: json['value'] as int,
      assignmentRound: json['assignmentRound'] as int?,
    );
  }
}

class OnlineEngineAction {
  const OnlineEngineAction({
    required this.kind,
    required this.playerID,
    this.suit = -1,
    this.card = const OnlineEngineCard(suit: -1, value: 0),
    this.handCard = const OnlineEngineCard(suit: -1, value: 0),
    this.plotCard = const OnlineEngineCard(suit: -1, value: 0),
    this.plotZone = -1,
    this.targetSuit = -1,
  });

  final int kind;
  final int playerID;
  final int suit;
  final OnlineEngineCard card;
  final OnlineEngineCard handCard;
  final OnlineEngineCard plotCard;
  final int plotZone;
  final int targetSuit;

  CEngineActionValue get cValue {
    return CEngineActionValue(
      kind: kind,
      playerID: playerID,
      suit: suit,
      card: card.valueObject,
      handCard: handCard.valueObject,
      plotCard: plotCard.valueObject,
      plotZone: plotZone,
      targetSuit: targetSuit,
    );
  }

  EngineAction get engineAction {
    return engineActionFromCValue(cValue);
  }

  Map<String, Object?> toJson() {
    return {
      'kind': kind,
      'playerID': playerID,
      'suit': suit,
      'card': card.toJson(),
      'handCard': handCard.toJson(),
      'plotCard': plotCard.toJson(),
      'plotZone': plotZone,
      'targetSuit': targetSuit,
    };
  }

  static OnlineEngineAction fromJson(Map<String, Object?> json) {
    return OnlineEngineAction(
      kind: json['kind'] as int,
      playerID: json['playerID'] as int,
      suit: json['suit'] as int? ?? -1,
      card: OnlineEngineCard.fromJson(_objectMap(json['card'])),
      handCard: OnlineEngineCard.fromJson(_objectMap(json['handCard'])),
      plotCard: OnlineEngineCard.fromJson(_objectMap(json['plotCard'])),
      plotZone: json['plotZone'] as int? ?? -1,
      targetSuit: json['targetSuit'] as int? ?? -1,
    );
  }

  static OnlineEngineAction fromEngineAction(EngineAction action) {
    final cAction = cEngineAction(action);
    if (cAction == null) {
      throw const FormatException('Action cannot be sent online');
    }
    return OnlineEngineAction(
      kind: cAction.kind,
      playerID: cAction.playerID,
      suit: cAction.suit,
      card: OnlineEngineCard(
        suit: cAction.card.suit,
        value: cAction.card.value,
      ),
      handCard: OnlineEngineCard(
        suit: cAction.handCard.suit,
        value: cAction.handCard.value,
      ),
      plotCard: OnlineEngineCard(
        suit: cAction.plotCard.suit,
        value: cAction.plotCard.value,
      ),
      plotZone: cAction.plotZone,
      targetSuit: cAction.targetSuit,
    );
  }
}

class OnlinePlayerSnapshot {
  const OnlinePlayerSnapshot({
    required this.id,
    required this.hand,
    required this.revealedPlot,
    required this.hiddenPlot,
    this.hiddenPlotCount,
    required this.medals,
    required this.bankedMedals,
    required this.brigadeLeader,
    required this.wonTrickThisYear,
    required this.stacks,
  });

  final int id;
  final List<OnlineEngineCard> hand;
  final List<OnlineEngineCard> revealedPlot;
  final List<OnlineEngineCard> hiddenPlot;
  final int? hiddenPlotCount;

  int get effectiveHiddenPlotCount => hiddenPlotCount ?? hiddenPlot.length;
  final int medals;
  final int bankedMedals;
  final bool brigadeLeader;
  final bool wonTrickThisYear;
  final List<OnlinePlotStackSnapshot> stacks;

  static OnlinePlayerSnapshot fromJson(Map<String, Object?> json) {
    return OnlinePlayerSnapshot(
      id: json['id'] as int,
      hand: _cards(json['hand']),
      revealedPlot: _cards(json['revealedPlot']),
      hiddenPlot: _cards(json['hiddenPlot']),
      hiddenPlotCount:
          json['hiddenPlotCount'] as int? ?? _cards(json['hiddenPlot']).length,
      medals: json['medals'] as int,
      bankedMedals: json['bankedMedals'] as int,
      brigadeLeader: json['brigadeLeader'] as bool,
      wonTrickThisYear: json['wonTrickThisYear'] as bool,
      stacks: [
        for (final value in _objectList(json['stacks']))
          OnlinePlotStackSnapshot.fromJson(_objectMap(value)),
      ],
    );
  }
}

class OnlinePlotStackSnapshot {
  const OnlinePlotStackSnapshot({
    required this.revealed,
    required this.hidden,
    this.hiddenCount,
  });

  final List<OnlineEngineCard> revealed;
  final List<OnlineEngineCard> hidden;
  final int? hiddenCount;

  int get effectiveHiddenCount => hiddenCount ?? hidden.length;

  static OnlinePlotStackSnapshot fromJson(Map<String, Object?> json) {
    return OnlinePlotStackSnapshot(
      revealed: _cards(json['revealed']),
      hidden: _cards(json['hidden']),
      hiddenCount: json['hiddenCount'] as int? ?? _cards(json['hidden']).length,
    );
  }
}

class OnlineTrickPlaySnapshot {
  const OnlineTrickPlaySnapshot({required this.playerID, required this.card});

  final int playerID;
  final OnlineEngineCard card;

  static OnlineTrickPlaySnapshot fromJson(Map<String, Object?> json) {
    return OnlineTrickPlaySnapshot(
      playerID: json['playerID'] as int,
      card: OnlineEngineCard.fromJson(_objectMap(json['card'])),
    );
  }
}

class OnlineSuitCardsSnapshot {
  const OnlineSuitCardsSnapshot({required this.suit, required this.cards});

  final int suit;
  final List<OnlineEngineCard> cards;

  static OnlineSuitCardsSnapshot fromJson(Map<String, Object?> json) {
    return OnlineSuitCardsSnapshot(
      suit: json['suit'] as int,
      cards: _cards(json['cards']),
    );
  }
}

class OnlineSuitValueSnapshot {
  const OnlineSuitValueSnapshot({required this.suit, required this.value});

  final int suit;
  final int value;

  static OnlineSuitValueSnapshot fromJson(Map<String, Object?> json) {
    return OnlineSuitValueSnapshot(
      suit: json['suit'] as int,
      value: json['value'] as int,
    );
  }
}

class OnlineSuitPlayersSnapshot {
  const OnlineSuitPlayersSnapshot({required this.suit, required this.values});

  final int suit;
  final List<int> values;

  static OnlineSuitPlayersSnapshot fromJson(Map<String, Object?> json) {
    return OnlineSuitPlayersSnapshot(
      suit: json['suit'] as int,
      values: _ints(json['values']),
    );
  }
}

class OnlineAssignmentSnapshot {
  const OnlineAssignmentSnapshot({
    required this.card,
    required this.targetSuit,
  });

  final OnlineEngineCard card;
  final int targetSuit;

  static OnlineAssignmentSnapshot fromJson(Map<String, Object?> json) {
    return OnlineAssignmentSnapshot(
      card: OnlineEngineCard.fromJson(_objectMap(json['card'])),
      targetSuit: json['targetSuit'] as int,
    );
  }
}

class OnlineRequisitionSnapshot {
  const OnlineRequisitionSnapshot({
    required this.playerID,
    required this.suit,
    required this.card,
    required this.message,
  });

  final int playerID;
  final int suit;
  final OnlineEngineCard card;
  final String message;

  static OnlineRequisitionSnapshot fromJson(Map<String, Object?> json) {
    return OnlineRequisitionSnapshot(
      playerID: json['playerID'] as int,
      suit: json['suit'] as int,
      card: OnlineEngineCard.fromJson(_objectMap(json['card'])),
      message: json['message'] as String,
    );
  }
}

class OnlineScoreSnapshot {
  const OnlineScoreSnapshot({
    required this.playerID,
    required this.visibleScore,
    required this.finalScore,
  });

  final int playerID;
  final int visibleScore;
  final int finalScore;

  static OnlineScoreSnapshot fromJson(Map<String, Object?> json) {
    return OnlineScoreSnapshot(
      playerID: json['playerID'] as int,
      visibleScore: json['visibleScore'] as int,
      finalScore: json['finalScore'] as int,
    );
  }
}

class OnlinePlayerProfile {
  const OnlinePlayerProfile({
    required this.playerID,
    this.userID,
    this.displayName,
    this.avatarURL,
    this.stats = defaultProfileStats,
  });

  final int playerID;
  final String? userID;
  final String? displayName;
  final String? avatarURL;
  final KolkhozProfileStats stats;

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;

  static OnlinePlayerProfile fromJson(Map<String, Object?> json) {
    return OnlinePlayerProfile(
      playerID: json['playerID'] as int,
      userID: json['userID'] as String?,
      displayName: json['displayName'] as String?,
      avatarURL: json['avatarURL'] as String?,
      stats: profileStatsFromSupabaseJson(json['stats']),
    );
  }
}

class OnlineComradeProfile {
  const OnlineComradeProfile({
    required this.userID,
    this.displayName,
    this.avatarURL,
    this.comradeCode,
    this.requestedAt,
    this.isOnline = false,
    this.inGame = false,
    this.inLobby = false,
    this.isComrade = false,
    this.rank,
    this.stats = defaultProfileStats,
  });

  final String userID;
  final String? displayName;
  final String? avatarURL;
  final String? comradeCode;
  final DateTime? requestedAt;
  final bool isOnline;
  final bool inGame;
  final bool inLobby;
  final bool isComrade;
  final int? rank;
  final KolkhozProfileStats stats;

  String get displayLabel {
    final trimmed = displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return comradeCode ?? userID;
  }

  String? get portraitAsset =>
      profilePortraitAssets.contains(avatarURL) ? avatarURL : null;

  static OnlineComradeProfile fromJson(Map<String, Object?> json) {
    return OnlineComradeProfile(
      userID: json['userID'] as String,
      displayName: json['displayName'] as String?,
      avatarURL: json['avatarURL'] as String?,
      comradeCode: json['comradeCode'] as String?,
      requestedAt: _dateTimeFromEpochSeconds(json['requestedAt']),
      isOnline: json['isOnline'] as bool? ?? false,
      inGame: json['inGame'] as bool? ?? false,
      inLobby: json['inLobby'] as bool? ?? false,
      isComrade: json['isComrade'] as bool? ?? false,
      rank: json['rank'] as int?,
      stats: profileStatsFromSupabaseJson(json['stats']),
    );
  }
}

class OnlineComradesResponse {
  const OnlineComradesResponse({
    this.userID,
    this.comradeCode,
    this.comrades = const [],
    this.incomingRequests = const [],
    this.outgoingRequests = const [],
  });

  final String? userID;
  final String? comradeCode;
  final List<OnlineComradeProfile> comrades;
  final List<OnlineComradeProfile> incomingRequests;
  final List<OnlineComradeProfile> outgoingRequests;

  Set<String> get userIDs => {for (final comrade in comrades) comrade.userID};

  static OnlineComradesResponse fromJson(Map<String, Object?> json) {
    return OnlineComradesResponse(
      userID: json['userID'] as String?,
      comradeCode: json['comradeCode'] as String?,
      comrades: [
        for (final value in _objectList(json['comrades'] ?? const []))
          OnlineComradeProfile.fromJson(_objectMap(value)),
      ],
      incomingRequests: [
        for (final value in _objectList(json['incomingRequests'] ?? const []))
          OnlineComradeProfile.fromJson(_objectMap(value)),
      ],
      outgoingRequests: [
        for (final value in _objectList(json['outgoingRequests'] ?? const []))
          OnlineComradeProfile.fromJson(_objectMap(value)),
      ],
    );
  }
}

class OnlineEngineSnapshot {
  const OnlineEngineSnapshot({
    required this.year,
    required this.phase,
    required this.currentPlayer,
    required this.waitingPlayer,
    required this.waitingForExternalAction,
    required this.lead,
    required this.trumpSelector,
    required this.trump,
    required this.trickCount,
    required this.isFamine,
    required this.players,
    required this.jobPiles,
    required this.revealedJobs,
    required this.claimedJobs,
    required this.workHours,
    required this.jobBuckets,
    required this.accumulatedJobCards,
    required this.currentTrick,
    required this.lastTrick,
    required this.lastWinner,
    required this.exiled,
    this.exiledPlayers = const [],
    required this.pendingAssignments,
    required this.requisitionEvents,
    required this.scores,
    required this.winnerID,
    required this.swapConfirmed,
    required this.swapCount,
  });

  final int year;
  final int phase;
  final int currentPlayer;
  final int waitingPlayer;
  final bool waitingForExternalAction;
  final int lead;
  final int trumpSelector;
  final int trump;
  final int trickCount;
  final bool isFamine;
  final List<OnlinePlayerSnapshot> players;
  final List<OnlineSuitCardsSnapshot> jobPiles;
  final List<OnlineSuitCardsSnapshot> revealedJobs;
  final List<int> claimedJobs;
  final List<OnlineSuitValueSnapshot> workHours;
  final List<OnlineSuitCardsSnapshot> jobBuckets;
  final List<OnlineSuitCardsSnapshot> accumulatedJobCards;
  final List<OnlineTrickPlaySnapshot> currentTrick;
  final List<OnlineTrickPlaySnapshot> lastTrick;
  final int lastWinner;
  final List<OnlineSuitCardsSnapshot> exiled;
  final List<OnlineSuitPlayersSnapshot> exiledPlayers;
  final List<OnlineAssignmentSnapshot> pendingAssignments;
  final List<OnlineRequisitionSnapshot> requisitionEvents;
  final List<OnlineScoreSnapshot> scores;
  final int winnerID;
  final List<int> swapConfirmed;
  final List<int> swapCount;

  static OnlineEngineSnapshot fromJson(Map<String, Object?> json) {
    return OnlineEngineSnapshot(
      year: json['year'] as int,
      phase: json['phase'] as int,
      currentPlayer: json['currentPlayer'] as int,
      waitingPlayer: json['waitingPlayer'] as int,
      waitingForExternalAction: json['waitingForExternalAction'] as bool,
      lead: json['lead'] as int,
      trumpSelector: json['trumpSelector'] as int,
      trump: json['trump'] as int,
      trickCount: json['trickCount'] as int,
      isFamine: json['isFamine'] as bool,
      players: [
        for (final value in _objectList(json['players']))
          OnlinePlayerSnapshot.fromJson(_objectMap(value)),
      ],
      jobPiles: _suitCards(json['jobPiles']),
      revealedJobs: _suitCards(json['revealedJobs']),
      claimedJobs: _ints(json['claimedJobs']),
      workHours: [
        for (final value in _objectList(json['workHours']))
          OnlineSuitValueSnapshot.fromJson(_objectMap(value)),
      ],
      jobBuckets: _suitCards(json['jobBuckets']),
      accumulatedJobCards: _suitCards(json['accumulatedJobCards']),
      currentTrick: [
        for (final value in _objectList(json['currentTrick']))
          OnlineTrickPlaySnapshot.fromJson(_objectMap(value)),
      ],
      lastTrick: [
        for (final value in _objectList(json['lastTrick']))
          OnlineTrickPlaySnapshot.fromJson(_objectMap(value)),
      ],
      lastWinner: json['lastWinner'] as int,
      exiled: _suitCards(json['exiled']),
      exiledPlayers: [
        for (final value in _objectList(json['exiledPlayers'] ?? const []))
          OnlineSuitPlayersSnapshot.fromJson(_objectMap(value)),
      ],
      pendingAssignments: [
        for (final value in _objectList(json['pendingAssignments']))
          OnlineAssignmentSnapshot.fromJson(_objectMap(value)),
      ],
      requisitionEvents: [
        for (final value in _objectList(json['requisitionEvents']))
          OnlineRequisitionSnapshot.fromJson(_objectMap(value)),
      ],
      scores: [
        for (final value in _objectList(json['scores']))
          OnlineScoreSnapshot.fromJson(_objectMap(value)),
      ],
      winnerID: json['winnerID'] as int,
      swapConfirmed: _ints(json['swapConfirmed']),
      swapCount: _ints(json['swapCount']),
    );
  }
}

class OnlineSessionUpdate {
  const OnlineSessionUpdate({
    required this.sessionID,
    this.seed,
    required this.inviteCode,
    required this.viewerID,
    required this.actionLogCount,
    required this.isViewerTurn,
    required this.legalActions,
    required this.variants,
    required this.controllers,
    required this.playerProfiles,
    this.ranked = true,
    this.browserJoinable = true,
    this.seatPresence = const [],
    this.turnPlayerID,
    this.turnDeadlineAt,
    this.started = true,
    this.lobbyCountdownEndsAt,
    this.gameLogActions = const [],
    this.reactions = const [],
    required this.snapshot,
  });

  final String sessionID;
  final int? seed;
  final String inviteCode;
  final int? viewerID;
  final int actionLogCount;
  final bool isViewerTurn;
  final List<OnlineEngineAction> legalActions;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final List<OnlinePlayerProfile> playerProfiles;
  final bool ranked;
  final bool browserJoinable;
  final List<OnlineSeatPresence> seatPresence;
  final int? turnPlayerID;
  final double? turnDeadlineAt;
  final bool started;
  final double? lobbyCountdownEndsAt;
  final List<OnlineEngineAction> gameLogActions;
  final List<OnlineReaction> reactions;
  final OnlineEngineSnapshot snapshot;

  int? get lobbyCountdownSeconds {
    final deadline = lobbyCountdownEndsAt;
    if (deadline == null || started) {
      return null;
    }
    final remaining = deadline - DateTime.now().millisecondsSinceEpoch / 1000;
    return remaining.ceil().clamp(0, 30).toInt();
  }

  static OnlineSessionUpdate fromJson(Map<String, Object?> json) {
    return OnlineSessionUpdate(
      sessionID: json['sessionID'] as String,
      seed: json['seed'] as int?,
      inviteCode: json['inviteCode'] as String? ?? json['sessionID'] as String,
      viewerID: json['viewerID'] as int?,
      actionLogCount: json['actionLogCount'] as int,
      isViewerTurn: json['isViewerTurn'] as bool? ?? false,
      legalActions: [
        for (final value in _objectList(json['legalActions'] ?? const []))
          OnlineEngineAction.fromJson(_objectMap(value)),
      ],
      variants: variantsFromJson(_objectMap(json['variants'])),
      controllers: KolkhozPlayerController.normalized([
        for (final value in _objectList(json['controllers']))
          controllerFromJson(value),
      ]),
      playerProfiles: [
        for (final value in _objectList(json['playerProfiles'] ?? const []))
          OnlinePlayerProfile.fromJson(_objectMap(value)),
      ],
      ranked: json['ranked'] as bool? ?? true,
      browserJoinable: json['browserJoinable'] as bool? ?? true,
      seatPresence: [
        for (final value in _objectList(json['seatPresence'] ?? const []))
          OnlineSeatPresence.fromJson(_objectMap(value)),
      ],
      turnPlayerID: json['turnPlayerID'] as int?,
      turnDeadlineAt: (json['turnDeadlineAt'] as num?)?.toDouble(),
      started: json['started'] as bool? ?? true,
      lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
      gameLogActions: [
        for (final value in _objectList(json['gameLogActions'] ?? const []))
          OnlineEngineAction.fromJson(_objectMap(value)),
      ],
      reactions: [
        for (final value in _objectList(json['reactions'] ?? const []))
          OnlineReaction.fromJson(_objectMap(value)),
      ],
      snapshot: OnlineEngineSnapshot.fromJson(_objectMap(json['snapshot'])),
    );
  }

  OnlineSessionUpdate copyWith({List<OnlineEngineAction>? legalActions}) {
    return OnlineSessionUpdate(
      sessionID: sessionID,
      seed: seed,
      inviteCode: inviteCode,
      viewerID: viewerID,
      actionLogCount: actionLogCount,
      isViewerTurn: isViewerTurn,
      legalActions: legalActions ?? this.legalActions,
      variants: variants,
      controllers: controllers,
      playerProfiles: playerProfiles,
      ranked: ranked,
      browserJoinable: browserJoinable,
      seatPresence: seatPresence,
      turnPlayerID: turnPlayerID,
      turnDeadlineAt: turnDeadlineAt,
      started: started,
      lobbyCountdownEndsAt: lobbyCountdownEndsAt,
      gameLogActions: gameLogActions,
      reactions: reactions,
      snapshot: snapshot,
    );
  }
}

class OnlineReaction {
  const OnlineReaction({
    required this.revision,
    required this.playerID,
    required this.reactionID,
    required this.year,
    required this.phase,
    required this.createdAt,
  });

  final int revision;
  final int playerID;
  final String reactionID;
  final int year;
  final int phase;
  final double createdAt;

  static OnlineReaction fromJson(Map<String, Object?> json) {
    return OnlineReaction(
      revision: json['revision'] as int,
      playerID: json['playerID'] as int,
      reactionID: json['reactionID'] as String,
      year: json['year'] as int,
      phase: json['phase'] as int,
      createdAt: (json['createdAt'] as num).toDouble(),
    );
  }
}

class OnlineSeatPresence {
  const OnlineSeatPresence({
    required this.playerID,
    required this.connected,
    required this.lastSeenAt,
    required this.timeouts,
    required this.autopilot,
    required this.abandoned,
  });

  final int playerID;
  final bool connected;
  final double? lastSeenAt;
  final int timeouts;
  final bool autopilot;
  final bool abandoned;

  static OnlineSeatPresence fromJson(Map<String, Object?> json) {
    return OnlineSeatPresence(
      playerID: json['playerID'] as int,
      connected: json['connected'] as bool? ?? false,
      lastSeenAt: (json['lastSeenAt'] as num?)?.toDouble(),
      timeouts: json['timeouts'] as int? ?? 0,
      autopilot: json['autopilot'] as bool? ?? false,
      abandoned: json['abandoned'] as bool? ?? false,
    );
  }
}

class OnlineSessionResponse {
  const OnlineSessionResponse({
    required this.sessionID,
    required this.inviteCode,
    required this.playerID,
    required this.seatToken,
    required this.update,
  });

  final String sessionID;
  final String inviteCode;
  final int playerID;
  final String seatToken;
  final OnlineSessionUpdate update;

  static OnlineSessionResponse fromJson(Map<String, Object?> json) {
    return OnlineSessionResponse(
      sessionID: json['sessionID'] as String,
      inviteCode: json['inviteCode'] as String? ?? json['sessionID'] as String,
      playerID: json['playerID'] as int,
      seatToken: json['seatToken'] as String,
      update: OnlineSessionUpdate.fromJson(_objectMap(json['update'])),
    );
  }
}

class OnlineActiveSession {
  const OnlineActiveSession({
    required this.sessionID,
    required this.inviteCode,
    required this.playerID,
    required this.started,
    required this.requiresSync,
  });

  final String sessionID;
  final String inviteCode;
  final int playerID;
  final bool started;
  final bool requiresSync;

  static OnlineActiveSession fromJson(Map<String, Object?> json) {
    return OnlineActiveSession(
      sessionID: json['sessionID'] as String,
      inviteCode: json['inviteCode'] as String? ?? json['sessionID'] as String,
      playerID: json['playerID'] as int,
      started: json['started'] as bool? ?? false,
      requiresSync: json['requiresSync'] as bool? ?? true,
    );
  }
}

class OnlinePresenceHeartbeat {
  const OnlinePresenceHeartbeat({required this.status, this.activeSession});

  final OnlineServerStatus status;
  final OnlineActiveSession? activeSession;

  int get citizensOnline => status.citizensOnline;

  static OnlinePresenceHeartbeat fromJson(Map<String, Object?> json) {
    final active = json['activeSession'];
    return OnlinePresenceHeartbeat(
      status: OnlineServerStatus.fromJson(json),
      activeSession: active == null
          ? null
          : OnlineActiveSession.fromJson(_objectMap(active)),
    );
  }
}

class OnlineActionUpdate {
  const OnlineActionUpdate({
    required this.revision,
    required this.action,
    required this.update,
  });

  final int revision;
  final OnlineEngineAction action;
  final OnlineSessionUpdate update;

  static OnlineActionUpdate fromJson(Map<String, Object?> json) {
    return OnlineActionUpdate(
      revision: json['revision'] as int,
      action: OnlineEngineAction.fromJson(_objectMap(json['action'])),
      update: OnlineSessionUpdate.fromJson(_objectMap(json['update'])),
    );
  }
}

class OnlineActionUpdatesResponse {
  const OnlineActionUpdatesResponse({
    required this.sessionID,
    required this.actionLogCount,
    required this.updates,
    this.resyncUpdate,
  });

  final String sessionID;
  final int actionLogCount;
  final List<OnlineActionUpdate> updates;
  final OnlineSessionUpdate? resyncUpdate;

  static OnlineActionUpdatesResponse fromJson(Map<String, Object?> json) {
    return OnlineActionUpdatesResponse(
      sessionID: json['sessionID'] as String,
      actionLogCount: json['actionLogCount'] as int,
      updates: [
        for (final value in _objectList(json['updates'] ?? const []))
          OnlineActionUpdate.fromJson(_objectMap(value)),
      ],
      resyncUpdate: json['resyncUpdate'] == null
          ? null
          : OnlineSessionUpdate.fromJson(_objectMap(json['resyncUpdate'])),
    );
  }
}

class OnlineSessionListing {
  const OnlineSessionListing({
    required this.sessionID,
    this.inviteCode,
    required this.openSeats,
    required this.occupiedSeats,
    required this.controllers,
    required this.playerProfiles,
    this.ranked = true,
    this.browserJoinable = true,
    this.seatPresence = const [],
    this.turnPlayerID,
    this.turnDeadlineAt,
    this.started = true,
    this.lobbyCountdownEndsAt,
    required this.actionLogCount,
    required this.createdAt,
    required this.expiresAt,
  });

  final String sessionID;
  final String? inviteCode;
  final List<int> openSeats;
  final List<int> occupiedSeats;
  final List<KolkhozPlayerController> controllers;
  final List<OnlinePlayerProfile> playerProfiles;
  final bool ranked;
  final bool browserJoinable;
  final List<OnlineSeatPresence> seatPresence;
  final int? turnPlayerID;
  final double? turnDeadlineAt;
  final bool started;
  final double? lobbyCountdownEndsAt;
  final int actionLogCount;
  final double createdAt;
  final double expiresAt;

  String get shortID =>
      inviteCode ??
      (sessionID.length <= 8
          ? sessionID
          : sessionID.substring(0, 8).toUpperCase());

  int get connectedHumanSeatCount {
    bool isHumanSeat(int playerID) {
      return playerID >= 0 &&
          playerID < controllers.length &&
          controllers[playerID] == KolkhozPlayerController.human;
    }

    if (seatPresence.isNotEmpty) {
      return seatPresence
          .where(
            (presence) => presence.connected && isHumanSeat(presence.playerID),
          )
          .length;
    }
    return occupiedSeats.where(isHumanSeat).length;
  }

  static OnlineSessionListing fromJson(Map<String, Object?> json) {
    return OnlineSessionListing(
      sessionID: json['sessionID'] as String,
      inviteCode: json['inviteCode'] as String?,
      openSeats: _ints(json['openSeats']),
      occupiedSeats: _ints(json['occupiedSeats']),
      controllers: KolkhozPlayerController.normalized([
        for (final value in _objectList(json['controllers']))
          controllerFromJson(value),
      ]),
      playerProfiles: [
        for (final value in _objectList(json['playerProfiles'] ?? const []))
          OnlinePlayerProfile.fromJson(_objectMap(value)),
      ],
      ranked: json['ranked'] as bool? ?? true,
      browserJoinable: json['browserJoinable'] as bool? ?? true,
      seatPresence: [
        for (final value in _objectList(json['seatPresence'] ?? const []))
          OnlineSeatPresence.fromJson(_objectMap(value)),
      ],
      turnPlayerID: json['turnPlayerID'] as int?,
      turnDeadlineAt: (json['turnDeadlineAt'] as num?)?.toDouble(),
      started: json['started'] as bool? ?? true,
      lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
      actionLogCount: json['actionLogCount'] as int,
      createdAt: (json['createdAt'] as num).toDouble(),
      expiresAt: (json['expiresAt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OnlineSessionInvite {
  const OnlineSessionInvite({
    required this.sessionID,
    required this.openSeats,
    required this.occupiedSeats,
    required this.controllers,
    required this.playerProfiles,
    required this.hostProfile,
    this.ranked = false,
    this.browserJoinable = false,
    this.started = false,
    this.lobbyCountdownEndsAt,
    required this.createdAt,
    required this.expiresAt,
  });

  final String sessionID;
  final List<int> openSeats;
  final List<int> occupiedSeats;
  final List<KolkhozPlayerController> controllers;
  final List<OnlinePlayerProfile> playerProfiles;
  final OnlinePlayerProfile? hostProfile;
  final bool ranked;
  final bool browserJoinable;
  final bool started;
  final double? lobbyCountdownEndsAt;
  final double createdAt;
  final double expiresAt;

  String get hostDisplayName {
    final trimmed = hostProfile?.displayName?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
    return 'Comrade';
  }

  static OnlineSessionInvite fromJson(Map<String, Object?> json) {
    final hostProfileJson = json['hostProfile'];
    return OnlineSessionInvite(
      sessionID: json['sessionID'] as String,
      openSeats: _ints(json['openSeats']),
      occupiedSeats: _ints(json['occupiedSeats']),
      controllers: KolkhozPlayerController.normalized([
        for (final value in _objectList(json['controllers']))
          controllerFromJson(value),
      ]),
      playerProfiles: [
        for (final value in _objectList(json['playerProfiles'] ?? const []))
          OnlinePlayerProfile.fromJson(_objectMap(value)),
      ],
      hostProfile: hostProfileJson is Map
          ? OnlinePlayerProfile.fromJson(_objectMap(hostProfileJson))
          : null,
      ranked: json['ranked'] as bool? ?? false,
      browserJoinable: json['browserJoinable'] as bool? ?? false,
      started: json['started'] as bool? ?? false,
      lobbyCountdownEndsAt: (json['lobbyCountdownEndsAt'] as num?)?.toDouble(),
      createdAt: (json['createdAt'] as num).toDouble(),
      expiresAt: (json['expiresAt'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OnlineServerStatus {
  const OnlineServerStatus({required this.citizensOnline});

  final int citizensOnline;

  static OnlineServerStatus fromJson(Map<String, Object?> json) {
    final service = _objectMap(json['service']);
    return OnlineServerStatus(
      citizensOnline: _nonNegativeInt(
        service['citizensOnline'] ?? service['activeSeats'],
      ),
    );
  }
}

List<OnlineEngineCard> _cards(Object? value) {
  return [
    for (final card in _objectList(value))
      OnlineEngineCard.fromJson(_objectMap(card)),
  ];
}

List<OnlineSuitCardsSnapshot> _suitCards(Object? value) {
  return [
    for (final entry in _objectList(value))
      OnlineSuitCardsSnapshot.fromJson(_objectMap(entry)),
  ];
}

List<int> _ints(Object? value) {
  return [for (final entry in _objectList(value)) entry as int];
}

int _nonNegativeInt(Object? value) {
  return value is int && value >= 0 ? value : 0;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw const FormatException('Expected object');
}

List<Object?> _objectList(Object? value) {
  if (value is List<Object?>) {
    return value;
  }
  if (value is List) {
    return value.cast<Object?>();
  }
  throw const FormatException('Expected list');
}

DateTime? _dateTimeFromEpochSeconds(Object? value) {
  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
  }
  if (value is double) {
    return DateTime.fromMillisecondsSinceEpoch(
      (value * 1000).round(),
      isUtc: true,
    );
  }
  return null;
}

Map<String, Object?> onlineObjectMap(Object? value) => _objectMap(value);

List<Object?> onlineObjectList(Object? value) => _objectList(value);
