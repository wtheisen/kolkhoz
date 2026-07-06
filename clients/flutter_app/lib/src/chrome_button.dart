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
const chromeButtonPrimaryAsset = 'ios_resources/ui-button-primary.png';
const chromeButtonSecondaryAsset = 'ios_resources/ui-button-secondary.png';
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
       textSize = PixelTextSize.headline,
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
    final button = Container(
      key: surfaceKey,
      width: effectiveWidth,
      height: effectiveHeight,
      alignment: Alignment.center,
      padding: effectivePadding,
      decoration: BoxDecoration(
        color: backgroundColor,
        image: backgroundAsset == null
            ? null
            : DecorationImage(
                image: AssetImage(backgroundAsset!),
                fit: BoxFit.fill,
                filterQuality: FilterQuality.none,
              ),
        border: border,
        borderRadius: borderRadius,
        boxShadow: effectiveBoxShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: spacing,
        children: [
          ?iconWidget,
          if (expandLabel)
            Expanded(child: labelWidget)
          else
            Flexible(child: labelWidget),
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
    this.height = 34,
    super.key,
  });

  final String label;
  final bool selected;
  final DesignTokens tokens;
  final VoidCallback? onPressed;
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
          child: ChromeScaledLabel(
            label,
            color: selected ? tokens.colors.onAccent : tokens.colors.creamDim,
            size: PixelTextSize.caption,
          ),
        ),
      ),
    );
  }
}
