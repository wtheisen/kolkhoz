import 'package:flutter/widgets.dart';

class BrigadeFieldsScope extends InheritedWidget {
  const BrigadeFieldsScope({
    required this.verticalPage,
    required this.transitionProgress,
    required this.focusedSurfaceID,
    required this.focusProgress,
    required this.onFocusSurface,
    required super.child,
    super.key,
  });

  final int verticalPage;
  final double? transitionProgress;
  final String? focusedSurfaceID;
  final double focusProgress;
  final ValueChanged<String?> onFocusSurface;

  static int verticalPageOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
          ?.verticalPage ??
      0;

  static double? transitionProgressOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
      ?.transitionProgress;

  static double cameraPositionOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>();
    return scope?.transitionProgress ?? scope?.verticalPage.toDouble() ?? 0;
  }

  static String? focusedSurfaceOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
      ?.focusedSurfaceID;

  static double focusProgressOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
          ?.focusProgress ??
      0;

  static ValueChanged<String?>? focusSurfaceHandlerOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<BrigadeFieldsScope>()
          ?.onFocusSurface;

  @override
  bool updateShouldNotify(BrigadeFieldsScope oldWidget) =>
      verticalPage != oldWidget.verticalPage ||
      transitionProgress != oldWidget.transitionProgress ||
      focusedSurfaceID != oldWidget.focusedSurfaceID ||
      focusProgress != oldWidget.focusProgress;
}
