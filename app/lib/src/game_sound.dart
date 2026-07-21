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
    actionSubmitAssignments => GameSoundCue.assignment,
    _ => null,
  };
}

GameSoundCue? gameSoundCueWithVoiceOverride(
  GameSoundCue? cue,
  String? voiceAsset,
) {
  return cue == GameSoundCue.cardPlay && voiceAsset != null ? null : cue;
}

List<String> assignmentWorkAssetsForTransition({
  required TableViewModel? previous,
  required int previousActionCount,
  required List<EngineAction> actions,
}) {
  if (previous == null || actions.length <= previousActionCount) {
    return const [];
  }
  final action = actions.last;
  final targetSuit = action.targetSuit;
  if (action.kind != actionAssign || targetSuit == null) {
    return const [];
  }
  final assets = <String>['audio/assignment_$targetSuit.wav'];
  if (action.card?.suit == wreckerSuit) {
    assets.add('audio/assignment_saboteur.wav');
  }
  return assets;
}

String? faceCardVoiceAssetForTransition({
  required TableViewModel? previous,
  required TableViewModel next,
  required int previousActionCount,
  required List<EngineAction> actions,
}) {
  if (previous == null || actions.length <= previousActionCount) {
    return null;
  }
  final action = actions.last;
  final card = action.card;
  if (action.kind != actionPlayCard || card == null) {
    return null;
  }
  if (card.suit == wreckerSuit) {
    final variant = (next.table.year + action.playerID).isEven
        ? 'wrench'
        : 'any-crop';
    return 'audio/voice_lines/saboteur-$variant.wav';
  }
  final rank = switch (card.value) {
    11 => 'jack',
    12 => 'queen',
    13 => 'king',
    _ => null,
  };
  if (rank == null) {
    return null;
  }
  final playedCard = [...next.table.trick.plays, ...next.table.lastTrick.plays]
      .where(
        (play) => play.seatID == action.playerID && play.card.id == card.id,
      )
      .firstOrNull;
  final prefix = playedCard?.card.nomenclature ?? false ? 'nomenklatura-' : '';
  return 'audio/voice_lines/$prefix$rank-${card.suit}.wav';
}

class GameSoundController {
  GameSoundController({this.enabled = true});

  bool enabled;
  final List<AudioPlayer> _activePlayers = [];

  Future<void> play(GameSoundCue? cue) async {
    if (cue == null) {
      return;
    }
    await playAsset(cue.assetPath, volume: cue.volume);
  }

  Future<void> playAsset(String? assetPath, {double volume = 0.85}) async {
    if (!enabled || assetPath == null) {
      return;
    }
    final player = AudioPlayer();
    _activePlayers.add(player);
    try {
      await player.play(AssetSource(assetPath), volume: volume);
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
