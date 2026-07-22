import 'package:flutter/material.dart';

import 'package:kolkhoz_app/src/app/settings/settings.dart';
import 'package:kolkhoz_app/src/app/views/shared/design_tokens.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/game_constants.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/remote_game_engine/game_session_models.dart';
import 'package:kolkhoz_app/src/app/views/shared/pixel_text.dart';
import 'package:kolkhoz_app/src/app/views/game/game_controller/models/render_model.dart';
import 'package:kolkhoz_app/src/app/views/game/views/components/board_widgets.dart';

const reactionIDs = [
  'comrade',
  'medal',
  'protected',
  'warning',
  'wheat',
  'wrecker',
];

String reactionAsset(String reactionID) => switch (reactionID) {
  'comrade' => 'icon-comrade.png',
  'medal' => 'icon-medal-star.png',
  'protected' => 'icon-status-protected.png',
  'warning' => 'icon-warning.png',
  'wheat' => 'icon-wheat.png',
  'wrecker' => 'icon-wrecker.png',
  _ => 'icon-comrade.png',
};

class GameLogPanel extends StatelessWidget {
  const GameLogPanel({
    required this.model,
    required this.tokens,
    required this.language,
    required this.actions,
    required this.reactions,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;
  final KolkhozLanguage language;
  final List<EngineAction> actions;
  final List<OnlineReaction> reactions;

  @override
  Widget build(BuildContext context) {
    final years = _groupEntries(actions, reactions);
    final latestYear = years.isEmpty ? 1 : years.last.year;
    return CommandPanelSurface(
      tokens: tokens,
      padding: EdgeInsets.all(tokens.spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PixelText(
            language == KolkhozLanguage.en ? 'GAME LOG' : 'ЖУРНАЛ ИГРЫ',
            size: PixelTextSize.title,
            variant: PixelTextVariant.heavy,
            color: tokens.colors.gold,
          ),
          const SizedBox(height: 6),
          Expanded(
            child: ListView(
              key: const Key('game-log-list'),
              children: [
                if (years.isEmpty)
                  PixelText(
                    language == KolkhozLanguage.en
                        ? 'The first action will appear here.'
                        : 'Первое действие появится здесь.',
                    size: PixelTextSize.caption,
                    color: tokens.colors.creamDim,
                  ),
                for (final year in years)
                  _LogExpansion(
                    key: PageStorageKey('log-year-${year.year}'),
                    title: language == KolkhozLanguage.en
                        ? 'Year ${year.year}'
                        : 'Год ${year.year}',
                    iconAsset:
                        'assets/ui/Icons/icon-year-${year.year.clamp(1, 5)}.png',
                    initiallyExpanded: year.year == latestYear,
                    tokens: tokens,
                    children: [
                      for (var index = 0; index < year.phases.length; index++)
                        _LogExpansion(
                          key: PageStorageKey(
                            'log-year-${year.year}-${year.phases[index].phase}',
                          ),
                          title: _phaseLabel(
                            year.phases[index].phase,
                            language,
                          ),
                          iconAsset: _phaseIconAsset(year.phases[index].phase),
                          flipIconHorizontally:
                              year.phases[index].phase == phasePass &&
                              year.year.isEven,
                          initiallyExpanded:
                              year.year == latestYear &&
                              index == year.phases.length - 1,
                          tokens: tokens,
                          children: [
                            for (final action in year.phases[index].actions)
                              _LogLine(
                                action: action,
                                model: model,
                                language: language,
                                tokens: tokens,
                              ),
                            for (final reaction in year.phases[index].reactions)
                              _ReactionLine(
                                reaction: reaction,
                                model: model,
                                language: language,
                                tokens: tokens,
                              ),
                          ],
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ReactionTray extends StatelessWidget {
  const ReactionTray({
    required this.tokens,
    required this.language,
    required this.enabled,
    this.onReaction,
    super.key,
  });

  final DesignTokens tokens;
  final KolkhozLanguage language;
  final bool enabled;
  final ValueChanged<String>? onReaction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: tokens.colors.table,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final reactionID in reactionIDs)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Tooltip(
                  message: _reactionLabel(reactionID, language),
                  child: IconButton(
                    key: Key('reaction-$reactionID'),
                    onPressed: enabled
                        ? () => onReaction?.call(reactionID)
                        : null,
                    icon: Image.asset(
                      'assets/ui/Icons/${reactionAsset(reactionID)}',
                      width: 30,
                      height: 30,
                      filterQuality: FilterQuality.none,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LogExpansion extends StatefulWidget {
  const _LogExpansion({
    required this.title,
    required this.iconAsset,
    required this.initiallyExpanded,
    required this.tokens,
    required this.children,
    this.flipIconHorizontally = false,
    super.key,
  });

  final String title;
  final String iconAsset;
  final bool initiallyExpanded;
  final DesignTokens tokens;
  final List<Widget> children;
  final bool flipIconHorizontally;

  @override
  State<_LogExpansion> createState() => _LogExpansionState();
}

class _LogExpansionState extends State<_LogExpansion> {
  late bool expanded = widget.initiallyExpanded;
  bool restored = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (restored) {
      return;
    }
    restored = true;
    final stored = PageStorage.maybeOf(context)?.readState(context);
    if (stored is bool) {
      expanded = stored;
    }
  }

  void toggle() {
    setState(() => expanded = !expanded);
    PageStorage.maybeOf(context)?.writeState(context, expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: widget.title,
          onTap: toggle,
          child: ExcludeSemantics(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: toggle,
              child: SizedBox(
                height: 40,
                child: Row(
                  children: [
                    AnimatedRotation(
                      turns: expanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 140),
                      child: CustomPaint(
                        size: const Size.square(14),
                        painter: _ExpansionChevronPainter(
                          color: expanded
                              ? widget.tokens.colors.gold
                              : widget.tokens.colors.smoke,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Transform.flip(
                      flipX: widget.flipIconHorizontally,
                      child: Image.asset(
                        widget.iconAsset,
                        width: 24,
                        height: 24,
                        filterQuality: FilterQuality.none,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: PixelText(
                        widget.title,
                        size: PixelTextSize.headline,
                        variant: PixelTextVariant.heavy,
                        color: widget.tokens.colors.cream,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 160),
          alignment: Alignment.topCenter,
          child: expanded
              ? Padding(
                  padding: const EdgeInsets.only(left: 22, bottom: 4),
                  child: Column(children: widget.children),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _ExpansionChevronPainter extends CustomPainter {
  const _ExpansionChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.square
      ..strokeJoin = StrokeJoin.miter;
    final path = Path()
      ..moveTo(size.width * 0.3, size.height * 0.16)
      ..lineTo(size.width * 0.72, size.height * 0.5)
      ..lineTo(size.width * 0.3, size.height * 0.84);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ExpansionChevronPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _LogLine extends StatelessWidget {
  const _LogLine({
    required this.action,
    required this.model,
    required this.language,
    required this.tokens,
  });

  final EngineAction action;
  final TableViewModel model;
  final KolkhozLanguage language;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (action.playerID < 0) {
      return _SystemLogEventRow(
        tokens: tokens,
        children: _actionWidgets(action, language, tokens),
      );
    }
    return _LogEventRow(
      seat: _playerSeat(model, action.playerID),
      tokens: tokens,
      children: _actionWidgets(action, language, tokens),
    );
  }
}

class _SystemLogEventRow extends StatelessWidget {
  const _SystemLogEventRow({required this.tokens, required this.children});

  final DesignTokens tokens;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Wrap(
        spacing: 5,
        runSpacing: 3,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Image.asset(
            'assets/ui/Icons/icon-requisition-north.png',
            width: 22,
            height: 22,
            filterQuality: FilterQuality.none,
          ),
          ...children,
        ],
      ),
    );
  }
}

class _ReactionLine extends StatelessWidget {
  const _ReactionLine({
    required this.reaction,
    required this.model,
    required this.language,
    required this.tokens,
  });

  final OnlineReaction reaction;
  final TableViewModel model;
  final KolkhozLanguage language;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return _LogEventRow(
      seat: _playerSeat(model, reaction.playerID),
      tokens: tokens,
      children: [
        _InlineLogText(
          text: language == KolkhozLanguage.en ? 'sent' : 'отправил',
          tokens: tokens,
        ),
        Tooltip(
          message: reaction.reactionID,
          child: Image.asset(
            'assets/ui/Icons/${reactionAsset(reaction.reactionID)}',
            width: 20,
            height: 20,
            filterQuality: FilterQuality.none,
          ),
        ),
      ],
    );
  }
}

class _LogEventRow extends StatelessWidget {
  const _LogEventRow({
    required this.seat,
    required this.tokens,
    required this.children,
  });

  final Seat seat;
  final DesignTokens tokens;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          PortraitFrame(seat: seat, tokens: tokens, width: 30, height: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 5,
              runSpacing: 3,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PixelText(
                  seat.name,
                  size: PixelTextSize.caption,
                  variant: PixelTextVariant.heavy,
                  color: tokens.colors.cream,
                ),
                ...children,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineLogText extends StatelessWidget {
  const _InlineLogText({required this.text, required this.tokens});

  final String text;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PixelText(
      text,
      size: PixelTextSize.caption,
      color: tokens.colors.creamDim,
    );
  }
}

class _InlineSuitIcon extends StatelessWidget {
  const _InlineSuitIcon({required this.suit, required this.tokens});

  final String? suit;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final resolvedSuit = suit ?? 'wheat';
    return Tooltip(
      message: resolvedSuit,
      child: Image.asset(
        'assets/ui/Icons/icon-$resolvedSuit.png',
        width: 18,
        height: 18,
        filterQuality: FilterQuality.none,
        errorBuilder: (_, _, _) => SizedBox(
          width: 18,
          height: 18,
          child: ColoredBox(color: tokens.colors.smoke),
        ),
      ),
    );
  }
}

class _InlineCard extends StatelessWidget {
  const _InlineCard({required this.card, required this.tokens});

  final EngineCard card;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PixelText(
          '${card.value}',
          size: PixelTextSize.caption,
          variant: PixelTextVariant.heavy,
          color: tokens.colors.gold,
        ),
        const SizedBox(width: 3),
        _InlineSuitIcon(suit: card.suit, tokens: tokens),
      ],
    );
  }
}

class _LogYear {
  const _LogYear(this.year, this.phases);
  final int year;
  final List<_LogPhase> phases;
}

class _LogPhase {
  const _LogPhase(this.phase, this.actions, this.reactions);
  final String phase;
  final List<EngineAction> actions;
  final List<OnlineReaction> reactions;
}

List<_LogYear> _groupEntries(
  List<EngineAction> actions,
  List<OnlineReaction> reactions,
) {
  final result = <_LogYear>[];
  var year = 1;
  for (final action in actions) {
    final phase = _phaseForAction(action.kind);
    if (result.isEmpty || result.last.year != year) {
      result.add(_LogYear(year, []));
    }
    final phases = result.last.phases;
    if (phases.isEmpty || phases.last.phase != phase) {
      phases.add(_LogPhase(phase, [], []));
    }
    phases.last.actions.add(action);
    if (action.kind == actionContinueAfterRequisition) {
      year++;
    }
  }
  for (final reaction in reactions) {
    _LogYear? year;
    for (final entry in result) {
      if (entry.year == reaction.year) {
        year = entry;
        break;
      }
    }
    if (year == null) {
      year = _LogYear(reaction.year, []);
      result.add(year);
      result.sort((left, right) => left.year.compareTo(right.year));
    }
    final phaseName = _phaseNameFromCode(reaction.phase);
    _LogPhase? phase;
    for (final entry in year.phases) {
      if (entry.phase == phaseName) {
        phase = entry;
        break;
      }
    }
    if (phase == null) {
      phase = _LogPhase(phaseName, [], []);
      year.phases.add(phase);
    }
    phase.reactions.add(reaction);
  }
  return result;
}

String _phaseNameFromCode(int phase) => switch (phase) {
  0 => phasePlanning,
  1 => phaseSwap,
  2 => phaseTrick,
  3 => phaseAssignment,
  4 => phaseRequisition,
  6 => phasePass,
  _ => 'events',
};

String _phaseForAction(String kind) => switch (kind) {
  actionSetTrump || actionRevealReward || actionRevealTrump => phasePlanning,
  actionSwap || actionUndoSwap || actionConfirmSwap => phaseSwap,
  actionPassCard => phasePass,
  actionPlayCard => phaseTrick,
  actionAssign || actionSubmitAssignments => phaseAssignment,
  actionContinueAfterRequisition => phaseRequisition,
  actionRequisitionEvent => phaseRequisition,
  _ => 'events',
};

String _phaseLabel(String phase, KolkhozLanguage language) {
  final english = language == KolkhozLanguage.en;
  return switch (phase) {
    phasePlanning => english ? 'Planning' : 'Планирование',
    phaseSwap => english ? 'Plot exchange' : 'Обмен с участком',
    phasePass => english ? 'Pass' : 'Передача',
    phaseTrick => english ? 'Tricks' : 'Взятки',
    phaseAssignment => english ? 'Job assignment' : 'Назначение работ',
    phaseRequisition => english ? 'Requisition' : 'Реквизиция',
    _ => english ? 'Events' : 'События',
  };
}

String _phaseIconAsset(String phase) {
  final icon = switch (phase) {
    phasePlanning => 'icon-crop-seal.png',
    phaseSwap => 'icon-toolbar-swap.png',
    phasePass => 'icon-pass.png',
    phaseTrick => 'icon-toolbar-play.png',
    phaseAssignment => 'icon-toolbar-assign.png',
    phaseRequisition => 'icon-requisition-north.png',
    _ => 'icon-game-log.png',
  };
  return 'assets/ui/Icons/$icon';
}

List<Widget> _actionWidgets(
  EngineAction action,
  KolkhozLanguage language,
  DesignTokens tokens,
) {
  final english = language == KolkhozLanguage.en;
  _InlineLogText text(String en, String ru) =>
      _InlineLogText(text: english ? en : ru, tokens: tokens);
  final card = action.card;
  return switch (action.kind) {
    actionSetTrump => [
      text('selected', 'выбрал'),
      _InlineSuitIcon(suit: action.suit, tokens: tokens),
      text('as trump.', 'козырем.'),
    ],
    actionRevealReward => [
      text('revealed a job reward.', 'открыл награду за работу.'),
    ],
    actionRevealTrump => [
      text('revealed the final-year trump.', 'открыл козырь последнего года.'),
    ],
    actionSwap =>
      action.handCard == null || action.plotCard == null
          ? [
              text(
                'exchanged a hand card with a hidden plot card.',
                'обменял карту руки на скрытую карту участка.',
              ),
            ]
          : [
              text('exchanged', 'обменял'),
              _InlineCard(card: action.handCard!, tokens: tokens),
              text('for', 'на'),
              _InlineCard(card: action.plotCard!, tokens: tokens),
              text('.', '.'),
            ],
    actionUndoSwap => [
      text('undid the last plot exchange.', 'отменил последний обмен.'),
    ],
    actionConfirmSwap => [
      text('confirmed the plot exchange.', 'подтвердил обмен.'),
    ],
    actionPassCard => [
      text('locked a card for the pass.', 'выбрал карту для передачи.'),
    ],
    actionPlayCard =>
      card == null
          ? [text('played a hidden card.', 'сыграл скрытую карту.')]
          : [
              text('played', 'сыграл'),
              _InlineCard(card: card, tokens: tokens),
              text('.', '.'),
            ],
    actionAssign =>
      card == null
          ? [text('assigned a hidden card.', 'назначил скрытую карту.')]
          : [
              text('assigned', 'назначил'),
              _InlineCard(card: card, tokens: tokens),
              text('to', 'на'),
              _InlineSuitIcon(suit: action.targetSuit, tokens: tokens),
              text('.', '.'),
            ],
    actionSubmitAssignments => [
      text('submitted job assignments.', 'завершил назначение работ.'),
    ],
    actionContinueAfterRequisition => [
      text('completed requisition.', 'завершил реквизицию.'),
    ],
    actionRequisitionEvent => switch (action.requisitionKind) {
      1 => [
        text('lost', 'лишился'),
        if (card != null) _InlineCard(card: card, tokens: tokens),
        text('to', 'из-за'),
        _InlineSuitIcon(suit: action.suit, tokens: tokens),
        text('requisition.', 'реквизиции.'),
      ],
      2 => [
        text('No matching card was found for', 'Не найдена карта для'),
        _InlineSuitIcon(suit: action.suit, tokens: tokens),
        text('.', '.'),
      ],
      3 => [
        text('Drunkard', 'Пьяница'),
        if (card != null) _InlineCard(card: card, tokens: tokens),
        text('was sent north for', 'отправлен на север за'),
        _InlineSuitIcon(suit: action.suit, tokens: tokens),
        text('.', '.'),
      ],
      4 => [text('was protected from requisition.', 'защищён от реквизиции.')],
      _ => [text('requisition resolved.', 'реквизиция завершена.')],
    },
    _ => [text('performed ${action.kind}.', '${action.kind}.')],
  };
}

Seat _playerSeat(TableViewModel model, int playerID) {
  for (final seat in model.table.seats) {
    if (seat.id == playerID) {
      return seat;
    }
  }
  return model.table.seats.first;
}

String _reactionLabel(String reactionID, KolkhozLanguage language) {
  final english = language == KolkhozLanguage.en;
  return switch (reactionID) {
    'comrade' => english ? 'Comrade' : 'Товарищ',
    'medal' => english ? 'Well played' : 'Отлично',
    'protected' => english ? 'Protected' : 'Защищено',
    'warning' => english ? 'Warning' : 'Внимание',
    'wheat' => english ? 'Harvest' : 'Урожай',
    'wrecker' => english ? 'Wrecker' : 'Вредитель',
    _ => reactionID,
  };
}
