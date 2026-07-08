import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'pixel_text.dart';

const kolkhozFontStyle = TextStyle(fontFamily: 'Handjet');

const commandButtonProminentWidth = commandButtonProminentMinHeight * 4;
const commandButtonProminentMinHeight = 58.0;
const commandButtonProminentHorizontalPadding = 42.0;
const commandButtonProminentTopPadding = 14.0;
const commandButtonProminentBottomPadding = 10.0;
const commandButtonProminentOuterShadowOpacity = 0.34;
const commandButtonProminentOuterShadowRadius = 8.0;
const commandButtonProminentOuterShadowYOffset = 3.0;
const chromeButtonPrimaryAsset = 'ios_resources/ui-nav-button-active.png';
const chromeButtonSecondaryAsset = 'ios_resources/ui-nav-button-inactive.png';
const chromeButtonPrimaryCurrentAsset =
    'ios_resources/ui-nav-button-active-current.png';
const chromeButtonSecondaryCurrentAsset =
    'ios_resources/ui-nav-button-inactive-current.png';
const chromeIconMutedOpacity = 0.82;
const chromeIconMutedSaturationMatrix = <double>[
  0.76378,
  0.21456,
  0.02166,
  0,
  0,
  0.06378,
  0.91456,
  0.02166,
  0,
  0,
  0.06378,
  0.21456,
  0.72166,
  0,
  0,
  0,
  0,
  0,
  1,
  0,
];

class ChromeScaledLabel extends StatelessWidget {
  const ChromeScaledLabel(
    this.text, {
    required this.color,
    required this.size,
    this.variant = PixelTextVariant.heavy,
    this.textAlign = TextAlign.center,
    this.uppercase = true,
    super.key,
  });

  final String text;
  final Color color;
  final PixelTextSize size;
  final PixelTextVariant variant;
  final TextAlign textAlign;
  final bool uppercase;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: PixelText(
        uppercase ? text.toUpperCase() : text,
        size: size,
        variant: variant,
        color: color,
        textAlign: textAlign,
      ),
    );
  }
}

class ChromeAssetIcon extends StatelessWidget {
  const ChromeAssetIcon({
    required this.asset,
    required this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.opacity = 1,
    this.muted = false,
    this.errorBuilder,
    super.key,
  });

  final String asset;
  final double width;
  final double? height;
  final BoxFit fit;
  final double opacity;
  final bool muted;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      width: width,
      height: height ?? width,
      fit: fit,
      filterQuality: FilterQuality.none,
      errorBuilder: errorBuilder,
    );
    final icon = muted
        ? ColorFiltered(
            colorFilter: const ColorFilter.matrix(
              chromeIconMutedSaturationMatrix,
            ),
            child: image,
          )
        : image;
    return Opacity(
      opacity: muted ? chromeIconMutedOpacity : opacity,
      child: icon,
    );
  }
}

class ChromeButtonBackground extends StatelessWidget {
  const ChromeButtonBackground({required this.asset, super.key});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final config = chromeButtonNineSliceConfig(asset);
    if (config == null) {
      return Image.asset(
        asset,
        fit: BoxFit.fill,
        filterQuality: FilterQuality.none,
      );
    }
    return FutureBuilder<ui.Image>(
      future: _ChromeImageCache.load(context, asset),
      builder: (context, snapshot) {
        final image = snapshot.data;
        if (image == null) {
          return Image.asset(
            asset,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.none,
          );
        }
        return CustomPaint(
          painter: _ChromeNineSlicePainter(image: image, config: config),
        );
      },
    );
  }
}

class ChromeNineSliceConfig {
  const ChromeNineSliceConfig({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
    this.tileSampleSize = 48,
  });

  final double left;
  final double top;
  final double right;
  final double bottom;
  final double tileSampleSize;
}

ChromeNineSliceConfig? chromeButtonNineSliceConfig(String asset) {
  return switch (asset) {
    chromeButtonSecondaryAsset => const ChromeNineSliceConfig(
      left: 96,
      top: 96,
      right: 96,
      bottom: 96,
    ),
    chromeButtonPrimaryAsset => const ChromeNineSliceConfig(
      left: 96,
      top: 96,
      right: 96,
      bottom: 96,
    ),
    _ => null,
  };
}

class _ChromeImageCache {
  static final Map<String, Future<ui.Image>> _images = {};

  static Future<ui.Image> load(BuildContext context, String asset) {
    return _images.putIfAbsent(asset, () async {
      final bytes = await DefaultAssetBundle.of(context).load(asset);
      final codec = await ui.instantiateImageCodec(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
      final frame = await codec.getNextFrame();
      return frame.image;
    });
  }
}

class _ChromeNineSlicePainter extends CustomPainter {
  const _ChromeNineSlicePainter({required this.image, required this.config});

  final ui.Image image;
  final ChromeNineSliceConfig config;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) {
      return;
    }
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final scale = math.min(size.width / imageWidth, size.height / imageHeight);
    final left = _scaledInset(config.left, scale, size.width);
    final right = _scaledInset(config.right, scale, size.width - left);
    final top = _scaledInset(config.top, scale, size.height);
    final bottom = _scaledInset(config.bottom, scale, size.height - top);

    final srcLeft = config.left;
    final srcRight = imageWidth - config.right;
    final srcTop = config.top;
    final srcBottom = imageHeight - config.bottom;
    final dstLeft = left;
    final dstRight = size.width - right;
    final dstTop = top;
    final dstBottom = size.height - bottom;

    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false;

    _drawPatch(
      canvas,
      paint,
      Rect.fromLTWH(0, 0, srcLeft, srcTop),
      Rect.fromLTWH(0, 0, dstLeft, dstTop),
    );
    _drawPatch(
      canvas,
      paint,
      Rect.fromLTWH(srcRight, 0, config.right, srcTop),
      Rect.fromLTWH(dstRight, 0, right, dstTop),
    );
    _drawPatch(
      canvas,
      paint,
      Rect.fromLTWH(0, srcBottom, srcLeft, config.bottom),
      Rect.fromLTWH(0, dstBottom, dstLeft, bottom),
    );
    _drawPatch(
      canvas,
      paint,
      Rect.fromLTWH(srcRight, srcBottom, config.right, config.bottom),
      Rect.fromLTWH(dstRight, dstBottom, right, bottom),
    );

    _tilePatch(
      canvas,
      paint,
      _horizontalTileSource(imageWidth: imageWidth, top: 0, bottom: srcTop),
      Rect.fromLTRB(dstLeft, 0, dstRight, dstTop),
      scale,
    );
    _tilePatch(
      canvas,
      paint,
      _horizontalTileSource(
        imageWidth: imageWidth,
        top: srcBottom,
        bottom: imageHeight,
      ),
      Rect.fromLTRB(dstLeft, dstBottom, dstRight, size.height),
      scale,
    );
    _tilePatch(
      canvas,
      paint,
      _verticalTileSource(imageHeight: imageHeight, left: 0, right: srcLeft),
      Rect.fromLTRB(0, dstTop, dstLeft, dstBottom),
      scale,
    );
    _tilePatch(
      canvas,
      paint,
      _verticalTileSource(
        imageHeight: imageHeight,
        left: srcRight,
        right: imageWidth,
      ),
      Rect.fromLTRB(dstRight, dstTop, size.width, dstBottom),
      scale,
    );
    _tilePatch(
      canvas,
      paint,
      _centerTileSource(imageWidth: imageWidth, imageHeight: imageHeight),
      Rect.fromLTRB(dstLeft, dstTop, dstRight, dstBottom),
      scale,
    );
  }

  double _scaledInset(double sourceInset, double scale, double available) {
    if (available <= 2) {
      return math.max(0, available / 2);
    }
    return math.min(sourceInset * scale, math.max(1, (available / 2) - 1));
  }

  void _drawPatch(Canvas canvas, Paint paint, Rect source, Rect destination) {
    if (source.isEmpty || destination.isEmpty) {
      return;
    }
    canvas.drawImageRect(image, source, destination, paint);
  }

  void _tilePatch(
    Canvas canvas,
    Paint paint,
    Rect source,
    Rect destination,
    double scale,
  ) {
    if (source.isEmpty || destination.isEmpty) {
      return;
    }
    final tileWidth = math.max(1.0, source.width * scale);
    final tileHeight = math.max(1.0, source.height * scale);
    for (var y = destination.top; y < destination.bottom; y += tileHeight) {
      final drawHeight = math.min(tileHeight, destination.bottom - y);
      final sourceHeight = source.height * (drawHeight / tileHeight);
      for (var x = destination.left; x < destination.right; x += tileWidth) {
        final drawWidth = math.min(tileWidth, destination.right - x);
        final sourceWidth = source.width * (drawWidth / tileWidth);
        _drawPatch(
          canvas,
          paint,
          Rect.fromLTWH(source.left, source.top, sourceWidth, sourceHeight),
          Rect.fromLTWH(x, y, drawWidth, drawHeight),
        );
      }
    }
  }

  Rect _horizontalTileSource({
    required double imageWidth,
    required double top,
    required double bottom,
  }) {
    final left = ((imageWidth - config.tileSampleSize) / 2).roundToDouble();
    return Rect.fromLTRB(
      left,
      top,
      math.min(imageWidth, left + config.tileSampleSize),
      bottom,
    );
  }

  Rect _verticalTileSource({
    required double imageHeight,
    required double left,
    required double right,
  }) {
    final top = ((imageHeight - config.tileSampleSize) / 2).roundToDouble();
    return Rect.fromLTRB(
      left,
      top,
      right,
      math.min(imageHeight, top + config.tileSampleSize),
    );
  }

  Rect _centerTileSource({
    required double imageWidth,
    required double imageHeight,
  }) {
    final left = ((imageWidth - config.tileSampleSize) / 2).roundToDouble();
    final top = ((imageHeight - config.tileSampleSize) / 2).roundToDouble();
    return Rect.fromLTWH(
      left,
      top,
      math.min(config.tileSampleSize, imageWidth - left),
      math.min(config.tileSampleSize, imageHeight - top),
    );
  }

  @override
  bool shouldRepaint(_ChromeNineSlicePainter oldDelegate) {
    return image != oldDelegate.image || config != oldDelegate.config;
  }
}

class ChromeAssetButton extends StatelessWidget {
  const ChromeAssetButton({
    required this.label,
    required this.tokens,
    required this.textColor,
    required this.textSize,
    this.backgroundAsset,
    this.backgroundColor,
    this.border,
    this.borderRadius,
    this.onPressed,
    this.iconAsset,
    this.iconSize = 20,
    this.iconOpacity = 1,
    this.iconMuted = false,
    this.width,
    this.height,
    this.padding,
    this.boxShadow,
    this.surfaceKey,
    this.uppercase = true,
    this.enabled = true,
    this.disabledOpacity = 0.45,
    this.spacing = 8,
    this.expandLabel = true,
    this.commandProminent = false,
    super.key,
  }) : assert(backgroundAsset != null || backgroundColor != null);

  ChromeAssetButton.command({
    required this.label,
    required this.tokens,
    required bool prominent,
    this.textSize = PixelTextSize.headline,
    this.onPressed,
    this.iconAsset,
    this.iconSize = 20,
    this.iconOpacity = 1,
    this.width,
    this.height,
    this.padding,
    this.boxShadow,
    this.surfaceKey,
    this.uppercase = true,
    this.enabled = true,
    this.disabledOpacity = 0.45,
    this.spacing = 8,
    this.expandLabel = true,
    super.key,
  }) : backgroundAsset = prominent
           ? chromeButtonPrimaryAsset
           : chromeButtonSecondaryAsset,
       backgroundColor = null,
       border = null,
       borderRadius = null,
       textColor = prominent ? tokens.colors.onAccent : tokens.colors.cardInk,
       iconMuted = false,
       commandProminent = prominent;

  final String label;
  final DesignTokens tokens;
  final Color textColor;
  final PixelTextSize textSize;
  final String? backgroundAsset;
  final Color? backgroundColor;
  final BoxBorder? border;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onPressed;
  final String? iconAsset;
  final double iconSize;
  final double iconOpacity;
  final bool iconMuted;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? boxShadow;
  final Key? surfaceKey;
  final bool uppercase;
  final bool enabled;
  final double disabledOpacity;
  final double spacing;
  final bool expandLabel;
  final bool commandProminent;

  @override
  Widget build(BuildContext context) {
    final effectiveWidth =
        width ?? (commandProminent ? commandButtonProminentWidth : null);
    final effectiveHeight =
        height ?? (commandProminent ? commandButtonProminentMinHeight : null);
    final effectivePadding =
        padding ??
        (commandProminent
            ? const EdgeInsets.only(
                left: commandButtonProminentHorizontalPadding,
                right: commandButtonProminentHorizontalPadding,
                top: commandButtonProminentTopPadding,
                bottom: commandButtonProminentBottomPadding,
              )
            : null);
    final effectiveBoxShadow =
        boxShadow ??
        (commandProminent
            ? [
                BoxShadow(
                  color: tokens.colors.black.withValues(
                    alpha: commandButtonProminentOuterShadowOpacity,
                  ),
                  blurRadius: commandButtonProminentOuterShadowRadius,
                  offset: const Offset(
                    0,
                    commandButtonProminentOuterShadowYOffset,
                  ),
                ),
              ]
            : null);
    final labelWidget = ChromeScaledLabel(
      label,
      color: textColor,
      size: textSize,
      uppercase: uppercase,
    );
    final iconWidget = iconAsset == null
        ? null
        : ChromeAssetIcon(
            asset: iconAsset!,
            width: iconSize,
            height: iconSize,
            fit: BoxFit.fill,
            opacity: iconOpacity,
            muted: iconMuted,
          );
    final content = Padding(
      padding: effectivePadding ?? EdgeInsets.zero,
      child: iconWidget == null
          ? Center(child: labelWidget)
          : expandLabel
          ? Stack(
              alignment: Alignment.center,
              children: [
                Center(child: labelWidget),
                Align(alignment: Alignment.centerLeft, child: iconWidget),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              spacing: spacing,
              children: [
                iconWidget,
                Flexible(child: labelWidget),
              ],
            ),
    );
    final button = Container(
      key: surfaceKey,
      width: effectiveWidth,
      height: effectiveHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: borderRadius,
        boxShadow: effectiveBoxShadow,
      ),
      child: backgroundAsset == null
          ? content
          : Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: ChromeButtonBackground(asset: backgroundAsset!),
                ),
                Positioned.fill(child: content),
              ],
            ),
    );
    final child = enabled
        ? button
        : Opacity(opacity: disabledOpacity, child: button);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: child,
    );
  }
}

class ChromeChoiceButton extends StatelessWidget {
  const ChromeChoiceButton({
    required this.label,
    required this.selected,
    required this.tokens,
    this.onPressed,
    this.iconAsset,
    this.iconSize = 18,
    this.height = 34,
    super.key,
  });

  final String label;
  final bool selected;
  final DesignTokens tokens;
  final VoidCallback? onPressed;
  final String? iconAsset;
  final double iconSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? tokens.colors.gold.withValues(alpha: 0.72)
              : tokens.colors.black.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: selected
                ? tokens.colors.gold
                : tokens.colors.steel.withValues(alpha: 0.44),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 5,
            children: [
              if (iconAsset != null)
                ChromeAssetIcon(
                  asset: iconAsset!,
                  width: iconSize,
                  height: iconSize,
                  fit: BoxFit.contain,
                ),
              Flexible(
                child: ChromeScaledLabel(
                  label,
                  color: selected
                      ? tokens.colors.onAccent
                      : tokens.colors.creamDim,
                  size: PixelTextSize.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
