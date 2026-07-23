import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'card_motion_plan.dart';

export 'card_motion_geometry.dart';

/// Publishes card and semantic-anchor geometry for one rendered board frame.
class CardMotionScope extends InheritedWidget {
  const CardMotionScope({
    required this.controller,
    required this.frame,
    required this.rootKey,
    required this.activeCardIDs,
    required super.child,
    super.key,
  });

  final CardMotionController controller;
  final int frame;
  final GlobalKey rootKey;
  final Set<String> activeCardIDs;

  static CardMotionScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<CardMotionScope>();
  }

  @override
  bool updateShouldNotify(CardMotionScope oldWidget) {
    return oldWidget.frame != frame ||
        oldWidget.activeCardIDs.length != activeCardIDs.length ||
        !oldWidget.activeCardIDs.containsAll(activeCardIDs);
  }
}

/// Frame-scoped geometry registry shared by motion-tracked widgets.
class CardMotionController {
  int _frame = 0;
  Map<MotionAnchor, Rect> _previousRects = {};
  final Map<MotionAnchor, CardMotionRect> _currentRects = {};
  final ValueNotifier<JobCardArrival?> jobCardArrival = ValueNotifier(null);

  Map<MotionAnchor, Rect> get previousRects => _previousRects;

  Map<MotionAnchor, Rect> get currentRects {
    return {
      for (final entry in _currentRects.entries)
        if (entry.value.frame == _frame) entry.key: entry.value.rect,
    };
  }

  int beginFrame() => ++_frame;

  void recordJobCardArrival(JobCardArrival arrival) {
    jobCardArrival.value = arrival;
  }

  void record({
    required int frame,
    required MotionAnchor anchor,
    required Rect rect,
  }) {
    if (frame == _frame) {
      _currentRects[anchor] = CardMotionRect(frame: frame, rect: rect);
    }
  }

  void commitFrame() {
    _previousRects = {..._previousRects, ...currentRects};
  }

  void dispose() {
    jobCardArrival.dispose();
  }
}

class CardMotionRect {
  const CardMotionRect({required this.frame, required this.rect});

  final int frame;
  final Rect rect;
}

class MotionTrackedCard extends StatefulWidget {
  const MotionTrackedCard({
    required this.card,
    required this.child,
    this.compositeWhenVisible = true,
    super.key,
  });

  final TableCard card;
  final Widget child;
  final bool compositeWhenVisible;

  @override
  State<MotionTrackedCard> createState() => _MotionTrackedCardState();
}

class MotionTrackedRegion extends StatefulWidget {
  const MotionTrackedRegion({
    required this.motionKey,
    required this.child,
    super.key,
  });

  final MotionAnchor motionKey;
  final Widget child;

  @override
  State<MotionTrackedRegion> createState() => _MotionTrackedRegionState();
}

class _MotionTrackedRegionState extends State<MotionTrackedRegion> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    _recordGeometry(context, key: _key, anchor: widget.motionKey);
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class _MotionTrackedCardState extends State<MotionTrackedCard> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    _recordGeometry(
      context,
      key: _key,
      anchor: MotionAnchor.card(widget.card.id),
    );
    final scope = CardMotionScope.maybeOf(context);
    final hidden = scope?.activeCardIDs.contains(widget.card.id) ?? false;
    if (!hidden && !widget.compositeWhenVisible) {
      return KeyedSubtree(key: _key, child: widget.child);
    }
    return Opacity(key: _key, opacity: hidden ? 0 : 1, child: widget.child);
  }
}

void _recordGeometry(
  BuildContext context, {
  required GlobalKey key,
  required MotionAnchor anchor,
}) {
  final scope = CardMotionScope.maybeOf(context);
  if (scope == null) {
    return;
  }
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final root = scope.rootKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || root == null || !box.attached || !root.attached) {
      return;
    }
    scope.controller.record(
      frame: scope.frame,
      anchor: anchor,
      rect: transformedPaintRect(box, root),
    );
  });
}

Rect transformedPaintRect(RenderBox box, RenderBox root) {
  final topLeft = box.localToGlobal(Offset.zero, ancestor: root);
  final topRight = box.localToGlobal(Offset(box.size.width, 0), ancestor: root);
  final bottomLeft = box.localToGlobal(
    Offset(0, box.size.height),
    ancestor: root,
  );
  final bottomRight = box.localToGlobal(
    box.size.bottomRight(Offset.zero),
    ancestor: root,
  );
  return Rect.fromLTRB(
    math.min(
      topLeft.dx,
      math.min(topRight.dx, math.min(bottomLeft.dx, bottomRight.dx)),
    ),
    math.min(
      topLeft.dy,
      math.min(topRight.dy, math.min(bottomLeft.dy, bottomRight.dy)),
    ),
    math.max(
      topLeft.dx,
      math.max(topRight.dx, math.max(bottomLeft.dx, bottomRight.dx)),
    ),
    math.max(
      topLeft.dy,
      math.max(topRight.dy, math.max(bottomLeft.dy, bottomRight.dy)),
    ),
  );
}
