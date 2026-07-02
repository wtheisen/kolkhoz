import Combine
import Foundation
import KolkhozCore

@MainActor
public final class GameStore: ObservableObject {
    @Published public private(set) var state: KolkhozState
    @Published public private(set) var animationEvents: [KolkhozAnimationEvent] = []
    @Published public private(set) var revealedPlayerID: Int?
    @Published public private(set) var onlineSessionID: UUID?
    @Published public private(set) var onlineInviteCode: String?
    @Published public private(set) var onlineServerURL: URL?
    @Published public var lastError: String?
    public private(set) var restoredSavedGame = false

    private var runtime: GameRuntime
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
            let engine = try? KolkhozCEngineAdapter(savedGame: autosave.savedGame)
            if let engine {
                self.runtime = .c(engine)
                self.state = engine.state
                self.currentControllers = PlayerController.normalized(autosave.savedGame.controllers)
                self.revealedPlayerID = engine.state.players.filter(\.isHuman).count > 1 ? nil : engine.state.humanPlayer.id
                self.restoredSavedGame = true
                return
            }
            try? FileManager.default.removeItem(at: autosaveURL)
        }

        let engine = KolkhozCEngineAdapter(seed: seed, variants: variants, controllers: controllers)
        self.runtime = .c(engine)
        self.state = engine.state
        self.currentControllers = PlayerController.normalized(controllers)
        self.revealedPlayerID = engine.state.players.filter(\.isHuman).count > 1 ? nil : engine.state.humanPlayer.id
    }

    public init(scriptedState: KolkhozState) {
        self.autosaveURL = Self.defaultAutosaveURL()
        self.autosaveEnabled = false
        let runtime = ScriptedGameRuntime(state: scriptedState)
        self.runtime = .scripted(runtime)
        self.state = runtime.state
        self.currentControllers = PlayerController.normalized(scriptedState.players.map { $0.isHuman ? .human : .heuristicAI })
        self.revealedPlayerID = scriptedState.humanPlayer.id
    }

    #if DEBUG
    public init(previewState: KolkhozState) {
        self.autosaveURL = Self.defaultAutosaveURL()
        self.autosaveEnabled = false
        let runtime = ScriptedGameRuntime(state: previewState)
        self.runtime = .scripted(runtime)
        self.state = runtime.state
        self.currentControllers = PlayerController.normalized(previewState.players.map { $0.isHuman ? .human : .heuristicAI })
    }
    #endif

    public func newGame(variants: GameVariants? = nil, controllers: [PlayerController]? = nil) {
        clearOnlineSession()
        revealedPlayerID = nil
        let nextVariants = variants ?? state.variants
        if let controllers {
            currentControllers = PlayerController.normalized(controllers)
            runtime = .c(KolkhozCEngineAdapter(variants: nextVariants, controllers: currentControllers))
        } else {
            switch runtime {
            case .c(let engine):
                engine.newGame(variants: variants)
            case .scripted, .online:
                runtime = .c(KolkhozCEngineAdapter(variants: nextVariants, controllers: currentControllers))
            }
        }
        restoredSavedGame = false
        animationEvents = []
        sync()
    }

    public func loadScriptedState(_ scriptedState: KolkhozState) {
        let scripted = ScriptedGameRuntime(state: scriptedState)
        runtime = .scripted(scripted)
        state = scripted.state
        animationEvents = []
        lastError = nil
        revealedPlayerID = scriptedState.humanPlayer.id
    }

    public func setTrump(_ suit: Suit) {
        if submitOnline(KolkhozEngineAction(kind: .setTrump, playerID: Int32(localPlayerID), suit: suit.engineCode)) { return }
        perform { try runtime.setTrump(suit, playerID: localPlayerID) }
    }

    public func play(_ card: Card) {
        if submitOnline(KolkhozEngineAction(kind: .playCard, playerID: Int32(localPlayerID), card: card.engineCard)) { return }
        perform { try runtime.playCard(card, playerID: localPlayerID) }
    }

    public func swap(handCard: Card, plotCard: Card, revealed: Bool) {
        if submitOnline(KolkhozEngineAction(
            kind: .swap,
            playerID: Int32(localPlayerID),
            handCard: handCard.engineCard,
            plotCard: plotCard.engineCard,
            plotZone: (revealed ? PlotCardZone.revealed : .hidden).engineCode
        )) { return }
        perform { try runtime.swap(handCard: handCard, plotCard: plotCard, revealed: revealed, playerID: localPlayerID) }
    }

    public func confirmSwap() {
        if submitOnline(KolkhozEngineAction(kind: .confirmSwap, playerID: Int32(localPlayerID))) { return }
        perform { try runtime.confirmSwap(playerID: localPlayerID) }
    }

    public func undoSwap() {
        if submitOnline(KolkhozEngineAction(kind: .undoSwap, playerID: Int32(localPlayerID))) { return }
        perform { try runtime.undoSwap(playerID: localPlayerID) }
    }

    public func assign(_ card: Card, to suit: Suit) {
        if submitOnline(KolkhozEngineAction(kind: .assign, playerID: Int32(localPlayerID), card: card.engineCard, targetSuit: suit.engineCode)) { return }
        perform { try runtime.assign(card: card, to: suit, playerID: localPlayerID) }
    }

    public func submitAssignments() {
        if submitOnline(KolkhozEngineAction(kind: .submitAssignments, playerID: Int32(localPlayerID))) { return }
        perform { try runtime.submitAssignments(playerID: localPlayerID) }
    }

    public func continueAfterRequisition() {
        if submitOnline(KolkhozEngineAction(kind: .continueAfterRequisition, playerID: Int32(localPlayerID))) { return }
        runtime.continueAfterRequisition()
        sync()
    }

    public func visibleScore(for playerID: Int) -> Int {
        runtime.visibleScore(for: playerID)
    }

    public func validCardsForHuman() -> Set<Card> {
        if case .online(let online) = runtime {
            return Set(online.legalActions.compactMap { action in
                guard action.kind == .playCard,
                      action.playerID == Int32(localPlayerID),
                      let card = Card(engineCard: action.card) else {
                    return nil
                }
                return card
            })
        }
        return runtime.validCardsForHuman(playerID: localPlayerID)
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

    public var isOnlineGame: Bool {
        if case .online = runtime { return true }
        return false
    }

    @discardableResult
    public func hostOnlineGame(baseURL: URL, variants: GameVariants, controllers: [PlayerController]) async throws -> String {
        let normalizedControllers = PlayerController.normalized(controllers)
        let client = KolkhozOnlineClient(transport: KolkhozHTTPOnlineTransport(baseURL: baseURL))
        let response = try await client.createSession(KolkhozOnlineCreateSessionRequest(
            variants: variants,
            controllers: normalizedControllers
        ))
        connectOnline(
            client: client,
            baseURL: baseURL,
            update: response.update,
            playerID: response.playerID
        )
        return response.sessionID.uuidString
    }

    public func joinOnlineGame(baseURL: URL, inviteCode: String, preferredPlayerID: Int32? = nil) async throws {
        let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let sessionID = UUID(uuidString: code) else {
            throw OnlineGameError.invalidInviteCode
        }
        let client = KolkhozOnlineClient(transport: KolkhozHTTPOnlineTransport(baseURL: baseURL))
        let response = try await client.joinSession(sessionID: sessionID, preferredPlayerID: preferredPlayerID)
        connectOnline(
            client: client,
            baseURL: baseURL,
            update: response.update,
            playerID: response.playerID
        )
    }

    public func refreshOnlineGame() async {
        guard case .online(let online) = runtime else { return }
        do {
            try await online.refresh()
            lastError = nil
            sync()
        } catch is CancellationError {
            return
        } catch {
            lastError = String(describing: error)
        }
    }

    public func leaveOnlineGame() {
        guard isOnlineGame else { return }
        clearOnlineSession()
        newGame(variants: state.variants, controllers: currentControllers)
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

    private func submitOnline(_ action: KolkhozEngineAction) -> Bool {
        guard case .online(let online) = runtime else { return false }
        Task { @MainActor in
            do {
                try await online.submit(action)
                lastError = nil
                sync()
            } catch is CancellationError {
                return
            } catch {
                lastError = String(describing: error)
            }
        }
        return true
    }

    private func connectOnline(
        client: KolkhozOnlineClient,
        baseURL: URL,
        update: KolkhozOnlineSessionUpdate,
        playerID: Int32
    ) {
        let online = OnlineGameRuntime(
            client: client,
            sessionID: update.sessionID,
            playerID: playerID,
            update: update
        )
        runtime = .online(online)
        currentControllers = online.displayControllers
        onlineSessionID = update.sessionID
        onlineInviteCode = update.sessionID.uuidString
        onlineServerURL = baseURL
        revealedPlayerID = Int(playerID)
        restoredSavedGame = false
        animationEvents = []
        lastError = nil
        sync()
        Task { @MainActor in
            await refreshOnlineGame()
        }
    }

    private func clearOnlineSession() {
        onlineSessionID = nil
        onlineInviteCode = nil
        onlineServerURL = nil
    }

    private func sync() {
        state = runtime.state
        animationEvents.append(contentsOf: runtime.drainAnimationEvents())
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
        guard !isOnlineGame else { return }
        guard state.phase != .gameOver else {
            try? FileManager.default.removeItem(at: autosaveURL)
            return
        }
        guard let savedGame = runtime.cSavedGame else { return }
        do {
            let payload = KolkhozAutosave(savedGame: savedGame)
            let data = try JSONEncoder().encode(payload)
            try FileManager.default.createDirectory(at: autosaveURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: autosaveURL, options: [.atomic])
        } catch {
            // Autosave should never block play.
        }
    }

    private static func loadAutosave(from url: URL) -> KolkhozAutosave? {
        guard let data = try? Data(contentsOf: url),
              let autosave = try? JSONDecoder().decode(KolkhozAutosave.self, from: data) else {
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

@MainActor
private enum GameRuntime {
    case scripted(ScriptedGameRuntime)
    case c(KolkhozCEngineAdapter)
    case online(OnlineGameRuntime)

    var state: KolkhozState {
        switch self {
        case .scripted(let engine): engine.state
        case .c(let engine): engine.state
        case .online(let engine): engine.state
        }
    }

    var cSavedGame: KolkhozCEngineSavedGame? {
        guard case .c(let engine) = self else { return nil }
        return engine.savedGame
    }

    func drainAnimationEvents() -> [KolkhozAnimationEvent] {
        switch self {
        case .scripted: []
        case .c(let engine): engine.drainAnimationEvents()
        case .online: []
        }
    }

    func setTrump(_ suit: Suit, playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.setTrump(suit, playerID: playerID)
        case .c(let engine): try engine.setTrump(suit, playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func playCard(_ card: Card, playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.playCard(card, playerID: playerID)
        case .c(let engine): try engine.playCard(card, playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func swap(handCard: Card, plotCard: Card, revealed: Bool, playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.swap(handCard: handCard, plotCard: plotCard, revealed: revealed, playerID: playerID)
        case .c(let engine): try engine.swap(handCard: handCard, plotCard: plotCard, revealed: revealed, playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func undoSwap(playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.undoSwap(playerID: playerID)
        case .c(let engine): try engine.undoSwap(playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func confirmSwap(playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.confirmSwap(playerID: playerID)
        case .c(let engine): try engine.confirmSwap(playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func assign(card: Card, to suit: Suit, playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.assign(card: card, to: suit, playerID: playerID)
        case .c(let engine): try engine.assign(card: card, to: suit, playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func submitAssignments(playerID: Int) throws {
        switch self {
        case .scripted(let engine): try engine.submitAssignments(playerID: playerID)
        case .c(let engine): try engine.submitAssignments(playerID: playerID)
        case .online: throw OnlineGameError.onlineActionRequiresSubmit
        }
    }

    func continueAfterRequisition() {
        switch self {
        case .scripted(let engine): engine.continueAfterRequisition()
        case .c(let engine): engine.continueAfterRequisition()
        case .online: break
        }
    }

    func visibleScore(for playerID: Int) -> Int {
        switch self {
        case .scripted(let engine): engine.visibleScore(for: playerID)
        case .c(let engine): engine.visibleScore(for: playerID)
        case .online(let engine): engine.visibleScore(for: playerID)
        }
    }

    func validCardsForHuman(playerID: Int) -> Set<Card> {
        switch self {
        case .scripted(let engine): return engine.validCardsForHuman(playerID: playerID)
        case .c(let engine): return engine.validCardsForHuman(playerID: playerID)
        case .online(let engine):
            return Set(engine.legalActions.compactMap { action in
                guard action.kind == .playCard,
                      action.playerID == Int32(playerID),
                      let card = Card(engineCard: action.card) else {
                    return nil
                }
                return card
            })
        }
    }
}

private enum OnlineGameError: Error {
    case invalidInviteCode
    case onlineActionRequiresSubmit
}

@MainActor
private final class ScriptedGameRuntime {
    private(set) var state: KolkhozState

    init(state: KolkhozState) {
        self.state = state
    }

    func setTrump(_ suit: Suit, playerID: Int) throws {
        guard state.phase == .planning else { throw KolkhozMoveError.wrongPhase }
        guard playerID == state.currentPlayer else { throw KolkhozMoveError.wrongPlayer }
        state.trump = suit
        state.phase = .trick
        state.currentPlayer = state.lead
    }

    func playCard(_ card: Card, playerID: Int) throws {
        guard state.phase == .trick else { throw KolkhozMoveError.wrongPhase }
        guard state.players.indices.contains(playerID) else { throw KolkhozMoveError.wrongPlayer }
        guard let index = state.players[playerID].hand.firstIndex(of: card),
              validCardsForHuman(playerID: playerID).contains(card) else {
            throw KolkhozMoveError.invalidCard
        }
        state.players[playerID].hand.remove(at: index)
        state.currentTrick.append(TrickPlay(playerID: playerID, card: card))
    }

    func swap(handCard: Card, plotCard: Card, revealed: Bool, playerID: Int) throws {
        guard state.phase == .swap else { throw KolkhozMoveError.wrongPhase }
        guard state.players.indices.contains(playerID),
              let handIndex = state.players[playerID].hand.firstIndex(of: handCard) else {
            throw KolkhozMoveError.invalidCard
        }
        if revealed {
            guard let plotIndex = state.players[playerID].plot.revealed.firstIndex(of: plotCard) else {
                throw KolkhozMoveError.invalidCard
            }
            state.players[playerID].plot.revealed[plotIndex] = handCard
            state.players[playerID].hand[handIndex] = plotCard
            state.lastSwap = SwapRecord(playerID: playerID, plotZone: .revealed, plotIndex: plotIndex, handIndex: handIndex, newPlotCard: handCard)
        } else {
            guard let plotIndex = state.players[playerID].plot.hidden.firstIndex(of: plotCard) else {
                throw KolkhozMoveError.invalidCard
            }
            state.players[playerID].plot.hidden[plotIndex] = handCard
            state.players[playerID].hand[handIndex] = plotCard
            state.lastSwap = SwapRecord(playerID: playerID, plotZone: .hidden, plotIndex: plotIndex, handIndex: handIndex, newPlotCard: handCard)
        }
        state.swapCount.insert(playerID)
    }

    func undoSwap(playerID: Int) throws {
        guard let lastSwap = state.lastSwap, lastSwap.playerID == playerID else {
            throw KolkhozMoveError.invalidCard
        }
        guard state.players.indices.contains(playerID),
              state.players[playerID].hand.indices.contains(lastSwap.handIndex) else {
            throw KolkhozMoveError.invalidCard
        }
        switch lastSwap.plotZone {
        case .hidden:
            guard state.players[playerID].plot.hidden.indices.contains(lastSwap.plotIndex) else { throw KolkhozMoveError.invalidCard }
            let card = state.players[playerID].plot.hidden[lastSwap.plotIndex]
            state.players[playerID].plot.hidden[lastSwap.plotIndex] = state.players[playerID].hand[lastSwap.handIndex]
            state.players[playerID].hand[lastSwap.handIndex] = card
        case .revealed:
            guard state.players[playerID].plot.revealed.indices.contains(lastSwap.plotIndex) else { throw KolkhozMoveError.invalidCard }
            let card = state.players[playerID].plot.revealed[lastSwap.plotIndex]
            state.players[playerID].plot.revealed[lastSwap.plotIndex] = state.players[playerID].hand[lastSwap.handIndex]
            state.players[playerID].hand[lastSwap.handIndex] = card
        }
        state.swapCount.remove(playerID)
        state.lastSwap = nil
    }

    func confirmSwap(playerID: Int) throws {
        guard state.phase == .swap else { throw KolkhozMoveError.wrongPhase }
        state.swapConfirmed.insert(playerID)
    }

    func assign(card: Card, to suit: Suit, playerID: Int) throws {
        guard state.phase == .assignment else { throw KolkhozMoveError.wrongPhase }
        guard state.lastWinner == playerID else { throw KolkhozMoveError.wrongPlayer }
        state.pendingAssignments[card.id] = suit
    }

    func submitAssignments(playerID: Int) throws {
        guard state.phase == .assignment else { throw KolkhozMoveError.wrongPhase }
        guard state.lastWinner == playerID else { throw KolkhozMoveError.wrongPlayer }
        state.pendingAssignments = [:]
    }

    func continueAfterRequisition() {
        if state.phase == .requisition {
            state.phase = .planning
        }
    }

    func visibleScore(for playerID: Int) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = player.plot.revealed.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.revealed.reduce(0) { $0 + $1.value }
        }
        if state.variants.medalsCount {
            score += player.medals + player.plot.medals
        }
        return score
    }

    func validCardsForHuman(playerID: Int) -> Set<Card> {
        guard state.phase == .trick,
              state.players.indices.contains(playerID) else {
            return []
        }
        guard let leadSuit = state.currentTrick.first?.card.suit else {
            return Set(state.players[playerID].hand)
        }
        let hand = state.players[playerID].hand
        let hasLeadSuit = hand.contains { $0.suit == leadSuit }
        return Set(hand.filter { !hasLeadSuit || $0.suit == leadSuit })
    }
}

@MainActor
private final class OnlineGameRuntime {
    let client: KolkhozOnlineClient
    let sessionID: UUID
    let playerID: Int32
    private(set) var serverControllers: [PlayerController]
    private(set) var displayControllers: [PlayerController]
    private(set) var variants: GameVariants
    private(set) var state: KolkhozState
    private(set) var legalActions: [KolkhozEngineAction] = []
    private var actionLogCount: Int
    private var visibleScores: [Int: Int]

    init(client: KolkhozOnlineClient, sessionID: UUID, playerID: Int32, update: KolkhozOnlineSessionUpdate) {
        self.client = client
        self.sessionID = sessionID
        self.playerID = playerID
        self.variants = update.variants
        self.serverControllers = PlayerController.normalized(update.controllers)
        self.displayControllers = Self.displayControllers(from: serverControllers, localPlayerID: playerID)
        self.state = update.snapshot.kolkhozState(variants: update.variants, controllers: displayControllers)
        self.actionLogCount = update.actionLogCount
        self.visibleScores = Self.visibleScores(from: update.snapshot)
    }

    func refresh() async throws {
        let update = try await client.update(sessionID: sessionID, viewerID: playerID)
        apply(update)
        try await refreshLegalActions()
    }

    func submit(_ action: KolkhozEngineAction) async throws {
        let update = try await client.submit(sessionID: sessionID, playerID: playerID, action: action)
        apply(update)
        try await refreshLegalActions()
    }

    func visibleScore(for playerID: Int) -> Int {
        state.gameResult?.scores[playerID] ?? visibleScores[playerID] ?? 0
    }

    private func apply(_ update: KolkhozOnlineSessionUpdate) {
        variants = update.variants
        serverControllers = PlayerController.normalized(update.controllers)
        displayControllers = Self.displayControllers(from: serverControllers, localPlayerID: playerID)
        actionLogCount = update.actionLogCount
        visibleScores = Self.visibleScores(from: update.snapshot)
        state = update.snapshot.kolkhozState(variants: variants, controllers: displayControllers)
    }

    private func refreshLegalActions() async throws {
        guard state.phase != .gameOver,
              state.players.indices.contains(Int(playerID)),
              state.currentPlayer == Int(playerID) || (state.phase == .assignment && state.lastWinner == Int(playerID)) || state.phase == .requisition else {
            legalActions = []
            return
        }
        legalActions = try await client.legalActions(sessionID: sessionID, playerID: playerID)
    }

    private static func displayControllers(from controllers: [PlayerController], localPlayerID: Int32) -> [PlayerController] {
        var display = PlayerController.normalized(controllers).map { controller in
            controller == .human ? .heuristicAI : controller
        }
        let index = Int(localPlayerID)
        if display.indices.contains(index) {
            display[index] = .human
        }
        return display
    }

    private static func visibleScores(from snapshot: KolkhozEngineSnapshot) -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: snapshot.scores.map { (Int($0.playerID), Int($0.visibleScore)) })
    }
}

private struct KolkhozAutosave: Codable {
    var version = 2
    let savedGame: KolkhozCEngineSavedGame
}
