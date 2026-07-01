import Foundation
import KolkhozCore

struct Options {
    var modelPath: String?
    var baselineModelPath: String?
    var gamesPerSeat = 100
    var seed: UInt64 = 3_000_000
    var minWinDelta = 0.02
    var minSeatWinDelta = 0.0
    var minRankDelta = 0.0
    var minSeatRankDelta = 0.0
    var minMarginDelta = 0.0
    var minSeatMarginDelta = 0.0
    var bootstrapSamples = 2_000
}

struct Sample {
    let gameIndex: Int
    let seat: Int
    let candidateWin: Double
    let heuristicWin: Double
    let candidateStrictWin: Double
    let heuristicStrictWin: Double
    let candidateRank: Double
    let heuristicRank: Double
    let candidateMargin: Double
    let heuristicMargin: Double
}

struct GameOutcome {
    let scores: [Int: Int]
    let medals: [Int: Int]
    let winnerID: Int
}

struct Interval {
    let mean: Double
    let low: Double
    let high: Double
}

struct GateResult {
    let passed: Bool
    let winnerDelta: Interval
    let rankDelta: Interval
    let marginDelta: Interval
}

struct BootstrapRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }

    mutating func nextInt(upperBound: Int) -> Int {
        Int(next() % UInt64(upperBound))
    }
}

enum BenchmarkError: Error {
    case missingModel
    case incompatibleModel
    case gameDidNotFinish
    case invalidPolicyAction
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--model":
            options.modelPath = args.isEmpty ? nil : args.removeFirst()
        case "--baseline-model":
            options.baselineModelPath = args.isEmpty ? nil : args.removeFirst()
        case "--games-per-seat":
            if let value = args.first, let parsed = Int(value) {
                options.gamesPerSeat = parsed
                args.removeFirst()
            }
        case "--seed":
            if let value = args.first, let parsed = UInt64(value) {
                options.seed = parsed
                args.removeFirst()
            }
        case "--min-win-delta":
            if let value = args.first, let parsed = Double(value) {
                options.minWinDelta = parsed
                args.removeFirst()
            }
        case "--min-seat-win-delta":
            if let value = args.first, let parsed = Double(value) {
                options.minSeatWinDelta = parsed
                args.removeFirst()
            }
        case "--min-rank-delta":
            if let value = args.first, let parsed = Double(value) {
                options.minRankDelta = parsed
                args.removeFirst()
            }
        case "--min-seat-rank-delta":
            if let value = args.first, let parsed = Double(value) {
                options.minSeatRankDelta = parsed
                args.removeFirst()
            }
        case "--min-margin-delta":
            if let value = args.first, let parsed = Double(value) {
                options.minMarginDelta = parsed
                args.removeFirst()
            }
        case "--min-seat-margin-delta":
            if let value = args.first, let parsed = Double(value) {
                options.minSeatMarginDelta = parsed
                args.removeFirst()
            }
        case "--bootstrap-samples":
            if let value = args.first, let parsed = Int(value) {
                options.bootstrapSamples = max(0, parsed)
                args.removeFirst()
            }
        default:
            break
        }
    }
    return options
}

func playGame(seed: UInt64, model: KolkhozPolicyModel?, modelSeat: Int?) throws -> GameOutcome {
    let seatModels: [Int: KolkhozPolicyModel]
    if let model, let modelSeat {
        seatModels = [modelSeat: model]
    } else {
        seatModels = [:]
    }

    let engine = KolkhozEngine(seed: seed, variants: .kolkhoz, aiModel: nil, aiModels: seatModels)
    var guardCount = 0

    while engine.state.phase != .gameOver && guardCount < 1_000 {
        guardCount += 1
        let humanModel = modelSeat == 0 ? model : nil
        let decider = KolkhozAIDecider(state: engine.state, model: humanModel)

        switch engine.state.phase {
        case .planning where engine.state.currentPlayer == 0:
            try engine.setTrump(decider.chooseTrump(for: 0))

        case .swap where engine.state.currentPlayer == 0:
            if let choice = decider.chooseSwap(for: 0) {
                try engine.swap(handCard: choice.handCard, plotCard: choice.plotCard, revealed: choice.zone == .revealed)
            }
            try engine.confirmSwap()

        case .trick where engine.state.currentPlayer == 0:
            let index = decider.chooseCardIndex(for: 0)
            guard engine.state.players[0].hand.indices.contains(index) else {
                throw BenchmarkError.invalidPolicyAction
            }
            try engine.playCard(engine.state.players[0].hand[index])

        case .assignment where engine.state.lastWinner == 0:
            let assignments = decider.chooseAssignments(for: 0)
            for play in engine.state.lastTrick {
                guard let suit = assignments[play.card.id] else {
                    throw BenchmarkError.invalidPolicyAction
                }
                try engine.assign(card: play.card, to: suit)
            }
            try engine.submitAssignments()

        case .requisition:
            engine.continueAfterRequisition()

        default:
            break
        }
    }

    guard engine.state.phase == .gameOver, let result = engine.state.gameResult else {
        throw BenchmarkError.gameDidNotFinish
    }
    let medals = Dictionary(uniqueKeysWithValues: engine.state.players.map { ($0.id, $0.plot.medals + $0.medals) })
    return GameOutcome(scores: result.scores, medals: medals, winnerID: result.winnerID)
}

func beats(_ lhs: Int, _ rhs: Int, scores: [Int: Int], medals: [Int: Int]) -> Bool {
    let lhsScore = scores[lhs] ?? 0
    let rhsScore = scores[rhs] ?? 0
    if lhsScore != rhsScore { return lhsScore > rhsScore }
    let lhsMedals = medals[lhs] ?? 0
    let rhsMedals = medals[rhs] ?? 0
    if lhsMedals != rhsMedals { return lhsMedals > rhsMedals }
    return lhs > rhs
}

func rank(of playerID: Int, outcome: GameOutcome) -> Int {
    1 + outcome.scores.keys.filter { $0 != playerID && beats($0, playerID, scores: outcome.scores, medals: outcome.medals) }.count
}

func metrics(for playerID: Int, outcome: GameOutcome) -> (win: Double, strictWin: Double, rank: Double, margin: Double) {
    let scores = outcome.scores
    let playerScore = scores[playerID] ?? 0
    let bestOpponent = scores
        .filter { $0.key != playerID }
        .map(\.value)
        .max() ?? 0
    let isStrictWinner = !scores.keys.contains { $0 != playerID && beats($0, playerID, scores: scores, medals: outcome.medals) }
    return (
        win: outcome.winnerID == playerID ? 1 : 0,
        strictWin: isStrictWinner ? 1 : 0,
        rank: Double(rank(of: playerID, outcome: outcome)),
        margin: Double(playerScore - bestOpponent)
    )
}

func interval(_ values: [Double]) -> Interval {
    let mean = values.reduce(0, +) / Double(values.count)
    guard values.count > 1 else { return Interval(mean: mean, low: mean, high: mean) }
    let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
    let standardError = sqrt(variance / Double(values.count))
    let radius = 1.96 * standardError
    return Interval(mean: mean, low: mean - radius, high: mean + radius)
}

func bootstrapInterval(
    samples: [Sample],
    values: (Sample) -> Double,
    gamesPerSeat: Int,
    bootstrapSamples: Int,
    seed: UInt64
) -> Interval {
    let observed = mean(samples.map(values))
    guard bootstrapSamples > 0, gamesPerSeat > 1, !samples.isEmpty else {
        return interval(samples.map(values))
    }

    let byGame = Dictionary(grouping: samples, by: \.gameIndex)
    let gameIndexes = Array(byGame.keys).sorted()
    guard !gameIndexes.isEmpty else { return Interval(mean: observed, low: observed, high: observed) }

    var rng = BootstrapRNG(state: seed)
    var estimates: [Double] = []
    estimates.reserveCapacity(bootstrapSamples)
    for _ in 0..<bootstrapSamples {
        var total = 0.0
        var count = 0
        for _ in 0..<gamesPerSeat {
            let gameIndex = gameIndexes[rng.nextInt(upperBound: gameIndexes.count)]
            for sample in byGame[gameIndex] ?? [] {
                total += values(sample)
                count += 1
            }
        }
        estimates.append(count > 0 ? total / Double(count) : observed)
    }
    estimates.sort()
    let lowIndex = max(0, min(estimates.count - 1, Int(Double(estimates.count - 1) * 0.025)))
    let highIndex = max(0, min(estimates.count - 1, Int(Double(estimates.count - 1) * 0.975)))
    return Interval(mean: observed, low: estimates[lowIndex], high: estimates[highIndex])
}

func format(_ interval: Interval) -> String {
    "\(String(format: "%.4f", interval.mean)) [\(String(format: "%.4f", interval.low)), \(String(format: "%.4f", interval.high))]"
}

func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

func printSummary(label: String, samples: [Sample], options: Options, gate: Bool, seed: UInt64) -> GateResult {
    let winDelta = bootstrapInterval(
        samples: samples,
        values: { $0.candidateWin - $0.heuristicWin },
        gamesPerSeat: options.gamesPerSeat,
        bootstrapSamples: options.bootstrapSamples,
        seed: seed
    )
    let strictWinDelta = bootstrapInterval(
        samples: samples,
        values: { $0.candidateStrictWin - $0.heuristicStrictWin },
        gamesPerSeat: options.gamesPerSeat,
        bootstrapSamples: options.bootstrapSamples,
        seed: seed &+ 1
    )
    let rankDelta = bootstrapInterval(
        samples: samples,
        values: { $0.heuristicRank - $0.candidateRank },
        gamesPerSeat: options.gamesPerSeat,
        bootstrapSamples: options.bootstrapSamples,
        seed: seed &+ 2
    )
    let marginDelta = bootstrapInterval(
        samples: samples,
        values: { $0.candidateMargin - $0.heuristicMargin },
        gamesPerSeat: options.gamesPerSeat,
        bootstrapSamples: options.bootstrapSamples,
        seed: seed &+ 3
    )
    let candidateWinRate = mean(samples.map(\.candidateWin))
    let heuristicWinRate = mean(samples.map(\.heuristicWin))
    let candidateStrictWinRate = mean(samples.map(\.candidateStrictWin))
    let heuristicStrictWinRate = mean(samples.map(\.heuristicStrictWin))
    let candidateAvgRank = mean(samples.map(\.candidateRank))
    let heuristicAvgRank = mean(samples.map(\.heuristicRank))
    let candidateAvgMargin = mean(samples.map(\.candidateMargin))
    let heuristicAvgMargin = mean(samples.map(\.heuristicMargin))

    print("\(label) samples=\(samples.count)")
    print("  candidate_winner_rate=\(String(format: "%.4f", candidateWinRate)) heuristic_winner_rate=\(String(format: "%.4f", heuristicWinRate))")
    print("  candidate_strict_win_rate=\(String(format: "%.4f", candidateStrictWinRate)) heuristic_strict_win_rate=\(String(format: "%.4f", heuristicStrictWinRate))")
    print("  candidate_avg_rank=\(String(format: "%.4f", candidateAvgRank)) heuristic_avg_rank=\(String(format: "%.4f", heuristicAvgRank))")
    print("  candidate_avg_margin=\(String(format: "%.4f", candidateAvgMargin)) heuristic_avg_margin=\(String(format: "%.4f", heuristicAvgMargin))")
    print("  winner_delta=\(format(winDelta))")
    print("  strict_win_delta=\(format(strictWinDelta))")
    print("  rank_delta=\(format(rankDelta)) positive_is_better")
    print("  margin_delta=\(format(marginDelta))")

    guard gate else { return GateResult(passed: false, winnerDelta: winDelta, rankDelta: rankDelta, marginDelta: marginDelta) }
    let minWinDelta = label == "aggregate" ? options.minWinDelta : options.minSeatWinDelta
    let minRankDelta = label == "aggregate" ? options.minRankDelta : options.minSeatRankDelta
    let minMarginDelta = label == "aggregate" ? options.minMarginDelta : options.minSeatMarginDelta
    let passes = winDelta.low >= minWinDelta && rankDelta.low >= minRankDelta && marginDelta.low >= minMarginDelta
    print("  min_required_winner_low=\(String(format: "%.4f", minWinDelta))")
    print("  min_required_rank_low=\(String(format: "%.4f", minRankDelta))")
    print("  min_required_margin_low=\(String(format: "%.4f", minMarginDelta))")
    print("  promotion_gate=\(passes ? "pass" : "fail")")
    return GateResult(passed: passes, winnerDelta: winDelta, rankDelta: rankDelta, marginDelta: marginDelta)
}

func main() throws {
    let options = parseOptions()
    guard let modelPath = options.modelPath else { throw BenchmarkError.missingModel }
    let model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: modelPath))
    guard model.isCompatible else { throw BenchmarkError.incompatibleModel }
    let baselineModel = try options.baselineModelPath.map { try KolkhozPolicyModel.load(from: URL(fileURLWithPath: $0)) }
    if let baselineModel {
        guard baselineModel.isCompatible else { throw BenchmarkError.incompatibleModel }
    }

    var samples: [Sample] = []
    for seat in 0..<4 {
        for gameIndex in 0..<options.gamesPerSeat {
            let seed = options.seed + UInt64(gameIndex)
            let candidateScores = try playGame(seed: seed, model: model, modelSeat: seat)
            let heuristicScores = try playGame(seed: seed, model: baselineModel, modelSeat: baselineModel == nil ? nil : seat)
            let candidate = metrics(for: seat, outcome: candidateScores)
            let heuristic = metrics(for: seat, outcome: heuristicScores)
            samples.append(Sample(
                gameIndex: gameIndex,
                seat: seat,
                candidateWin: candidate.win,
                heuristicWin: heuristic.win,
                candidateStrictWin: candidate.strictWin,
                heuristicStrictWin: heuristic.strictWin,
                candidateRank: candidate.rank,
                heuristicRank: heuristic.rank,
                candidateMargin: candidate.margin,
                heuristicMargin: heuristic.margin
            ))
        }
    }

    let baselineLabel = baselineModel == nil ? "heuristic" : "baseline_model"
    print("paired_real_engine_benchmark games_per_seat=\(options.gamesPerSeat) seed=\(options.seed) baseline=\(baselineLabel) bootstrap_samples=\(options.bootstrapSamples)")
    let aggregate = printSummary(label: "aggregate", samples: samples, options: options, gate: true, seed: options.seed ^ 0xA11CE)
    var seatPasses: [Bool] = []
    for seat in 0..<4 {
        let result = printSummary(
            label: "seat_\(seat)",
            samples: samples.filter { $0.seat == seat },
            options: options,
            gate: true,
            seed: options.seed ^ UInt64(0xBEE0 + seat)
        )
        seatPasses.append(result.passed)
    }
    let passes = aggregate.passed && seatPasses.allSatisfy { $0 }
    print("promotion_gate_overall=\(passes ? "pass" : "fail")")
    if !passes {
        exit(2)
    }
}

do {
    try main()
} catch {
    fputs("KolkhozPolicyBenchmark failed: \(error)\n", stderr)
    exit(1)
}
