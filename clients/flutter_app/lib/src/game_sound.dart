import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

import 'game_constants.dart';
import 'render_model.dart';

enum GameSoundCue {
  cardPlay('audio/card_play.wav', 0.55),
  trickWin('audio/trick_win.wav', 0.65),
  assignment('audio/assignment.wav', 0.5),
  requisition('audio/requisition.wav', 0.65),
  yearStart('audio/year_start.wav', 0.55),
  gameOver('audio/game_over.wav', 0.7);

  const GameSoundCue(this.assetPath, this.volume);

  final String assetPath;
  final double volume;
}

GameSoundCue? gameSoundCueForTransition({
  required TableViewModel? previous,
  required TableViewModel next,
  required int previousActionCount,
  required List<EngineAction> actions,
}) {
  if (previous == null || actions.length < previousActionCount) {
    return null;
  }
  if (next.table.phase == phaseGameOver &&
      previous.table.phase != phaseGameOver) {
    return GameSoundCue.gameOver;
  }
  if (next.table.year > previous.table.year) {
    return GameSoundCue.yearStart;
  }
  if (next.table.phase == phaseRequisition &&
      previous.table.phase != phaseRequisition) {
    return GameSoundCue.requisition;
  }
  if (next.table.phase == phaseAssignment &&
      previous.table.phase != phaseAssignment) {
    return GameSoundCue.trickWin;
  }
  if (actions.length == previousActionCount) {
    return null;
  }
  return switch (actions.last.kind) {
    actionPlayCard => GameSoundCue.cardPlay,
    actionAssign || actionSubmitAssignments => GameSoundCue.assignment,
    _ => null,
  };
}

class GameSoundController {
  GameSoundController({this.enabled = true});

  bool enabled;
  final List<AudioPlayer> _activePlayers = [];

  Future<void> play(GameSoundCue? cue) async {
    if (!enabled || cue == null) {
      return;
    }
    final player = AudioPlayer();
    _activePlayers.add(player);
    try {
      await player.play(AssetSource(cue.assetPath), volume: cue.volume);
      unawaited(player.onPlayerComplete.first.then((_) => _release(player)));
    } catch (_) {
      await _release(player);
    }
  }

  Future<void> _release(AudioPlayer player) async {
    _activePlayers.remove(player);
    await player.dispose();
  }

  Future<void> dispose() async {
    final players = List<AudioPlayer>.of(_activePlayers);
    _activePlayers.clear();
    await Future.wait(players.map((player) => player.dispose()));
  }
}
