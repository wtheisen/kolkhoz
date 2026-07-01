import Combine
import Foundation
import KolkhozCore

@MainActor
public final class GameStore: ObservableObject {
    @Published public private(set) var state: KolkhozState
    @Published public private(set) var animationEvents: [KolkhozAnimationEvent] = []
    @Published public private(set) var revealedPlayerID: Int?
    @Published public var lastError: String?

    private var engine: KolkhozEngine

    public init(
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = PlayerController.defaultControllers
    ) {
        let engine = KolkhozEngine(seed: seed, variants: variants, controllers: controllers)
        self.engine = engine
        self.state = engine.state
        self.revealedPlayerID = engine.state.players.filter(\.isHuman).count > 1 ? nil : engine.state.humanPlayer.id
    }

    public init(scriptedState: KolkhozState) {
        let engine = KolkhozEngine(testing: scriptedState)
        self.engine = engine
        self.state = engine.state
        self.revealedPlayerID = engine.state.humanPlayer.id
    }

    #if DEBUG
    public init(previewState: KolkhozState) {
        let engine = KolkhozEngine(testing: previewState)
        self.engine = engine
        self.state = engine.state
    }
    #endif

    public func newGame(variants: GameVariants? = nil, controllers: [PlayerController]? = nil) {
        revealedPlayerID = nil
        if let controllers {
            engine = KolkhozEngine(variants: variants ?? state.variants, controllers: controllers)
        } else {
            engine.newGame(variants: variants)
        }
        animationEvents = []
        sync()
    }

    public func loadScriptedState(_ scriptedState: KolkhozState) {
        engine = KolkhozEngine(testing: scriptedState)
        state = engine.state
        animationEvents = []
        lastError = nil
        revealedPlayerID = engine.state.humanPlayer.id
    }

    public func setTrump(_ suit: Suit) {
        perform { try engine.setTrump(suit, playerID: localPlayerID) }
    }

    public func play(_ card: Card) {
        perform { try engine.playCard(card, playerID: localPlayerID) }
    }

    public func swap(handCard: Card, plotCard: Card, revealed: Bool) {
        perform { try engine.swap(handCard: handCard, plotCard: plotCard, revealed: revealed, playerID: localPlayerID) }
    }

    public func confirmSwap() {
        perform { try engine.confirmSwap(playerID: localPlayerID) }
    }

    public func undoSwap() {
        perform { try engine.undoSwap(playerID: localPlayerID) }
    }

    public func assign(_ card: Card, to suit: Suit) {
        perform { try engine.assign(card: card, to: suit, playerID: localPlayerID) }
    }

    public func submitAssignments() {
        perform { try engine.submitAssignments(playerID: localPlayerID) }
    }

    public func continueAfterRequisition() {
        engine.continueAfterRequisition()
        sync()
    }

    public func visibleScore(for playerID: Int) -> Int {
        engine.visibleScore(for: playerID)
    }

    public func validCardsForHuman() -> Set<Card> {
        engine.validCardsForHuman(playerID: localPlayerID)
    }

    public var localPlayerID: Int {
        if state.players.indices.contains(state.currentPlayer), state.players[state.currentPlayer].isHuman {
            return state.currentPlayer
        }
        if state.phase == .assignment,
           let winner = state.lastWinner,
           state.players.indices.contains(winner),
           state.players[winner].isHuman {
            return winner
        }
        return state.players.first(where: \.isHuman)?.id ?? 0
    }

    public var isHotSeatPrivacyRequired: Bool {
        state.phase != .gameOver &&
            state.players.filter(\.isHuman).count > 1 &&
            revealedPlayerID != localPlayerID
    }

    public func revealLocalPlayer() {
        revealedPlayerID = localPlayerID
        lastError = nil
    }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            lastError = nil
            sync()
        } catch {
            lastError = String(describing: error)
        }
    }

    private func sync() {
        state = engine.state
        animationEvents.append(contentsOf: engine.drainAnimationEvents())
        updateHotSeatReveal()
    }

    private func updateHotSeatReveal() {
        if state.phase == .gameOver || state.players.filter(\.isHuman).count <= 1 {
            revealedPlayerID = localPlayerID
            return
        }
        if let revealedPlayerID,
           state.players.indices.contains(revealedPlayerID),
           state.players[revealedPlayerID].isHuman {
            return
        }
        revealedPlayerID = nil
    }

    public func consumeAnimationEvent(_ id: UUID) {
        animationEvents.removeAll { $0.id == id }
    }
}
