import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StaticHeroPanelsLabApp());
}

enum StaticHeroPanel { brigade, fields, north }

extension on StaticHeroPanel {
  String get label => switch (this) {
    StaticHeroPanel.brigade => 'BRIGADE',
    StaticHeroPanel.fields => 'FIELDS',
    StaticHeroPanel.north => 'NORTH',
  };

  String get subtitle => switch (this) {
    StaticHeroPanel.brigade => 'PLOTS · COMMUNAL TRICK',
    StaticHeroPanel.fields => 'WORKER ASSIGNMENT',
    StaticHeroPanel.north => 'REMOVED CARDS · YEAR 3',
  };

  String get rasterUnderlay =>
      'assets/art/field_plan/game/backgrounds/'
      'static-hero-$name-underlay-v1.png';
}

class StaticHeroPanelsLabApp extends StatelessWidget {
  const StaticHeroPanelsLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz · Static Hero Panels Lab',
      theme: ThemeData(
        fontFamily: 'PTSansNarrow',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xffb82d1f),
          brightness: Brightness.light,
        ),
      ),
      home: const StaticHeroPanelsLabScreen(),
    );
  }
}

class StaticHeroPanelsLabScreen extends StatefulWidget {
  const StaticHeroPanelsLabScreen({super.key});

  @override
  State<StaticHeroPanelsLabScreen> createState() =>
      _StaticHeroPanelsLabScreenState();
}

class _StaticHeroPanelsLabScreenState extends State<StaticHeroPanelsLabScreen> {
  StaticHeroPanel panel = StaticHeroPanel.brigade;
  int transitionDirection = 1;
  Duration transitionDuration = const Duration(milliseconds: 320);
  double dragDistance = 0;
  bool hasTransitioned = false;

  void _selectPanel(StaticHeroPanel next, {bool fast = false, int? direction}) {
    if (next == panel) return;
    setState(() {
      transitionDirection = direction ?? (next.index > panel.index ? 1 : -1);
      transitionDuration = Duration(milliseconds: fast ? 105 : 240);
      hasTransitioned = true;
      panel = next;
    });
  }

  void _move(int delta, {bool fast = false}) {
    final next = (panel.index + delta).clamp(
      0,
      StaticHeroPanel.values.length - 1,
    );
    _selectPanel(
      StaticHeroPanel.values[next],
      fast: fast,
      direction: delta.sign,
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy.abs() < 8) return;
    _move(event.scrollDelta.dy > 0 ? 1 : -1, fast: true);
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.digit1): () =>
            _selectPanel(StaticHeroPanel.brigade, fast: true),
        const SingleActivator(LogicalKeyboardKey.digit2): () =>
            _selectPanel(StaticHeroPanel.fields, fast: true),
        const SingleActivator(LogicalKeyboardKey.digit3): () =>
            _selectPanel(StaticHeroPanel.north, fast: true),
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _move(-1, fast: true),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _move(1, fast: true),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: const Color(0xff181712),
          body: SafeArea(
            child: Listener(
              onPointerSignal: _handlePointerSignal,
              child: GestureDetector(
                key: const Key('static-hero-navigation-surface'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => dragDistance = 0,
                onHorizontalDragUpdate: (details) {
                  dragDistance += details.delta.dx;
                },
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  final direction = velocity.abs() > 120
                      ? -velocity.sign.toInt()
                      : dragDistance.abs() > 52
                      ? -dragDistance.sign.toInt()
                      : 0;
                  if (direction != 0) {
                    _move(direction, fast: velocity.abs() > 900);
                  }
                },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 760;
                    final handHeight = compact ? 92.0 : 122.0;
                    return Stack(
                      children: [
                        Positioned.fill(
                          bottom: handHeight,
                          child: AnimatedSwitcher(
                            duration: transitionDuration,
                            reverseDuration: transitionDuration,
                            switchInCurve: Curves.easeOutQuart,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) {
                              return _PosterPanelTransition(
                                animation: animation,
                                direction: transitionDirection,
                                child: child,
                              );
                            },
                            child: _StaticHeroComposition(
                              key: ValueKey(panel),
                              panel: panel,
                              compact: compact,
                            ),
                          ),
                        ),
                        if (hasTransitioned)
                          Positioned.fill(
                            bottom: handHeight,
                            child: _PosterSceneWipe(
                              key: ValueKey('poster-wipe-${panel.name}'),
                              duration: transitionDuration,
                              direction: transitionDirection,
                            ),
                          ),
                        Positioned(
                          top: compact ? 8 : 14,
                          left: compact ? 8 : 16,
                          right: compact ? 8 : 16,
                          child: _PosterNavigation(
                            panel: panel,
                            compact: compact,
                            onSelected: _selectPanel,
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: handHeight,
                          child: _PermanentHandTray(compact: compact),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PosterPanelTransition extends StatelessWidget {
  const _PosterPanelTransition({
    required this.animation,
    required this.direction,
    required this.child,
  });

  final Animation<double> animation;
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final slide = Tween<Offset>(
      begin: Offset(direction * 0.075, 0),
      end: Offset.zero,
    ).animate(animation);
    return FadeTransition(
      opacity: animation,
      child: SlideTransition(position: slide, child: child),
    );
  }
}

class _PosterSceneWipe extends StatelessWidget {
  const _PosterSceneWipe({
    required this.duration,
    required this.direction,
    super.key,
  });

  final Duration duration;
  final int direction;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) {
          final veil = math.sin(progress * math.pi).clamp(0.0, 1.0);
          return CustomPaint(
            key: const Key('static-hero-poster-wipe'),
            painter: _PosterWipePainter(
              progress: progress,
              direction: direction,
              opacity: veil,
            ),
          );
        },
      ),
    );
  }
}

class _PosterWipePainter extends CustomPainter {
  const _PosterWipePainter({
    required this.progress,
    required this.direction,
    required this.opacity,
  });

  final double progress;
  final int direction;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final travel = direction > 0 ? progress : 1 - progress;
    final center = size.width * (-0.18 + travel * 1.36);
    final width = size.width * 0.22;
    final red = Paint()
      ..color = const Color(0xffb52b1d).withValues(alpha: opacity);
    final cream = Paint()
      ..color = const Color(0xffffe3aa).withValues(alpha: opacity * 0.92);
    canvas.drawPath(
      Path()
        ..moveTo(center - width, 0)
        ..lineTo(center + width * 0.18, 0)
        ..lineTo(center + width, size.height)
        ..lineTo(center - width * 0.2, size.height)
        ..close(),
      red,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center - width * 1.16, 0)
        ..lineTo(center - width * 0.82, 0)
        ..lineTo(center, size.height)
        ..lineTo(center - width * 0.34, size.height)
        ..close(),
      cream,
    );
    final vehicleY = size.height * 0.54;
    final vehicleX = center - width * 0.18;
    final vehicle = Paint()
      ..color = const Color(0xff20231f).withValues(alpha: opacity);
    canvas.drawRect(
      Rect.fromLTWH(vehicleX, vehicleY, width * 0.34, width * 0.09),
      vehicle,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        vehicleX + width * 0.22,
        vehicleY - width * 0.075,
        width * 0.1,
        width * 0.16,
      ),
      vehicle,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        vehicleX + width * 0.25,
        vehicleY - width * 0.055,
        width * 0.035,
        width * 0.04,
      ),
      Paint()..color = const Color(0xffffe3aa).withValues(alpha: opacity),
    );
    for (final wheelX in [vehicleX + width * 0.08, vehicleX + width * 0.27]) {
      canvas.drawCircle(
        Offset(wheelX, vehicleY + width * 0.095),
        width * 0.045,
        vehicle,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PosterWipePainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.direction != direction ||
      oldDelegate.opacity != opacity;
}

class _PosterNavigation extends StatelessWidget {
  const _PosterNavigation({
    required this.panel,
    required this.compact,
    required this.onSelected,
  });

  final StaticHeroPanel panel;
  final bool compact;
  final ValueChanged<StaticHeroPanel> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: const BoxDecoration(color: Color(0xffefe0b7)),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 13,
              vertical: compact ? 5 : 8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  panel.label,
                  style: TextStyle(
                    color: const Color(0xffb52b1d),
                    fontSize: compact ? 18 : 26,
                    height: 0.95,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                  ),
                ),
                if (!compact)
                  Text(
                    panel.subtitle,
                    style: const TextStyle(
                      color: Color(0xff20231f),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const Spacer(),
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xffefe0b7),
            border: Border.all(color: const Color(0xff20231f), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final candidate in StaticHeroPanel.values)
                _PosterTab(
                  panel: candidate,
                  selected: candidate == panel,
                  compact: compact,
                  onTap: () => onSelected(candidate),
                ),
            ],
          ),
        ),
        if (!compact) ...[const SizedBox(width: 10), const _MiniHud()],
      ],
    );
  }
}

class _PosterTab extends StatelessWidget {
  const _PosterTab({
    required this.panel,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final StaticHeroPanel panel;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: Key('static-hero-tab-${panel.name}'),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 16,
          vertical: compact ? 9 : 12,
        ),
        color: selected ? const Color(0xffb52b1d) : Colors.transparent,
        child: Text(
          panel.label,
          style: TextStyle(
            color: selected ? const Color(0xffffecc2) : const Color(0xff20231f),
            fontSize: compact ? 11 : 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),
      ),
    );
  }
}

class _MiniHud extends StatelessWidget {
  const _MiniHud();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('static-hero-mini-hud'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      color: const Color(0xff20231f),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _HudDatum(value: '3', label: 'YEAR'),
          SizedBox(width: 15),
          _HudDatum(value: '40', label: 'TARGET'),
          SizedBox(width: 15),
          _HudDatum(value: '18', label: 'SCORE'),
        ],
      ),
    );
  }
}

class _HudDatum extends StatelessWidget {
  const _HudDatum({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xffffdc65),
            fontSize: 19,
            height: 0.95,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xffffecc2),
            fontSize: 8,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _StaticHeroComposition extends StatelessWidget {
  const _StaticHeroComposition({
    required this.panel,
    required this.compact,
    super.key,
  });

  final StaticHeroPanel panel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        key: Key('static-hero-panel-${panel.name}'),
        fit: StackFit.expand,
        children: [
          Image.asset(
            panel.rasterUnderlay,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) =>
                CustomPaint(painter: _StaticHeroPainter(panel)),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.055,
                child: Image.asset(
                  'assets/art/field_plan/shared/textures/paper-light.png',
                  fit: BoxFit.cover,
                  colorBlendMode: BlendMode.multiply,
                  color: const Color(0xff8d7957),
                ),
              ),
            ),
          ),
          CustomPaint(painter: _StaticHeroInformationPainter(panel)),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    for (final spec in _cardSpecs(panel))
                      _PlacedGameCard(
                        spec: spec,
                        size: constraints.biggest,
                        compact: compact,
                      ),
                    if (panel == StaticHeroPanel.north)
                      _EmptyYearMarker(
                        size: constraints.biggest,
                        compact: compact,
                      ),
                  ],
                );
              },
            ),
          ),
          Positioned(
            left: compact ? 10 : 18,
            bottom: compact ? 8 : 14,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xffead8ab).withValues(alpha: 0.90),
                border: Border.all(
                  color: const Color(0xff24251f).withValues(alpha: 0.72),
                  width: 0.8,
                ),
                boxShadow: const [
                  BoxShadow(color: Color(0x6621251f), offset: Offset(2, 2)),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 6 : 8,
                  vertical: compact ? 3 : 4,
                ),
                child: Text(
                  compact ? 'FLICK OR TAP' : 'FLICK · TABS · KEYS 1—3',
                  style: TextStyle(
                    color: const Color(0xff24251f),
                    fontSize: compact ? 9 : 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyYearMarker extends StatelessWidget {
  const _EmptyYearMarker({required this.size, required this.compact});

  final Size size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final width = (size.width * (compact ? 0.055 : 0.048)).clamp(34.0, 58.0);
    final height = width * 1.28;
    return Positioned(
      key: const Key('static-north-empty-year-3'),
      left: size.width * 0.49 - width / 2,
      top: size.height * 0.44 - height / 2,
      child: Transform.rotate(
        angle: -0.025,
        child: CustomPaint(
          size: Size(width, height),
          painter: _EmptyYearCardPainter(),
        ),
      ),
    );
  }
}

class _EmptyYearCardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const ink = Color(0xff20231f);
    const cream = Color(0xffffe3aa);
    const red = Color(0xffb52b1d);
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.09,
        size.height * 0.09,
        size.width,
        size.height,
      ),
      Paint()..color = ink.withValues(alpha: 0.72),
    );
    canvas.drawRect(Offset.zero & size, Paint()..color = cream);
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final check = Paint()
      ..color = red
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(4, size.width * 0.11)
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(
      Offset(size.width * 0.22, size.height * 0.53),
      Offset(size.width * 0.43, size.height * 0.72),
      check,
    );
    canvas.drawLine(
      Offset(size.width * 0.43, size.height * 0.72),
      Offset(size.width * 0.8, size.height * 0.27),
      check,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _PlacedGameCard extends StatelessWidget {
  const _PlacedGameCard({
    required this.spec,
    required this.size,
    required this.compact,
  });

  final _CardSpec spec;
  final Size size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final baseScale = (size.width / 1200).clamp(0.62, 1.08);
    final scale = baseScale * spec.scale * (compact ? 1.22 : 1.42);
    final cardSize = _scaledCardSize(lightDesignTokens.card.small, scale);
    return Positioned(
      key: Key('static-${spec.id}'),
      left: size.width * spec.x - cardSize.width / 2,
      top: size.height * spec.y - cardSize.height / 2,
      child: Transform.rotate(
        angle: spec.turns,
        child: SizedBox(
          width: cardSize.width,
          height: cardSize.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _CardSlabShadowPainter(
                    length: cardSize.width * spec.shadowLength,
                  ),
                ),
              ),
              Positioned.fill(
                child: GameCard(
                  card: TableCard(
                    id: spec.id,
                    suit: spec.suit,
                    value: spec.value,
                    rank: _rank(spec.value),
                    selected: false,
                    highlighted: false,
                    pending: false,
                  ),
                  tokens: lightDesignTokens,
                  trump: 'beet',
                  sizeOverride: cardSize,
                  motionTracked: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardSlabShadowPainter extends CustomPainter {
  const _CardSlabShadowPainter({required this.length});

  final double length;

  @override
  void paint(Canvas canvas, Size size) {
    final offset = Offset(length, length * 0.72);
    canvas.drawPath(
      Path()
        ..moveTo(size.width * 0.08 + offset.dx, size.height * 0.08 + offset.dy)
        ..lineTo(size.width + offset.dx, offset.dy)
        ..lineTo(size.width + offset.dx, size.height + offset.dy)
        ..lineTo(offset.dx, size.height + offset.dy)
        ..close(),
      Paint()..color = const Color(0xff20231f).withValues(alpha: 0.74),
    );
    canvas.drawRect(
      Rect.fromLTWH(2, size.height - 3, size.width - 4, 4),
      Paint()..color = const Color(0xff8f3a27),
    );
  }

  @override
  bool shouldRepaint(covariant _CardSlabShadowPainter oldDelegate) =>
      oldDelegate.length != length;
}

class _PermanentHandTray extends StatelessWidget {
  const _PermanentHandTray({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = _handCards;
    return Container(
      key: const Key('static-hero-hand-tray'),
      decoration: const BoxDecoration(
        color: Color(0xff171914),
        border: Border(top: BorderSide(color: Color(0xffead8a8), width: 3)),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 46,
            child: ColoredBox(color: Color(0xffb52b1d)),
          ),
          Positioned(
            left: compact ? 12 : 64,
            top: compact ? 8 : 12,
            child: Text(
              compact ? 'HAND' : 'YOUR HAND',
              style: TextStyle(
                color: const Color(0xffffecc2),
                fontSize: compact ? 12 : 17,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          Align(
            alignment: Alignment.center,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = compact ? 1.08 : 1.48;
                final size = _scaledCardSize(
                  lightDesignTokens.card.small,
                  scale,
                );
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final card in cards)
                      Padding(
                        padding: EdgeInsets.only(left: compact ? 2 : 5),
                        child: GameCard(
                          key: Key('static-hand-${card.id}'),
                          card: card,
                          tokens: lightDesignTokens,
                          trump: 'beet',
                          sizeOverride: size,
                          motionTracked: false,
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          if (!compact)
            const Positioned(
              right: 20,
              top: 18,
              child: Text(
                'YOUR TURN',
                style: TextStyle(
                  color: Color(0xffffdc65),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StaticHeroInformationPainter extends CustomPainter {
  const _StaticHeroInformationPainter(this.panel);

  final StaticHeroPanel panel;

  static const ink = Color(0xff20231f);
  static const cream = Color(0xffffe3aa);
  static const red = Color(0xffb52b1d);

  @override
  void paint(Canvas canvas, Size size) {
    switch (panel) {
      case StaticHeroPanel.brigade:
        break;
      case StaticHeroPanel.fields:
        const fields = [
          ('WHEAT', 31, Offset(0.075, 0.475)),
          ('BEET', 22, Offset(0.78, 0.475)),
          ('SUNFLOWER', 36, Offset(0.075, 0.84)),
          ('POTATO', 18, Offset(0.78, 0.84)),
        ];
        for (final field in fields) {
          _paintJobPlacard(canvas, size, field.$1, field.$2, field.$3);
        }
      case StaticHeroPanel.north:
        const plaques = [
          Offset(0.345, 0.19),
          Offset(0.295, 0.29),
          Offset(0.235, 0.395),
          Offset(0.175, 0.525),
          Offset(0.115, 0.685),
        ];
        for (var year = 0; year < plaques.length; year++) {
          _paintYearPlaque(canvas, size, year + 1, plaques[year]);
        }
    }
  }

  void _paintJobPlacard(
    Canvas canvas,
    Size size,
    String text,
    int hours,
    Offset point,
  ) {
    final label = _text(text, math.max(9, size.width * 0.011), cream);
    final progress = _text('$hours/40', math.max(10, size.width * 0.012), red);
    final rect = Rect.fromLTWH(
      point.dx * size.width,
      point.dy * size.height,
      label.width + progress.width + 24,
      math.max(label.height, progress.height) + 8,
    );
    canvas.drawRect(
      rect.shift(Offset(size.width * 0.006, size.height * 0.009)),
      Paint()..color = red,
    );
    canvas.drawRect(rect, Paint()..color = ink);
    label.paint(canvas, rect.topLeft + const Offset(6, 4));
    progress.paint(
      canvas,
      Offset(rect.right - progress.width - 6, rect.top + 3),
    );
  }

  void _paintYearPlaque(Canvas canvas, Size size, int year, Offset point) {
    final label = _text('YEAR $year', math.max(8, size.width * 0.01), ink);
    final rect = Rect.fromLTWH(
      point.dx * size.width,
      point.dy * size.height,
      label.width + 18,
      label.height + 7,
    );
    canvas.drawRect(
      rect.shift(Offset(size.width * 0.006, size.height * 0.009)),
      Paint()..color = ink.withValues(alpha: 0.72),
    );
    canvas.drawRect(rect, Paint()..color = cream);
    label.paint(canvas, rect.topLeft + const Offset(9, 3));
  }

  TextPainter _text(String text, double size, Color color) => TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'PTSansNarrow',
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  bool shouldRepaint(covariant _StaticHeroInformationPainter oldDelegate) =>
      oldDelegate.panel != panel;
}

class _StaticHeroPainter extends CustomPainter {
  _StaticHeroPainter(this.panel);

  final StaticHeroPanel panel;

  static const ink = Color(0xff20231f);
  static const cream = Color(0xffffe3aa);
  static const paper = Color(0xffe5cd91);
  static const red = Color(0xffb52b1d);
  static const green = Color(0xffaab85c);
  static const olive = Color(0xff77834b);
  static const ochre = Color(0xffc9a34f);
  static const snow = Color(0xffe9ddbb);
  static const rust = Color(0xff8f3a27);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = paper);
    switch (panel) {
      case StaticHeroPanel.brigade:
        _paintBrigade(canvas, size);
      case StaticHeroPanel.fields:
        _paintFields(canvas, size);
      case StaticHeroPanel.north:
        _paintNorth(canvas, size);
    }
    _paintRegistration(canvas, size);
  }

  void _paintBrigade(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.27),
      Paint()..color = ink,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.22),
        Offset(0.32, 0.12),
        Offset(0.62, 0.2),
        Offset(1, 0.09),
        Offset(1, 0.31),
        Offset(0, 0.31),
      ]),
      Paint()..color = cream,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.27, size.width, size.height * 0.73),
      Paint()..color = green,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.27),
        Offset(0.48, 0.27),
        Offset(0.37, 1),
        Offset(0, 1),
      ]),
      Paint()..color = olive,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0.73, 0.27),
        Offset(1, 0.27),
        Offset(1, 0.72),
        Offset(0.83, 0.6),
      ]),
      Paint()..color = ochre,
    );
    _paintFactory(canvas, size, left: 0.055, top: 0.105, scale: 1.05);
    _paintBridge(canvas, size);
    _paintPowerLines(canvas, size, 0.205);

    final plots = <(Path, Color, String)>[
      (
        _poly(size, const [
          Offset(0.055, 0.34),
          Offset(0.36, 0.29),
          Offset(0.43, 0.47),
          Offset(0.1, 0.53),
        ]),
        ochre,
        'I',
      ),
      (
        _poly(size, const [
          Offset(0.64, 0.29),
          Offset(0.95, 0.35),
          Offset(0.9, 0.53),
          Offset(0.57, 0.47),
        ]),
        paper,
        'II',
      ),
      (
        _poly(size, const [
          Offset(0.1, 0.58),
          Offset(0.43, 0.52),
          Offset(0.38, 0.86),
          Offset(0.025, 0.8),
        ]),
        paper,
        'III',
      ),
      (
        _poly(size, const [
          Offset(0.57, 0.52),
          Offset(0.9, 0.58),
          Offset(0.975, 0.83),
          Offset(0.62, 0.88),
        ]),
        ochre,
        'IV',
      ),
    ];
    for (var i = 0; i < plots.length; i++) {
      _paintPlane(canvas, size, plots[i].$1, plots[i].$2, shadow: 0.014);
      _paintPlotFurrows(canvas, size, plots[i].$1, i);
      _paintPlotFlag(canvas, size, i, plots[i].$3);
    }
    canvas.drawPath(
      _poly(size, const [
        Offset(0.46, 0.27),
        Offset(0.54, 0.27),
        Offset(0.61, 1),
        Offset(0.38, 1),
      ]),
      Paint()..color = cream,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.535),
        Offset(0.44, 0.49),
        Offset(0.5, 0.55),
        Offset(0.44, 0.61),
        Offset(0, 0.635),
      ]),
      Paint()..color = cream,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(1, 0.535),
        Offset(0.56, 0.49),
        Offset(0.5, 0.55),
        Offset(0.56, 0.61),
        Offset(1, 0.635),
      ]),
      Paint()..color = cream,
    );
    final dais = _poly(size, const [
      Offset(0.41, 0.46),
      Offset(0.59, 0.46),
      Offset(0.63, 0.58),
      Offset(0.5, 0.66),
      Offset(0.37, 0.58),
    ]);
    canvas.drawPath(
      dais.shift(Offset(size.width * 0.018, size.height * 0.026)),
      Paint()..color = ink,
    );
    canvas.drawPath(dais, Paint()..color = cream);
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.55),
      math.min(size.width, size.height) * 0.047,
      Paint()..color = red,
    );
    _paintText(
      canvas,
      'COMMUNAL TRICK',
      Offset(size.width * 0.438, size.height * 0.61),
      size.width * 0.011,
      ink,
    );
    for (final figure in const [
      Offset(0.065, 0.57),
      Offset(0.935, 0.57),
      Offset(0.19, 0.88),
      Offset(0.81, 0.9),
      Offset(0.34, 0.49),
      Offset(0.66, 0.49),
    ]) {
      _paintFigure(canvas, size, figure, figure.dx < 0.5 ? ink : red);
    }
    _paintTractor(canvas, size, const Offset(0.055, 0.73), 0.8);
    _paintTractor(canvas, size, const Offset(0.84, 0.72), 0.72);
  }

  void _paintFields(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.25),
      Paint()..color = ink,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.2),
        Offset(0.43, 0.1),
        Offset(0.72, 0.19),
        Offset(1, 0.08),
        Offset(1, 0.29),
        Offset(0, 0.29),
      ]),
      Paint()..color = cream,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.75),
      Paint()..color = cream,
    );
    _paintFarmComplex(canvas, size);
    _paintPowerLines(canvas, size, 0.19);
    final fields = <(Path, Color, String)>[
      (
        _poly(size, const [
          Offset(0.045, 0.34),
          Offset(0.45, 0.28),
          Offset(0.47, 0.54),
          Offset(0.075, 0.57),
        ]),
        ochre,
        'WHEAT',
      ),
      (
        _poly(size, const [
          Offset(0.55, 0.28),
          Offset(0.955, 0.34),
          Offset(0.925, 0.57),
          Offset(0.53, 0.54),
        ]),
        olive,
        'BEET',
      ),
      (
        _poly(size, const [
          Offset(0.075, 0.61),
          Offset(0.47, 0.58),
          Offset(0.43, 0.93),
          Offset(0.025, 0.87),
        ]),
        green,
        'SUNFLOWER',
      ),
      (
        _poly(size, const [
          Offset(0.53, 0.58),
          Offset(0.925, 0.61),
          Offset(0.975, 0.87),
          Offset(0.57, 0.93),
        ]),
        rust,
        'POTATO',
      ),
    ];
    for (var i = 0; i < fields.length; i++) {
      _paintPlane(canvas, size, fields[i].$1, fields[i].$2, shadow: 0.012);
      _paintCropIdentity(canvas, size, i);
      final labelX = i.isEven ? 0.085 : 0.785;
      final labelY = i < 2 ? 0.485 : 0.835;
      _paintJobPlacard(
        canvas,
        size,
        fields[i].$3,
        const [31, 22, 36, 18][i],
        Offset(labelX, labelY),
      );
    }
    canvas.drawPath(
      _poly(size, const [
        Offset(0.48, 0.25),
        Offset(0.52, 0.25),
        Offset(0.57, 1),
        Offset(0.43, 1),
      ]),
      Paint()..color = paper,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.56),
        Offset(0.48, 0.52),
        Offset(0.52, 0.52),
        Offset(1, 0.56),
        Offset(1, 0.61),
        Offset(0.52, 0.57),
        Offset(0.48, 0.57),
        Offset(0, 0.61),
      ]),
      Paint()..color = paper,
    );
    for (final figure in const [
      Offset(0.48, 0.34),
      Offset(0.52, 0.35),
      Offset(0.09, 0.31),
      Offset(0.9, 0.31),
      Offset(0.91, 0.9),
    ]) {
      _paintFigure(canvas, size, figure, figure.dx > 0.5 ? red : ink);
    }
    _paintTractor(canvas, size, const Offset(0.45, 0.91), 0.9);
  }

  void _paintNorth(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.25),
      Paint()..color = ink,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.2),
        Offset(0.22, 0.1),
        Offset(0.46, 0.2),
        Offset(0.7, 0.08),
        Offset(1, 0.19),
        Offset(1, 0.33),
        Offset(0, 0.31),
      ]),
      Paint()..color = snow,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.25, size.width, size.height * 0.75),
      Paint()..color = snow,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0, 0.46),
        Offset(0.28, 0.34),
        Offset(0.52, 0.42),
        Offset(0.78, 0.31),
        Offset(1, 0.39),
        Offset(1, 0.55),
        Offset(0, 0.6),
      ]),
      Paint()..color = const Color(0xffd6c596),
    );
    _paintPowerLines(canvas, size, 0.17);
    _paintWatchTower(canvas, size);
    _paintNorthTrain(canvas, size);
    for (var year = 1; year <= 5; year++) {
      final y = size.height * (0.215 + (year - 1) * 0.125);
      final width = size.width * (0.49 + year * 0.06);
      final x = (size.width - width) / 2;
      _paintBarracks(canvas, size, year, x, y, width);
    }
    _paintRailway(canvas, size);
    _paintSnowFence(canvas, size, left: true);
    _paintSnowFence(canvas, size, left: false);
  }

  void _paintPowerLines(Canvas canvas, Size size, double yFactor) {
    final line = Paint()
      ..color = ink
      ..strokeWidth = math.max(1, size.width * 0.0012);
    final y = size.height * yFactor;
    canvas.drawLine(Offset(0, y), Offset(size.width, y * 0.9), line);
    for (final x in [0.08, 0.27, 0.73, 0.92]) {
      final px = size.width * x;
      canvas.drawLine(
        Offset(px, y - size.height * 0.06),
        Offset(px, y + size.height * 0.06),
        line,
      );
      canvas.drawLine(
        Offset(px - size.width * 0.015, y - size.height * 0.02),
        Offset(px + size.width * 0.015, y - size.height * 0.02),
        line,
      );
    }
  }

  void _paintPlane(
    Canvas canvas,
    Size size,
    Path path,
    Color color, {
    required double shadow,
  }) {
    canvas.drawPath(
      path.shift(Offset(size.width * shadow, size.height * shadow)),
      Paint()..color = ink,
    );
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(
      path,
      Paint()
        ..color = cream
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  Path _poly(Size size, List<Offset> points) {
    final path = Path()
      ..moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    return path..close();
  }

  void _paintFactory(
    Canvas canvas,
    Size size, {
    required double left,
    required double top,
    required double scale,
  }) {
    final x = size.width * left;
    final y = size.height * top;
    canvas.drawRect(
      Rect.fromLTWH(x, y, size.width * 0.24 * scale, size.height * 0.085),
      Paint()..color = red,
    );
    canvas.drawPath(
      _poly(size, [
        Offset(left, top),
        Offset(left + 0.055 * scale, top - 0.035),
        Offset(left + 0.11 * scale, top),
        Offset(left + 0.165 * scale, top - 0.035),
        Offset(left + 0.22 * scale, top),
      ]),
      Paint()..color = red,
    );
    for (final dx in [0.035, 0.095, 0.155]) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (left + dx * scale),
          size.height * (top - 0.09),
          size.width * 0.014,
          size.height * 0.095,
        ),
        Paint()..color = cream,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (left + dx * scale + 0.004),
          size.height * (top - 0.105),
          size.width * 0.006,
          size.height * 0.02,
        ),
        Paint()..color = red,
      );
    }
    for (var i = 0; i < 7; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          x + size.width * (0.012 + i * 0.03),
          y + size.height * 0.025,
          size.width * 0.016,
          size.height * 0.022,
        ),
        Paint()..color = ink,
      );
    }
  }

  void _paintBridge(Canvas canvas, Size size) {
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.5, size.width * 0.002);
    canvas.drawLine(
      Offset(size.width * 0.32, size.height * 0.205),
      Offset(size.width * 0.64, size.height * 0.19),
      line,
    );
    for (var i = 0; i < 8; i++) {
      final x = size.width * (0.33 + i * 0.04);
      canvas.drawLine(
        Offset(x, size.height * 0.205),
        Offset(x + size.width * 0.025, size.height * 0.19),
        line,
      );
      canvas.drawLine(
        Offset(x, size.height * 0.19),
        Offset(x + size.width * 0.025, size.height * 0.205),
        line,
      );
    }
  }

  void _paintPlotFurrows(Canvas canvas, Size size, Path clip, int index) {
    canvas.save();
    canvas.clipPath(clip);
    final line = Paint()
      ..color = (index.isEven ? cream : ochre).withValues(alpha: 0.7)
      ..strokeWidth = math.max(1, size.width * 0.0014);
    final top = index < 2 ? 0.32 : 0.59;
    for (var row = 0; row < 7; row++) {
      final y = size.height * (top + row * 0.028);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y + size.height * (index.isEven ? 0.035 : -0.035)),
        line,
      );
    }
    canvas.restore();
  }

  void _paintPlotFlag(Canvas canvas, Size size, int index, String label) {
    final x = size.width * (index.isEven ? 0.12 : 0.86);
    final y = size.height * (index < 2 ? 0.37 : 0.65);
    canvas.drawLine(
      Offset(x, y),
      Offset(x, y + size.height * 0.09),
      Paint()
        ..color = ink
        ..strokeWidth = math.max(1.5, size.width * 0.0017),
    );
    canvas.drawPath(
      Path()
        ..moveTo(x, y)
        ..lineTo(
          x + size.width * (index.isEven ? 0.035 : -0.035),
          y + size.height * 0.012,
        )
        ..lineTo(x, y + size.height * 0.028)
        ..close(),
      Paint()..color = red,
    );
    _paintText(
      canvas,
      label,
      Offset(
        x + size.width * (index.isEven ? 0.006 : -0.02),
        y + size.height * 0.035,
      ),
      size.width * 0.009,
      ink,
    );
  }

  void _paintFigure(Canvas canvas, Size size, Offset point, Color color) {
    final x = point.dx * size.width;
    final y = point.dy * size.height;
    final unit = math.max(2.4, size.width * 0.0042);
    canvas.drawCircle(Offset(x, y), unit, Paint()..color = color);
    canvas.drawLine(
      Offset(x, y + unit),
      Offset(x, y + unit * 4.2),
      Paint()
        ..color = color
        ..strokeWidth = unit * 1.15,
    );
    canvas.drawLine(
      Offset(x, y + unit * 2),
      Offset(x - unit * 1.7, y + unit * 3.1),
      Paint()
        ..color = color
        ..strokeWidth = unit * 0.65,
    );
    canvas.drawLine(
      Offset(x, y + unit * 2),
      Offset(x + unit * 1.7, y + unit * 2.7),
      Paint()
        ..color = color
        ..strokeWidth = unit * 0.65,
    );
    canvas.drawLine(
      Offset(x, y + unit * 4),
      Offset(x - unit, y + unit * 6),
      Paint()
        ..color = color
        ..strokeWidth = unit * 0.75,
    );
    canvas.drawLine(
      Offset(x, y + unit * 4),
      Offset(x + unit, y + unit * 6),
      Paint()
        ..color = color
        ..strokeWidth = unit * 0.75,
    );
  }

  void _paintTractor(Canvas canvas, Size size, Offset point, double scale) {
    final x = point.dx * size.width;
    final y = point.dy * size.height;
    final w = size.width * 0.055 * scale;
    final h = size.height * 0.035 * scale;
    canvas.drawRect(Rect.fromLTWH(x, y, w * 0.6, h), Paint()..color = red);
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.55, y - h * 0.55, w * 0.3, h * 1.55),
      Paint()..color = ink,
    );
    canvas.drawRect(
      Rect.fromLTWH(x + w * 0.6, y - h * 0.4, w * 0.16, h * 0.5),
      Paint()..color = cream,
    );
    canvas.drawCircle(
      Offset(x + w * 0.22, y + h),
      h * 0.48,
      Paint()..color = ink,
    );
    canvas.drawCircle(
      Offset(x + w * 0.72, y + h),
      h * 0.62,
      Paint()..color = ink,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x + w * 0.05, y + h * 1.35)
        ..lineTo(x + w * 1.18, y + h * 1.7)
        ..lineTo(x + w * 0.95, y + h * 2.05)
        ..lineTo(x, y + h * 1.65)
        ..close(),
      Paint()..color = ink.withValues(alpha: 0.45),
    );
  }

  void _paintFarmComplex(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.62,
        size.height * 0.12,
        size.width * 0.22,
        size.height * 0.09,
      ),
      Paint()..color = ink,
    );
    canvas.drawPath(
      _poly(size, const [
        Offset(0.6, 0.12),
        Offset(0.73, 0.055),
        Offset(0.86, 0.12),
      ]),
      Paint()..color = red,
    );
    for (var i = 0; i < 7; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (0.635 + i * 0.027),
          size.height * 0.15,
          size.width * 0.014,
          size.height * 0.03,
        ),
        Paint()..color = cream,
      );
    }
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.88,
        size.height * 0.055,
        size.width * 0.013,
        size.height * 0.15,
      ),
      Paint()..color = red,
    );
    canvas.drawCircle(
      Offset(size.width * 0.8865, size.height * 0.055),
      size.width * 0.024,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.5, size.width * 0.002),
    );
  }

  void _paintCropIdentity(Canvas canvas, Size size, int index) {
    final inkPaint = Paint()..color = index == 1 || index == 3 ? cream : ink;
    final left = index.isEven ? 0.13 : 0.64;
    final top = index < 2 ? 0.45 : 0.76;
    if (index == 0) {
      for (var i = 0; i < 7; i++) {
        final x = size.width * (left + i * 0.035);
        final y = size.height * top;
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + size.height * 0.065),
          inkPaint..strokeWidth = math.max(1.5, size.width * 0.0018),
        );
        canvas.drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x - size.width * 0.008, y + size.height * 0.018)
            ..lineTo(x + size.width * 0.008, y + size.height * 0.018)
            ..close(),
          inkPaint,
        );
      }
    } else if (index == 1) {
      for (var i = 0; i < 7; i++) {
        final x = size.width * (left + i * 0.035);
        final y = size.height * (top + (i.isOdd ? 0.018 : 0));
        canvas.drawCircle(
          Offset(x, y),
          size.width * 0.009,
          Paint()..color = red,
        );
        canvas.drawLine(
          Offset(x, y + size.height * 0.012),
          Offset(x, y + size.height * 0.05),
          inkPaint..strokeWidth = 2,
        );
      }
    } else if (index == 2) {
      for (var i = 0; i < 6; i++) {
        final x = size.width * (left + i * 0.043);
        final y = size.height * (top + (i.isOdd ? 0.015 : 0));
        canvas.drawCircle(
          Offset(x, y),
          size.width * 0.012,
          Paint()..color = ink,
        );
        for (var ray = 0; ray < 8; ray++) {
          final angle = ray * math.pi / 4;
          canvas.drawLine(
            Offset(
              x + math.cos(angle) * size.width * 0.014,
              y + math.sin(angle) * size.width * 0.014,
            ),
            Offset(
              x + math.cos(angle) * size.width * 0.024,
              y + math.sin(angle) * size.width * 0.024,
            ),
            Paint()
              ..color = ochre
              ..strokeWidth = 2,
          );
        }
      }
    } else {
      for (var row = 0; row < 2; row++) {
        for (var column = 0; column < 6; column++) {
          final x = size.width * (left + column * 0.04 + (row * 0.012));
          final y = size.height * (top + row * 0.055);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset(x, y),
              width: size.width * 0.025,
              height: size.height * 0.025,
            ),
            inkPaint,
          );
          canvas.drawCircle(
            Offset(x + size.width * 0.004, y - size.height * 0.004),
            size.width * 0.0018,
            Paint()..color = rust,
          );
        }
      }
    }
  }

  void _paintJobPlacard(
    Canvas canvas,
    Size size,
    String text,
    int hours,
    Offset point,
  ) {
    final label = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'PTSansNarrow',
          fontSize: math.max(9, size.width * 0.011),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: cream,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final progress = TextPainter(
      text: TextSpan(
        text: '$hours/40',
        style: TextStyle(
          fontFamily: 'PTSansNarrow',
          fontSize: math.max(10, size.width * 0.012),
          fontWeight: FontWeight.w700,
          color: red,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final width = label.width + progress.width + 24;
    final rect = Rect.fromLTWH(
      point.dx * size.width,
      point.dy * size.height,
      width,
      math.max(label.height, progress.height) + 8,
    );
    canvas.drawRect(
      rect.shift(Offset(size.width * 0.006, size.height * 0.009)),
      Paint()..color = red,
    );
    canvas.drawRect(rect, Paint()..color = ink);
    label.paint(canvas, rect.topLeft + const Offset(6, 4));
    progress.paint(
      canvas,
      Offset(rect.right - progress.width - 6, rect.top + 3),
    );
  }

  void _paintBarracks(
    Canvas canvas,
    Size size,
    int year,
    double x,
    double y,
    double width,
  ) {
    final roofHeight = size.height * 0.062;
    final frontHeight = size.height * 0.052;
    final roof = Path()
      ..moveTo(x + width * 0.06, y)
      ..lineTo(x + width * 0.94, y)
      ..lineTo(x + width, y + roofHeight)
      ..lineTo(x, y + roofHeight)
      ..close();
    canvas.drawPath(
      roof.shift(Offset(size.width * 0.012, size.height * 0.018)),
      Paint()..color = const Color(0xff7b745f),
    );
    canvas.drawPath(roof, Paint()..color = ink);
    final front = Rect.fromLTWH(
      x + width * 0.02,
      y + roofHeight,
      width * 0.96,
      frontHeight,
    );
    canvas.drawRect(front, Paint()..color = red);
    canvas.drawRect(
      Rect.fromLTWH(
        front.center.dx - size.width * 0.011,
        front.top,
        size.width * 0.022,
        front.height,
      ),
      Paint()..color = ink,
    );
    for (var window = 0; window < 9; window++) {
      if (window == 4) continue;
      final wx = front.left + front.width * (0.055 + window * 0.108);
      canvas.drawRect(
        Rect.fromLTWH(
          wx,
          front.top + front.height * 0.24,
          front.width * 0.048,
          front.height * 0.42,
        ),
        Paint()..color = ink,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          wx + 1,
          front.top + front.height * 0.26,
          front.width * 0.02,
          front.height * 0.35,
        ),
        Paint()..color = ochre,
      );
    }
    final sign = Rect.fromLTWH(
      x + width * 0.055,
      y + roofHeight * 0.2,
      size.width * 0.085,
      roofHeight * 0.45,
    );
    canvas.drawRect(sign, Paint()..color = cream);
    _paintText(
      canvas,
      'YEAR $year',
      sign.topLeft + Offset(size.width * 0.008, roofHeight * 0.1),
      size.width * 0.011,
      ink,
    );
    canvas.drawLine(
      Offset(x + width * 0.02, front.bottom),
      Offset(x + width * 0.98, front.bottom),
      Paint()
        ..color = ink
        ..strokeWidth = math.max(2, size.width * 0.003),
    );
  }

  void _paintWatchTower(Canvas canvas, Size size) {
    final x = size.width * 0.83;
    final y = size.height * 0.035;
    canvas.drawRect(
      Rect.fromLTWH(x, y, size.width * 0.04, size.height * 0.16),
      Paint()..color = cream,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x - size.width * 0.01, y)
        ..lineTo(x + size.width * 0.02, y - size.height * 0.025)
        ..lineTo(x + size.width * 0.05, y)
        ..close(),
      Paint()..color = red,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        x + size.width * 0.015,
        y + size.height * 0.04,
        size.width * 0.01,
        size.height * 0.025,
      ),
      Paint()..color = ink,
    );
    canvas.drawLine(
      Offset(x + size.width * 0.02, y - size.height * 0.025),
      Offset(x + size.width * 0.02, y - size.height * 0.06),
      Paint()
        ..color = cream
        ..strokeWidth = 2,
    );
    canvas.drawPath(
      Path()
        ..moveTo(x + size.width * 0.02, y - size.height * 0.06)
        ..lineTo(x + size.width * 0.05, y - size.height * 0.045)
        ..lineTo(x + size.width * 0.02, y - size.height * 0.03)
        ..close(),
      Paint()..color = red,
    );
  }

  void _paintNorthTrain(Canvas canvas, Size size) {
    final y = size.height * 0.18;
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.69,
        y,
        size.width * 0.1,
        size.height * 0.026,
      ),
      Paint()..color = ink,
    );
    for (var i = 0; i < 4; i++) {
      canvas.drawRect(
        Rect.fromLTWH(
          size.width * (0.6 + i * 0.022),
          y + size.height * 0.005,
          size.width * 0.017,
          size.height * 0.018,
        ),
        Paint()..color = red,
      );
    }
    canvas.drawCircle(
      Offset(size.width * 0.71, y + size.height * 0.03),
      size.width * 0.005,
      Paint()..color = cream,
    );
    canvas.drawCircle(
      Offset(size.width * 0.77, y + size.height * 0.03),
      size.width * 0.005,
      Paint()..color = cream,
    );
  }

  void _paintRailway(Canvas canvas, Size size) {
    final rail = Paint()
      ..color = ink
      ..strokeWidth = math.max(2.5, size.width * 0.0035);
    canvas.drawLine(
      Offset(size.width * 0.39, size.height),
      Offset(size.width * 0.488, size.height * 0.79),
      rail,
    );
    canvas.drawLine(
      Offset(size.width * 0.61, size.height),
      Offset(size.width * 0.512, size.height * 0.79),
      rail,
    );
    for (var i = 0; i < 6; i++) {
      final t = i / 5;
      final y = size.height * (0.82 + t * 0.18);
      final half = size.width * (0.025 + t * 0.12);
      canvas.drawLine(
        Offset(size.width * 0.5 - half, y),
        Offset(size.width * 0.5 + half, y),
        Paint()
          ..color = i.isEven ? red : ink
          ..strokeWidth = math.max(3, size.width * 0.006),
      );
    }
  }

  void _paintSnowFence(Canvas canvas, Size size, {required bool left}) {
    final line = Paint()
      ..color = ink
      ..strokeWidth = math.max(1.5, size.width * 0.002);
    final startX = left ? 0.02 : 0.78;
    for (var i = 0; i < 6; i++) {
      final x = size.width * (startX + i * 0.04);
      final y = size.height * (0.77 + i * 0.03);
      canvas.drawLine(
        Offset(x, y - size.height * 0.05),
        Offset(x, y + size.height * 0.04),
        line,
      );
      if (i > 0) {
        canvas.drawLine(
          Offset(x - size.width * 0.04, y - size.height * 0.015),
          Offset(x, y),
          line,
        );
      }
    }
  }

  void _paintRegistration(Canvas canvas, Size size) {
    final mark = Paint()
      ..color = red.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(4, 4, size.width - 8, size.height - 8), mark);
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset offset,
    double fontSize,
    Color color,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'PTSansNarrow',
          fontSize: math.max(8, fontSize),
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _StaticHeroPainter oldDelegate) =>
      oldDelegate.panel != panel;
}

class _CardSpec {
  const _CardSpec({
    required this.id,
    required this.suit,
    required this.value,
    required this.x,
    required this.y,
    this.scale = 1,
    this.turns = 0,
    this.shadowLength = 0.24,
  });

  final String id;
  final String suit;
  final int value;
  final double x;
  final double y;
  final double scale;
  final double turns;
  final double shadowLength;
}

List<_CardSpec> _cardSpecs(StaticHeroPanel panel) => switch (panel) {
  StaticHeroPanel.brigade => const [
    _CardSpec(
      id: 'brigade-a1',
      suit: 'wheat',
      value: 11,
      x: 0.2,
      y: 0.39,
      turns: -0.04,
    ),
    _CardSpec(
      id: 'brigade-a2',
      suit: 'sunflower',
      value: 9,
      x: 0.27,
      y: 0.4,
      turns: 0.03,
    ),
    _CardSpec(
      id: 'brigade-b1',
      suit: 'beet',
      value: 12,
      x: 0.69,
      y: 0.39,
      turns: -0.03,
    ),
    _CardSpec(
      id: 'brigade-b2',
      suit: 'potato',
      value: 7,
      x: 0.76,
      y: 0.4,
      turns: 0.04,
    ),
    _CardSpec(
      id: 'brigade-c1',
      suit: 'sunflower',
      value: 7,
      x: 0.2,
      y: 0.69,
      turns: -0.04,
    ),
    _CardSpec(
      id: 'brigade-c2',
      suit: 'wheat',
      value: 6,
      x: 0.27,
      y: 0.7,
      turns: 0.03,
    ),
    _CardSpec(
      id: 'brigade-d1',
      suit: 'potato',
      value: 13,
      x: 0.69,
      y: 0.69,
      turns: -0.03,
    ),
    _CardSpec(
      id: 'brigade-d2',
      suit: 'beet',
      value: 6,
      x: 0.76,
      y: 0.7,
      turns: 0.04,
    ),
    _CardSpec(
      id: 'brigade-trick-1',
      suit: 'wheat',
      value: 13,
      x: 0.45,
      y: 0.52,
      scale: 0.78,
      turns: -0.08,
      shadowLength: 0.16,
    ),
    _CardSpec(
      id: 'brigade-trick-2',
      suit: 'beet',
      value: 10,
      x: 0.49,
      y: 0.5,
      scale: 0.78,
      turns: -0.02,
    ),
    _CardSpec(
      id: 'brigade-trick-3',
      suit: 'potato',
      value: 9,
      x: 0.53,
      y: 0.5,
      scale: 0.78,
      turns: 0.03,
    ),
    _CardSpec(
      id: 'brigade-trick-4',
      suit: 'sunflower',
      value: 8,
      x: 0.57,
      y: 0.52,
      scale: 0.78,
      turns: 0.08,
    ),
  ],
  StaticHeroPanel.fields => const [
    _CardSpec(id: 'fields-wheat-1', suit: 'wheat', value: 11, x: 0.2, y: 0.39),
    _CardSpec(id: 'fields-wheat-2', suit: 'wheat', value: 7, x: 0.27, y: 0.4),
    _CardSpec(id: 'fields-wheat-3', suit: 'wheat', value: 12, x: 0.34, y: 0.4),
    _CardSpec(id: 'fields-beet-1', suit: 'beet', value: 12, x: 0.67, y: 0.39),
    _CardSpec(id: 'fields-beet-2', suit: 'beet', value: 8, x: 0.74, y: 0.4),
    _CardSpec(
      id: 'fields-sunflower-1',
      suit: 'sunflower',
      value: 13,
      x: 0.2,
      y: 0.7,
    ),
    _CardSpec(
      id: 'fields-sunflower-2',
      suit: 'sunflower',
      value: 7,
      x: 0.27,
      y: 0.71,
    ),
    _CardSpec(
      id: 'fields-sunflower-3',
      suit: 'sunflower',
      value: 10,
      x: 0.34,
      y: 0.71,
    ),
    _CardSpec(id: 'fields-potato-1', suit: 'potato', value: 7, x: 0.67, y: 0.7),
    _CardSpec(
      id: 'fields-potato-2',
      suit: 'potato',
      value: 12,
      x: 0.74,
      y: 0.71,
    ),
    _CardSpec(
      id: 'fields-potato-3',
      suit: 'potato',
      value: 8,
      x: 0.81,
      y: 0.71,
    ),
  ],
  StaticHeroPanel.north => [
    for (var year = 0; year < 5; year++)
      for (var card = 0; card < (year == 2 ? 0 : math.min(5, year + 2)); card++)
        _CardSpec(
          id: 'north-y${year + 1}-$card',
          suit: ['wheat', 'sunflower', 'potato', 'beet'][(year + card) % 4],
          value: 13 - ((year + card) % 6),
          x: 0.42 + card * 0.055,
          y: _northRoofY[year],
          scale: 0.68,
          turns: (card - 2) * 0.015,
        ),
  ],
};

const _northRoofY = [0.205, 0.335, 0.44, 0.585, 0.755];

final _handCards = [
  _tableCard('hand-wheat-13', 'wheat', 13),
  _tableCard('hand-sunflower-9', 'sunflower', 9),
  _tableCard('hand-potato-7', 'potato', 7),
  _tableCard('hand-beet-6', 'beet', 6),
  _tableCard('hand-wrecker', wreckerSuit, 0),
];

TableCard _tableCard(String id, String suit, int value) => TableCard(
  id: id,
  suit: suit,
  value: value,
  rank: _rank(value),
  selected: false,
  highlighted: false,
  pending: false,
);

String _rank(int value) => switch (value) {
  0 => 'S',
  11 => 'J',
  12 => 'Q',
  13 => 'K',
  _ => '$value',
};

TokenCardSize _scaledCardSize(TokenCardSize source, double scale) =>
    TokenCardSize(
      width: source.width * scale,
      height: source.height * scale,
      faceInset: source.faceInset * scale,
      cornerWidth: source.cornerWidth * scale,
      cornerHeight: source.cornerHeight * scale,
      cornerRankFontSize: source.cornerRankFontSize * scale,
      cornerSuitSize: source.cornerSuitSize * scale,
      topCornerRankSuitSpacing: source.topCornerRankSuitSpacing * scale,
      bottomCornerRankSuitSpacing: source.bottomCornerRankSuitSpacing * scale,
      topCornerSuitXOffset: source.topCornerSuitXOffset * scale,
      bottomCornerSuitXOffset: source.bottomCornerSuitXOffset * scale,
      pipSize: source.pipSize * scale,
    );
