import Foundation
import KolkhozCore

struct ParityFailure: Error, CustomStringConvertible {
    let message: String

    var description: String { message }
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
        throw ParityFailure(message: "no legal actions")
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

func describe(_ action: KolkhozEngineAction) -> String {
    "kind=\(action.kind.rawValue) player=\(action.playerID) suit=\(action.suit) card=\(action.card.suit):\(action.card.value) hand=\(action.handCard.suit):\(action.handCard.value) plot=\(action.plotCard.suit):\(action.plotCard.value) target=\(action.targetSuit)"
}

func assertParity(reference: KolkhozEngine, candidate: KolkhozHeadlessEngine, suite: String, seed: UInt64, step: Int, action: KolkhozEngineAction?) throws {
    let referenceSnapshot = KolkhozEngineSnapshot(engine: reference)
    let candidateSnapshot = candidate.snapshot
    guard referenceSnapshot == candidateSnapshot else {
        let actionText = action.map(describe) ?? "initial"
        throw ParityFailure(
            message: """
            parity mismatch suite=\(suite) seed=\(seed) step=\(step) action=\(actionText)
            reference: \(referenceSnapshot.compactTrace)
            \(snapshotDetail(referenceSnapshot))
            candidate:  \(candidateSnapshot.compactTrace)
            \(snapshotDetail(candidateSnapshot))
            """
        )
    }
}

func assertLegalActionsParity(reference: KolkhozEngine, candidate: KolkhozHeadlessEngine, suite: String, seed: UInt64, step: Int) throws {
    let referenceActions = KolkhozHeadlessEngine.legalActions(for: reference).sorted(by: actionSort)
    let candidateActions = candidate.legalActions().sorted(by: actionSort)
    guard referenceActions == candidateActions else {
        throw ParityFailure(
            message: """
            legal action mismatch suite=\(suite) seed=\(seed) step=\(step)
            reference: \(referenceActions.map(describe).joined(separator: " | "))
            candidate:  \(candidateActions.map(describe).joined(separator: " | "))
            """
        )
    }
}

func snapshotDetail(_ snapshot: KolkhozEngineSnapshot) -> String {
    let hands = snapshot.players.map { player in
        let cards = player.hand.map { "\($0.suit):\($0.value)" }.joined(separator: ",")
        return "\(player.id)=[\(cards)]"
    }.joined(separator: " ")
    let jobs = snapshot.revealedJobs.map { entry in
        let cards = entry.cards.map { "\($0.suit):\($0.value)" }.joined(separator: ",")
        return "\(entry.suit)=[\(cards)]"
    }.joined(separator: " ")
    let scores = snapshot.scores.map { "\($0.playerID):v\($0.visibleScore):f\($0.finalScore)" }.joined(separator: " ")
    return "hands \(hands)\njobs \(jobs)\nscores \(scores)"
}

func runSeed(_ seed: UInt64, suite: String, variants: GameVariants) throws -> Int {
    let reference = KolkhozEngine(
        seed: seed,
        variants: variants,
        controllers: KolkhozHeadlessEngine.allHumanControllers,
        aiModel: nil
    )
    let candidate = KolkhozHeadlessEngine(seed: seed, variants: variants)
    try assertParity(reference: reference, candidate: candidate, suite: suite, seed: seed, step: 0, action: nil)
    try assertLegalActionsParity(reference: reference, candidate: candidate, suite: suite, seed: seed, step: 0)

    var step = 0
    while reference.state.phase != .gameOver {
        step += 1
        guard step <= 1_000 else {
            throw ParityFailure(message: "\(suite) seed \(seed) exceeded step guard")
        }
        try assertLegalActionsParity(reference: reference, candidate: candidate, suite: suite, seed: seed, step: step)
        let actions = candidate.legalActions()
        guard !actions.isEmpty else {
            throw ParityFailure(message: "\(suite) seed \(seed) step \(step) had no legal actions in phase \(candidate.phaseCode)")
        }
        let action = try chooseAction(from: actions)
        try KolkhozHeadlessEngine.apply(action, to: reference)
        try candidate.apply(action)
        try assertParity(reference: reference, candidate: candidate, suite: suite, seed: seed, step: step, action: action)
    }

    return step
}

let suites: [(String, GameVariants, ClosedRange<UInt64>)] = [
    ("kolkhoz", .kolkhoz, 1...32),
    ("noSwap", GameVariants(nomenclature: false, allowSwap: false), 1...12),
    ("nomenclature52", GameVariants(nomenclature: true), 1...12),
    ("medalsCount", GameVariants(nomenclature: false, medalsCount: true), 1...12),
    ("mice52", GameVariants(nomenclature: false, miceVariant: true), 1...12),
    ("northern52", GameVariants(nomenclature: false, northernStyle: true), 1...12),
    ("littleKolkhoz", .littleKolkhoz, 1...16),
    ("campStyle", .campStyle, 1...16),
    ("accumulateJobs", GameVariants(nomenclature: false, accumulateJobs: true, heroOfSovietUnion: true), 1...16)
]

do {
    var totalSteps = 0
    var totalSeeds = 0
    for (suite, variants, seeds) in suites {
        for seed in seeds {
            totalSteps += try runSeed(seed, suite: suite, variants: variants)
            totalSeeds += 1
        }
    }
    print("Kolkhoz C engine parity passed for \(totalSeeds) seeds across \(suites.count) rulesets, \(totalSteps) portable actions")
} catch {
    fputs("Kolkhoz engine parity failed: \(error)\n", stderr)
    exit(1)
}
