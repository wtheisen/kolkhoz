import Combine
import Foundation
import KolkhozCore

@MainActor
public final class GameStore: ObservableObject {
    @Published public private(set) var state: KolkhozState
    @Published public private(set) var animationEvents: [KolkhozAnimationEvent] = []
    @Published public var lastError: String?

    private var engine: KolkhozEngine

    public init(seed: UInt64 = UInt64(Date().timeIntervalSince1970), variants: GameVariants = .kolkhoz) {
        let engine = KolkhozEngine(seed: seed, variants: variants)
        self.engine = engine
        self.state = engine.state
    }

    public func newGame(variants: GameVariants? = nil) {
        engine.newGame(variants: variants)
        animationEvents = []
        sync()
    }

    public func setTrump(_ suit: Suit) {
        perform { try engine.setTrump(suit) }
    }

    public func play(_ card: Card) {
        perform { try engine.playCard(card) }
    }

    public func swap(handCard: Card, plotCard: Card, revealed: Bool) {
        perform { try engine.swap(handCard: handCard, plotCard: plotCard, revealed: revealed) }
    }

    public func confirmSwap() {
        perform { try engine.confirmSwap() }
    }

    public func undoSwap() {
        perform { try engine.undoSwap() }
    }

    public func assign(_ card: Card, to suit: Suit) {
        perform { try engine.assign(card: card, to: suit) }
    }

    public func submitAssignments() {
        perform { try engine.submitAssignments() }
    }

    public func continueAfterRequisition() {
        engine.continueAfterRequisition()
        sync()
    }

    public func visibleScore(for playerID: Int) -> Int {
        engine.visibleScore(for: playerID)
    }

    public func validCardsForHuman() -> Set<Card> {
        engine.validCardsForHuman()
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
    }

    public func consumeAnimationEvent(_ id: UUID) {
        animationEvents.removeAll { $0.id == id }
    }
}
