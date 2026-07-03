import 'dart:math' as math;

const northColumnVerticalInset = 24.0;
const northColumnMinHeight = 120.0;
const northHeaderHeight = 34.0;
const northCardScrollMinHeight = 70.0;
const northCardScrollReservedHeight = 16.0;
const northCardStackBottomPadding = 20.0;
const northCardStackSpacing = -58.0;
const northEmptyYearMinHeight = 80.0;
const northEmptyYearSpacing = 32.0;

double northCardScrollHeight({
  required double columnHeight,
  required double headerHeight,
}) {
  return math.max(
    northCardScrollMinHeight,
    columnHeight - headerHeight - northCardScrollReservedHeight,
  );
}
