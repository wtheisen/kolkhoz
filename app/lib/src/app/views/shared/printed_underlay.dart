import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
import 'package:kolkhoz_app/src/app/views/shared/chrome_button.dart';

const ledgerNeutralUnderlay = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/underlays/ledger-neutral.png',
);
const ledgerPrimaryUnderlay = ArtAssetRef(
  fieldPlanPath: 'assets/art/field_plan/ledger/underlays/ledger-primary.png',
);
const fieldPlanLightPaperTexture =
    'assets/art/field_plan/shared/textures/paper-light.png';
const _fieldPlanNineSlice = ChromeNineSliceConfig(
  left: 32,
  top: 32,
  right: 32,
  bottom: 32,
  tileSampleSize: 64,
);

enum PrintedUnderlayTone { neutral, primary, disabled }

class PrintedUnderlay extends StatelessWidget {
  const PrintedUnderlay({
    required this.child,
    this.tone = PrintedUnderlayTone.neutral,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    this.focused = false,
    super.key,
  });

  final Widget child;
  final PrintedUnderlayTone tone;
  final EdgeInsetsGeometry padding;
  final bool focused;

  @override
  Widget build(BuildContext context) {
    final primary = tone == PrintedUnderlayTone.primary;
    Widget underlay = _PrintedUnderlayBackground(
      asset: primary ? ledgerPrimaryUnderlay : ledgerNeutralUnderlay,
    );
    if (tone == PrintedUnderlayTone.disabled) {
      underlay = Opacity(opacity: 0.46, child: underlay);
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        underlay,
        if (focused)
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0xffa33a28), width: 3),
                ),
              ),
            ),
          ),
        Padding(padding: padding, child: child),
      ],
    );
  }
}

class _PrintedUnderlayBackground extends StatelessWidget {
  const _PrintedUnderlayBackground({required this.asset});

  final ArtAssetRef asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.Image>(
      future: ChromeImageCache.load(context, asset.fieldPlanPath),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return const SizedBox.expand();
        }
        return CustomPaint(
          painter: ChromeNineSlicePainter(
            image: image,
            config: _fieldPlanNineSlice,
            maxScale: 1,
          ),
        );
      },
    );
  }
}

class PrintedPaperSurface extends StatelessWidget {
  const PrintedPaperSurface({
    required this.child,
    this.color = const Color(0xffe7d4a5),
    this.textureOpacity = 0.32,
    super.key,
  });

  final Widget child;
  final Color color;
  final double textureOpacity;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: color),
        IgnorePointer(
          child: Opacity(
            opacity: textureOpacity,
            child: Image.asset(
              fieldPlanLightPaperTexture,
              alignment: Alignment.topLeft,
              fit: BoxFit.none,
              repeat: ImageRepeat.repeat,
              filterQuality: FilterQuality.medium,
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class PrintedSelectionStamp extends StatelessWidget {
  const PrintedSelectionStamp({
    this.size = 30,
    this.color = const Color(0xffa33a28),
    super.key,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _SelectionStampPainter(color)),
    );
  }
}

class _SelectionStampPainter extends CustomPainter {
  const _SelectionStampPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.09
      ..strokeCap = StrokeCap.square;
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.shortestSide * 0.43,
      paint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.24, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.7)
        ..lineTo(size.width * 0.77, size.height * 0.3),
      paint,
    );
  }

  @override
  bool shouldRepaint(_SelectionStampPainter oldDelegate) {
    return color != oldDelegate.color;
  }
}
