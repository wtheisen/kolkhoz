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
    case undoSwap = 8
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

public struct KolkhozEnginePlayerSnapshot: Codable, Equatable, Sendable {
    public var id: Int32
    public var hand: [KolkhozEngineCard]
    public var revealedPlot: [KolkhozEngineCard]
    public var hiddenPlot: [KolkhozEngineCard]
    public var medals: Int32
    public var bankedMedals: Int32
    public var brigadeLeader: Bool
    public var wonTrickThisYear: Bool
    public var stacks: [KolkhozEnginePlotStackSnapshot]

    public init(
        id: Int32,
        hand: [KolkhozEngineCard],
        revealedPlot: [KolkhozEngineCard],
        hiddenPlot: [KolkhozEngineCard],
        medals: Int32,
        bankedMedals: Int32,
        brigadeLeader: Bool,
        wonTrickThisYear: Bool,
        stacks: [KolkhozEnginePlotStackSnapshot]
    ) {
        self.id = id
        self.hand = hand
        self.revealedPlot = revealedPlot
        self.hiddenPlot = hiddenPlot
        self.medals = medals
        self.bankedMedals = bankedMedals
        self.brigadeLeader = brigadeLeader
        self.wonTrickThisYear = wonTrickThisYear
        self.stacks = stacks
    }
}

public struct KolkhozEnginePlotStackSnapshot: Codable, Equatable, Sendable {
    public var revealed: [KolkhozEngineCard]
    public var hidden: [KolkhozEngineCard]

    public init(revealed: [KolkhozEngineCard], hidden: [KolkhozEngineCard]) {
        self.revealed = revealed
        self.hidden = hidden
    }
}

public struct KolkhozEngineTrickPlaySnapshot: Codable, Equatable, Sendable {
    public var playerID: Int32
    public var card: KolkhozEngineCard

    public init(playerID: Int32, card: KolkhozEngineCard) {
        self.playerID = playerID
        self.card = card
    }
}

public struct KolkhozEngineSuitCardsSnapshot: Codable, Equatable, Sendable {
    public var suit: Int32
    public var cards: [KolkhozEngineCard]

    public init(suit: Int32, cards: [KolkhozEngineCard]) {
        self.suit = suit
        self.cards = cards
    }
}

public struct KolkhozEngineSuitValueSnapshot: Codable, Equatable, Sendable {
    public var suit: Int32
    public var value: Int32

    public init(suit: Int32, value: Int32) {
        self.suit = suit
        self.value = value
    }
}

public struct KolkhozEngineAssignmentSnapshot: Codable, Equatable, Sendable {
    public var card: KolkhozEngineCard
    public var targetSuit: Int32

    public init(card: KolkhozEngineCard, targetSuit: Int32) {
        self.card = card
        self.targetSuit = targetSuit
    }
}

public struct KolkhozEngineRequisitionSnapshot: Codable, Equatable, Sendable {
    public var playerID: Int32
    public var suit: Int32
    public var card: KolkhozEngineCard
    public var message: String

    public init(playerID: Int32, suit: Int32, card: KolkhozEngineCard, message: String) {
        self.playerID = playerID
        self.suit = suit
        self.card = card
        self.message = message
    }
}

public struct KolkhozEngineScoreSnapshot: Codable, Equatable, Sendable {
    public var playerID: Int32
    public var visibleScore: Int32
    public var finalScore: Int32

    public init(playerID: Int32, visibleScore: Int32, finalScore: Int32) {
        self.playerID = playerID
        self.visibleScore = visibleScore
        self.finalScore = finalScore
    }
}

public struct KolkhozEngineSwapSnapshot: Codable, Equatable, Sendable {
    public var playerID: Int32
    public var plotZone: Int32
    public var plotIndex: Int32
    public var handIndex: Int32
    public var newPlotCard: KolkhozEngineCard

    public init(playerID: Int32, plotZone: Int32, plotIndex: Int32, handIndex: Int32, newPlotCard: KolkhozEngineCard) {
        self.playerID = playerID
        self.plotZone = plotZone
        self.plotIndex = plotIndex
        self.handIndex = handIndex
        self.newPlotCard = newPlotCard
    }
}

public struct KolkhozEngineSnapshot: Codable, Equatable, Sendable {
    public var year: Int32
    public var phase: Int32
    public var currentPlayer: Int32
    public var waitingPlayer: Int32
    public var waitingForExternalAction: Bool
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
    public var swapConfirmed: [Int32]
    public var swapCount: [Int32]
    public var lastSwap: KolkhozEngineSwapSnapshot?

    public init(
        year: Int32,
        phase: Int32,
        currentPlayer: Int32,
        waitingPlayer: Int32,
        waitingForExternalAction: Bool,
        lead: Int32,
        trumpSelector: Int32,
        trump: Int32,
        trickCount: Int32,
        isFamine: Bool,
        players: [KolkhozEnginePlayerSnapshot],
        jobPiles: [KolkhozEngineSuitCardsSnapshot],
        revealedJobs: [KolkhozEngineSuitCardsSnapshot],
        claimedJobs: [Int32],
        workHours: [KolkhozEngineSuitValueSnapshot],
        jobBuckets: [KolkhozEngineSuitCardsSnapshot],
        accumulatedJobCards: [KolkhozEngineSuitCardsSnapshot],
        currentTrick: [KolkhozEngineTrickPlaySnapshot],
        lastTrick: [KolkhozEngineTrickPlaySnapshot],
        lastWinner: Int32,
        exiled: [KolkhozEngineSuitCardsSnapshot],
        pendingAssignments: [KolkhozEngineAssignmentSnapshot],
        requisitionEvents: [KolkhozEngineRequisitionSnapshot],
        scores: [KolkhozEngineScoreSnapshot],
        winnerID: Int32,
        swapConfirmed: [Int32],
        swapCount: [Int32],
        lastSwap: KolkhozEngineSwapSnapshot?
    ) {
        self.year = year
        self.phase = phase
        self.currentPlayer = currentPlayer
        self.waitingPlayer = waitingPlayer
        self.waitingForExternalAction = waitingForExternalAction
        self.lead = lead
        self.trumpSelector = trumpSelector
        self.trump = trump
        self.trickCount = trickCount
        self.isFamine = isFamine
        self.players = players
        self.jobPiles = jobPiles
        self.revealedJobs = revealedJobs
        self.claimedJobs = claimedJobs
        self.workHours = workHours
        self.jobBuckets = jobBuckets
        self.accumulatedJobCards = accumulatedJobCards
        self.currentTrick = currentTrick
        self.lastTrick = lastTrick
        self.lastWinner = lastWinner
        self.exiled = exiled
        self.pendingAssignments = pendingAssignments
        self.requisitionEvents = requisitionEvents
        self.scores = scores
        self.winnerID = winnerID
        self.swapConfirmed = swapConfirmed
        self.swapCount = swapCount
        self.lastSwap = lastSwap
    }

    init(cEngine: KCEngine) {
        var engine = cEngine
        year = engine.year
        phase = engine.phase
        currentPlayer = engine.current_player
        waitingPlayer = kc_engine_waiting_player(&engine)
        waitingForExternalAction = kc_engine_waiting_for_external_action(&engine)
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
        swapConfirmed = (0..<Int(KC_PLAYER_COUNT)).compactMap { engine.swapConfirmed(at: $0) ? Int32($0) : nil }
        swapCount = (0..<Int(KC_PLAYER_COUNT)).compactMap { engine.swapCount(at: $0) ? Int32($0) : nil }
        if engine.has_last_swap {
            lastSwap = KolkhozEngineSwapSnapshot(
                playerID: engine.last_swap_player_id,
                plotZone: engine.last_swap_plot_zone,
                plotIndex: engine.last_swap_plot_index,
                handIndex: engine.last_swap_hand_index,
                newPlotCard: KolkhozEngineCard(cCard: engine.last_swap_new_plot_card)
            )
        } else {
            lastSwap = nil
        }
    }

    public var compactTrace: String {
        let handCounts = players.map { "\($0.id):\($0.hand.count)" }.joined(separator: ",")
        let work = workHours.map { "\($0.suit):\($0.value)" }.joined(separator: ",")
        return "y=\(year) p=\(phase) cp=\(currentPlayer) wait=\(waitingPlayer) external=\(waitingForExternalAction) lead=\(lead) trump=\(trump) trick=\(trickCount) hands=[\(handCounts)] work=[\(work)] winner=\(winnerID)"
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
        let cControllers = controllers.cControllers
        var cEngine = KCEngine()
        kc_engine_init_with_controllers(&cEngine, seed, cVariants, cControllers)
        engine = cEngine
    }

    public var phaseCode: Int32 { engine.phase }
    public var waitingPlayer: Int32 { kc_engine_waiting_player(&engine) }
    public var isWaitingForExternalAction: Bool { kc_engine_waiting_for_external_action(&engine) }
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

}

public struct KolkhozCEngineSavedGame: Codable, Sendable {
    public var version: Int
    public var seed: UInt64
    public var variants: GameVariants
    public var controllers: [PlayerController]
    public var actions: [KolkhozEngineAction]

    public init(
        version: Int = 1,
        seed: UInt64,
        variants: GameVariants,
        controllers: [PlayerController],
        actions: [KolkhozEngineAction] = []
    ) {
        self.version = version
        self.seed = seed
        self.variants = variants
        self.controllers = PlayerController.normalized(controllers)
        self.actions = actions
    }
}

public final class KolkhozCEngineAdapter {
    private var engine: KolkhozHeadlessEngine
    private var seed: UInt64
    private var variants: GameVariants
    private var controllers: [PlayerController]
    private var actions: [KolkhozEngineAction]
    public private(set) var state: KolkhozState

    public init(
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = PlayerController.defaultControllers
    ) {
        self.seed = seed
        self.variants = variants
        self.controllers = PlayerController.normalized(controllers)
        self.actions = []
        self.engine = KolkhozHeadlessEngine(seed: seed, variants: variants, controllers: self.controllers)
        self.state = engine.snapshot.kolkhozState(variants: variants, controllers: self.controllers)
    }

    public convenience init(savedGame: KolkhozCEngineSavedGame) throws {
        self.init(seed: savedGame.seed, variants: savedGame.variants, controllers: savedGame.controllers)
        for action in savedGame.actions {
            try apply(action)
        }
    }

    public var savedGame: KolkhozCEngineSavedGame {
        KolkhozCEngineSavedGame(
            seed: seed,
            variants: variants,
            controllers: controllers,
            actions: actions
        )
    }

    public var snapshot: KolkhozEngineSnapshot {
        engine.snapshot
    }

    public func legalActions() -> [KolkhozEngineAction] {
        engine.legalActions()
    }

    public func newGame(seed: UInt64 = UInt64(Date().timeIntervalSince1970), variants: GameVariants? = nil) {
        self.seed = seed
        if let variants {
            self.variants = variants
        }
        actions = []
        engine = KolkhozHeadlessEngine(seed: seed, variants: self.variants, controllers: controllers)
        sync()
    }

    public func drainAnimationEvents() -> [KolkhozAnimationEvent] {
        []
    }

    public func setTrump(_ suit: Suit, playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(kind: .setTrump, playerID: Int32(playerID ?? state.currentPlayer), suit: suit.engineCode))
    }

    public func playCard(_ card: Card, playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(kind: .playCard, playerID: Int32(playerID ?? state.currentPlayer), card: card.engineCard))
    }

    public func swap(handCard: Card, plotCard: Card, revealed: Bool, playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(
            kind: .swap,
            playerID: Int32(playerID ?? state.currentPlayer),
            handCard: handCard.engineCard,
            plotCard: plotCard.engineCard,
            plotZone: (revealed ? PlotCardZone.revealed : .hidden).engineCode
        ))
    }

    public func undoSwap(playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(kind: .undoSwap, playerID: Int32(playerID ?? state.currentPlayer)))
    }

    public func confirmSwap(playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(kind: .confirmSwap, playerID: Int32(playerID ?? state.currentPlayer)))
    }

    public func assign(card: Card, to suit: Suit, playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(
            kind: .assign,
            playerID: Int32(playerID ?? state.lastWinner ?? state.currentPlayer),
            card: card.engineCard,
            targetSuit: suit.engineCode
        ))
    }

    public func submitAssignments(playerID: Int? = nil) throws {
        try apply(KolkhozEngineAction(
            kind: .submitAssignments,
            playerID: Int32(playerID ?? state.lastWinner ?? state.currentPlayer)
        ))
    }

    public func continueAfterRequisition() {
        try? apply(KolkhozEngineAction(kind: .continueAfterRequisition, playerID: 0))
    }

    public func validCardsForHuman(playerID: Int? = nil) -> Set<Card> {
        let playerID = Int32(playerID ?? state.currentPlayer)
        return Set(engine.legalActions().compactMap { action in
            guard action.kind == .playCard,
                  action.playerID == playerID,
                  let card = Card(engineCard: action.card) else {
                return nil
            }
            return card
        })
    }

    public func visibleScore(for playerID: Int) -> Int {
        Int(engine.snapshot.scores.first { $0.playerID == Int32(playerID) }?.visibleScore ?? 0)
    }

    public func finalScore(for playerID: Int) -> Int {
        Int(engine.snapshot.scores.first { $0.playerID == Int32(playerID) }?.finalScore ?? 0)
    }

    public func apply(_ action: KolkhozEngineAction) throws {
        try engine.apply(action)
        actions.append(action)
        sync()
    }

    private func sync() {
        state = engine.snapshot.kolkhozState(variants: variants, controllers: controllers)
    }
}

public extension KolkhozEngineSnapshot {
    func kolkhozState(variants: GameVariants, controllers: [PlayerController]) -> KolkhozState {
        let normalizedControllers = PlayerController.normalized(controllers)
        let playerStates = players.map { player -> PlayerState in
            let playerID = Int(player.id)
            let isHuman = normalizedControllers.indices.contains(playerID) && normalizedControllers[playerID] == .human
            var state = PlayerState(
                id: playerID,
                name: isHuman ? "Player \(playerID + 1)" : "Bot \(playerID)",
                isHuman: isHuman
            )
            state.hand = player.hand.cards
            state.plot.revealed = player.revealedPlot.cards
            state.plot.hidden = player.hiddenPlot.cards
            state.plot.medals = Int(player.bankedMedals)
            state.plot.stacks = player.stacks.map { stack in
                PlotStack(revealed: stack.revealed.cards, hidden: stack.hidden.cards)
            }
            state.brigadeLeader = player.brigadeLeader
            state.hasWonTrickThisYear = player.wonTrickThisYear
            state.medals = Int(player.medals)
            return state
        }

        var state = KolkhozState(
            players: playerStates,
            lead: Int(lead),
            trumpSelector: Int(trumpSelector),
            variants: variants
        )
        state.year = Int(year)
        state.trump = Suit(engineCode: trump)
        state.jobPiles = jobPiles.cardsBySuit
        state.revealedJobs = Dictionary(uniqueKeysWithValues: revealedJobs.compactMap { entry in
            guard let suit = Suit(engineCode: entry.suit), let card = entry.cards.cards.first else { return nil }
            return (suit, card)
        })
        state.claimedJobs = Set(claimedJobs.compactMap(Suit.init(engineCode:)))
        state.workHours = Dictionary(uniqueKeysWithValues: workHours.compactMap { entry in
            guard let suit = Suit(engineCode: entry.suit) else { return nil }
            return (suit, Int(entry.value))
        })
        state.jobBuckets = jobBuckets.cardsBySuit
        state.currentTrick = currentTrick.compactMap(\.trickPlay)
        state.lastTrick = lastTrick.compactMap(\.trickPlay)
        state.lastWinner = lastWinner >= 0 ? Int(lastWinner) : nil
        state.trickCount = Int(trickCount)
        state.exiled = Dictionary(uniqueKeysWithValues: exiled.map { (Int($0.suit), $0.cards.cards) })
        state.isFamine = isFamine
        state.phase = GamePhase(engineCode: phase) ?? .gameOver
        state.currentPlayer = Int(currentPlayer)
        state.pendingAssignments = Dictionary(uniqueKeysWithValues: pendingAssignments.compactMap { assignment in
            guard let card = Card(engineCard: assignment.card),
                  let suit = Suit(engineCode: assignment.targetSuit) else {
                return nil
            }
            return (card.id, suit)
        })
        state.requisitionEvents = requisitionEvents.map { event in
            RequisitionEvent(
                playerID: event.playerID >= 0 ? Int(event.playerID) : nil,
                suit: Suit(engineCode: event.suit) ?? .wheat,
                card: Card(engineCard: event.card),
                message: event.message
            )
        }
        if winnerID >= 0 {
            state.gameResult = GameResult(
                winnerID: Int(winnerID),
                scores: Dictionary(uniqueKeysWithValues: scores.map { (Int($0.playerID), Int($0.finalScore)) })
            )
        }
        state.accumulatedJobCards = accumulatedJobCards.cardsBySuit
        state.swapConfirmed = Set(swapConfirmed.map(Int.init))
        state.swapCount = Set(swapCount.map(Int.init))
        if let lastSwap,
           let zone = PlotCardZone(engineCode: lastSwap.plotZone),
           let newPlotCard = Card(engineCard: lastSwap.newPlotCard) {
            state.lastSwap = SwapRecord(
                playerID: Int(lastSwap.playerID),
                plotZone: zone,
                plotIndex: Int(lastSwap.plotIndex),
                handIndex: Int(lastSwap.handIndex),
                newPlotCard: newPlotCard
            )
        }
        return state
    }
}

public extension Suit {
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

private extension Array where Element == PlayerController {
    var cControllers: KCControllers {
        var controllers = KCControllers()
        kc_controllers_all_external(&controllers)
        for (index, controller) in PlayerController.normalized(self).enumerated() {
            let cController = Int32(controller == .human ? KC_CONTROLLER_EXTERNAL : KC_CONTROLLER_HEURISTIC_AI)
            kc_controllers_set(&controllers, Int32(index), cController)
        }
        return controllers
    }
}

public extension GamePhase {
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

    init?(engineCode: Int32) {
        switch engineCode {
        case 0: self = .planning
        case 1: self = .swap
        case 2: self = .trick
        case 3: self = .assignment
        case 4: self = .requisition
        case 5: self = .gameOver
        default: return nil
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

    mutating func swapConfirmed(at index: Int) -> Bool {
        withUnsafePointer(to: &swap_confirmed) { pointer in
            pointer.withMemoryRebound(to: Bool.self, capacity: Int(KC_PLAYER_COUNT)) { $0[index] }
        }
    }

    mutating func swapCount(at index: Int) -> Bool {
        withUnsafePointer(to: &swap_count) { pointer in
            pointer.withMemoryRebound(to: Bool.self, capacity: Int(KC_PLAYER_COUNT)) { $0[index] }
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

public extension PlotCardZone {
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

public extension Card {
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

private extension KolkhozEngineTrickPlaySnapshot {
    var trickPlay: TrickPlay? {
        guard let card = Card(engineCard: card) else { return nil }
        return TrickPlay(playerID: Int(playerID), card: card)
    }
}

private extension Array where Element == KolkhozEngineCard {
    var cards: [Card] {
        compactMap(Card.init(engineCard:))
    }
}

private extension Array where Element == KolkhozEngineSuitCardsSnapshot {
    var cardsBySuit: [Suit: [Card]] {
        var result = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, [Card]()) })
        for entry in self {
            guard let suit = Suit(engineCode: entry.suit) else { continue }
            result[suit] = entry.cards.cards
        }
        return result
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
