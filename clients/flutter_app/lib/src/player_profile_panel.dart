import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'app_text.dart';
import 'chrome_button.dart';
import 'design_tokens.dart';
import 'pixel_text.dart';

class PlayerProfileStat {
  const PlayerProfileStat({
    required this.label,
    required this.value,
    this.prominent = false,
  });

  final String label;
  final String value;
  final bool prominent;
}

class PlayerProfileStatGroup {
  const PlayerProfileStatGroup({required this.label, required this.stats});

  final String label;
  final List<PlayerProfileStat> stats;
}

class PlayerProfileChip {
  const PlayerProfileChip({required this.label, this.active = false});

  final String label;
  final bool active;
}

class PlayerProfileAction {
  const PlayerProfileAction({
    required this.label,
    required this.iconAsset,
    required this.onPressed,
    this.prominent = false,
    this.height = 28,
    this.iconSize = 16,
    this.textSize = PixelTextSize.xSmall,
  });

  final String label;
  final String iconAsset;
  final VoidCallback? onPressed;
  final bool prominent;
  final double height;
  final double iconSize;
  final PixelTextSize textSize;
}

class PlayerProfileBadge extends StatelessWidget {
  const PlayerProfileBadge({
    required this.tokens,
    required this.displayName,
    required this.portraitAsset,
    this.seatLabel,
    this.subtitle,
    this.subtitleIconAsset,
    this.title,
    this.portraitSemanticsLabel,
    this.onPortraitPressed,
    this.statGroups = const [],
    this.action,
    this.trailing,
    this.active = false,
    this.muted = false,
    this.portraitSelected = false,
    this.portraitSize = 48,
    this.minHeight = 82,
    super.key,
  });

  final DesignTokens tokens;
  final String displayName;
  final String portraitAsset;
  final String? seatLabel;
  final String? subtitle;
  final String? subtitleIconAsset;
  final Widget? title;
  final String? portraitSemanticsLabel;
  final VoidCallback? onPortraitPressed;
  final List<PlayerProfileStatGroup> statGroups;
  final PlayerProfileAction? action;
  final Widget? trailing;
  final bool active;
  final bool muted;
  final bool portraitSelected;
  final double portraitSize;
  final double minHeight;

  @override
  Widget build(BuildContext context) => PlayerProfilePanel(
    tokens: tokens,
    displayName: displayName,
    portraitAsset: portraitAsset,
    seatLabel: seatLabel,
    subtitle: subtitle,
    subtitleIconAsset: subtitleIconAsset,
    title: title,
    portraitSemanticsLabel: portraitSemanticsLabel,
    onPortraitPressed: onPortraitPressed,
    statGroups: statGroups,
    action: action,
    trailing: trailing,
    active: active,
    muted: muted,
    portraitSelected: portraitSelected,
    portraitSize: portraitSize,
    minHeight: minHeight,
  );
}

class ExpandedPlayerProfile extends StatelessWidget {
  const ExpandedPlayerProfile({
    required this.tokens,
    required this.displayName,
    required this.portraitAsset,
    this.subtitle,
    this.title,
    this.portraitSemanticsLabel,
    this.onPortraitPressed,
    this.chips = const [],
    this.statGroups = const [],
    this.action,
    this.footer,
    this.active = false,
    this.portraitSelected = false,
    this.portraitSize = 72,
    super.key,
  });

  final DesignTokens tokens;
  final String displayName;
  final String portraitAsset;
  final String? subtitle;
  final Widget? title;
  final String? portraitSemanticsLabel;
  final VoidCallback? onPortraitPressed;
  final List<PlayerProfileChip> chips;
  final List<PlayerProfileStatGroup> statGroups;
  final PlayerProfileAction? action;
  final Widget? footer;
  final bool active;
  final bool portraitSelected;
  final double portraitSize;

  @override
  Widget build(BuildContext context) => PlayerProfilePanel(
    tokens: tokens,
    displayName: displayName,
    portraitAsset: portraitAsset,
    subtitle: subtitle,
    title: title,
    portraitSemanticsLabel: portraitSemanticsLabel,
    onPortraitPressed: onPortraitPressed,
    chips: chips,
    statGroups: statGroups,
    action: action,
    footer: footer,
    active: active,
    portraitSelected: portraitSelected,
    portraitSize: portraitSize,
    minHeight: 0,
    padding: const EdgeInsets.all(10),
    expandStats: true,
    scrollStats: true,
  );
}

class PlayerProfilePanel extends StatelessWidget {
  const PlayerProfilePanel({
    required this.tokens,
    required this.displayName,
    required this.portraitAsset,
    this.seatLabel,
    this.subtitle,
    this.subtitleIconAsset,
    this.title,
    this.portraitSemanticsLabel,
    this.onPortraitPressed,
    this.chips = const [],
    this.statGroups = const [],
    this.action,
    this.footer,
    this.trailing,
    this.active = false,
    this.muted = false,
    this.portraitSelected = false,
    this.portraitSize = 48,
    this.minHeight = 82,
    this.padding = const EdgeInsets.all(8),
    this.expandStats = false,
    this.scrollStats = false,
    this.backgroundColor,
    this.borderColor,
    this.titleColor,
    this.subtitleColor,
    super.key,
  });

  final DesignTokens tokens;
  final String displayName;
  final String portraitAsset;
  final String? seatLabel;
  final String? subtitle;
  final String? subtitleIconAsset;
  final Widget? title;
  final String? portraitSemanticsLabel;
  final VoidCallback? onPortraitPressed;
  final List<PlayerProfileChip> chips;
  final List<PlayerProfileStatGroup> statGroups;
  final PlayerProfileAction? action;
  final Widget? footer;
  final Widget? trailing;
  final bool active;
  final bool muted;
  final bool portraitSelected;
  final double portraitSize;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final bool expandStats;
  final bool scrollStats;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? titleColor;
  final Color? subtitleColor;

  @override
  Widget build(BuildContext context) {
    final effectiveBorder =
        borderColor ??
        (active
            ? tokens.colors.goldBright
            : muted
            ? tokens.colors.steel.withValues(alpha: 0.36)
            : tokens.colors.gold.withValues(alpha: 0.56));
    final effectiveTitleColor =
        titleColor ??
        (muted
            ? tokens.colors.creamDim.withValues(alpha: 0.68)
            : tokens.colors.cream);
    final effectiveSubtitleColor =
        subtitleColor ??
        (muted
            ? tokens.colors.creamDim.withValues(alpha: 0.58)
            : tokens.colors.gold);
    final stats = PlayerProfileStatsGrid(tokens: tokens, groups: statGroups);
    final statsChild = scrollStats
        ? SingleChildScrollView(child: stats)
        : stats;

    return Semantics(
      container: true,
      label: displayName,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight),
        padding: padding,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              tokens.colors.black.withValues(alpha: muted ? 0.18 : 0.34),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: effectiveBorder, width: active ? 1.5 : 1),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: tokens.colors.gold.withValues(alpha: 0.16),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              spacing: 8,
              children: [
                _ProfilePortraitSlot(
                  tokens: tokens,
                  asset: portraitAsset,
                  size: portraitSize,
                  selected: active || portraitSelected,
                  opacity: muted ? 0.46 : 1,
                  label: seatLabel,
                  active: active,
                  semanticsLabel: portraitSemanticsLabel ?? portraitAsset,
                  onPressed: onPortraitPressed,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 4,
                    children: [
                      title ??
                          Text(
                            displayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: kolkhozFontStyle.copyWith(
                              color: effectiveTitleColor,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                      if (subtitle != null)
                        Row(
                          spacing: 5,
                          children: [
                            if (subtitleIconAsset != null)
                              _PlayerProfileAssetIcon(
                                subtitleIconAsset!,
                                size: 15,
                                opacity: muted ? 0.58 : 1,
                              ),
                            Expanded(
                              child: Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kolkhozFontStyle.copyWith(
                                  color: effectiveSubtitleColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (action != null)
                        SizedBox(
                          height: action!.height,
                          width: double.infinity,
                          child: ChromeAssetButton.command(
                            label: action!.label,
                            prominent: action!.prominent,
                            tokens: tokens,
                            iconAsset: action!.iconAsset,
                            iconSize: action!.iconSize,
                            textSize: action!.textSize,
                            expandLabel: false,
                            padding: const EdgeInsets.symmetric(horizontal: 7),
                            spacing: 4,
                            onPressed: action!.onPressed,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final chip in chips)
                    PlayerProfileChipView(tokens: tokens, chip: chip),
                ],
              ),
            ],
            if (statGroups.isNotEmpty) ...[
              const SizedBox(height: 8),
              if (expandStats) Expanded(child: statsChild) else statsChild,
            ],
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ),
      ),
    );
  }
}

class PlayerProfilePortraitImage extends StatelessWidget {
  const PlayerProfilePortraitImage({
    required this.tokens,
    required this.asset,
    required this.size,
    required this.selected,
    super.key,
  });

  final DesignTokens tokens;
  final String asset;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: selected
            ? tokens.colors.gold.withValues(alpha: 0.26)
            : tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: selected
              ? tokens.colors.gold
              : tokens.colors.steel.withValues(alpha: 0.42),
          width: selected ? 1.5 : 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'ios_resources/$asset.png',
          fit: BoxFit.cover,
          filterQuality: FilterQuality.none,
          errorBuilder: (_, _, _) =>
              ColoredBox(color: tokens.colors.black.withValues(alpha: 0.42)),
        ),
      ),
    );
  }
}

class PlayerProfileStatsGrid extends StatelessWidget {
  const PlayerProfileStatsGrid({
    required this.tokens,
    required this.groups,
    this.columnsForWidth,
    this.tileHeight,
    super.key,
  });

  final DesignTokens tokens;
  final List<PlayerProfileStatGroup> groups;
  final int Function(double width)? columnsForWidth;
  final double? tileHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columnCount =
            columnsForWidth?.call(constraints.maxWidth) ??
            (constraints.maxWidth >= 520
                ? 3
                : constraints.maxWidth < 260
                ? 1
                : 2);
        const spacing = 8.0;
        final tileWidth =
            (constraints.maxWidth - (spacing * (columnCount - 1))) /
            columnCount;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final group in groups)
              SizedBox(
                width: tileWidth,
                height: tileHeight,
                child: _PlayerProfileStatGroupCard(
                  tokens: tokens,
                  group: group,
                ),
              ),
          ],
        );
      },
    );
  }
}

class PlayerProfileChipView extends StatelessWidget {
  const PlayerProfileChipView({
    required this.tokens,
    required this.chip,
    super.key,
  });

  final DesignTokens tokens;
  final PlayerProfileChip chip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: chip.active
            ? tokens.colors.red.withValues(alpha: 0.72)
            : tokens.colors.gold.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: chip.active
              ? tokens.colors.gold.withValues(alpha: 0.76)
              : tokens.colors.gold.withValues(alpha: 0.34),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
        child: PixelText(
          chip.label,
          size: PixelTextSize.xSmall,
          variant: PixelTextVariant.heavy,
          color: chip.active ? tokens.colors.onAccent : tokens.colors.gold,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

List<PlayerProfileStatGroup> kolkhozProfileStatGroups({
  required KolkhozProfileStats stats,
  required KolkhozLanguage language,
}) {
  return [
    PlayerProfileStatGroup(
      label: language.t(KolkhozText.kolkhozappOffline),
      stats: [
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappGames),
          value: stats.offlinePlays.toString(),
        ),
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappWins),
          value: stats.offlineWins.toString(),
        ),
      ],
    ),
    PlayerProfileStatGroup(
      label: language.t(KolkhozText.kolkhozappCasual),
      stats: [
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappRating),
          value: stats.casualRating.toString(),
          prominent: true,
        ),
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappGames),
          value: stats.casualPlays.toString(),
        ),
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappWins),
          value: stats.casualWins.toString(),
        ),
      ],
    ),
    PlayerProfileStatGroup(
      label: language.t(KolkhozText.kolkhozappRanked),
      stats: [
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappRating),
          value: stats.rating.toString(),
          prominent: true,
        ),
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappGames),
          value: stats.rankedPlays.toString(),
        ),
        PlayerProfileStat(
          label: language.t(KolkhozText.kolkhozappWins),
          value: stats.rankedWins.toString(),
        ),
      ],
    ),
  ];
}

class _ProfilePortraitSlot extends StatelessWidget {
  const _ProfilePortraitSlot({
    required this.tokens,
    required this.asset,
    required this.size,
    required this.selected,
    required this.opacity,
    required this.semanticsLabel,
    required this.active,
    this.label,
    this.onPressed,
  });

  final DesignTokens tokens;
  final String asset;
  final double size;
  final bool selected;
  final double opacity;
  final String semanticsLabel;
  final bool active;
  final String? label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final portrait = Opacity(
      opacity: opacity,
      child: PlayerProfilePortraitImage(
        tokens: tokens,
        asset: asset,
        size: size,
        selected: selected,
      ),
    );
    final child = label == null
        ? portrait
        : Stack(
            clipBehavior: Clip.none,
            children: [
              portrait,
              Positioned(
                left: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? tokens.colors.gold
                        : tokens.colors.black.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: tokens.colors.gold.withValues(alpha: 0.82),
                    ),
                  ),
                  child: Text(
                    label!,
                    style: kolkhozFontStyle.copyWith(
                      color: active
                          ? tokens.colors.onAccent
                          : tokens.colors.gold,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          );
    if (onPressed == null) {
      return Semantics(label: semanticsLabel, child: child);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Semantics(
        button: true,
        enabled: true,
        label: semanticsLabel,
        child: child,
      ),
    );
  }
}

class _PlayerProfileStatGroupCard extends StatelessWidget {
  const _PlayerProfileStatGroupCard({
    required this.tokens,
    required this.group,
  });

  final DesignTokens tokens;
  final PlayerProfileStatGroup group;

  @override
  Widget build(BuildContext context) {
    final prominent = group.stats.any((stat) => stat.prominent);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: prominent
            ? tokens.colors.red.withValues(alpha: 0.58)
            : tokens.colors.black.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: prominent
              ? tokens.colors.gold.withValues(alpha: 0.76)
              : tokens.colors.steel.withValues(alpha: 0.34),
          width: prominent ? 1.4 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: 8,
        children: [
          Text(
            group.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: kolkhozFontStyle.copyWith(
              color: prominent
                  ? tokens.colors.activeSurfaceTextMuted
                  : tokens.colors.creamDim.withValues(alpha: 0.76),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          for (final stat in group.stats)
            _PlayerProfileStatRow(
              tokens: tokens,
              stat: stat,
              prominentGroup: prominent,
              showLabel: group.stats.length > 1 || group.label != stat.label,
            ),
        ],
      ),
    );
  }
}

class _PlayerProfileStatRow extends StatelessWidget {
  const _PlayerProfileStatRow({
    required this.tokens,
    required this.stat,
    required this.prominentGroup,
    required this.showLabel,
  });

  final DesignTokens tokens;
  final PlayerProfileStat stat;
  final bool prominentGroup;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final valueColor = prominentGroup
        ? tokens.colors.activeSurfaceText
        : stat.prominent
        ? tokens.colors.gold
        : tokens.colors.cream;
    final labelColor = prominentGroup
        ? tokens.colors.activeSurfaceTextMuted
        : tokens.colors.creamDim.withValues(alpha: 0.76);
    return Row(
      children: [
        if (showLabel)
          Expanded(
            child: Text(
              stat.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kolkhozFontStyle.copyWith(
                color: labelColor,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          const Spacer(),
        Text(
          stat.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: kolkhozFontStyle.copyWith(
            color: valueColor,
            fontSize: stat.prominent ? 19 : 18,
            height: 0.95,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PlayerProfileAssetIcon extends StatelessWidget {
  const _PlayerProfileAssetIcon(
    this.asset, {
    required this.size,
    this.opacity = 1,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      asset,
      width: size,
      height: size,
      opacity: AlwaysStoppedAnimation(opacity),
      filterQuality: FilterQuality.none,
    );
  }
}
