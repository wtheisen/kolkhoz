import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class KCEngine extends Opaque {}

final class KCCardNative extends Struct {
  @Int32()
  external int suit;

  @Int32()
  external int value;
}

final class KCActionNative extends Struct {
  @Int32()
  external int kind;

  @Int32()
  external int playerID;

  @Int32()
  external int suit;

  external KCCardNative card;

  external KCCardNative handCard;

  external KCCardNative plotCard;

  @Int32()
  external int plotZone;

  @Int32()
  external int targetSuit;
}

class EngineCardValue {
  const EngineCardValue({required this.suit, required this.value});

  final int suit;
  final int value;

  bool get isValid =>
      (suit >= 0 && suit < 4 && value > 0) || (suit == 4 && value == 14);
}

class CEngineActionValue {
  const CEngineActionValue({
    required this.kind,
    required this.playerID,
    required this.suit,
    required this.card,
    required this.handCard,
    required this.plotCard,
    required this.plotZone,
    required this.targetSuit,
  });

  final int kind;
  final int playerID;
  final int suit;
  final EngineCardValue card;
  final EngineCardValue handCard;
  final EngineCardValue plotCard;
  final int plotZone;
  final int targetSuit;
}

class KolkhozGameVariants {
  const KolkhozGameVariants({
    this.deckType = 52,
    this.nomenclature = true,
    this.allowSwap = true,
    this.northernStyle = false,
    this.miceVariant = false,
    this.ordenNachalniku = false,
    this.medalsCount = false,
    this.accumulateJobs = false,
    this.heroOfSovietUnion = true,
    this.wreckerCard = false,
  });

  final int deckType;
  final bool nomenclature;
  final bool allowSwap;
  final bool northernStyle;
  final bool miceVariant;
  final bool ordenNachalniku;
  final bool medalsCount;
  final bool accumulateJobs;
  final bool heroOfSovietUnion;
  final bool wreckerCard;

  KolkhozGameVariants copyWith({
    int? deckType,
    bool? nomenclature,
    bool? allowSwap,
    bool? northernStyle,
    bool? miceVariant,
    bool? ordenNachalniku,
    bool? medalsCount,
    bool? accumulateJobs,
    bool? heroOfSovietUnion,
    bool? wreckerCard,
  }) {
    return KolkhozGameVariants(
      deckType: deckType ?? this.deckType,
      nomenclature: nomenclature ?? this.nomenclature,
      allowSwap: allowSwap ?? this.allowSwap,
      northernStyle: northernStyle ?? this.northernStyle,
      miceVariant: miceVariant ?? this.miceVariant,
      ordenNachalniku: ordenNachalniku ?? this.ordenNachalniku,
      medalsCount: medalsCount ?? this.medalsCount,
      accumulateJobs: accumulateJobs ?? this.accumulateJobs,
      heroOfSovietUnion: heroOfSovietUnion ?? this.heroOfSovietUnion,
      wreckerCard: wreckerCard ?? this.wreckerCard,
    );
  }

  static const kolkhoz = KolkhozGameVariants(
    nomenclature: false,
    wreckerCard: true,
  );
  static const littleKolkhoz = KolkhozGameVariants(
    deckType: 36,
    nomenclature: true,
    allowSwap: true,
    ordenNachalniku: true,
    heroOfSovietUnion: false,
  );
  static const campStyle = KolkhozGameVariants(
    deckType: 36,
    nomenclature: true,
    allowSwap: true,
    northernStyle: true,
    miceVariant: true,
    heroOfSovietUnion: true,
  );
}

enum KolkhozPlayerController {
  human,
  heuristicAI,
  mediumAI,
  neuralAI;

  static const defaultControllers = [human, neuralAI, neuralAI, neuralAI];

  static List<KolkhozPlayerController> normalized(
    List<KolkhozPlayerController> controllers,
  ) {
    final normalized = List<KolkhozPlayerController>.generate(
      4,
      (index) => index < controllers.length
          ? controllers[index]
          : defaultControllers[index],
    );
    if (!normalized.contains(KolkhozPlayerController.human)) {
      normalized[0] = KolkhozPlayerController.human;
    }
    return normalized;
  }
}

class KolkhozCEngineBridge {
  KolkhozCEngineBridge({DynamicLibrary? library})
    : _lib = library ?? _openLibrary() {
    _bind();
  }

  final DynamicLibrary _lib;

  late final Pointer<KCEngine> Function() _engineAlloc;
  late final void Function(Pointer<KCEngine>) _engineFree;
  late final void Function(Pointer<KCEngine>, Pointer<KCEngine>) _engineClone;
  late final void Function(
    Pointer<KCEngine>,
    int,
    KCVariantsNative,
    KCControllersNative,
  )
  _engineInitWithControllers;
  late final void Function(Pointer<KCVariantsNative>) _variantsKolkhoz;
  late final void Function(Pointer<KCControllersNative>)
  _controllersAllExternal;
  late final void Function(Pointer<KCControllersNative>, int, int)
  _controllersSet;
  late final int Function(Pointer<KCEngine>) _phase;
  late final int Function(Pointer<KCEngine>) _year;
  late final int Function(Pointer<KCEngine>) _currentPlayer;
  late final int Function(Pointer<KCEngine>) _leadPlayer;
  late final int Function(Pointer<KCEngine>) _trump;
  late final int Function(Pointer<KCEngine>) _trickCount;
  late final int Function(Pointer<KCEngine>) _lastWinner;
  late final int Function(Pointer<KCEngine>) _winnerID;
  late final bool Function(Pointer<KCEngine>) _isFamine;
  late final int Function(Pointer<KCEngine>, int) _visibleScore;
  late final int Function(Pointer<KCEngine>, int) _finalScore;
  late final int Function(Pointer<KCEngine>, int) _playerMedals;
  late final int Function(Pointer<KCEngine>, int) _playerBankedMedals;
  late final bool Function(Pointer<KCEngine>, int) _playerBrigadeLeader;
  late final int Function(Pointer<KCEngine>, int) _handCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int) _handCard;
  late final int Function(Pointer<KCEngine>, int) _plotRevealedCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int)
  _plotRevealedCard;
  late final int Function(Pointer<KCEngine>, int) _plotHiddenCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int) _plotHiddenCard;
  late final int Function(Pointer<KCEngine>, int) _plotStackCount;
  late final int Function(Pointer<KCEngine>, int, int) _plotStackRevealedCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int, int)
  _plotStackRevealedCard;
  late final int Function(Pointer<KCEngine>, int, int) _plotStackHiddenCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int, int)
  _plotStackHiddenCard;
  late final bool Function(Pointer<KCEngine>, int) _hasRevealedJob;
  late final KCCardNative Function(Pointer<KCEngine>, int) _revealedJobCard;
  late final bool Function(Pointer<KCEngine>, int) _claimedJob;
  late final int Function(Pointer<KCEngine>, int) _workHours;
  late final int Function(Pointer<KCEngine>, int) _jobBucketCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int) _jobBucketCard;
  late final int Function(Pointer<KCEngine>, int, int) _jobBucketTrick;
  late final int Function(Pointer<KCEngine>) _currentTrickCount;
  late final int Function(Pointer<KCEngine>, int) _currentTrickPlayer;
  late final KCCardNative Function(Pointer<KCEngine>, int) _currentTrickCard;
  late final int Function(Pointer<KCEngine>) _lastTrickCount;
  late final int Function(Pointer<KCEngine>, int) _lastTrickPlayer;
  late final KCCardNative Function(Pointer<KCEngine>, int) _lastTrickCard;
  late final int Function(Pointer<KCEngine>, int) _pendingAssignmentTarget;
  late final int Function(Pointer<KCEngine>, int) _exiledCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int) _exiledCard;
  late final int Function(Pointer<KCEngine>) _requisitionEventCount;
  late final int Function(Pointer<KCEngine>, int) _requisitionEventPlayer;
  late final int Function(Pointer<KCEngine>, int) _requisitionEventSuit;
  late final KCCardNative Function(Pointer<KCEngine>, int)
  _requisitionEventCard;
  late final int Function(Pointer<KCEngine>, int) _requisitionEventMessageKind;
  late final bool Function(Pointer<KCEngine>, int) _swapCount;
  late final bool Function(Pointer<KCEngine>, int) _swapConfirmed;
  late final int Function(Pointer<KCEngine>) _legalActionCount;
  late final int Function(Pointer<KCEngine>, int) _legalActionKind;
  late final int Function(Pointer<KCEngine>, int) _legalActionPlayer;
  late final int Function(Pointer<KCEngine>, int) _legalActionSuit;
  late final KCCardNative Function(Pointer<KCEngine>, int) _legalActionCard;
  late final KCCardNative Function(Pointer<KCEngine>, int) _legalActionHandCard;
  late final KCCardNative Function(Pointer<KCEngine>, int) _legalActionPlotCard;
  late final int Function(Pointer<KCEngine>, int) _legalActionPlotZone;
  late final int Function(Pointer<KCEngine>, int) _legalActionTargetSuit;
  late final int Function(Pointer<KCEngine>, int, int) _applySetTrump;
  late final int Function(Pointer<KCEngine>, int, int, int) _applyPlayCard;
  late final int Function(Pointer<KCEngine>, int, int, int, int, int, int)
  _applySwap;
  late final int Function(Pointer<KCEngine>, int, int, int, int) _applyAssign;
  late final int Function(Pointer<KCEngine>, int, int) _applySimple;
  late final int Function(Pointer<KCEngine>) _stepAutomatic;
  late final int Function(Pointer<KCEngine>, KCPolicyModelBufferNative)
  _stepPolicyAutomatic;
  late final bool Function(
    Pointer<KCEngine>,
    KCPolicyModelBufferNative,
    Pointer<KCActionNative>,
  )
  _policyAction;
  late final int Function(Pointer<KCEngine>, KCActionNative) _applyPolicyAction;
  late final int Function(Pointer<KCEngine>, int, int) _applySetTrumpManual;
  late final int Function(Pointer<KCEngine>, int, int, int)
  _applyPlayCardManual;
  late final int Function(Pointer<KCEngine>, int, int, int, int, int, int)
  _applySwapManual;
  late final int Function(Pointer<KCEngine>, int, int, int, int)
  _applyAssignManual;
  late final int Function(Pointer<KCEngine>, int, int) _applySimpleManual;

  Pointer<KCEngine> newEngine({
    int? seed,
    KolkhozGameVariants variants = KolkhozGameVariants.kolkhoz,
    List<KolkhozPlayerController> controllers =
        KolkhozPlayerController.defaultControllers,
  }) {
    final engine = _engineAlloc();
    final arena = Arena();
    try {
      final nativeVariants = arena<KCVariantsNative>();
      final nativeControllers = arena<KCControllersNative>();
      _writeVariants(nativeVariants.ref, variants);
      _writeControllers(nativeControllers, controllers);
      _engineInitWithControllers(
        engine,
        seed ?? DateTime.now().millisecondsSinceEpoch,
        nativeVariants.ref,
        nativeControllers.ref,
      );
    } finally {
      arena.releaseAll();
    }
    return engine;
  }

  KolkhozGameVariants kolkhozEngineDefaults() {
    final arena = Arena();
    try {
      final nativeVariants = arena<KCVariantsNative>();
      _variantsKolkhoz(nativeVariants);
      return KolkhozGameVariants(
        deckType: nativeVariants.ref.deckType,
        nomenclature: nativeVariants.ref.nomenclature,
        allowSwap: nativeVariants.ref.allowSwap,
        northernStyle: nativeVariants.ref.northernStyle,
        miceVariant: nativeVariants.ref.miceVariant,
        ordenNachalniku: nativeVariants.ref.ordenNachalniku,
        medalsCount: nativeVariants.ref.medalsCount,
        accumulateJobs: nativeVariants.ref.accumulateJobs,
        heroOfSovietUnion: nativeVariants.ref.heroOfSovietUnion,
        wreckerCard: nativeVariants.ref.wrecker,
      );
    } finally {
      arena.releaseAll();
    }
  }

  void _writeVariants(KCVariantsNative native, KolkhozGameVariants variants) {
    native
      ..deckType = variants.deckType
      ..nomenclature = variants.nomenclature
      ..allowSwap = variants.allowSwap
      ..northernStyle = variants.northernStyle
      ..miceVariant = variants.miceVariant
      ..ordenNachalniku = variants.ordenNachalniku
      ..medalsCount = variants.medalsCount
      ..accumulateJobs = variants.accumulateJobs
      ..heroOfSovietUnion = variants.heroOfSovietUnion
      ..wrecker = variants.wreckerCard;
  }

  void _writeControllers(
    Pointer<KCControllersNative> native,
    List<KolkhozPlayerController> controllers,
  ) {
    _controllersAllExternal(native);
    final normalized = KolkhozPlayerController.normalized(controllers);
    for (var index = 0; index < normalized.length; index += 1) {
      _controllersSet(native, index, _controllerCode(normalized[index]));
    }
  }

  int _controllerCode(KolkhozPlayerController controller) {
    return switch (controller) {
      KolkhozPlayerController.human => kcControllerExternal,
      KolkhozPlayerController.heuristicAI => kcControllerHeuristicAI,
      KolkhozPlayerController.mediumAI => kcControllerPolicyAI,
      KolkhozPlayerController.neuralAI => kcControllerPolicyAI,
    };
  }

  void freeEngine(Pointer<KCEngine> engine) => _engineFree(engine);

  Pointer<KCEngine> cloneEngine(Pointer<KCEngine> source) {
    final clone = _engineAlloc();
    _engineClone(source, clone);
    return clone;
  }

  int phase(Pointer<KCEngine> engine) => _phase(engine);
  int year(Pointer<KCEngine> engine) => _year(engine);
  int currentPlayer(Pointer<KCEngine> engine) => _currentPlayer(engine);
  int leadPlayer(Pointer<KCEngine> engine) => _leadPlayer(engine);
  int trump(Pointer<KCEngine> engine) => _trump(engine);
  int trickCount(Pointer<KCEngine> engine) => _trickCount(engine);
  int lastWinner(Pointer<KCEngine> engine) => _lastWinner(engine);
  int winnerID(Pointer<KCEngine> engine) => _winnerID(engine);
  bool isFamine(Pointer<KCEngine> engine) => _isFamine(engine);
  int visibleScore(Pointer<KCEngine> engine, int playerID) =>
      _visibleScore(engine, playerID);
  int finalScore(Pointer<KCEngine> engine, int playerID) =>
      _finalScore(engine, playerID);
  int playerMedals(Pointer<KCEngine> engine, int playerID) =>
      _playerMedals(engine, playerID);
  int playerBankedMedals(Pointer<KCEngine> engine, int playerID) =>
      _playerBankedMedals(engine, playerID);
  bool playerBrigadeLeader(Pointer<KCEngine> engine, int playerID) =>
      _playerBrigadeLeader(engine, playerID);
  int handCount(Pointer<KCEngine> engine, int playerID) =>
      _handCount(engine, playerID);
  EngineCardValue handCard(Pointer<KCEngine> engine, int playerID, int index) =>
      _cardValue(_handCard(engine, playerID, index));
  int plotRevealedCount(Pointer<KCEngine> engine, int playerID) =>
      _plotRevealedCount(engine, playerID);
  EngineCardValue plotRevealedCard(
    Pointer<KCEngine> engine,
    int playerID,
    int index,
  ) => _cardValue(_plotRevealedCard(engine, playerID, index));
  int plotHiddenCount(Pointer<KCEngine> engine, int playerID) =>
      _plotHiddenCount(engine, playerID);
  EngineCardValue plotHiddenCard(
    Pointer<KCEngine> engine,
    int playerID,
    int index,
  ) => _cardValue(_plotHiddenCard(engine, playerID, index));
  int plotStackCount(Pointer<KCEngine> engine, int playerID) =>
      _plotStackCount(engine, playerID);
  int plotStackRevealedCount(
    Pointer<KCEngine> engine,
    int playerID,
    int stackIndex,
  ) => _plotStackRevealedCount(engine, playerID, stackIndex);
  EngineCardValue plotStackRevealedCard(
    Pointer<KCEngine> engine,
    int playerID,
    int stackIndex,
    int cardIndex,
  ) => _cardValue(
    _plotStackRevealedCard(engine, playerID, stackIndex, cardIndex),
  );
  int plotStackHiddenCount(
    Pointer<KCEngine> engine,
    int playerID,
    int stackIndex,
  ) => _plotStackHiddenCount(engine, playerID, stackIndex);
  EngineCardValue plotStackHiddenCard(
    Pointer<KCEngine> engine,
    int playerID,
    int stackIndex,
    int cardIndex,
  ) =>
      _cardValue(_plotStackHiddenCard(engine, playerID, stackIndex, cardIndex));
  bool hasRevealedJob(Pointer<KCEngine> engine, int suit) =>
      _hasRevealedJob(engine, suit);
  EngineCardValue revealedJobCard(Pointer<KCEngine> engine, int suit) =>
      _cardValue(_revealedJobCard(engine, suit));
  bool claimedJob(Pointer<KCEngine> engine, int suit) =>
      _claimedJob(engine, suit);
  int workHours(Pointer<KCEngine> engine, int suit) => _workHours(engine, suit);
  int jobBucketCount(Pointer<KCEngine> engine, int suit) =>
      _jobBucketCount(engine, suit);
  EngineCardValue jobBucketCard(
    Pointer<KCEngine> engine,
    int suit,
    int index,
  ) => _cardValue(_jobBucketCard(engine, suit, index));
  int jobBucketTrick(Pointer<KCEngine> engine, int suit, int index) =>
      _jobBucketTrick(engine, suit, index);
  int currentTrickCount(Pointer<KCEngine> engine) => _currentTrickCount(engine);
  int currentTrickPlayer(Pointer<KCEngine> engine, int index) =>
      _currentTrickPlayer(engine, index);
  EngineCardValue currentTrickCard(Pointer<KCEngine> engine, int index) =>
      _cardValue(_currentTrickCard(engine, index));
  int lastTrickCount(Pointer<KCEngine> engine) => _lastTrickCount(engine);
  int lastTrickPlayer(Pointer<KCEngine> engine, int index) =>
      _lastTrickPlayer(engine, index);
  EngineCardValue lastTrickCard(Pointer<KCEngine> engine, int index) =>
      _cardValue(_lastTrickCard(engine, index));
  int pendingAssignmentTarget(Pointer<KCEngine> engine, int index) =>
      _pendingAssignmentTarget(engine, index);
  int exiledCount(Pointer<KCEngine> engine, int year) =>
      _exiledCount(engine, year);
  EngineCardValue exiledCard(Pointer<KCEngine> engine, int year, int index) =>
      _cardValue(_exiledCard(engine, year, index));
  int requisitionEventCount(Pointer<KCEngine> engine) =>
      _requisitionEventCount(engine);
  int requisitionEventPlayer(Pointer<KCEngine> engine, int index) =>
      _requisitionEventPlayer(engine, index);
  int requisitionEventSuit(Pointer<KCEngine> engine, int index) =>
      _requisitionEventSuit(engine, index);
  EngineCardValue requisitionEventCard(Pointer<KCEngine> engine, int index) =>
      _cardValue(_requisitionEventCard(engine, index));
  int requisitionEventMessageKind(Pointer<KCEngine> engine, int index) =>
      _requisitionEventMessageKind(engine, index);
  bool swapCount(Pointer<KCEngine> engine, int playerID) =>
      _swapCount(engine, playerID);
  bool swapConfirmed(Pointer<KCEngine> engine, int playerID) =>
      _swapConfirmed(engine, playerID);

  List<CEngineActionValue> legalActions(Pointer<KCEngine> engine) {
    final count = _legalActionCount(engine);
    return [
      for (var index = 0; index < count; index++)
        CEngineActionValue(
          kind: _legalActionKind(engine, index),
          playerID: _legalActionPlayer(engine, index),
          suit: _legalActionSuit(engine, index),
          card: _cardValue(_legalActionCard(engine, index)),
          handCard: _cardValue(_legalActionHandCard(engine, index)),
          plotCard: _cardValue(_legalActionPlotCard(engine, index)),
          plotZone: _legalActionPlotZone(engine, index),
          targetSuit: _legalActionTargetSuit(engine, index),
        ),
    ];
  }

  int apply(Pointer<KCEngine> engine, CEngineActionValue action) {
    return switch (action.kind) {
      kcActionSetTrump => _applySetTrump(engine, action.playerID, action.suit),
      kcActionPlayCard => _applyPlayCard(
        engine,
        action.playerID,
        action.card.suit,
        action.card.value,
      ),
      kcActionSwap => _applySwap(
        engine,
        action.playerID,
        action.handCard.suit,
        action.handCard.value,
        action.plotCard.suit,
        action.plotCard.value,
        action.plotZone,
      ),
      kcActionAssign => _applyAssign(
        engine,
        action.playerID,
        action.card.suit,
        action.card.value,
        action.targetSuit,
      ),
      _ => _applySimple(engine, action.kind, action.playerID),
    };
  }

  int applyManual(Pointer<KCEngine> engine, CEngineActionValue action) {
    return switch (action.kind) {
      kcActionSetTrump => _applySetTrumpManual(
        engine,
        action.playerID,
        action.suit,
      ),
      kcActionPlayCard => _applyPlayCardManual(
        engine,
        action.playerID,
        action.card.suit,
        action.card.value,
      ),
      kcActionSwap => _applySwapManual(
        engine,
        action.playerID,
        action.handCard.suit,
        action.handCard.value,
        action.plotCard.suit,
        action.plotCard.value,
        action.plotZone,
      ),
      kcActionAssign => _applyAssignManual(
        engine,
        action.playerID,
        action.card.suit,
        action.card.value,
        action.targetSuit,
      ),
      _ => _applySimpleManual(engine, action.kind, action.playerID),
    };
  }

  int stepAutomatic(Pointer<KCEngine> engine) => _stepAutomatic(engine);

  int stepPolicyAutomatic(
    Pointer<KCEngine> engine,
    KCPolicyModelBufferNative model,
  ) => _stepPolicyAutomatic(engine, model);

  CEngineActionValue? policyAction(
    Pointer<KCEngine> engine,
    KCPolicyModelBufferNative model,
  ) {
    final arena = Arena();
    try {
      final selected = arena<KCActionNative>();
      if (!_policyAction(engine, model, selected)) {
        return null;
      }
      return _actionValue(selected.ref);
    } finally {
      arena.releaseAll();
    }
  }

  int applyPolicyAction(Pointer<KCEngine> engine, CEngineActionValue action) {
    final arena = Arena();
    try {
      final native = arena<KCActionNative>();
      _writeAction(native.ref, action);
      return _applyPolicyAction(engine, native.ref);
    } finally {
      arena.releaseAll();
    }
  }

  void _bind() {
    _engineAlloc = _lib
        .lookupFunction<
          Pointer<KCEngine> Function(),
          Pointer<KCEngine> Function()
        >('kc_engine_alloc');
    _engineFree = _lib
        .lookupFunction<
          Void Function(Pointer<KCEngine>),
          void Function(Pointer<KCEngine>)
        >('kc_engine_free');
    _engineClone = _lib
        .lookupFunction<
          Void Function(Pointer<KCEngine>, Pointer<KCEngine>),
          void Function(Pointer<KCEngine>, Pointer<KCEngine>)
        >('kc_engine_clone');
    _engineInitWithControllers = _lib
        .lookupFunction<
          Void Function(
            Pointer<KCEngine>,
            Uint64,
            KCVariantsNative,
            KCControllersNative,
          ),
          void Function(
            Pointer<KCEngine>,
            int,
            KCVariantsNative,
            KCControllersNative,
          )
        >('kc_engine_init_with_controllers');
    _variantsKolkhoz = _lib
        .lookupFunction<
          Void Function(Pointer<KCVariantsNative>),
          void Function(Pointer<KCVariantsNative>)
        >('kc_variants_kolkhoz');
    _controllersAllExternal = _lib
        .lookupFunction<
          Void Function(Pointer<KCControllersNative>),
          void Function(Pointer<KCControllersNative>)
        >('kc_controllers_all_external');
    _controllersSet = _lib
        .lookupFunction<
          Void Function(Pointer<KCControllersNative>, Int32, Int32),
          void Function(Pointer<KCControllersNative>, int, int)
        >('kc_controllers_set');
    _phase = _int0('kc_engine_phase');
    _year = _int0('kc_engine_year');
    _currentPlayer = _int0('kc_engine_current_player');
    _leadPlayer = _int0('kc_engine_lead_player');
    _trump = _int0('kc_engine_trump');
    _trickCount = _int0('kc_engine_trick_count');
    _lastWinner = _int0('kc_engine_last_winner');
    _winnerID = _int0('kc_engine_winner_id');
    _isFamine = _bool0('kc_engine_is_famine');
    _visibleScore = _int1('kc_visible_score');
    _finalScore = _int1('kc_final_score');
    _playerMedals = _int1('kc_player_medals');
    _playerBankedMedals = _int1('kc_player_banked_medals');
    _playerBrigadeLeader = _bool1('kc_player_brigade_leader');
    _handCount = _int1('kc_player_hand_count');
    _handCard = _card2('kc_player_hand_card');
    _plotRevealedCount = _int1('kc_player_plot_revealed_count');
    _plotRevealedCard = _card2('kc_player_plot_revealed_card');
    _plotHiddenCount = _int1('kc_player_plot_hidden_count');
    _plotHiddenCard = _card2('kc_player_plot_hidden_card');
    _plotStackCount = _int1('kc_player_plot_stack_count');
    _plotStackRevealedCount = _int2('kc_player_plot_stack_revealed_count');
    _plotStackRevealedCard = _card3('kc_player_plot_stack_revealed_card');
    _plotStackHiddenCount = _int2('kc_player_plot_stack_hidden_count');
    _plotStackHiddenCard = _card3('kc_player_plot_stack_hidden_card');
    _hasRevealedJob = _bool1('kc_has_revealed_job');
    _revealedJobCard = _card1('kc_revealed_job_card');
    _claimedJob = _bool1('kc_claimed_job');
    _workHours = _int1('kc_work_hours');
    _jobBucketCount = _int1('kc_job_bucket_count');
    _jobBucketCard = _card2('kc_job_bucket_card');
    _jobBucketTrick = _int2('kc_job_bucket_trick');
    _currentTrickCount = _int0('kc_current_trick_count');
    _currentTrickPlayer = _int1('kc_current_trick_player');
    _currentTrickCard = _card1('kc_current_trick_card');
    _lastTrickCount = _int0('kc_last_trick_count');
    _lastTrickPlayer = _int1('kc_last_trick_player');
    _lastTrickCard = _card1('kc_last_trick_card');
    _pendingAssignmentTarget = _int1('kc_pending_assignment_target');
    _exiledCount = _int1('kc_exiled_count');
    _exiledCard = _card2('kc_exiled_card');
    _requisitionEventCount = _int0('kc_requisition_event_count');
    _requisitionEventPlayer = _int1('kc_requisition_event_player');
    _requisitionEventSuit = _int1('kc_requisition_event_suit');
    _requisitionEventCard = _card1('kc_requisition_event_card');
    _requisitionEventMessageKind = _int1('kc_requisition_event_message_kind');
    _swapCount = _bool1('kc_swap_count');
    _swapConfirmed = _bool1('kc_swap_confirmed');
    _legalActionCount = _int0('kc_legal_action_count');
    _legalActionKind = _int1('kc_legal_action_kind_at');
    _legalActionPlayer = _int1('kc_legal_action_player_at');
    _legalActionSuit = _int1('kc_legal_action_suit_at');
    _legalActionCard = _card1('kc_legal_action_card_at');
    _legalActionHandCard = _card1('kc_legal_action_hand_card_at');
    _legalActionPlotCard = _card1('kc_legal_action_plot_card_at');
    _legalActionPlotZone = _int1('kc_legal_action_plot_zone_at');
    _legalActionTargetSuit = _int1('kc_legal_action_target_suit_at');
    _applySetTrump = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int)
        >('kc_engine_apply_set_trump');
    _applyPlayCard = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int)
        >('kc_engine_apply_play_card');
    _applySwap = _lib
        .lookupFunction<
          Int32 Function(
            Pointer<KCEngine>,
            Int32,
            Int32,
            Int32,
            Int32,
            Int32,
            Int32,
          ),
          int Function(Pointer<KCEngine>, int, int, int, int, int, int)
        >('kc_engine_apply_swap');
    _applyAssign = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int, int)
        >('kc_engine_apply_assign');
    _applySimple = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int)
        >('kc_engine_apply_simple');
    _stepAutomatic = _int0('kc_engine_step_automatic');
    _stepPolicyAutomatic = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, KCPolicyModelBufferNative),
          int Function(Pointer<KCEngine>, KCPolicyModelBufferNative)
        >('kc_engine_step_policy_automatic');
    _policyAction = _lib
        .lookupFunction<
          Bool Function(
            Pointer<KCEngine>,
            KCPolicyModelBufferNative,
            Pointer<KCActionNative>,
          ),
          bool Function(
            Pointer<KCEngine>,
            KCPolicyModelBufferNative,
            Pointer<KCActionNative>,
          )
        >('kc_engine_policy_action');
    _applyPolicyAction = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, KCActionNative),
          int Function(Pointer<KCEngine>, KCActionNative)
        >('kc_engine_apply_policy_action');
    _applySetTrumpManual = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int)
        >('kc_engine_apply_set_trump_manual');
    _applyPlayCardManual = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int)
        >('kc_engine_apply_play_card_manual');
    _applySwapManual = _lib
        .lookupFunction<
          Int32 Function(
            Pointer<KCEngine>,
            Int32,
            Int32,
            Int32,
            Int32,
            Int32,
            Int32,
          ),
          int Function(Pointer<KCEngine>, int, int, int, int, int, int)
        >('kc_engine_apply_swap_manual');
    _applyAssignManual = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int, int)
        >('kc_engine_apply_assign_manual');
    _applySimpleManual = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int)
        >('kc_engine_apply_simple_manual');
  }

  int Function(Pointer<KCEngine>) _int0(String name) {
    return _lib.lookupFunction<
      Int32 Function(Pointer<KCEngine>),
      int Function(Pointer<KCEngine>)
    >(name);
  }

  int Function(Pointer<KCEngine>, int) _int1(String name) {
    return _lib.lookupFunction<
      Int32 Function(Pointer<KCEngine>, Int32),
      int Function(Pointer<KCEngine>, int)
    >(name);
  }

  int Function(Pointer<KCEngine>, int, int) _int2(String name) {
    return _lib.lookupFunction<
      Int32 Function(Pointer<KCEngine>, Int32, Int32),
      int Function(Pointer<KCEngine>, int, int)
    >(name);
  }

  bool Function(Pointer<KCEngine>) _bool0(String name) {
    return _lib.lookupFunction<
      Bool Function(Pointer<KCEngine>),
      bool Function(Pointer<KCEngine>)
    >(name);
  }

  bool Function(Pointer<KCEngine>, int) _bool1(String name) {
    return _lib.lookupFunction<
      Bool Function(Pointer<KCEngine>, Int32),
      bool Function(Pointer<KCEngine>, int)
    >(name);
  }

  KCCardNative Function(Pointer<KCEngine>, int) _card1(String name) {
    return _lib.lookupFunction<
      KCCardNative Function(Pointer<KCEngine>, Int32),
      KCCardNative Function(Pointer<KCEngine>, int)
    >(name);
  }

  KCCardNative Function(Pointer<KCEngine>, int, int) _card2(String name) {
    return _lib.lookupFunction<
      KCCardNative Function(Pointer<KCEngine>, Int32, Int32),
      KCCardNative Function(Pointer<KCEngine>, int, int)
    >(name);
  }

  KCCardNative Function(Pointer<KCEngine>, int, int, int) _card3(String name) {
    return _lib.lookupFunction<
      KCCardNative Function(Pointer<KCEngine>, Int32, Int32, Int32),
      KCCardNative Function(Pointer<KCEngine>, int, int, int)
    >(name);
  }

  EngineCardValue _cardValue(KCCardNative card) {
    return EngineCardValue(suit: card.suit, value: card.value);
  }

  CEngineActionValue _actionValue(KCActionNative action) {
    return CEngineActionValue(
      kind: action.kind,
      playerID: action.playerID,
      suit: action.suit,
      card: _cardValue(action.card),
      handCard: _cardValue(action.handCard),
      plotCard: _cardValue(action.plotCard),
      plotZone: action.plotZone,
      targetSuit: action.targetSuit,
    );
  }

  void _writeAction(KCActionNative native, CEngineActionValue action) {
    native
      ..kind = action.kind
      ..playerID = action.playerID
      ..suit = action.suit
      ..card.suit = action.card.suit
      ..card.value = action.card.value
      ..handCard.suit = action.handCard.suit
      ..handCard.value = action.handCard.value
      ..plotCard.suit = action.plotCard.suit
      ..plotCard.value = action.plotCard.value
      ..plotZone = action.plotZone
      ..targetSuit = action.targetSuit;
  }

  static DynamicLibrary _openLibrary() {
    final envPath = Platform.environment['KOLKHOZ_C_ENGINE_LIB'];
    if (envPath != null && envPath.isNotEmpty) {
      return DynamicLibrary.open(envPath);
    }
    if (Platform.isMacOS || Platform.isIOS) {
      final executable = File(Platform.resolvedExecutable);
      final bundleContents = executable.parent.parent;
      for (final path in [
        '${bundleContents.path}/Frameworks/libkolkhoz_c_engine.dylib',
        'native/macos/libkolkhoz_c_engine.dylib',
        '../../clients/flutter_app/native/macos/libkolkhoz_c_engine.dylib',
      ]) {
        if (File(path).existsSync()) {
          return DynamicLibrary.open(path);
        }
      }
      return DynamicLibrary.process();
    }
    if (Platform.isWindows) {
      return DynamicLibrary.open('kolkhoz_c_engine.dll');
    }
    return DynamicLibrary.open('libkolkhoz_c_engine.so');
  }
}

final class KCVariantsNative extends Struct {
  @Int32()
  external int deckType;

  @Bool()
  external bool nomenclature;

  @Bool()
  external bool allowSwap;

  @Bool()
  external bool northernStyle;

  @Bool()
  external bool miceVariant;

  @Bool()
  external bool ordenNachalniku;

  @Bool()
  external bool medalsCount;

  @Bool()
  external bool accumulateJobs;

  @Bool()
  external bool heroOfSovietUnion;

  @Bool()
  external bool wrecker;
}

final class KCControllersNative extends Struct {
  @Array(4)
  external Array<Int32> seats;
}

final class KCPolicyModelBufferNative extends Struct {
  @Int32()
  external int inputSize;

  @Int32()
  external int hiddenSize;

  @Int32()
  external int layerCount;

  @Array(4)
  external Array<Int32> layerSizes;

  @Int32()
  external int headCount;

  external Pointer<Double> w1;

  external Pointer<Double> b1;

  @Array(4)
  external Array<Pointer<Double>> layerWeights;

  @Array(4)
  external Array<Pointer<Double>> layerBiases;

  external Pointer<Double> w2;

  external Pointer<Double> outputWeights;

  external Pointer<Double> b2;

  external Pointer<Double> b2s;
}

const kcActionSetTrump = 1;
const kcActionSwap = 2;
const kcActionConfirmSwap = 3;
const kcActionPlayCard = 4;
const kcActionAssign = 5;
const kcActionSubmitAssignments = 6;
const kcActionContinueAfterRequisition = 7;
const kcActionUndoSwap = 8;

const kcPhasePlanning = 0;
const kcPhaseSwap = 1;
const kcPhaseTrick = 2;
const kcPhaseAssignment = 3;
const kcPhaseRequisition = 4;
const kcPhaseGameOver = 5;

const kcControllerExternal = 0;
const kcControllerHeuristicAI = 1;
const kcControllerPolicyAI = 2;
