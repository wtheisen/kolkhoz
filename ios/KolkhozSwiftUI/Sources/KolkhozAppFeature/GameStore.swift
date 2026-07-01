import Combine
import Foundation
import KolkhozCore

@MainActor
public final class GameStore: ObservableObject {
    @Published public private(set) var state: KolkhozState
    @Published public private(set) var animationEvents: [KolkhozAnimationEvent] = []
    @Published public private(set) var revealedPlayerID: Int?
    @Published public var lastError: String?
    public private(set) var restoredSavedGame = false

    private var engine: KolkhozEngine
    private var currentControllers: [PlayerController]
    private let autosaveURL: URL
    private let autosaveEnabled: Bool

    public init(
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = PlayerController.defaultControllers
    ) {
        self.autosaveURL = Self.defaultAutosaveURL()
        self.autosaveEnabled = true
        if let autosave = Self.loadAutosave(from: autosaveURL) {
            let engine = KolkhozEngine(testing: autosave.state, controllers: autosave.controllers)
            self.engine = engine
            self.state = engine.state
            self.currentControllers = PlayerController.normalized(autosave.controllers)
            self.revealedPlayerID = engine.state.players.filter(\.isHuman).count > 1 ? nil : engine.state.humanPlayer.id
            self.restoredSavedGame = true
            return
        }

        let engine = KolkhozEngine(seed: seed, variants: variants, controllers: controllers)
        self.engine = engine
        self.state = engine.state
        self.currentControllers = PlayerController.normalized(controllers)
        self.revealedPlayerID = engine.state.players.filter(\.isHuman).count > 1 ? nil : engine.state.humanPlayer.id
    }

    public init(scriptedState: KolkhozState) {
        self.autosaveURL = Self.defaultAutosaveURL()
        self.autosaveEnabled = false
        let engine = KolkhozEngine(testing: scriptedState)
        self.engine = engine
        self.state = engine.state
        self.currentControllers = PlayerController.normalized(scriptedState.players.map { $0.isHuman ? .human : .heuristicAI })
        self.revealedPlayerID = engine.state.humanPlayer.id
    }

    #if DEBUG
    public init(previewState: KolkhozState) {
        self.autosaveURL = Self.defaultAutosaveURL()
        self.autosaveEnabled = false
        let engine = KolkhozEngine(testing: previewState)
        self.engine = engine
        self.state = engine.state
        self.currentControllers = PlayerController.normalized(previewState.players.map { $0.isHuman ? .human : .heuristicAI })
    }
    #endif

    public func newGame(variants: GameVariants? = nil, controllers: [PlayerController]? = nil) {
        revealedPlayerID = nil
        if let controllers {
            currentControllers = PlayerController.normalized(controllers)
            engine = KolkhozEngine(variants: variants ?? state.variants, controllers: controllers)
        } else {
            engine.newGame(variants: variants)
        }
        restoredSavedGame = false
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
        saveAutosave()
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

    private var savedControllers: [PlayerController] {
        currentControllers
    }

    private func saveAutosave() {
        guard autosaveEnabled else { return }
        guard state.phase != .gameOver else {
            try? FileManager.default.removeItem(at: autosaveURL)
            return
        }
        do {
            let payload = KolkhozAutosave(state: state, controllers: savedControllers)
            let data = try JSONEncoder().encode(payload)
            try FileManager.default.createDirectory(at: autosaveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: autosaveURL, options: [.atomic])
        } catch {
            // Autosave should never block play.
        }
    }

    private static func loadAutosave(from url: URL) -> KolkhozAutosave? {
        guard let data = try? Data(contentsOf: url),
              let autosave = try? JSONDecoder().decode(KolkhozAutosave.self, from: data),
              autosave.state.phase != .gameOver else {
            return nil
        }
        return autosave
    }

    private static func defaultAutosaveURL() -> URL {
        let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("Kolkhoz", isDirectory: true)
            .appendingPathComponent("autosave.json")
    }
}

private struct KolkhozAutosave: Codable {
    var version = 1
    let state: KolkhozState
    let controllers: [PlayerController]
}
