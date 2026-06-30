import Foundation
import KolkhozCore

struct Options {
    var startPath: String?
    var outputPath = "../../training/rl/runs/real_trained_policy.json"
    var generations = 12
    var population = 10
    var gamesPerSeat = 12
    var seed: UInt64 = 500_000
    var sigma = 0.02
    var hiddenSize = 48
    var winWeight = 100.0
    var rankWeight = 8.0
    var marginWeight = 1.0
    var historyPath: String?
}

struct RewardWeights {
    let win: Double
    let rank: Double
    let margin: Double
}

struct Evaluation: Comparable {
    let score: Double
    let wins: Int
    let games: Int
    let averageRank: Double
    let averageMargin: Double

    static func < (lhs: Evaluation, rhs: Evaluation) -> Bool {
        lhs.score < rhs.score
    }
}

struct HistoryEvent: Encodable {
    let prefix: String
    let generation: Int
    let candidate: Int?
    let score: Double
    let wins: Int
    let games: Int
    let winRate: Double
    let averageRank: Double
    let averageMargin: Double
}

enum TrainerError: Error {
    case gameDidNotFinish
    case invalidPolicyAction
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--start":
            options.startPath = args.isEmpty ? nil : args.removeFirst()
        case "--output":
            if let value = args.first {
                options.outputPath = value
                args.removeFirst()
            }
        case "--generations":
            if let value = args.first, let parsed = Int(value) {
                options.generations = parsed
                args.removeFirst()
            }
        case "--population":
            if let value = args.first, let parsed = Int(value) {
                options.population = parsed
                args.removeFirst()
            }
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
        case "--sigma":
            if let value = args.first, let parsed = Double(value) {
                options.sigma = parsed
                args.removeFirst()
            }
        case "--hidden-size":
            if let value = args.first, let parsed = Int(value) {
                options.hiddenSize = parsed
                args.removeFirst()
            }
        case "--win-weight":
            if let value = args.first, let parsed = Double(value) {
                options.winWeight = parsed
                args.removeFirst()
            }
        case "--rank-weight":
            if let value = args.first, let parsed = Double(value) {
                options.rankWeight = parsed
                args.removeFirst()
            }
        case "--margin-weight":
            if let value = args.first, let parsed = Double(value) {
                options.marginWeight = parsed
                args.removeFirst()
            }
        case "--history":
            options.historyPath = args.isEmpty ? nil : args.removeFirst()
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
                throw TrainerError.invalidPolicyAction
            }
            try engine.playCard(engine.state.players[0].hand[index])

        case .assignment where engine.state.lastWinner == 0:
            let assignments = decider.chooseAssignments(for: 0)
            for play in engine.state.lastTrick {
                guard let suit = assignments[play.card.id] else {
                    throw TrainerError.invalidPolicyAction
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
        throw TrainerError.gameDidNotFinish
    }
    return result.scores
}

func rank(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    return 1 + scores.values.filter { $0 > target }.count
}

func evaluate(_ model: KolkhozPolicyModel, seed: UInt64, gamesPerSeat: Int, reward: RewardWeights) throws -> Evaluation {
    var wins = 0
    var rankTotal = 0
    var marginTotal = 0
    var games = 0

    for seat in 0..<4 {
        for gameIndex in 0..<gamesPerSeat {
            let gameSeed = seed + UInt64(seat * gamesPerSeat + gameIndex)
            let scores = try playGame(seed: gameSeed, model: model, modelSeat: seat)
            let modelScore = scores[seat] ?? 0
            let bestOpponent = scores
                .filter { $0.key != seat }
                .map(\.value)
                .max() ?? 0
            if modelScore >= bestOpponent {
                wins += 1
            }
            rankTotal += rank(of: seat, scores: scores)
            marginTotal += modelScore - bestOpponent
            games += 1
        }
    }

    let averageRank = Double(rankTotal) / Double(games)
    let averageMargin = Double(marginTotal) / Double(games)
    let winRate = Double(wins) / Double(games)
    let score = winRate * reward.win - averageRank * reward.rank + averageMargin * reward.margin
    return Evaluation(score: score, wins: wins, games: games, averageRank: averageRank, averageMargin: averageMargin)
}

func randomModel(hiddenSize: Int, rng: inout SeededGenerator) -> KolkhozPolicyModel {
    KolkhozPolicyModel(
        version: 1,
        featureVersion: 1,
        inputSize: 34,
        hiddenSize: hiddenSize,
        w1: (0..<(hiddenSize * 34)).map { _ in rng.gaussian() * 0.05 },
        b1: Array(repeating: 0, count: hiddenSize),
        w2: (0..<hiddenSize).map { _ in rng.gaussian() * 0.05 },
        b2: 0
    )
}

func mutate(_ model: KolkhozPolicyModel, sigma: Double, rng: inout SeededGenerator) -> KolkhozPolicyModel {
    KolkhozPolicyModel(
        version: model.version,
        featureVersion: model.featureVersion,
        inputSize: model.inputSize,
        hiddenSize: model.hiddenSize,
        w1: model.w1.map { $0 + rng.gaussian() * sigma },
        b1: model.b1.map { $0 + rng.gaussian() * sigma },
        w2: model.w2.map { $0 + rng.gaussian() * sigma },
        b2: model.b2 + rng.gaussian() * sigma
    )
}

func printEvaluation(prefix: String, generation: Int, candidate: Int?, evaluation: Evaluation) {
    let candidateText = candidate.map { " candidate=\($0)" } ?? ""
    print(
        "\(prefix) generation=\(generation)\(candidateText) score=\(String(format: "%.3f", evaluation.score)) " +
        "wins=\(evaluation.wins)/\(evaluation.games) avg_rank=\(String(format: "%.3f", evaluation.averageRank)) " +
        "avg_margin=\(String(format: "%.3f", evaluation.averageMargin))"
    )
}

func historyEvent(prefix: String, generation: Int, candidate: Int?, evaluation: Evaluation) -> HistoryEvent {
    HistoryEvent(
        prefix: prefix,
        generation: generation,
        candidate: candidate,
        score: evaluation.score,
        wins: evaluation.wins,
        games: evaluation.games,
        winRate: Double(evaluation.wins) / Double(evaluation.games),
        averageRank: evaluation.averageRank,
        averageMargin: evaluation.averageMargin
    )
}

func recordHistory(
    _ history: inout [HistoryEvent],
    prefix: String,
    generation: Int,
    candidate: Int?,
    evaluation: Evaluation
) {
    printEvaluation(prefix: prefix, generation: generation, candidate: candidate, evaluation: evaluation)
    history.append(historyEvent(prefix: prefix, generation: generation, candidate: candidate, evaluation: evaluation))
}

func main() throws {
    let options = parseOptions()
    var rng = SeededGenerator(seed: options.seed)
    let reward = RewardWeights(win: options.winWeight, rank: options.rankWeight, margin: options.marginWeight)
    var best: KolkhozPolicyModel

    if let startPath = options.startPath {
        best = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: startPath))
        guard best.isCompatible else {
            fputs("Starting model is not compatible\n", stderr)
            exit(2)
        }
    } else {
        best = randomModel(hiddenSize: options.hiddenSize, rng: &rng)
    }

    var history: [HistoryEvent] = []
    var bestEvaluation = try evaluate(best, seed: options.seed, gamesPerSeat: options.gamesPerSeat, reward: reward)
    recordHistory(&history, prefix: "baseline", generation: 0, candidate: nil, evaluation: bestEvaluation)

    if options.generations > 0 {
        for generation in 1...options.generations {
        let generationSeed = options.seed + UInt64(generation * 10_000)
        var generationBest = best
        let parentEvaluation = try evaluate(
            best,
            seed: generationSeed,
            gamesPerSeat: options.gamesPerSeat,
            reward: reward
        )
        var generationBestEvaluation = parentEvaluation
        recordHistory(&history, prefix: "parent", generation: generation, candidate: nil, evaluation: generationBestEvaluation)

        for candidateIndex in 0..<options.population {
            let candidate = mutate(best, sigma: options.sigma, rng: &rng)
            let evaluation = try evaluate(
                candidate,
                seed: generationSeed,
                gamesPerSeat: options.gamesPerSeat,
                reward: reward
            )
            recordHistory(&history, prefix: "evaluated", generation: generation, candidate: candidateIndex, evaluation: evaluation)
            if evaluation > generationBestEvaluation {
                generationBest = candidate
                generationBestEvaluation = evaluation
            }
        }

        if generationBestEvaluation > parentEvaluation {
            let validationEvaluation = try evaluate(
                generationBest,
                seed: options.seed,
                gamesPerSeat: options.gamesPerSeat,
                reward: reward
            )
            recordHistory(&history, prefix: "validation", generation: generation, candidate: nil, evaluation: validationEvaluation)
            if validationEvaluation > bestEvaluation {
                best = generationBest
                bestEvaluation = validationEvaluation
                recordHistory(&history, prefix: "accepted", generation: generation, candidate: nil, evaluation: bestEvaluation)
            } else {
                recordHistory(&history, prefix: "rejected", generation: generation, candidate: nil, evaluation: bestEvaluation)
            }
        } else {
            recordHistory(&history, prefix: "kept", generation: generation, candidate: nil, evaluation: bestEvaluation)
        }
        }
    }

    let outputURL = URL(fileURLWithPath: options.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try best.save(to: outputURL)
    recordHistory(&history, prefix: "final", generation: options.generations, candidate: nil, evaluation: bestEvaluation)
    if let historyPath = options.historyPath {
        let historyURL = URL(fileURLWithPath: historyPath)
        try FileManager.default.createDirectory(
            at: historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(history)
        try data.write(to: historyURL)
        print("history \(historyPath)")
    }
    print("exported \(options.outputPath)")
}

struct SeededGenerator {
    private var state: UInt64
    private var spareGaussian: Double?

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func uniform() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func gaussian() -> Double {
        if let spareGaussian {
            self.spareGaussian = nil
            return spareGaussian
        }
        let u1 = max(uniform(), .leastNonzeroMagnitude)
        let u2 = uniform()
        let radius = sqrt(-2 * log(u1))
        let theta = 2 * Double.pi * u2
        spareGaussian = radius * sin(theta)
        return radius * cos(theta)
    }
}

do {
    try main()
} catch {
    fputs("KolkhozRealTrainer failed: \(error)\n", stderr)
    exit(1)
}
