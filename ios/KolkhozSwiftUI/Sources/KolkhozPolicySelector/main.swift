import Foundation
import KolkhozCore

struct Options {
    var modelPaths: [String] = []
    var baselineModelPath = "Sources/KolkhozCore/Resources/kolkhoz_policy.json"
    var seeds: [UInt64] = [15_000_000, 16_000_000]
    var gamesPerSeat = 60
}

struct Sample {
    let seat: Int
    let candidateTop: Double
    let baselineTop: Double
    let candidateStrict: Double
    let baselineStrict: Double
    let candidateRank: Double
    let baselineRank: Double
    let candidateMargin: Double
    let baselineMargin: Double
}

struct Interval {
    let mean: Double
    let low: Double
    let high: Double
}

struct SelectionResult {
    let path: String
    let samples: [Sample]
    let topDelta: Interval
    let strictDelta: Interval
    let rankDelta: Interval
    let marginDelta: Interval
    let worstSeatTop: Double
    let worstSeatRank: Double
    let worstSeatMargin: Double
    let score: Double
}

enum SelectorError: Error {
    case missingModels
    case incompatibleModel(String)
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
            if let value = args.first {
                options.modelPaths.append(value)
                args.removeFirst()
            }
        case "--models":
            if let value = args.first {
                options.modelPaths += value.split(separator: ",").map(String.init)
                args.removeFirst()
            }
        case "--baseline-model":
            if let value = args.first {
                options.baselineModelPath = value
                args.removeFirst()
            }
        case "--seeds":
            if let value = args.first {
                let parsed = value.split(separator: ",").compactMap { UInt64($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                if !parsed.isEmpty {
                    options.seeds = parsed
                }
                args.removeFirst()
            }
        case "--games-per-seat":
            if let value = args.first, let parsed = Int(value) {
                options.gamesPerSeat = parsed
                args.removeFirst()
            }
        default:
            break
        }
    }
    return options
}

func playGame(seed: UInt64, model: KolkhozPolicyModel, modelSeat: Int) throws -> [Int: Int] {
    let engine = KolkhozEngine(seed: seed, variants: .kolkhoz, aiModel: nil, aiModels: [modelSeat: model])
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
                throw SelectorError.invalidPolicyAction
            }
            try engine.playCard(engine.state.players[0].hand[index])
        case .assignment where engine.state.lastWinner == 0:
            let assignments = decider.chooseAssignments(for: 0)
            for play in engine.state.lastTrick {
                guard let suit = assignments[play.card.id] else {
                    throw SelectorError.invalidPolicyAction
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
        throw SelectorError.gameDidNotFinish
    }
    return result.scores
}

func rank(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    return 1 + scores.values.filter { $0 > target }.count
}

func metrics(for playerID: Int, scores: [Int: Int]) -> (top: Double, strict: Double, rank: Double, margin: Double) {
    let score = scores[playerID] ?? 0
    let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
    return (
        top: score >= bestOpponent ? 1 : 0,
        strict: score > bestOpponent ? 1 : 0,
        rank: Double(rank(of: playerID, scores: scores)),
        margin: Double(score - bestOpponent)
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

func format(_ value: Double) -> String {
    String(format: "%.4f", value)
}

func format(_ interval: Interval) -> String {
    "\(format(interval.mean)) [\(format(interval.low)), \(format(interval.high))]"
}

func evaluate(path: String, candidate: KolkhozPolicyModel, baseline: KolkhozPolicyModel, options: Options) throws -> SelectionResult {
    var samples: [Sample] = []
    for seedBase in options.seeds {
        for seat in 0..<4 {
            for gameIndex in 0..<options.gamesPerSeat {
                let seed = seedBase + UInt64(gameIndex)
                let candidateScores = try playGame(seed: seed, model: candidate, modelSeat: seat)
                let baselineScores = try playGame(seed: seed, model: baseline, modelSeat: seat)
                let candidateMetrics = metrics(for: seat, scores: candidateScores)
                let baselineMetrics = metrics(for: seat, scores: baselineScores)
                samples.append(Sample(
                    seat: seat,
                    candidateTop: candidateMetrics.top,
                    baselineTop: baselineMetrics.top,
                    candidateStrict: candidateMetrics.strict,
                    baselineStrict: baselineMetrics.strict,
                    candidateRank: candidateMetrics.rank,
                    baselineRank: baselineMetrics.rank,
                    candidateMargin: candidateMetrics.margin,
                    baselineMargin: baselineMetrics.margin
                ))
            }
        }
    }

    let topDelta = interval(samples.map { $0.candidateTop - $0.baselineTop })
    let strictDelta = interval(samples.map { $0.candidateStrict - $0.baselineStrict })
    let rankDelta = interval(samples.map { $0.baselineRank - $0.candidateRank })
    let marginDelta = interval(samples.map { $0.candidateMargin - $0.baselineMargin })

    let seatTop = (0..<4).map { seat in mean(samples.filter { $0.seat == seat }.map { $0.candidateTop - $0.baselineTop }) }
    let seatRank = (0..<4).map { seat in mean(samples.filter { $0.seat == seat }.map { $0.baselineRank - $0.candidateRank }) }
    let seatMargin = (0..<4).map { seat in mean(samples.filter { $0.seat == seat }.map { $0.candidateMargin - $0.baselineMargin }) }
    let worstSeatTop = seatTop.min() ?? 0
    let worstSeatRank = seatRank.min() ?? 0
    let worstSeatMargin = seatMargin.min() ?? 0
    let regressionPenalty = min(0, worstSeatTop) * 1.5 + min(0, worstSeatRank) + min(0, worstSeatMargin) * 0.02
    let score = topDelta.mean + strictDelta.mean * 0.5 + rankDelta.mean * 0.25 + marginDelta.mean * 0.02 + regressionPenalty

    return SelectionResult(
        path: path,
        samples: samples,
        topDelta: topDelta,
        strictDelta: strictDelta,
        rankDelta: rankDelta,
        marginDelta: marginDelta,
        worstSeatTop: worstSeatTop,
        worstSeatRank: worstSeatRank,
        worstSeatMargin: worstSeatMargin,
        score: score
    )
}

func mean(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    return values.reduce(0, +) / Double(values.count)
}

func printResult(_ result: SelectionResult) {
    print("model \(result.path)")
    print("  score=\(format(result.score)) samples=\(result.samples.count)")
    print("  top_delta=\(format(result.topDelta))")
    print("  strict_delta=\(format(result.strictDelta))")
    print("  rank_delta=\(format(result.rankDelta)) positive_is_better")
    print("  margin_delta=\(format(result.marginDelta))")
    print("  worst_seat_top_delta=\(format(result.worstSeatTop))")
    print("  worst_seat_rank_delta=\(format(result.worstSeatRank))")
    print("  worst_seat_margin_delta=\(format(result.worstSeatMargin))")
}

func main() throws {
    let options = parseOptions()
    guard !options.modelPaths.isEmpty else { throw SelectorError.missingModels }
    let baseline = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: options.baselineModelPath))
    guard baseline.isCompatible else { throw SelectorError.incompatibleModel(options.baselineModelPath) }

    var results: [SelectionResult] = []
    for path in options.modelPaths {
        let model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: path))
        guard model.isCompatible else { throw SelectorError.incompatibleModel(path) }
        let result = try evaluate(path: path, candidate: model, baseline: baseline, options: options)
        results.append(result)
        printResult(result)
    }

    if let best = results.max(by: { $0.score < $1.score }) {
        print("best_model \(best.path)")
        print("best_score \(format(best.score))")
    }
}

do {
    try main()
} catch {
    fputs("KolkhozPolicySelector failed: \(error)\n", stderr)
    exit(1)
}
