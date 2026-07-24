import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

export 'package:kolkhoz_app/src/app/views/game/game_controller/models/engine_values.dart';

final class KCEngine extends Opaque {}

final class KCPolicyWorkspace extends Opaque {}

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
  _engineInitWithControllersStepwise;
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
  late final int Function(Pointer<KCEngine>) _currentTrickWinner;
  late final int Function(Pointer<KCEngine>, int) _currentTrickPlayer;
  late final KCCardNative Function(Pointer<KCEngine>, int) _currentTrickCard;
  late final int Function(Pointer<KCEngine>) _lastTrickCount;
  late final int Function(Pointer<KCEngine>, int) _lastTrickPlayer;
  late final KCCardNative Function(Pointer<KCEngine>, int) _lastTrickCard;
  late final int Function(Pointer<KCEngine>, int) _pendingAssignmentTarget;
  late final int Function(Pointer<KCEngine>, int) _exiledCount;
  late final KCCardNative Function(Pointer<KCEngine>, int, int) _exiledCard;
  late final int Function(Pointer<KCEngine>, int, int) _exiledPlayer;
  late final int Function(Pointer<KCEngine>) _requisitionEventCount;
  late final int Function(Pointer<KCEngine>, int) _requisitionEventPlayer;
  late final int Function(Pointer<KCEngine>, int) _requisitionEventSuit;
  late final KCCardNative Function(Pointer<KCEngine>, int)
  _requisitionEventCard;
  late final int Function(Pointer<KCEngine>, int) _requisitionEventMessageKind;
  late final int Function(Pointer<KCEngine>) _transitionEventCount;
  late final int Function(Pointer<KCEngine>, int) _transitionEventKind;
  late final int Function(Pointer<KCEngine>, int) _transitionEventPlayer;
  late final KCCardNative Function(Pointer<KCEngine>, int) _transitionEventCard;
  late final int Function(Pointer<KCEngine>, int) _transitionEventFromZone;
  late final int Function(Pointer<KCEngine>, int) _transitionEventToZone;
  late final int Function(Pointer<KCEngine>, int) _transitionEventFromOwner;
  late final int Function(Pointer<KCEngine>, int) _transitionEventToOwner;
  late final int Function(Pointer<KCEngine>, int) _transitionEventTargetSuit;
  late final int Function(Pointer<KCEngine>, int) _transitionEventTrickWinner;
  late final bool Function(Pointer<KCEngine>, int) _swapCount;
  late final bool Function(Pointer<KCEngine>, int) _swapConfirmed;
  late final bool Function(Pointer<KCEngine>, int) _passConfirmed;
  late final KCCardNative Function(Pointer<KCEngine>) _finalYearTrumpCard;
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
  late final int Function(Pointer<KCEngine>, int, int, int) _applyPassCard;
  late final int Function(Pointer<KCEngine>, int, int, int, int, int, int)
  _applySwap;
  late final int Function(Pointer<KCEngine>, int, int, int, int) _applyAssign;
  late final int Function(Pointer<KCEngine>, int, int) _applySimple;
  late final int Function(Pointer<KCEngine>, int, int, int) _applySuitAction;
  late final int Function(Pointer<KCEngine>) _stepAutomatic;
  late final bool Function(Pointer<KCEngine>, Pointer<KCActionNative>)
  _heuristicAction;
  late final int Function(Pointer<KCEngine>, KCPolicyModelBufferNative)
  _stepPolicyAutomatic;
  late final bool Function(
    Pointer<KCEngine>,
    KCPolicyModelBufferNative,
    Pointer<KCActionNative>,
  )
  _policyAction;
  late final Pointer<KCPolicyWorkspace> Function(KCPolicyModelBufferNative)
  _policyWorkspaceAlloc;
  late final void Function(Pointer<KCPolicyWorkspace>) _policyWorkspaceFree;
  late final bool Function(
    Pointer<KCEngine>,
    KCPolicyModelBufferNative,
    Pointer<KCPolicyWorkspace>,
    Pointer<KCActionNative>,
  )
  _policyActionWithWorkspace;
  late final int Function(Pointer<KCEngine>, KCActionNative) _applyAIAction;
  late final int Function(Pointer<KCEngine>, int, int) _applySetTrumpManual;
  late final int Function(Pointer<KCEngine>, int, int, int)
  _applyPlayCardManual;
  late final int Function(Pointer<KCEngine>, int, int, int)
  _applyPassCardManual;
  late final int Function(Pointer<KCEngine>, int, int, int, int, int, int)
  _applySwapManual;
  late final int Function(Pointer<KCEngine>, int, int, int, int)
  _applyAssignManual;
  late final int Function(Pointer<KCEngine>, int, int) _applySimpleManual;
  late final int Function(Pointer<KCEngine>, int, int, int)
  _applySuitActionManual;

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
      _engineInitWithControllersStepwise(
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
        maxYears: nativeVariants.ref.maxYears,
        nomenclature: nativeVariants.ref.nomenclature,
        allowSwap: nativeVariants.ref.allowSwap,
        northernStyle: nativeVariants.ref.northernStyle,
        miceVariant: nativeVariants.ref.miceVariant,
        ordenNachalniku: nativeVariants.ref.ordenNachalniku,
        medalsCount: nativeVariants.ref.medalsCount,
        accumulateJobs: nativeVariants.ref.accumulateJobs,
        heroOfSovietUnion: nativeVariants.ref.heroOfSovietUnion,
        wreckerCard: nativeVariants.ref.wrecker,
        finalYearTrump: nativeVariants.ref.finalYearTrump,
        passCards: nativeVariants.ref.passCards,
        highestCardsRequisition: nativeVariants.ref.highestCardsRequisition,
        lottoRewards: nativeVariants.ref.lottoRewards,
      );
    } finally {
      arena.releaseAll();
    }
  }

  void _writeVariants(KCVariantsNative native, KolkhozGameVariants variants) {
    native
      ..deckType = variants.deckType
      ..maxYears = variants.maxYears
      ..nomenclature = variants.nomenclature
      ..allowSwap = variants.allowSwap
      ..northernStyle = variants.northernStyle
      ..miceVariant = variants.miceVariant
      ..ordenNachalniku = variants.ordenNachalniku
      ..medalsCount = variants.medalsCount
      ..accumulateJobs = variants.accumulateJobs
      ..heroOfSovietUnion = variants.heroOfSovietUnion
      ..wrecker = variants.wreckerCard
      ..finalYearTrump = variants.finalYearTrump && variants.wreckerCard
      ..passCards = variants.passCards
      ..highestCardsRequisition = variants.highestCardsRequisition
      ..lottoRewards = variants.lottoRewards && variants.deckType != 36;
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
  int currentTrickWinner(Pointer<KCEngine> engine) =>
      _currentTrickWinner(engine);
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
  int exiledPlayer(Pointer<KCEngine> engine, int year, int index) =>
      _exiledPlayer(engine, year, index);
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
  List<EngineTransitionEvent> transitionEvents(Pointer<KCEngine> engine) => [
    for (var index = 0; index < _transitionEventCount(engine); index++)
      EngineTransitionEvent(
        kind: _transitionEventKind(engine, index),
        playerID: _transitionEventPlayer(engine, index),
        card: _cardValue(_transitionEventCard(engine, index)),
        fromZone: _transitionEventFromZone(engine, index),
        toZone: _transitionEventToZone(engine, index),
        fromOwner: _transitionEventFromOwner(engine, index),
        toOwner: _transitionEventToOwner(engine, index),
        targetSuit: _transitionEventTargetSuit(engine, index),
        trickWinnerID: _transitionEventTrickWinner(engine, index),
      ),
  ];
  bool swapCount(Pointer<KCEngine> engine, int playerID) =>
      _swapCount(engine, playerID);
  bool swapConfirmed(Pointer<KCEngine> engine, int playerID) =>
      _swapConfirmed(engine, playerID);
  bool passConfirmed(Pointer<KCEngine> engine, int playerID) =>
      _passConfirmed(engine, playerID);
  EngineCardValue finalYearTrumpCard(Pointer<KCEngine> engine) =>
      _cardValue(_finalYearTrumpCard(engine));

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
      kcActionPassCard => _applyPassCard(
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
      kcActionRevealReward => _applySuitAction(
        engine,
        action.kind,
        action.playerID,
        action.suit,
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
      kcActionPassCard => _applyPassCardManual(
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
      kcActionRevealReward => _applySuitActionManual(
        engine,
        action.kind,
        action.playerID,
        action.suit,
      ),
      _ => _applySimpleManual(engine, action.kind, action.playerID),
    };
  }

  int stepAutomatic(Pointer<KCEngine> engine) => _stepAutomatic(engine);

  CEngineActionValue? heuristicAction(Pointer<KCEngine> engine) {
    final arena = Arena();
    try {
      final selected = arena<KCActionNative>();
      if (!_heuristicAction(engine, selected)) {
        return null;
      }
      return _actionValue(selected.ref);
    } finally {
      arena.releaseAll();
    }
  }

  int stepPolicyAutomatic(
    Pointer<KCEngine> engine,
    KCPolicyModelBufferNative model,
  ) => _stepPolicyAutomatic(engine, model);

  CEngineActionValue? policyAction(
    Pointer<KCEngine> engine,
    KCPolicyModelBufferNative model, [
    Pointer<KCPolicyWorkspace>? workspace,
  ]) {
    final arena = Arena();
    try {
      final selected = arena<KCActionNative>();
      final ok = workspace == null
          ? _policyAction(engine, model, selected)
          : _policyActionWithWorkspace(engine, model, workspace, selected);
      if (!ok) {
        return null;
      }
      return _actionValue(selected.ref);
    } finally {
      arena.releaseAll();
    }
  }

  Pointer<KCPolicyWorkspace> allocPolicyWorkspace(
    KCPolicyModelBufferNative model,
  ) => _policyWorkspaceAlloc(model);

  void freePolicyWorkspace(Pointer<KCPolicyWorkspace> workspace) {
    _policyWorkspaceFree(workspace);
  }

  int applyAIAction(Pointer<KCEngine> engine, CEngineActionValue action) {
    final arena = Arena();
    try {
      final native = arena<KCActionNative>();
      _writeAction(native.ref, action);
      return _applyAIAction(engine, native.ref);
    } finally {
      arena.releaseAll();
    }
  }

  int applyPolicyAction(Pointer<KCEngine> engine, CEngineActionValue action) =>
      applyAIAction(engine, action);

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
    _engineInitWithControllersStepwise = _lib
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
        >('kc_engine_init_with_controllers_stepwise');
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
    _currentTrickWinner = _int0('kc_current_trick_winner');
    _currentTrickPlayer = _int1('kc_current_trick_player');
    _currentTrickCard = _card1('kc_current_trick_card');
    _lastTrickCount = _int0('kc_last_trick_count');
    _lastTrickPlayer = _int1('kc_last_trick_player');
    _lastTrickCard = _card1('kc_last_trick_card');
    _pendingAssignmentTarget = _int1('kc_pending_assignment_target');
    _exiledCount = _int1('kc_exiled_count');
    _exiledCard = _card2('kc_exiled_card');
    _exiledPlayer = _int2('kc_exiled_player');
    _requisitionEventCount = _int0('kc_requisition_event_count');
    _requisitionEventPlayer = _int1('kc_requisition_event_player');
    _requisitionEventSuit = _int1('kc_requisition_event_suit');
    _requisitionEventCard = _card1('kc_requisition_event_card');
    _requisitionEventMessageKind = _int1('kc_requisition_event_message_kind');
    _transitionEventCount = _int0('kc_transition_event_count');
    _transitionEventKind = _int1('kc_transition_event_kind');
    _transitionEventPlayer = _int1('kc_transition_event_player');
    _transitionEventCard = _card1('kc_transition_event_card');
    _transitionEventFromZone = _int1('kc_transition_event_from_zone');
    _transitionEventToZone = _int1('kc_transition_event_to_zone');
    _transitionEventFromOwner = _int1('kc_transition_event_from_owner');
    _transitionEventToOwner = _int1('kc_transition_event_to_owner');
    _transitionEventTargetSuit = _int1('kc_transition_event_target_suit');
    _transitionEventTrickWinner = _int1('kc_transition_event_trick_winner');
    _swapCount = _bool1('kc_swap_count');
    _swapConfirmed = _bool1('kc_swap_confirmed');
    _passConfirmed = _bool1('kc_pass_confirmed');
    _finalYearTrumpCard = _card0('kc_final_year_trump_card');
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
    _applyPassCard = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int)
        >('kc_engine_apply_pass_card');
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
    _applySuitAction = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int)
        >('kc_engine_apply_suit_action');
    _stepAutomatic = _int0('kc_engine_step_automatic');
    _heuristicAction = _lib
        .lookupFunction<
          Bool Function(Pointer<KCEngine>, Pointer<KCActionNative>),
          bool Function(Pointer<KCEngine>, Pointer<KCActionNative>)
        >('kc_engine_heuristic_action');
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
    _policyWorkspaceAlloc = _lib
        .lookupFunction<
          Pointer<KCPolicyWorkspace> Function(KCPolicyModelBufferNative),
          Pointer<KCPolicyWorkspace> Function(KCPolicyModelBufferNative)
        >('kc_policy_workspace_alloc');
    _policyWorkspaceFree = _lib
        .lookupFunction<
          Void Function(Pointer<KCPolicyWorkspace>),
          void Function(Pointer<KCPolicyWorkspace>)
        >('kc_policy_workspace_free');
    _policyActionWithWorkspace = _lib
        .lookupFunction<
          Bool Function(
            Pointer<KCEngine>,
            KCPolicyModelBufferNative,
            Pointer<KCPolicyWorkspace>,
            Pointer<KCActionNative>,
          ),
          bool Function(
            Pointer<KCEngine>,
            KCPolicyModelBufferNative,
            Pointer<KCPolicyWorkspace>,
            Pointer<KCActionNative>,
          )
        >('kc_engine_policy_action_with_workspace');
    _applyAIAction = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, KCActionNative),
          int Function(Pointer<KCEngine>, KCActionNative)
        >('kc_engine_apply_ai_action_stepwise');
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
    _applyPassCardManual = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int)
        >('kc_engine_apply_pass_card_manual');
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
    _applySuitActionManual = _lib
        .lookupFunction<
          Int32 Function(Pointer<KCEngine>, Int32, Int32, Int32),
          int Function(Pointer<KCEngine>, int, int, int)
        >('kc_engine_apply_suit_action_manual');
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

  KCCardNative Function(Pointer<KCEngine>) _card0(String name) {
    return _lib.lookupFunction<
      KCCardNative Function(Pointer<KCEngine>),
      KCCardNative Function(Pointer<KCEngine>)
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
        'app/native/macos/libkolkhoz_c_engine.dylib',
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

  @Int32()
  external int maxYears;

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

  @Bool()
  external bool finalYearTrump;

  @Bool()
  external bool passCards;

  @Bool()
  external bool highestCardsRequisition;

  @Bool()
  external bool lottoRewards;
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
