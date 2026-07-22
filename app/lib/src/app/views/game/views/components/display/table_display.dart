import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/app_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

int inferredWinnerID(List<Score> scoreboard) {
  if (scoreboard.isEmpty) {
    return -1;
  }
  var winner = scoreboard.first;
  for (final score in scoreboard.skip(1)) {
    if (finalScoreValue(score) > finalScoreValue(winner)) {
      winner = score;
    }
  }
  return winner.seatID;
}

int finalScoreForSeat(List<Score> scoreboard, int seatID) {
  for (final score in scoreboard) {
    if (score.seatID == seatID) {
      return finalScoreValue(score);
    }
  }
  return 0;
}

int finalScoreValue(Score score) {
  return score.finalScore ?? score.visibleScore;
}

Seat viewerSeat(TableViewModel model) {
  final viewerID = model.viewer.seatID;
  if (viewerID == null) {
    return model.table.seats.first;
  }
  return model.table.seats.firstWhere(
    (seat) => seat.id == viewerID,
    orElse: () => model.table.seats.first,
  );
}

Seat localSeat(TableViewModel model) {
  final currentPlayer = seatByID(model, model.table.currentPlayerID);
  if (currentPlayer != null && isLocalHumanSeat(currentPlayer)) {
    return currentPlayer;
  }

  final assignmentWinnerID = model.table.phase == phaseAssignment
      ? model.table.lastTrick.winnerSeatID
      : null;
  if (assignmentWinnerID != null) {
    final assignmentWinner = seatByID(model, assignmentWinnerID);
    if (assignmentWinner != null && isLocalHumanSeat(assignmentWinner)) {
      return assignmentWinner;
    }
  }

  for (final seat in model.table.seats) {
    if (isLocalHumanSeat(seat)) {
      return seat;
    }
  }

  return viewerSeat(model);
}

Seat? seatByID(TableViewModel model, int seatID) {
  for (final seat in model.table.seats) {
    if (seat.id == seatID) {
      return seat;
    }
  }
  return null;
}

bool isLocalHumanSeat(Seat seat) {
  return seat.controller == controllerHuman;
}

bool isHumanControlledSeat(Seat seat) {
  return seat.controller == controllerHuman ||
      seat.controller == controllerRemoteHuman;
}

String seatDisplayName(Seat seat, {KolkhozLanguage? language}) {
  if (seat.isViewer) {
    return (language ?? KolkhozLanguage.en).t(KolkhozText.tabledisplayYou);
  }
  final firstName = seat.name.split(' ').first;
  return firstName.length > 6 ? '${firstName.substring(0, 6)}.' : firstName;
}
