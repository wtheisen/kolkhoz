import Foundation
import KolkhozCore

struct Options {
    var modelPath: String?
    var games = 100
    var seed: UInt64 = 10_000
    var variants = GameVariants.kolkhoz
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--model":
            options.modelPath = args.isEmpty ? nil : args.removeFirst()
        case "--games":
            if let value = args.first, let parsed = Int(value) {
                options.games = parsed
                args.removeFirst()
            }
        case "--seed":
            if let value = args.first, let parsed = UInt64(value) {
                options.seed = parsed
                args.removeFirst()
            }
        default:
            break
        }
    }
    return options
}

func playGame(seed: UInt64, variants: GameVariants, model: KolkhozPolicyModel?) throws -> [Int: Int] {
    let engine = KolkhozEngine(seed: seed, variants: variants, aiModel: model)
    var guardCount = 0

    while engine.state.phase != .gameOver && guardCount < 1_000 {
        guardCount += 1
        let decider = KolkhozAIDecider(state: engine.state, model: model)

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
                throw EvaluationError.invalidPolicyAction
            }
            try engine.playCard(engine.state.players[0].hand[index])

        case .assignment where engine.state.lastWinner == 0:
            let assignments = decider.chooseAssignments(for: 0)
            for play in engine.state.lastTrick {
                guard let suit = assignments[play.card.id] else {
                    throw EvaluationError.invalidPolicyAction
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
        throw EvaluationError.gameDidNotFinish
    }
    return result.scores
}

enum EvaluationError: Error {
    case gameDidNotFinish
    case invalidPolicyAction
}

func bestScore(_ scores: [Int: Int]) -> Int {
    scores.values.max() ?? 0
}

func main() throws {
    let options = parseOptions()
    let model: KolkhozPolicyModel?
    if let modelPath = options.modelPath {
        model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: modelPath))
        guard model?.isCompatible == true else {
            fputs("Model is not compatible with current Swift feature contract\n", stderr)
            exit(2)
        }
    } else {
        model = nil
    }

    var policyWins = 0
    var heuristicWins = 0
    var ties = 0
    var marginTotal = 0

    for offset in 0..<options.games {
        let seed = options.seed + UInt64(offset)
        let policyScores = try playGame(seed: seed, variants: options.variants, model: model)
        let heuristicScores = try playGame(seed: seed, variants: options.variants, model: nil)
        let policyBest = bestScore(policyScores)
        let heuristicBest = bestScore(heuristicScores)
        marginTotal += policyBest - heuristicBest

        if policyBest > heuristicBest {
            policyWins += 1
        } else if heuristicBest > policyBest {
            heuristicWins += 1
        } else {
            ties += 1
        }
    }

    let averageMargin = Double(marginTotal) / Double(max(1, options.games))
    print("real_engine_eval games=\(options.games) policy_wins=\(policyWins) heuristic_wins=\(heuristicWins) ties=\(ties) avg_best_score_margin=\(String(format: "%.2f", averageMargin))")
}

do {
    try main()
} catch {
    fputs("KolkhozPolicyEval failed: \(error)\n", stderr)
    exit(1)
}
