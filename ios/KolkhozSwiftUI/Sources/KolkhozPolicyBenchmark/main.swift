import Foundation
import KolkhozCore

struct Options {
    var modelPath: String?
    var gamesPerSeat = 100
    var seed: UInt64 = 3_000_000
    var minWinDelta = 0.02
}

struct Sample {
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

struct Interval {
    let mean: Double
    let low: Double
    let high: Double
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
        default:
            break
        }
    }
    return options
}

func playGame(seed: UInt64, model: KolkhozPolicyModel?, modelSeat: Int?) throws -> [Int: Int] {
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
    return result.scores
}

func rank(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    return 1 + scores.values.filter { $0 > target }.count
}

func metrics(for playerID: Int, scores: [Int: Int]) -> (win: Double, strictWin: Double, rank: Double, margin: Double) {
    let playerScore = scores[playerID] ?? 0
    let bestOpponent = scores
        .filter { $0.key != playerID }
        .map(\.value)
        .max() ?? 0
    return (
        win: playerScore >= bestOpponent ? 1 : 0,
        strictWin: playerScore > bestOpponent ? 1 : 0,
        rank: Double(rank(of: playerID, scores: scores)),
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

func format(_ interval: Interval) -> String {
    "\(String(format: "%.4f", interval.mean)) [\(String(format: "%.4f", interval.low)), \(String(format: "%.4f", interval.high))]"
}

func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(values.count)
}

func printSummary(label: String, samples: [Sample], minWinDelta: Double? = nil) -> Bool {
    let winDelta = interval(samples.map { $0.candidateWin - $0.heuristicWin })
    let strictWinDelta = interval(samples.map { $0.candidateStrictWin - $0.heuristicStrictWin })
    let rankDelta = interval(samples.map { $0.heuristicRank - $0.candidateRank })
    let marginDelta = interval(samples.map { $0.candidateMargin - $0.heuristicMargin })
    let candidateWinRate = mean(samples.map(\.candidateWin))
    let heuristicWinRate = mean(samples.map(\.heuristicWin))
    let candidateStrictWinRate = mean(samples.map(\.candidateStrictWin))
    let heuristicStrictWinRate = mean(samples.map(\.heuristicStrictWin))
    let candidateAvgRank = mean(samples.map(\.candidateRank))
    let heuristicAvgRank = mean(samples.map(\.heuristicRank))
    let candidateAvgMargin = mean(samples.map(\.candidateMargin))
    let heuristicAvgMargin = mean(samples.map(\.heuristicMargin))

    print("\(label) samples=\(samples.count)")
    print("  candidate_top_rate=\(String(format: "%.4f", candidateWinRate)) heuristic_top_rate=\(String(format: "%.4f", heuristicWinRate))")
    print("  candidate_strict_win_rate=\(String(format: "%.4f", candidateStrictWinRate)) heuristic_strict_win_rate=\(String(format: "%.4f", heuristicStrictWinRate))")
    print("  candidate_avg_rank=\(String(format: "%.4f", candidateAvgRank)) heuristic_avg_rank=\(String(format: "%.4f", heuristicAvgRank))")
    print("  candidate_avg_margin=\(String(format: "%.4f", candidateAvgMargin)) heuristic_avg_margin=\(String(format: "%.4f", heuristicAvgMargin))")
    print("  top_or_tied_delta=\(format(winDelta))")
    print("  strict_win_delta=\(format(strictWinDelta))")
    print("  rank_delta=\(format(rankDelta)) positive_is_better")
    print("  margin_delta=\(format(marginDelta))")

    guard let minWinDelta else { return false }
    let passes = winDelta.low >= minWinDelta && rankDelta.low > 0 && marginDelta.low > 0
    print("  min_required_top_or_tied_low=\(String(format: "%.4f", minWinDelta))")
    print("  promotion_gate=\(passes ? "pass" : "fail")")
    return passes
}

func main() throws {
    let options = parseOptions()
    guard let modelPath = options.modelPath else { throw BenchmarkError.missingModel }
    let model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: modelPath))
    guard model.isCompatible else { throw BenchmarkError.incompatibleModel }

    var samples: [Sample] = []
    for seat in 0..<4 {
        for gameIndex in 0..<options.gamesPerSeat {
            let seed = options.seed + UInt64(seat * options.gamesPerSeat + gameIndex)
            let candidateScores = try playGame(seed: seed, model: model, modelSeat: seat)
            let heuristicScores = try playGame(seed: seed, model: nil, modelSeat: nil)
            let candidate = metrics(for: seat, scores: candidateScores)
            let heuristic = metrics(for: seat, scores: heuristicScores)
            samples.append(Sample(
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

    print("paired_real_engine_benchmark games_per_seat=\(options.gamesPerSeat) seed=\(options.seed)")
    _ = printSummary(label: "aggregate", samples: samples, minWinDelta: options.minWinDelta)
    for seat in 0..<4 {
        _ = printSummary(label: "seat_\(seat)", samples: samples.filter { $0.seat == seat })
    }
}

do {
    try main()
} catch {
    fputs("KolkhozPolicyBenchmark failed: \(error)\n", stderr)
    exit(1)
}
