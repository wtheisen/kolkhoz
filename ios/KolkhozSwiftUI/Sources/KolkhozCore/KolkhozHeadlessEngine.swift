import Foundation
import KolkhozCEngine

public enum KolkhozEngineActionKind: Int32, Codable, Sendable {
    case setTrump = 1
    case swap = 2
    case confirmSwap = 3
    case playCard = 4
    case assign = 5
    case submitAssignments = 6
    case continueAfterRequisition = 7
}

public struct KolkhozEngineCard: Codable, Hashable, Sendable {
    public var suit: Int32
    public var value: Int32

    public init(suit: Int32, value: Int32) {
        self.suit = suit
        self.value = value
    }

    public static let none = KolkhozEngineCard(suit: -1, value: 0)
}

public struct KolkhozEngineAction: Codable, Hashable, Sendable {
    public var kind: KolkhozEngineActionKind
    public var playerID: Int32
    public var suit: Int32
    public var card: KolkhozEngineCard
    public var handCard: KolkhozEngineCard
    public var plotCard: KolkhozEngineCard
    public var plotZone: Int32
    public var targetSuit: Int32

    public init(
        kind: KolkhozEngineActionKind,
        playerID: Int32 = -1,
        suit: Int32 = -1,
        card: KolkhozEngineCard = .none,
        handCard: KolkhozEngineCard = .none,
        plotCard: KolkhozEngineCard = .none,
        plotZone: Int32 = -1,
        targetSuit: Int32 = -1
    ) {
        self.kind = kind
        self.playerID = playerID
        self.suit = suit
        self.card = card
        self.handCard = handCard
        self.plotCard = plotCard
        self.plotZone = plotZone
        self.targetSuit = targetSuit
    }
}

public struct KolkhozEnginePlayerSnapshot: Equatable, Sendable {
    public var id: Int32
    public var hand: [KolkhozEngineCard]
    public var revealedPlot: [KolkhozEngineCard]
    public var hiddenPlot: [KolkhozEngineCard]
    public var medals: Int32
    public var bankedMedals: Int32
    public var brigadeLeader: Bool
    public var wonTrickThisYear: Bool
    public var stacks: [KolkhozEnginePlotStackSnapshot]
}

public struct KolkhozEnginePlotStackSnapshot: Equatable, Sendable {
    public var revealed: [KolkhozEngineCard]
    public var hidden: [KolkhozEngineCard]
}

public struct KolkhozEngineTrickPlaySnapshot: Equatable, Sendable {
    public var playerID: Int32
    public var card: KolkhozEngineCard
}

public struct KolkhozEngineSuitCardsSnapshot: Equatable, Sendable {
    public var suit: Int32
    public var cards: [KolkhozEngineCard]
}

public struct KolkhozEngineSuitValueSnapshot: Equatable, Sendable {
    public var suit: Int32
    public var value: Int32
}

public struct KolkhozEngineAssignmentSnapshot: Equatable, Sendable {
    public var card: KolkhozEngineCard
    public var targetSuit: Int32
}

public struct KolkhozEngineRequisitionSnapshot: Equatable, Sendable {
    public var playerID: Int32
    public var suit: Int32
    public var card: KolkhozEngineCard
    public var message: String
}

public struct KolkhozEngineScoreSnapshot: Equatable, Sendable {
    public var playerID: Int32
    public var visibleScore: Int32
    public var finalScore: Int32
}

public struct KolkhozEngineSnapshot: Equatable, Sendable {
    public var year: Int32
    public var phase: Int32
    public var currentPlayer: Int32
    public var lead: Int32
    public var trumpSelector: Int32
    public var trump: Int32
    public var trickCount: Int32
    public var isFamine: Bool
    public var players: [KolkhozEnginePlayerSnapshot]
    public var jobPiles: [KolkhozEngineSuitCardsSnapshot]
    public var revealedJobs: [KolkhozEngineSuitCardsSnapshot]
    public var claimedJobs: [Int32]
    public var workHours: [KolkhozEngineSuitValueSnapshot]
    public var jobBuckets: [KolkhozEngineSuitCardsSnapshot]
    public var accumulatedJobCards: [KolkhozEngineSuitCardsSnapshot]
    public var currentTrick: [KolkhozEngineTrickPlaySnapshot]
    public var lastTrick: [KolkhozEngineTrickPlaySnapshot]
    public var lastWinner: Int32
    public var exiled: [KolkhozEngineSuitCardsSnapshot]
    public var pendingAssignments: [KolkhozEngineAssignmentSnapshot]
    public var requisitionEvents: [KolkhozEngineRequisitionSnapshot]
    public var scores: [KolkhozEngineScoreSnapshot]
    public var winnerID: Int32

    public init(engine: KolkhozEngine) {
        let state = engine.state
        year = Int32(state.year)
        phase = state.phase.engineCode
        currentPlayer = Int32(state.currentPlayer)
        lead = Int32(state.lead)
        trumpSelector = Int32(state.trumpSelector)
        trump = state.trump?.engineCode ?? -1
        trickCount = Int32(state.trickCount)
        isFamine = state.isFamine
        players = state.players.map { player in
            KolkhozEnginePlayerSnapshot(
                id: Int32(player.id),
                hand: player.hand.map(\.engineCard),
                revealedPlot: player.plot.revealed.map(\.engineCard),
                hiddenPlot: player.plot.hidden.map(\.engineCard),
                medals: Int32(player.medals),
                bankedMedals: Int32(player.plot.medals),
                brigadeLeader: player.brigadeLeader,
                wonTrickThisYear: player.hasWonTrickThisYear,
                stacks: player.plot.stacks.map { stack in
                    KolkhozEnginePlotStackSnapshot(
                        revealed: stack.revealed.map(\.engineCard),
                        hidden: stack.hidden.map(\.engineCard)
                    )
                }
            )
        }
        jobPiles = Self.suitCards(from: state.jobPiles)
        revealedJobs = Suit.allCases.map { suit in
            KolkhozEngineSuitCardsSnapshot(suit: suit.engineCode, cards: state.revealedJobs[suit].map { [$0.engineCard] } ?? [])
        }
        claimedJobs = Suit.allCases.filter { state.claimedJobs.contains($0) }.map(\.engineCode)
        workHours = Suit.allCases.map { suit in
            KolkhozEngineSuitValueSnapshot(suit: suit.engineCode, value: Int32(state.workHours[suit, default: 0]))
        }
        jobBuckets = Self.suitCards(from: state.jobBuckets)
        accumulatedJobCards = Self.suitCards(from: state.accumulatedJobCards)
        currentTrick = state.currentTrick.map(\.engineSnapshot)
        lastTrick = state.lastTrick.map(\.engineSnapshot)
        lastWinner = Int32(state.lastWinner ?? -1)
        exiled = state.exiled.keys.sorted().map { year in
            KolkhozEngineSuitCardsSnapshot(
                suit: Int32(year),
                cards: state.exiled[year, default: []].map(\.engineCard)
            )
        }
        pendingAssignments = state.lastTrick.compactMap { play in
            guard let target = state.pendingAssignments[play.card.id] else { return nil }
            return KolkhozEngineAssignmentSnapshot(card: play.card.engineCard, targetSuit: target.engineCode)
        }
        requisitionEvents = state.requisitionEvents.map { event in
            KolkhozEngineRequisitionSnapshot(
                playerID: Int32(event.playerID ?? -1),
                suit: event.suit.engineCode,
                card: event.card?.engineCard ?? .none,
                message: event.message
            )
        }
        scores = state.players.map { player in
            KolkhozEngineScoreSnapshot(
                playerID: Int32(player.id),
                visibleScore: Int32(engine.visibleScore(for: player.id)),
                finalScore: Int32(engine.finalScore(for: player.id))
            )
        }
        winnerID = Int32(state.gameResult?.winnerID ?? -1)
    }

    init(cEngine: KCEngine) {
        var engine = cEngine
        year = engine.year
        phase = engine.phase
        currentPlayer = engine.current_player
        lead = engine.lead
        trumpSelector = engine.trump_selector
        trump = engine.trump
        trickCount = engine.trick_count
        isFamine = engine.is_famine
        players = withUnsafePointer(to: &engine.players) { pointer in
            pointer.withMemoryRebound(to: KCPlayer.self, capacity: Int(KC_PLAYER_COUNT)) { playerPointer in
                (0..<Int(KC_PLAYER_COUNT)).map { index in
                    var player = playerPointer[index]
                    return KolkhozEnginePlayerSnapshot(
                        id: player.id,
                        hand: Self.cards(from: &player.hand),
                        revealedPlot: Self.cards(from: &player.plot_revealed),
                        hiddenPlot: Self.cards(from: &player.plot_hidden),
                        medals: player.medals,
                        bankedMedals: player.plot_medals,
                        brigadeLeader: player.brigade_leader,
                        wonTrickThisYear: player.has_won_trick_this_year,
                        stacks: Self.stacks(from: &player)
                    )
                }
            }
        }
        jobPiles = Self.suitCards(from: &engine.job_piles)
        revealedJobs = Self.revealedJobs(from: &engine)
        claimedJobs = (0..<Int(KC_SUIT_COUNT)).compactMap { engine.claimedJob(at: $0) ? Int32($0) : nil }
        workHours = (0..<Int(KC_SUIT_COUNT)).map { suit in
            KolkhozEngineSuitValueSnapshot(suit: Int32(suit), value: engine.workHour(at: suit))
        }
        jobBuckets = Self.suitCards(from: &engine.job_buckets)
        accumulatedJobCards = Self.suitCards(from: &engine.accumulated_job_cards)
        currentTrick = Self.trickPlays(from: &engine.current_trick, count: Int(engine.current_trick_count))
        lastTrick = Self.trickPlays(from: &engine.last_trick, count: Int(engine.last_trick_count))
        lastWinner = engine.last_winner
        exiled = withUnsafePointer(to: &engine.exiled) { pointer in
            pointer.withMemoryRebound(to: KCCardList.self, capacity: Int(KC_MAX_YEARS + 1)) { listPointer in
                (0...Int(KC_MAX_YEARS)).map { year in
                    var list = listPointer[year]
                    return KolkhozEngineSuitCardsSnapshot(suit: Int32(year), cards: Self.cards(from: &list))
                }
            }
        }.filter { !$0.cards.isEmpty }
        pendingAssignments = (0..<Int(engine.last_trick_count)).compactMap { index in
            let target = engine.pendingAssignmentTarget(at: index)
            guard target >= 0 else { return nil }
            let play = Self.trickPlay(from: engine.trickPlay(at: index, inLastTrick: true))
            return KolkhozEngineAssignmentSnapshot(card: play.card, targetSuit: target)
        }
        requisitionEvents = Self.requisitionEvents(from: &engine)
        scores = (0..<Int(KC_PLAYER_COUNT)).map { playerID in
            KolkhozEngineScoreSnapshot(
                playerID: Int32(playerID),
                visibleScore: kc_visible_score(&engine, Int32(playerID)),
                finalScore: kc_final_score(&engine, Int32(playerID))
            )
        }
        winnerID = engine.winner_id
    }

    public var compactTrace: String {
        let handCounts = players.map { "\($0.id):\($0.hand.count)" }.joined(separator: ",")
        let work = workHours.map { "\($0.suit):\($0.value)" }.joined(separator: ",")
        return "y=\(year) p=\(phase) cp=\(currentPlayer) lead=\(lead) trump=\(trump) trick=\(trickCount) hands=[\(handCounts)] work=[\(work)] winner=\(winnerID)"
    }

    private static func suitCards(from cardsBySuit: [Suit: [Card]]) -> [KolkhozEngineSuitCardsSnapshot] {
        Suit.allCases.map { suit in
            KolkhozEngineSuitCardsSnapshot(
                suit: suit.engineCode,
                cards: cardsBySuit[suit, default: []].map(\.engineCard)
            )
        }
    }

    private static func cards(from list: inout KCCardList) -> [KolkhozEngineCard] {
        withUnsafePointer(to: &list.cards) { pointer in
            pointer.withMemoryRebound(to: KCCard.self, capacity: Int(KC_MAX_CARDS)) { cardPointer in
                (0..<Int(list.count)).map { index in
                    KolkhozEngineCard(cCard: cardPointer[index])
                }
            }
        }
    }

    private static func stacks(from player: inout KCPlayer) -> [KolkhozEnginePlotStackSnapshot] {
        withUnsafePointer(to: &player.stacks) { pointer in
            pointer.withMemoryRebound(to: KCPlotStack.self, capacity: Int(KC_MAX_STACKS)) { stackPointer in
                (0..<Int(player.stack_count)).map { index in
                    var stack = stackPointer[index]
                    let revealed = withUnsafePointer(to: &stack.revealed) { cardPointer in
                        cardPointer.withMemoryRebound(to: KCCard.self, capacity: Int(KC_MAX_CARDS)) { rebound in
                            (0..<Int(stack.revealed_count)).map { KolkhozEngineCard(cCard: rebound[$0]) }
                        }
                    }
                    let hidden = withUnsafePointer(to: &stack.hidden) { cardPointer in
                        cardPointer.withMemoryRebound(to: KCCard.self, capacity: Int(KC_MAX_CARDS)) { rebound in
                            (0..<Int(stack.hidden_count)).map { KolkhozEngineCard(cCard: rebound[$0]) }
                        }
                    }
                    return KolkhozEnginePlotStackSnapshot(revealed: revealed, hidden: hidden)
                }
            }
        }
    }

    private static func suitCards(from tuple: inout (KCCardList, KCCardList, KCCardList, KCCardList)) -> [KolkhozEngineSuitCardsSnapshot] {
        withUnsafePointer(to: &tuple) { pointer in
            pointer.withMemoryRebound(to: KCCardList.self, capacity: Int(KC_SUIT_COUNT)) { listPointer in
                (0..<Int(KC_SUIT_COUNT)).map { suit in
                    var list = listPointer[suit]
                    return KolkhozEngineSuitCardsSnapshot(suit: Int32(suit), cards: cards(from: &list))
                }
            }
        }
    }

    private static func revealedJobs(from engine: inout KCEngine) -> [KolkhozEngineSuitCardsSnapshot] {
        (0..<Int(KC_SUIT_COUNT)).map { suit in
            guard engine.hasRevealedJob(at: suit) else {
                return KolkhozEngineSuitCardsSnapshot(suit: Int32(suit), cards: [])
            }
            return KolkhozEngineSuitCardsSnapshot(
                suit: Int32(suit),
                cards: [KolkhozEngineCard(cCard: engine.revealedJob(at: suit))]
            )
        }
    }

    private static func trickPlays(from tuple: inout (KCTrickPlay, KCTrickPlay, KCTrickPlay, KCTrickPlay), count: Int) -> [KolkhozEngineTrickPlaySnapshot] {
        withUnsafePointer(to: &tuple) { pointer in
            pointer.withMemoryRebound(to: KCTrickPlay.self, capacity: Int(KC_PLAYER_COUNT)) { playPointer in
                (0..<count).map { index in
                    trickPlay(from: playPointer[index])
                }
            }
        }
    }

    private static func trickPlay(from play: KCTrickPlay) -> KolkhozEngineTrickPlaySnapshot {
        KolkhozEngineTrickPlaySnapshot(
            playerID: play.player_id,
            card: KolkhozEngineCard(cCard: play.card)
        )
    }

    private static func requisitionEvents(from engine: inout KCEngine) -> [KolkhozEngineRequisitionSnapshot] {
        withUnsafePointer(to: &engine.requisition_events) { pointer in
            pointer.withMemoryRebound(to: KCRequisitionEvent.self, capacity: Int(KC_MAX_CARDS)) { eventPointer in
                (0..<Int(engine.requisition_event_count)).map { index in
                    let event = eventPointer[index]
                    return KolkhozEngineRequisitionSnapshot(
                        playerID: event.player_id,
                        suit: event.suit,
                        card: KolkhozEngineCard(cCard: event.card),
                        message: Self.requisitionMessage(for: event)
                    )
                }
            }
        }
    }

    private static func requisitionMessage(for event: KCRequisitionEvent) -> String {
        let suit = Suit(engineCode: event.suit)?.rawValue ?? "Wheat"
        let card = Card(engineCard: KolkhozEngineCard(cCard: event.card))
        switch event.message_kind {
        case 1:
            let name = event.player_id >= 0 ? "Player \(event.player_id + 1)" : "Player"
            let rank = card?.rank ?? ""
            return "\(name) sends \(rank) \(suit) north"
        case 2:
            return "\(suit) failed; no vulnerable matching cards"
        case 3:
            let rank = card?.rank ?? ""
            let cardSuit = card?.suit.rawValue ?? suit
            return "Drunkard \(rank) \(cardSuit) goes north"
        case 4:
            let name = event.player_id >= 0 ? "Player \(event.player_id + 1)" : "Player"
            return "\(name) is immune after winning every trick"
        default:
            return ""
        }
    }
}

public final class KolkhozHeadlessEngine {
    public static let allHumanControllers: [PlayerController] = [.human, .human, .human, .human]

    private var engine: KCEngine

    public init(
        seed: UInt64,
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = KolkhozHeadlessEngine.allHumanControllers
    ) {
        let cVariants = variants.cVariants
        var cEngine = KCEngine()
        kc_engine_init(&cEngine, seed, cVariants)
        engine = cEngine
    }

    public var phaseCode: Int32 { engine.phase }
    public var snapshot: KolkhozEngineSnapshot { KolkhozEngineSnapshot(cEngine: engine) }

    public func legalActions() -> [KolkhozEngineAction] {
        var cEngine = engine
        var actions = Array(repeating: KCAction(), count: 256)
        let count = kc_engine_legal_actions(&cEngine, &actions, Int32(actions.count))
        return actions.prefix(Int(count)).map(KolkhozEngineAction.init(cAction:))
    }

    public func apply(_ action: KolkhozEngineAction) throws {
        let result = kc_engine_apply(&engine, action.cAction)
        if result != 0 {
            throw KolkhozMoveError(cError: result)
        }
    }

    public static func legalActions(for engine: KolkhozEngine) -> [KolkhozEngineAction] {
        let state = engine.state
        switch state.phase {
        case .planning:
            guard !state.isFamine else { return [] }
            return Suit.allCases.map { suit in
                KolkhozEngineAction(kind: .setTrump, playerID: Int32(state.currentPlayer), suit: suit.engineCode)
            }

        case .swap:
            guard state.players.indices.contains(state.currentPlayer) else { return [] }
            let playerID = state.currentPlayer
            var actions: [KolkhozEngineAction] = []
            if !state.swapCount.contains(playerID) {
                let hand = state.players[playerID].hand
                for handCard in hand {
                    for plotCard in state.players[playerID].plot.hidden {
                        actions.append(KolkhozEngineAction(
                            kind: .swap,
                            playerID: Int32(playerID),
                            handCard: handCard.engineCard,
                            plotCard: plotCard.engineCard,
                            plotZone: PlotCardZone.hidden.engineCode
                        ))
                    }
                    for plotCard in state.players[playerID].plot.revealed {
                        actions.append(KolkhozEngineAction(
                            kind: .swap,
                            playerID: Int32(playerID),
                            handCard: handCard.engineCard,
                            plotCard: plotCard.engineCard,
                            plotZone: PlotCardZone.revealed.engineCode
                        ))
                    }
                }
            }
            actions.append(KolkhozEngineAction(kind: .confirmSwap, playerID: Int32(playerID)))
            return actions

        case .trick:
            let playerID = state.currentPlayer
            return engine.validCardsForHuman(playerID: playerID)
                .sortedByCard()
                .map { card in
                    KolkhozEngineAction(kind: .playCard, playerID: Int32(playerID), card: card.engineCard)
                }

        case .assignment:
            guard let winner = state.lastWinner else { return [] }
            if state.pendingAssignments.count >= state.lastTrick.count {
                return [KolkhozEngineAction(kind: .submitAssignments, playerID: Int32(winner))]
            }
            guard let play = state.lastTrick.first(where: { state.pendingAssignments[$0.card.id] == nil }) else {
                return [KolkhozEngineAction(kind: .submitAssignments, playerID: Int32(winner))]
            }
            let legalSuits = Suit.allCases.filter { suit in
                state.lastTrick.contains { $0.card.suit == suit }
            }
            return legalSuits.map { suit in
                KolkhozEngineAction(
                    kind: .assign,
                    playerID: Int32(winner),
                    card: play.card.engineCard,
                    targetSuit: suit.engineCode
                )
            }

        case .requisition:
            return [KolkhozEngineAction(kind: .continueAfterRequisition, playerID: 0)]

        case .gameOver:
            return []
        }
    }

    public static func apply(_ action: KolkhozEngineAction, to engine: KolkhozEngine) throws {
        let playerID = Int(action.playerID)
        switch action.kind {
        case .setTrump:
            guard let suit = Suit(engineCode: action.suit) else { throw KolkhozMoveError.invalidCard }
            try engine.setTrump(suit, playerID: playerID)

        case .swap:
            guard let handCard = Card(engineCard: action.handCard),
                  let plotCard = Card(engineCard: action.plotCard),
                  let zone = PlotCardZone(engineCode: action.plotZone) else {
                throw KolkhozMoveError.invalidCard
            }
            try engine.swap(handCard: handCard, plotCard: plotCard, revealed: zone == .revealed, playerID: playerID)

        case .confirmSwap:
            try engine.confirmSwap(playerID: playerID)

        case .playCard:
            guard let card = Card(engineCard: action.card) else { throw KolkhozMoveError.invalidCard }
            try engine.playCard(card, playerID: playerID)

        case .assign:
            guard let card = Card(engineCard: action.card),
                  let targetSuit = Suit(engineCode: action.targetSuit) else {
                throw KolkhozMoveError.invalidAssignment
            }
            try engine.assign(card: card, to: targetSuit, playerID: playerID)

        case .submitAssignments:
            try engine.submitAssignments(playerID: playerID)

        case .continueAfterRequisition:
            engine.continueAfterRequisition()
        }
    }
}

private extension Suit {
    var engineCode: Int32 {
        switch self {
        case .wheat: 0
        case .sunflower: 1
        case .potato: 2
        case .beet: 3
        }
    }

    init?(engineCode: Int32) {
        switch engineCode {
        case 0: self = .wheat
        case 1: self = .sunflower
        case 2: self = .potato
        case 3: self = .beet
        default: return nil
        }
    }
}

private extension GameVariants {
    var cVariants: KCVariants {
        KCVariants(
            deck_type: Int32(deckType),
            nomenclature: nomenclature,
            allow_swap: allowSwap,
            northern_style: northernStyle,
            mice_variant: miceVariant,
            orden_nachalniku: ordenNachalniku,
            medals_count: medalsCount,
            accumulate_jobs: accumulateJobs,
            hero_of_soviet_union: heroOfSovietUnion
        )
    }
}

private extension GamePhase {
    var engineCode: Int32 {
        switch self {
        case .planning: 0
        case .swap: 1
        case .trick: 2
        case .assignment: 3
        case .requisition: 4
        case .gameOver: 5
        }
    }
}

private extension KolkhozEngineAction {
    init(cAction: KCAction) {
        self.init(
            kind: KolkhozEngineActionKind(rawValue: cAction.kind) ?? .continueAfterRequisition,
            playerID: cAction.player_id,
            suit: cAction.suit,
            card: KolkhozEngineCard(cCard: cAction.card),
            handCard: KolkhozEngineCard(cCard: cAction.hand_card),
            plotCard: KolkhozEngineCard(cCard: cAction.plot_card),
            plotZone: cAction.plot_zone,
            targetSuit: cAction.target_suit
        )
    }

    var cAction: KCAction {
        KCAction(
            kind: kind.rawValue,
            player_id: playerID,
            suit: suit,
            card: card.cCard,
            hand_card: handCard.cCard,
            plot_card: plotCard.cCard,
            plot_zone: plotZone,
            target_suit: targetSuit
        )
    }
}

private extension KolkhozEngineCard {
    init(cCard: KCCard) {
        self.init(suit: cCard.suit, value: cCard.value)
    }

    var cCard: KCCard {
        KCCard(suit: suit, value: value)
    }
}

private extension KolkhozMoveError {
    init(cError: Int32) {
        switch cError {
        case 1: self = .wrongPhase
        case 2: self = .wrongPlayer
        case 4: self = .invalidAssignment
        default: self = .invalidCard
        }
    }
}

private extension KCEngine {
    mutating func hasRevealedJob(at index: Int) -> Bool {
        withUnsafePointer(to: &has_revealed_job) { pointer in
            pointer.withMemoryRebound(to: Bool.self, capacity: Int(KC_SUIT_COUNT)) { $0[index] }
        }
    }

    mutating func revealedJob(at index: Int) -> KCCard {
        withUnsafePointer(to: &revealed_jobs) { pointer in
            pointer.withMemoryRebound(to: KCCard.self, capacity: Int(KC_SUIT_COUNT)) { $0[index] }
        }
    }

    mutating func claimedJob(at index: Int) -> Bool {
        withUnsafePointer(to: &claimed_jobs) { pointer in
            pointer.withMemoryRebound(to: Bool.self, capacity: Int(KC_SUIT_COUNT)) { $0[index] }
        }
    }

    mutating func workHour(at index: Int) -> Int32 {
        withUnsafePointer(to: &work_hours) { pointer in
            pointer.withMemoryRebound(to: Int32.self, capacity: Int(KC_SUIT_COUNT)) { $0[index] }
        }
    }

    mutating func pendingAssignmentTarget(at index: Int) -> Int32 {
        withUnsafePointer(to: &pending_assignment_targets) { pointer in
            pointer.withMemoryRebound(to: Int32.self, capacity: Int(KC_PLAYER_COUNT)) { $0[index] }
        }
    }

    mutating func trickPlay(at index: Int, inLastTrick: Bool) -> KCTrickPlay {
        if inLastTrick {
            return withUnsafePointer(to: &last_trick) { pointer in
                pointer.withMemoryRebound(to: KCTrickPlay.self, capacity: Int(KC_PLAYER_COUNT)) { $0[index] }
            }
        }
        return withUnsafePointer(to: &current_trick) { pointer in
            pointer.withMemoryRebound(to: KCTrickPlay.self, capacity: Int(KC_PLAYER_COUNT)) { $0[index] }
        }
    }
}

private extension PlotCardZone {
    var engineCode: Int32 {
        switch self {
        case .hidden: 0
        case .revealed: 1
        }
    }

    init?(engineCode: Int32) {
        switch engineCode {
        case 0: self = .hidden
        case 1: self = .revealed
        default: return nil
        }
    }
}

private extension Card {
    var engineCard: KolkhozEngineCard {
        KolkhozEngineCard(suit: suit.engineCode, value: Int32(value))
    }

    init?(engineCard: KolkhozEngineCard) {
        guard let suit = Suit(engineCode: engineCard.suit), engineCard.value > 0 else { return nil }
        self.init(suit: suit, value: Int(engineCard.value))
    }
}

private extension TrickPlay {
    var engineSnapshot: KolkhozEngineTrickPlaySnapshot {
        KolkhozEngineTrickPlaySnapshot(playerID: Int32(playerID), card: card.engineCard)
    }
}

private extension Sequence where Element == Card {
    func sortedByCard() -> [Card] {
        sorted { lhs, rhs in
            if lhs.suit.engineCode == rhs.suit.engineCode {
                return lhs.value < rhs.value
            }
            return lhs.suit.engineCode < rhs.suit.engineCode
        }
    }
}
