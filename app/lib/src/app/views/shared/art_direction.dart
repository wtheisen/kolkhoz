import 'package:flutter/widgets.dart';

class ArtAssetRef {
  const ArtAssetRef({required this.fieldPlanPath});

  final String fieldPlanPath;
}

class ArtAssetImage extends StatelessWidget {
  const ArtAssetImage({
    required this.asset,
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
    return _image(asset.fieldPlanPath, errorBuilder);
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
