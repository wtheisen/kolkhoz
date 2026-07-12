import 'package:flutter/widgets.dart';

const kolkhozArtStyleEnvironmentKey = 'KOLKHOZ_ART_STYLE';
const fieldPlanArtStyleValue = 'field_plan';

enum KolkhozArtStyle {
  legacy,
  fieldPlan;

  static KolkhozArtStyle fromEnvironmentValue(String? value) {
    return value == fieldPlanArtStyleValue
        ? KolkhozArtStyle.fieldPlan
        : KolkhozArtStyle.legacy;
  }

  bool get usesNewArt => this == KolkhozArtStyle.fieldPlan;
  bool get supportsDarkAppearance => this == KolkhozArtStyle.legacy;
}

const configuredKolkhozArtStyle =
    String.fromEnvironment(
          kolkhozArtStyleEnvironmentKey,
          defaultValue: 'legacy',
        ) ==
        fieldPlanArtStyleValue
    ? KolkhozArtStyle.fieldPlan
    : KolkhozArtStyle.legacy;

class ArtAssetRef {
  const ArtAssetRef({required this.legacyPath, this.fieldPlanPath});

  final String legacyPath;
  final String? fieldPlanPath;

  String pathFor(KolkhozArtStyle style) {
    if (style.usesNewArt && fieldPlanPath != null) {
      return fieldPlanPath!;
    }
    return legacyPath;
  }
}

class ArtAssetImage extends StatelessWidget {
  const ArtAssetImage({
    required this.asset,
    this.style = configuredKolkhozArtStyle,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.filterQuality = FilterQuality.medium,
    this.isAntiAlias = false,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.errorBuilder,
    super.key,
  });

  final ArtAssetRef asset;
  final KolkhozArtStyle style;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final AlignmentGeometry alignment;
  final FilterQuality filterQuality;
  final bool isAntiAlias;
  final String? semanticLabel;
  final bool excludeFromSemantics;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) {
    final requestedPath = asset.pathFor(style);
    if (requestedPath == asset.legacyPath) {
      return _image(asset.legacyPath, errorBuilder);
    }
    return _image(
      requestedPath,
      (context, error, stackTrace) => _image(asset.legacyPath, errorBuilder),
    );
  }

  Image _image(String path, ImageErrorWidgetBuilder? onError) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      filterQuality: filterQuality,
      isAntiAlias: isAntiAlias,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      errorBuilder: onError,
    );
  }
}
