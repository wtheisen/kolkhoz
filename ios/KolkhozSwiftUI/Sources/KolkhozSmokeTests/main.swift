import Foundation
import KolkhozCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Smoke test failed: \(message)\n", stderr)
        exit(1)
    }
}

final class AsyncTestResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?

    func set(_ result: Result<Void, Error>) {
        lock.lock()
        self.result = result
        lock.unlock()
    }

    func get() -> Result<Void, Error>? {
        lock.lock()
        defer { lock.unlock() }
        return result
    }
}

func runAsync(_ operation: @Sendable @escaping () async throws -> Void) throws {
    let semaphore = DispatchSemaphore(value: 0)
    let resultBox = AsyncTestResultBox()
    Task.detached {
        do {
            try await operation()
            resultBox.set(.success(()))
        } catch {
            resultBox.set(.failure(error))
        }
        semaphore.signal()
    }
    semaphore.wait()
    if case .failure(let error) = resultBox.get() {
        throw error
    }
}

func smokeActionKey(_ action: KolkhozEngineAction) -> [Int32] {
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

func chooseSmokeAction(from actions: [KolkhozEngineAction]) -> KolkhozEngineAction? {
    let swaps = actions.filter { $0.kind == .swap }.sorted {
        let leftDelta = $0.plotCard.value - $0.handCard.value
        let rightDelta = $1.plotCard.value - $1.handCard.value
        return leftDelta == rightDelta ? smokeActionKey($0).lexicographicallyPrecedes(smokeActionKey($1)) : leftDelta > rightDelta
    }
    if let swap = swaps.first, swap.plotCard.value > swap.handCard.value + 1 {
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
    return actions.sorted { smokeActionKey($0).lexicographicallyPrecedes(smokeActionKey($1)) }.first
}

func expectProjectedStateMatches(_ lhs: KolkhozState, _ rhs: KolkhozState, _ context: String) {
    expect(lhs.phase == rhs.phase, "\(context): phase should match")
    expect(lhs.currentPlayer == rhs.currentPlayer, "\(context): current player should match")
    expect(lhs.lead == rhs.lead, "\(context): lead should match")
    expect(lhs.year == rhs.year, "\(context): year should match")
    expect(lhs.trump == rhs.trump, "\(context): trump should match")
    expect(lhs.trumpSelector == rhs.trumpSelector, "\(context): trump selector should match")
    expect(lhs.trickCount == rhs.trickCount, "\(context): trick count should match")
    expect(lhs.isFamine == rhs.isFamine, "\(context): famine flag should match")
    expect(lhs.players.map(\.hand) == rhs.players.map(\.hand), "\(context): hands should match")
    expect(lhs.players.map(\.plot) == rhs.players.map(\.plot), "\(context): plots should match")
    expect(lhs.players.map(\.brigadeLeader) == rhs.players.map(\.brigadeLeader), "\(context): brigade leaders should match")
    expect(lhs.players.map(\.hasWonTrickThisYear) == rhs.players.map(\.hasWonTrickThisYear), "\(context): trick winners should match")
    expect(lhs.players.map(\.medals) == rhs.players.map(\.medals), "\(context): medals should match")
    expect(lhs.jobPiles == rhs.jobPiles, "\(context): job piles should match")
    expect(lhs.revealedJobs == rhs.revealedJobs, "\(context): revealed jobs should match")
    expect(lhs.claimedJobs == rhs.claimedJobs, "\(context): claimed jobs should match")
    expect(lhs.workHours == rhs.workHours, "\(context): work hours should match")
    expect(lhs.jobBuckets == rhs.jobBuckets, "\(context): job buckets should match")
    expect(lhs.currentTrick == rhs.currentTrick, "\(context): current trick should match")
    expect(lhs.lastTrick == rhs.lastTrick, "\(context): last trick should match")
    expect(lhs.lastWinner == rhs.lastWinner, "\(context): last winner should match")
    expect(lhs.exiled == rhs.exiled, "\(context): exiled cards should match")
    expect(lhs.pendingAssignments == rhs.pendingAssignments, "\(context): pending assignments should match")
    expect(lhs.requisitionEvents.map(\.message) == rhs.requisitionEvents.map(\.message), "\(context): requisition messages should match")
    expect(lhs.gameResult == rhs.gameResult, "\(context): game result should match")
    expect(lhs.accumulatedJobCards == rhs.accumulatedJobCards, "\(context): accumulated jobs should match")
    expect(lhs.swapConfirmed == rhs.swapConfirmed, "\(context): swap confirmations should match")
    expect(lhs.swapCount == rhs.swapCount, "\(context): swap counts should match")
}

func testNewGameDealsCards() {
    let engine = KolkhozEngine(seed: 42)
    let state = engine.state
    let cardsInPlay = state.players.reduce(0) { $0 + $1.hand.count } + state.currentTrick.count

    expect(state.players.count == 4, "expected four players")
    expect(cardsInPlay == 20, "expected twenty worker cards in play")
    expect(state.revealedJobs.count == Suit.allCases.count, "expected one revealed job per suit")
}

func testDefaultKolkhozDisablesNomenclature() {
    expect(!GameVariants.kolkhoz.nomenclature, "default Kolkhoz preset should not enable nomenklatura")
}

func testValidCardsRespectLeadSuit() {
    let engine = KolkhozEngine(seed: 100)
    var state = engine.state
    state.phase = .trick
    state.currentPlayer = 0
    state.players[0].hand = [
        Card(suit: .wheat, value: 7),
        Card(suit: .beet, value: 12)
    ]
    state.currentTrick = [TrickPlay(playerID: 1, card: Card(suit: .wheat, value: 9))]

    let patched = KolkhozEngine(testing: state)
    expect(patched.validCardsForHuman() == [Card(suit: .wheat, value: 7)], "human must follow lead suit")
}

func testEngineEmitsCardPlayAnimationEvents() throws {
    var players = (0..<4).map { id in
        PlayerState(id: id, name: id == 0 ? "Player" : "Bot \(id)", isHuman: id == 0)
    }
    players[0].hand = [Card(suit: .wheat, value: 6)]
    players[1].hand = [Card(suit: .wheat, value: 13)]
    players[2].hand = [Card(suit: .wheat, value: 7)]
    players[3].hand = [Card(suit: .wheat, value: 8)]

    var state = KolkhozState(players: players, lead: 0, trumpSelector: 0)
    state.phase = .trick
    state.currentPlayer = 0
    state.trump = nil

    let engine = KolkhozEngine(testing: state)
    try engine.playCard(Card(suit: .wheat, value: 6))
    let events = engine.drainAnimationEvents()
    let cardPlayEvents = events.compactMap { event -> Int? in
        guard case .cardPlayed(_, let playerID, _) = event else { return nil }
        return playerID
    }

    expect(cardPlayEvents == [0, 1, 2, 3], "expected card-play animation event for each trick participant")
}

func testGameCanReachGameOver() throws {
    let engine = KolkhozEngine(seed: 88)
    var turnGuard = 0

    while engine.state.phase != .gameOver && turnGuard < 500 {
        turnGuard += 1

        switch engine.state.phase {
        case .planning where engine.state.currentPlayer == 0:
            try engine.setTrump(.wheat)

        case .swap:
            try engine.confirmSwap()

        case .trick where engine.state.currentPlayer == 0:
            let card = engine.validCardsForHuman().sorted { $0.value < $1.value }.first ?? engine.state.players[0].hand[0]
            try engine.playCard(card)

        case .assignment:
            let target = engine.state.lastTrick.first?.card.suit ?? .wheat
            for play in engine.state.lastTrick {
                try engine.assign(card: play.card, to: target)
            }
            try engine.submitAssignments()

        case .requisition:
            engine.continueAfterRequisition()

        default:
            break
        }
    }

    expect(engine.state.phase == .gameOver, "deterministic game should complete")
    expect(engine.state.gameResult != nil, "game should produce a result")
}

func testPolicyModelCanDriveGameOver() throws {
    let inputSize = 83
    let hiddenSize = 4
    let model = KolkhozPolicyModel(
        version: 1,
        featureVersion: 2,
        inputSize: inputSize,
        hiddenSize: hiddenSize,
        w1: Array(repeating: 0.01, count: inputSize * hiddenSize),
        b1: Array(repeating: 0, count: hiddenSize),
        w2: Array(repeating: 0.01, count: hiddenSize),
        b2: 0
    )
    expect(model.isCompatible, "test policy model should match Swift feature contract")

    let engine = KolkhozEngine(seed: 91, aiModel: model)
    var turnGuard = 0

    while engine.state.phase != .gameOver && turnGuard < 500 {
        turnGuard += 1

        switch engine.state.phase {
        case .planning where engine.state.currentPlayer == 0:
            try engine.setTrump(.wheat)

        case .swap:
            try engine.confirmSwap()

        case .trick where engine.state.currentPlayer == 0:
            let card = engine.validCardsForHuman().sorted { $0.value < $1.value }.first ?? engine.state.players[0].hand[0]
            try engine.playCard(card)

        case .assignment:
            let target = engine.state.lastTrick.first?.card.suit ?? .wheat
            for play in engine.state.lastTrick {
                try engine.assign(card: play.card, to: target)
            }
            try engine.submitAssignments()

        case .requisition:
            engine.continueAfterRequisition()

        default:
            break
        }
    }

    expect(engine.state.phase == .gameOver, "compatible policy model should be able to drive AI turns")
}

func testV5ModelNoSwapDoesNotFallBackToHeuristicSwap() {
    let hiddenSize = 4
    let model = KolkhozPolicyModel(
        version: 1,
        featureVersion: 5,
        inputSize: 200,
        hiddenSize: hiddenSize,
        w1: Array(repeating: 0, count: 200 * hiddenSize),
        b1: Array(repeating: 0, count: hiddenSize),
        w2: Array(repeating: 0, count: hiddenSize),
        b2: 0
    )
    expect(model.isCompatible, "test v5 policy model should match Swift feature contract")

    var players = (0..<4).map { id in
        PlayerState(id: id, name: id == 0 ? "Player" : "Bot \(id)", isHuman: id == 0)
    }
    players[1].hand = [Card(suit: .wheat, value: 6)]
    players[1].plot.hidden = [Card(suit: .sunflower, value: 13)]

    var state = KolkhozState(players: players, lead: 0, trumpSelector: 0)
    state.phase = .swap
    state.currentPlayer = 1

    let decider = KolkhozAIDecider(state: state, model: model)
    expect(decider.chooseSwap(for: 1) == nil, "v5 model no-swap should be terminal instead of falling back to heuristic swap")
}

func testHotSeatStopsOnSecondHumanTurn() throws {
    var players = (0..<4).map { id in
        PlayerState(id: id, name: id < 2 ? "Player \(id + 1)" : "Bot \(id)", isHuman: id < 2)
    }
    players[0].hand = [Card(suit: .wheat, value: 9)]
    players[1].hand = [Card(suit: .wheat, value: 6)]
    players[2].hand = [Card(suit: .wheat, value: 7)]
    players[3].hand = [Card(suit: .wheat, value: 8)]

    var state = KolkhozState(players: players, lead: 1, trumpSelector: 0)
    state.phase = .trick
    state.currentPlayer = 1
    state.trump = nil

    let engine = KolkhozEngine(testing: state)
    try engine.playCard(Card(suit: .wheat, value: 6), playerID: 1)

    expect(engine.state.phase == .trick, "hot-seat trick should pause before the next human")
    expect(engine.state.currentPlayer == 0, "hot-seat trick should rotate to player 1 after AI seats")
    expect(engine.state.currentTrick.map(\.playerID) == [1, 2, 3], "AI seats should auto-play between human turns")
}

func testHeadlessAllHumanKeepsRemoteSeatsExternal() throws {
    var seedWithRemoteTurn: UInt64?
    for seed in UInt64(1)...UInt64(128) {
        let engine = KolkhozHeadlessEngine(seed: seed, controllers: KolkhozHeadlessEngine.allHumanControllers)
        if engine.waitingPlayer > 0 {
            seedWithRemoteTurn = seed
            break
        }
    }
    guard let seed = seedWithRemoteTurn else {
        expect(false, "expected to find a seed where a non-local remote seat acts first")
        return
    }

    let engine = KolkhozHeadlessEngine(seed: seed, controllers: KolkhozHeadlessEngine.allHumanControllers)
    expect(engine.isWaitingForExternalAction, "all-human headless engine should wait for remote player actions")
    expect(engine.waitingPlayer > 0, "all-human headless engine should not auto-play remote seats")
    guard let action = engine.legalActions().first else {
        expect(false, "remote player should have legal actions")
        return
    }
    expect(action.playerID == engine.waitingPlayer, "remote legal action should belong to the waiting seat")
    try engine.apply(action)
    expect(engine.snapshot.phase != 5, "single remote action should not auto-finish the game")
}

func testHeadlessMixedControllersAdvanceThroughAISeats() throws {
    var seedWithAITurn: UInt64?
    for seed in UInt64(1)...UInt64(128) {
        let allRemote = KolkhozHeadlessEngine(seed: seed, controllers: KolkhozHeadlessEngine.allHumanControllers)
        if allRemote.waitingPlayer > 0 {
            seedWithAITurn = seed
            break
        }
    }
    guard let seed = seedWithAITurn else {
        expect(false, "expected to find a seed where an AI seat would act first")
        return
    }

    let engine = KolkhozHeadlessEngine(
        seed: seed,
        controllers: [.human, .heuristicAI, .heuristicAI, .heuristicAI]
    )
    expect(engine.isWaitingForExternalAction, "mixed headless engine should stop for the external human seat")
    expect(engine.waitingPlayer == 0, "mixed headless engine should auto-advance through AI seats")

    var guardCount = 0
    while engine.phaseCode != 5 && guardCount < 40 {
        guardCount += 1
        expect(engine.isWaitingForExternalAction, "mixed headless engine should not stop on AI seats")
        expect(engine.waitingPlayer == 0, "mixed headless engine should wait only on player 1")
        guard let action = engine.legalActions().first else {
            expect(false, "external human should have a legal action")
            return
        }
        try engine.apply(action)
    }
}

func testCEngineAdapterProjectsOfflineState() throws {
    let seed: UInt64 = 7
    let controllers = KolkhozHeadlessEngine.allHumanControllers
    let reference = KolkhozEngine(seed: seed, variants: .kolkhoz, controllers: controllers, aiModel: nil)
    let candidate = KolkhozCEngineAdapter(seed: seed, variants: .kolkhoz, controllers: controllers)
    expectProjectedStateMatches(reference.state, candidate.state, "initial c adapter")

    var step = 0
    while reference.state.phase != .gameOver && step < 120 {
        step += 1
        guard let action = chooseSmokeAction(from: KolkhozHeadlessEngine.legalActions(for: reference)) else {
            expect(false, "c adapter parity should always have a legal action")
            return
        }
        try KolkhozHeadlessEngine.apply(action, to: reference)
        try candidate.apply(action)
        expectProjectedStateMatches(reference.state, candidate.state, "c adapter step \(step)")
    }
}

func testCEngineAdapterCanCompleteOfflineGame() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 11,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )
    var turnGuard = 0

    while engine.state.phase != .gameOver && turnGuard < 500 {
        turnGuard += 1
        guard let action = chooseSmokeAction(from: KolkhozHeadlessEngine.legalActions(for: KolkhozEngine(testing: engine.state, controllers: KolkhozHeadlessEngine.allHumanControllers, aiModel: nil))) else {
            expect(false, "c adapter offline game should have legal actions")
            return
        }
        try engine.apply(action)
    }

    expect(engine.state.phase == .gameOver, "c adapter offline game should complete")
    expect(engine.state.gameResult != nil, "c adapter offline game should produce a result")
}

func testCEngineAdapterUndoSwapRestoresState() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 21,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )
    var guardCount = 0
    var swapAction: KolkhozEngineAction?

    while engine.state.phase != .gameOver && guardCount < 300 {
        guardCount += 1
        let reference = KolkhozEngine(
            testing: engine.state,
            controllers: KolkhozHeadlessEngine.allHumanControllers,
            aiModel: nil
        )
        let actions = KolkhozHeadlessEngine.legalActions(for: reference)
        if engine.state.phase == .swap, let swap = actions.first(where: { $0.kind == .swap }) {
            swapAction = swap
            break
        }
        guard let action = chooseSmokeAction(from: actions) else {
            expect(false, "c adapter should have legal actions before swap undo test")
            return
        }
        try engine.apply(action)
    }

    guard let swapAction else {
        expect(false, "c adapter should reach a swappable state")
        return
    }

    let beforeHands = engine.state.players.map(\.hand)
    let beforeRevealed = engine.state.players.map { $0.plot.revealed }
    let beforeHidden = engine.state.players.map { $0.plot.hidden }
    let playerID = Int(swapAction.playerID)

    try engine.apply(swapAction)
    expect(engine.state.swapCount.contains(playerID), "c adapter swap should stage swap count")
    expect(engine.state.lastSwap?.playerID == playerID, "c adapter swap should expose last swap")
    try engine.undoSwap(playerID: playerID)

    expect(engine.state.players.map(\.hand) == beforeHands, "c adapter undo swap should restore hands")
    expect(engine.state.players.map { $0.plot.revealed } == beforeRevealed, "c adapter undo swap should restore revealed plots")
    expect(engine.state.players.map { $0.plot.hidden } == beforeHidden, "c adapter undo swap should restore hidden plots")
    expect(!engine.state.swapCount.contains(playerID), "c adapter undo swap should clear staged swap")
    expect(engine.state.lastSwap == nil, "c adapter undo swap should clear last swap")
}

func testCEngineAdapterRestoresFromActionLog() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 31,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )

    for step in 0..<80 where engine.state.phase != .gameOver {
        let reference = KolkhozEngine(
            testing: engine.state,
            controllers: KolkhozHeadlessEngine.allHumanControllers,
            aiModel: nil
        )
        guard let action = chooseSmokeAction(from: KolkhozHeadlessEngine.legalActions(for: reference)) else {
            expect(false, "c adapter action-log test should have legal action at step \(step)")
            return
        }
        try engine.apply(action)
    }

    let data = try JSONEncoder().encode(engine.savedGame)
    let decoded = try JSONDecoder().decode(KolkhozCEngineSavedGame.self, from: data)
    let restored = try KolkhozCEngineAdapter(savedGame: decoded)

    expectProjectedStateMatches(engine.state, restored.state, "c adapter action-log restore")
    expect(restored.savedGame.actions == engine.savedGame.actions, "restored c adapter should preserve action log")
}

func testOnlineSnapshotRedactsPrivateState() throws {
    let session = KolkhozAuthoritativeSession(
        seed: 41,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )
    let full = session.fullSnapshot
    let viewer = session.update(for: 0).snapshot

    expect(!full.players[1].hand.isEmpty, "full server snapshot should retain opponent hands")
    expect(viewer.players[0].hand == full.players[0].hand, "viewer should keep own hand")
    expect(viewer.players[1].hand.isEmpty, "viewer should not receive opponent hand")
    expect(viewer.players[1].hiddenPlot.isEmpty, "viewer should not receive opponent hidden plot")
    expect(viewer.jobPiles.allSatisfy(\.cards.isEmpty), "viewer should not receive future job pile order")
}

func testAuthoritativeSessionValidatesAndReplaysActions() throws {
    let session = KolkhozAuthoritativeSession(
        seed: 43,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )
    let waitingPlayer = session.fullSnapshot.waitingPlayer
    guard let action = session.legalActions(for: waitingPlayer).first else {
        expect(false, "authoritative session should expose legal action for waiting player")
        return
    }

    do {
        _ = try session.submit(action, from: (waitingPlayer + 1) % 4)
        expect(false, "authoritative session should reject wrong player")
    } catch KolkhozOnlineSessionError.wrongPlayer {
    }

    let update = try session.submit(action, from: waitingPlayer)
    expect(update.actionLogCount == 1, "authoritative session should append accepted action")
    expect(session.savedGame.actions == [action], "authoritative session should persist accepted action")

    let restored = try KolkhozAuthoritativeSession(id: session.id, savedGame: session.savedGame)
    expect(restored.fullSnapshot == session.fullSnapshot, "authoritative session should restore from action log")
}

func testOnlineSessionServiceManagesSeatsAndReplay() throws {
    let service = KolkhozOnlineSessionService()
    let created = try service.createSession(KolkhozOnlineCreateSessionRequest(seed: 53))
    let joined = try service.joinSession(KolkhozOnlineJoinSessionRequest(sessionID: created.sessionID, preferredPlayerID: 1))
    expect(created.playerID == 0, "online service should assign player 1 first")
    expect(joined.playerID == 1, "online service should honor available preferred seat")

    do {
        _ = try service.joinSession(KolkhozOnlineJoinSessionRequest(sessionID: created.sessionID, preferredPlayerID: 1))
        expect(false, "online service should reject occupied seat")
    } catch KolkhozOnlineSessionError.seatUnavailable {
    }

    let waitingPlayer = try service.update(KolkhozOnlineStateRequest(sessionID: created.sessionID)).snapshot.waitingPlayer
    if waitingPlayer > 1 {
        _ = try service.joinSession(KolkhozOnlineJoinSessionRequest(sessionID: created.sessionID, preferredPlayerID: waitingPlayer))
    }
    guard let action = try service.legalActions(sessionID: created.sessionID, playerID: waitingPlayer).first else {
        expect(false, "online service should expose legal actions")
        return
    }
    let update = try service.submitAction(KolkhozOnlineSubmitActionRequest(sessionID: created.sessionID, playerID: waitingPlayer, action: action))
    expect(update.actionLogCount == 1, "online service should append accepted action")

    let savedGame = try service.savedGame(sessionID: created.sessionID)
    let restoredID = try service.restoreSession(savedGame: savedGame)
    let restored = try service.update(KolkhozOnlineStateRequest(sessionID: restoredID))
    let original = try service.update(KolkhozOnlineStateRequest(sessionID: created.sessionID))
    expect(restored.actionLogCount == 1, "online service should restore action log count")
    expect(restored.snapshot == original.snapshot, "online service restored snapshot should match original")
}

func testOnlineClientUsesTransportBindings() throws {
    struct SmokeOnlineTransport: KolkhozOnlineTransport {
        let sessionID: UUID
        let playerID: Int32
        let action: KolkhozEngineAction
        let update: KolkhozOnlineSessionUpdate

        func createSession(_ request: KolkhozOnlineCreateSessionRequest) async throws -> KolkhozOnlineCreateSessionResponse {
            KolkhozOnlineCreateSessionResponse(sessionID: sessionID, playerID: playerID, update: update)
        }

        func joinSession(_ request: KolkhozOnlineJoinSessionRequest) async throws -> KolkhozOnlineJoinSessionResponse {
            KolkhozOnlineJoinSessionResponse(sessionID: sessionID, playerID: request.preferredPlayerID ?? playerID, update: update)
        }

        func fetchUpdate(_ request: KolkhozOnlineStateRequest) async throws -> KolkhozOnlineSessionUpdate {
            update
        }

        func fetchLegalActions(sessionID: UUID, playerID: Int32) async throws -> [KolkhozEngineAction] {
            [action]
        }

        func submitAction(_ request: KolkhozOnlineSubmitActionRequest) async throws -> KolkhozOnlineSessionUpdate {
            var submitted = update
            submitted.actionLogCount += 1
            return submitted
        }
    }

    let sessionID = UUID()
    let snapshot = KolkhozCEngineAdapter(seed: 59, variants: .kolkhoz, controllers: KolkhozHeadlessEngine.allHumanControllers).snapshot.redacted(for: 0)
    let update = KolkhozOnlineSessionUpdate(sessionID: sessionID, viewerID: 0, actionLogCount: 0, snapshot: snapshot)
    let action = KolkhozEngineAction(kind: .setTrump, playerID: 0, suit: 0)

    try runAsync {
        let transport = SmokeOnlineTransport(sessionID: sessionID, playerID: 0, action: action, update: update)
        let client = KolkhozOnlineClient(transport: transport)
        let created = try await client.createSession()
        expect(created.sessionID == sessionID, "online client should create sessions through transport")
        let joined = try await client.joinSession(sessionID: sessionID, preferredPlayerID: 1)
        expect(joined.playerID == 1, "online client should join sessions through transport")
        let firstUpdate = try await client.update(sessionID: sessionID, viewerID: 0)
        expect(firstUpdate.snapshot.players[1].hand.isEmpty, "online client update should carry redacted snapshots")
        guard let fetchedAction = try await client.legalActions(sessionID: sessionID, playerID: 0).first else {
            expect(false, "online client should fetch legal actions")
            return
        }
        expect(fetchedAction == action, "online client should decode legal actions")
        let submitted = try await client.submit(sessionID: sessionID, playerID: 0, action: action)
        expect(submitted.actionLogCount == 1, "online client should submit portable action")
    }
}

func testOnlineHTTPRouterServesSessionFlow() throws {
    let router = KolkhozOnlineHTTPRouter()
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let createBody = try encoder.encode(KolkhozOnlineCreateSessionRequest(seed: 61))
    let createResponse = router.handle(method: "POST", path: "/sessions", body: createBody)
    expect(createResponse.statusCode == 200, "online http router should create session")
    let created = try decoder.decode(KolkhozOnlineCreateSessionResponse.self, from: createResponse.body)

    let joinBody = try encoder.encode(KolkhozOnlineJoinSessionRequest(sessionID: created.sessionID, preferredPlayerID: 1))
    let joinResponse = router.handle(method: "POST", path: "/sessions/\(created.sessionID.uuidString)/join", body: joinBody)
    expect(joinResponse.statusCode == 200, "online http router should join session")
    let joined = try decoder.decode(KolkhozOnlineJoinSessionResponse.self, from: joinResponse.body)
    expect(joined.playerID == 1, "online http router should return joined seat")

    let stateResponse = router.handle(
        method: "GET",
        path: "/sessions/\(created.sessionID.uuidString)/state",
        queryItems: [URLQueryItem(name: "viewerID", value: "\(created.playerID)")]
    )
    expect(stateResponse.statusCode == 200, "online http router should serve redacted state")
    let update = try decoder.decode(KolkhozOnlineSessionUpdate.self, from: stateResponse.body)
    expect(update.snapshot.players[1].hand.isEmpty, "online http router state should be redacted")

    let waitingPlayer = update.snapshot.waitingPlayer
    if waitingPlayer > 1 {
        let waitingJoin = try encoder.encode(KolkhozOnlineJoinSessionRequest(sessionID: created.sessionID, preferredPlayerID: waitingPlayer))
        _ = router.handle(method: "POST", path: "/sessions/\(created.sessionID.uuidString)/join", body: waitingJoin)
    }

    let legalResponse = router.handle(method: "GET", path: "/sessions/\(created.sessionID.uuidString)/players/\(waitingPlayer)/actions")
    expect(legalResponse.statusCode == 200, "online http router should serve legal actions")
    let actions = try decoder.decode([KolkhozEngineAction].self, from: legalResponse.body)
    guard let action = actions.first else {
        expect(false, "online http router should return at least one legal action")
        return
    }

    let submitBody = try encoder.encode(KolkhozOnlineSubmitActionRequest(sessionID: created.sessionID, playerID: waitingPlayer, action: action))
    let submitResponse = router.handle(method: "POST", path: "/sessions/\(created.sessionID.uuidString)/actions", body: submitBody)
    expect(submitResponse.statusCode == 200, "online http router should submit legal action")
    let submitted = try decoder.decode(KolkhozOnlineSessionUpdate.self, from: submitResponse.body)
    expect(submitted.actionLogCount == 1, "online http router should return advanced action log count")

    let missingResponse = router.handle(method: "GET", path: "/sessions/\(UUID().uuidString)/state")
    expect(missingResponse.statusCode == 404, "online http router should report missing sessions")
}

func testRequisitionUsesHumanFacingName() throws {
    var players = (0..<4).map { id in
        PlayerState(id: id, name: id == 0 ? "Player" : "Bot \(id)", isHuman: id == 0)
    }
    players[0].plot.hidden = [Card(suit: .sunflower, value: 10)]

    var state = KolkhozState(
        players: players,
        lead: 0,
        trumpSelector: 0,
        variants: GameVariants(deckType: 36, nomenclature: false, northernStyle: true)
    )
    state.phase = .assignment
    state.currentPlayer = 0
    state.lastWinner = 0
    state.trickCount = 4
    state.lastTrick = [
        TrickPlay(playerID: 0, card: Card(suit: .wheat, value: 7)),
        TrickPlay(playerID: 1, card: Card(suit: .wheat, value: 8)),
        TrickPlay(playerID: 2, card: Card(suit: .wheat, value: 12)),
        TrickPlay(playerID: 3, card: Card(suit: .wheat, value: 13))
    ]

    let engine = KolkhozEngine(testing: state)
    for play in engine.state.lastTrick {
        try engine.assign(card: play.card, to: .wheat)
    }
    try engine.submitAssignments()

    expect(
        engine.state.requisitionEvents.contains { $0.message == "Player sends 10 Sunflower north" },
        "human requisition message should use the seat name"
    )
    expect(
        !engine.state.requisitionEvents.contains { $0.message.contains("You send") },
        "human requisition message should not collapse every hot-seat human to you"
    )
}

func testSwappedRewardDoesNotShortNextDeal() {
    let returnedReward = Card(suit: .wheat, value: 1)
    let guaranteedDealCards = Set(
        [returnedReward] +
            Suit.allCases.flatMap { suit in (9...13).map { Card(suit: suit, value: $0) } }.dropLast()
    )
    var players = (0..<4).map { id in
        PlayerState(id: id, name: id == 0 ? "Player" : "Bot \(id)", isHuman: id == 0)
    }
    players[0].plot.revealed = [Card(suit: .wheat, value: 6)]
    players[1].plot.revealed = [Card(suit: .sunflower, value: 6)]
    players[2].plot.revealed = [Card(suit: .potato, value: 6)]
    players[3].plot.revealed = [Card(suit: .beet, value: 6)]

    var state = KolkhozState(players: players, lead: 0, trumpSelector: 0)
    state.year = 3
    state.phase = .requisition
    state.jobPiles = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, []) })
    state.revealedJobs = [:]
    state.exiled = [1: Suit.allCases.flatMap { suit in
        (1...13).map { Card(suit: suit, value: $0) }.filter { card in
            !guaranteedDealCards.contains(card) && !players.flatMap { $0.plot.revealed }.contains(card)
        }
    }]

    let engine = KolkhozEngine(testing: state)
    engine.continueAfterRequisition()

    let handCounts = engine.state.players.map(\.hand.count)
    expect(handCounts == [5, 5, 5, 5], "played swapped reward should remain available for the next normal deal")
    expect(
        engine.state.players.flatMap(\.hand).contains(returnedReward),
        "claimed reward that left the plot should be eligible to return to hand"
    )
}

func testFinalScoreTieBreaksByTotalMedals() {
    var players = (0..<4).map { id in
        PlayerState(id: id, name: id == 0 ? "Player" : "Bot \(id)", isHuman: id == 0)
    }
    players[0].plot.hidden = [Card(suit: .wheat, value: 10)]
    players[1].plot.hidden = [Card(suit: .sunflower, value: 10)]
    players[2].plot.hidden = [Card(suit: .potato, value: 9)]
    players[3].plot.hidden = [Card(suit: .beet, value: 8)]
    players[0].plot.medals = 1
    players[1].plot.medals = 3

    var state = KolkhozState(players: players, lead: 0, trumpSelector: 0)
    state.year = 5
    state.phase = .requisition

    let engine = KolkhozEngine(testing: state)
    engine.continueAfterRequisition()

    expect(engine.state.phase == .gameOver, "continuing year-five requisition should finish the game")
    expect(engine.state.gameResult?.winnerID == 1, "equal final scores should break by total medals won")
}

do {
    testNewGameDealsCards()
    testDefaultKolkhozDisablesNomenclature()
    testValidCardsRespectLeadSuit()
    try testEngineEmitsCardPlayAnimationEvents()
    try testGameCanReachGameOver()
    try testPolicyModelCanDriveGameOver()
    testV5ModelNoSwapDoesNotFallBackToHeuristicSwap()
    try testHotSeatStopsOnSecondHumanTurn()
    try testHeadlessAllHumanKeepsRemoteSeatsExternal()
    try testHeadlessMixedControllersAdvanceThroughAISeats()
    try testCEngineAdapterProjectsOfflineState()
    try testCEngineAdapterCanCompleteOfflineGame()
    try testCEngineAdapterUndoSwapRestoresState()
    try testCEngineAdapterRestoresFromActionLog()
    try testOnlineSnapshotRedactsPrivateState()
    try testAuthoritativeSessionValidatesAndReplaysActions()
    try testOnlineSessionServiceManagesSeatsAndReplay()
    try testOnlineClientUsesTransportBindings()
    try testOnlineHTTPRouterServesSessionFlow()
    try testRequisitionUsesHumanFacingName()
    testSwappedRewardDoesNotShortNextDeal()
    testFinalScoreTieBreaksByTotalMedals()
    print("Kolkhoz smoke tests passed")
} catch {
    fputs("Smoke test threw error: \(error)\n", stderr)
    exit(1)
}
