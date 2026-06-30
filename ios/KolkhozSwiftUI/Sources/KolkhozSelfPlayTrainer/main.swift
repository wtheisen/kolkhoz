import Foundation
import KolkhozCore

struct Options {
    var startPath = "Sources/KolkhozCore/Resources/kolkhoz_policy.json"
    var outputPath = "../../training/rl/runs/policy_self_play.json"
    var historyPath: String?
    var generations = 10
    var population = 12
    var gamesPerSeat = 8
    var opponentsPerCandidate = 3
    var poolSize = 5
    var seed: UInt64 = 13_000_000
    var sigma = 0.0025
    var winWeight = 100.0
    var rankWeight = 10.0
    var marginWeight = 0.8
}

struct RewardWeights {
    let win: Double
    let rank: Double
    let margin: Double
}

struct Evaluation: Comparable, Codable {
    let score: Double
    let wins: Int
    let games: Int
    let averageRank: Double
    let averageMargin: Double

    static func < (lhs: Evaluation, rhs: Evaluation) -> Bool {
        lhs.score < rhs.score
    }
}

struct PoolEntry {
    let label: String
    let model: KolkhozPolicyModel
    let evaluation: Evaluation
}

struct HistoryEvent: Encodable {
    let prefix: String
    let generation: Int
    let candidate: Int?
    let poolCount: Int
    let score: Double
    let wins: Int
    let games: Int
    let winRate: Double
    let averageRank: Double
    let averageMargin: Double
}

enum SelfPlayError: Error {
    case incompatibleModel(String)
    case gameDidNotFinish(phase: GamePhase, year: Int, currentPlayer: Int, guardCount: Int)
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--start":
            if let value = args.first {
                options.startPath = value
                args.removeFirst()
            }
        case "--output":
            if let value = args.first {
                options.outputPath = value
                args.removeFirst()
            }
        case "--history":
            if let value = args.first {
                options.historyPath = value
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
        case "--opponents-per-candidate":
            if let value = args.first, let parsed = Int(value) {
                options.opponentsPerCandidate = parsed
                args.removeFirst()
            }
        case "--pool-size":
            if let value = args.first, let parsed = Int(value) {
                options.poolSize = parsed
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
        default:
            break
        }
    }
    return options
}

func playSelfPlayGame(
    seed: UInt64,
    candidate: KolkhozPolicyModel,
    candidateSeat: Int,
    opponents: [KolkhozPolicyModel]
) throws -> [Int: Int] {
    var allSeatModels: [Int: KolkhozPolicyModel] = [:]
    for seat in 0..<4 {
        if seat == candidateSeat {
            allSeatModels[seat] = candidate
        } else {
            let opponentIndex = (seed.hashValue + seat + candidateSeat) %% opponents.count
            allSeatModels[seat] = opponents[opponentIndex]
        }
    }
    let automatedSeatModels = allSeatModels.filter { $0.key != 0 }

    let engine = KolkhozEngine(
        seed: seed,
        variants: .kolkhoz,
        controllers: [.human, .neuralAI, .neuralAI, .neuralAI],
        aiModel: nil,
        aiModels: automatedSeatModels
    )

    var guardCount = 0
    while engine.state.phase != .gameOver && guardCount < 1_000 {
        guardCount += 1
        let seatZeroDecider = KolkhozAIDecider(state: engine.state, model: allSeatModels[0])

        switch engine.state.phase {
        case .planning where engine.state.currentPlayer == 0:
            try engine.setTrump(seatZeroDecider.chooseTrump(for: 0))

        case .swap where engine.state.currentPlayer == 0:
            if let choice = seatZeroDecider.chooseSwap(for: 0) {
                try engine.swap(handCard: choice.handCard, plotCard: choice.plotCard, revealed: choice.zone == .revealed)
            }
            try engine.confirmSwap()

        case .trick where engine.state.currentPlayer == 0:
            let index = seatZeroDecider.chooseCardIndex(for: 0)
            guard engine.state.players[0].hand.indices.contains(index) else {
                throw SelfPlayError.gameDidNotFinish(
                    phase: engine.state.phase,
                    year: engine.state.year,
                    currentPlayer: engine.state.currentPlayer,
                    guardCount: guardCount
                )
            }
            try engine.playCard(engine.state.players[0].hand[index])

        case .assignment where engine.state.lastWinner == 0:
            let assignments = seatZeroDecider.chooseAssignments(for: 0)
            for play in engine.state.lastTrick {
                guard let suit = assignments[play.card.id] else {
                    throw SelfPlayError.gameDidNotFinish(
                        phase: engine.state.phase,
                        year: engine.state.year,
                        currentPlayer: engine.state.currentPlayer,
                        guardCount: guardCount
                    )
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
        throw SelfPlayError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }
    return result.scores
}

func rank(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    return 1 + scores.values.filter { $0 > target }.count
}

func evaluate(
    _ candidate: KolkhozPolicyModel,
    pool: [PoolEntry],
    seed: UInt64,
    gamesPerSeat: Int,
    opponentsPerCandidate: Int,
    reward: RewardWeights
) throws -> Evaluation {
    let opponentModels = pool.map(\.model)
    var wins = 0
    var rankTotal = 0
    var marginTotal = 0
    var games = 0
    let opponentRuns = max(1, min(opponentsPerCandidate, opponentModels.count))

    for opponentRun in 0..<opponentRuns {
        let opponents = rotated(opponentModels, by: opponentRun)
        for seat in 0..<4 {
            for gameIndex in 0..<gamesPerSeat {
                let gameSeed = seed
                    + UInt64(opponentRun * 1_000_000)
                    + UInt64(seat * gamesPerSeat + gameIndex)
                let scores = try playSelfPlayGame(
                    seed: gameSeed,
                    candidate: candidate,
                    candidateSeat: seat,
                    opponents: opponents
                )
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
    }

    let averageRank = Double(rankTotal) / Double(games)
    let averageMargin = Double(marginTotal) / Double(games)
    let winRate = Double(wins) / Double(games)
    let score = winRate * reward.win - averageRank * reward.rank + averageMargin * reward.margin
    return Evaluation(score: score, wins: wins, games: games, averageRank: averageRank, averageMargin: averageMargin)
}

func randomModelLike(_ model: KolkhozPolicyModel, rng: inout SeededGenerator) -> KolkhozPolicyModel {
    KolkhozPolicyModel(
        version: model.version,
        featureVersion: model.featureVersion,
        inputSize: model.inputSize,
        hiddenSize: model.hiddenSize,
        w1: (0..<model.w1.count).map { _ in rng.gaussian() * 0.05 },
        b1: Array(repeating: 0, count: model.b1.count),
        w2: (0..<model.w2.count).map { _ in rng.gaussian() * 0.05 },
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

func rotated<T>(_ values: [T], by offset: Int) -> [T] {
    guard !values.isEmpty else { return values }
    let shift = offset %% values.count
    return Array(values[shift...] + values[..<shift])
}

func printEvaluation(prefix: String, generation: Int, candidate: Int?, evaluation: Evaluation, poolCount: Int) {
    let candidateText = candidate.map { " candidate=\($0)" } ?? ""
    print(
        "\(prefix) generation=\(generation)\(candidateText) pool=\(poolCount) " +
        "score=\(String(format: "%.3f", evaluation.score)) wins=\(evaluation.wins)/\(evaluation.games) " +
        "avg_rank=\(String(format: "%.3f", evaluation.averageRank)) " +
        "avg_margin=\(String(format: "%.3f", evaluation.averageMargin))"
    )
}

func recordHistory(
    _ history: inout [HistoryEvent],
    prefix: String,
    generation: Int,
    candidate: Int?,
    evaluation: Evaluation,
    poolCount: Int
) {
    printEvaluation(prefix: prefix, generation: generation, candidate: candidate, evaluation: evaluation, poolCount: poolCount)
    history.append(HistoryEvent(
        prefix: prefix,
        generation: generation,
        candidate: candidate,
        poolCount: poolCount,
        score: evaluation.score,
        wins: evaluation.wins,
        games: evaluation.games,
        winRate: Double(evaluation.wins) / Double(evaluation.games),
        averageRank: evaluation.averageRank,
        averageMargin: evaluation.averageMargin
    ))
}

func trimPool(_ pool: inout [PoolEntry], maxSize: Int) {
    guard pool.count > maxSize else { return }
    pool.sort { lhs, rhs in lhs.evaluation > rhs.evaluation }
    pool = Array(pool.prefix(maxSize))
}

func main() throws {
    let options = parseOptions()
    let reward = RewardWeights(win: options.winWeight, rank: options.rankWeight, margin: options.marginWeight)
    var rng = SeededGenerator(seed: options.seed)
    var history: [HistoryEvent] = []

    var best = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: options.startPath))
    guard best.isCompatible else {
        throw SelfPlayError.incompatibleModel(options.startPath)
    }

    let baselineEvaluation = try evaluate(
        best,
        pool: [PoolEntry(label: "baseline", model: best, evaluation: Evaluation(score: 0, wins: 0, games: 1, averageRank: 4, averageMargin: 0))],
        seed: options.seed,
        gamesPerSeat: options.gamesPerSeat,
        opponentsPerCandidate: 1,
        reward: reward
    )
    var bestEvaluation = baselineEvaluation
    var pool = [PoolEntry(label: "baseline", model: best, evaluation: baselineEvaluation)]
    recordHistory(&history, prefix: "baseline", generation: 0, candidate: nil, evaluation: baselineEvaluation, poolCount: pool.count)

    if options.poolSize > 1 {
        let random = randomModelLike(best, rng: &rng)
        let randomEvaluation = try evaluate(
            random,
            pool: pool,
            seed: options.seed + 50_000,
            gamesPerSeat: max(1, options.gamesPerSeat / 2),
            opponentsPerCandidate: 1,
            reward: reward
        )
        pool.append(PoolEntry(label: "random_control", model: random, evaluation: randomEvaluation))
        recordHistory(&history, prefix: "random_control", generation: 0, candidate: nil, evaluation: randomEvaluation, poolCount: pool.count)
    }

    for generation in 1...options.generations {
        let generationSeed = options.seed + UInt64(generation * 100_000)
        var generationBest = best
        var generationBestEvaluation = try evaluate(
            best,
            pool: pool,
            seed: generationSeed,
            gamesPerSeat: options.gamesPerSeat,
            opponentsPerCandidate: options.opponentsPerCandidate,
            reward: reward
        )
        recordHistory(&history, prefix: "parent", generation: generation, candidate: nil, evaluation: generationBestEvaluation, poolCount: pool.count)

        for candidateIndex in 0..<options.population {
            let candidate = mutate(best, sigma: options.sigma, rng: &rng)
            let evaluation = try evaluate(
                candidate,
                pool: pool,
                seed: generationSeed + UInt64(candidateIndex * 10_000),
                gamesPerSeat: options.gamesPerSeat,
                opponentsPerCandidate: options.opponentsPerCandidate,
                reward: reward
            )
            recordHistory(&history, prefix: "evaluated", generation: generation, candidate: candidateIndex, evaluation: evaluation, poolCount: pool.count)
            if evaluation > generationBestEvaluation {
                generationBest = candidate
                generationBestEvaluation = evaluation
            }
        }

        let validationEvaluation = try evaluate(
            generationBest,
            pool: pool,
            seed: options.seed + UInt64(generation * 1_000_000),
            gamesPerSeat: max(options.gamesPerSeat * 2, options.gamesPerSeat),
            opponentsPerCandidate: options.opponentsPerCandidate,
            reward: reward
        )
        recordHistory(&history, prefix: "validation", generation: generation, candidate: nil, evaluation: validationEvaluation, poolCount: pool.count)

        if validationEvaluation > bestEvaluation {
            best = generationBest
            bestEvaluation = validationEvaluation
            pool.append(PoolEntry(label: "accepted_\(generation)", model: generationBest, evaluation: validationEvaluation))
            trimPool(&pool, maxSize: max(1, options.poolSize))
            recordHistory(&history, prefix: "accepted", generation: generation, candidate: nil, evaluation: bestEvaluation, poolCount: pool.count)
        } else {
            recordHistory(&history, prefix: "rejected", generation: generation, candidate: nil, evaluation: bestEvaluation, poolCount: pool.count)
        }
    }

    let outputURL = URL(fileURLWithPath: options.outputPath)
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try best.save(to: outputURL)
    recordHistory(&history, prefix: "final", generation: options.generations, candidate: nil, evaluation: bestEvaluation, poolCount: pool.count)

    if let historyPath = options.historyPath {
        let historyURL = URL(fileURLWithPath: historyPath)
        try FileManager.default.createDirectory(
            at: historyURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(history).write(to: historyURL)
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

infix operator %%: MultiplicationPrecedence

func %% (lhs: Int, rhs: Int) -> Int {
    let remainder = lhs % rhs
    return remainder >= 0 ? remainder : remainder + rhs
}

do {
    try main()
} catch {
    fputs("KolkhozSelfPlayTrainer failed: \(error)\n", stderr)
    exit(1)
}
