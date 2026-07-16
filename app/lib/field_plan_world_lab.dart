import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'src/north_threat_state.dart';
import 'src/world_depth_camera.dart';
import 'src/world_depth_manifest.dart';
import 'src/world_depth_scene.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const FieldPlanWorldLabApp(
      initialCameraZ: 3,
      initialGuidesEnabled: false,
      initialCorridorProofEnabled: true,
    ),
  );
}

class FieldPlanWorldLabApp extends StatelessWidget {
  const FieldPlanWorldLabApp({
    this.manifest,
    this.initialCameraZ,
    this.initialThreat = 0.5,
    this.initialAtmosphereEnabled = true,
    this.initialGuidesEnabled = true,
    this.initialCorridorProofEnabled = false,
    super.key,
  });

  final WorldDepthManifest? manifest;
  final double? initialCameraZ;
  final double initialThreat;
  final bool initialAtmosphereEnabled;
  final bool initialGuidesEnabled;
  final bool initialCorridorProofEnabled;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz · World Depth Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff9f2d31),
          brightness: Brightness.dark,
        ),
        fontFamily: 'PTSansNarrow',
        useMaterial3: true,
      ),
      home: FieldPlanWorldLabScreen(
        manifest: manifest,
        initialCameraZ: initialCameraZ,
        initialThreat: initialThreat,
        initialAtmosphereEnabled: initialAtmosphereEnabled,
        initialGuidesEnabled: initialGuidesEnabled,
        initialCorridorProofEnabled: initialCorridorProofEnabled,
      ),
    );
  }
}

class FieldPlanWorldLabScreen extends StatefulWidget {
  const FieldPlanWorldLabScreen({
    this.manifest,
    this.initialCameraZ,
    this.initialThreat = 0.5,
    this.initialAtmosphereEnabled = true,
    this.initialGuidesEnabled = true,
    this.initialCorridorProofEnabled = false,
    super.key,
  });

  final WorldDepthManifest? manifest;
  final double? initialCameraZ;
  final double initialThreat;
  final bool initialAtmosphereEnabled;
  final bool initialGuidesEnabled;
  final bool initialCorridorProofEnabled;

  @override
  State<FieldPlanWorldLabScreen> createState() =>
      _FieldPlanWorldLabScreenState();
}

class _FieldPlanWorldLabScreenState extends State<FieldPlanWorldLabScreen>
    with SingleTickerProviderStateMixin {
  late final Future<WorldDepthManifest> manifestFuture =
      WorldDepthManifest.load();
  late final AnimationController travelController;
  late double cameraZ;
  late double threat;
  double travelBegin = 0;
  double travelEnd = 0;
  Curve travelCurve = Curves.easeInOutCubic;
  bool showPlateLabels = false;
  late bool showCalibrationGuides;
  late bool atmosphereEnabled;
  late bool corridorProofEnabled;

  @override
  void initState() {
    super.initState();
    cameraZ = worldDepthCameraCalibration.clampZ(
      widget.initialCameraZ ?? worldDepthCameraCalibration.startZ,
    );
    threat = widget.initialThreat.clamp(0.0, 1.0).toDouble();
    showCalibrationGuides = widget.initialGuidesEnabled;
    atmosphereEnabled = widget.initialAtmosphereEnabled;
    corridorProofEnabled = widget.initialCorridorProofEnabled;
    travelController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 720),
        )..addListener(() {
          final progress = travelCurve.transform(travelController.value);
          setState(() {
            cameraZ = travelBegin + (travelEnd - travelBegin) * progress;
          });
        });
  }

  @override
  void dispose() {
    travelController.dispose();
    super.dispose();
  }

  WorldDepthStop _nearestStop(double z) {
    return worldDepthCameraCalibration.nearestStop(z);
  }

  void _animateTo(double target) {
    travelController.stop();
    travelCurve = Curves.easeInOutCubic;
    travelBegin = cameraZ;
    travelEnd = worldDepthCameraCalibration.clampZ(target);
    final distance = (travelEnd - travelBegin).abs();
    travelController.duration = Duration(
      milliseconds: math.max(180, (720 * distance / 3).round()),
    );
    travelController.forward(from: 0);
  }

  void _coastTo(double target, {required Duration duration}) {
    travelController.stop();
    travelCurve = Curves.easeOutCubic;
    travelBegin = cameraZ;
    travelEnd = worldDepthCameraCalibration.clampZ(target);
    if ((travelEnd - travelBegin).abs() < 0.001) return;
    travelController.duration = duration;
    travelController.forward(from: 0);
  }

  void _handleDragUpdate(DragUpdateDetails details, double viewportHeight) {
    travelController.stop();
    final dragDistance = math.max(1.0, viewportHeight * 0.72);
    setState(() {
      cameraZ = worldDepthCameraCalibration.clampZ(
        cameraZ + details.delta.dy / dragDistance * 3,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details, double viewportHeight) {
    final dragDistance = math.max(1.0, viewportHeight * 0.72);
    final velocity = (details.primaryVelocity ?? 0) / dragDistance * 3;
    if (velocity.abs() < 0.08) return;
    _coastTo(
      cameraZ + velocity * 0.18,
      duration: Duration(
        milliseconds: (260 + math.min(340, velocity.abs() * 55)).round(),
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent signal) {
    if (signal is! PointerScrollEvent) return;
    final pendingTarget = travelController.isAnimating ? travelEnd : cameraZ;
    final target = worldDepthCameraCalibration.clampZ(
      pendingTarget + signal.scrollDelta.dy / 240,
    );
    _coastTo(
      target,
      duration: Duration(
        milliseconds: (220 + (target - cameraZ).abs() * 160).round().clamp(
          240,
          460,
        ),
      ),
    );
  }

  void _setCameraZ(double z) {
    travelController.stop();
    setState(() => cameraZ = worldDepthCameraCalibration.clampZ(z));
  }

  @override
  Widget build(BuildContext context) {
    final providedManifest = widget.manifest;
    if (providedManifest != null) return _buildLab(providedManifest);
    return FutureBuilder<WorldDepthManifest>(
      future: manifestFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ManifestError(error: snapshot.error!);
        }
        final manifest = snapshot.data;
        if (manifest == null) {
          return const ColoredBox(
            color: Color(0xff091315),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return _buildLab(manifest);
      },
    );
  }

  Widget _buildLab(WorldDepthManifest manifest) {
    final activeStop = _nearestStop(cameraZ);
    final threatState = NorthThreatState.resolve(threat);
    return Scaffold(
      backgroundColor: const Color(0xff091315),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Listener(
            onPointerSignal: _handlePointerSignal,
            child: GestureDetector(
              key: const Key('field-plan-depth-scene'),
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) {
                travelController.stop();
              },
              onVerticalDragUpdate: (details) =>
                  _handleDragUpdate(details, constraints.maxHeight),
              onVerticalDragEnd: (details) =>
                  _handleDragEnd(details, constraints.maxHeight),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  WorldDepthScene(
                    manifest: manifest,
                    cameraZ: cameraZ,
                    threatState: threatState,
                    atmosphereEnabled: atmosphereEnabled,
                    corridorProofEnabled: corridorProofEnabled,
                    showPlateLabels: showPlateLabels,
                    showCalibrationGuides: showCalibrationGuides,
                  ),
                  Positioned(
                    left: 18,
                    top: 18,
                    child: _WorldLabTitle(
                      stop: activeStop,
                      cameraZ: cameraZ,
                      layerCount: manifest.layers.length,
                      corridorProofEnabled: corridorProofEnabled,
                    ),
                  ),
                  Positioned(
                    top: 18,
                    right: 18,
                    child: _DepthNavigation(
                      stops: manifest.stops,
                      activeStop: activeStop,
                      showPlateLabels: showPlateLabels,
                      showCalibrationGuides: showCalibrationGuides,
                      corridorProofEnabled: corridorProofEnabled,
                      onSelected: (stop) => _animateTo(stop.z),
                      onToggleLabels: () =>
                          setState(() => showPlateLabels = !showPlateLabels),
                      onToggleGuides: () => setState(
                        () => showCalibrationGuides = !showCalibrationGuides,
                      ),
                      onToggleCorridorProof: () => setState(
                        () => corridorProofEnabled = !corridorProofEnabled,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 92,
                    right: 18,
                    child: _DepthRail(
                      cameraZ: cameraZ,
                      stops: manifest.stops,
                      layers: manifest.layers,
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 106,
                    child: Center(
                      child: _ThreatControls(
                        threat: threat,
                        state: threatState,
                        atmosphereEnabled: atmosphereEnabled,
                        onThreatChanged: (value) =>
                            setState(() => threat = value),
                        onAtmosphereChanged: (value) =>
                            setState(() => atmosphereEnabled = value),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 18,
                    right: 18,
                    bottom: 18,
                    child: Center(
                      child: _CameraScrubber(
                        cameraZ: cameraZ,
                        stops: manifest.stops,
                        onChanged: _setCameraZ,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WorldLabTitle extends StatelessWidget {
  const _WorldLabTitle({
    required this.stop,
    required this.cameraZ,
    required this.layerCount,
    required this.corridorProofEnabled,
  });

  final WorldDepthStop stop;
  final double cameraZ;
  final int layerCount;
  final bool corridorProofEnabled;

  @override
  Widget build(BuildContext context) {
    return _HudSurface(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.landscape, color: Color(0xffe3bd51), size: 28),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WORLD DEPTH LAB',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.3,
                ),
              ),
              Text(
                '${stop.label} · Z ${cameraZ.toStringAsFixed(2)} · '
                '${corridorProofEnabled ? '8 DEPTH PLATES · TEMPORARY' : '$layerCount FIGMA PLATES'}',
                style: const TextStyle(
                  color: Color(0xffe3bd51),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepthNavigation extends StatelessWidget {
  const _DepthNavigation({
    required this.stops,
    required this.activeStop,
    required this.showPlateLabels,
    required this.showCalibrationGuides,
    required this.corridorProofEnabled,
    required this.onSelected,
    required this.onToggleLabels,
    required this.onToggleGuides,
    required this.onToggleCorridorProof,
  });

  final List<WorldDepthStop> stops;
  final WorldDepthStop activeStop;
  final bool showPlateLabels;
  final bool showCalibrationGuides;
  final bool corridorProofEnabled;
  final ValueChanged<WorldDepthStop> onSelected;
  final VoidCallback onToggleLabels;
  final VoidCallback onToggleGuides;
  final VoidCallback onToggleCorridorProof;

  @override
  Widget build(BuildContext context) {
    return _HudSurface(
      padding: const EdgeInsets.all(6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final stop in stops)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: stop.id == activeStop.id
                      ? const Color(0xff182527)
                      : const Color(0xffffe8aa),
                  backgroundColor: stop.id == activeStop.id
                      ? const Color(0xffe3bd51)
                      : Colors.transparent,
                ),
                onPressed: () => onSelected(stop),
                key: Key('camera-stop-${stop.id}'),
                child: Text(stop.label),
              ),
            ),
          IconButton(
            key: const Key('toggle-corridor-proof'),
            tooltip: 'Toggle temporary corridor proof plates',
            onPressed: onToggleCorridorProof,
            icon: Icon(
              corridorProofEnabled ? Icons.layers : Icons.layers_outlined,
              color: corridorProofEnabled
                  ? const Color(0xffe3bd51)
                  : const Color(0xffffe8aa),
            ),
          ),
          IconButton(
            key: const Key('toggle-calibration-guides'),
            tooltip: 'Toggle calibration guides',
            onPressed: onToggleGuides,
            icon: Icon(
              showCalibrationGuides ? Icons.grid_on : Icons.grid_off,
              color: const Color(0xffffe8aa),
            ),
          ),
          IconButton(
            tooltip: 'Toggle plate labels',
            onPressed: onToggleLabels,
            icon: Icon(
              showPlateLabels ? Icons.label : Icons.label_outline,
              color: const Color(0xffffe8aa),
            ),
          ),
        ],
      ),
    );
  }
}

class _DepthRail extends StatelessWidget {
  const _DepthRail({
    required this.cameraZ,
    required this.stops,
    required this.layers,
  });

  final double cameraZ;
  final List<WorldDepthStop> stops;
  final List<WorldDepthLayer> layers;

  @override
  Widget build(BuildContext context) {
    final minZ = worldDepthCameraCalibration.startZ;
    final maxZ = layers.map((layer) => layer.worldZ).reduce(math.max);
    return _HudSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SizedBox(
        width: 190,
        height: 32,
        child: CustomPaint(
          painter: _DepthRailPainter(
            cameraZ: cameraZ,
            minZ: minZ,
            maxZ: maxZ,
            stops: stops,
            layers: layers,
          ),
        ),
      ),
    );
  }
}

class _DepthRailPainter extends CustomPainter {
  const _DepthRailPainter({
    required this.cameraZ,
    required this.minZ,
    required this.maxZ,
    required this.stops,
    required this.layers,
  });

  final double cameraZ;
  final double minZ;
  final double maxZ;
  final List<WorldDepthStop> stops;
  final List<WorldDepthLayer> layers;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = const Color(0xff6f817d)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      line,
    );
    double x(double z) => (z - minZ) / (maxZ - minZ) * size.width;
    for (final layer in layers) {
      canvas.drawCircle(
        Offset(x(layer.worldZ), size.height / 2),
        2.5,
        Paint()..color = const Color(0xffd2b65f),
      );
    }
    for (final stop in stops) {
      canvas.drawLine(
        Offset(x(stop.z), 4),
        Offset(x(stop.z), size.height - 4),
        Paint()
          ..color = const Color(0xffffe8aa)
          ..strokeWidth = 1,
      );
    }
    canvas.drawCircle(
      Offset(x(cameraZ.clamp(minZ, maxZ)), size.height / 2),
      6,
      Paint()..color = const Color(0xffa93439),
    );
  }

  @override
  bool shouldRepaint(_DepthRailPainter oldDelegate) =>
      oldDelegate.cameraZ != cameraZ ||
      oldDelegate.layers != layers ||
      oldDelegate.stops != stops;
}

class _CameraScrubber extends StatelessWidget {
  const _CameraScrubber({
    required this.cameraZ,
    required this.stops,
    required this.onChanged,
  });

  final double cameraZ;
  final List<WorldDepthStop> stops;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final calibration = worldDepthCameraCalibration;
    return _HudSurface(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 6),
      child: SizedBox(
        width: 820,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'CAMERA Z',
                  style: TextStyle(
                    color: Color(0xffffe8aa),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                Expanded(
                  child: Slider(
                    key: const Key('camera-z-scrubber'),
                    min: calibration.startZ,
                    max: calibration.terminalZ,
                    value: cameraZ,
                    label: cameraZ.toStringAsFixed(3),
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 58,
                  child: Text(
                    cameraZ.toStringAsFixed(3),
                    key: const Key('camera-z-value'),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 28,
              child: Stack(
                children: [
                  for (final stop in stops)
                    Align(
                      alignment: Alignment(
                        calibration.progressAtZ(stop.z) * 2 - 1,
                        0,
                      ),
                      child: Text(
                        '│ ${stop.label} ${stop.z.toStringAsFixed(1)}',
                        style: const TextStyle(
                          color: Color(0xffd2b65f),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreatControls extends StatelessWidget {
  const _ThreatControls({
    required this.threat,
    required this.state,
    required this.atmosphereEnabled,
    required this.onThreatChanged,
    required this.onAtmosphereChanged,
  });

  final double threat;
  final NorthThreatState state;
  final bool atmosphereEnabled;
  final ValueChanged<double> onThreatChanged;
  final ValueChanged<bool> onAtmosphereChanged;

  @override
  Widget build(BuildContext context) {
    return _HudSurface(
      padding: const EdgeInsets.fromLTRB(14, 4, 10, 4),
      child: SizedBox(
        width: 820,
        child: Row(
          children: [
            const Text(
              'NORTH THREAT / YEAR',
              style: TextStyle(
                color: Color(0xffffe8aa),
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            Expanded(
              child: Slider(
                key: const Key('north-threat-scrubber'),
                min: 0,
                max: 1,
                value: threat,
                label: 'Year ${state.year.toStringAsFixed(2)}',
                onChanged: onThreatChanged,
              ),
            ),
            SizedBox(
              width: 90,
              child: Text(
                '${threat.toStringAsFixed(3)} / Y${state.year.toStringAsFixed(2)}',
                key: const Key('north-threat-value'),
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Colors.white,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ATMOSPHERE',
              style: TextStyle(
                color: Color(0xffffe8aa),
                fontWeight: FontWeight.w700,
              ),
            ),
            Switch(
              key: const Key('north-atmosphere-toggle'),
              value: atmosphereEnabled,
              onChanged: onAtmosphereChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ManifestError extends StatelessWidget {
  const _ManifestError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xff091315),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'WORLD DEPTH MANIFEST FAILED\n\n$error\n\n'
            'Run: dart run tool/sync_world_depth_plates.dart',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xffffd782), fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _HudSurface extends StatelessWidget {
  const _HudSurface({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xe619282a),
        border: Border.all(color: const Color(0xff5f736f)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
