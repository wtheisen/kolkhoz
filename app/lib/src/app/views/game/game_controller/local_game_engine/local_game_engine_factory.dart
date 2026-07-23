import 'dart:async';
import 'dart:io';

import 'package:kolkhoz_app/src/app/settings/animation_speed.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/game_ui_state.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_action_codec.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/c_engine_bridge.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/local_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/native_game_engine.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player_ai_heuristic.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player_ai_neural.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/players/player_human.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/policy_model.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/local_game_engine/saved_game_store.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

class LocalGameEngineBindings {
  const LocalGameEngineBindings({
    required this.players,
    required this.animationSpeed,
    required this.uiState,
    required this.setUiState,
    required this.revealedPlayerID,
    required this.setRevealedPlayerID,
    required this.lastSyncedPhase,
    required this.setLastSyncedPhase,
    required this.onGameUpdate,
    required this.onStateChanged,
    required this.onError,
    required this.onPersist,
  });

  final List<GamePlayer> Function() players;
  final GameAnimationSpeed Function() animationSpeed;
  final GameUiState Function() uiState;
  final void Function(GameUiState) setUiState;
  final int? Function() revealedPlayerID;
  final void Function(int?) setRevealedPlayerID;
  final String? Function() lastSyncedPhase;
  final void Function(String?) setLastSyncedPhase;
  final void Function(GameEngineUpdate) onGameUpdate;
  final void Function() onStateChanged;
  final void Function(String?) onError;
  final void Function() onPersist;
}

class RestoredLocalGame {
  const RestoredLocalGame({
    required this.engine,
    required this.players,
    required this.seed,
    required this.variants,
    required this.controllers,
  });

  final LocalGameEngine engine;
  final List<GamePlayer> players;
  final int seed;
  final KolkhozGameVariants variants;
  final List<KolkhozPlayerController> controllers;
}

class LocalGameEngineFactory {
  LocalGameEngineFactory({
    KolkhozCEngineBridge? bridge,
    KolkhozAutosaveStore? autosaveStore,
    KolkhozNativePolicyModel? mediumPolicy,
    Future<KolkhozNativePolicyModel>? mediumPolicyLoader,
    KolkhozNativePolicyModel? neuralPolicy,
    Future<KolkhozNativePolicyModel>? neuralPolicyLoader,
    this.autosaveEnabled = true,
  }) : _bridge = bridge ?? KolkhozCEngineBridge(),
       _autosaveStore = autosaveStore ?? KolkhozAutosaveStore.defaultStore(),
       _mediumPolicy = mediumPolicy,
       _mediumPolicyLoader = mediumPolicy == null
           ? mediumPolicyLoader ??
                 KolkhozNativePolicyModel.loadAsset(mediumNeuralPolicyAsset)
           : null,
       _neuralPolicy = neuralPolicy,
       _neuralPolicyLoader = neuralPolicy == null
           ? neuralPolicyLoader ??
                 KolkhozNativePolicyModel.loadAsset(defaultNeuralPolicyAsset)
           : null;

  final KolkhozCEngineBridge _bridge;
  final KolkhozAutosaveStore _autosaveStore;
  final bool autosaveEnabled;
  KolkhozNativePolicyModel? _mediumPolicy;
  Future<KolkhozNativePolicyModel>? _mediumPolicyLoader;
  KolkhozNativePolicyModel? _neuralPolicy;
  Future<KolkhozNativePolicyModel>? _neuralPolicyLoader;
  bool _mediumPolicyUnavailable = false;
  bool _neuralPolicyUnavailable = false;
  bool _disposed = false;

  Directory get dataDirectory => KolkhozAutosaveStore.defaultFile().parent;

  List<GamePlayer> createPlayers(List<KolkhozPlayerController> controllers) {
    final normalized = KolkhozPlayerController.normalized(controllers);
    return [
      for (final (seatID, controller) in normalized.indexed)
        switch (controller) {
          KolkhozPlayerController.human => HumanPlayer(seatID: seatID),
          KolkhozPlayerController.heuristicAI => HeuristicAIPlayer(
            seatID: seatID,
          ),
          KolkhozPlayerController.mediumAI => NeuralAIPlayer(
            seatID: seatID,
            controller: controller,
            model: () => _mediumPolicy,
            modelUnavailable: () => _mediumPolicyUnavailable,
          ),
          KolkhozPlayerController.neuralAI => NeuralAIPlayer(
            seatID: seatID,
            controller: controller,
            model: () => _neuralPolicy,
            modelUnavailable: () => _neuralPolicyUnavailable,
          ),
        },
    ];
  }

  LocalGameEngine create({
    required int seed,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
    required LocalGameEngineBindings bindings,
  }) => _wrap(
    NativeGameEngine(
      bridge: _bridge,
      seed: seed,
      variants: variants,
      controllers: controllers,
    ),
    bindings,
  );

  RestoredLocalGame? restore(LocalGameEngineBindings bindings) {
    if (!autosaveEnabled) return null;
    final payload = _autosaveStore.load();
    if (payload == null) return null;
    NativeGameEngine? nativeEngine;
    try {
      nativeEngine = NativeGameEngine(
        bridge: _bridge,
        seed: payload.seed,
        variants: payload.variants,
        controllers: payload.controllers,
      );
      for (final action in payload.actions) {
        final nativeAction = cEngineAction(action);
        if (nativeAction == null) {
          throw const FormatException('Saved action cannot be replayed');
        }
        final usesAI =
            nativeAction.playerID >= 0 &&
            nativeAction.playerID < payload.controllers.length &&
            payload.controllers[nativeAction.playerID] !=
                KolkhozPlayerController.human;
        final result = usesAI
            ? nativeEngine.applyAIAction(nativeAction)
            : nativeEngine.applyManual(nativeAction);
        if (result != 0) {
          throw FormatException('Saved action rejected ($result)');
        }
      }
      final engine = _wrap(
        nativeEngine,
        bindings,
        actionLog: payload.actions,
        gameLog: payload.gameLogActions.isEmpty
            ? payload.actions
            : payload.gameLogActions,
      );
      nativeEngine = null;
      return RestoredLocalGame(
        engine: engine,
        players: createPlayers(payload.controllers),
        seed: payload.seed,
        variants: payload.variants,
        controllers: payload.controllers,
      );
    } catch (_) {
      nativeEngine?.dispose();
      _autosaveStore.clear();
      return null;
    }
  }

  void save({
    required int seed,
    required KolkhozGameVariants variants,
    required List<KolkhozPlayerController> controllers,
    required LocalGameEngine engine,
  }) {
    if (!autosaveEnabled) return;
    _autosaveStore.save(
      KolkhozSavedGamePayload(
        seed: seed,
        variants: variants,
        controllers: controllers,
        actions: engine.actionLog,
        gameLogActions: engine.gameLog,
      ),
    );
  }

  void clearAutosave() => _autosaveStore.clear();

  void startPolicyLoading({
    required void Function() onReady,
    required void Function(String) onError,
  }) {
    _loadPolicy(
      loader: _mediumPolicyLoader,
      onLoaded: (policy) {
        _mediumPolicyLoader = null;
        _mediumPolicy = policy;
      },
      onUnavailable: () {
        _mediumPolicyLoader = null;
        _mediumPolicyUnavailable = true;
      },
      label: 'Medium AI',
      onReady: onReady,
      onError: onError,
    );
    _loadPolicy(
      loader: _neuralPolicyLoader,
      onLoaded: (policy) {
        _neuralPolicyLoader = null;
        _neuralPolicy = policy;
      },
      onUnavailable: () {
        _neuralPolicyLoader = null;
        _neuralPolicyUnavailable = true;
      },
      label: 'Neural AI',
      onReady: onReady,
      onError: onError,
    );
  }

  void _loadPolicy({
    required Future<KolkhozNativePolicyModel>? loader,
    required void Function(KolkhozNativePolicyModel) onLoaded,
    required void Function() onUnavailable,
    required String label,
    required void Function() onReady,
    required void Function(String) onError,
  }) {
    if (loader == null) return;
    unawaited(
      loader
          .then((policy) {
            if (_disposed) {
              policy.dispose();
              return;
            }
            onLoaded(policy);
            onReady();
          })
          .catchError((Object error) {
            onUnavailable();
            if (!_disposed) onError('$label unavailable ($error)');
          }),
    );
  }

  LocalGameEngine _wrap(
    NativeGameEngine engine,
    LocalGameEngineBindings bindings, {
    List<EngineAction> actionLog = const [],
    List<EngineAction> gameLog = const [],
  }) => LocalGameEngine(
    engine: engine,
    players: bindings.players,
    animationSpeed: bindings.animationSpeed,
    uiState: bindings.uiState,
    setUiState: bindings.setUiState,
    revealedPlayerID: bindings.revealedPlayerID,
    setRevealedPlayerID: bindings.setRevealedPlayerID,
    lastSyncedPhase: bindings.lastSyncedPhase,
    setLastSyncedPhase: bindings.setLastSyncedPhase,
    onGameUpdate: bindings.onGameUpdate,
    onStateChanged: bindings.onStateChanged,
    onError: bindings.onError,
    onPersist: bindings.onPersist,
    actionLog: actionLog,
    gameLog: gameLog,
  );

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _mediumPolicy?.dispose();
    _mediumPolicy = null;
    _neuralPolicy?.dispose();
    _neuralPolicy = null;
  }
}
