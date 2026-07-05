import 'dart:convert';
import 'dart:io';

import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'render_model.dart';
import 'saved_game_store.dart';

class OnlineEngineCard {
  const OnlineEngineCard({required this.suit, required this.value});

  final int suit;
  final int value;

  bool get isValid => suit >= 0 && value > 0;

  EngineCardValue get valueObject => EngineCardValue(suit: suit, value: value);

  Map<String, Object?> toJson() => {'suit': suit, 'value': value};

  static OnlineEngineCard fromJson(Map<String, Object?> json) {
    return OnlineEngineCard(
      suit: json['suit'] as int,
      value: json['value'] as int,
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
  const OnlinePlotStackSnapshot({required this.revealed, required this.hidden});

  final List<OnlineEngineCard> revealed;
  final List<OnlineEngineCard> hidden;

  static OnlinePlotStackSnapshot fromJson(Map<String, Object?> json) {
    return OnlinePlotStackSnapshot(
      revealed: _cards(json['revealed']),
      hidden: _cards(json['hidden']),
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
    required this.viewerID,
    required this.actionLogCount,
    required this.variants,
    required this.controllers,
    required this.snapshot,
  });

  final String sessionID;
  final int? viewerID;
  final int actionLogCount;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
  final OnlineEngineSnapshot snapshot;

  static OnlineSessionUpdate fromJson(Map<String, Object?> json) {
    return OnlineSessionUpdate(
      sessionID: json['sessionID'] as String,
      viewerID: json['viewerID'] as int?,
      actionLogCount: json['actionLogCount'] as int,
      variants: variantsFromJson(_objectMap(json['variants'])),
      controllers: KolkhozPlayerController.normalized([
        for (final value in _objectList(json['controllers']))
          controllerFromJson(value),
      ]),
      snapshot: OnlineEngineSnapshot.fromJson(_objectMap(json['snapshot'])),
    );
  }
}

class OnlineSessionResponse {
  const OnlineSessionResponse({
    required this.sessionID,
    required this.playerID,
    required this.update,
  });

  final String sessionID;
  final int playerID;
  final OnlineSessionUpdate update;

  static OnlineSessionResponse fromJson(Map<String, Object?> json) {
    return OnlineSessionResponse(
      sessionID: json['sessionID'] as String,
      playerID: json['playerID'] as int,
      update: OnlineSessionUpdate.fromJson(_objectMap(json['update'])),
    );
  }
}

class KolkhozOnlineClient {
  KolkhozOnlineClient(this.baseURL, {HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final Uri baseURL;
  final HttpClient _httpClient;

  Future<OnlineSessionResponse> createSession({
    int? seed,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
  }) async {
    final body = <String, Object?>{
      'variants': variantsToJson(variants),
      'controllers': controllers.map((controller) => controller.name).toList(),
    };
    if (seed != null) {
      body['seed'] = seed;
    }
    final json = await _sendJson(method: 'POST', path: 'sessions', body: body);
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionResponse> joinSession({
    required String sessionID,
    int? preferredPlayerID,
  }) async {
    final body = <String, Object?>{'sessionID': sessionID};
    if (preferredPlayerID != null) {
      body['preferredPlayerID'] = preferredPlayerID;
    }
    final json = await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/join',
      body: body,
    );
    return OnlineSessionResponse.fromJson(json);
  }

  Future<OnlineSessionUpdate> fetchUpdate({
    required String sessionID,
    required int playerID,
  }) async {
    final json = await _sendJson(
      method: 'GET',
      path: 'sessions/$sessionID/state',
      query: {'viewerID': '$playerID'},
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<List<OnlineEngineAction>> fetchLegalActions({
    required String sessionID,
    required int playerID,
  }) async {
    final decoded = await _send(
      method: 'GET',
      path: 'sessions/$sessionID/players/$playerID/actions',
    );
    return [
      for (final value in _objectList(decoded))
        OnlineEngineAction.fromJson(_objectMap(value)),
    ];
  }

  Future<OnlineSessionUpdate> submitAction({
    required String sessionID,
    required int playerID,
    required EngineAction action,
  }) async {
    final json = await _sendJson(
      method: 'POST',
      path: 'sessions/$sessionID/actions',
      body: {
        'sessionID': sessionID,
        'playerID': playerID,
        'action': OnlineEngineAction.fromEngineAction(action).toJson(),
      },
    );
    return OnlineSessionUpdate.fromJson(json);
  }

  Future<Map<String, Object?>> _sendJson({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Object? body,
  }) async {
    final decoded = await _send(
      method: method,
      path: path,
      query: query,
      body: body,
    );
    return _objectMap(decoded);
  }

  Future<Object?> _send({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Object? body,
  }) async {
    final uri = _resolve(path, query);
    final request = await _httpClient.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    if (body != null) {
      final encodedBody = utf8.encode(jsonEncode(body));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.contentLength = encodedBody.length;
      request.add(encodedBody);
    }
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        responseBody.isEmpty ? 'Online request failed' : responseBody,
        uri: uri,
      );
    }
    return responseBody.isEmpty ? null : jsonDecode(responseBody);
  }

  Uri _resolve(String path, Map<String, String> query) {
    final normalizedBase = baseURL.path.endsWith('/')
        ? baseURL
        : baseURL.replace(path: '${baseURL.path}/');
    final resolved = normalizedBase.resolve(path);
    if (query.isEmpty) {
      return resolved;
    }
    return resolved.replace(queryParameters: query);
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
