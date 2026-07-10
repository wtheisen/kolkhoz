import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../pixel_text.dart';

class ProgressionNotice extends StatelessWidget {
  const ProgressionNotice({
    required this.message,
    required this.tokens,
    super.key,
  });

  final String message;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: tokens.colors.panel,
          borderRadius: BorderRadius.circular(tokens.radius.md),
          border: Border.all(color: tokens.colors.goldBright, width: 2),
          boxShadow: [
            BoxShadow(
              color: tokens.colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'ios_resources/Icons/icon-medal-star.png',
              width: 28,
              height: 28,
              filterQuality: FilterQuality.none,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: PixelText(
                message.toUpperCase(),
                color: tokens.colors.cream,
                size: PixelTextSize.caption,
                variant: PixelTextVariant.heavy,
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
