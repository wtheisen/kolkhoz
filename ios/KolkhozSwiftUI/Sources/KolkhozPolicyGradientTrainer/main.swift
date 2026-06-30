import Foundation
import KolkhozCore

struct Options {
    var startPath = "Sources/KolkhozCore/Resources/kolkhoz_policy.json"
    var opponentPath: String?
    var opponentMode = "model"
    var outputPath = "../../training/rl/runs/policy_pg_self_play.json"
    var historyPath: String?
    var checkpointEvery = 0
    var episodes = 2_000
    var batchSize = 32
    var seed: UInt64 = 14_000_000
    var expandHidden: Int?
    var expandScale = 0.01
    var roundCurriculum = false
    var roundPlotCards = 6
    var roundFamineRate = 0.2
    var optimizer = "sgd"
    var learningRate = 0.0004
    var adamBeta1 = 0.9
    var adamBeta2 = 0.999
    var adamEpsilon = 0.00000001
    var temperature = 1.15
    var maxGradientNorm = 5.0
    var l2 = 0.00001
    var winWeight = 1.0
    var strictWeight = 0.0
    var rankWeight = 0.25
    var marginWeight = 0.05
    var scoreDeltaWeight = 0.0
    var marginDeltaWeight = 0.0
    var pairedBaseline = true
    var seatBalancedUpdate = false
    var advantageClip = 0.0
    var trainingSeats: [Int]?
}

struct RewardWeights {
    let win: Double
    let strict: Double
    let rank: Double
    let margin: Double
}

struct EpisodeSummary: Encodable {
    let episode: Int
    let actions: Int
    let topRate: Double
    let averageRank: Double
    let averageMargin: Double
    let averageReward: Double
    let averageAdvantage: Double
    let averageShapedReward: Double
}

struct BatchSummary: Encodable {
    let episode: Int
    let actions: Int
    let gradientNorm: Double
    let scale: Double
    let topRate: Double
    let averageRank: Double
    let averageMargin: Double
    let averageReward: Double
    let averageAdvantage: Double
    let averageShapedReward: Double
}

enum TrainerError: Error {
    case incompatibleModel(String)
    case noLegalActions(phase: GamePhase, playerID: Int)
    case invalidAction
    case gameDidNotFinish(phase: GamePhase, year: Int, currentPlayer: Int, guardCount: Int)
}

enum PolicyAction {
    case trump(Suit)
    case noSwap
    case swap(handCard: Card, plotCard: Card, revealed: Bool)
    case play(Card)
    case assign(Suit)
}

struct ActionCandidate {
    let action: PolicyAction
    let features: [Double]?
    let score: Double
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--start":
            options.startPath = args.isEmpty ? options.startPath : args.removeFirst()
        case "--opponent-model":
            options.opponentPath = args.isEmpty ? nil : args.removeFirst()
        case "--opponent-mode":
            if let value = args.first {
                options.opponentMode = value
                args.removeFirst()
            }
        case "--output":
            options.outputPath = args.isEmpty ? options.outputPath : args.removeFirst()
        case "--history":
            options.historyPath = args.isEmpty ? nil : args.removeFirst()
        case "--checkpoint-every":
            if let value = args.first, let parsed = Int(value) {
                options.checkpointEvery = parsed
                args.removeFirst()
            }
        case "--episodes":
            if let value = args.first, let parsed = Int(value) {
                options.episodes = parsed
                args.removeFirst()
            }
        case "--batch-size":
            if let value = args.first, let parsed = Int(value) {
                options.batchSize = parsed
                args.removeFirst()
            }
        case "--seed":
            if let value = args.first, let parsed = UInt64(value) {
                options.seed = parsed
                args.removeFirst()
            }
        case "--expand-hidden":
            if let value = args.first, let parsed = Int(value) {
                options.expandHidden = parsed
                args.removeFirst()
            }
        case "--expand-scale":
            if let value = args.first, let parsed = Double(value) {
                options.expandScale = parsed
                args.removeFirst()
            }
        case "--round-curriculum":
            options.roundCurriculum = true
        case "--round-plot-cards":
            if let value = args.first, let parsed = Int(value) {
                options.roundPlotCards = parsed
                args.removeFirst()
            }
        case "--round-famine-rate":
            if let value = args.first, let parsed = Double(value) {
                options.roundFamineRate = parsed
                args.removeFirst()
            }
        case "--learning-rate":
            if let value = args.first, let parsed = Double(value) {
                options.learningRate = parsed
                args.removeFirst()
            }
        case "--optimizer":
            if let value = args.first {
                options.optimizer = value
                args.removeFirst()
            }
        case "--adam-beta1":
            if let value = args.first, let parsed = Double(value) {
                options.adamBeta1 = parsed
                args.removeFirst()
            }
        case "--adam-beta2":
            if let value = args.first, let parsed = Double(value) {
                options.adamBeta2 = parsed
                args.removeFirst()
            }
        case "--adam-epsilon":
            if let value = args.first, let parsed = Double(value) {
                options.adamEpsilon = parsed
                args.removeFirst()
            }
        case "--temperature":
            if let value = args.first, let parsed = Double(value) {
                options.temperature = parsed
                args.removeFirst()
            }
        case "--max-gradient-norm":
            if let value = args.first, let parsed = Double(value) {
                options.maxGradientNorm = parsed
                args.removeFirst()
            }
        case "--l2":
            if let value = args.first, let parsed = Double(value) {
                options.l2 = parsed
                args.removeFirst()
            }
        case "--win-weight":
            if let value = args.first, let parsed = Double(value) {
                options.winWeight = parsed
                args.removeFirst()
            }
        case "--strict-weight":
            if let value = args.first, let parsed = Double(value) {
                options.strictWeight = parsed
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
        case "--score-delta-weight":
            if let value = args.first, let parsed = Double(value) {
                options.scoreDeltaWeight = parsed
                args.removeFirst()
            }
        case "--margin-delta-weight":
            if let value = args.first, let parsed = Double(value) {
                options.marginDeltaWeight = parsed
                args.removeFirst()
            }
        case "--paired-baseline":
            options.pairedBaseline = true
        case "--no-paired-baseline":
            options.pairedBaseline = false
        case "--seat-balanced-update":
            options.seatBalancedUpdate = true
        case "--advantage-clip":
            if let value = args.first, let parsed = Double(value) {
                options.advantageClip = parsed
                args.removeFirst()
            }
        case "--training-seats":
            if let value = args.first {
                let seats = value
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .filter { (0..<4).contains($0) }
                options.trainingSeats = seats.isEmpty ? nil : seats
                args.removeFirst()
            }
        default:
            break
        }
    }
    return options
}

func playEpisode(
    model: KolkhozPolicyModel,
    opponentModel: KolkhozPolicyModel?,
    seed: UInt64,
    trainingSeat: Int?,
    rng: inout SeededGenerator,
    temperature: Double,
    pairedBaseline: Bool,
    advantageClip: Double,
    reward: RewardWeights,
    opponentMode: String,
    scoreDeltaWeight: Double,
    marginDeltaWeight: Double
) throws -> (gradient: PolicyGradient, summary: EpisodeSummary) {
    let engine = KolkhozEngine(
        seed: seed,
        variants: .kolkhoz,
        controllers: [.human, .human, .human, .human],
        aiModel: nil
    )

    var playerGradients = Array(repeating: PolicyGradient.zerosLike(model), count: 4)
    var playerShapedGradients = Array(repeating: PolicyGradient.zerosLike(model), count: 4)
    var playerShapedRewards = Array(repeating: 0.0, count: 4)
    var playerActionCounts = Array(repeating: 0, count: 4)
    var guardCount = 0

    while engine.state.phase != .gameOver && guardCount < 2_000 {
        guardCount += 1
        switch engine.state.phase {
        case .planning:
            let playerID = engine.state.currentPlayer
            try chooseAndApply(
                playerID: playerID,
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                state: engine.state,
                engine: engine,
                rng: &rng,
                temperature: temperature,
                opponentMode: opponentMode,
                scoreDeltaWeight: scoreDeltaWeight,
                marginDeltaWeight: marginDeltaWeight,
                playerGradients: &playerGradients,
                playerShapedGradients: &playerShapedGradients,
                playerShapedRewards: &playerShapedRewards,
                playerActionCounts: &playerActionCounts
            )

        case .swap:
            let playerID = engine.state.currentPlayer
            try chooseAndApply(
                playerID: playerID,
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                state: engine.state,
                engine: engine,
                rng: &rng,
                temperature: temperature,
                opponentMode: opponentMode,
                scoreDeltaWeight: scoreDeltaWeight,
                marginDeltaWeight: marginDeltaWeight,
                playerGradients: &playerGradients,
                playerShapedGradients: &playerShapedGradients,
                playerShapedRewards: &playerShapedRewards,
                playerActionCounts: &playerActionCounts
            )

        case .trick:
            let playerID = engine.state.currentPlayer
            try chooseAndApply(
                playerID: playerID,
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                state: engine.state,
                engine: engine,
                rng: &rng,
                temperature: temperature,
                opponentMode: opponentMode,
                scoreDeltaWeight: scoreDeltaWeight,
                marginDeltaWeight: marginDeltaWeight,
                playerGradients: &playerGradients,
                playerShapedGradients: &playerShapedGradients,
                playerShapedRewards: &playerShapedRewards,
                playerActionCounts: &playerActionCounts
            )

        case .assignment:
            guard let playerID = engine.state.lastWinner else { throw TrainerError.invalidAction }
            try chooseAndApply(
                playerID: playerID,
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                state: engine.state,
                engine: engine,
                rng: &rng,
                temperature: temperature,
                opponentMode: opponentMode,
                scoreDeltaWeight: scoreDeltaWeight,
                marginDeltaWeight: marginDeltaWeight,
                playerGradients: &playerGradients,
                playerShapedGradients: &playerShapedGradients,
                playerShapedRewards: &playerShapedRewards,
                playerActionCounts: &playerActionCounts
            )

        case .requisition:
            engine.continueAfterRequisition()

        case .gameOver:
            break
        }
    }

    guard engine.state.phase == .gameOver, let result = engine.state.gameResult else {
        throw TrainerError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }

    let rewards = centeredRewards(scores: result.scores, reward: reward)
    var gradient = PolicyGradient.zerosLike(model)
    let trainedSeats = trainingSeat.map { [$0] } ?? Array(0..<4)
    let baselineScores: [Int: Int]?
    if let opponentModel, let trainingSeat, pairedBaseline {
        baselineScores = try playBaselineGame(
            seed: seed,
            model: opponentModel,
            modelSeat: trainingSeat,
            opponentMode: opponentMode
        )
        _ = trainingSeat
    } else {
        baselineScores = nil
    }
    var advantageTotal = 0.0
    for playerID in trainedSeats {
        let actionCount = max(1, playerActionCounts[playerID])
        let advantage: Double
        if let baselineScores {
            advantage = rawReward(playerID: playerID, scores: result.scores, reward: reward)
                - rawReward(playerID: playerID, scores: baselineScores, reward: reward)
        } else if trainingSeat == nil {
            advantage = rewards[playerID, default: 0]
        } else {
            advantage = rawReward(playerID: playerID, scores: result.scores, reward: reward)
        }
        let clippedAdvantage = clip(advantage, limit: advantageClip)
        advantageTotal += clippedAdvantage
        let scale = clippedAdvantage / Double(actionCount)
        gradient.add(playerGradients[playerID], scale: scale)
        gradient.add(playerShapedGradients[playerID])
    }

    let topCount = (0..<4).filter { playerID in
        let score = result.scores[playerID] ?? 0
        let bestOpponent = result.scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
        return score >= bestOpponent
    }.count
    let averageRank = Double((0..<4).map { rank(of: $0, scores: result.scores) }.reduce(0, +)) / 4
    let averageMargin = Double((0..<4).map { margin(of: $0, scores: result.scores) }.reduce(0, +)) / 4
    let averageReward = rewards.values.reduce(0, +) / Double(rewards.count)
    let averageAdvantage = advantageTotal / Double(max(1, trainedSeats.count))
    let shapedRewardTotal = trainedSeats.map { playerShapedRewards[$0] }.reduce(0, +)
    let shapedActionCount = trainedSeats.map { max(1, playerActionCounts[$0]) }.reduce(0, +)
    let averageShapedReward = shapedRewardTotal / Double(max(1, shapedActionCount))
    let summary = EpisodeSummary(
        episode: Int(seed),
        actions: playerActionCounts.reduce(0, +),
        topRate: Double(topCount) / 4,
        averageRank: averageRank,
        averageMargin: averageMargin,
        averageReward: averageReward,
        averageAdvantage: averageAdvantage,
        averageShapedReward: averageShapedReward
    )
    return (gradient, summary)
}

func playRoundEpisode(
    initialState: KolkhozState,
    model: KolkhozPolicyModel,
    opponentModel: KolkhozPolicyModel?,
    trainingSeat: Int?,
    rng: inout SeededGenerator,
    temperature: Double,
    pairedBaseline: Bool,
    advantageClip: Double,
    reward: RewardWeights,
    opponentMode: String,
    scoreDeltaWeight: Double,
    marginDeltaWeight: Double
) throws -> (gradient: PolicyGradient, summary: EpisodeSummary) {
    let engine = KolkhozEngine(
        testing: initialState,
        controllers: [.human, .human, .human, .human],
        aiModel: nil
    )
    let startingYear = engine.state.year

    var playerGradients = Array(repeating: PolicyGradient.zerosLike(model), count: 4)
    var playerShapedGradients = Array(repeating: PolicyGradient.zerosLike(model), count: 4)
    var playerShapedRewards = Array(repeating: 0.0, count: 4)
    var playerActionCounts = Array(repeating: 0, count: 4)
    var guardCount = 0

    while engine.state.phase != .gameOver && engine.state.year == startingYear && guardCount < 600 {
        guardCount += 1
        switch engine.state.phase {
        case .planning, .swap, .trick:
            let playerID = engine.state.currentPlayer
            try chooseAndApply(
                playerID: playerID,
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                state: engine.state,
                engine: engine,
                rng: &rng,
                temperature: temperature,
                opponentMode: opponentMode,
                scoreDeltaWeight: scoreDeltaWeight,
                marginDeltaWeight: marginDeltaWeight,
                playerGradients: &playerGradients,
                playerShapedGradients: &playerShapedGradients,
                playerShapedRewards: &playerShapedRewards,
                playerActionCounts: &playerActionCounts
            )
        case .assignment:
            guard let playerID = engine.state.lastWinner else { throw TrainerError.invalidAction }
            try chooseAndApply(
                playerID: playerID,
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                state: engine.state,
                engine: engine,
                rng: &rng,
                temperature: temperature,
                opponentMode: opponentMode,
                scoreDeltaWeight: scoreDeltaWeight,
                marginDeltaWeight: marginDeltaWeight,
                playerGradients: &playerGradients,
                playerShapedGradients: &playerShapedGradients,
                playerShapedRewards: &playerShapedRewards,
                playerActionCounts: &playerActionCounts
            )
        case .requisition:
            engine.continueAfterRequisition()
        case .gameOver:
            break
        }
    }

    guard engine.state.phase == .gameOver || engine.state.year != startingYear else {
        throw TrainerError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }

    let scores = finalScores(engine)
    let rewards = centeredRewards(scores: scores, reward: reward)
    var gradient = PolicyGradient.zerosLike(model)
    let trainedSeats = trainingSeat.map { [$0] } ?? Array(0..<4)
    let baselineScores: [Int: Int]?
    if let opponentModel, let trainingSeat, pairedBaseline {
        baselineScores = try playRoundBaseline(
            state: initialState,
            model: opponentModel,
            modelSeat: trainingSeat,
            opponentMode: opponentMode
        )
    } else {
        baselineScores = nil
    }

    var advantageTotal = 0.0
    for playerID in trainedSeats {
        let actionCount = max(1, playerActionCounts[playerID])
        let advantage: Double
        if let baselineScores {
            advantage = rawReward(playerID: playerID, scores: scores, reward: reward)
                - rawReward(playerID: playerID, scores: baselineScores, reward: reward)
        } else if trainingSeat == nil {
            advantage = rewards[playerID, default: 0]
        } else {
            advantage = rawReward(playerID: playerID, scores: scores, reward: reward)
        }
        let clippedAdvantage = clip(advantage, limit: advantageClip)
        advantageTotal += clippedAdvantage
        gradient.add(playerGradients[playerID], scale: clippedAdvantage / Double(actionCount))
        gradient.add(playerShapedGradients[playerID])
    }

    let topCount = (0..<4).filter { playerID in
        let score = scores[playerID] ?? 0
        let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
        return score >= bestOpponent
    }.count
    let averageRank = Double((0..<4).map { rank(of: $0, scores: scores) }.reduce(0, +)) / 4
    let averageMargin = Double((0..<4).map { margin(of: $0, scores: scores) }.reduce(0, +)) / 4
    let averageReward = rewards.values.reduce(0, +) / Double(rewards.count)
    let averageAdvantage = advantageTotal / Double(max(1, trainedSeats.count))
    let shapedRewardTotal = trainedSeats.map { playerShapedRewards[$0] }.reduce(0, +)
    let shapedActionCount = trainedSeats.map { max(1, playerActionCounts[$0]) }.reduce(0, +)
    let averageShapedReward = shapedRewardTotal / Double(max(1, shapedActionCount))
    return (
        gradient,
        EpisodeSummary(
            episode: startingYear,
            actions: playerActionCounts.reduce(0, +),
            topRate: Double(topCount) / 4,
            averageRank: averageRank,
            averageMargin: averageMargin,
            averageReward: averageReward,
            averageAdvantage: averageAdvantage,
            averageShapedReward: averageShapedReward
        )
    )
}

func clip(_ value: Double, limit: Double) -> Double {
    guard limit > 0 else { return value }
    return min(max(value, -limit), limit)
}

func playBaselineGame(seed: UInt64, model: KolkhozPolicyModel, modelSeat: Int, opponentMode: String) throws -> [Int: Int] {
    let engine = KolkhozEngine(
        seed: seed,
        variants: .kolkhoz,
        controllers: [.human, .human, .human, .human],
        aiModel: nil
    )

    var guardCount = 0
    while engine.state.phase != .gameOver && guardCount < 2_000 {
        guardCount += 1
        switch engine.state.phase {
        case .planning, .swap, .trick:
            let playerID = engine.state.currentPlayer
            if playerID == modelSeat || opponentMode != "heuristic" {
                let action = try greedyAction(model: model, state: engine.state, playerID: playerID)
                try apply(action, to: engine, playerID: playerID)
            } else {
                try applyHeuristicDecision(to: engine, playerID: playerID)
            }
        case .assignment:
            guard let playerID = engine.state.lastWinner else { throw TrainerError.invalidAction }
            if playerID == modelSeat || opponentMode != "heuristic" {
                let action = try greedyAction(model: model, state: engine.state, playerID: playerID)
                try apply(action, to: engine, playerID: playerID)
            } else {
                try applyHeuristicDecision(to: engine, playerID: playerID)
            }
        case .requisition:
            engine.continueAfterRequisition()
        case .gameOver:
            break
        }
    }

    guard engine.state.phase == .gameOver, let result = engine.state.gameResult else {
        throw TrainerError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }
    return result.scores
}

func playRoundBaseline(
    state: KolkhozState,
    model: KolkhozPolicyModel,
    modelSeat: Int,
    opponentMode: String
) throws -> [Int: Int] {
    let engine = KolkhozEngine(
        testing: state,
        controllers: [.human, .human, .human, .human],
        aiModel: nil
    )
    let startingYear = engine.state.year
    var guardCount = 0
    while engine.state.phase != .gameOver && engine.state.year == startingYear && guardCount < 600 {
        guardCount += 1
        switch engine.state.phase {
        case .planning, .swap, .trick:
            let playerID = engine.state.currentPlayer
            if playerID == modelSeat || opponentMode != "heuristic" {
                let action = try greedyAction(model: model, state: engine.state, playerID: playerID)
                try apply(action, to: engine, playerID: playerID)
            } else {
                try applyHeuristicDecision(to: engine, playerID: playerID)
            }
        case .assignment:
            guard let playerID = engine.state.lastWinner else { throw TrainerError.invalidAction }
            if playerID == modelSeat || opponentMode != "heuristic" {
                let action = try greedyAction(model: model, state: engine.state, playerID: playerID)
                try apply(action, to: engine, playerID: playerID)
            } else {
                try applyHeuristicDecision(to: engine, playerID: playerID)
            }
        case .requisition:
            engine.continueAfterRequisition()
        case .gameOver:
            break
        }
    }

    guard engine.state.phase == .gameOver || engine.state.year != startingYear else {
        throw TrainerError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }
    return finalScores(engine)
}

func finalScores(_ engine: KolkhozEngine) -> [Int: Int] {
    Dictionary(uniqueKeysWithValues: (0..<4).map { ($0, engine.finalScore(for: $0)) })
}

func randomRoundState(seed: UInt64, plotCardsPerPlayer: Int, famineRate: Double) -> KolkhozState {
    var rng = SeededGenerator(seed: seed)
    var players = (0..<4).map { PlayerState(id: $0, name: "Player \($0 + 1)", isHuman: true) }
    let lead = Int(rng.next() % 4)
    let selector = Int(rng.next() % 4)
    var state = KolkhozState(players: players, lead: lead, trumpSelector: selector, variants: .kolkhoz)
    let isFamine = rng.uniform() < min(max(famineRate, 0), 1)
    state.year = isFamine ? 5 : 1 + Int(rng.next() % 4)
    state.isFamine = isFamine
    state.phase = .planning
    state.currentPlayer = selector
    state.trumpSelector = selector
    state.trickCount = 0
    state.trump = nil
    state.claimedJobs = []
    state.currentTrick = []
    state.lastTrick = []
    state.lastWinner = nil
    state.pendingAssignments = [:]
    state.requisitionEvents = []
    state.swapConfirmed = []
    state.swapCount = []
    state.lastSwap = nil
    state.workHours = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, Int(rng.next() % 28)) })
    state.jobBuckets = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, []) })
    state.jobPiles = Dictionary(uniqueKeysWithValues: Suit.allCases.map { suit in
        (suit, (1...5).map { Card(suit: suit, value: $0) }.shuffled(using: &rng))
    })
    state.revealedJobs = Dictionary(uniqueKeysWithValues: Suit.allCases.map { suit in
        (suit, Card(suit: suit, value: 1 + Int(rng.next() % 5)))
    })

    var deck = workerDeck().shuffled(using: &rng)
    let cardsPerPlayer = isFamine ? 4 : 5
    for playerID in players.indices {
        players[playerID].hand = drawCards(count: cardsPerPlayer, from: &deck)
        let remainingPlayers = max(1, players.count - playerID)
        let plotCount = min(max(0, plotCardsPerPlayer), deck.count / remainingPlayers)
        let revealedCount = min(plotCount, Int(rng.next() % UInt64(max(1, plotCount + 1))))
        players[playerID].plot.revealed = drawCards(count: revealedCount, from: &deck)
        players[playerID].plot.hidden = drawCards(count: max(0, plotCount - revealedCount), from: &deck)
        players[playerID].hasWonTrickThisYear = rng.uniform() < 0.35
        players[playerID].medals = Int(rng.next() % 3)
    }
    state.players = players
    return state
}

func workerDeck() -> [Card] {
    Suit.allCases.flatMap { suit in (6...13).map { Card(suit: suit, value: $0) } }
}

func drawCards(count: Int, from deck: inout [Card]) -> [Card] {
    (0..<count).compactMap { _ in deck.popLast() }
}

func applyHeuristicDecision(to engine: KolkhozEngine, playerID: Int) throws {
    let decider = KolkhozAIDecider(state: engine.state, model: nil)
    switch engine.state.phase {
    case .planning:
        try engine.setTrump(decider.chooseTrump(for: playerID), playerID: playerID)
    case .swap:
        if let choice = decider.chooseSwap(for: playerID) {
            try engine.swap(handCard: choice.handCard, plotCard: choice.plotCard, revealed: choice.zone == .revealed, playerID: playerID)
        }
        try engine.confirmSwap(playerID: playerID)
    case .trick:
        let index = decider.chooseCardIndex(for: playerID)
        guard engine.state.players[playerID].hand.indices.contains(index) else {
            throw TrainerError.invalidAction
        }
        try engine.playCard(engine.state.players[playerID].hand[index], playerID: playerID)
    case .assignment:
        let assignments = decider.chooseAssignments(for: playerID)
        for play in engine.state.lastTrick {
            guard let suit = assignments[play.card.id] else {
                throw TrainerError.invalidAction
            }
            try engine.assign(card: play.card, to: suit, playerID: playerID)
        }
        try engine.submitAssignments(playerID: playerID)
    case .requisition:
        engine.continueAfterRequisition()
    case .gameOver:
        break
    }
}

func chooseAndApply(
    playerID: Int,
    model: KolkhozPolicyModel,
    opponentModel: KolkhozPolicyModel?,
    trainingSeat: Int?,
    state: KolkhozState,
    engine: KolkhozEngine,
    rng: inout SeededGenerator,
    temperature: Double,
    opponentMode: String,
    scoreDeltaWeight: Double,
    marginDeltaWeight: Double,
    playerGradients: inout [PolicyGradient],
    playerShapedGradients: inout [PolicyGradient],
    playerShapedRewards: inout [Double],
    playerActionCounts: inout [Int]
) throws {
    if trainingSeat == nil || trainingSeat == playerID {
        let beforeScore = engine.finalScore(for: playerID)
        let beforeMargin = scoreMargin(for: playerID, engine: engine)
        let selection = try sampleAction(model: model, state: state, playerID: playerID, temperature: temperature, rng: &rng)
        playerGradients[playerID].add(selection.gradient)
        playerActionCounts[playerID] += 1
        try apply(selection.action, to: engine, playerID: playerID)
        let scoreDelta = Double(engine.finalScore(for: playerID) - beforeScore)
        let marginDelta = Double(scoreMargin(for: playerID, engine: engine) - beforeMargin)
        let shapedReward = scoreDeltaWeight * scoreDelta + marginDeltaWeight * marginDelta
        if shapedReward != 0 {
            playerShapedGradients[playerID].add(selection.gradient, scale: shapedReward)
            playerShapedRewards[playerID] += shapedReward
        }
    } else if opponentMode == "heuristic" {
        try applyHeuristicDecision(to: engine, playerID: playerID)
    } else {
        let opponent = opponentModel ?? model
        let action = try greedyAction(model: opponent, state: state, playerID: playerID)
        try apply(action, to: engine, playerID: playerID)
    }
}

func scoreMargin(for playerID: Int, engine: KolkhozEngine) -> Int {
    let ownScore = engine.finalScore(for: playerID)
    let bestOpponent = (0..<4)
        .filter { $0 != playerID }
        .map { engine.finalScore(for: $0) }
        .max() ?? 0
    return ownScore - bestOpponent
}

func sampleAction(
    model: KolkhozPolicyModel,
    state: KolkhozState,
    playerID: Int,
    temperature: Double,
    rng: inout SeededGenerator
) throws -> (action: PolicyAction, gradient: PolicyGradient) {
    let candidates = actionCandidates(model: model, state: state, playerID: playerID)
    guard !candidates.isEmpty else {
        throw TrainerError.noLegalActions(phase: state.phase, playerID: playerID)
    }

    let safeTemperature = max(0.05, temperature)
    let logits = candidates.map { $0.score / safeTemperature }
    let maxLogit = logits.max() ?? 0
    let weights = logits.map { exp($0 - maxLogit) }
    let total = weights.reduce(0, +)
    var draw = rng.uniform() * total
    var chosenIndex = candidates.count - 1
    for index in candidates.indices {
        draw -= weights[index]
        if draw <= 0 {
            chosenIndex = index
            break
        }
    }

    let probabilities = weights.map { $0 / total }
    var gradient = PolicyGradient.zerosLike(model)
    if let features = candidates[chosenIndex].features {
        gradient.add(scoreGradient(model: model, features: features), scale: 1 / safeTemperature)
    }
    for index in candidates.indices {
        guard let features = candidates[index].features else { continue }
        gradient.add(scoreGradient(model: model, features: features), scale: -probabilities[index] / safeTemperature)
    }

    return (candidates[chosenIndex].action, gradient)
}

func actionCandidates(model: KolkhozPolicyModel, state: KolkhozState, playerID: Int) -> [ActionCandidate] {
    switch state.phase {
    case .planning:
        return Suit.allCases.map { suit in
            let features = PolicyFeatures.trump(state: state, playerID: playerID, suit: suit)
            return ActionCandidate(action: .trump(suit), features: features, score: model.score(features))
        }

    case .swap:
        var candidates = [ActionCandidate(action: .noSwap, features: nil, score: 0)]
        guard state.players.indices.contains(playerID), !state.swapCount.contains(playerID) else {
            return candidates
        }
        for handCard in state.players[playerID].hand {
            for plotCard in state.players[playerID].plot.hidden {
                let features = PolicyFeatures.swap(
                    state: state,
                    playerID: playerID,
                    handCard: handCard,
                    plotCard: plotCard,
                    zone: .hidden
                )
                candidates.append(ActionCandidate(
                    action: .swap(handCard: handCard, plotCard: plotCard, revealed: false),
                    features: features,
                    score: model.score(features)
                ))
            }
            for plotCard in state.players[playerID].plot.revealed {
                let features = PolicyFeatures.swap(
                    state: state,
                    playerID: playerID,
                    handCard: handCard,
                    plotCard: plotCard,
                    zone: .revealed
                )
                candidates.append(ActionCandidate(
                    action: .swap(handCard: handCard, plotCard: plotCard, revealed: true),
                    features: features,
                    score: model.score(features)
                ))
            }
        }
        return candidates

    case .trick:
        guard state.players.indices.contains(playerID) else { return [] }
        return state.players[playerID].hand.enumerated().compactMap { index, card in
            guard isValidPlay(state: state, playerID: playerID, cardIndex: index) else { return nil }
            let features = PolicyFeatures.playCard(state: state, playerID: playerID, card: card)
            return ActionCandidate(action: .play(card), features: features, score: model.score(features))
        }

    case .assignment:
        let legalSet = Set(state.lastTrick.map(\.card.suit))
        return Suit.allCases.filter { legalSet.contains($0) }.map { suit in
            let features = PolicyFeatures.assign(state: state, playerID: playerID, suit: suit)
            return ActionCandidate(action: .assign(suit), features: features, score: model.score(features))
        }

    case .requisition, .gameOver:
        return []
    }
}

func greedyAction(model: KolkhozPolicyModel, state: KolkhozState, playerID: Int) throws -> PolicyAction {
    guard let best = actionCandidates(model: model, state: state, playerID: playerID).max(by: { $0.score < $1.score }) else {
        throw TrainerError.noLegalActions(phase: state.phase, playerID: playerID)
    }
    return best.action
}

func apply(_ action: PolicyAction, to engine: KolkhozEngine, playerID: Int) throws {
    switch action {
    case .trump(let suit):
        try engine.setTrump(suit, playerID: playerID)
    case .noSwap:
        try engine.confirmSwap(playerID: playerID)
    case .swap(let handCard, let plotCard, let revealed):
        try engine.swap(handCard: handCard, plotCard: plotCard, revealed: revealed, playerID: playerID)
        try engine.confirmSwap(playerID: playerID)
    case .play(let card):
        try engine.playCard(card, playerID: playerID)
    case .assign(let suit):
        for play in engine.state.lastTrick {
            try engine.assign(card: play.card, to: suit, playerID: playerID)
        }
        try engine.submitAssignments(playerID: playerID)
    }
}

func centeredRewards(scores: [Int: Int], reward: RewardWeights) -> [Int: Double] {
    let raw = Dictionary(uniqueKeysWithValues: (0..<4).map { playerID in
        let score = scores[playerID] ?? 0
        let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
        let isTop = score >= bestOpponent ? 1.0 : 0.0
        let isStrictTop = score > bestOpponent ? 1.0 : 0.0
        let rankPenalty = Double(rank(of: playerID, scores: scores) - 1)
        let scoreMargin = Double(score - bestOpponent)
        let value = reward.win * isTop + reward.strict * isStrictTop - reward.rank * rankPenalty + reward.margin * scoreMargin
        return (playerID, value)
    })
    let mean = raw.values.reduce(0, +) / Double(raw.count)
    return raw.mapValues { $0 - mean }
}

func rawReward(playerID: Int, scores: [Int: Int], reward: RewardWeights) -> Double {
    let score = scores[playerID] ?? 0
    let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
    let isTop = score >= bestOpponent ? 1.0 : 0.0
    let isStrictTop = score > bestOpponent ? 1.0 : 0.0
    let rankPenalty = Double(rank(of: playerID, scores: scores) - 1)
    let scoreMargin = Double(score - bestOpponent)
    return reward.win * isTop + reward.strict * isStrictTop - reward.rank * rankPenalty + reward.margin * scoreMargin
}

func rank(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    return 1 + scores.values.filter { $0 > target }.count
}

func margin(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
    return target - bestOpponent
}

func isValidPlay(state: KolkhozState, playerID: Int, cardIndex: Int) -> Bool {
    guard state.players.indices.contains(playerID),
          state.players[playerID].hand.indices.contains(cardIndex) else {
        return false
    }
    guard let leadSuit = state.currentTrick.first?.card.suit else {
        return true
    }
    let hand = state.players[playerID].hand
    let hasLeadSuit = hand.contains { $0.suit == leadSuit }
    return !hasLeadSuit || hand[cardIndex].suit == leadSuit
}

struct PolicyGradient {
    var w1: [Double]
    var b1: [Double]
    var w2: [Double]
    var b2: Double

    static func zerosLike(_ model: KolkhozPolicyModel) -> PolicyGradient {
        PolicyGradient(
            w1: Array(repeating: 0, count: model.w1.count),
            b1: Array(repeating: 0, count: model.b1.count),
            w2: Array(repeating: 0, count: model.w2.count),
            b2: 0
        )
    }

    mutating func add(_ other: PolicyGradient, scale: Double = 1) {
        for index in w1.indices { w1[index] += other.w1[index] * scale }
        for index in b1.indices { b1[index] += other.b1[index] * scale }
        for index in w2.indices { w2[index] += other.w2[index] * scale }
        b2 += other.b2 * scale
    }

    func norm() -> Double {
        var total = b2 * b2
        total += w1.reduce(0) { $0 + $1 * $1 }
        total += b1.reduce(0) { $0 + $1 * $1 }
        total += w2.reduce(0) { $0 + $1 * $1 }
        return sqrt(total)
    }
}

struct AdamState {
    var step: Int
    var first: PolicyGradient
    var second: PolicyGradient

    static func zerosLike(_ model: KolkhozPolicyModel) -> AdamState {
        AdamState(
            step: 0,
            first: .zerosLike(model),
            second: .zerosLike(model)
        )
    }
}

func scoreGradient(model: KolkhozPolicyModel, features: [Double]) -> PolicyGradient {
    var gradient = PolicyGradient.zerosLike(model)
    var preActivation = Array(repeating: 0.0, count: model.hiddenSize)
    var hidden = Array(repeating: 0.0, count: model.hiddenSize)

    for row in 0..<model.hiddenSize {
        var value = model.b1[row]
        let offset = row * model.inputSize
        for column in 0..<model.inputSize {
            value += model.w1[offset + column] * features[column]
        }
        preActivation[row] = value
        hidden[row] = max(0, value)
    }

    gradient.b2 = 1
    for row in 0..<model.hiddenSize {
        gradient.w2[row] = hidden[row]
        guard preActivation[row] > 0 else { continue }
        let upstream = model.w2[row]
        gradient.b1[row] = upstream
        let offset = row * model.inputSize
        for column in 0..<model.inputSize {
            gradient.w1[offset + column] = upstream * features[column]
        }
    }
    return gradient
}

func applying(_ gradient: PolicyGradient, to model: KolkhozPolicyModel, options: Options, divisor: Double) -> (model: KolkhozPolicyModel, norm: Double, scale: Double) {
    let norm = gradient.norm() / max(1, divisor)
    let clipScale = norm > options.maxGradientNorm ? options.maxGradientNorm / norm : 1
    let step = options.learningRate * clipScale / max(1, divisor)

    let w1 = model.w1.indices.map { index in
        model.w1[index] + step * gradient.w1[index] - options.learningRate * options.l2 * model.w1[index]
    }
    let b1 = model.b1.indices.map { index in
        model.b1[index] + step * gradient.b1[index] - options.learningRate * options.l2 * model.b1[index]
    }
    let w2 = model.w2.indices.map { index in
        model.w2[index] + step * gradient.w2[index] - options.learningRate * options.l2 * model.w2[index]
    }
    let b2 = model.b2 + step * gradient.b2 - options.learningRate * options.l2 * model.b2

    return (
        KolkhozPolicyModel(
            version: model.version,
            featureVersion: model.featureVersion,
            inputSize: model.inputSize,
            hiddenSize: model.hiddenSize,
            w1: w1,
            b1: b1,
            w2: w2,
            b2: b2
        ),
        norm,
        clipScale
    )
}

func applyingAdam(
    _ gradient: PolicyGradient,
    to model: KolkhozPolicyModel,
    state: inout AdamState,
    options: Options,
    divisor: Double
) -> (model: KolkhozPolicyModel, norm: Double, scale: Double) {
    let safeDivisor = max(1, divisor)
    let norm = gradient.norm() / safeDivisor
    let clipScale = norm > options.maxGradientNorm ? options.maxGradientNorm / norm : 1
    let scale = clipScale / safeDivisor
    state.step += 1

    let beta1 = options.adamBeta1
    let beta2 = options.adamBeta2
    let oneMinusBeta1Power = 1 - pow(beta1, Double(state.step))
    let oneMinusBeta2Power = 1 - pow(beta2, Double(state.step))

    func update(
        value: Double,
        gradient: Double,
        first: inout Double,
        second: inout Double
    ) -> Double {
        let clippedGradient = gradient * scale
        first = beta1 * first + (1 - beta1) * clippedGradient
        second = beta2 * second + (1 - beta2) * clippedGradient * clippedGradient
        let firstHat = first / oneMinusBeta1Power
        let secondHat = second / oneMinusBeta2Power
        let adamStep = options.learningRate * firstHat / (sqrt(secondHat) + options.adamEpsilon)
        return value + adamStep - options.learningRate * options.l2 * value
    }

    var w1 = model.w1
    for index in w1.indices {
        w1[index] = update(
            value: w1[index],
            gradient: gradient.w1[index],
            first: &state.first.w1[index],
            second: &state.second.w1[index]
        )
    }

    var b1 = model.b1
    for index in b1.indices {
        b1[index] = update(
            value: b1[index],
            gradient: gradient.b1[index],
            first: &state.first.b1[index],
            second: &state.second.b1[index]
        )
    }

    var w2 = model.w2
    for index in w2.indices {
        w2[index] = update(
            value: w2[index],
            gradient: gradient.w2[index],
            first: &state.first.w2[index],
            second: &state.second.w2[index]
        )
    }

    let b2 = update(
        value: model.b2,
        gradient: gradient.b2,
        first: &state.first.b2,
        second: &state.second.b2
    )

    return (
        KolkhozPolicyModel(
            version: model.version,
            featureVersion: model.featureVersion,
            inputSize: model.inputSize,
            hiddenSize: model.hiddenSize,
            w1: w1,
            b1: b1,
            w2: w2,
            b2: b2
        ),
        norm,
        clipScale
    )
}

enum PolicyFeatures {
    static let version = 1
    static let inputSize = 34

    static func trump(state: KolkhozState, playerID: Int, suit: Suit) -> [Double] {
        features(state: state, playerID: playerID, action: .trump, suit: suit, card: nil, zone: nil, swapDelta: 0)
    }

    static func swap(state: KolkhozState, playerID: Int, handCard: Card, plotCard: Card, zone: PlotCardZone) -> [Double] {
        features(
            state: state,
            playerID: playerID,
            action: .swap,
            suit: plotCard.suit,
            card: plotCard,
            zone: zone,
            swapDelta: Double(plotCard.value - handCard.value) / 13
        )
    }

    static func playCard(state: KolkhozState, playerID: Int, card: Card) -> [Double] {
        features(state: state, playerID: playerID, action: .play, suit: card.suit, card: card, zone: nil, swapDelta: 0)
    }

    static func assign(state: KolkhozState, playerID: Int, suit: Suit) -> [Double] {
        features(state: state, playerID: playerID, action: .assign, suit: suit, card: nil, zone: nil, swapDelta: 0)
    }
}

private extension PolicyFeatures {
    enum Action: Int {
        case trump
        case swap
        case play
        case assign
    }

    static func features(
        state: KolkhozState,
        playerID: Int,
        action: Action,
        suit: Suit,
        card: Card?,
        zone: PlotCardZone?,
        swapDelta: Double
    ) -> [Double] {
        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = state.workHours[suit, default: 0]
        let afterWork = currentWork + trickWork
        let plotCards = player.plot.hidden + player.plot.revealed
        let suitPlotCount = plotCards.filter { $0.suit == suit }.count
        let hiddenSuitCount = player.plot.hidden.filter { $0.suit == suit }.count
        let revealedJob = state.revealedJobs[suit]?.value ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(suitIndex(suit), count: 4))
        values.append(contentsOf: oneHot(card.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(card?.value ?? 0) / 13)
        values.append(Double(state.year) / 5)
        values.append(Double(state.trickCount) / 4)
        values.append(Double(player.hand.count) / 5)
        values.append(player.hasWonTrickThisYear ? 1 : 0)
        values.append(contentsOf: oneHot(leadSuit.map(suitIndex) ?? -1, count: 4))
        values.append(contentsOf: oneHot(state.trump.map(suitIndex) ?? -1, count: 4))
        values.append(Double(currentWork) / 40)
        values.append(Double(afterWork >= 40 ? 1 : 0))
        values.append(Double(suitPlotCount) / 8)
        values.append(Double(hiddenSuitCount) / 8)
        values.append(Double(revealedJob) / 5)
        values.append(wouldCurrentlyWin(card, state: state) ? 1 : 0)
        values.append(zone == .hidden ? 1 : 0)
        values.append(zone == .revealed ? 1 : 0)
        values.append(swapDelta)

        precondition(values.count == inputSize, "Kolkhoz policy feature size changed")
        return values
    }

    static func oneHot(_ selected: Int, count: Int) -> [Double] {
        (0..<count).map { $0 == selected ? 1 : 0 }
    }

    static func suitIndex(_ suit: Suit) -> Int {
        switch suit {
        case .wheat: 0
        case .sunflower: 1
        case .potato: 2
        case .beet: 3
        }
    }

    static func workValue(for card: Card, state: KolkhozState) -> Int {
        if state.variants.nomenclature && card.value == 11 && card.suit == state.trump {
            return 0
        }
        return card.value
    }

    static func wouldCurrentlyWin(_ card: Card?, state: KolkhozState) -> Bool {
        guard let card, !state.currentTrick.isEmpty else { return false }
        let candidate = TrickPlay(playerID: state.currentPlayer, card: card)
        let plays = state.currentTrick + [candidate]
        let leadSuit = state.currentTrick.first?.card.suit ?? card.suit
        let trumpCards = plays.filter { $0.card.suit == state.trump }
        let contenders = trumpCards.isEmpty ? plays.filter { $0.card.suit == leadSuit } : trumpCards
        return contenders.max { $0.card.value < $1.card.value } == candidate
    }
}

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

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

    mutating func signedUniform() -> Double {
        uniform() * 2 - 1
    }
}

func writeHistory(_ history: [BatchSummary], to path: String) throws {
    let url = URL(fileURLWithPath: path)
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(history).write(to: url)
}

func checkpointURL(outputPath: String, episode: Int) -> URL {
    let outputURL = URL(fileURLWithPath: outputPath)
    let directory = outputURL.deletingLastPathComponent()
    let base = outputURL.deletingPathExtension().lastPathComponent
    return directory.appendingPathComponent("\(base)_e\(episode).json")
}

func scheduledTrainingSeat(episode: Int, opponentModel: KolkhozPolicyModel?, seats: [Int]?) -> Int? {
    guard opponentModel != nil else { return nil }
    let schedule = seats?.isEmpty == false ? seats! : [0, 1, 2, 3]
    return schedule[(episode - 1) % schedule.count]
}

func expandedModel(_ model: KolkhozPolicyModel, hiddenSize targetHiddenSize: Int, scale: Double, rng: inout SeededGenerator) -> KolkhozPolicyModel {
    guard targetHiddenSize > model.hiddenSize else { return model }
    var w1 = Array(repeating: 0.0, count: targetHiddenSize * model.inputSize)
    for row in 0..<model.hiddenSize {
        let oldOffset = row * model.inputSize
        let newOffset = row * model.inputSize
        for column in 0..<model.inputSize {
            w1[newOffset + column] = model.w1[oldOffset + column]
        }
    }

    var b1 = Array(repeating: 0.0, count: targetHiddenSize)
    var w2 = Array(repeating: 0.0, count: targetHiddenSize)
    for row in 0..<model.hiddenSize {
        b1[row] = model.b1[row]
        w2[row] = model.w2[row]
    }

    let safeScale = max(0, scale)
    for row in model.hiddenSize..<targetHiddenSize {
        let offset = row * model.inputSize
        for column in 0..<model.inputSize {
            w1[offset + column] = rng.signedUniform() * safeScale
        }
        b1[row] = rng.signedUniform() * safeScale
        w2[row] = rng.signedUniform() * safeScale
    }

    return KolkhozPolicyModel(
        version: model.version,
        featureVersion: model.featureVersion,
        inputSize: model.inputSize,
        hiddenSize: targetHiddenSize,
        w1: w1,
        b1: b1,
        w2: w2,
        b2: model.b2
    )
}

func main() throws {
    let options = parseOptions()
    let reward = RewardWeights(
        win: options.winWeight,
        strict: options.strictWeight,
        rank: options.rankWeight,
        margin: options.marginWeight
    )
    var rng = SeededGenerator(seed: options.seed)
    var model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: options.startPath))
    guard model.isCompatible else {
        throw TrainerError.incompatibleModel(options.startPath)
    }
    if let expandHidden = options.expandHidden, expandHidden > model.hiddenSize {
        let previousHiddenSize = model.hiddenSize
        model = expandedModel(model, hiddenSize: expandHidden, scale: options.expandScale, rng: &rng)
        print("expanded_hidden from=\(previousHiddenSize) to=\(model.hiddenSize) scale=\(options.expandScale)")
    }
    let opponentModel = try options.opponentPath.map { try KolkhozPolicyModel.load(from: URL(fileURLWithPath: $0)) }
    if let opponentModel, !opponentModel.isCompatible {
        throw TrainerError.incompatibleModel(options.opponentPath ?? "opponent")
    }

    var batchGradient = PolicyGradient.zerosLike(model)
    var batchActions = 0
    var batchTopRate = 0.0
    var batchRank = 0.0
    var batchMargin = 0.0
    var batchReward = 0.0
    var batchAdvantage = 0.0
    var batchShapedReward = 0.0
    var batchEpisodes = 0
    var history: [BatchSummary] = []
    var adamState = AdamState.zerosLike(model)
    var seatBatchGradients = Array(repeating: PolicyGradient.zerosLike(model), count: 4)
    var seatBatchCounts = Array(repeating: 0, count: 4)

    for episode in 1...options.episodes {
        let trainingSeat = scheduledTrainingSeat(
            episode: episode,
            opponentModel: opponentModel,
            seats: options.trainingSeats
        )
        let result = if options.roundCurriculum {
            try playRoundEpisode(
                initialState: randomRoundState(
                    seed: options.seed + UInt64(episode),
                    plotCardsPerPlayer: options.roundPlotCards,
                    famineRate: options.roundFamineRate
                ),
                model: model,
                opponentModel: opponentModel,
                trainingSeat: trainingSeat,
                rng: &rng,
                temperature: options.temperature,
                pairedBaseline: options.pairedBaseline,
                advantageClip: options.advantageClip,
                reward: reward,
                opponentMode: options.opponentMode,
                scoreDeltaWeight: options.scoreDeltaWeight,
                marginDeltaWeight: options.marginDeltaWeight
            )
        } else {
            try playEpisode(
                model: model,
                opponentModel: opponentModel,
                seed: options.seed + UInt64(episode),
                trainingSeat: trainingSeat,
                rng: &rng,
                temperature: options.temperature,
                pairedBaseline: options.pairedBaseline,
                advantageClip: options.advantageClip,
                reward: reward,
                opponentMode: options.opponentMode,
                scoreDeltaWeight: options.scoreDeltaWeight,
                marginDeltaWeight: options.marginDeltaWeight
            )
        }
        if options.seatBalancedUpdate, let trainingSeat {
            seatBatchGradients[trainingSeat].add(result.gradient)
            seatBatchCounts[trainingSeat] += 1
        } else {
            batchGradient.add(result.gradient)
        }
        batchActions += result.summary.actions
        batchTopRate += result.summary.topRate
        batchRank += result.summary.averageRank
        batchMargin += result.summary.averageMargin
        batchReward += result.summary.averageReward
        batchAdvantage += result.summary.averageAdvantage
        batchShapedReward += result.summary.averageShapedReward
        batchEpisodes += 1

        if episode % options.batchSize == 0 || episode == options.episodes {
            let updateGradient: PolicyGradient
            let divisor: Double
            if options.seatBalancedUpdate, opponentModel != nil {
                var combinedGradient = PolicyGradient.zerosLike(model)
                var activeSeats = 0
                for seat in 0..<4 where seatBatchCounts[seat] > 0 {
                    combinedGradient.add(seatBatchGradients[seat], scale: 1 / Double(seatBatchCounts[seat]))
                    activeSeats += 1
                }
                updateGradient = combinedGradient
                divisor = Double(max(1, activeSeats))
            } else {
                updateGradient = batchGradient
                divisor = Double(max(1, batchEpisodes))
            }
            let updated = options.optimizer.lowercased() == "adam"
                ? applyingAdam(updateGradient, to: model, state: &adamState, options: options, divisor: divisor)
                : applying(updateGradient, to: model, options: options, divisor: divisor)
            model = updated.model
            let summary = BatchSummary(
                episode: episode,
                actions: batchActions,
                gradientNorm: updated.norm,
                scale: updated.scale,
                topRate: batchTopRate / Double(max(1, batchEpisodes)),
                averageRank: batchRank / Double(max(1, batchEpisodes)),
                averageMargin: batchMargin / Double(max(1, batchEpisodes)),
                averageReward: batchReward / Double(max(1, batchEpisodes)),
                averageAdvantage: batchAdvantage / Double(max(1, batchEpisodes)),
                averageShapedReward: batchShapedReward / Double(max(1, batchEpisodes))
            )
            history.append(summary)
            let topRateText = String(format: "%.3f", summary.topRate)
            let rankText = String(format: "%.3f", summary.averageRank)
            let marginText = String(format: "%.3f", summary.averageMargin)
            let advantageText = String(format: "%.3f", summary.averageAdvantage)
            let shapedText = String(format: "%.3f", summary.averageShapedReward)
            let normText = String(format: "%.3f", updated.norm)
            let scaleText = String(format: "%.3f", updated.scale)
            print("pg episode=\(episode) actions=\(batchActions) top_rate=\(topRateText) avg_rank=\(rankText) avg_margin=\(marginText) advantage=\(advantageText) shaped=\(shapedText) grad_norm=\(normText) clip=\(scaleText)")
            if options.checkpointEvery > 0 && episode % options.checkpointEvery == 0 {
                let url = checkpointURL(outputPath: options.outputPath, episode: episode)
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try model.save(to: url)
                print("checkpoint \(url.path)")
            }
            batchGradient = PolicyGradient.zerosLike(model)
            seatBatchGradients = Array(repeating: PolicyGradient.zerosLike(model), count: 4)
            seatBatchCounts = Array(repeating: 0, count: 4)
            batchActions = 0
            batchTopRate = 0
            batchRank = 0
            batchMargin = 0
            batchReward = 0
            batchAdvantage = 0
            batchShapedReward = 0
            batchEpisodes = 0
        }
    }

    let outputURL = URL(fileURLWithPath: options.outputPath)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try model.save(to: outputURL)
    if let historyPath = options.historyPath {
        try writeHistory(history, to: historyPath)
        print("history \(historyPath)")
    }
    print("exported \(options.outputPath)")
}

do {
    try main()
} catch {
    fputs("KolkhozPolicyGradientTrainer failed: \(error)\n", stderr)
    exit(1)
}
