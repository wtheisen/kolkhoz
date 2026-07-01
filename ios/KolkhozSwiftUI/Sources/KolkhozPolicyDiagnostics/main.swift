import Foundation
import KolkhozCore

struct Options {
    var candidatePath: String?
    var baselinePath: String?
    var baselineIsHeuristic = false
    var gamesPerSeat = 25
    var seed: UInt64 = 9_000_000
    var maxExamples = 12
    var includeCandidateDriven = true
    var includeBaselineDriven = true
}

enum DiagnosticsError: Error {
    case missingCandidate
    case missingBaseline
    case incompatibleModel(String)
    case gameDidNotFinish(seed: UInt64, seat: Int, driver: DriverKind, phase: GamePhase)
    case invalidAction(String)
}

enum DriverKind: String, CaseIterable {
    case baseline
    case candidate
}

enum PolicyAction: Equatable, Hashable {
    case trump(Suit)
    case noSwap
    case swap(handCard: Card, plotCard: Card, revealed: Bool)
    case play(Card)
    case assign(Suit)
}

struct DecisionContext: Hashable {
    let driver: DriverKind
    let seat: Int
    let phase: GamePhase
    let year: Int
}

struct Counter {
    private var counts: [String: Int] = [:]

    mutating func add(_ key: String) {
        counts[key, default: 0] += 1
    }

    mutating func add(_ key: String, count: Int) {
        counts[key, default: 0] += count
    }

    func sorted() -> [(String, Int)] {
        counts.sorted {
            if $0.value == $1.value { return $0.key < $1.key }
            return $0.value > $1.value
        }
    }
}

struct DecisionStats {
    var decisions = 0
    var disagreements = 0
    var candidateActions = Counter()
    var baselineActions = Counter()
    var candidateSwapPasses = 0
    var baselineSwapPasses = 0
    var candidateSwapChoices = 0
    var baselineSwapChoices = 0
    var candidateTrickValueTotal = 0
    var baselineTrickValueTotal = 0
    var trickDecisions = 0

    mutating func record(candidate: PolicyAction, baseline: PolicyAction) {
        decisions += 1
        if candidate != baseline {
            disagreements += 1
        }
        candidateActions.add(candidate.summary)
        baselineActions.add(baseline.summary)

        if candidate.isSwapPhaseAction {
            switch candidate {
            case .noSwap: candidateSwapPasses += 1
            case .swap: candidateSwapChoices += 1
            default: break
            }
        }
        if baseline.isSwapPhaseAction {
            switch baseline {
            case .noSwap: baselineSwapPasses += 1
            case .swap: baselineSwapChoices += 1
            default: break
            }
        }

        if case .play(let card) = candidate {
            candidateTrickValueTotal += card.value
            trickDecisions += 1
        }
        if case .play(let card) = baseline {
            baselineTrickValueTotal += card.value
        }
    }

    var disagreementRate: Double {
        decisions == 0 ? 0 : Double(disagreements) / Double(decisions)
    }

    var candidateSwapPassRate: Double {
        let total = candidateSwapPasses + candidateSwapChoices
        return total == 0 ? 0 : Double(candidateSwapPasses) / Double(total)
    }

    var baselineSwapPassRate: Double {
        let total = baselineSwapPasses + baselineSwapChoices
        return total == 0 ? 0 : Double(baselineSwapPasses) / Double(total)
    }

    var candidateAverageTrickValue: Double {
        trickDecisions == 0 ? 0 : Double(candidateTrickValueTotal) / Double(trickDecisions)
    }

    var baselineAverageTrickValue: Double {
        trickDecisions == 0 ? 0 : Double(baselineTrickValueTotal) / Double(trickDecisions)
    }
}

struct OutcomeStats {
    var games = 0
    var driverWins = 0
    var driverRankTotal = 0
    var driverMarginTotal = 0

    mutating func record(seat: Int, outcome: GameOutcome) {
        games += 1
        if outcome.winnerID == seat {
            driverWins += 1
        }
        driverRankTotal += rank(of: seat, outcome: outcome)
        let own = outcome.scores[seat] ?? 0
        let bestOpponent = outcome.scores
            .filter { $0.key != seat }
            .map(\.value)
            .max() ?? 0
        driverMarginTotal += own - bestOpponent
    }

    var winRate: Double {
        games == 0 ? 0 : Double(driverWins) / Double(games)
    }

    var averageRank: Double {
        games == 0 ? 0 : Double(driverRankTotal) / Double(games)
    }

    var averageMargin: Double {
        games == 0 ? 0 : Double(driverMarginTotal) / Double(games)
    }
}

struct GameOutcome {
    let scores: [Int: Int]
    let medals: [Int: Int]
    let winnerID: Int
}

struct Example {
    let driver: DriverKind
    let seed: UInt64
    let seat: Int
    let year: Int
    let trick: Int
    let phase: GamePhase
    let currentPlayer: Int
    let candidate: PolicyAction
    let baseline: PolicyAction
    let summary: String
}

struct Diagnostics {
    var aggregate = DecisionStats()
    var byContext: [DecisionContext: DecisionStats] = [:]
    var outcomes: [DriverKind: OutcomeStats] = [:]
    var examples: [Example] = []

    mutating func record(
        driver: DriverKind,
        seat: Int,
        state: KolkhozState,
        candidate: PolicyAction,
        baseline: PolicyAction,
        seed: UInt64,
        maxExamples: Int
    ) {
        aggregate.record(candidate: candidate, baseline: baseline)
        let context = DecisionContext(driver: driver, seat: seat, phase: state.phase, year: state.year)
        byContext[context, default: DecisionStats()].record(candidate: candidate, baseline: baseline)

        if candidate != baseline, examples.count < maxExamples {
            examples.append(Example(
                driver: driver,
                seed: seed,
                seat: seat,
                year: state.year,
                trick: state.trickCount,
                phase: state.phase,
                currentPlayer: state.currentPlayer,
                candidate: candidate,
                baseline: baseline,
                summary: stateSummary(state, seat: seat)
            ))
        }
    }

    mutating func recordOutcome(driver: DriverKind, seat: Int, outcome: GameOutcome) {
        outcomes[driver, default: OutcomeStats()].record(seat: seat, outcome: outcome)
    }
}

func parseOptions() -> Options {
    var options = Options()
    var args = Array(CommandLine.arguments.dropFirst())
    while !args.isEmpty {
        let arg = args.removeFirst()
        switch arg {
        case "--candidate", "--model":
            options.candidatePath = args.isEmpty ? nil : args.removeFirst()
        case "--baseline-model":
            options.baselinePath = args.isEmpty ? nil : args.removeFirst()
            options.baselineIsHeuristic = false
        case "--baseline":
            if let value = args.first {
                if value == "heuristic" {
                    options.baselineIsHeuristic = true
                    options.baselinePath = nil
                } else if value == "bundled" {
                    options.baselineIsHeuristic = false
                    options.baselinePath = nil
                }
                args.removeFirst()
            }
        case "--games-per-seat":
            if let value = args.first, let parsed = Int(value) {
                options.gamesPerSeat = max(1, parsed)
                args.removeFirst()
            }
        case "--seed":
            if let value = args.first, let parsed = UInt64(value) {
                options.seed = parsed
                args.removeFirst()
            }
        case "--max-examples":
            if let value = args.first, let parsed = Int(value) {
                options.maxExamples = max(0, parsed)
                args.removeFirst()
            }
        case "--driver":
            if let value = args.first {
                options.includeBaselineDriven = value == "baseline" || value == "both"
                options.includeCandidateDriven = value == "candidate" || value == "both"
                args.removeFirst()
            }
        default:
            break
        }
    }
    return options
}

func loadModel(path: String?, label: String) throws -> KolkhozPolicyModel {
    let model: KolkhozPolicyModel
    if let path {
        model = try KolkhozPolicyModel.load(from: URL(fileURLWithPath: path))
    } else if let bundled = KolkhozPolicyModel.bundled() {
        model = bundled
    } else {
        throw DiagnosticsError.missingBaseline
    }
    guard model.isCompatible else {
        throw DiagnosticsError.incompatibleModel(label)
    }
    return model
}

func chooseAction(model: KolkhozPolicyModel?, state: KolkhozState, playerID: Int) throws -> PolicyAction {
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
            throw DiagnosticsError.invalidAction("invalid card index \(index)")
        }
        return .play(state.players[playerID].hand[index])

    case .assignment:
        let assignments = decider.chooseAssignments(for: playerID)
        guard let suit = state.lastTrick.first.flatMap({ assignments[$0.card.id] }) else {
            throw DiagnosticsError.invalidAction("missing assignment")
        }
        return .assign(suit)

    case .requisition, .gameOver:
        throw DiagnosticsError.invalidAction("no policy action in \(state.phase.rawValue)")
    }
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

func playDiagnosticGame(
    seed: UInt64,
    seat: Int,
    driver: DriverKind,
    candidate: KolkhozPolicyModel,
    baseline: KolkhozPolicyModel?,
    diagnostics: inout Diagnostics,
    maxExamples: Int
) throws {
    let controllers = Array(repeating: PlayerController.human, count: 4)
    let engine = KolkhozEngine(seed: seed, variants: .kolkhoz, controllers: controllers, aiModel: nil)
    var guardCount = 0

    while engine.state.phase != .gameOver && guardCount < 1_000 {
        guardCount += 1
        let state = engine.state

        switch state.phase {
        case .planning, .swap, .trick, .assignment:
            let playerID = state.phase == .assignment ? (state.lastWinner ?? state.currentPlayer) : state.currentPlayer
            let candidateAction = try chooseAction(model: candidate, state: state, playerID: playerID)
            let baselineAction = try chooseAction(model: baseline, state: state, playerID: playerID)

            if playerID == seat {
                diagnostics.record(
                    driver: driver,
                    seat: seat,
                    state: state,
                    candidate: candidateAction,
                    baseline: baselineAction,
                    seed: seed,
                    maxExamples: maxExamples
                )
            }

            let actionToApply: PolicyAction
            if playerID == seat {
                actionToApply = driver == .candidate ? candidateAction : baselineAction
            } else {
                actionToApply = baselineAction
            }
            try apply(actionToApply, to: engine, playerID: playerID)

        case .requisition:
            engine.continueAfterRequisition()

        case .gameOver:
            break
        }
    }

    guard engine.state.phase == .gameOver, let result = engine.state.gameResult else {
        throw DiagnosticsError.gameDidNotFinish(seed: seed, seat: seat, driver: driver, phase: engine.state.phase)
    }
    let medals = Dictionary(uniqueKeysWithValues: engine.state.players.map { ($0.id, $0.plot.medals + $0.medals) })
    diagnostics.recordOutcome(
        driver: driver,
        seat: seat,
        outcome: GameOutcome(scores: result.scores, medals: medals, winnerID: result.winnerID)
    )
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

func stateSummary(_ state: KolkhozState, seat: Int) -> String {
    let work = Suit.allCases
        .map { "\($0.shortName)=\(state.workHours[$0, default: 0])" }
        .joined(separator: ",")
    let hand = state.players[seat].hand.map(\.shortName).joined(separator: " ")
    let visible = state.players.indices
        .map { "\($0):\(visibleScore(for: $0, state: state))" }
        .joined(separator: ",")
    return "trump=\(state.trump?.shortName ?? "none") lead=\(state.lead) work=[\(work)] visible=[\(visible)] hand=[\(hand)]"
}

func visibleScore(for playerID: Int, state: KolkhozState) -> Int {
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

func printStats(_ label: String, _ stats: DecisionStats, indent: String = "") {
    guard stats.decisions > 0 else { return }
    print("\(indent)\(label) decisions=\(stats.decisions) disagreements=\(stats.disagreements) disagreement_rate=\(formatRate(stats.disagreementRate))")
    if stats.candidateSwapPasses + stats.candidateSwapChoices + stats.baselineSwapPasses + stats.baselineSwapChoices > 0 {
        print("\(indent)  swap_pass_rate candidate=\(formatRate(stats.candidateSwapPassRate)) baseline=\(formatRate(stats.baselineSwapPassRate))")
    }
    if stats.trickDecisions > 0 {
        print("\(indent)  avg_played_card_value candidate=\(formatDouble(stats.candidateAverageTrickValue)) baseline=\(formatDouble(stats.baselineAverageTrickValue))")
    }
    print("\(indent)  candidate_top_actions \(formatCounts(stats.candidateActions))")
    print("\(indent)  baseline_top_actions \(formatCounts(stats.baselineActions))")
}

func formatCounts(_ counter: Counter, limit: Int = 6) -> String {
    counter.sorted().prefix(limit).map { "\($0.0):\($0.1)" }.joined(separator: " ")
}

func formatRate(_ value: Double) -> String {
    String(format: "%.1f%%", value * 100)
}

func formatDouble(_ value: Double) -> String {
    String(format: "%.2f", value)
}

func printDiagnostics(_ diagnostics: Diagnostics, options: Options, baselineLabel: String) {
    print("policy_diagnostics games_per_seat=\(options.gamesPerSeat) seed=\(options.seed) baseline=\(baselineLabel)")
    for driver in DriverKind.allCases {
        guard let outcome = diagnostics.outcomes[driver], outcome.games > 0 else { continue }
        print("driver=\(driver.rawValue) games=\(outcome.games) seat_win_rate=\(formatRate(outcome.winRate)) avg_rank=\(formatDouble(outcome.averageRank)) avg_margin=\(formatDouble(outcome.averageMargin))")
    }
    printStats("aggregate", diagnostics.aggregate)

    for driver in DriverKind.allCases {
        for phase in [GamePhase.planning, .swap, .trick, .assignment] {
            var combined = DecisionStats()
            for (context, stats) in diagnostics.byContext where context.driver == driver && context.phase == phase {
                combined.merge(stats)
            }
            printStats("driver=\(driver.rawValue) phase=\(phase.rawValue)", combined, indent: "  ")
        }
    }

    for seat in 0..<4 {
        var combined = DecisionStats()
        for (context, stats) in diagnostics.byContext where context.seat == seat {
            combined.merge(stats)
        }
        printStats("seat_\(seat)", combined, indent: "  ")
    }

    if !diagnostics.examples.isEmpty {
        print("examples")
        for example in diagnostics.examples {
            print("  driver=\(example.driver.rawValue) seed=\(example.seed) seat=\(example.seat) year=\(example.year) trick=\(example.trick) phase=\(example.phase.rawValue) player=\(example.currentPlayer)")
            print("    candidate=\(example.candidate.detail)")
            print("    baseline=\(example.baseline.detail)")
            print("    state \(example.summary)")
        }
    }
}

func main() throws {
    let options = parseOptions()
    guard let candidatePath = options.candidatePath else {
        throw DiagnosticsError.missingCandidate
    }
    let candidate = try loadModel(path: candidatePath, label: "candidate")
    let baseline = options.baselineIsHeuristic ? nil : try loadModel(path: options.baselinePath, label: "baseline")
    let baselineLabel = options.baselineIsHeuristic ? "heuristic" : (options.baselinePath ?? "bundled")

    var diagnostics = Diagnostics()
    let drivers = DriverKind.allCases.filter {
        ($0 == .baseline && options.includeBaselineDriven) || ($0 == .candidate && options.includeCandidateDriven)
    }
    for driver in drivers {
        for seat in 0..<4 {
            for gameIndex in 0..<options.gamesPerSeat {
                let seed = options.seed + UInt64(gameIndex)
                try playDiagnosticGame(
                    seed: seed,
                    seat: seat,
                    driver: driver,
                    candidate: candidate,
                    baseline: baseline,
                    diagnostics: &diagnostics,
                    maxExamples: options.maxExamples
                )
            }
        }
    }

    printDiagnostics(diagnostics, options: options, baselineLabel: baselineLabel)
}

extension DecisionStats {
    mutating func merge(_ other: DecisionStats) {
        decisions += other.decisions
        disagreements += other.disagreements
        candidateSwapPasses += other.candidateSwapPasses
        baselineSwapPasses += other.baselineSwapPasses
        candidateSwapChoices += other.candidateSwapChoices
        baselineSwapChoices += other.baselineSwapChoices
        candidateTrickValueTotal += other.candidateTrickValueTotal
        baselineTrickValueTotal += other.baselineTrickValueTotal
        trickDecisions += other.trickDecisions
        for (key, count) in other.candidateActions.sorted() {
            candidateActions.add(key, count: count)
        }
        for (key, count) in other.baselineActions.sorted() {
            baselineActions.add(key, count: count)
        }
    }
}

extension PolicyAction {
    var isSwapPhaseAction: Bool {
        switch self {
        case .noSwap, .swap: true
        default: false
        }
    }

    var summary: String {
        switch self {
        case .trump(let suit): "trump_\(suit.shortName)"
        case .noSwap: "swap_pass"
        case .swap: "swap_take"
        case .play(let card): "play_\(card.suit.shortName)_\(card.value)"
        case .assign(let suit): "assign_\(suit.shortName)"
        }
    }

    var detail: String {
        switch self {
        case .trump(let suit):
            "trump \(suit.rawValue)"
        case .noSwap:
            "pass swap"
        case .swap(let handCard, let plotCard, let revealed):
            "swap hand \(handCard.shortName) with \(revealed ? "revealed" : "hidden") \(plotCard.shortName)"
        case .play(let card):
            "play \(card.shortName)"
        case .assign(let suit):
            "assign trick to \(suit.rawValue)"
        }
    }
}

extension Suit {
    var shortName: String {
        switch self {
        case .wheat: "W"
        case .sunflower: "S"
        case .potato: "P"
        case .beet: "B"
        }
    }
}

extension Card {
    var shortName: String {
        "\(suit.shortName)\(value)"
    }
}

do {
    try main()
} catch {
    fputs("KolkhozPolicyDiagnostics failed: \(error)\n", stderr)
    exit(1)
}
