import Foundation
import KolkhozCEngine
import KolkhozCore

let cValueInputSize = 64

struct Options {
    var startPath: String?
    var opponentPath: String?
    var opponentMode = "model"
    var engine = "c-direct"
    var cThreadCount = max(1, min(10, ProcessInfo.processInfo.activeProcessorCount))
    var outputPath = "../../training/rl/runs/policy_pg_self_play.json"
    var historyPath: String?
    var leaguePaths: [String] = []
    var checkpointEvery = 0
    var episodes = 2_000
    var batchSize = 32
    var seed: UInt64 = 14_000_000
    var expandHidden: Int?
    var expandScale = 0.01
    var scratch = true
    var scratchLayers: [Int] = [128, 128]
    var scratchScale = 1.0
    var sharedHeads = false
    var roundCurriculum = false
    var roundPlotCards = 6
    var roundFamineRate = 0.2
    var optimizer = "ppo"
    var learningRate = 0.0004
    var ppoEpochs = 4
    var ppoMinibatchSize = 256
    var ppoClip = 0.2
    var entropyWeight = 0.01
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
    var workDeltaWeight = 0.0
    var claimDeltaWeight = 0.0
    var ownRequisitionWeight = 0.0
    var pairedBaseline = true
    var perTransitionValueAdvantages = false
    var phaseBalancedPPO = false
    var imitationWeight = 0.0
    var imitationHeadWeights: [Double] = [-1, -1, -1, -1]
    var teacherForcingRate = 0.0
    var greedySampleRate = 0.25
    var advantageBaselineBeta = 0.05
    var valueLearningRate = 0.02
    var seatBalancedUpdate = false
    var advantageClip = 0.0
    var trainingSeats: [Int]?
    var freezeHidden = false
    var validationSeeds: [UInt64] = []
    var validationGamesPerSeat = 0
    var validationOutputPath: String?
    var validationBaselinePath: String?
    var validationMinScore = -Double.greatestFiniteMagnitude
    var validationMinTopDelta = -Double.greatestFiniteMagnitude
    var validationMinRankDelta = -Double.greatestFiniteMagnitude
    var validationMinMarginDelta = -Double.greatestFiniteMagnitude
    var validationMinWorstTopDelta = -Double.greatestFiniteMagnitude
    var validationMinWorstRankDelta = -Double.greatestFiniteMagnitude
    var validationMinWorstMarginDelta = -Double.greatestFiniteMagnitude
    var behaviorCloneSteps = 0
    var behaviorCloneOnly = false
    var behaviorCloneLearningRate: Double?
    var behaviorCloneHeadWeights: [Double] = [1, 1, 1, 1]
    var behaviorCloneDistillTemperature = 0.0
    var behaviorCloneRolloutTeacher = false
    var behaviorCloneRolloutMinImprovement = 0.0
    var behaviorCloneRolloutRoundOnly = false
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
    let averagePPOKL: Double
    let averagePPOAbsKL: Double
    let averagePPOEntropy: Double
    let averagePPOClipFraction: Double
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
    let averagePPOKL: Double
    let averagePPOAbsKL: Double
    let averagePPOEntropy: Double
    let averagePPOClipFraction: Double
}

struct ValidationSummary {
    let score: Double
    let samples: Int
    let topDelta: Double
    let strictDelta: Double
    let rankDelta: Double
    let marginDelta: Double
    let worstSeatTop: Double
    let worstSeatRank: Double
    let worstSeatMargin: Double
}

struct ValidationOutcome {
    let scores: [Int: Int]
    let medals: [Int: Int]
    let winnerID: Int
}

enum TrainerError: Error {
    case incompatibleModel(String)
    case noLegalActions(phase: GamePhase, playerID: Int)
    case invalidAction
    case gameDidNotFinish(phase: GamePhase, year: Int, currentPlayer: Int, guardCount: Int)
}

enum PolicyAction: Equatable {
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
            options.scratch = false
        case "--opponent-model":
            options.opponentPath = args.isEmpty ? nil : args.removeFirst()
        case "--opponent-mode":
            if let value = args.first {
                options.opponentMode = value
                args.removeFirst()
            }
        case "--engine":
            if let value = args.first {
                options.engine = value
                args.removeFirst()
            }
        case "--c-threads":
            if let value = args.first, let parsed = Int(value) {
                options.cThreadCount = max(1, parsed)
                args.removeFirst()
            }
        case "--output":
            options.outputPath = args.isEmpty ? options.outputPath : args.removeFirst()
        case "--history":
            options.historyPath = args.isEmpty ? nil : args.removeFirst()
        case "--league-models":
            if let value = args.first {
                options.leaguePaths = value.split(separator: ",").map(String.init)
                args.removeFirst()
            }
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
        case "--scratch":
            options.scratch = true
        case "--layers":
            if let value = args.first {
                let layers = value
                    .split(separator: ",")
                    .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                    .filter { $0 > 0 }
                if !layers.isEmpty {
                    options.scratchLayers = Array(layers.prefix(4))
                }
                args.removeFirst()
            }
        case "--scratch-scale":
            if let value = args.first, let parsed = Double(value) {
                options.scratchScale = parsed
                args.removeFirst()
            }
        case "--shared-heads":
            options.sharedHeads = true
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
        case "--ppo":
            options.optimizer = "ppo"
        case "--ppo-epochs":
            if let value = args.first, let parsed = Int(value) {
                options.ppoEpochs = max(1, parsed)
                args.removeFirst()
            }
        case "--ppo-minibatch-size":
            if let value = args.first, let parsed = Int(value) {
                options.ppoMinibatchSize = max(1, parsed)
                args.removeFirst()
            }
        case "--ppo-clip":
            if let value = args.first, let parsed = Double(value) {
                options.ppoClip = max(0, parsed)
                args.removeFirst()
            }
        case "--entropy-weight":
            if let value = args.first, let parsed = Double(value) {
                options.entropyWeight = max(0, parsed)
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
        case "--work-delta-weight":
            if let value = args.first, let parsed = Double(value) {
                options.workDeltaWeight = parsed
                args.removeFirst()
            }
        case "--claim-delta-weight":
            if let value = args.first, let parsed = Double(value) {
                options.claimDeltaWeight = parsed
                args.removeFirst()
            }
        case "--own-requisition-weight":
            if let value = args.first, let parsed = Double(value) {
                options.ownRequisitionWeight = parsed
                args.removeFirst()
            }
        case "--paired-baseline":
            options.pairedBaseline = true
        case "--no-paired-baseline":
            options.pairedBaseline = false
        case "--per-transition-value-advantages":
            options.perTransitionValueAdvantages = true
        case "--phase-balanced-ppo":
            options.phaseBalancedPPO = true
        case "--imitation-weight":
            if let value = args.first, let parsed = Double(value) {
                options.imitationWeight = max(0, parsed)
                args.removeFirst()
            }
        case "--imitation-head-weights":
            if let value = args.first {
                let weights = value
                    .split(separator: ",")
                    .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                if weights.count == 4 {
                    options.imitationHeadWeights = weights.map { max(0, $0) }
                }
                args.removeFirst()
            }
        case "--teacher-forcing-rate":
            if let value = args.first, let parsed = Double(value) {
                options.teacherForcingRate = min(max(parsed, 0), 1)
                args.removeFirst()
            }
        case "--greedy-sample-rate":
            if let value = args.first, let parsed = Double(value) {
                options.greedySampleRate = min(max(parsed, 0), 1)
                args.removeFirst()
            }
        case "--advantage-baseline-beta":
            if let value = args.first, let parsed = Double(value) {
                options.advantageBaselineBeta = min(max(parsed, 0), 1)
                args.removeFirst()
            }
        case "--value-learning-rate":
            if let value = args.first, let parsed = Double(value) {
                options.valueLearningRate = max(0, parsed)
                args.removeFirst()
            }
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
        case "--freeze-hidden":
            options.freezeHidden = true
        case "--validation-seeds":
            if let value = args.first {
                let seeds = value
                    .split(separator: ",")
                    .compactMap { UInt64($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                options.validationSeeds = seeds
                args.removeFirst()
            }
        case "--validation-games-per-seat":
            if let value = args.first, let parsed = Int(value) {
                options.validationGamesPerSeat = parsed
                args.removeFirst()
            }
        case "--validation-output":
            options.validationOutputPath = args.isEmpty ? nil : args.removeFirst()
        case "--validation-baseline-model":
            options.validationBaselinePath = args.isEmpty ? nil : args.removeFirst()
        case "--validation-min-score":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinScore = parsed
                args.removeFirst()
            }
        case "--validation-min-top-delta":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinTopDelta = parsed
                args.removeFirst()
            }
        case "--validation-min-rank-delta":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinRankDelta = parsed
                args.removeFirst()
            }
        case "--validation-min-margin-delta":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinMarginDelta = parsed
                args.removeFirst()
            }
        case "--validation-min-worst-top-delta":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinWorstTopDelta = parsed
                args.removeFirst()
            }
        case "--validation-min-worst-rank-delta":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinWorstRankDelta = parsed
                args.removeFirst()
            }
        case "--validation-min-worst-margin-delta":
            if let value = args.first, let parsed = Double(value) {
                options.validationMinWorstMarginDelta = parsed
                args.removeFirst()
            }
        case "--behavior-clone-steps":
            if let value = args.first, let parsed = Int(value) {
                options.behaviorCloneSteps = max(0, parsed)
                args.removeFirst()
            }
        case "--behavior-clone-only":
            options.behaviorCloneOnly = true
        case "--behavior-clone-learning-rate":
            if let value = args.first, let parsed = Double(value) {
                options.behaviorCloneLearningRate = max(0, parsed)
                args.removeFirst()
            }
        case "--behavior-clone-head-weights":
            if let value = args.first {
                let weights = value
                    .split(separator: ",")
                    .compactMap { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
                if weights.count == 4 {
                    options.behaviorCloneHeadWeights = weights.map { max(0, $0) }
                }
                args.removeFirst()
            }
        case "--behavior-clone-distill-temperature":
            if let value = args.first, let parsed = Double(value) {
                options.behaviorCloneDistillTemperature = max(0, parsed)
                args.removeFirst()
            }
        case "--behavior-clone-rollout-teacher":
            options.behaviorCloneRolloutTeacher = true
        case "--behavior-clone-rollout-min-improvement":
            if let value = args.first, let parsed = Double(value) {
                options.behaviorCloneRolloutMinImprovement = max(0, parsed)
                args.removeFirst()
            }
        case "--behavior-clone-rollout-round-only":
            options.behaviorCloneRolloutRoundOnly = true
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
    marginDeltaWeight: Double,
    workDeltaWeight: Double,
    claimDeltaWeight: Double,
    ownRequisitionWeight: Double
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
                workDeltaWeight: workDeltaWeight,
                claimDeltaWeight: claimDeltaWeight,
                ownRequisitionWeight: ownRequisitionWeight,
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
                workDeltaWeight: workDeltaWeight,
                claimDeltaWeight: claimDeltaWeight,
                ownRequisitionWeight: ownRequisitionWeight,
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
                workDeltaWeight: workDeltaWeight,
                claimDeltaWeight: claimDeltaWeight,
                ownRequisitionWeight: ownRequisitionWeight,
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
                workDeltaWeight: workDeltaWeight,
                claimDeltaWeight: claimDeltaWeight,
                ownRequisitionWeight: ownRequisitionWeight,
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
        averageShapedReward: averageShapedReward,
        averagePPOKL: 0,
        averagePPOAbsKL: 0,
        averagePPOEntropy: 0,
        averagePPOClipFraction: 0
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
    marginDeltaWeight: Double,
    workDeltaWeight: Double,
    claimDeltaWeight: Double,
    ownRequisitionWeight: Double
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
                workDeltaWeight: workDeltaWeight,
                claimDeltaWeight: claimDeltaWeight,
                ownRequisitionWeight: ownRequisitionWeight,
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
                workDeltaWeight: workDeltaWeight,
                claimDeltaWeight: claimDeltaWeight,
                ownRequisitionWeight: ownRequisitionWeight,
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
            averageShapedReward: averageShapedReward,
            averagePPOKL: 0,
            averagePPOAbsKL: 0,
            averagePPOEntropy: 0,
            averagePPOClipFraction: 0
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

    var deck = workerDeck(deckType: state.variants.deckType).shuffled(using: &rng)
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

func workerDeck(deckType: Int) -> [Card] {
    let values = deckType == 36 ? 6...13 : 1...13
    return Suit.allCases.flatMap { suit in values.map { Card(suit: suit, value: $0) } }
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
    workDeltaWeight: Double,
    claimDeltaWeight: Double,
    ownRequisitionWeight: Double,
    playerGradients: inout [PolicyGradient],
    playerShapedGradients: inout [PolicyGradient],
    playerShapedRewards: inout [Double],
    playerActionCounts: inout [Int]
) throws {
    if trainingSeat == nil || trainingSeat == playerID {
        let beforeScore = engine.finalScore(for: playerID)
        let beforeMargin = scoreMargin(for: playerID, engine: engine)
        let beforeWork = totalWorkHours(engine.state)
        let beforeClaims = engine.state.claimedJobs.count
        let beforeOwnRequisitions = ownRequisitionEvents(playerID: playerID, state: engine.state)
        let selection = try sampleAction(model: model, state: state, playerID: playerID, temperature: temperature, rng: &rng)
        playerGradients[playerID].add(selection.gradient)
        playerActionCounts[playerID] += 1
        try apply(selection.action, to: engine, playerID: playerID)
        let scoreDelta = Double(engine.finalScore(for: playerID) - beforeScore)
        let marginDelta = Double(scoreMargin(for: playerID, engine: engine) - beforeMargin)
        let workDelta = Double(totalWorkHours(engine.state) - beforeWork)
        let claimDelta = Double(engine.state.claimedJobs.count - beforeClaims)
        let ownRequisitionDelta = Double(ownRequisitionEvents(playerID: playerID, state: engine.state) - beforeOwnRequisitions)
        let shapedReward = scoreDeltaWeight * scoreDelta
            + marginDeltaWeight * marginDelta
            + workDeltaWeight * workDelta
            + claimDeltaWeight * claimDelta
            - ownRequisitionWeight * ownRequisitionDelta
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

func totalWorkHours(_ state: KolkhozState) -> Int {
    state.workHours.values.reduce(0, +)
}

func ownRequisitionEvents(playerID: Int, state: KolkhozState) -> Int {
    state.requisitionEvents.filter { $0.playerID == playerID && $0.card != nil }.count
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
            let features = PolicyFeatures.trump(state: state, playerID: playerID, suit: suit, featureVersion: model.featureVersion)
            return ActionCandidate(action: .trump(suit), features: features, score: model.score(features))
        }

    case .swap:
        let noSwapFeatures = PolicyFeatures.noSwap(state: state, playerID: playerID, featureVersion: model.featureVersion)
        var candidates = [ActionCandidate(action: .noSwap, features: noSwapFeatures, score: model.score(noSwapFeatures))]
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
                    zone: .hidden,
                    featureVersion: model.featureVersion
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
                    zone: .revealed,
                    featureVersion: model.featureVersion
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
            let features = PolicyFeatures.playCard(state: state, playerID: playerID, card: card, featureVersion: model.featureVersion)
            return ActionCandidate(action: .play(card), features: features, score: model.score(features))
        }

    case .assignment:
        let legalSet = Set(state.lastTrick.map(\.card.suit))
        return Suit.allCases.filter { legalSet.contains($0) }.map { suit in
            let features = PolicyFeatures.assign(state: state, playerID: playerID, suit: suit, featureVersion: model.featureVersion)
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

func deciderAction(model: KolkhozPolicyModel?, state: KolkhozState, playerID: Int) throws -> PolicyAction {
    let decider = KolkhozAIDecider(state: state, model: model)
    switch state.phase {
    case .planning:
        return .trump(decider.chooseTrump(for: playerID))
    case .swap:
        if let choice = decider.chooseSwap(for: playerID) {
            return .swap(handCard: choice.handCard, plotCard: choice.plotCard, revealed: choice.zone == .revealed)
        }
        return .noSwap
    case .trick:
        let index = decider.chooseCardIndex(for: playerID)
        guard state.players[playerID].hand.indices.contains(index) else {
            throw TrainerError.invalidAction
        }
        return .play(state.players[playerID].hand[index])
    case .assignment:
        let assignments = decider.chooseAssignments(for: playerID)
        guard let suit = state.lastTrick.first.flatMap({ assignments[$0.card.id] }) else {
            throw TrainerError.invalidAction
        }
        return .assign(suit)
    case .requisition, .gameOver:
        throw TrainerError.invalidAction
    }
}

func rolloutImprovedAction(
    teacherModel: KolkhozPolicyModel,
    state: KolkhozState,
    playerID: Int,
    minImprovement: Double,
    roundOnly: Bool
) throws -> PolicyAction {
    let teacherAction = try deciderAction(model: teacherModel, state: state, playerID: playerID)
    let candidates = actionCandidates(model: teacherModel, state: state, playerID: playerID)
    guard !candidates.isEmpty else {
        throw TrainerError.noLegalActions(phase: state.phase, playerID: playerID)
    }

    var bestAction = teacherAction
    var bestUtility = -Double.greatestFiniteMagnitude
    var teacherUtility = -Double.greatestFiniteMagnitude
    for candidate in candidates {
        let engine = KolkhozEngine(testing: state, controllers: Array(repeating: .human, count: 4), aiModel: nil)
        do {
            try apply(candidate.action, to: engine, playerID: playerID)
            let outcome = try finishWithDecider(engine: engine, model: teacherModel, roundOnly: roundOnly)
            let metrics = validationMetrics(for: playerID, outcome: outcome)
            let utility = metrics.strict * 1_000 + (4 - metrics.rank) * 100 + metrics.margin
            if candidate.action == teacherAction {
                teacherUtility = utility
            }
            if utility > bestUtility || (utility == bestUtility && candidate.action == teacherAction) {
                bestUtility = utility
                bestAction = candidate.action
            }
        } catch {
            continue
        }
    }
    guard bestAction != teacherAction, bestUtility >= teacherUtility + minImprovement else {
        return teacherAction
    }
    return bestAction
}

func finishWithDecider(engine: KolkhozEngine, model: KolkhozPolicyModel?, roundOnly: Bool = false) throws -> ValidationOutcome {
    let startingYear = engine.state.year
    var guardCount = 0
    while engine.state.phase != .gameOver
        && (!roundOnly || engine.state.year == startingYear)
        && guardCount < 1_000 {
        guardCount += 1
        switch engine.state.phase {
        case .planning, .swap, .trick:
            let action = try deciderAction(model: model, state: engine.state, playerID: engine.state.currentPlayer)
            try apply(action, to: engine, playerID: engine.state.currentPlayer)
        case .assignment:
            let playerID = engine.state.lastWinner ?? engine.state.currentPlayer
            let action = try deciderAction(model: model, state: engine.state, playerID: playerID)
            try apply(action, to: engine, playerID: playerID)
        case .requisition:
            engine.continueAfterRequisition()
        case .gameOver:
            break
        }
    }
    if roundOnly && engine.state.phase != .gameOver && engine.state.year != startingYear {
        return validationOutcome(from: engine.state)
    }
    guard engine.state.phase == .gameOver, let result = engine.state.gameResult else {
        throw TrainerError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }
    let medals = Dictionary(uniqueKeysWithValues: engine.state.players.map { ($0.id, $0.plot.medals + $0.medals) })
    return ValidationOutcome(scores: result.scores, medals: medals, winnerID: result.winnerID)
}

func validationOutcome(from state: KolkhozState) -> ValidationOutcome {
    var scores: [Int: Int] = [:]
    var medals: [Int: Int] = [:]
    for player in state.players {
        scores[player.id] = PolicyFeatures.finalScore(for: player.id, state: state)
        medals[player.id] = player.plot.medals + player.medals
    }
    let winner = state.players.map(\.id).max { lhs, rhs in
        let lhsScore = scores[lhs] ?? 0
        let rhsScore = scores[rhs] ?? 0
        if lhsScore != rhsScore { return lhsScore < rhsScore }
        let lhsMedals = medals[lhs] ?? 0
        let rhsMedals = medals[rhs] ?? 0
        if lhsMedals != rhsMedals { return lhsMedals < rhsMedals }
        return lhs < rhs
    } ?? 0
    return ValidationOutcome(scores: scores, medals: medals, winnerID: winner)
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

struct BehaviorCloneSummary {
    let steps: Int
    let accuracy: Double
    let averageLoss: Double
    let gradientNorm: Double
}

func actionHeadIndex(_ action: PolicyAction) -> Int {
    switch action {
    case .trump: return 0
    case .noSwap, .swap: return 1
    case .play: return 2
    case .assign: return 3
    }
}

func teacherScore(model: KolkhozPolicyModel, state: KolkhozState, playerID: Int, action: PolicyAction) -> Double {
    switch action {
    case .trump(let suit):
        return model.score(PolicyFeatures.trump(state: state, playerID: playerID, suit: suit, featureVersion: model.featureVersion))
    case .noSwap:
        if model.featureVersion >= PolicyFeatures.version {
            return model.score(PolicyFeatures.noSwap(state: state, playerID: playerID, featureVersion: model.featureVersion))
        }
        return 0
    case .swap(let handCard, let plotCard, let revealed):
        return model.score(PolicyFeatures.swap(
            state: state,
            playerID: playerID,
            handCard: handCard,
            plotCard: plotCard,
            zone: revealed ? .revealed : .hidden,
            featureVersion: model.featureVersion
        ))
    case .play(let card):
        return model.score(PolicyFeatures.playCard(state: state, playerID: playerID, card: card, featureVersion: model.featureVersion))
    case .assign(let suit):
        return model.score(PolicyFeatures.assign(state: state, playerID: playerID, suit: suit, featureVersion: model.featureVersion))
    }
}

func softmaxProbabilities(_ scores: [Double], temperature: Double) -> [Double] {
    let safeTemperature = max(0.05, temperature)
    let logits = scores.map { $0 / safeTemperature }
    let maxLogit = logits.max() ?? 0
    let weights = logits.map { exp($0 - maxLogit) }
    let total = max(weights.reduce(0, +), .leastNonzeroMagnitude)
    return weights.map { $0 / total }
}

func behaviorCloneGradient(
    model: KolkhozPolicyModel,
    teacherModel: KolkhozPolicyModel,
    state: KolkhozState,
    playerID: Int,
    teacherAction: PolicyAction,
    temperature: Double,
    headWeights: [Double],
    distillTemperature: Double
) throws -> (gradient: PolicyGradient, loss: Double, correct: Bool, weight: Double) {
    let candidates = actionCandidates(model: model, state: state, playerID: playerID)
    guard !candidates.isEmpty else {
        throw TrainerError.noLegalActions(phase: state.phase, playerID: playerID)
    }
    guard let teacherIndex = candidates.firstIndex(where: { $0.action == teacherAction }) else {
        throw TrainerError.invalidAction
    }

    let probabilities = softmaxProbabilities(candidates.map(\.score), temperature: temperature)
    let teacherProbabilities: [Double]
    if distillTemperature > 0 {
        let teacherScores = candidates.map { teacherScore(model: teacherModel, state: state, playerID: playerID, action: $0.action) }
        teacherProbabilities = softmaxProbabilities(teacherScores, temperature: distillTemperature)
    } else {
        teacherProbabilities = candidates.indices.map { $0 == teacherIndex ? 1.0 : 0.0 }
    }
    var gradient = PolicyGradient.zerosLike(model)

    let safeTemperature = max(0.05, temperature)
    var loss = 0.0
    for index in candidates.indices {
        guard let features = candidates[index].features else { continue }
        let target = teacherProbabilities[index]
        loss -= target * log(max(probabilities[index], .leastNonzeroMagnitude))
        gradient.add(scoreGradient(model: model, features: features), scale: (target - probabilities[index]) / safeTemperature)
    }

    let head = actionHeadIndex(teacherAction)
    let weight = headWeights.indices.contains(head) ? headWeights[head] : 1
    return (
        gradient,
        loss,
        candidates.indices.max(by: { candidates[$0].score < candidates[$1].score }) == teacherIndex,
        weight
    )
}

func behaviorClonePretrain(
    model startModel: KolkhozPolicyModel,
    teacherModel: KolkhozPolicyModel,
    options: Options
) throws -> (model: KolkhozPolicyModel, summary: BehaviorCloneSummary) {
    var model = startModel
    var adamState = AdamState.zerosLike(model)
    var batchGradient = PolicyGradient.zerosLike(model)
    var batchWeight = 0.0
    var steps = 0
    var correct = 0
    var totalLoss = 0.0
    var lastNorm = 0.0
    let batchSize = max(1, options.batchSize)
    let validationSelectionEnabled = options.checkpointEvery > 0
        && !options.validationSeeds.isEmpty
        && options.validationGamesPerSeat > 0
    let validationURL = validationBestURL(
        outputPath: options.outputPath,
        validationOutputPath: options.validationOutputPath
    )
    var bestValidationScore = -Double.infinity
    var bestValidationStep = 0
    var bestValidationModel = model
    let originalLearningRate = options.learningRate
    var cloneOptions = options
    if let cloneLearningRate = options.behaviorCloneLearningRate {
        cloneOptions.learningRate = cloneLearningRate
    }

    var episode = 0
    while steps < options.behaviorCloneSteps {
        episode += 1
        let seed = options.seed &+ UInt64(episode)
        let engine: KolkhozEngine
        if options.roundCurriculum {
            let state = randomRoundState(
                seed: seed,
                plotCardsPerPlayer: options.roundPlotCards,
                famineRate: options.roundFamineRate
            )
            engine = KolkhozEngine(testing: state, controllers: Array(repeating: .human, count: 4), aiModel: nil)
        } else {
            engine = KolkhozEngine(seed: seed, variants: .kolkhoz, controllers: Array(repeating: .human, count: 4), aiModel: nil)
        }
        let startingYear = engine.state.year

        var guardCount = 0
        while engine.state.phase != .gameOver
            && (!options.roundCurriculum || engine.state.year == startingYear)
            && steps < options.behaviorCloneSteps
            && guardCount < 2_000 {
            guardCount += 1
            switch engine.state.phase {
            case .planning, .swap, .trick, .assignment:
                let playerID = engine.state.phase == .assignment ? (engine.state.lastWinner ?? engine.state.currentPlayer) : engine.state.currentPlayer
                let teacherAction = try options.behaviorCloneRolloutTeacher
                    ? rolloutImprovedAction(
                        teacherModel: teacherModel,
                        state: engine.state,
                        playerID: playerID,
                        minImprovement: options.behaviorCloneRolloutMinImprovement,
                        roundOnly: options.behaviorCloneRolloutRoundOnly
                    )
                    : deciderAction(model: teacherModel, state: engine.state, playerID: playerID)
                let sample = try behaviorCloneGradient(
                    model: model,
                    teacherModel: teacherModel,
                    state: engine.state,
                    playerID: playerID,
                    teacherAction: teacherAction,
                    temperature: options.temperature,
                    headWeights: options.behaviorCloneHeadWeights,
                    distillTemperature: options.behaviorCloneDistillTemperature
                )
                if sample.weight > 0 {
                    batchGradient.add(sample.gradient, scale: sample.weight)
                    batchWeight += sample.weight
                }
                totalLoss += sample.loss
                correct += sample.correct ? 1 : 0
                steps += 1

                if steps % batchSize == 0 || steps == options.behaviorCloneSteps {
                    let updated = applyingAdam(batchGradient, to: model, state: &adamState, options: cloneOptions, divisor: max(1, batchWeight))
                    model = updated.model
                    lastNorm = updated.norm
                    batchGradient = PolicyGradient.zerosLike(model)
                    batchWeight = 0
                    if validationSelectionEnabled
                        && (steps % options.checkpointEvery == 0 || steps == options.behaviorCloneSteps) {
                        let checkpoint = checkpointURL(outputPath: options.outputPath, episode: steps)
                        try FileManager.default.createDirectory(at: checkpoint.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try model.save(to: checkpoint)
                        print("behavior_clone_checkpoint \(checkpoint.path)")
                        let validation = try validateModel(
                            model,
                            baselineModel: teacherModel,
                            seeds: options.validationSeeds,
                            gamesPerSeat: options.validationGamesPerSeat
                        )
                        printValidation(validation, episode: steps)
                        let gateStatus = validationGateStatus(validation, options: options)
                        print("validation_gate episode=\(steps) status=\(gateStatus)")
                        if validation.score > bestValidationScore {
                            bestValidationScore = validation.score
                            bestValidationStep = steps
                            bestValidationModel = model
                        }
                        if gateStatus == "pass" {
                            try FileManager.default.createDirectory(at: validationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                            try model.save(to: validationURL)
                            print("validation_best \(validationURL.path)")
                        }
                    }
                }

                try apply(teacherAction, to: engine, playerID: playerID)

            case .requisition:
                engine.continueAfterRequisition()
            case .gameOver:
                break
            }
        }

        if guardCount >= 2_000 {
            throw TrainerError.gameDidNotFinish(
                phase: engine.state.phase,
                year: engine.state.year,
                currentPlayer: engine.state.currentPlayer,
                guardCount: guardCount
            )
        }
    }

    if let cloneLearningRate = options.behaviorCloneLearningRate {
        print("behavior_clone_learning_rate=\(String(format: "%.6f", cloneLearningRate)) original_learning_rate=\(String(format: "%.6f", originalLearningRate))")
    }
    if validationSelectionEnabled && bestValidationScore.isFinite {
        model = bestValidationModel
        print("behavior_clone_selected step=\(bestValidationStep) validation_score=\(String(format: "%.4f", bestValidationScore))")
    }
    return (
        model,
        BehaviorCloneSummary(
            steps: steps,
            accuracy: Double(correct) / Double(max(1, steps)),
            averageLoss: totalLoss / Double(max(1, steps)),
            gradientNorm: lastNorm
        )
    )
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

func beats(_ lhs: Int, _ rhs: Int, scores: [Int: Int], medals: [Int: Int]) -> Bool {
    let lhsScore = scores[lhs] ?? 0
    let rhsScore = scores[rhs] ?? 0
    if lhsScore != rhsScore { return lhsScore > rhsScore }
    let lhsMedals = medals[lhs] ?? 0
    let rhsMedals = medals[rhs] ?? 0
    if lhsMedals != rhsMedals { return lhsMedals > rhsMedals }
    return lhs > rhs
}

func rank(of playerID: Int, outcome: ValidationOutcome) -> Int {
    1 + outcome.scores.keys.filter { $0 != playerID && beats($0, playerID, scores: outcome.scores, medals: outcome.medals) }.count
}

func margin(of playerID: Int, scores: [Int: Int]) -> Int {
    let target = scores[playerID] ?? 0
    let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
    return target - bestOpponent
}

func validationMetrics(for playerID: Int, outcome: ValidationOutcome) -> (top: Double, strict: Double, rank: Double, margin: Double) {
    let scores = outcome.scores
    let playerScore = scores[playerID] ?? 0
    let bestOpponent = scores.filter { $0.key != playerID }.map(\.value).max() ?? 0
    let isStrictTop = !scores.keys.contains { $0 != playerID && beats($0, playerID, scores: scores, medals: outcome.medals) }
    return (
        top: outcome.winnerID == playerID ? 1 : 0,
        strict: isStrictTop ? 1 : 0,
        rank: Double(rank(of: playerID, outcome: outcome)),
        margin: Double(playerScore - bestOpponent)
    )
}

func mean(_ values: [Double]) -> Double {
    values.reduce(0, +) / Double(max(1, values.count))
}

func playValidationGame(seed: UInt64, model: KolkhozPolicyModel?, modelSeat: Int?) throws -> ValidationOutcome {
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
                throw TrainerError.invalidAction
            }
            try engine.playCard(engine.state.players[0].hand[index])
        case .assignment where engine.state.lastWinner == 0:
            let assignments = decider.chooseAssignments(for: 0)
            for play in engine.state.lastTrick {
                guard let suit = assignments[play.card.id] else {
                    throw TrainerError.invalidAction
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
        throw TrainerError.gameDidNotFinish(
            phase: engine.state.phase,
            year: engine.state.year,
            currentPlayer: engine.state.currentPlayer,
            guardCount: guardCount
        )
    }
    let medals = Dictionary(uniqueKeysWithValues: engine.state.players.map { ($0.id, $0.plot.medals + $0.medals) })
    return ValidationOutcome(scores: result.scores, medals: medals, winnerID: result.winnerID)
}

func validateModel(
    _ model: KolkhozPolicyModel,
    baselineModel: KolkhozPolicyModel?,
    seeds: [UInt64],
    gamesPerSeat: Int
) throws -> ValidationSummary {
    var topDeltas: [Double] = []
    var strictDeltas: [Double] = []
    var rankDeltas: [Double] = []
    var marginDeltas: [Double] = []
    var seatTop = Array(repeating: [Double](), count: 4)
    var seatRank = Array(repeating: [Double](), count: 4)
    var seatMargin = Array(repeating: [Double](), count: 4)

    for seedBase in seeds {
        for seat in 0..<4 {
            for gameIndex in 0..<gamesPerSeat {
                let seed = seedBase + UInt64(gameIndex)
                let candidateScores = try playValidationGame(seed: seed, model: model, modelSeat: seat)
                let baselineScores = try playValidationGame(
                    seed: seed,
                    model: baselineModel,
                    modelSeat: baselineModel == nil ? nil : seat
                )
                let candidate = validationMetrics(for: seat, outcome: candidateScores)
                let baseline = validationMetrics(for: seat, outcome: baselineScores)
                let topDelta = candidate.top - baseline.top
                let strictDelta = candidate.strict - baseline.strict
                let rankDelta = baseline.rank - candidate.rank
                let marginDelta = candidate.margin - baseline.margin
                topDeltas.append(topDelta)
                strictDeltas.append(strictDelta)
                rankDeltas.append(rankDelta)
                marginDeltas.append(marginDelta)
                seatTop[seat].append(topDelta)
                seatRank[seat].append(rankDelta)
                seatMargin[seat].append(marginDelta)
            }
        }
    }

    let topDelta = mean(topDeltas)
    let strictDelta = mean(strictDeltas)
    let rankDelta = mean(rankDeltas)
    let marginDelta = mean(marginDeltas)
    let worstSeatTop = seatTop.map(mean).min() ?? 0
    let worstSeatRank = seatRank.map(mean).min() ?? 0
    let worstSeatMargin = seatMargin.map(mean).min() ?? 0
    let regressionPenalty = min(0, worstSeatTop) * 1.5 + min(0, worstSeatRank) + min(0, worstSeatMargin) * 0.02
    let score = topDelta + strictDelta * 0.5 + rankDelta * 0.25 + marginDelta * 0.02 + regressionPenalty

    return ValidationSummary(
        score: score,
        samples: topDeltas.count,
        topDelta: topDelta,
        strictDelta: strictDelta,
        rankDelta: rankDelta,
        marginDelta: marginDelta,
        worstSeatTop: worstSeatTop,
        worstSeatRank: worstSeatRank,
        worstSeatMargin: worstSeatMargin
    )
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
    var hiddenWeights: [[Double]]
    var hiddenBiases: [[Double]]
    var w2: [Double]
    var outputWeights: [Double]
    var b2s: [Double]

    static func zerosLike(_ model: KolkhozPolicyModel) -> PolicyGradient {
        PolicyGradient(
            w1: Array(repeating: 0, count: model.w1.count),
            b1: Array(repeating: 0, count: model.b1.count),
            hiddenWeights: model.hiddenWeights.map { Array(repeating: 0, count: $0.count) },
            hiddenBiases: model.hiddenBiases.map { Array(repeating: 0, count: $0.count) },
            w2: Array(repeating: 0, count: model.w2.count),
            outputWeights: Array(repeating: 0, count: model.outputWeights.count),
            b2s: Array(repeating: 0, count: model.headCount)
        )
    }

    mutating func add(_ other: PolicyGradient, scale: Double = 1) {
        for index in w1.indices { w1[index] += other.w1[index] * scale }
        for index in b1.indices { b1[index] += other.b1[index] * scale }
        for layer in hiddenWeights.indices {
            for index in hiddenWeights[layer].indices {
                hiddenWeights[layer][index] += other.hiddenWeights[layer][index] * scale
            }
            for index in hiddenBiases[layer].indices {
                hiddenBiases[layer][index] += other.hiddenBiases[layer][index] * scale
            }
        }
        for index in w2.indices { w2[index] += other.w2[index] * scale }
        for index in outputWeights.indices { outputWeights[index] += other.outputWeights[index] * scale }
        for index in b2s.indices { b2s[index] += other.b2s[index] * scale }
    }

    func norm() -> Double {
        var total = b2s.reduce(0) { $0 + $1 * $1 }
        total += w1.reduce(0) { $0 + $1 * $1 }
        total += b1.reduce(0) { $0 + $1 * $1 }
        for weights in hiddenWeights { total += weights.reduce(0) { $0 + $1 * $1 } }
        for biases in hiddenBiases { total += biases.reduce(0) { $0 + $1 * $1 } }
        total += w2.reduce(0) { $0 + $1 * $1 }
        total += outputWeights.reduce(0) { $0 + $1 * $1 }
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
    if model.usesLayerStack {
        var activations: [[Double]] = [features]
        var preActivations: [[Double]] = []

        for layer in model.hiddenLayerSizes.indices {
            let input = activations[layer]
            let layerSize = model.hiddenLayerSizes[layer]
            let weights = model.hiddenWeights[layer]
            let biases = model.hiddenBiases[layer]
            var preActivation = Array(repeating: 0.0, count: layerSize)
            var activation = Array(repeating: 0.0, count: layerSize)
            for row in 0..<layerSize {
                var value = biases[row]
                let offset = row * input.count
                for column in 0..<input.count {
                    value += weights[offset + column] * input[column]
                }
                preActivation[row] = value
                activation[row] = max(0, value)
            }
            preActivations.append(preActivation)
            activations.append(activation)
        }

        let head = actionHead(for: features, headCount: model.headCount)
        gradient.b2s[head] = 1
        let lastActivation = activations.last ?? []
        let outputOffset = head * lastActivation.count
        for row in lastActivation.indices {
            gradient.outputWeights[outputOffset + row] = lastActivation[row]
        }

        var upstream = Array(repeating: 0.0, count: lastActivation.count)
        for row in upstream.indices {
            upstream[row] = model.outputWeights[outputOffset + row]
        }

        for layer in model.hiddenLayerSizes.indices.reversed() {
            let input = activations[layer]
            let layerSize = model.hiddenLayerSizes[layer]
            let weights = model.hiddenWeights[layer]
            var nextUpstream = Array(repeating: 0.0, count: input.count)
            for row in 0..<layerSize {
                guard preActivations[layer][row] > 0 else { continue }
                let delta = upstream[row]
                gradient.hiddenBiases[layer][row] = delta
                let offset = row * input.count
                for column in 0..<input.count {
                    gradient.hiddenWeights[layer][offset + column] = delta * input[column]
                    nextUpstream[column] += delta * weights[offset + column]
                }
            }
            upstream = nextUpstream
        }

        if !gradient.hiddenWeights.isEmpty {
            gradient.w1 = gradient.hiddenWeights[0]
            gradient.b1 = gradient.hiddenBiases[0]
        }
        return gradient
    }

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

    let head = actionHead(for: features, headCount: model.headCount)
    gradient.b2s[head] = 1
    let headOffset = head * model.hiddenSize
    for row in 0..<model.hiddenSize {
        gradient.w2[headOffset + row] = hidden[row]
        guard preActivation[row] > 0 else { continue }
        let upstream = model.w2[headOffset + row]
        gradient.b1[row] = upstream
        let offset = row * model.inputSize
        for column in 0..<model.inputSize {
            gradient.w1[offset + column] = upstream * features[column]
        }
    }
    return gradient
}

func actionHead(for features: [Double], headCount: Int) -> Int {
    guard headCount > 1 else { return 0 }
    let selected = features.prefix(PolicyFeatures.actionHeadCount).enumerated().max { $0.element < $1.element }?.offset ?? 0
    if headCount == PolicyFeatures.modelHeadCount {
        let playerRange = features.count >= PolicyFeatures.v4InputSize ? 4..<8 : 83..<87
        guard features.count >= playerRange.upperBound else {
            return min(max(0, selected), headCount - 1)
        }
        let playerSlice = features[playerRange]
        let player = playerSlice.enumerated().max { $0.element < $1.element }?.offset ?? 0
        return min(max(0, player * PolicyFeatures.actionHeadCount + selected), headCount - 1)
    }
    return min(max(0, selected), headCount - 1)
}

func applying(_ gradient: PolicyGradient, to model: KolkhozPolicyModel, options: Options, divisor: Double) -> (model: KolkhozPolicyModel, norm: Double, scale: Double) {
    let norm = gradient.norm() / max(1, divisor)
    let clipScale = norm > options.maxGradientNorm ? options.maxGradientNorm / norm : 1
    let step = options.learningRate * clipScale / max(1, divisor)

    if model.usesLayerStack {
        var hiddenWeights = model.hiddenWeights
        var hiddenBiases = model.hiddenBiases
        for layer in hiddenWeights.indices {
            for index in hiddenWeights[layer].indices {
                hiddenWeights[layer][index] += step * gradient.hiddenWeights[layer][index] - options.learningRate * options.l2 * hiddenWeights[layer][index]
            }
            for index in hiddenBiases[layer].indices {
                hiddenBiases[layer][index] += step * gradient.hiddenBiases[layer][index] - options.learningRate * options.l2 * hiddenBiases[layer][index]
            }
        }
        let outputWeights = model.outputWeights.indices.map { index in
            model.outputWeights[index] + step * gradient.outputWeights[index] - options.learningRate * options.l2 * model.outputWeights[index]
        }
        let b2s = model.b2s.indices.map { index in
            model.b2s[index] + step * gradient.b2s[index] - options.learningRate * options.l2 * model.b2s[index]
        }
        return (
            KolkhozPolicyModel(
                version: model.version,
                featureVersion: model.featureVersion,
                inputSize: model.inputSize,
                hiddenSize: model.hiddenSize,
                hiddenLayerSizes: model.hiddenLayerSizes,
                w1: hiddenWeights.first ?? model.w1,
                b1: hiddenBiases.first ?? model.b1,
                hiddenWeights: hiddenWeights,
                hiddenBiases: hiddenBiases,
                w2: model.w2,
                outputWeights: outputWeights,
                b2: b2s.first ?? model.b2,
                b2s: b2s,
                valueWeights: model.valueWeights,
                valueBias: model.valueBias
            ),
            norm,
            clipScale
        )
    }

    let w1 = model.w1.indices.map { index in
        model.w1[index] + step * gradient.w1[index] - options.learningRate * options.l2 * model.w1[index]
    }
    let b1 = model.b1.indices.map { index in
        model.b1[index] + step * gradient.b1[index] - options.learningRate * options.l2 * model.b1[index]
    }
    let w2 = model.w2.indices.map { index in
        model.w2[index] + step * gradient.w2[index] - options.learningRate * options.l2 * model.w2[index]
    }
    let b2s = model.b2s.indices.map { index in
        model.b2s[index] + step * gradient.b2s[index] - options.learningRate * options.l2 * model.b2s[index]
    }

    return (
        KolkhozPolicyModel(
            version: model.version,
            featureVersion: model.featureVersion,
            inputSize: model.inputSize,
            hiddenSize: model.hiddenSize,
            hiddenLayerSizes: model.hiddenLayerSizes,
            w1: w1,
            b1: b1,
            hiddenWeights: model.hiddenWeights,
            hiddenBiases: model.hiddenBiases,
            w2: w2,
            outputWeights: model.outputWeights,
            b2: b2s.first ?? model.b2,
            b2s: b2s,
            valueWeights: model.valueWeights,
            valueBias: model.valueBias
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

    if model.usesLayerStack {
        var hiddenWeights = model.hiddenWeights
        var hiddenBiases = model.hiddenBiases
        for layer in hiddenWeights.indices {
            for index in hiddenWeights[layer].indices {
                hiddenWeights[layer][index] = update(
                    value: hiddenWeights[layer][index],
                    gradient: gradient.hiddenWeights[layer][index],
                    first: &state.first.hiddenWeights[layer][index],
                    second: &state.second.hiddenWeights[layer][index]
                )
            }
            for index in hiddenBiases[layer].indices {
                hiddenBiases[layer][index] = update(
                    value: hiddenBiases[layer][index],
                    gradient: gradient.hiddenBiases[layer][index],
                    first: &state.first.hiddenBiases[layer][index],
                    second: &state.second.hiddenBiases[layer][index]
                )
            }
        }

        var outputWeights = model.outputWeights
        for index in outputWeights.indices {
            outputWeights[index] = update(
                value: outputWeights[index],
                gradient: gradient.outputWeights[index],
                first: &state.first.outputWeights[index],
                second: &state.second.outputWeights[index]
            )
        }

        var b2s = model.b2s
        for index in b2s.indices {
            b2s[index] = update(
                value: b2s[index],
                gradient: gradient.b2s[index],
                first: &state.first.b2s[index],
                second: &state.second.b2s[index]
            )
        }

        return (
            KolkhozPolicyModel(
                version: model.version,
                featureVersion: model.featureVersion,
                inputSize: model.inputSize,
                hiddenSize: model.hiddenSize,
                hiddenLayerSizes: model.hiddenLayerSizes,
                w1: hiddenWeights.first ?? model.w1,
                b1: hiddenBiases.first ?? model.b1,
                hiddenWeights: hiddenWeights,
                hiddenBiases: hiddenBiases,
                w2: model.w2,
                outputWeights: outputWeights,
                b2: b2s.first ?? model.b2,
                b2s: b2s,
                valueWeights: model.valueWeights,
                valueBias: model.valueBias
            ),
            norm,
            clipScale
        )
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

    var b2s = model.b2s
    for index in b2s.indices {
        b2s[index] = update(
            value: b2s[index],
            gradient: gradient.b2s[index],
            first: &state.first.b2s[index],
            second: &state.second.b2s[index]
        )
    }

    return (
        KolkhozPolicyModel(
            version: model.version,
            featureVersion: model.featureVersion,
            inputSize: model.inputSize,
            hiddenSize: model.hiddenSize,
            hiddenLayerSizes: model.hiddenLayerSizes,
            w1: w1,
            b1: b1,
            hiddenWeights: model.hiddenWeights,
            hiddenBiases: model.hiddenBiases,
            w2: w2,
            outputWeights: model.outputWeights,
            b2: b2s.first ?? model.b2,
            b2s: b2s,
            valueWeights: model.valueWeights,
            valueBias: model.valueBias
        ),
        norm,
        clipScale
    )
}

final class CPolicyModelStorage {
    let inputSize: Int
    let hiddenSize: Int
    let headCount: Int
    let layerCount: Int
    let layerSizes: [Int]
    var w1: [Double]
    var b1: [Double]
    var layer0Weights: [Double]
    var layer1Weights: [Double]
    var layer2Weights: [Double]
    var layer3Weights: [Double]
    var layer0Biases: [Double]
    var layer1Biases: [Double]
    var layer2Biases: [Double]
    var layer3Biases: [Double]
    var w2: [Double]
    var outputWeights: [Double]
    var b2: Double
    var b2s: [Double]

    init(_ model: KolkhozPolicyModel) {
        self.inputSize = model.inputSize
        self.hiddenSize = model.hiddenSize
        self.headCount = model.headCount
        self.layerCount = model.usesLayerStack ? min(4, model.hiddenLayerSizes.count) : 0
        self.layerSizes = Array(model.hiddenLayerSizes.prefix(4))
        self.w1 = model.w1
        self.b1 = model.b1
        let weights = Array(model.hiddenWeights.prefix(4)) + Array(repeating: [], count: max(0, 4 - model.hiddenWeights.count))
        let biases = Array(model.hiddenBiases.prefix(4)) + Array(repeating: [], count: max(0, 4 - model.hiddenBiases.count))
        self.layer0Weights = weights[0]
        self.layer1Weights = weights[1]
        self.layer2Weights = weights[2]
        self.layer3Weights = weights[3]
        self.layer0Biases = biases[0]
        self.layer1Biases = biases[1]
        self.layer2Biases = biases[2]
        self.layer3Biases = biases[3]
        self.w2 = model.w2
        self.outputWeights = model.outputWeights
        self.b2 = model.b2
        self.b2s = model.b2s
    }

    func trainedModel(from base: KolkhozPolicyModel, valueWeights: [Double]? = nil) -> KolkhozPolicyModel {
        let trainedLayerWeights = [layer0Weights, layer1Weights, layer2Weights, layer3Weights]
        let trainedLayerBiases = [layer0Biases, layer1Biases, layer2Biases, layer3Biases]
        let trainedW1 = layerCount > 0 ? layer0Weights : w1
        let trainedB1 = layerCount > 0 ? layer0Biases : b1
        return KolkhozPolicyModel(
            version: base.version,
            featureVersion: base.featureVersion,
            inputSize: base.inputSize,
            hiddenSize: base.hiddenSize,
            hiddenLayerSizes: layerCount > 0 ? layerSizes : [],
            w1: trainedW1,
            b1: trainedB1,
            hiddenWeights: layerCount > 0 ? Array(trainedLayerWeights.prefix(layerCount)) : [],
            hiddenBiases: layerCount > 0 ? Array(trainedLayerBiases.prefix(layerCount)) : [],
            w2: w2,
            outputWeights: layerCount > 0 ? outputWeights : [],
            b2: b2s.first ?? b2,
            b2s: b2s,
            valueWeights: valueWeights ?? base.valueWeights,
            valueBias: base.valueBias
        )
    }

    func withBuffer<R>(_ body: (KCPolicyModelBuffer) -> R) -> R {
        let sizes = (
            Int32(layerSizes.indices.contains(0) ? layerSizes[0] : 0),
            Int32(layerSizes.indices.contains(1) ? layerSizes[1] : 0),
            Int32(layerSizes.indices.contains(2) ? layerSizes[2] : 0),
            Int32(layerSizes.indices.contains(3) ? layerSizes[3] : 0)
        )
        return w1.withUnsafeMutableBufferPointer { w1Pointer in
            b1.withUnsafeMutableBufferPointer { b1Pointer in
                layer0Weights.withUnsafeMutableBufferPointer { layer0Pointer in
                    layer1Weights.withUnsafeMutableBufferPointer { layer1Pointer in
                        layer2Weights.withUnsafeMutableBufferPointer { layer2Pointer in
                            layer3Weights.withUnsafeMutableBufferPointer { layer3Pointer in
                                layer0Biases.withUnsafeMutableBufferPointer { bias0Pointer in
                                    layer1Biases.withUnsafeMutableBufferPointer { bias1Pointer in
                                        layer2Biases.withUnsafeMutableBufferPointer { bias2Pointer in
                                            layer3Biases.withUnsafeMutableBufferPointer { bias3Pointer in
                                                w2.withUnsafeMutableBufferPointer { w2Pointer in
                                                    outputWeights.withUnsafeMutableBufferPointer { outputPointer in
                                                        b2s.withUnsafeMutableBufferPointer { b2sPointer in
                                                            withUnsafeMutablePointer(to: &b2) { b2Pointer in
                                                                let useLayers = layerCount > 0
                                                                let buffer = KCPolicyModelBuffer(
                                                                    input_size: Int32(inputSize),
                                                                    hidden_size: Int32(hiddenSize),
                                                                    layer_count: Int32(layerCount),
                                                                    layer_sizes: sizes,
                                                                    head_count: Int32(headCount),
                                                                    w1: w1Pointer.baseAddress,
                                                                    b1: b1Pointer.baseAddress,
                                                                    layer_weights: (
                                                                        useLayers ? layer0Pointer.baseAddress : nil,
                                                                        useLayers && layerCount > 1 ? layer1Pointer.baseAddress : nil,
                                                                        useLayers && layerCount > 2 ? layer2Pointer.baseAddress : nil,
                                                                        useLayers && layerCount > 3 ? layer3Pointer.baseAddress : nil
                                                                    ),
                                                                    layer_biases: (
                                                                        useLayers ? bias0Pointer.baseAddress : nil,
                                                                        useLayers && layerCount > 1 ? bias1Pointer.baseAddress : nil,
                                                                        useLayers && layerCount > 2 ? bias2Pointer.baseAddress : nil,
                                                                        useLayers && layerCount > 3 ? bias3Pointer.baseAddress : nil
                                                                    ),
                                                                    w2: w2Pointer.baseAddress,
                                                                    output_weights: useLayers ? outputPointer.baseAddress : nil,
                                                                    b2: b2Pointer,
                                                                    b2s: b2sPointer.baseAddress
                                                                )
                                                                return body(buffer)
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

func trainWithDirectCEngine(
    model: KolkhozPolicyModel,
    opponentModel: KolkhozPolicyModel?,
    options: Options,
    reward: RewardWeights,
    valueWeights: inout [Double]
) throws -> (model: KolkhozPolicyModel, result: KCPolicyGradientResult) {
    let optimizer = options.optimizer.lowercased()
    let usePPOAdam = optimizer == "ppo-adam" || optimizer == "adam"
    let usesShapedRewards = options.scoreDeltaWeight != 0
        || options.marginDeltaWeight != 0
        || options.workDeltaWeight != 0
        || options.claimDeltaWeight != 0
        || options.ownRequisitionWeight != 0
    guard (optimizer == "sgd" || optimizer == "ppo" || usePPOAdam),
          !options.seatBalancedUpdate,
          (optimizer != "sgd" || !usesShapedRewards) else {
        throw TrainerError.incompatibleModel("--engine c-direct supports PPO/SGD self-play or frozen-opponent paired-baseline training; shaped rewards require PPO/Adam. Use --engine swift for seat-balanced training.")
    }

    let modelStorage = CPolicyModelStorage(model)
    let opponentStorage = opponentModel.map(CPolicyModelStorage.init)
    var result = KCPolicyGradientResult()
    if model.valueWeights.count == cValueInputSize {
        valueWeights = model.valueWeights
    } else if valueWeights.count != cValueInputSize {
        valueWeights = Array(repeating: 0, count: cValueInputSize)
    }
    let trainingSeats = options.trainingSeats ?? []
    let cTrainingSeats = (
        Int32(trainingSeats.indices.contains(0) ? trainingSeats[0] : -1),
        Int32(trainingSeats.indices.contains(1) ? trainingSeats[1] : -1),
        Int32(trainingSeats.indices.contains(2) ? trainingSeats[2] : -1),
        Int32(trainingSeats.indices.contains(3) ? trainingSeats[3] : -1)
    )

    let status = valueWeights.withUnsafeMutableBufferPointer { valueWeightsPointer in
        modelStorage.withBuffer { cModel in
            func run(opponentBuffer: KCPolicyModelBuffer, hasOpponent: Bool) -> Int32 {
                let config = KCPolicyGradientConfig(
                    episodes: Int32(options.episodes),
                    batch_size: Int32(options.batchSize),
                    seed: options.seed,
                    learning_rate: options.learningRate,
                    temperature: options.temperature,
                    max_gradient_norm: options.maxGradientNorm,
                    l2: options.l2,
                    win_weight: reward.win,
                    strict_weight: reward.strict,
                    rank_weight: reward.rank,
                    margin_weight: reward.margin,
                    score_delta_weight: options.scoreDeltaWeight,
                    margin_delta_weight: options.marginDeltaWeight,
                    work_delta_weight: options.workDeltaWeight,
                    claim_delta_weight: options.claimDeltaWeight,
                    own_requisition_weight: options.ownRequisitionWeight,
                    thread_count: Int32(options.cThreadCount),
                    greedy_sample_rate: options.greedySampleRate,
                    advantage_baseline_beta: options.advantageBaselineBeta,
                    advantage_clip: options.advantageClip,
                    value_learning_rate: options.valueLearningRate,
                    value_weights: valueWeightsPointer.baseAddress,
                    training_seat_count: Int32(trainingSeats.count),
                    training_seats: cTrainingSeats,
                    round_curriculum: options.roundCurriculum,
                    round_plot_cards: Int32(options.roundPlotCards),
                    round_famine_rate: options.roundFamineRate,
                    has_opponent_model: hasOpponent,
                    opponent_is_heuristic: options.opponentMode == "heuristic",
                    paired_baseline: options.pairedBaseline,
                    freeze_hidden: options.freezeHidden,
                    per_transition_value_advantages: options.perTransitionValueAdvantages,
                    phase_balanced_ppo: options.phaseBalancedPPO,
                    use_ppo: optimizer != "sgd",
                    use_adam: usePPOAdam,
                    imitation_weight: options.imitationWeight,
                    imitation_trump_weight: options.imitationHeadWeights[0],
                    imitation_swap_weight: options.imitationHeadWeights[1],
                    imitation_play_weight: options.imitationHeadWeights[2],
                    imitation_assign_weight: options.imitationHeadWeights[3],
                    teacher_forcing_rate: options.teacherForcingRate,
                    ppo_epochs: Int32(options.ppoEpochs),
                    ppo_minibatch_size: Int32(options.ppoMinibatchSize),
                    ppo_clip: options.ppoClip,
                    entropy_weight: options.entropyWeight,
                    adam_beta1: options.adamBeta1,
                    adam_beta2: options.adamBeta2,
                    adam_epsilon: options.adamEpsilon,
                    opponent_model: opponentBuffer
                )
                return kc_train_policy_gradient(cModel, config, &result)
            }

            guard let opponentStorage else {
                let emptyOpponent = KCPolicyModelBuffer(
                    input_size: 0,
                    hidden_size: 0,
                    layer_count: 0,
                    layer_sizes: (0, 0, 0, 0),
                    head_count: 0,
                    w1: nil,
                    b1: nil,
                    layer_weights: (nil, nil, nil, nil),
                    layer_biases: (nil, nil, nil, nil),
                    w2: nil,
                    output_weights: nil,
                    b2: nil,
                    b2s: nil
                )
                return run(opponentBuffer: emptyOpponent, hasOpponent: false)
            }

            return opponentStorage.withBuffer { opponentBuffer in
                run(opponentBuffer: opponentBuffer, hasOpponent: true)
            }
        }
    }

    guard status == 0 else {
        throw TrainerError.incompatibleModel("C direct trainer failed with status \(status)")
    }

    print(
            "pg_c_direct episodes=\(result.episodes) actions=\(result.actions) batches=\(result.batches) " +
            "optimizer=\(optimizer) ppo_epochs=\(optimizer != "sgd" ? options.ppoEpochs : 0) ppo_minibatch=\(optimizer != "sgd" ? options.ppoMinibatchSize : 0) entropy_weight=\(String(format: "%.4f", optimizer != "sgd" ? options.entropyWeight : 0)) phase_balanced=\(options.phaseBalancedPPO ? 1 : 0) imitation_weight=\(String(format: "%.3f", options.imitationWeight)) imitation_heads=\(formatImitationHeadWeights(options.imitationHeadWeights)) teacher_forcing=\(String(format: "%.2f", options.teacherForcingRate)) threads=\(optimizer != "sgd" ? 1 : options.cThreadCount) " +
            "greedy_sample_rate=\(String(format: "%.2f", options.greedySampleRate)) winner_rate=\(String(format: "%.3f", result.top_rate)) avg_rank=\(String(format: "%.3f", result.average_rank)) " +
            "avg_margin=\(String(format: "%.3f", result.average_margin)) avg_reward=\(String(format: "%.3f", result.average_reward)) advantage=\(String(format: "%.3f", result.average_advantage)) " +
            "grad_norm=\(String(format: "%.3f", result.last_gradient_norm)) clip=\(String(format: "%.3f", result.last_clip_scale)) " +
            "ppo_kl=\(String(format: "%.5f", result.average_ppo_kl)) ppo_abs_kl=\(String(format: "%.5f", result.average_ppo_abs_kl)) ppo_entropy=\(String(format: "%.3f", result.average_ppo_entropy)) " +
            "ppo_clip_frac=\(String(format: "%.3f", result.average_ppo_clip_fraction)) " +
            "checksum=\(result.checksum) weight_checksum=\(String(format: "%.6f", result.weight_checksum))"
    )

    return (
        modelStorage.trainedModel(from: model, valueWeights: valueWeights),
        result
    )
}

func batchSummary(from result: KCPolicyGradientResult) -> BatchSummary {
    BatchSummary(
        episode: Int(result.episodes),
        actions: Int(result.actions),
        gradientNorm: result.last_gradient_norm,
        scale: result.last_clip_scale,
        topRate: result.top_rate,
        averageRank: result.average_rank,
        averageMargin: result.average_margin,
        averageReward: result.average_reward,
        averageAdvantage: result.average_advantage,
        averageShapedReward: 0,
        averagePPOKL: result.average_ppo_kl,
        averagePPOAbsKL: result.average_ppo_abs_kl,
        averagePPOEntropy: result.average_ppo_entropy,
        averagePPOClipFraction: result.average_ppo_clip_fraction
    )
}

func addPolicyGradientResult(_ result: KCPolicyGradientResult, to aggregate: inout KCPolicyGradientResult) {
    let previousEpisodes = aggregate.episodes
    let combinedEpisodes = previousEpisodes + result.episodes
    if combinedEpisodes > 0 {
        let previousWeight = Double(previousEpisodes)
        let resultWeight = Double(result.episodes)
        let combinedWeight = Double(combinedEpisodes)
        aggregate.top_rate = (aggregate.top_rate * previousWeight + result.top_rate * resultWeight) / combinedWeight
        aggregate.average_rank = (aggregate.average_rank * previousWeight + result.average_rank * resultWeight) / combinedWeight
        aggregate.average_margin = (aggregate.average_margin * previousWeight + result.average_margin * resultWeight) / combinedWeight
        aggregate.average_reward = (aggregate.average_reward * previousWeight + result.average_reward * resultWeight) / combinedWeight
        aggregate.average_advantage = (aggregate.average_advantage * previousWeight + result.average_advantage * resultWeight) / combinedWeight
        aggregate.average_ppo_kl = (aggregate.average_ppo_kl * previousWeight + result.average_ppo_kl * resultWeight) / combinedWeight
        aggregate.average_ppo_abs_kl = (aggregate.average_ppo_abs_kl * previousWeight + result.average_ppo_abs_kl * resultWeight) / combinedWeight
        aggregate.average_ppo_entropy = (aggregate.average_ppo_entropy * previousWeight + result.average_ppo_entropy * resultWeight) / combinedWeight
        aggregate.average_ppo_clip_fraction = (aggregate.average_ppo_clip_fraction * previousWeight + result.average_ppo_clip_fraction * resultWeight) / combinedWeight
    }
    aggregate.episodes = combinedEpisodes
    aggregate.actions += result.actions
    aggregate.batches += result.batches
    aggregate.checksum = aggregate.checksum &+ result.checksum
    aggregate.last_gradient_norm = result.last_gradient_norm
    aggregate.last_clip_scale = result.last_clip_scale
    aggregate.weight_checksum = result.weight_checksum
}

func trainWithDirectCEngineLeague(
    model: KolkhozPolicyModel,
    opponentModels: [KolkhozPolicyModel],
    options: Options,
    reward: RewardWeights
) throws -> (model: KolkhozPolicyModel, result: KCPolicyGradientResult) {
    var valueWeights = Array(repeating: 0.0, count: cValueInputSize)
    guard !opponentModels.isEmpty else {
        return try trainWithDirectCEngine(
            model: model,
            opponentModel: nil,
            options: options,
            reward: reward,
            valueWeights: &valueWeights
        )
    }

    var current = model
    var dynamicOpponents = opponentModels
    var aggregate = KCPolicyGradientResult()
    let chunkEpisodes = options.valueLearningRate > 0
        ? max(1, min(options.episodes, options.batchSize * 8))
        : max(1, options.batchSize)
    let maxSelfSnapshots = 8
    var episodeOffset = 0
    var chunkIndex = 0
    while episodeOffset < options.episodes {
        var chunkOptions = options
        chunkOptions.episodes = min(chunkEpisodes, options.episodes - episodeOffset)
        chunkOptions.seed = options.seed + UInt64(episodeOffset)
        let preChunkSnapshot = current
        let opponent = dynamicOpponents[chunkIndex % dynamicOpponents.count]
        let trained = try trainWithDirectCEngine(
            model: current,
            opponentModel: opponent,
            options: chunkOptions,
            reward: reward,
            valueWeights: &valueWeights
        )
        current = trained.model
        addPolicyGradientResult(trained.result, to: &aggregate)
        dynamicOpponents.append(preChunkSnapshot)
        let maxOpponentCount = opponentModels.count + maxSelfSnapshots
        if dynamicOpponents.count > maxOpponentCount {
            dynamicOpponents.remove(at: opponentModels.count)
        }
        episodeOffset += chunkOptions.episodes
        chunkIndex += 1
    }

    print(
        "pg_c_direct_league chunks=\(chunkIndex) fixed_opponents=\(opponentModels.count) self_snapshots=\(dynamicOpponents.count - opponentModels.count) episodes=\(aggregate.episodes) " +
            "winner_rate=\(String(format: "%.3f", aggregate.top_rate)) avg_rank=\(String(format: "%.3f", aggregate.average_rank)) " +
            "avg_margin=\(String(format: "%.3f", aggregate.average_margin)) avg_reward=\(String(format: "%.3f", aggregate.average_reward)) advantage=\(String(format: "%.3f", aggregate.average_advantage)) " +
            "weight_checksum=\(String(format: "%.6f", aggregate.weight_checksum))"
    )

    return (current, aggregate)
}

func trainWithDirectCEngineSelected(
    model: KolkhozPolicyModel,
    opponentModel: KolkhozPolicyModel?,
    options: Options,
    reward: RewardWeights,
    validationBaselineModel: KolkhozPolicyModel?
) throws -> (model: KolkhozPolicyModel, result: KCPolicyGradientResult) {
    let chunkEpisodes = max(1, min(options.checkpointEvery, options.episodes))
    var current = model
    var bestModel = model
    var bestValidationScore = -Double.infinity
    var aggregate = KCPolicyGradientResult()
    var valueWeights = model.valueWeights.count == cValueInputSize
        ? model.valueWeights
        : Array(repeating: 0.0, count: cValueInputSize)
    let validationURL = validationBestURL(
        outputPath: options.outputPath,
        validationOutputPath: options.validationOutputPath
    )

    var episodeOffset = 0
    while episodeOffset < options.episodes {
        var chunkOptions = options
        chunkOptions.episodes = min(chunkEpisodes, options.episodes - episodeOffset)
        chunkOptions.seed = options.seed + UInt64(episodeOffset)
        let trained = try trainWithDirectCEngine(
            model: current,
            opponentModel: opponentModel,
            options: chunkOptions,
            reward: reward,
            valueWeights: &valueWeights
        )
        current = trained.model
        addPolicyGradientResult(trained.result, to: &aggregate)
        episodeOffset += chunkOptions.episodes

        let checkpoint = checkpointURL(outputPath: options.outputPath, episode: episodeOffset)
        try FileManager.default.createDirectory(at: checkpoint.deletingLastPathComponent(), withIntermediateDirectories: true)
        try current.save(to: checkpoint)
        print("checkpoint \(checkpoint.path)")

        let validation = try validateModel(
            current,
            baselineModel: validationBaselineModel,
            seeds: options.validationSeeds,
            gamesPerSeat: options.validationGamesPerSeat
        )
        print(
            "validation episode=\(episodeOffset) score=\(String(format: "%.4f", validation.score)) samples=\(validation.samples) top_delta=\(String(format: "%.4f", validation.topDelta)) strict_delta=\(String(format: "%.4f", validation.strictDelta)) rank_delta=\(String(format: "%.4f", validation.rankDelta)) margin_delta=\(String(format: "%.4f", validation.marginDelta)) worst_top=\(String(format: "%.4f", validation.worstSeatTop)) worst_rank=\(String(format: "%.4f", validation.worstSeatRank)) worst_margin=\(String(format: "%.4f", validation.worstSeatMargin))"
        )
        let gateStatus = validationGateStatus(validation, options: options)
        print("validation_gate episode=\(episodeOffset) status=\(gateStatus)")
        if gateStatus == "pass" && validation.score > bestValidationScore {
            bestValidationScore = validation.score
            bestModel = current
            try FileManager.default.createDirectory(at: validationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bestModel.save(to: validationURL)
            print("validation_best \(validationURL.path)")
        }
    }

    print(
        "pg_c_direct_selected chunks=\((options.episodes + chunkEpisodes - 1) / chunkEpisodes) episodes=\(aggregate.episodes) " +
            "best_validation_score=\(String(format: "%.4f", bestValidationScore)) weight_checksum=\(String(format: "%.6f", aggregate.weight_checksum))"
    )
    return (bestValidationScore.isFinite ? bestModel : current, aggregate)
}

func writeDirectCEngineArtifacts(
    trained: KolkhozPolicyModel,
    result: KCPolicyGradientResult,
    options: Options,
    validationBaselineModel: KolkhozPolicyModel?
) throws {
    let outputURL = URL(fileURLWithPath: options.outputPath)
    try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try trained.save(to: outputURL)
    print("exported \(options.outputPath)")

    if let historyPath = options.historyPath {
        try writeHistory([batchSummary(from: result)], to: historyPath)
        print("history \(historyPath)")
    }

    let validationEnabled = !options.validationSeeds.isEmpty && options.validationGamesPerSeat > 0
    if validationEnabled {
        let validation = try validateModel(
            trained,
            baselineModel: validationBaselineModel,
            seeds: options.validationSeeds,
            gamesPerSeat: options.validationGamesPerSeat
        )
        print(
            "validation episode=\(options.episodes) score=\(String(format: "%.4f", validation.score)) samples=\(validation.samples) top_delta=\(String(format: "%.4f", validation.topDelta)) strict_delta=\(String(format: "%.4f", validation.strictDelta)) rank_delta=\(String(format: "%.4f", validation.rankDelta)) margin_delta=\(String(format: "%.4f", validation.marginDelta)) worst_top=\(String(format: "%.4f", validation.worstSeatTop)) worst_rank=\(String(format: "%.4f", validation.worstSeatRank)) worst_margin=\(String(format: "%.4f", validation.worstSeatMargin))"
        )
        let gateStatus = validationGateStatus(validation, options: options)
        print("validation_gate episode=\(options.episodes) status=\(gateStatus)")
        if gateStatus == "pass" {
            let validationURL = validationBestURL(
                outputPath: options.outputPath,
                validationOutputPath: options.validationOutputPath
            )
            try FileManager.default.createDirectory(at: validationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try trained.save(to: validationURL)
            print("validation_best \(validationURL.path)")
        }
    }
}

enum PolicyFeatures {
    static let version = 5
    static let inputSize = 200
    static let v4Version = 4
    static let v4InputSize = 200
    static let v3Version = 3
    static let v3InputSize = 95
    static let v2Version = 2
    static let v2InputSize = 83
    static let actionHeadCount = 4
    static let modelHeadCount = 16
    static let legacyVersion = 1
    static let legacyInputSize = 34

    static func isSupported(featureVersion: Int, inputSize: Int) -> Bool {
        (featureVersion == version && inputSize == Self.inputSize)
            || (featureVersion == v4Version && inputSize == v4InputSize)
            || (featureVersion == v3Version && inputSize == v3InputSize)
            || (featureVersion == v2Version && inputSize == v2InputSize)
            || (featureVersion == legacyVersion && inputSize == legacyInputSize)
    }

    static func trump(state: KolkhozState, playerID: Int, suit: Suit, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .trump, suit: suit, card: nil, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
    }

    static func swap(state: KolkhozState, playerID: Int, handCard: Card, plotCard: Card, zone: PlotCardZone, featureVersion: Int = version) -> [Double] {
        features(
            state: state,
            playerID: playerID,
            action: .swap,
            suit: plotCard.suit,
            card: plotCard,
            handCard: handCard,
            zone: zone,
            swapDelta: Double(plotCard.value - handCard.value) / 13,
            featureVersion: featureVersion
        )
    }

    static func noSwap(state: KolkhozState, playerID: Int, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .swap, suit: nil, card: nil, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
    }

    static func playCard(state: KolkhozState, playerID: Int, card: Card, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .play, suit: card.suit, card: card, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
    }

    static func assign(state: KolkhozState, playerID: Int, suit: Suit, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .assign, suit: suit, card: nil, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
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
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        zone: PlotCardZone?,
        swapDelta: Double,
        featureVersion: Int
    ) -> [Double] {
        if featureVersion == version {
            return v5Features(
                state: state,
                playerID: playerID,
                action: action,
                suit: suit,
                card: card,
                handCard: handCard,
                zone: zone,
                swapDelta: swapDelta
            )
        }
        if featureVersion == v4Version {
            return v4Features(
                state: state,
                playerID: playerID,
                action: action,
                suit: suit,
                card: card,
                handCard: handCard,
                zone: zone,
                swapDelta: swapDelta
            )
        }

        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = suit.map { state.workHours[$0, default: 0] } ?? 0
        let afterWork = currentWork + trickWork
        let plotCards = player.plot.hidden + player.plot.revealed
        let suitPlotCount = suit.map { target in plotCards.filter { $0.suit == target }.count } ?? 0
        let hiddenSuitCount = suit.map { target in player.plot.hidden.filter { $0.suit == target }.count } ?? 0
        let revealedJob = suit.flatMap { state.revealedJobs[$0]?.value } ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(suit.map(suitIndex) ?? -1, count: 4))
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

        if featureVersion == legacyVersion {
            precondition(values.count == legacyInputSize, "Kolkhoz policy legacy feature size changed")
            return values
        }

        appendV2Features(
            to: &values,
            state: state,
            playerID: playerID,
            suit: suit,
            card: card,
            handCard: handCard,
            leadSuit: leadSuit
        )
        if featureVersion == v2Version {
            precondition(values.count == v2InputSize, "Kolkhoz policy v2 feature size changed")
            return values
        }

        appendV3Features(to: &values, state: state, playerID: playerID)

        precondition(values.count == v3InputSize, "Kolkhoz policy v3 feature size changed")
        return values
    }

    static func v5Features(
        state: KolkhozState,
        playerID: Int,
        action: Action,
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        zone: PlotCardZone?,
        swapDelta: Double
    ) -> [Double] {
        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = suit.map { state.workHours[$0, default: 0] } ?? 0
        let afterWork = currentWork + trickWork
        let ownVisible = visibleScore(for: playerID, state: state)
        let ownKnownScore = knownScore(for: playerID, state: state)
        let bestOpponentVisible = state.players
            .filter { $0.id != playerID }
            .map { visibleScore(for: $0.id, state: state) }
            .max() ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(playerID, count: 4))
        values.append(contentsOf: oneHot(suit.map(suitIndex) ?? -1, count: 4))
        values.append(contentsOf: oneHot(card.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(card?.value ?? 0) / 13)
        values.append(Double(handCard?.value ?? 0) / 13)
        values.append(swapDelta)
        values.append(zone == .hidden ? 1 : 0)
        values.append(zone == .revealed ? 1 : 0)
        values.append(Double(state.year) / 5)
        values.append(state.isFamine ? 1 : 0)
        values.append(Double(state.trickCount) / 4)
        values.append(Double(state.currentTrick.count) / 4)
        values.append(Double((playerID - state.lead + 4) % 4) / 3)
        values.append(Double((playerID - state.trumpSelector + 4) % 4) / 3)
        values.append(card?.suit == leadSuit ? 1 : 0)
        values.append(card?.suit == state.trump ? 1 : 0)
        values.append(wouldCurrentlyWin(card, state: state) ? 1 : 0)
        values.append(Double(currentWork) / 40)
        values.append(Double(max(0, 40 - currentWork)) / 40)
        values.append(afterWork >= 40 ? 1 : 0)
        values.append(Double(suit.flatMap { state.revealedJobs[$0]?.value } ?? 0) / 5)
        values.append(suit.map { state.claimedJobs.contains($0) } ?? false ? 1 : 0)
        values.append(Double(player.hand.count) / 5)
        values.append(Double(revealedPlotCount(for: player)) / 16)
        values.append(Double(hiddenPlotCount(for: player)) / 16)
        values.append(Double(player.plot.medals + player.medals) / 20)
        values.append(Double(ownVisible) / 100)
        values.append(Double(ownKnownScore) / 100)
        values.append(Double(bestOpponentVisible) / 100)
        values.append(Double(bestOpponentVisible) / 100)
        values.append(Double(ownKnownScore - bestOpponentVisible) / 100)
        values.append(Double(ownVisible - bestOpponentVisible) / 100)
        values.append(player.hasWonTrickThisYear ? 1 : 0)
        values.append(player.brigadeLeader ? 1 : 0)
        values.append(state.variants.nomenclature ? 1 : 0)
        values.append(state.variants.allowSwap ? 1 : 0)
        values.append(state.variants.northernStyle ? 1 : 0)
        values.append(state.variants.miceVariant ? 1 : 0)
        values.append(state.variants.ordenNachalniku ? 1 : 0)
        values.append(state.variants.medalsCount ? 1 : 0)
        values.append(state.variants.accumulateJobs ? 1 : 0)
        values.append(state.variants.heroOfSovietUnion ? 1 : 0)
        values.append(state.variants.deckType == 36 ? 1 : 0)

        for seat in 0..<4 {
            guard state.players.indices.contains(seat) else {
                values.append(contentsOf: Array(repeating: 0.0, count: 9))
                continue
            }
            let seatPlayer = state.players[seat]
            values.append(Double(seatPlayer.hand.count) / 5)
            values.append(Double(revealedPlotCount(for: seatPlayer)) / 16)
            values.append(Double(hiddenPlotCount(for: seatPlayer)) / 16)
            values.append(Double(seatPlayer.plot.medals + seatPlayer.medals) / 20)
            values.append(seatPlayer.hasWonTrickThisYear ? 1 : 0)
            values.append(seatPlayer.brigadeLeader ? 1 : 0)
            values.append(Double(visibleScore(for: seat, state: state)) / 100)
            values.append(Double(seat == playerID ? knownScore(for: seat, state: state) : visibleScore(for: seat, state: state)) / 100)
            values.append(Double(seat == playerID ? seatPlayer.hand.map(\.value).max() ?? 0 : 0) / 13)
            values.append(Double(seat == playerID ? seatPlayer.hand.map(\.value).min() ?? 0 : 0) / 13)
        }

        for target in Suit.allCases {
            values.append(Double(state.workHours[target, default: 0]) / 40)
            values.append(Double(max(0, 40 - state.workHours[target, default: 0])) / 40)
            values.append(Double(state.revealedJobs[target]?.value ?? 0) / 5)
            values.append(state.claimedJobs.contains(target) ? 1 : 0)
            let ownCards = player.hand.filter { $0.suit == target }
            values.append(Double(ownCards.count) / 5)
            values.append(Double(ownCards.map(\.value).max() ?? 0) / 13)
            values.append(Double(ownCards.map(\.value).min() ?? 0) / 13)
            values.append(Double(revealedPlotCount(for: player, suit: target)) / 8)
            values.append(Double(hiddenPlotCount(for: player, suit: target)) / 8)
            values.append(Double(state.players.reduce(0) { $0 + revealedPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.players.reduce(0) { $0 + hiddenPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.currentTrick.filter { $0.card.suit == target }.count + state.lastTrick.filter { $0.card.suit == target }.count) / 8)
        }

        appendTrickFeatures(to: &values, plays: state.currentTrick)
        appendTrickFeatures(to: &values, plays: state.lastTrick)
        precondition(values.count == inputSize, "Kolkhoz policy v5 feature size changed")
        return values
    }

    static func v4Features(
        state: KolkhozState,
        playerID: Int,
        action: Action,
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        zone: PlotCardZone?,
        swapDelta: Double
    ) -> [Double] {
        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = suit.map { state.workHours[$0, default: 0] } ?? 0
        let afterWork = currentWork + trickWork
        let ownVisible = visibleScore(for: playerID, state: state)
        let ownFinal = gameFinalScore(for: playerID, state: state)
        let bestOpponentVisible = state.players
            .filter { $0.id != playerID }
            .map { visibleScore(for: $0.id, state: state) }
            .max() ?? 0
        let bestOpponentFinal = state.players
            .filter { $0.id != playerID }
            .map { gameFinalScore(for: $0.id, state: state) }
            .max() ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(playerID, count: 4))
        values.append(contentsOf: oneHot(suit.map(suitIndex) ?? -1, count: 4))
        values.append(contentsOf: oneHot(card.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(card?.value ?? 0) / 13)
        values.append(Double(handCard?.value ?? 0) / 13)
        values.append(swapDelta)
        values.append(zone == .hidden ? 1 : 0)
        values.append(zone == .revealed ? 1 : 0)
        values.append(Double(state.year) / 5)
        values.append(state.isFamine ? 1 : 0)
        values.append(Double(state.trickCount) / 4)
        values.append(Double(state.currentTrick.count) / 4)
        values.append(Double((playerID - state.lead + 4) % 4) / 3)
        values.append(Double((playerID - state.trumpSelector + 4) % 4) / 3)
        values.append(card?.suit == leadSuit ? 1 : 0)
        values.append(card?.suit == state.trump ? 1 : 0)
        values.append(wouldCurrentlyWin(card, state: state) ? 1 : 0)
        values.append(Double(currentWork) / 40)
        values.append(Double(max(0, 40 - currentWork)) / 40)
        values.append(afterWork >= 40 ? 1 : 0)
        values.append(Double(suit.flatMap { state.revealedJobs[$0]?.value } ?? 0) / 5)
        values.append(suit.map { state.claimedJobs.contains($0) } ?? false ? 1 : 0)
        values.append(Double(player.hand.count) / 5)
        values.append(Double(revealedPlotCount(for: player)) / 16)
        values.append(Double(hiddenPlotCount(for: player)) / 16)
        values.append(Double(player.plot.medals + player.medals) / 20)
        values.append(Double(ownVisible) / 100)
        values.append(Double(ownFinal) / 100)
        values.append(Double(bestOpponentVisible) / 100)
        values.append(Double(bestOpponentFinal) / 100)
        values.append(Double(ownFinal - bestOpponentFinal) / 100)
        values.append(Double(ownVisible - bestOpponentVisible) / 100)
        values.append(player.hasWonTrickThisYear ? 1 : 0)
        values.append(player.brigadeLeader ? 1 : 0)
        values.append(state.variants.nomenclature ? 1 : 0)
        values.append(state.variants.allowSwap ? 1 : 0)
        values.append(state.variants.northernStyle ? 1 : 0)
        values.append(state.variants.miceVariant ? 1 : 0)
        values.append(state.variants.ordenNachalniku ? 1 : 0)
        values.append(state.variants.medalsCount ? 1 : 0)
        values.append(state.variants.accumulateJobs ? 1 : 0)
        values.append(state.variants.heroOfSovietUnion ? 1 : 0)
        values.append(state.variants.deckType == 36 ? 1 : 0)

        for seat in 0..<4 {
            guard state.players.indices.contains(seat) else {
                values.append(contentsOf: Array(repeating: 0.0, count: 10))
                continue
            }
            let seatPlayer = state.players[seat]
            values.append(Double(seatPlayer.hand.count) / 5)
            values.append(Double(revealedPlotCount(for: seatPlayer)) / 16)
            values.append(Double(hiddenPlotCount(for: seatPlayer)) / 16)
            values.append(Double(seatPlayer.plot.medals + seatPlayer.medals) / 20)
            values.append(seatPlayer.hasWonTrickThisYear ? 1 : 0)
            values.append(seatPlayer.brigadeLeader ? 1 : 0)
            values.append(Double(visibleScore(for: seat, state: state)) / 100)
            values.append(Double(gameFinalScore(for: seat, state: state)) / 100)
            values.append(Double(seatPlayer.hand.map(\.value).max() ?? 0) / 13)
            values.append(Double(seatPlayer.hand.map(\.value).min() ?? 0) / 13)
        }

        for target in Suit.allCases {
            values.append(Double(state.workHours[target, default: 0]) / 40)
            values.append(Double(max(0, 40 - state.workHours[target, default: 0])) / 40)
            values.append(Double(state.revealedJobs[target]?.value ?? 0) / 5)
            values.append(state.claimedJobs.contains(target) ? 1 : 0)
            values.append(Double(player.hand.filter { $0.suit == target }.count) / 5)
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).max() ?? 0) / 13)
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).min() ?? 0) / 13)
            values.append(Double(revealedPlotCount(for: player, suit: target)) / 8)
            values.append(Double(hiddenPlotCount(for: player, suit: target)) / 8)
            values.append(Double(state.players.reduce(0) { $0 + revealedPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.players.reduce(0) { $0 + hiddenPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.currentTrick.filter { $0.card.suit == target }.count + state.lastTrick.filter { $0.card.suit == target }.count) / 8)
        }

        appendTrickFeatures(to: &values, plays: state.currentTrick)
        appendTrickFeatures(to: &values, plays: state.lastTrick)
        precondition(values.count == inputSize, "Kolkhoz policy v4 feature size changed")
        return values
    }

    static func appendV2Features(
        to values: inout [Double],
        state: KolkhozState,
        playerID: Int,
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        leadSuit: Suit?
    ) {
        let player = state.players[playerID]
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target }.count) / 5)
        }
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target && $0.value >= 11 }.count) / 5)
        }
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).max() ?? 0) / 13)
        }
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).min() ?? 0) / 13)
        }
        for target in Suit.allCases {
            values.append(Double(player.plot.revealed.filter { $0.suit == target }.count) / 8)
        }
        for target in Suit.allCases {
            values.append(Double(player.plot.hidden.filter { $0.suit == target }.count) / 8)
        }
        for target in Suit.allCases {
            values.append(Double(state.revealedJobs[target]?.value ?? 0) / 5)
        }
        for target in Suit.allCases {
            values.append(Double(state.workHours[target, default: 0]) / 40)
        }
        for target in Suit.allCases {
            values.append(state.claimedJobs.contains(target) ? 1 : 0)
        }
        values.append(contentsOf: oneHot(handCard.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(handCard?.value ?? 0) / 13)
        values.append(card?.suit == state.trump ? 1 : 0)
        values.append(card?.suit == leadSuit ? 1 : 0)
        values.append(Double(state.players[playerID].plot.medals + state.players[playerID].medals) / 20)
        values.append(Double(state.currentTrick.count) / 4)
        let ownScore = finalScore(for: playerID, state: state)
        let bestOpponent = state.players
            .filter { $0.id != playerID }
            .map { finalScore(for: $0.id, state: state) }
            .max() ?? 0
        values.append(Double(ownScore) / 100)
        values.append(Double(bestOpponent) / 100)
        values.append(Double(ownScore - bestOpponent) / 100)
        values.append(suit == state.trump ? 1 : 0)
    }

    static func appendV3Features(to values: inout [Double], state: KolkhozState, playerID: Int) {
        values.append(contentsOf: oneHot(playerID, count: 4))
        values.append(contentsOf: oneHot((playerID - state.lead + 4) % 4, count: 4))
        values.append(contentsOf: oneHot((playerID - state.trumpSelector + 4) % 4, count: 4))
    }

    static func appendTrickFeatures(to values: inout [Double], plays: [TrickPlay]) {
        for slot in 0..<4 {
            guard plays.indices.contains(slot) else {
                values.append(contentsOf: Array(repeating: 0.0, count: 7))
                continue
            }
            let play = plays[slot]
            values.append(1)
            values.append(Double(play.playerID) / 3)
            values.append(contentsOf: oneHot(suitIndex(play.card.suit), count: 4))
            values.append(Double(play.card.value) / 13)
        }
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

    static func finalScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = visibleScore(for: playerID, state: state)
        score += player.plot.hidden.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.hidden.reduce(0) { $0 + $1.value }
        }
        return score
    }

    static func visibleScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = player.plot.revealed.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.revealed.reduce(0) { $0 + $1.value }
        }
        if state.variants.medalsCount {
            score += player.plot.medals + player.medals
        }
        return score
    }

    static func gameFinalScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        return visibleScore(for: playerID, state: state) + player.plot.hidden.reduce(0) { $0 + $1.value }
    }

    static func knownScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = visibleScore(for: playerID, state: state)
        score += player.plot.hidden.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.hidden.reduce(0) { $0 + $1.value }
        }
        return score
    }

    static func revealedPlotCount(for player: PlayerState, suit: Suit? = nil) -> Int {
        let cards = player.plot.revealed + player.plot.stacks.flatMap(\.revealed)
        guard let suit else { return cards.count }
        return cards.filter { $0.suit == suit }.count
    }

    static func hiddenPlotCount(for player: PlayerState, suit: Suit? = nil) -> Int {
        let cards = player.plot.hidden + player.plot.stacks.flatMap(\.hidden)
        guard let suit else { return cards.count }
        return cards.filter { $0.suit == suit }.count
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

func formatImitationHeadWeights(_ weights: [Double]) -> String {
    guard weights.count == 4, weights.contains(where: { $0 >= 0 }) else { return "global" }
    return weights
        .map { $0 >= 0 ? String(format: "%.3f", $0) : "global" }
        .joined(separator: ",")
}

func formatBehaviorCloneHeadWeights(_ weights: [Double]) -> String {
    guard weights.count == 4 else { return "1.000,1.000,1.000,1.000" }
    return weights.map { String(format: "%.3f", $0) }.joined(separator: ",")
}

func printValidation(_ validation: ValidationSummary, episode: Int) {
    print(
        "validation episode=\(episode) score=\(String(format: "%.4f", validation.score)) samples=\(validation.samples) top_delta=\(String(format: "%.4f", validation.topDelta)) strict_delta=\(String(format: "%.4f", validation.strictDelta)) rank_delta=\(String(format: "%.4f", validation.rankDelta)) margin_delta=\(String(format: "%.4f", validation.marginDelta)) worst_top=\(String(format: "%.4f", validation.worstSeatTop)) worst_rank=\(String(format: "%.4f", validation.worstSeatRank)) worst_margin=\(String(format: "%.4f", validation.worstSeatMargin))"
    )
}

func validationPassesSelectionGate(_ validation: ValidationSummary, options: Options) -> Bool {
    validation.score >= options.validationMinScore
        && validation.topDelta >= options.validationMinTopDelta
        && validation.rankDelta >= options.validationMinRankDelta
        && validation.marginDelta >= options.validationMinMarginDelta
        && validation.worstSeatTop >= options.validationMinWorstTopDelta
        && validation.worstSeatRank >= options.validationMinWorstRankDelta
        && validation.worstSeatMargin >= options.validationMinWorstMarginDelta
}

func validationGateStatus(_ validation: ValidationSummary, options: Options) -> String {
    validationPassesSelectionGate(validation, options: options) ? "pass" : "fail"
}

func validationBestURL(outputPath: String, validationOutputPath: String?) -> URL {
    if let validationOutputPath {
        return URL(fileURLWithPath: validationOutputPath)
    }
    let outputURL = URL(fileURLWithPath: outputPath)
    let directory = outputURL.deletingLastPathComponent()
    let base = outputURL.deletingPathExtension().lastPathComponent
    return directory.appendingPathComponent("\(base)_best.json")
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
    var w2 = Array(repeating: 0.0, count: targetHiddenSize * model.headCount)
    for row in 0..<model.hiddenSize {
        b1[row] = model.b1[row]
    }
    for head in 0..<model.headCount {
        for row in 0..<model.hiddenSize {
            w2[head * targetHiddenSize + row] = model.w2[head * model.hiddenSize + row]
        }
    }

    let safeScale = max(0, scale)
    for row in model.hiddenSize..<targetHiddenSize {
        let offset = row * model.inputSize
        for column in 0..<model.inputSize {
            w1[offset + column] = rng.signedUniform() * safeScale
        }
        b1[row] = rng.signedUniform() * safeScale
        for head in 0..<model.headCount {
            w2[head * targetHiddenSize + row] = rng.signedUniform() * safeScale
        }
    }

    return KolkhozPolicyModel(
        version: model.version,
        featureVersion: model.featureVersion,
        inputSize: model.inputSize,
        hiddenSize: targetHiddenSize,
        w1: w1,
        b1: b1,
        w2: w2,
        b2: model.b2,
        b2s: model.b2s,
        valueWeights: model.valueWeights,
        valueBias: model.valueBias
    )
}

func loadCompatiblePolicyModel(path: String) throws -> KolkhozPolicyModel {
    let model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: path))
    guard model.isCompatible else {
        throw TrainerError.incompatibleModel(path)
    }
    return model
}

func trainingStartModel(path: String) throws -> KolkhozPolicyModel {
    let model = try loadCompatiblePolicyModel(path: path)
    let supportedHeadCounts: Set<Int> = [PolicyFeatures.actionHeadCount, PolicyFeatures.modelHeadCount]
    guard model.featureVersion == PolicyFeatures.version,
          model.inputSize == PolicyFeatures.inputSize,
          supportedHeadCounts.contains(model.headCount) else {
        throw TrainerError.incompatibleModel("\(path) is not a current v\(PolicyFeatures.version) training model; use --scratch or provide a v\(PolicyFeatures.version) checkpoint")
    }
    return model
}

func randomWeights(fanIn: Int, fanOut: Int, scale: Double, rng: inout SeededGenerator) -> [Double] {
    let limit = scale * sqrt(6.0 / Double(max(1, fanIn + fanOut)))
    return (0..<(fanIn * fanOut)).map { _ in rng.signedUniform() * limit }
}

func scratchPolicyModel(layers requestedLayers: [Int], scale: Double, sharedHeads: Bool, rng: inout SeededGenerator) -> KolkhozPolicyModel {
    let layers = Array((requestedLayers.isEmpty ? [128] : requestedLayers).prefix(4)).map { max(1, $0) }
    let headCount = sharedHeads ? PolicyFeatures.actionHeadCount : PolicyFeatures.modelHeadCount
    var hiddenWeights: [[Double]] = []
    var hiddenBiases: [[Double]] = []
    for (index, layerSize) in layers.enumerated() {
        let inputSize = index == 0 ? PolicyFeatures.inputSize : layers[index - 1]
        hiddenWeights.append(randomWeights(fanIn: inputSize, fanOut: layerSize, scale: scale, rng: &rng))
        hiddenBiases.append(Array(repeating: 0.0, count: layerSize))
    }
    let outputWeights = randomWeights(
        fanIn: layers.last ?? 1,
        fanOut: headCount,
        scale: scale,
        rng: &rng
    )
    return KolkhozPolicyModel(
        version: 5,
        featureVersion: PolicyFeatures.version,
        inputSize: PolicyFeatures.inputSize,
        hiddenSize: layers[0],
        hiddenLayerSizes: layers,
        w1: hiddenWeights[0],
        b1: hiddenBiases[0],
        hiddenWeights: hiddenWeights,
        hiddenBiases: hiddenBiases,
        w2: [],
        outputWeights: outputWeights,
        b2: 0,
        b2s: Array(repeating: 0.0, count: headCount),
        valueWeights: Array(repeating: 0.0, count: cValueInputSize),
        valueBias: 0
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
    var model: KolkhozPolicyModel
    if options.scratch {
        model = scratchPolicyModel(layers: options.scratchLayers, scale: options.scratchScale, sharedHeads: options.sharedHeads, rng: &rng)
        let layerDescription = options.scratchLayers.map(String.init).joined(separator: ",")
        print("scratch_model feature_version=\(PolicyFeatures.version) input_size=\(PolicyFeatures.inputSize) layers=\(layerDescription) scale=\(options.scratchScale) heads=\(model.headCount)")
    } else {
        guard let startPath = options.startPath else {
            throw TrainerError.incompatibleModel("missing --start for non-scratch training")
        }
        model = try trainingStartModel(path: startPath)
    }
    guard model.featureVersion == PolicyFeatures.version,
          model.inputSize == PolicyFeatures.inputSize else {
        throw TrainerError.incompatibleModel("trainable model must be v\(PolicyFeatures.version)/\(PolicyFeatures.inputSize)")
    }
    if let expandHidden = options.expandHidden, expandHidden > model.hiddenSize {
        let previousHiddenSize = model.hiddenSize
        model = expandedModel(model, hiddenSize: expandHidden, scale: options.expandScale, rng: &rng)
        print("expanded_hidden from=\(previousHiddenSize) to=\(model.hiddenSize) scale=\(options.expandScale)")
    }
    let opponentModel = try options.opponentPath.map { try loadCompatiblePolicyModel(path: $0) }
    let leagueModels = try options.leaguePaths.map { try loadCompatiblePolicyModel(path: $0) }
    let validationBaselineModel: KolkhozPolicyModel?
    if let validationBaselinePath = options.validationBaselinePath {
        validationBaselineModel = try loadCompatiblePolicyModel(path: validationBaselinePath)
    } else {
        validationBaselineModel = opponentModel ?? leagueModels.first
    }

    if options.behaviorCloneSteps > 0 {
        guard let teacherModel = opponentModel ?? validationBaselineModel else {
            throw TrainerError.incompatibleModel("--behavior-clone-steps requires --opponent-model or --validation-baseline-model")
        }
        let cloned = try behaviorClonePretrain(model: model, teacherModel: teacherModel, options: options)
        model = cloned.model
        print(
            "behavior_clone steps=\(cloned.summary.steps) accuracy=\(String(format: "%.4f", cloned.summary.accuracy)) " +
            "loss=\(String(format: "%.4f", cloned.summary.averageLoss)) grad_norm=\(String(format: "%.4f", cloned.summary.gradientNorm)) " +
            "head_weights=\(formatBehaviorCloneHeadWeights(options.behaviorCloneHeadWeights)) distill_temperature=\(String(format: "%.3f", options.behaviorCloneDistillTemperature)) " +
            "rollout_teacher=\(options.behaviorCloneRolloutTeacher ? 1 : 0) rollout_round_only=\(options.behaviorCloneRolloutRoundOnly ? 1 : 0)"
        )
        if options.behaviorCloneOnly {
            let outputURL = URL(fileURLWithPath: options.outputPath)
            try FileManager.default.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try model.save(to: outputURL)
            print("exported \(options.outputPath)")
            if let validation = try? validateModel(
                model,
                baselineModel: validationBaselineModel,
                seeds: options.validationSeeds,
                gamesPerSeat: options.validationGamesPerSeat
            ), validation.samples > 0 {
                printValidation(validation, episode: options.behaviorCloneSteps)
                let gateStatus = validationGateStatus(validation, options: options)
                print("validation_gate episode=\(options.behaviorCloneSteps) status=\(gateStatus)")
                if gateStatus == "pass" {
                    try? model.save(to: validationBestURL(outputPath: options.outputPath, validationOutputPath: options.validationOutputPath))
                }
            }
            return
        }
    }

    let engine = options.engine.lowercased()
    if engine == "c-direct" {
        let leagueOpponents = ([opponentModel].compactMap { $0 }) + leagueModels
        var valueWeights = Array(repeating: 0.0, count: cValueInputSize)
        let cDirectValidationSelection = options.checkpointEvery > 0
            && !options.validationSeeds.isEmpty
            && options.validationGamesPerSeat > 0
            && leagueModels.isEmpty
        let trained = if cDirectValidationSelection {
            try trainWithDirectCEngineSelected(
                model: model,
                opponentModel: opponentModel,
                options: options,
                reward: reward,
                validationBaselineModel: validationBaselineModel
            )
        } else if leagueOpponents.isEmpty {
            try trainWithDirectCEngine(model: model, opponentModel: nil, options: options, reward: reward, valueWeights: &valueWeights)
        } else if leagueModels.isEmpty {
            try trainWithDirectCEngine(model: model, opponentModel: opponentModel, options: options, reward: reward, valueWeights: &valueWeights)
        } else {
            try trainWithDirectCEngineLeague(model: model, opponentModels: leagueOpponents, options: options, reward: reward)
        }
        try writeDirectCEngineArtifacts(
            trained: trained.model,
            result: trained.result,
            options: options,
            validationBaselineModel: validationBaselineModel
        )
        return
    } else if engine != "swift" && engine != "swift-legacy" {
        throw TrainerError.incompatibleModel("unknown --engine \(options.engine)")
    }

    let validationEnabled = !options.validationSeeds.isEmpty && options.validationGamesPerSeat > 0
    let validationURL = validationBestURL(
        outputPath: options.outputPath,
        validationOutputPath: options.validationOutputPath
    )
    var bestValidationScore = -Double.infinity

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
                marginDeltaWeight: options.marginDeltaWeight,
                workDeltaWeight: options.workDeltaWeight,
                claimDeltaWeight: options.claimDeltaWeight,
                ownRequisitionWeight: options.ownRequisitionWeight
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
                marginDeltaWeight: options.marginDeltaWeight,
                workDeltaWeight: options.workDeltaWeight,
                claimDeltaWeight: options.claimDeltaWeight,
                ownRequisitionWeight: options.ownRequisitionWeight
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
                averageShapedReward: batchShapedReward / Double(max(1, batchEpisodes)),
                averagePPOKL: 0,
                averagePPOAbsKL: 0,
                averagePPOEntropy: 0,
                averagePPOClipFraction: 0
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
                if validationEnabled {
                    let validation = try validateModel(
                        model,
                        baselineModel: validationBaselineModel,
                        seeds: options.validationSeeds,
                        gamesPerSeat: options.validationGamesPerSeat
                    )
                    print(
                        "validation episode=\(episode) score=\(String(format: "%.4f", validation.score)) samples=\(validation.samples) top_delta=\(String(format: "%.4f", validation.topDelta)) strict_delta=\(String(format: "%.4f", validation.strictDelta)) rank_delta=\(String(format: "%.4f", validation.rankDelta)) margin_delta=\(String(format: "%.4f", validation.marginDelta)) worst_top=\(String(format: "%.4f", validation.worstSeatTop)) worst_rank=\(String(format: "%.4f", validation.worstSeatRank)) worst_margin=\(String(format: "%.4f", validation.worstSeatMargin))"
                    )
                    let gateStatus = validationGateStatus(validation, options: options)
                    print("validation_gate episode=\(episode) status=\(gateStatus)")
                    if gateStatus == "pass" && validation.score > bestValidationScore {
                        bestValidationScore = validation.score
                        try FileManager.default.createDirectory(at: validationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                        try model.save(to: validationURL)
                        print("validation_best \(validationURL.path)")
                    }
                }
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
