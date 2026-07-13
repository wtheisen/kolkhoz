import 'package:flutter/material.dart';

import 'field_plan_assets.dart';

const _fieldPlanSignAssetAspectRatio = 1413 / 846;

/// A printed field sign with optional posts extending below its face.
///
/// The sign owns only its physical presentation so callers can supply player
/// details, instructions, or any other compact content.
class FieldPlanSign extends StatelessWidget {
  const FieldPlanSign({
    required this.child,
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.padding = const EdgeInsets.all(2),
    this.showPosts = true,
    super.key,
  });

  final Widget child;
  final Color borderColor;
  final double borderWidth;
  final EdgeInsetsGeometry padding;
  final bool showPosts;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final imageHeight =
            constraints.maxWidth / _fieldPlanSignAssetAspectRatio;
        return Stack(
          clipBehavior: showPosts ? Clip.none : Clip.hardEdge,
          fit: StackFit.passthrough,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: imageHeight,
              child: Image.asset(
                fieldPlanSignAssetPath,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.high,
                isAntiAlias: true,
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: borderColor, width: borderWidth),
              ),
              child: Padding(padding: padding, child: child),
            ),
          ],
        );
      },
    );
  }
}
