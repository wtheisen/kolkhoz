import 'dart:math' as math;
import 'dart:ui' show clampDouble;

import 'design_tokens.dart';
import 'game_constants.dart';
import 'render_model.dart';

const jobsTileSpacingWidthFactor = 0.016;
const jobsTileSpacingMin = 6.0;
const jobsTileSpacingMax = 10.0;
const jobsTileHeightFactor = 0.98;
const jobsTilePadding = 8.0;
const jobsTileHeaderSpacing = 8.0;
const jobsTileContentGap = 7.0;
const jobsTileEmptyPromptMinHeight = 42.0;

List<Job> jobsInDisplayOrder(List<Job> jobs) {
  final jobsBySuit = {for (final job in jobs) job.suit: job};
  return displaySuitOrder
      .map((suit) => jobsBySuit[suit] ?? emptyVisualJob(suit))
      .toList(growable: false);
}

Job emptyVisualJob(String suit) {
  return Job(
    suit: suit,
    hours: 0,
    requiredHours: jobRequiredHours,
    claimed: false,
    reward: null,
    assignedCards: const [],
    validAssignmentTarget: false,
    highlighted: false,
  );
}

double jobsTileSpacing(double width) {
  return clampDouble(
    width * jobsTileSpacingWidthFactor,
    jobsTileSpacingMin,
    jobsTileSpacingMax,
  );
}

double jobsTileHeight({
  required double availableHeight,
  required bool assignmentPhase,
  required JobsLayoutTokens tokens,
}) {
  return math.max(
    assignmentPhase
        ? tokens.assignmentMinTileHeight
        : tokens.overviewMinTileHeight,
    availableHeight * jobsTileHeightFactor,
  );
}
