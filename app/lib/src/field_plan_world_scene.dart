import 'dart:convert';
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'field_plan_assets.dart';

const fieldPlanWorldEditorDefine = 'KOLKHOZ_FIELD_PLAN_EDITOR';
const fieldPlanWorldEditorEnabled =
    kDebugMode || bool.fromEnvironment(fieldPlanWorldEditorDefine);

enum FieldPlanWorldRegion { brigade, fields, north }

@immutable
class FieldPlanWorldLayer {
  const FieldPlanWorldLayer({
    required this.id,
    required this.assetPath,
    required this.region,
    this.worldRect = const Rect.fromLTWH(0, 0, 1, 1),
    this.zOrder = 0,
    this.parallax = 1,
    this.opacity = 1,
    this.offset = Offset.zero,
    this.scale = 1,
    this.participatesInCamera = true,
  });

  final String id;
  final String assetPath;
  final FieldPlanWorldRegion region;
  final Rect worldRect;
  final int zOrder;
  final double parallax;
  final double opacity;
  final Offset offset;
  final double scale;
  final bool participatesInCamera;

  FieldPlanWorldLayer copyWith({
    int? zOrder,
    double? parallax,
    double? opacity,
    Offset? offset,
    double? scale,
  }) => FieldPlanWorldLayer(
    id: id,
    assetPath: assetPath,
    region: region,
    worldRect: worldRect,
    zOrder: zOrder ?? this.zOrder,
    parallax: parallax ?? this.parallax,
    opacity: opacity ?? this.opacity,
    offset: offset ?? this.offset,
    scale: scale ?? this.scale,
    participatesInCamera: participatesInCamera,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'assetPath': assetPath,
    'region': region.name,
    'worldRect': [
      worldRect.left,
      worldRect.top,
      worldRect.width,
      worldRect.height,
    ],
    'zOrder': zOrder,
    'parallax': parallax,
    'opacity': opacity,
    'offset': [offset.dx, offset.dy],
    'scale': scale,
    'participatesInCamera': participatesInCamera,
  };
}

@immutable
class FieldPlanWorldQuad {
  const FieldPlanWorldQuad(
    this.topLeft,
    this.topRight,
    this.bottomRight,
    this.bottomLeft,
  );

  final Offset topLeft;
  final Offset topRight;
  final Offset bottomRight;
  final Offset bottomLeft;

  Offset get center => (topLeft + topRight + bottomRight + bottomLeft) / 4;

  List<Offset> get corners => [topLeft, topRight, bottomRight, bottomLeft];

  FieldPlanWorldQuad replaceCorner(int index, Offset point) => switch (index) {
    0 => FieldPlanWorldQuad(point, topRight, bottomRight, bottomLeft),
    1 => FieldPlanWorldQuad(topLeft, point, bottomRight, bottomLeft),
    2 => FieldPlanWorldQuad(topLeft, topRight, point, bottomLeft),
    _ => FieldPlanWorldQuad(topLeft, topRight, bottomRight, point),
  };

  Map<String, Object> toJson() => {
    'topLeft': [topLeft.dx, topLeft.dy],
    'topRight': [topRight.dx, topRight.dy],
    'bottomRight': [bottomRight.dx, bottomRight.dy],
    'bottomLeft': [bottomLeft.dx, bottomLeft.dy],
  };
}

@immutable
class FieldPlanWorldSurface {
  const FieldPlanWorldSurface({
    required this.id,
    required this.region,
    required this.quad,
  });

  final String id;
  final FieldPlanWorldRegion region;
  final FieldPlanWorldQuad quad;

  FieldPlanWorldSurface copyWith({FieldPlanWorldQuad? quad}) =>
      FieldPlanWorldSurface(id: id, region: region, quad: quad ?? this.quad);

  Map<String, Object> toJson() => {
    'id': id,
    'region': region.name,
    'quad': quad.toJson(),
  };
}

@immutable
class FieldPlanWorldCamera {
  const FieldPlanWorldCamera({
    required this.id,
    required this.region,
    this.center = const Offset(0.5, 0.5),
    this.zoom = 1,
    this.tilt = 0,
  });

  final String id;
  final FieldPlanWorldRegion region;
  final Offset center;
  final double zoom;
  final double tilt;

  Map<String, Object> toJson() => {
    'id': id,
    'region': region.name,
    'center': [center.dx, center.dy],
    'zoom': zoom,
    'tilt': tilt,
  };
}

@immutable
class FieldPlanWorldLayout {
  const FieldPlanWorldLayout({
    required this.layers,
    required this.surfaces,
    required this.cameras,
  });

  final List<FieldPlanWorldLayer> layers;
  final List<FieldPlanWorldSurface> surfaces;
  final List<FieldPlanWorldCamera> cameras;

  FieldPlanWorldSurface? surface(String id) {
    for (final surface in surfaces) {
      if (surface.id == id) {
        return surface;
      }
    }
    return null;
  }

  FieldPlanWorldLayout replaceLayer(FieldPlanWorldLayer replacement) =>
      FieldPlanWorldLayout(
        layers: [
          for (final layer in layers)
            if (layer.id == replacement.id) replacement else layer,
        ],
        surfaces: surfaces,
        cameras: cameras,
      );

  FieldPlanWorldLayout replaceSurface(FieldPlanWorldSurface replacement) =>
      FieldPlanWorldLayout(
        layers: layers,
        surfaces: [
          for (final surface in surfaces)
            if (surface.id == replacement.id) replacement else surface,
        ],
        cameras: cameras,
      );

  String prettyJson() => const JsonEncoder.withIndent('  ').convert({
    'layers': layers.map((layer) => layer.toJson()).toList(),
    'surfaces': surfaces.map((surface) => surface.toJson()).toList(),
    'cameras': cameras.map((camera) => camera.toJson()).toList(),
  });
}

const fieldPlanWorldLayout = FieldPlanWorldLayout(
  layers: [
    FieldPlanWorldLayer(
      id: 'brigade-landscape',
      assetPath: fieldPlanBrigadePlotBackgroundPath,
      region: FieldPlanWorldRegion.brigade,
    ),
    FieldPlanWorldLayer(
      id: 'fields-landscape',
      assetPath: fieldPlanFieldsBackgroundPath,
      region: FieldPlanWorldRegion.fields,
    ),
    FieldPlanWorldLayer(
      id: 'north-landscape',
      assetPath: fieldPlanNorthBackgroundPath,
      region: FieldPlanWorldRegion.north,
    ),
  ],
  surfaces: [
    FieldPlanWorldSurface(
      id: 'plot-1',
      region: FieldPlanWorldRegion.brigade,
      quad: FieldPlanWorldQuad(
        Offset(0.212, 0.345),
        Offset(0.378, 0.343),
        Offset(0.359, 0.455),
        Offset(0.184, 0.452),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'plot-2',
      region: FieldPlanWorldRegion.brigade,
      quad: FieldPlanWorldQuad(
        Offset(0.618, 0.341),
        Offset(0.789, 0.340),
        Offset(0.817, 0.454),
        Offset(0.638, 0.452),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'plot-3',
      region: FieldPlanWorldRegion.brigade,
      quad: FieldPlanWorldQuad(
        Offset(0.114, 0.725),
        Offset(0.326, 0.723),
        Offset(0.312, 0.867),
        Offset(0.076, 0.867),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'plot-0',
      region: FieldPlanWorldRegion.brigade,
      quad: FieldPlanWorldQuad(
        Offset(0.647, 0.716),
        Offset(0.883, 0.717),
        Offset(0.919, 0.863),
        Offset(0.663, 0.866),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'field-0',
      region: FieldPlanWorldRegion.fields,
      quad: FieldPlanWorldQuad(
        Offset(0.187, 0.193),
        Offset(0.450, 0.190),
        Offset(0.439, 0.353),
        Offset(0.066, 0.350),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'field-1',
      region: FieldPlanWorldRegion.fields,
      quad: FieldPlanWorldQuad(
        Offset(0.542, 0.185),
        Offset(0.801, 0.187),
        Offset(0.938, 0.351),
        Offset(0.562, 0.354),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'field-2',
      region: FieldPlanWorldRegion.fields,
      quad: FieldPlanWorldQuad(
        Offset(0.146, 0.535),
        Offset(0.420, 0.539),
        Offset(0.376, 0.853),
        Offset(0.013, 0.848),
      ),
    ),
    FieldPlanWorldSurface(
      id: 'field-3',
      region: FieldPlanWorldRegion.fields,
      quad: FieldPlanWorldQuad(
        Offset(0.575, 0.546),
        Offset(0.825, 0.548),
        Offset(0.989, 0.870),
        Offset(0.611, 0.873),
      ),
    ),
  ],
  cameras: [
    FieldPlanWorldCamera(
      id: 'brigade-overview',
      region: FieldPlanWorldRegion.brigade,
    ),
    FieldPlanWorldCamera(
      id: 'fields-overview',
      region: FieldPlanWorldRegion.fields,
    ),
    FieldPlanWorldCamera(
      id: 'north-overview',
      region: FieldPlanWorldRegion.north,
    ),
  ],
);

class FieldPlanWorldFocusScope extends InheritedWidget {
  const FieldPlanWorldFocusScope({
    required this.surfaceID,
    required this.progress,
    required super.child,
    super.key,
  });

  final String? surfaceID;
  final double progress;

  static FieldPlanWorldFocusScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FieldPlanWorldFocusScope>();

  @override
  bool updateShouldNotify(FieldPlanWorldFocusScope oldWidget) =>
      surfaceID != oldWidget.surfaceID || progress != oldWidget.progress;
}

class FieldPlanWorldScene extends StatefulWidget {
  const FieldPlanWorldScene({
    required this.cameraPosition,
    required this.overlayPage,
    required this.overlay,
    required this.focusedSurfaceID,
    required this.focusProgress,
    required this.onFocusSurface,
    this.layout = fieldPlanWorldLayout,
    super.key,
  });

  final double cameraPosition;
  final int overlayPage;
  final Widget overlay;
  final String? focusedSurfaceID;
  final double focusProgress;
  final ValueChanged<String?> onFocusSurface;
  final FieldPlanWorldLayout layout;

  @override
  State<FieldPlanWorldScene> createState() => _FieldPlanWorldSceneState();
}

class _FieldPlanWorldSceneState extends State<FieldPlanWorldScene> {
  late FieldPlanWorldLayout layout = widget.layout;
  bool editorOpen = false;
  String selectedLayerID = fieldPlanWorldLayout.layers.first.id;
  String selectedSurfaceID = fieldPlanWorldLayout.surfaces.first.id;
  double? previewCameraPosition;

  @override
  void didUpdateWidget(FieldPlanWorldScene oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.layout != oldWidget.layout && !editorOpen) {
      layout = widget.layout;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final cameraPosition = previewCameraPosition ?? widget.cameraPosition;
        final focusSurface = widget.focusedSurfaceID == null
            ? null
            : layout.surface(widget.focusedSurfaceID!);
        final layers = [...layout.layers]
          ..sort((a, b) => a.zOrder.compareTo(b.zOrder));
        final overlayMatrix = fieldPlanWorldCameraMatrix(
          size: size,
          page: widget.overlayPage.toDouble(),
          cameraPosition: cameraPosition,
          parallax: 1,
          focusSurface: focusSurface,
          focusProgress: widget.focusProgress,
        );

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onLongPress: fieldPlanWorldEditorEnabled
              ? () => setState(() => editorOpen = true)
              : null,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              children: [
                for (final layer in layers)
                  Transform(
                    key: Key('field-plan-world-layer-${layer.id}'),
                    alignment: Alignment.topLeft,
                    transform: layer.participatesInCamera
                        ? fieldPlanWorldCameraMatrix(
                            size: size,
                            page: layer.region.index.toDouble(),
                            cameraPosition: cameraPosition,
                            parallax: layer.parallax,
                            focusSurface: focusSurface,
                            focusProgress: widget.focusProgress,
                          )
                        : Matrix4.identity(),
                    child: Transform.translate(
                      offset: Offset(
                        layer.offset.dx * size.width,
                        layer.offset.dy * size.height,
                      ),
                      child: Transform.scale(
                        scale: layer.scale,
                        child: Opacity(
                          opacity: layer.opacity,
                          child: KeyedSubtree(
                            key: Key(switch (layer.region) {
                              FieldPlanWorldRegion.brigade =>
                                'field-plan-brigade-environment',
                              FieldPlanWorldRegion.fields =>
                                'field-plan-fields-environment',
                              FieldPlanWorldRegion.north =>
                                'field-plan-north-environment',
                            }),
                            child: Image.asset(
                              layer.assetPath,
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Transform(
                  key: const Key('field-plan-world-overlays'),
                  alignment: Alignment.topLeft,
                  transform: overlayMatrix,
                  child: FieldPlanWorldFocusScope(
                    surfaceID: widget.focusedSurfaceID,
                    progress: widget.focusProgress,
                    child: widget.overlay,
                  ),
                ),
                if (widget.focusedSurfaceID != null)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: SafeArea(
                      child: IconButton.filledTonal(
                        key: const Key('field-plan-surface-dismiss'),
                        tooltip: 'Return to overview',
                        onPressed: () => widget.onFocusSurface(null),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                if (fieldPlanWorldEditorEnabled && editorOpen)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: SafeArea(
                      child: IconButton.filledTonal(
                        key: const Key('field-plan-world-editor-toggle'),
                        tooltip: 'World calibration',
                        onPressed: () => setState(() => editorOpen = false),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                  ),
                if (editorOpen)
                  _FieldPlanWorldEditor(
                    layout: layout,
                    size: size,
                    cameraPosition: cameraPosition,
                    selectedLayerID: selectedLayerID,
                    selectedSurfaceID: selectedSurfaceID,
                    onLayerSelected: (id) =>
                        setState(() => selectedLayerID = id),
                    onSurfaceSelected: (id) =>
                        setState(() => selectedSurfaceID = id),
                    onLayoutChanged: (value) => setState(() => layout = value),
                    onCameraChanged: (value) =>
                        setState(() => previewCameraPosition = value),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Matrix4 fieldPlanWorldCameraMatrix({
  required Size size,
  required double page,
  required double cameraPosition,
  required double parallax,
  FieldPlanWorldSurface? focusSurface,
  double focusProgress = 0,
}) {
  final distance = page - cameraPosition;
  final pageMatrix = Matrix4.identity()
    ..translateByDouble(size.width / 2, size.height / 2, 0, 1)
    ..translateByDouble(
      -size.width / 2,
      -size.height / 2 + distance * size.height * parallax,
      0,
      1,
    );
  if (focusSurface == null ||
      focusSurface.region.index != page.round() ||
      focusProgress <= 0) {
    return pageMatrix;
  }
  final progress = Curves.easeInOutCubic.transform(focusProgress.clamp(0, 1));
  final viewportCenter = size.center(Offset.zero);
  final surfaceCenter = Offset(
    focusSurface.quad.center.dx * size.width,
    focusSurface.quad.center.dy * size.height,
  );
  final cameraCenter = Offset.lerp(viewportCenter, surfaceCenter, progress)!;
  final zoom = lerpDouble(1, 1.72, progress)!;
  final focusMatrix = Matrix4.identity()
    ..translateByDouble(viewportCenter.dx, viewportCenter.dy, 0, 1)
    ..scaleByDouble(zoom, zoom, 1, 1)
    ..translateByDouble(-cameraCenter.dx, -cameraCenter.dy, 0, 1);
  return pageMatrix..multiply(focusMatrix);
}

class _FieldPlanWorldEditor extends StatelessWidget {
  const _FieldPlanWorldEditor({
    required this.layout,
    required this.size,
    required this.cameraPosition,
    required this.selectedLayerID,
    required this.selectedSurfaceID,
    required this.onLayerSelected,
    required this.onSurfaceSelected,
    required this.onLayoutChanged,
    required this.onCameraChanged,
  });

  final FieldPlanWorldLayout layout;
  final Size size;
  final double cameraPosition;
  final String selectedLayerID;
  final String selectedSurfaceID;
  final ValueChanged<String> onLayerSelected;
  final ValueChanged<String> onSurfaceSelected;
  final ValueChanged<FieldPlanWorldLayout> onLayoutChanged;
  final ValueChanged<double> onCameraChanged;

  @override
  Widget build(BuildContext context) {
    final layer = layout.layers.firstWhere(
      (item) => item.id == selectedLayerID,
    );
    final surface = layout.surfaces.firstWhere(
      (item) => item.id == selectedSurfaceID,
    );
    final matrix = fieldPlanWorldCameraMatrix(
      size: size,
      page: surface.region.index.toDouble(),
      cameraPosition: cameraPosition,
      parallax: 1,
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanUpdate: (details) {
              onLayoutChanged(
                layout.replaceLayer(
                  layer.copyWith(
                    offset:
                        layer.offset +
                        Offset(
                          details.delta.dx / size.width,
                          details.delta.dy / size.height,
                        ),
                  ),
                ),
              );
            },
          ),
        ),
        for (final (index, corner) in surface.quad.corners.indexed)
          Positioned(
            left: corner.dx * size.width - 12,
            top:
                (corner.dy + surface.region.index - cameraPosition) *
                    size.height -
                12,
            child: GestureDetector(
              onPanUpdate: (details) {
                final next = Offset(
                  (corner.dx + details.delta.dx / size.width).clamp(0, 1),
                  (corner.dy + details.delta.dy / size.height).clamp(0, 1),
                );
                onLayoutChanged(
                  layout.replaceSurface(
                    surface.copyWith(
                      quad: surface.quad.replaceCorner(index, next),
                    ),
                  ),
                );
              },
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xfff4c542),
                  shape: BoxShape.circle,
                ),
                child: SizedBox.square(dimension: 24),
              ),
            ),
          ),
        Positioned(
          left: 50,
          top: 10,
          width: 310,
          child: Material(
            color: const Color(0xee182020),
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'FIELD PLAN WORLD CALIBRATION',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<String>(
                      value: selectedLayerID,
                      isExpanded: true,
                      dropdownColor: const Color(0xff182020),
                      items: [
                        for (final item in layout.layers)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.id),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) onLayerSelected(value);
                      },
                    ),
                    Text('Scale ${layer.scale.toStringAsFixed(2)}'),
                    Slider(
                      value: layer.scale,
                      min: 0.5,
                      max: 1.5,
                      onChanged: (value) => onLayoutChanged(
                        layout.replaceLayer(layer.copyWith(scale: value)),
                      ),
                    ),
                    Text('Parallax ${layer.parallax.toStringAsFixed(2)}'),
                    Slider(
                      value: layer.parallax,
                      min: 0,
                      max: 1.5,
                      onChanged: (value) => onLayoutChanged(
                        layout.replaceLayer(layer.copyWith(parallax: value)),
                      ),
                    ),
                    Row(
                      children: [
                        const Text('Depth'),
                        IconButton(
                          onPressed: () => onLayoutChanged(
                            layout.replaceLayer(
                              layer.copyWith(zOrder: layer.zOrder - 1),
                            ),
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                        Text('${layer.zOrder}'),
                        IconButton(
                          onPressed: () => onLayoutChanged(
                            layout.replaceLayer(
                              layer.copyWith(zOrder: layer.zOrder + 1),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                        ),
                      ],
                    ),
                    DropdownButton<String>(
                      value: selectedSurfaceID,
                      isExpanded: true,
                      dropdownColor: const Color(0xff182020),
                      items: [
                        for (final item in layout.surfaces)
                          DropdownMenuItem(
                            value: item.id,
                            child: Text(item.id),
                          ),
                      ],
                      onChanged: (value) {
                        if (value != null) onSurfaceSelected(value);
                      },
                    ),
                    Text('Camera ${cameraPosition.toStringAsFixed(3)}'),
                    Slider(
                      value: cameraPosition,
                      min: 0,
                      max: 2,
                      onChanged: onCameraChanged,
                    ),
                    Wrap(
                      spacing: 6,
                      children: [
                        for (var page = 0; page < 3; page++)
                          TextButton(
                            onPressed: () => onCameraChanged(page.toDouble()),
                            child: Text(FieldPlanWorldRegion.values[page].name),
                          ),
                      ],
                    ),
                    Text(
                      'surface center '
                      '${surface.quad.center.dx.toStringAsFixed(3)}, '
                      '${surface.quad.center.dy.toStringAsFixed(3)}\n'
                      'matrix ${matrix.storage.map((v) => v.toStringAsFixed(2)).join(', ')}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: layout.prettyJson()),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Copy JSON'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
