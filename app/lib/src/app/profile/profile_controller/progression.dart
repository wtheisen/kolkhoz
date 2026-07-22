enum ProgressionKind { challenge, achievement, unlock }

class ProgressionDefinition {
  const ProgressionDefinition({
    required this.id,
    required this.kind,
    required this.title,
    required this.description,
    required this.target,
    this.reward,
  });

  final String id;
  final ProgressionKind kind;
  final String title;
  final String description;
  final int target;
  final String? reward;
}

const progressionDefinitions = <ProgressionDefinition>[
  ProgressionDefinition(
    id: 'achievement.first_game',
    kind: ProgressionKind.achievement,
    title: 'First Five-Year Plan',
    description: 'Complete a game.',
    target: 1,
  ),
  ProgressionDefinition(
    id: 'achievement.clear_victory',
    kind: ProgressionKind.achievement,
    title: 'Unquestioned Mandate',
    description: 'Win by at least 25 points.',
    target: 1,
  ),
  ProgressionDefinition(
    id: 'achievement.medalist',
    kind: ProgressionKind.achievement,
    title: 'Order of Labor Glory',
    description: 'Finish a game with at least 5 medals.',
    target: 1,
  ),
  ProgressionDefinition(
    id: 'achievement.no_requisition',
    kind: ProgressionKind.achievement,
    title: 'Untouched Stores',
    description: 'Lose no plot cards during the final requisition.',
    target: 1,
  ),
  ProgressionDefinition(
    id: 'achievement.saboteur_exiled',
    kind: ProgressionKind.achievement,
    title: 'Saboteur Contained',
    description: 'See the Saboteur exiled during a completed game.',
    target: 1,
    reward: 'Beekeeper portrait',
  ),
  ProgressionDefinition(
    id: 'achievement.first_win',
    kind: ProgressionKind.achievement,
    title: 'Model Collective',
    description: 'Win a game.',
    target: 1,
  ),
  ProgressionDefinition(
    id: 'achievement.century',
    kind: ProgressionKind.achievement,
    title: 'Record Harvest',
    description: 'Finish a game with at least 100 points.',
    target: 1,
    reward: 'Agronomist portrait',
  ),
  ProgressionDefinition(
    id: 'challenge.games_5',
    kind: ProgressionKind.challenge,
    title: 'Reliable Comrade',
    description: 'Complete 5 games.',
    target: 5,
    reward: 'Harvest card back',
  ),
  ProgressionDefinition(
    id: 'challenge.wins_3',
    kind: ProgressionKind.challenge,
    title: 'Famine Manager',
    description: 'Win 3 full five-year games.',
    target: 3,
    reward: 'Granary card back',
  ),
  ProgressionDefinition(
    id: 'challenge.score_500',
    kind: ProgressionKind.challenge,
    title: 'Five Hundred Centners',
    description: 'Earn 500 total points across completed games.',
    target: 500,
    reward: 'Winter card back',
  ),
  ProgressionDefinition(
    id: 'challenge.medals_25',
    kind: ProgressionKind.challenge,
    title: 'Hero of the Collective',
    description: 'Earn 25 medals across completed games.',
    target: 25,
    reward: 'Mechanic portrait',
  ),
  ProgressionDefinition(
    id: 'challenge.games_10',
    kind: ProgressionKind.challenge,
    title: 'Veteran Foreman',
    description: 'Complete 10 games.',
    target: 10,
    reward: 'Brigade leader portrait',
  ),
  ProgressionDefinition(
    id: 'challenge.wins_5',
    kind: ProgressionKind.challenge,
    title: 'Against the Machine',
    description: 'Win 5 games.',
    target: 5,
  ),
  ProgressionDefinition(
    id: 'challenge.score_1000',
    kind: ProgressionKind.challenge,
    title: 'Thousand-Centner Harvest',
    description: 'Earn 1,000 total points across completed games.',
    target: 1000,
  ),
];

const progressionUnlockRewards = <String, String>{
  'challenge.games_5': 'unlock.card_back.harvest',
  'challenge.wins_3': 'unlock.card_back.granary',
  'challenge.score_500': 'unlock.card_back.winter',
};

class ProgressionGameSummary {
  const ProgressionGameSummary({
    required this.won,
    required this.score,
    required this.fullFiveYearGame,
    this.margin = 0,
    this.medals = 0,
    this.exiledPlotCards = 0,
    this.saboteurExiled = false,
  });

  final bool won;
  final int score;
  final bool fullFiveYearGame;
  final int margin;
  final int medals;
  final int exiledPlotCards;
  final bool saboteurExiled;
}

class ProgressionState {
  const ProgressionState({
    this.progress = const {},
    this.completed = const {},
    this.unlocks = const {},
  });

  final Map<String, int> progress;
  final Set<String> completed;
  final Set<String> unlocks;

  int progressFor(ProgressionDefinition definition) {
    return (progress[definition.id] ?? 0).clamp(0, definition.target);
  }

  bool isCompleted(String id) => completed.contains(id);

  bool hasUnlock(String id) => unlocks.contains(id);

  Map<String, Object?> toJson() => {
    'progress': progress,
    'completed': completed.toList()..sort(),
    'unlocks': unlocks.toList()..sort(),
  };

  static ProgressionState fromJson(Object? value) {
    if (value is! Map) {
      return const ProgressionState();
    }
    final storedProgress = value['progress'];
    final progress = <String, int>{};
    if (storedProgress is Map) {
      for (final entry in storedProgress.entries) {
        if (entry.key is String && entry.value is int && entry.value >= 0) {
          progress[entry.key as String] = entry.value as int;
        }
      }
    }
    return ProgressionState(
      progress: progress,
      completed: _stringSet(value['completed']),
      unlocks: _stringSet(value['unlocks']),
    );
  }

  static Set<String> _stringSet(Object? value) {
    return value is List ? value.whereType<String>().toSet() : <String>{};
  }
}

class ProgressionUpdate {
  const ProgressionUpdate({required this.state, required this.newCompletions});

  final ProgressionState state;
  final List<ProgressionDefinition> newCompletions;
}

ProgressionState mergeProgressionStates(
  ProgressionState offline,
  ProgressionState online,
) {
  final progress = <String, int>{};
  for (final definition in progressionDefinitions) {
    progress[definition.id] =
        (offline.progressFor(definition) + online.progressFor(definition))
            .clamp(0, definition.target);
  }
  return ProgressionState(
    progress: progress,
    completed: {...offline.completed, ...online.completed},
    unlocks: {...offline.unlocks, ...online.unlocks},
  );
}

ProgressionUpdate evaluateProgression(
  ProgressionState current,
  ProgressionGameSummary game,
) {
  final progress = Map<String, int>.of(current.progress);
  final completed = Set<String>.of(current.completed);
  final unlocks = Set<String>.of(current.unlocks);

  void add(String id, int amount) {
    progress[id] = (progress[id] ?? 0) + amount;
  }

  add('achievement.first_game', 1);
  add('challenge.games_5', 1);
  add('challenge.games_10', 1);
  add('challenge.score_500', game.score);
  add('challenge.score_1000', game.score);
  add('challenge.medals_25', game.medals);
  if (game.won) {
    add('achievement.first_win', 1);
    if (game.fullFiveYearGame) {
      add('challenge.wins_3', 1);
    }
    add('challenge.wins_5', 1);
    if (game.margin >= 25) {
      add('achievement.clear_victory', 1);
    }
  }
  if (game.score >= 100) {
    add('achievement.century', 1);
  }
  if (game.medals >= 5) {
    add('achievement.medalist', 1);
  }
  if (game.exiledPlotCards == 0) {
    add('achievement.no_requisition', 1);
  }
  if (game.saboteurExiled) {
    add('achievement.saboteur_exiled', 1);
  }

  final newCompletions = <ProgressionDefinition>[];
  for (final definition in progressionDefinitions) {
    final value = (progress[definition.id] ?? 0).clamp(0, definition.target);
    progress[definition.id] = value;
    if (value >= definition.target && completed.add(definition.id)) {
      newCompletions.add(definition);
      final reward = progressionUnlockRewards[definition.id];
      if (reward != null) {
        unlocks.add(reward);
      }
    }
  }

  return ProgressionUpdate(
    state: ProgressionState(
      progress: progress,
      completed: completed,
      unlocks: unlocks,
    ),
    newCompletions: newCompletions,
  );
}
