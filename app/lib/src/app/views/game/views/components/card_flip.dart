import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:kolkhoz_app/src/app/settings/game_motion.dart';

class CardFlip extends StatefulWidget {
  const CardFlip({
    required this.showFront,
    required this.front,
    required this.back,
    this.frontKey,
    this.backKey,
    this.onCompleted,
    super.key,
  });

  final bool showFront;
  final Widget front;
  final Widget back;
  final Key? frontKey;
  final Key? backKey;
  final VoidCallback? onCompleted;

  @override
  State<CardFlip> createState() => _CardFlipState();
}

class _CardFlipState extends State<CardFlip>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  bool frontCompletionReported = false;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      value: widget.showFront ? 1 : 0,
    )..addStatusListener(_handleStatus);
    if (widget.showFront) {
      _scheduleFrontCompletion();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    controller.duration = GameMotion.of(context).rewardFlip;
  }

  @override
  void didUpdateWidget(CardFlip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showFront == widget.showFront) {
      return;
    }
    if (!widget.showFront) {
      frontCompletionReported = false;
    }
    controller
      ..duration = GameMotion.of(context).rewardFlip
      ..animateTo(widget.showFront ? 1 : 0);
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.showFront) {
      _scheduleFrontCompletion();
    }
  }

  void _scheduleFrontCompletion() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.showFront || frontCompletionReported) {
        return;
      }
      frontCompletionReported = true;
      widget.onCompleted?.call();
    });
  }

  @override
  void dispose() {
    controller.removeStatusListener(_handleStatus);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final progress = GameMotion.rewardFlipCurve.transform(controller.value);
        final showingFront = progress >= 0.5;
        final transform = Matrix4.identity()
          ..setEntry(3, 2, 0.002)
          ..rotateY(math.pi * progress);
        return Transform(
          key: showingFront ? widget.frontKey : widget.backKey,
          alignment: Alignment.center,
          transform: transform,
          child: showingFront
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationY(math.pi),
                  child: widget.front,
                )
              : widget.back,
        );
      },
    );
  }
}

class InteractiveCardFlip extends StatefulWidget {
  const InteractiveCardFlip({
    required this.front,
    required this.back,
    required this.concealedLabel,
    required this.revealedLabel,
    this.frontKey,
    this.backKey,
    this.onTap,
    super.key,
  });

  final Widget front;
  final Widget back;
  final String concealedLabel;
  final String revealedLabel;
  final Key? frontKey;
  final Key? backKey;
  final VoidCallback? onTap;

  @override
  State<InteractiveCardFlip> createState() => _InteractiveCardFlipState();
}

class _InteractiveCardFlipState extends State<InteractiveCardFlip> {
  bool hovered = false;
  bool pinned = false;

  bool get showingFront => hovered || pinned;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: showingFront ? widget.revealedLabel : widget.concealedLabel,
      child: MouseRegion(
        onEnter: (_) => setState(() => hovered = true),
        onExit: (_) => setState(() => hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => pinned = !pinned);
            widget.onTap?.call();
          },
          child: CardFlip(
            showFront: showingFront,
            front: widget.front,
            back: widget.back,
            frontKey: widget.frontKey,
            backKey: widget.backKey,
          ),
        ),
      ),
    );
  }
}
