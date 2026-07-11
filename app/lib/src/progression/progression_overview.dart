import 'package:flutter/material.dart';

import '../design_tokens.dart';
import '../pixel_text.dart';
import 'progression.dart';

class ProgressionOverview extends StatelessWidget {
  const ProgressionOverview({
    required this.state,
    required this.tokens,
    super.key,
  });

  final ProgressionState state;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final achievements = progressionDefinitions
        .where((item) => item.kind == ProgressionKind.achievement)
        .toList();
    final challenges = progressionDefinitions
        .where((item) => item.kind == ProgressionKind.challenge)
        .toList();
    return ListView(
      key: const ValueKey('progression-overview'),
      padding: const EdgeInsets.only(bottom: 12),
      children: [
        _ProgressionHeader(state: state, tokens: tokens),
        const SizedBox(height: 14),
        _SectionTitle(label: 'ACTIVE CHALLENGES', tokens: tokens),
        const SizedBox(height: 7),
        for (final item in challenges) ...[
          _ProgressionRow(
            definition: item,
            value: state.progressFor(item),
            completed: state.isCompleted(item.id),
            tokens: tokens,
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 7),
        _SectionTitle(label: 'ACHIEVEMENTS', tokens: tokens),
        const SizedBox(height: 7),
        for (final item in achievements) ...[
          _ProgressionRow(
            definition: item,
            value: state.progressFor(item),
            completed: state.isCompleted(item.id),
            tokens: tokens,
          ),
          const SizedBox(height: 7),
        ],
      ],
    );
  }
}

class _ProgressionHeader extends StatelessWidget {
  const _ProgressionHeader({required this.state, required this.tokens});

  final ProgressionState state;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final total = progressionDefinitions.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tokens.colors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(tokens.radius.md),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/ui/Icons/icon-medal-star.png',
            width: 38,
            height: 38,
            filterQuality: FilterQuality.none,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(
                  'COLLECTIVE RECORD',
                  color: tokens.colors.goldBright,
                  size: PixelTextSize.headline,
                  variant: PixelTextVariant.heavy,
                ),
                const SizedBox(height: 4),
                Text(
                  '${state.completed.length} of $total completed • '
                  '${state.unlocks.length} rewards unlocked',
                  style: TextStyle(color: tokens.colors.cream, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.label, required this.tokens});

  final String label;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) => PixelText(
    label,
    color: tokens.colors.gold,
    size: PixelTextSize.caption,
    variant: PixelTextVariant.heavy,
  );
}

class _ProgressionRow extends StatelessWidget {
  const _ProgressionRow({
    required this.definition,
    required this.value,
    required this.completed,
    required this.tokens,
  });

  final ProgressionDefinition definition;
  final int value;
  final bool completed;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final accent = completed ? tokens.colors.goldBright : tokens.colors.steel;
    final fraction = definition.target == 0 ? 0.0 : value / definition.target;
    return Container(
      key: ValueKey('progression-${definition.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.colors.black.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(tokens.radius.sm),
        border: Border.all(color: accent.withValues(alpha: 0.58)),
      ),
      child: Row(
        children: [
          Opacity(
            opacity: completed ? 1 : 0.45,
            child: Image.asset(
              completed
                  ? 'assets/ui/Icons/icon-check.png'
                  : 'assets/ui/Icons/icon-medal-star.png',
              width: 24,
              height: 24,
              filterQuality: FilterQuality.none,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelText(
                  definition.title.toUpperCase(),
                  color: tokens.colors.cream,
                  size: PixelTextSize.caption,
                  variant: PixelTextVariant.heavy,
                  maxLines: 1,
                ),
                const SizedBox(height: 3),
                Text(
                  definition.description,
                  style: TextStyle(color: tokens.colors.smoke, fontSize: 13),
                ),
                if (definition.target > 1) ...[
                  const SizedBox(height: 7),
                  LinearProgressIndicator(
                    value: fraction.clamp(0, 1),
                    minHeight: 4,
                    color: accent,
                    backgroundColor: tokens.colors.black.withValues(alpha: 0.3),
                  ),
                ],
                if (definition.reward != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Reward: ${definition.reward}',
                    style: TextStyle(color: tokens.colors.gold, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          PixelText(
            completed ? 'DONE' : '$value/${definition.target}',
            color: accent,
            size: PixelTextSize.caption2,
            variant: PixelTextVariant.heavy,
          ),
        ],
      ),
    );
  }
}
