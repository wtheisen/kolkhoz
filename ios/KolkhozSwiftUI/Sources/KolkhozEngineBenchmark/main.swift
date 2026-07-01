import Foundation
import KolkhozCEngine
import KolkhozCore

struct BenchmarkFailure: Error, CustomStringConvertible {
    let message: String
    var description: String { message }
}

struct BenchmarkResult {
    let label: String
    let games: Int
    let actions: Int
    let seconds: Double
    let checksum: Int

    var gamesPerSecond: Double { Double(games) / seconds }
    var actionsPerSecond: Double { Double(actions) / seconds }
}

struct TrainingBenchmarkResult {
    let label: String
    let episodes: Int
    let actions: Int
    let seconds: Double
    let checksum: Int
    let weightChecksum: Double

    var episodesPerSecond: Double { Double(episodes) / seconds }
    var actionsPerSecond: Double { Double(actions) / seconds }
}

func parseGames(default defaultGames: Int) -> Int {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "--games"), args.indices.contains(index + 1), let value = Int(args[index + 1]) else {
        return defaultGames
    }
    return max(1, value)
}

func parseEpisodes(default defaultEpisodes: Int) -> Int {
    let args = ProcessInfo.processInfo.arguments
    guard let index = args.firstIndex(of: "--episodes"), args.indices.contains(index + 1), let value = Int(args[index + 1]) else {
        return defaultEpisodes
    }
    return max(1, value)
}

func chooseAction(from actions: [KolkhozEngineAction]) throws -> KolkhozEngineAction {
    if let swap = preferredSwap(from: actions) {
        return swap
    }
    if let submit = actions.first(where: { $0.kind == .submitAssignments }) {
        return submit
    }
    if let confirm = actions.first(where: { $0.kind == .confirmSwap }) {
        return confirm
    }
    if let continueAction = actions.first(where: { $0.kind == .continueAfterRequisition }) {
        return continueAction
    }
    guard let first = actions.sorted(by: actionSort).first else {
        throw BenchmarkFailure(message: "no legal actions")
    }
    return first
}

func preferredSwap(from actions: [KolkhozEngineAction]) -> KolkhozEngineAction? {
    let swaps = actions.filter { $0.kind == .swap }
    guard !swaps.isEmpty else { return nil }
    let sorted = swaps.sorted { lhs, rhs in
        let leftDelta = lhs.plotCard.value - lhs.handCard.value
        let rightDelta = rhs.plotCard.value - rhs.handCard.value
        if leftDelta != rightDelta {
            return leftDelta > rightDelta
        }
        return actionSort(lhs, rhs)
    }
    guard let best = sorted.first, best.plotCard.value > best.handCard.value + 1 else {
        return nil
    }
    return best
}

func actionSort(_ lhs: KolkhozEngineAction, _ rhs: KolkhozEngineAction) -> Bool {
    actionKey(lhs).lexicographicallyPrecedes(actionKey(rhs))
}

func actionKey(_ action: KolkhozEngineAction) -> [Int32] {
    [
        action.kind.rawValue,
        action.playerID,
        action.suit,
        action.card.suit,
        action.card.value,
        action.handCard.suit,
        action.handCard.value,
        action.plotCard.suit,
        action.plotCard.value,
        action.plotZone,
        action.targetSuit
    ]
}

let gradientFeatureCount = 16

func gradientFeatures(snapshot: KolkhozEngineSnapshot, action: KolkhozEngineAction, legalCount: Int) -> [Double] {
    [
        1,
        Double(snapshot.year) / 5,
        Double(snapshot.trickCount) / 4,
        Double(snapshot.phase) / 5,
        Double(snapshot.currentPlayer) / 3,
        Double(action.kind.rawValue) / 7,
        action.suit >= 0 ? Double(action.suit) / 3 : 0,
        action.card.suit >= 0 ? Double(action.card.suit) / 3 : 0,
        action.card.value > 0 ? Double(action.card.value) / 13 : 0,
        action.handCard.value > 0 ? Double(action.handCard.value) / 13 : 0,
        action.plotCard.value > 0 ? Double(action.plotCard.value) / 13 : 0,
        Double(action.plotCard.value - action.handCard.value) / 13,
        action.targetSuit >= 0 ? Double(action.targetSuit) / 3 : 0,
        Double(legalCount) / 64,
        action.kind == .swap ? 1 : 0,
        (action.kind == .submitAssignments || action.kind == .continueAfterRequisition) ? 1 : 0
    ]
}

func dot(_ weights: [Double], _ features: [Double]) -> Double {
    zip(weights, features).reduce(0) { $0 + $1.0 * $1.1 }
}

func chooseGradientAction(
    actions: [KolkhozEngineAction],
    snapshot: KolkhozEngineSnapshot,
    weights: [Double],
    gradient: inout [Double]
) throws -> KolkhozEngineAction {
    guard !actions.isEmpty else {
        throw BenchmarkFailure(message: "no legal gradient actions")
    }
    let features = actions.map { gradientFeatures(snapshot: snapshot, action: $0, legalCount: actions.count) }
    let scores = features.map { dot(weights, $0) }
    let chosenIndex = actions.indices.max { lhs, rhs in
        if scores[lhs] == scores[rhs] {
            return actionSort(actions[rhs], actions[lhs])
        }
        return scores[lhs] < scores[rhs]
    } ?? 0
    let maxScore = scores.max() ?? 0
    let expScores = scores.map { Foundation.exp($0 - maxScore) }
    let total = expScores.reduce(0, +)
    for featureIndex in 0..<gradientFeatureCount {
        let expected = actions.indices.reduce(0.0) { partial, index in
            partial + (expScores[index] / max(total, .leastNonzeroMagnitude)) * features[index][featureIndex]
        }
        gradient[featureIndex] += features[chosenIndex][featureIndex] - expected
    }
    return actions[chosenIndex]
}

@inline(never)
func runSwiftGame(seed: UInt64, variants: GameVariants) throws -> (actions: Int, checksum: Int) {
    let engine = KolkhozEngine(
        seed: seed,
        variants: variants,
        controllers: KolkhozHeadlessEngine.allHumanControllers,
        aiModel: nil
    )
    var actions = 0
    while engine.state.phase != .gameOver {
        let action = try chooseAction(from: KolkhozHeadlessEngine.legalActions(for: engine))
        try KolkhozHeadlessEngine.apply(action, to: engine)
        actions += 1
    }
    let result = engine.state.gameResult
    let checksum = (result?.winnerID ?? -1) * 31 + (result?.scores.values.reduce(0, +) ?? 0)
    return (actions, checksum)
}

@inline(never)
func runSwiftGradientTraining(label: String, episodes: Int, variants: GameVariants) throws -> TrainingBenchmarkResult {
    var weights = Array(repeating: 0.0, count: gradientFeatureCount)
    var actionCount = 0
    var checksum = 0
    let start = DispatchTime.now().uptimeNanoseconds
    for episode in 0..<episodes {
        let engine = KolkhozEngine(
            seed: UInt64(episode + 1),
            variants: variants,
            controllers: KolkhozHeadlessEngine.allHumanControllers,
            aiModel: nil
        )
        var gradient = Array(repeating: 0.0, count: gradientFeatureCount)
        var episodeActions = 0
        while engine.state.phase != .gameOver && episodeActions < 1_000 {
            let actions = KolkhozHeadlessEngine.legalActions(for: engine)
            let snapshot = KolkhozEngineSnapshot(engine: engine)
            let action = try chooseGradientAction(actions: actions, snapshot: snapshot, weights: weights, gradient: &gradient)
            try KolkhozHeadlessEngine.apply(action, to: engine)
            episodeActions += 1
        }
        guard let result = engine.state.gameResult else {
            throw BenchmarkFailure(message: "Swift gradient game did not finish")
        }
        let playerScore = result.scores[0] ?? 0
        let bestOpponent = result.scores.filter { $0.key != 0 }.map(\.value).max() ?? 0
        let step = 0.01 * (Double(playerScore - bestOpponent) / 50) / Double(max(1, episodeActions))
        for index in weights.indices {
            weights[index] += step * gradient[index]
        }
        actionCount += episodeActions
        checksum &+= (result.winnerID * 31 + result.scores.values.reduce(0, +))
    }
    let end = DispatchTime.now().uptimeNanoseconds
    let weightChecksum = weights.enumerated().reduce(0.0) { $0 + $1.element * Double($1.offset + 1) }
    return TrainingBenchmarkResult(
        label: label,
        episodes: episodes,
        actions: actionCount,
        seconds: Double(end - start) / 1_000_000_000,
        checksum: checksum,
        weightChecksum: weightChecksum
    )
}

@inline(never)
func runCBridgeGradientTraining(label: String, episodes: Int, variants: GameVariants) throws -> TrainingBenchmarkResult {
    var weights = Array(repeating: 0.0, count: gradientFeatureCount)
    var actionCount = 0
    var checksum = 0
    let start = DispatchTime.now().uptimeNanoseconds
    for episode in 0..<episodes {
        let engine = KolkhozHeadlessEngine(seed: UInt64(episode + 1), variants: variants)
        var gradient = Array(repeating: 0.0, count: gradientFeatureCount)
        var episodeActions = 0
        while engine.phaseCode != 5 && episodeActions < 1_000 {
            let actions = engine.legalActions()
            let snapshot = engine.snapshot
            let action = try chooseGradientAction(actions: actions, snapshot: snapshot, weights: weights, gradient: &gradient)
            try engine.apply(action)
            episodeActions += 1
        }
        let snapshot = engine.snapshot
        let playerScore = snapshot.scores.first(where: { $0.playerID == 0 }).map { Int($0.finalScore) } ?? 0
        let bestOpponent = snapshot.scores.filter { $0.playerID != 0 }.map { Int($0.finalScore) }.max() ?? 0
        let step = 0.01 * (Double(playerScore - bestOpponent) / 50) / Double(max(1, episodeActions))
        for index in weights.indices {
            weights[index] += step * gradient[index]
        }
        actionCount += episodeActions
        checksum &+= (Int(snapshot.winnerID) * 31 + snapshot.scores.reduce(0) { $0 + Int($1.finalScore) })
    }
    let end = DispatchTime.now().uptimeNanoseconds
    let weightChecksum = weights.enumerated().reduce(0.0) { $0 + $1.element * Double($1.offset + 1) }
    return TrainingBenchmarkResult(
        label: label,
        episodes: episodes,
        actions: actionCount,
        seconds: Double(end - start) / 1_000_000_000,
        checksum: checksum,
        weightChecksum: weightChecksum
    )
}

@inline(never)
func runCDirectGradientTraining(label: String, episodes: Int, variants: GameVariants) -> TrainingBenchmarkResult {
    let start = DispatchTime.now().uptimeNanoseconds
    let result = kc_run_gradient_benchmark(1, variants.cVariants, Int32(episodes))
    let end = DispatchTime.now().uptimeNanoseconds
    return TrainingBenchmarkResult(
        label: label,
        episodes: Int(result.episodes),
        actions: Int(result.actions),
        seconds: Double(end - start) / 1_000_000_000,
        checksum: Int(result.checksum),
        weightChecksum: result.weight_checksum
    )
}

@inline(never)
func runCGame(seed: UInt64, variants: GameVariants) throws -> (actions: Int, checksum: Int) {
    let engine = KolkhozHeadlessEngine(seed: seed, variants: variants)
    var actions = 0
    while engine.phaseCode != 5 {
        let action = try chooseAction(from: engine.legalActions())
        try engine.apply(action)
        actions += 1
    }
    let snapshot = engine.snapshot
    let checksum = Int(snapshot.winnerID) * 31 + snapshot.scores.reduce(0) { $0 + Int($1.finalScore) }
    return (actions, checksum)
}

@inline(never)
func runCDirectGame(seed: UInt64, variants: GameVariants) throws -> (actions: Int, checksum: Int) {
    let result = kc_run_benchmark_game(seed, variants.cVariants)
    if result.checksum < 0 {
        throw BenchmarkFailure(message: "direct C benchmark failed with checksum \(result.checksum)")
    }
    return (Int(result.actions), Int(result.checksum))
}

func benchmark(
    label: String,
    games: Int,
    variants: GameVariants,
    runner: (UInt64, GameVariants) throws -> (actions: Int, checksum: Int)
) throws -> BenchmarkResult {
    var actions = 0
    var checksum = 0
    let start = DispatchTime.now().uptimeNanoseconds
    for index in 0..<games {
        let result = try runner(UInt64(index + 1), variants)
        actions += result.actions
        checksum &+= result.checksum
    }
    let end = DispatchTime.now().uptimeNanoseconds
    let seconds = Double(end - start) / 1_000_000_000
    return BenchmarkResult(label: label, games: games, actions: actions, seconds: seconds, checksum: checksum)
}

private extension GameVariants {
    var cVariants: KCVariants {
        KCVariants(
            deck_type: Int32(deckType),
            nomenclature: nomenclature,
            allow_swap: allowSwap,
            northern_style: northernStyle,
            mice_variant: miceVariant,
            orden_nachalniku: ordenNachalniku,
            medals_count: medalsCount,
            accumulate_jobs: accumulateJobs,
            hero_of_soviet_union: heroOfSovietUnion
        )
    }
}

func printResult(_ engineName: String, _ result: BenchmarkResult) {
    print(String(
        format: "%@ %-17@ games=%6d actions=%8d time=%8.3fs games/s=%10.1f actions/s=%12.1f checksum=%d",
        engineName,
        result.label as NSString,
        result.games,
        result.actions,
        result.seconds,
        result.gamesPerSecond,
        result.actionsPerSecond,
        result.checksum
    ))
}

func printTrainingResult(_ engineName: String, _ result: TrainingBenchmarkResult) {
    print(String(
        format: "%@ %-17@ episodes=%6d actions=%8d time=%8.3fs episodes/s=%10.1f actions/s=%12.1f checksum=%d weight_checksum=%.6f",
        engineName,
        result.label as NSString,
        result.episodes,
        result.actions,
        result.seconds,
        result.episodesPerSecond,
        result.actionsPerSecond,
        result.checksum,
        result.weightChecksum
    ))
}

let gamesPerSuite = parseGames(default: 2_000)
let trainingEpisodes = parseEpisodes(default: 2_000)
let suites: [(String, GameVariants)] = [
    ("kolkhoz", .kolkhoz),
    ("noSwap", GameVariants(nomenclature: false, allowSwap: false)),
    ("nomenclature52", GameVariants(nomenclature: true)),
    ("medalsCount", GameVariants(nomenclature: false, medalsCount: true)),
    ("mice52", GameVariants(nomenclature: false, miceVariant: true)),
    ("northern52", GameVariants(nomenclature: false, northernStyle: true)),
    ("littleKolkhoz", .littleKolkhoz),
    ("campStyle", .campStyle),
    ("accumulateJobs", GameVariants(nomenclature: false, accumulateJobs: true, heroOfSovietUnion: true))
]

do {
    print("Kolkhoz engine benchmark release-mode recommended; games_per_suite=\(gamesPerSuite)")
    var swiftTotals = BenchmarkResult(label: "TOTAL", games: 0, actions: 0, seconds: 0, checksum: 0)
    var cBridgeTotals = BenchmarkResult(label: "TOTAL", games: 0, actions: 0, seconds: 0, checksum: 0)
    var cDirectTotals = BenchmarkResult(label: "TOTAL", games: 0, actions: 0, seconds: 0, checksum: 0)
    for (label, variants) in suites {
        let swiftResult = try benchmark(label: label, games: gamesPerSuite, variants: variants, runner: runSwiftGame)
        let cBridgeResult = try benchmark(label: label, games: gamesPerSuite, variants: variants, runner: runCGame)
        let cDirectResult = try benchmark(label: label, games: gamesPerSuite, variants: variants, runner: runCDirectGame)
        guard swiftResult.actions == cBridgeResult.actions,
              swiftResult.checksum == cBridgeResult.checksum,
              swiftResult.actions == cDirectResult.actions,
              swiftResult.checksum == cDirectResult.checksum else {
            throw BenchmarkFailure(
                message: "checksum/action mismatch for \(label): Swift actions=\(swiftResult.actions) checksum=\(swiftResult.checksum), C-Bridge actions=\(cBridgeResult.actions) checksum=\(cBridgeResult.checksum), C-Direct actions=\(cDirectResult.actions) checksum=\(cDirectResult.checksum)"
            )
        }
        printResult("Swift", swiftResult)
        printResult("C-Bridge", cBridgeResult)
        printResult("C-Direct", cDirectResult)
        swiftTotals = BenchmarkResult(
            label: "TOTAL",
            games: swiftTotals.games + swiftResult.games,
            actions: swiftTotals.actions + swiftResult.actions,
            seconds: swiftTotals.seconds + swiftResult.seconds,
            checksum: swiftTotals.checksum &+ swiftResult.checksum
        )
        cBridgeTotals = BenchmarkResult(
            label: "TOTAL",
            games: cBridgeTotals.games + cBridgeResult.games,
            actions: cBridgeTotals.actions + cBridgeResult.actions,
            seconds: cBridgeTotals.seconds + cBridgeResult.seconds,
            checksum: cBridgeTotals.checksum &+ cBridgeResult.checksum
        )
        cDirectTotals = BenchmarkResult(
            label: "TOTAL",
            games: cDirectTotals.games + cDirectResult.games,
            actions: cDirectTotals.actions + cDirectResult.actions,
            seconds: cDirectTotals.seconds + cDirectResult.seconds,
            checksum: cDirectTotals.checksum &+ cDirectResult.checksum
        )
    }
    printResult("Swift", swiftTotals)
    printResult("C-Bridge", cBridgeTotals)
    printResult("C-Direct", cDirectTotals)
    print(String(format: "C-Bridge speedup: %.2fx games/s, %.2fx actions/s", cBridgeTotals.gamesPerSecond / swiftTotals.gamesPerSecond, cBridgeTotals.actionsPerSecond / swiftTotals.actionsPerSecond))
    print(String(format: "C-Direct speedup: %.2fx games/s, %.2fx actions/s", cDirectTotals.gamesPerSecond / swiftTotals.gamesPerSecond, cDirectTotals.actionsPerSecond / swiftTotals.actionsPerSecond))

    print("Kolkhoz gradient training benchmark; episodes=\(trainingEpisodes) ruleset=kolkhoz")
    let swiftTraining = try runSwiftGradientTraining(label: "kolkhoz", episodes: trainingEpisodes, variants: .kolkhoz)
    let cBridgeTraining = try runCBridgeGradientTraining(label: "kolkhoz", episodes: trainingEpisodes, variants: .kolkhoz)
    let cDirectTraining = runCDirectGradientTraining(label: "kolkhoz", episodes: trainingEpisodes, variants: .kolkhoz)
    guard swiftTraining.actions == cBridgeTraining.actions,
          swiftTraining.checksum == cBridgeTraining.checksum,
          swiftTraining.actions == cDirectTraining.actions,
          swiftTraining.checksum == cDirectTraining.checksum else {
        throw BenchmarkFailure(
            message: "gradient checksum/action mismatch: Swift actions=\(swiftTraining.actions) checksum=\(swiftTraining.checksum), C-Bridge actions=\(cBridgeTraining.actions) checksum=\(cBridgeTraining.checksum), C-Direct actions=\(cDirectTraining.actions) checksum=\(cDirectTraining.checksum)"
        )
    }
    printTrainingResult("Swift-Grad", swiftTraining)
    printTrainingResult("CBridge-Grad", cBridgeTraining)
    printTrainingResult("CDirect-Grad", cDirectTraining)
    print(String(format: "CBridge gradient speedup: %.2fx episodes/s, %.2fx actions/s", cBridgeTraining.episodesPerSecond / swiftTraining.episodesPerSecond, cBridgeTraining.actionsPerSecond / swiftTraining.actionsPerSecond))
    print(String(format: "CDirect gradient speedup: %.2fx episodes/s, %.2fx actions/s", cDirectTraining.episodesPerSecond / swiftTraining.episodesPerSecond, cDirectTraining.actionsPerSecond / swiftTraining.actionsPerSecond))
} catch {
    fputs("KolkhozEngineBenchmark failed: \(error)\n", stderr)
    exit(1)
}
