import 'package:flutter/material.dart';

import 'src/app/views/game/views/components/board_widgets.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';

void main() {
  runApp(const CardViewApp());
}

class CardViewApp extends StatelessWidget {
  const CardViewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz Card View',
      theme: ThemeData(
        fontFamily: defaultDesignTokens.typography.family,
        useMaterial3: true,
      ),
      home: const CardViewScreen(),
    );
  }
}

class CardViewScreen extends StatefulWidget {
  const CardViewScreen({super.key});

  @override
  State<CardViewScreen> createState() => _CardViewScreenState();
}

class _CardViewScreenState extends State<CardViewScreen> {
  bool light = true;
  bool showTrump = true;
  double scale = 2.25;

  DesignTokens get tokens => light ? lightDesignTokens : defaultDesignTokens;
  String? get trump => showTrump ? 'beet' : null;

  @override
  Widget build(BuildContext context) {
    final cards = sampleCards;
    final size = scaledCardSize(tokens.card.large, scale);
    final compactSize = scaledCardSize(tokens.card.medium, scale);
    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _CardViewControls(
              tokens: tokens,
              light: light,
              showTrump: showTrump,
              scale: scale,
              onLightChanged: (value) => setState(() => light = value),
              onTrumpChanged: (value) => setState(() => showTrump = value),
              onScaleChanged: (value) => setState(() => scale = value),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CardRow(
                      tokens: tokens,
                      cards: cards,
                      size: size,
                      trump: trump,
                    ),
                    const SizedBox(height: 28),
                    _CardRow(
                      tokens: tokens,
                      cards: cards,
                      size: compactSize,
                      trump: trump,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardViewControls extends StatelessWidget {
  const _CardViewControls({
    required this.tokens,
    required this.light,
    required this.showTrump,
    required this.scale,
    required this.onLightChanged,
    required this.onTrumpChanged,
    required this.onScaleChanged,
  });

  final DesignTokens tokens;
  final bool light;
  final bool showTrump;
  final double scale;
  final ValueChanged<bool> onLightChanged;
  final ValueChanged<bool> onTrumpChanged;
  final ValueChanged<double> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        border: Border(
          bottom: BorderSide(color: tokens.colors.gold.withValues(alpha: 0.45)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: Wrap(
          spacing: 18,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'Card View',
              style: TextStyle(
                color: tokens.colors.cream,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Light')),
                ButtonSegment(value: false, label: Text('Dark')),
              ],
              selected: {light},
              onSelectionChanged: (selection) =>
                  onLightChanged(selection.first),
            ),
            FilterChip(
              label: const Text('Beet trump'),
              selected: showTrump,
              onSelected: onTrumpChanged,
            ),
            SizedBox(
              width: 260,
              child: Row(
                children: [
                  Text(
                    'Scale',
                    style: TextStyle(color: tokens.colors.cream, fontSize: 16),
                  ),
                  Expanded(
                    child: Slider(
                      min: 1.25,
                      max: 3.25,
                      divisions: 8,
                      value: scale,
                      label: scale.toStringAsFixed(2),
                      onChanged: onScaleChanged,
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

class _CardRow extends StatelessWidget {
  const _CardRow({
    required this.tokens,
    required this.cards,
    required this.size,
    required this.trump,
  });

  final DesignTokens tokens;
  final List<TableCard> cards;
  final TokenCardSize size;
  final String? trump;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 18,
      runSpacing: 18,
      children: [
        for (final card in cards)
          GameCard(
            card: card,
            tokens: tokens,
            trump: trump,
            sizeOverride: size,
            motionTracked: false,
          ),
      ],
    );
  }
}

TokenCardSize scaledCardSize(TokenCardSize size, double scale) {
  return TokenCardSize(
    width: size.width * scale,
    height: size.height * scale,
    faceInset: size.faceInset * scale,
    cornerWidth: size.cornerWidth * scale,
    cornerHeight: size.cornerHeight * scale,
    cornerRankFontSize: size.cornerRankFontSize * scale,
    cornerSuitSize: size.cornerSuitSize * scale,
    topCornerRankSuitSpacing: size.topCornerRankSuitSpacing * scale,
    bottomCornerRankSuitSpacing: size.bottomCornerRankSuitSpacing * scale,
    topCornerSuitXOffset: size.topCornerSuitXOffset * scale,
    bottomCornerSuitXOffset: size.bottomCornerSuitXOffset * scale,
    pipSize: size.pipSize * scale,
  );
}

final sampleCards = [
  card('wheat-6', 'wheat', 6, '6'),
  card('wheat-10', 'wheat', 10, '10'),
  card('potato-11', 'potato', 11, 'J'),
  card('beet-12', 'beet', 12, 'Q'),
  card('wheat-13', 'wheat', 13, 'K'),
  card('wrecker-0', wreckerSuit, 0, 'S'),
  card('beet-nomenclature-12', 'beet', 12, 'Q', nomenclature: true),
];

TableCard card(
  String id,
  String suit,
  int value,
  String rank, {
  bool nomenclature = false,
}) {
  return TableCard(
    id: id,
    suit: suit,
    value: value,
    rank: rank,
    selected: false,
    highlighted: false,
    pending: false,
    nomenclature: nomenclature,
  );
}
