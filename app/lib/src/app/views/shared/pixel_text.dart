import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/views/shared/field_plan_typography.dart';

enum PixelTextSize {
  xSmall(8),
  small(10),
  caption2(11),
  caption(13),
  headline(17),
  title(20),
  cardRank(24);

  const PixelTextSize(this.value);

  final int value;
}

enum PixelTextVariant { regular, heavy }

class PixelText extends StatelessWidget {
  static const double opticalYOffset = 4;

  const PixelText(
    this.text, {
    required this.size,
    this.variant = PixelTextVariant.regular,
    this.color = Colors.white,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    this.softWrap = false,
    super.key,
  });

  final String text;
  final PixelTextSize size;
  final PixelTextVariant variant;
  final Color color;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        text: text,
        style: fieldPlanDisplayTextStyle.copyWith(
          color: color,
          fontSize: size.value.toDouble(),
          fontWeight: variant == PixelTextVariant.heavy
              ? FontWeight.w700
              : FontWeight.w400,
          height: 1,
          letterSpacing: size.value <= PixelTextSize.caption2.value ? 0.2 : 0.5,
        ),
      ),
      maxLines: maxLines,
      overflow: overflow,
      textAlign: textAlign,
      softWrap: softWrap,
    );
  }
}
