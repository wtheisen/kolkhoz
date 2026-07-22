import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kolkhoz_app/src/app/views/shared/art_direction.dart';
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

enum PixelTextVariant {
  regular('b2'),
  heavy('b4');

  const PixelTextVariant(this.assetCode);

  final String assetCode;
}

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
    if (configuredKolkhozArtStyle.usesNewArt) {
      return Text(
        text,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        softWrap: softWrap,
        style: fieldPlanDisplayTextStyle.copyWith(
          color: color,
          fontSize: size.value.toDouble(),
          fontWeight: variant == PixelTextVariant.heavy
              ? FontWeight.w700
              : FontWeight.w400,
          height: 1,
          letterSpacing: size.value <= PixelTextSize.caption2.value ? 0.2 : 0.5,
        ),
      );
    }
    final cached = PixelFontAtlasCache.instance.get(
      variant: variant,
      size: size,
    );
    if (cached != null) {
      return _paint(cached);
    }
    return FutureBuilder<PixelFontAtlas>(
      future: PixelFontAtlasCache.instance.load(variant: variant, size: size),
      builder: (context, snapshot) {
        final atlas = snapshot.data;
        if (atlas == null) {
          return Text(
            text,
            maxLines: maxLines,
            overflow: overflow,
            textAlign: textAlign,
            softWrap: softWrap,
            style: TextStyle(
              color: color,
              fontSize: size.value.toDouble(),
              fontWeight: variant == PixelTextVariant.heavy
                  ? FontWeight.w900
                  : FontWeight.w700,
            ),
          );
        }
        return _paint(atlas);
      },
    );
  }

  Widget _paint(PixelFontAtlas atlas) => _PixelTextPaint(
    text: text,
    atlas: atlas,
    color: color,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
    softWrap: softWrap,
  );
}

class _PixelTextPaint extends StatelessWidget {
  const _PixelTextPaint({
    required this.text,
    required this.atlas,
    required this.color,
    required this.textAlign,
    required this.maxLines,
    required this.overflow,
    required this.softWrap,
  });

  final String text;
  final PixelFontAtlas atlas;
  final Color color;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;
  final bool softWrap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrapWidth = softWrap && constraints.hasBoundedWidth
            ? constraints.maxWidth
            : null;
        final laidOutLines = atlas.layoutText(text, maxWidth: wrapWidth);
        final lines = maxLines == null
            ? laidOutLines
            : laidOutLines.take(maxLines!).toList(growable: false);
        final width = lines.fold<double>(
          0,
          (widest, line) => line.width > widest ? line.width : widest,
        );
        final height = lines.length * atlas.lineHeight;
        final paintWidth = constraints.hasBoundedWidth
            ? softWrap
                  ? constraints.maxWidth
                  : constraints.maxWidth.clamp(0, width).toDouble()
            : width;
        return Semantics(
          label: text,
          child: ClipRect(
            child: SizedBox(
              width: paintWidth,
              height: height + PixelText.opticalYOffset,
              child: CustomPaint(
                painter: _PixelTextPainter(
                  lines: lines,
                  atlas: atlas,
                  color: color,
                  textAlign: textAlign,
                  overflow: overflow,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PixelTextPainter extends CustomPainter {
  const _PixelTextPainter({
    required this.lines,
    required this.atlas,
    required this.color,
    required this.textAlign,
    required this.overflow,
  });

  final List<PixelTextLine> lines;
  final PixelFontAtlas atlas;
  final Color color;
  final TextAlign textAlign;
  final TextOverflow overflow;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..filterQuality = FilterQuality.none
      ..isAntiAlias = false
      ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
    for (final (index, line) in lines.indexed) {
      final dx = switch (textAlign) {
        TextAlign.center => (size.width - line.width) / 2,
        TextAlign.right || TextAlign.end => size.width - line.width,
        _ => 0.0,
      };
      final dy = PixelText.opticalYOffset + index * atlas.lineHeight;
      for (final run in line.runs) {
        final glyph = run.glyph;
        final destination = Rect.fromLTWH(
          dx + run.x,
          dy,
          glyph.width,
          atlas.lineHeight,
        );
        if (overflow == TextOverflow.clip && destination.left >= size.width) {
          continue;
        }
        canvas.drawImageRect(atlas.image, glyph.source, destination, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelTextPainter oldDelegate) {
    return lines != oldDelegate.lines ||
        atlas != oldDelegate.atlas ||
        color != oldDelegate.color ||
        textAlign != oldDelegate.textAlign ||
        overflow != oldDelegate.overflow;
  }
}

class PixelFontAtlasCache {
  PixelFontAtlasCache._();

  static final instance = PixelFontAtlasCache._();

  final _atlases = <String, PixelFontAtlas>{};
  final _loads = <String, Future<PixelFontAtlas>>{};

  void resetForTesting() {
    _atlases.clear();
    _loads.clear();
  }

  PixelFontAtlas? get({
    required PixelTextVariant variant,
    required PixelTextSize size,
  }) {
    return _atlases[_name(variant, size)];
  }

  Future<PixelFontAtlas> load({
    required PixelTextVariant variant,
    required PixelTextSize size,
  }) {
    final name = _name(variant, size);
    final cached = _atlases[name];
    if (cached != null) {
      return Future.value(cached);
    }
    return _loads.putIfAbsent(name, () async {
      final atlas = await PixelFontAtlas.load(name);
      _atlases[name] = atlas;
      _loads.remove(name);
      return atlas;
    });
  }

  String _name(PixelTextVariant variant, PixelTextSize size) =>
      'handjet-${variant.assetCode}-${size.value}px';
}

class PixelFontAtlas {
  const PixelFontAtlas({
    required this.image,
    required this.lineHeight,
    required this.scale,
    required this.spaceAdvance,
    required this.glyphs,
  });

  final ui.Image image;
  final double lineHeight;
  final double scale;
  final double spaceAdvance;
  final Map<String, PixelGlyph> glyphs;

  static Future<PixelFontAtlas> load(String name) async {
    final metadataData = await rootBundle.loadString(
      'assets/ui/Fonts/Bitmap/$name.json',
    );
    final metadata = jsonDecode(metadataData) as Map<String, Object?>;
    final imageData = await rootBundle.load('assets/ui/Fonts/Bitmap/$name.png');
    final codec = await ui.instantiateImageCodec(
      imageData.buffer.asUint8List(),
    );
    final frame = await codec.getNextFrame();
    final scale = ((metadata['scale'] as num?) ?? 1)
        .toDouble()
        .clamp(1, double.infinity)
        .toDouble();
    final glyphMetadata = metadata['glyphs'] as Map<String, Object?>;
    final glyphs = <String, PixelGlyph>{};
    for (final entry in glyphMetadata.entries) {
      if (entry.key == ' ') {
        continue;
      }
      final value = entry.value as Map<String, Object?>;
      final x = (value['x'] as num).toDouble();
      final y = (value['y'] as num).toDouble();
      final w = (value['w'] as num).toDouble();
      final h = (value['h'] as num).toDouble();
      glyphs[entry.key] = PixelGlyph(
        source: Rect.fromLTWH(x, y, w, h),
        width: w / scale,
        advance: ((value['advance'] as num).toDouble()) / scale,
      );
    }
    final lineHeight = ((metadata['lineHeight'] as num).toDouble()) / scale;
    final space = glyphMetadata[' '] as Map<String, Object?>?;
    final spaceAdvance =
        ((space?['advance'] as num?)?.toDouble() ??
            ((metadata['size'] as num).toDouble() / 3)) /
        scale;
    return PixelFontAtlas(
      image: frame.image,
      lineHeight: lineHeight,
      scale: scale,
      spaceAdvance: spaceAdvance,
      glyphs: glyphs,
    );
  }

  PixelTextLine layoutLine(String text) {
    var x = 0.0;
    final runs = <PixelGlyphRun>[];
    for (final rune in text.runes) {
      final character = String.fromCharCode(rune);
      if (character.trim().isEmpty) {
        x += spaceAdvance;
        continue;
      }
      final glyph = glyphs[character] ?? glyphs['?'];
      if (glyph == null) {
        x += spaceAdvance;
        continue;
      }
      runs.add(PixelGlyphRun(x: x, glyph: glyph));
      x += glyph.advance;
    }
    return PixelTextLine(width: x, runs: runs);
  }

  List<PixelTextLine> layoutText(String text, {double? maxWidth}) {
    final result = <PixelTextLine>[];
    for (final paragraph in text.split('\n')) {
      if (maxWidth == null || maxWidth <= 0) {
        result.add(layoutLine(paragraph));
        continue;
      }
      final words = paragraph
          .split(RegExp(r'\s+'))
          .where((word) => word.isNotEmpty)
          .toList(growable: false);
      if (words.isEmpty) {
        result.add(layoutLine(''));
        continue;
      }
      var current = '';
      for (final word in words) {
        final candidate = current.isEmpty ? word : '$current $word';
        if (layoutLine(candidate).width <= maxWidth || current.isEmpty) {
          current = candidate;
        } else {
          result.add(layoutLine(current));
          current = word;
        }
      }
      if (current.isNotEmpty) {
        result.add(layoutLine(current));
      }
    }
    return result.isEmpty ? [layoutLine('')] : result;
  }
}

class PixelTextLine {
  const PixelTextLine({required this.width, required this.runs});

  final double width;
  final List<PixelGlyphRun> runs;
}

class PixelGlyphRun {
  const PixelGlyphRun({required this.x, required this.glyph});

  final double x;
  final PixelGlyph glyph;
}

class PixelGlyph {
  const PixelGlyph({
    required this.source,
    required this.width,
    required this.advance,
  });

  final Rect source;
  final double width;
  final double advance;
}
