import 'package:flutter/material.dart';

import 'contracts.dart';
import 'design_tokens.dart';
import 'fixture_repository.dart';

class FixtureRendererApp extends StatelessWidget {
  const FixtureRendererApp({required this.repository, super.key});

  final FixtureRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Kolkhoz Fixture Renderer',
      home: FutureBuilder<FixtureBundle>(
        future: repository.load(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return ErrorView(error: snapshot.error!);
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return FixtureHome(bundle: snapshot.data!);
        },
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({required this.error, super.key});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('Fixture load failed: $error')));
  }
}

class FixtureHome extends StatefulWidget {
  const FixtureHome({required this.bundle, super.key});

  final FixtureBundle bundle;

  @override
  State<FixtureHome> createState() => _FixtureHomeState();
}

class _FixtureHomeState extends State<FixtureHome> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.bundle.tokens;
    final fixture = widget.bundle.fixtures[selectedIndex];
    return Scaffold(
      backgroundColor: tokens.colors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FixtureHeader(
                fixtures: widget.bundle.fixtures,
                selectedIndex: selectedIndex,
                tokens: tokens,
                onSelected: (index) => setState(() => selectedIndex = index),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: FixtureBoard(fixture: fixture, tokens: tokens),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FixtureHeader extends StatelessWidget {
  const FixtureHeader({
    required this.fixtures,
    required this.selectedIndex,
    required this.tokens,
    required this.onSelected,
    super.key,
  });

  final List<NamedFixture> fixtures;
  final int selectedIndex;
  final DesignTokens tokens;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: [
        Text(
          'Kolkhoz fixtures',
          style: TextStyle(
            color: tokens.colors.gold,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        for (var index = 0; index < fixtures.length; index++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(fixtures[index].name),
              selected: selectedIndex == index,
              onSelected: (_) => onSelected(index),
              selectedColor: tokens.colors.gold,
              backgroundColor: tokens.colors.panel,
              labelStyle: TextStyle(
                color: selectedIndex == index
                    ? tokens.colors.cardInk
                    : tokens.colors.cream,
              ),
            ),
          ),
      ],
    );
  }
}

class FixtureBoard extends StatelessWidget {
  const FixtureBoard({required this.fixture, required this.tokens, super.key});

  final NamedFixture fixture;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final model = fixture.model;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.colors.table,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tokens.colors.gold, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PhaseBanner(model: model, tokens: tokens),
            const SizedBox(height: 10),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 5,
                    child: SeatAndTrickPanel(model: model, tokens: tokens),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 4,
                    child: JobsPanel(model: model, tokens: tokens),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 260,
                    child: InfoPanel(model: model, tokens: tokens),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            HandTray(model: model, tokens: tokens),
          ],
        ),
      ),
    );
  }
}

class PhaseBanner extends StatelessWidget {
  const PhaseBanner({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final table = model.table;
    final trump = table.trump == null ? 'none' : table.trump!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  table.phasePrompt.title,
                  style: TextStyle(
                    color: tokens.colors.gold,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  table.phasePrompt.body,
                  style: TextStyle(color: tokens.colors.creamDim),
                ),
              ],
            ),
          ),
          Text(
            'Year ${table.year}  Phase ${table.phase}  Trump $trump',
            style: TextStyle(
              color: tokens.colors.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class SeatAndTrickPanel extends StatelessWidget {
  const SeatAndTrickPanel({
    required this.model,
    required this.tokens,
    super.key,
  });

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final trick = model.table.lastTrick.plays.isNotEmpty
        ? model.table.lastTrick
        : model.table.trick;
    return Column(
      children: [
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (final seat in model.table.seats)
                SeatTile(seat: seat, tokens: tokens),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 128,
          child: PanelShell(
            tokens: tokens,
            title: 'Trick',
            child: TrickRow(trick: trick, tokens: tokens),
          ),
        ),
      ],
    );
  }
}

class SeatTile extends StatelessWidget {
  const SeatTile({required this.seat, required this.tokens, super.key});

  final Seat seat;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final borderColor = seat.isCurrentTurn
        ? tokens.colors.gold
        : tokens.colors.iron;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: borderColor,
          width: seat.isCurrentTurn ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: seat.isViewer
                ? tokens.colors.gold
                : tokens.colors.iron,
            child: Text('${seat.id + 1}'),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  seat.name,
                  style: TextStyle(
                    color: tokens.colors.cream,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${seat.controller}  score ${seat.visibleScore}',
                  style: TextStyle(color: tokens.colors.creamDim, fontSize: 12),
                ),
                Text(
                  'hand ${seat.hand.isEmpty ? seat.hiddenHandCount : seat.hand.length}  plot ${seat.plot.revealed.length}/${seat.plot.hiddenCount}',
                  style: TextStyle(color: tokens.colors.creamDim, fontSize: 12),
                ),
              ],
            ),
          ),
          if (seat.isBrigadeLeader)
            Icon(Icons.star, color: tokens.colors.gold, size: 18),
        ],
      ),
    );
  }
}

class JobsPanel extends StatelessWidget {
  const JobsPanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      tokens: tokens,
      title: 'Jobs',
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.35,
        children: [
          for (final job in model.table.jobs) JobTile(job: job, tokens: tokens),
        ],
      ),
    );
  }
}

class JobTile extends StatelessWidget {
  const JobTile({required this.job, required this.tokens, super.key});

  final Job job;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final progress = job.hours / job.requiredHours;
    final accent = suitColor(tokens, job.suit);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: job.validAssignmentTarget
            ? tokens.colors.iron
            : tokens.colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: job.highlighted || job.validAssignmentTarget
              ? tokens.colors.gold
              : tokens.colors.iron,
          width: job.validAssignmentTarget ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SuitDot(suit: job.suit, tokens: tokens),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  job.suit,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                job.claimed ? 'done' : '${job.hours}/40',
                style: TextStyle(color: tokens.colors.cream),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            color: job.claimed ? tokens.colors.green : accent,
            backgroundColor: tokens.colors.background,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              if (job.reward != null)
                MiniCard(card: job.reward!, tokens: tokens),
              for (final card in job.assignedCards)
                MiniCard(card: card, tokens: tokens),
            ],
          ),
        ],
      ),
    );
  }
}

class HandTray extends StatelessWidget {
  const HandTray({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final viewer = model.viewer.seatID == null
        ? model.table.seats.first
        : model.table.seats.firstWhere(
            (seat) => seat.id == model.viewer.seatID,
            orElse: () => model.table.seats.first,
          );
    return SizedBox(
      height: 126,
      child: PanelShell(
        tokens: tokens,
        title: 'Hand and legal actions',
        child: Row(
          children: [
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final card in viewer.hand)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GameCard(card: card, tokens: tokens),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final action in model.legalActions.where(
                  (action) => action.enabled,
                ))
                  ActionPill(action: action, tokens: tokens),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({required this.model, required this.tokens, super.key});

  final TableViewModel model;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return PanelShell(
      tokens: tokens,
      title: model.panels.rightInfo.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Panel: ${model.panels.active}',
            style: TextStyle(
              color: tokens.colors.gold,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Online: ${model.viewer.isOnline ? model.viewer.connection : 'offline'}',
            style: TextStyle(color: tokens.colors.creamDim),
          ),
          const SizedBox(height: 12),
          for (final section in model.panels.rightInfo.sections) ...[
            Text(
              section.title,
              style: TextStyle(
                color: tokens.colors.cream,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(section.body, style: TextStyle(color: tokens.colors.creamDim)),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class PanelShell extends StatelessWidget {
  const PanelShell({
    required this.tokens,
    required this.title,
    required this.child,
    super.key,
  });

  final DesignTokens tokens;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: tokens.colors.panel,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tokens.colors.gold.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.colors.gold,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class TrickRow extends StatelessWidget {
  const TrickRow({required this.trick, required this.tokens, super.key});

  final Trick trick;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    if (trick.plays.isEmpty) {
      return Center(
        child: Text(
          'No cards played',
          style: TextStyle(color: tokens.colors.creamDim),
        ),
      );
    }
    return Row(
      children: [
        for (final play in trick.plays)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              children: [
                Text(
                  'Seat ${play.seatID + 1}',
                  style: TextStyle(color: tokens.colors.creamDim, fontSize: 12),
                ),
                MiniCard(card: play.card, tokens: tokens),
              ],
            ),
          ),
      ],
    );
  }
}

class GameCard extends StatelessWidget {
  const GameCard({required this.card, required this.tokens, super.key});

  final ContractCard card;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    final border = card.selected
        ? tokens.colors.green
        : card.highlighted
        ? tokens.colors.gold
        : tokens.colors.iron;
    return Opacity(
      opacity: card.disabled ? 0.5 : 1,
      child: Container(
        width: 50,
        height: 71,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: tokens.colors.cardFill,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: border,
            width: card.selected || card.highlighted ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              card.rank,
              style: TextStyle(
                color: card.highlighted
                    ? tokens.colors.red
                    : tokens.colors.cardInk,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: SuitDot(suit: card.suit, tokens: tokens),
            ),
          ],
        ),
      ),
    );
  }
}

class MiniCard extends StatelessWidget {
  const MiniCard({required this.card, required this.tokens, super.key});

  final ContractCard card;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.colors.cardFill,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: card.pending ? tokens.colors.green : tokens.colors.iron,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.rank,
            style: TextStyle(
              color: tokens.colors.cardInk,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: SuitDot(suit: card.suit, tokens: tokens, size: 8),
          ),
        ],
      ),
    );
  }
}

class SuitDot extends StatelessWidget {
  const SuitDot({
    required this.suit,
    required this.tokens,
    this.size = 12,
    super.key,
  });

  final String suit;
  final DesignTokens tokens;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: suitColor(tokens, suit),
        shape: BoxShape.circle,
      ),
    );
  }
}

class ActionPill extends StatelessWidget {
  const ActionPill({required this.action, required this.tokens, super.key});

  final LegalAction action;
  final DesignTokens tokens;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: tokens.colors.gold,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        action.kind,
        style: TextStyle(
          color: tokens.colors.cardInk,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
