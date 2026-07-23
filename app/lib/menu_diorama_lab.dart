import 'dart:math' as math;

import 'package:flutter/material.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MenuDioramaLabApp());
}

class MenuDioramaLabApp extends StatelessWidget {
  const MenuDioramaLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz · Menu Diorama Lab',
      theme: ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'PTSansNarrow',
        useMaterial3: true,
      ),
      home: const MenuDioramaLabScreen(),
    );
  }
}

enum DioramaMenuPage {
  local('LOCAL GAME', Icons.agriculture),
  online('ONLINE GAME', Icons.public),
  howToPlay('HOW TO PLAY', Icons.menu_book),
  profile('PROFILE', Icons.person),
  settings('SETTINGS', Icons.settings);

  const DioramaMenuPage(this.label, this.icon);

  final String label;
  final IconData icon;
}

class MenuDioramaLabScreen extends StatefulWidget {
  const MenuDioramaLabScreen({super.key});

  @override
  State<MenuDioramaLabScreen> createState() => _MenuDioramaLabScreenState();
}

class _MenuDioramaLabScreenState extends State<MenuDioramaLabScreen> {
  DioramaMenuPage? _page;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff171712),
      body: Stack(
        children: [
          const Positioned.fill(child: MenuDioramaScene()),
          Positioned.fill(
            child: SafeArea(
              minimum: const EdgeInsets.all(24),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 820;
                  return Stack(
                    children: [
                      Align(
                        alignment: compact
                            ? Alignment.topCenter
                            : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: compact
                                ? constraints.maxWidth
                                : math.min(590, constraints.maxWidth * .39),
                          ),
                          child: _MenuPlacard(
                            compact: compact,
                            selected: _page,
                            onSelected: (page) => setState(() => _page = page),
                          ),
                        ),
                      ),
                      if (_page case final page?)
                        Positioned(
                          top: compact ? 155 : 72,
                          right: compact ? 8 : 20,
                          bottom: compact ? 8 : 34,
                          left: compact
                              ? 8
                              : math.min(620, constraints.maxWidth * .41),
                          child: _DestinationPlacard(
                            page: page,
                            onClose: () => setState(() => _page = null),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
          const Positioned(
            right: 16,
            bottom: 10,
            child: IgnorePointer(child: _LabCaption()),
          ),
        ],
      ),
    );
  }
}

class MenuDioramaScene extends StatefulWidget {
  const MenuDioramaScene({super.key});

  @override
  State<MenuDioramaScene> createState() => _MenuDioramaSceneState();
}

class _MenuDioramaSceneState extends State<MenuDioramaScene>
    with SingleTickerProviderStateMixin {
  static const _asset =
      'assets/art/field_plan/menu-village-day-underlay-v1.png';

  late final AnimationController _ambientClock;
  Offset _pointer = Offset.zero;
  bool _motionEnabled = true;

  @override
  void initState() {
    super.initState();
    _ambientClock = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final enabled = !MediaQuery.disableAnimationsOf(context);
    if (_motionEnabled == enabled) return;
    _motionEnabled = enabled;
    if (enabled) {
      _ambientClock.repeat();
    } else {
      _ambientClock.stop();
    }
  }

  @override
  void dispose() {
    _ambientClock.dispose();
    super.dispose();
  }

  void _updatePointer(PointerEvent event, Size size) {
    if (!_motionEnabled || size.isEmpty) return;
    final x = (event.localPosition.dx / size.width * 2 - 1).clamp(-1.0, 1.0);
    final y = (event.localPosition.dy / size.height * 2 - 1).clamp(-1.0, 1.0);
    setState(() => _pointer = Offset(x, y));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return MouseRegion(
          key: const Key('menu-diorama-pointer-surface'),
          cursor: SystemMouseCursors.basic,
          onHover: (event) => _updatePointer(event, size),
          onExit: (_) {
            if (_motionEnabled) setState(() => _pointer = Offset.zero);
          },
          child: AnimatedBuilder(
            animation: _ambientClock,
            builder: (context, _) {
              final t = _motionEnabled ? _ambientClock.value : 0.18;
              return Stack(
                key: const Key('menu-diorama-scene'),
                fit: StackFit.expand,
                children: [
                  Transform.translate(
                    key: const Key('menu-diorama-base'),
                    offset: _parallax(-1.5),
                    child: Image.asset(
                      _asset,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                  ),
                  const _SceneWash(),
                  _PaperLayer(
                    key: const Key('menu-diorama-far-layer'),
                    asset: _asset,
                    clipper: const _FarIndustryClipper(),
                    offset: _parallax(1.8),
                    elevation: 2,
                  ),
                  _PaperLayer(
                    key: const Key('menu-diorama-middle-layer'),
                    asset: _asset,
                    clipper: const _MiddleFieldsClipper(),
                    offset: _parallax(4),
                    elevation: 5,
                  ),
                  _PaperLayer(
                    key: const Key('menu-diorama-near-layer'),
                    asset: _asset,
                    clipper: const _ForegroundCropsClipper(),
                    offset: _parallax(7),
                    elevation: 9,
                  ),
                  Transform.translate(
                    offset: _parallax(2.4),
                    child: CustomPaint(
                      key: const Key('menu-diorama-ambient-life'),
                      painter: _AmbientLifePainter(
                        phase: t,
                        motionEnabled: _motionEnabled,
                      ),
                    ),
                  ),
                  const IgnorePointer(child: _PaperGrainVignette()),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Offset _parallax(double depth) {
    if (!_motionEnabled) return Offset.zero;
    return Offset(-_pointer.dx * depth, -_pointer.dy * depth * .52);
  }
}

class _PaperLayer extends StatelessWidget {
  const _PaperLayer({
    super.key,
    required this.asset,
    required this.clipper,
    required this.offset,
    required this.elevation,
  });

  final String asset;
  final CustomClipper<Path> clipper;
  final Offset offset;
  final double elevation;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: PhysicalShape(
        clipper: clipper,
        clipBehavior: Clip.antiAlias,
        color: const Color(0x01000000),
        shadowColor: const Color(0xcc0c0d0a),
        elevation: elevation,
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
      ),
    );
  }
}

class _FarIndustryClipper extends CustomClipper<Path> {
  const _FarIndustryClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * .07)
    ..lineTo(size.width, size.height * .07)
    ..lineTo(size.width, size.height * .40)
    ..cubicTo(
      size.width * .72,
      size.height * .39,
      size.width * .42,
      size.height * .42,
      0,
      size.height * .44,
    )
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MiddleFieldsClipper extends CustomClipper<Path> {
  const _MiddleFieldsClipper();

  @override
  Path getClip(Size size) => Path()
    ..moveTo(0, size.height * .35)
    ..lineTo(size.width, size.height * .34)
    ..lineTo(size.width, size.height * .72)
    ..lineTo(size.width * .79, size.height * .67)
    ..lineTo(size.width * .58, size.height * .73)
    ..lineTo(size.width * .39, size.height * .62)
    ..lineTo(size.width * .18, size.height * .59)
    ..lineTo(0, size.height * .64)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ForegroundCropsClipper extends CustomClipper<Path> {
  const _ForegroundCropsClipper();

  @override
  Path getClip(Size size) {
    final path = Path()
      ..moveTo(0, size.height * .49)
      ..lineTo(size.width * .26, size.height * .49)
      ..lineTo(size.width * .57, size.height * .69)
      ..lineTo(size.width * .52, size.height)
      ..lineTo(0, size.height)
      ..close()
      ..moveTo(size.width * .55, size.height)
      ..lineTo(size.width * .62, size.height * .74)
      ..lineTo(size.width, size.height * .70)
      ..lineTo(size.width, size.height)
      ..close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _SceneWash extends StatelessWidget {
  const _SceneWash();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xcc151713), Color(0x55151713), Color(0x00151713)],
          stops: [0, .32, .68],
        ),
      ),
    );
  }
}

class _AmbientLifePainter extends CustomPainter {
  const _AmbientLifePainter({required this.phase, required this.motionEnabled});

  final double phase;
  final bool motionEnabled;

  @override
  void paint(Canvas canvas, Size size) {
    _paintWindows(canvas, size);
    _paintSmoke(canvas, size);
    _paintFlag(canvas, size);
    _paintTractor(canvas, size);
  }

  void _paintWindows(Canvas canvas, Size size) {
    final flicker = motionEnabled
        ? .76 + .16 * math.sin(phase * math.pi * 8)
        : .82;
    final glow = Paint()
      ..color = const Color(0xffffbf55).withValues(alpha: flicker)
      ..blendMode = BlendMode.screen;
    final dark = Paint()..color = const Color(0xff302416);
    final units = <Offset>[
      const Offset(.427, .302),
      const Offset(.438, .302),
      const Offset(.449, .302),
      const Offset(.462, .302),
      const Offset(.476, .302),
      const Offset(.489, .302),
      const Offset(.849, .519),
      const Offset(.863, .519),
      const Offset(.849, .535),
      const Offset(.863, .535),
    ];
    final windowSize = Size(
      math.max(2.4, size.width * .0032),
      math.max(2.2, size.height * .005),
    );
    for (final unit in units) {
      final rect = Rect.fromCenter(
        center: Offset(unit.dx * size.width, unit.dy * size.height),
        width: windowSize.width + 1.5,
        height: windowSize.height + 1.5,
      );
      canvas.drawRect(rect, dark);
      canvas.drawRect(rect.deflate(.7), glow);
    }
  }

  void _paintSmoke(Canvas canvas, Size size) {
    final drift = motionEnabled ? math.sin(phase * math.pi * 2) : .2;
    final progress = motionEnabled ? phase : .22;
    final ink = Paint()..color = const Color(0xa8d7bd82);
    final outline = Paint()
      ..color = const Color(0x8a26271f)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, size.width / 1500);
    for (var chimney = 0; chimney < 2; chimney++) {
      final origin = Offset(
        size.width * (.487 + chimney * .024),
        size.height * .194,
      );
      for (var puff = 0; puff < 5; puff++) {
        final local = (progress + puff * .17 + chimney * .08) % 1;
        final center =
            origin +
            Offset(
              size.width * (.012 * local + .0025 * drift),
              -size.height * (.11 * local),
            );
        final radius = size.shortestSide * (.006 + local * .008);
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2.4,
            height: radius * 1.15,
          ),
          ink..color = ink.color.withValues(alpha: .62 * (1 - local)),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: radius * 2.4,
            height: radius * 1.15,
          ),
          outline..color = outline.color.withValues(alpha: .35 * (1 - local)),
        );
      }
    }
  }

  void _paintFlag(Canvas canvas, Size size) {
    final wave = motionEnabled ? math.sin(phase * math.pi * 10) : 0;
    final poleX = size.width * .625;
    final poleTop = size.height * .51;
    final poleBottom = size.height * .61;
    canvas.drawLine(
      Offset(poleX, poleTop),
      Offset(poleX, poleBottom),
      Paint()
        ..color = const Color(0xff25251d)
        ..strokeWidth = math.max(1.2, size.width / 1050),
    );
    canvas.drawPath(
      Path()
        ..moveTo(poleX, poleTop)
        ..quadraticBezierTo(
          poleX + size.width * .015,
          poleTop + wave * 2,
          poleX + size.width * .029,
          poleTop + size.height * .006,
        )
        ..lineTo(
          poleX + size.width * .029,
          poleTop + size.height * .035 + wave * 1.4,
        )
        ..quadraticBezierTo(
          poleX + size.width * .015,
          poleTop + size.height * .026,
          poleX,
          poleTop + size.height * .032,
        )
        ..close(),
      Paint()..color = const Color(0xffb83323),
    );
  }

  void _paintTractor(Canvas canvas, Size size) {
    final active = motionEnabled && phase > .58 && phase < .86;
    if (!active) return;
    final progress = ((phase - .58) / .28).clamp(0.0, 1.0);
    final center = Offset(
      size.width * (.57 + progress * .16),
      size.height * (.48 + progress * .035),
    );
    final scale = math.max(7.0, size.shortestSide * .012);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(.13);
    final outline = Paint()..color = const Color(0xff22231c);
    final red = Paint()..color = const Color(0xffa52f20);
    canvas.drawRect(
      Rect.fromLTWH(-scale, -scale * .34, scale * 1.6, scale * .5),
      outline,
    );
    canvas.drawRect(
      Rect.fromLTWH(-scale * .92, -scale * .27, scale * 1.42, scale * .34),
      red,
    );
    canvas.drawRect(
      Rect.fromLTWH(-scale * .17, -scale * .72, scale * .48, scale * .48),
      outline,
    );
    canvas.drawCircle(Offset(-scale * .58, scale * .2), scale * .28, outline);
    canvas.drawCircle(Offset(scale * .42, scale * .18), scale * .2, outline);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmbientLifePainter oldDelegate) =>
      phase != oldDelegate.phase || motionEnabled != oldDelegate.motionEnabled;
}

class _PaperGrainVignette extends StatelessWidget {
  const _PaperGrainVignette();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0x99211e17), width: 8),
        gradient: const RadialGradient(
          radius: 1.05,
          colors: [Colors.transparent, Color(0x52110f0c)],
          stops: [.58, 1],
        ),
      ),
    );
  }
}

class _MenuPlacard extends StatelessWidget {
  const _MenuPlacard({
    required this.compact,
    required this.selected,
    required this.onSelected,
  });

  final bool compact;
  final DioramaMenuPage? selected;
  final ValueChanged<DioramaMenuPage> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PaperPanel(
          color: const Color(0xffded0aa),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 20 : 28,
            vertical: compact ? 12 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '★  KOLKHOZ',
                style: TextStyle(
                  color: const Color(0xffa6291e),
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 42 : 66,
                  height: .9,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'A COLLECTIVE CARD GAME',
                style: TextStyle(
                  color: Color(0xff20221d),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.1,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: compact ? 8 : 14),
        if (!compact) ...[
          _MenuButton(
            page: DioramaMenuPage.local,
            selected: selected == DioramaMenuPage.local,
            onPressed: onSelected,
          ),
          const SizedBox(height: 10),
          _MenuButton(
            page: DioramaMenuPage.online,
            selected: selected == DioramaMenuPage.online,
            onPressed: onSelected,
          ),
          const SizedBox(height: 10),
          _MenuButton(
            page: DioramaMenuPage.howToPlay,
            selected: selected == DioramaMenuPage.howToPlay,
            onPressed: onSelected,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _UtilityButton(
                  page: DioramaMenuPage.profile,
                  onPressed: onSelected,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UtilityButton(
                  page: DioramaMenuPage.settings,
                  onPressed: onSelected,
                ),
              ),
            ],
          ),
        ] else
          Row(
            children: [
              for (final page in DioramaMenuPage.values.take(3)) ...[
                Expanded(
                  child: _CompactMenuButton(page: page, onPressed: onSelected),
                ),
                if (page != DioramaMenuPage.howToPlay) const SizedBox(width: 6),
              ],
            ],
          ),
      ],
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({
    required this.page,
    required this.selected,
    required this.onPressed,
  });

  final DioramaMenuPage page;
  final bool selected;
  final ValueChanged<DioramaMenuPage> onPressed;

  @override
  Widget build(BuildContext context) {
    final fill = selected || page == DioramaMenuPage.local
        ? const Color(0xffaa3022)
        : const Color(0xffd8c79e);
    final ink = selected || page == DioramaMenuPage.local
        ? const Color(0xfff0dfb7)
        : const Color(0xff20221d);
    return _PaperPanel(
      color: fill,
      padding: EdgeInsets.zero,
      child: InkWell(
        key: Key('menu-diorama-${page.name}'),
        onTap: () => onPressed(page),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 17),
          child: Row(
            children: [
              Icon(page.icon, size: 38, color: ink),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  page.label,
                  style: TextStyle(
                    color: ink,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    height: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMenuButton extends StatelessWidget {
  const _CompactMenuButton({required this.page, required this.onPressed});

  final DioramaMenuPage page;
  final ValueChanged<DioramaMenuPage> onPressed;

  @override
  Widget build(BuildContext context) {
    return _PaperPanel(
      color: const Color(0xffd8c79e),
      padding: EdgeInsets.zero,
      child: IconButton(
        key: Key('menu-diorama-${page.name}'),
        tooltip: page.label,
        onPressed: () => onPressed(page),
        color: const Color(0xff20221d),
        icon: Icon(page.icon),
      ),
    );
  }
}

class _UtilityButton extends StatelessWidget {
  const _UtilityButton({required this.page, required this.onPressed});

  final DioramaMenuPage page;
  final ValueChanged<DioramaMenuPage> onPressed;

  @override
  Widget build(BuildContext context) {
    return _PaperPanel(
      color: const Color(0xe921231f),
      padding: EdgeInsets.zero,
      child: TextButton.icon(
        key: Key('menu-diorama-${page.name}'),
        onPressed: () => onPressed(page),
        icon: Icon(page.icon, color: const Color(0xffcfb77f)),
        label: Text(
          page.label,
          style: const TextStyle(
            color: Color(0xffdfc994),
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _DestinationPlacard extends StatelessWidget {
  const _DestinationPlacard({required this.page, required this.onClose});

  final DioramaMenuPage page;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return _PaperPanel(
      key: const Key('menu-diorama-destination'),
      color: const Color(0xf0d8c89f),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(page.icon, color: const Color(0xff9d2c20), size: 34),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  page.label,
                  style: const TextStyle(
                    color: Color(0xff23241e),
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              IconButton(
                key: const Key('menu-diorama-close'),
                onPressed: onClose,
                color: const Color(0xff23241e),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(color: Color(0xff8f7d57), height: 32),
          const Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'THE VILLAGE NEVER LEAVES THE ROOM.',
                    style: TextStyle(
                      color: Color(0xff9d2c20),
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      letterSpacing: 2,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'This temporary paper panel demonstrates the intended menu '
                    'architecture: destination content occludes most of the '
                    'world, while the sharp, living diorama remains visible '
                    'around every edge.',
                    style: TextStyle(
                      color: Color(0xff34352d),
                      fontFamily: 'PTSans',
                      fontSize: 18,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.bottomRight,
            child: FilledButton.icon(
              onPressed: onClose,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xffa42d20),
                foregroundColor: const Color(0xffeeddb4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
              ),
              icon: const Icon(Icons.arrow_back),
              label: const Text(
                'RETURN TO THE YARD',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaperPanel extends StatelessWidget {
  const _PaperPanel({
    super.key,
    required this.color,
    required this.child,
    required this.padding,
  });

  final Color color;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: const Color(0xff292820), width: 3),
        boxShadow: const [
          BoxShadow(
            color: Color(0xaa11120f),
            offset: Offset(7, 9),
            blurRadius: 0,
          ),
          BoxShadow(
            color: Color(0x552b2418),
            offset: Offset(2, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _LabCaption extends StatelessWidget {
  const _LabCaption();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(color: Color(0xbb1b1c18)),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          'AMBIENT DIORAMA PROOF · MOVE POINTER',
          style: TextStyle(
            color: Color(0xffd6c38e),
            fontSize: 11,
            letterSpacing: 1.4,
          ),
        ),
      ),
    );
  }
}
