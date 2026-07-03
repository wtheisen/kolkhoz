import 'dart:ffi';

import 'package:flutter/foundation.dart';

import 'c_engine_action_codec.dart';
import 'c_engine_bridge.dart';
import 'game_constants.dart';
import 'game_ui_state.dart';
import 'render_model.dart';
import 'design_tokens.dart';
import 'table_view_projection.dart';

class LiveGameStore extends ChangeNotifier {
  LiveGameStore({KolkhozCEngineBridge? bridge})
    : bridge = bridge ?? KolkhozCEngineBridge() {
    newGame();
  }

  final KolkhozCEngineBridge bridge;

  DesignTokens tokens = defaultDesignTokens;
  GameUiState uiState = const GameUiState();
  List<KolkhozPlayerController> controllers = List.of(
    KolkhozPlayerController.defaultControllers,
  );
  TableViewModel? model;
  Pointer<KCEngine>? _engine;
  String? error;

  void newGame({
    KolkhozGameVariants variants = KolkhozGameVariants.kolkhoz,
    List<KolkhozPlayerController> controllers =
        KolkhozPlayerController.defaultControllers,
  }) {
    try {
      final oldEngine = _engine;
      if (oldEngine != null) {
        bridge.freeEngine(oldEngine);
      }
      final normalizedControllers = KolkhozPlayerController.normalized(
        controllers,
      );
      this.controllers = normalizedControllers;
      uiState = const GameUiState();
      _engine = bridge.newEngine(
        variants: variants,
        controllers: normalizedControllers,
      );
      error = null;
      _sync();
    } catch (exception) {
      error = '$exception';
      model = null;
      notifyListeners();
    }
  }

  void applyLegalAction(LegalAction action) {
    final engine = _engine;
    if (engine == null) {
      return;
    }
    final cAction = cEngineAction(action.engineAction);
    if (cAction == null) {
      return;
    }
    final result = bridge.apply(engine, cAction);
    if (result != 0) {
      error = 'Move rejected ($result)';
    } else {
      error = null;
      _clearSelectionAfter(action.kind);
    }
    _sync();
  }

  void setActivePanel(String panel) {
    uiState = uiState.activatePanel(panel);
    _sync();
  }

  void selectSwapHandCard(String cardID) {
    if (model?.table.phase != phaseSwap) {
      return;
    }
    uiState = uiState.selectSwapHandCard(cardID);
    _sync();
  }

  void selectPlotCard(String cardID, String zone) {
    if (model?.table.phase != phaseSwap) {
      return;
    }
    uiState = uiState.selectSwapPlotCard(cardID, zone);
    _sync();
  }

  void selectAssignmentCard(String cardID) {
    if (model?.table.phase != phaseAssignment) {
      return;
    }
    uiState = uiState.selectAssignmentCard(cardID);
    _sync();
  }

  void _clearSelectionAfter(String actionKind) {
    uiState = uiState.clearSelectionAfterAction(actionKind);
  }

  void _sync() {
    final engine = _engine;
    if (engine != null) {
      model = TableViewProjection(
        bridge: bridge,
        engine: engine,
        controllers: controllers,
        uiState: uiState,
      ).project();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    final engine = _engine;
    if (engine != null) {
      bridge.freeEngine(engine);
      _engine = null;
    }
    super.dispose();
  }
}
