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

func applySmokeActions(to engine: KolkhozCEngineAdapter, limit: Int = 500) throws {
    var turnGuard = 0
    while engine.state.phase != .gameOver && turnGuard < limit {
        turnGuard += 1
        guard let action = chooseSmokeAction(from: engine.legalActions()) else {
            expect(false, "c engine should expose a legal action before game over")
            return
        }
        try engine.apply(action)
    }
}

func expectStatesMatch(_ lhs: KolkhozState, _ rhs: KolkhozState, _ context: String) {
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
    let engine = KolkhozCEngineAdapter(
        seed: 42,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )
    let state = engine.state
    let cardsInPlay = state.players.reduce(0) { $0 + $1.hand.count } + state.currentTrick.count

    expect(state.players.count == 4, "expected four players")
    expect(cardsInPlay == 20, "expected twenty worker cards in play")
    expect(state.revealedJobs.count == Suit.allCases.count, "expected one revealed job per suit")
}

func testDefaultKolkhozDisablesNomenclature() {
    expect(!GameVariants.kolkhoz.nomenclature, "default Kolkhoz preset should not enable nomenklatura")
}

func testValidCardsRespectLeadSuit() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 100,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )

    for _ in 0..<160 where engine.state.phase != .gameOver {
        if engine.state.phase == .trick,
           let leadSuit = engine.state.currentTrick.first?.card.suit,
           engine.state.players.indices.contains(engine.state.currentPlayer) {
            let playerID = engine.state.currentPlayer
            let hand = engine.state.players[playerID].hand
            if hand.contains(where: { $0.suit == leadSuit }) {
                let valid = engine.validCardsForHuman(playerID: playerID)
                expect(!valid.isEmpty, "player with lead suit should have legal cards")
                expect(valid.allSatisfy { $0.suit == leadSuit }, "valid cards must follow lead suit")
                return
            }
        }
        guard let action = chooseSmokeAction(from: engine.legalActions()) else {
            expect(false, "valid-card smoke should have legal actions")
            return
        }
        try engine.apply(action)
    }

    expect(false, "expected to reach a trick state where follow-suit validation applies")
}

func testCEngineAppliesPlayCardActions() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 12,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )

    for _ in 0..<80 where engine.state.phase != .gameOver {
        guard let action = chooseSmokeAction(from: engine.legalActions()) else {
            expect(false, "play-card smoke should have legal actions")
            return
        }
        let beforeCount = engine.state.currentTrick.count
        let beforeHandCount = engine.state.players.indices.contains(Int(action.playerID)) ? engine.state.players[Int(action.playerID)].hand.count : -1
        try engine.apply(action)
        if action.kind == .playCard {
            let afterHandCount = engine.state.players.indices.contains(Int(action.playerID)) ? engine.state.players[Int(action.playerID)].hand.count : -1
            expect(afterHandCount == beforeHandCount - 1, "c engine should remove the played card from hand")
            expect(engine.state.currentTrick.count == beforeCount + 1 || engine.state.phase == .assignment, "c engine should add the played card or resolve the trick")
            return
        }
    }

    expect(false, "expected to apply a play-card action")
}

func testCEngineAdapterCanCompleteOfflineGame() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 88,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )

    try applySmokeActions(to: engine)

    expect(engine.state.phase == .gameOver, "deterministic c game should complete")
    expect(engine.state.gameResult != nil, "c game should produce a result")
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

func testCEngineAdapterUndoSwapRestoresState() throws {
    let engine = KolkhozCEngineAdapter(
        seed: 21,
        variants: .kolkhoz,
        controllers: KolkhozHeadlessEngine.allHumanControllers
    )
    var swapAction: KolkhozEngineAction?

    for _ in 0..<300 where engine.state.phase != .gameOver {
        let actions = engine.legalActions()
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

    for _ in 0..<80 where engine.state.phase != .gameOver {
        guard let action = chooseSmokeAction(from: engine.legalActions()) else {
            expect(false, "c adapter action-log test should have legal action")
            return
        }
        try engine.apply(action)
    }

    let data = try JSONEncoder().encode(engine.savedGame)
    let decoded = try JSONDecoder().decode(KolkhozCEngineSavedGame.self, from: data)
    let restored = try KolkhozCEngineAdapter(savedGame: decoded)

    expectStatesMatch(engine.state, restored.state, "c adapter action-log restore")
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

do {
    testNewGameDealsCards()
    testDefaultKolkhozDisablesNomenclature()
    try testValidCardsRespectLeadSuit()
    try testCEngineAppliesPlayCardActions()
    try testCEngineAdapterCanCompleteOfflineGame()
    try testHeadlessAllHumanKeepsRemoteSeatsExternal()
    try testHeadlessMixedControllersAdvanceThroughAISeats()
    try testCEngineAdapterUndoSwapRestoresState()
    try testCEngineAdapterRestoresFromActionLog()
    try testOnlineSnapshotRedactsPrivateState()
    try testAuthoritativeSessionValidatesAndReplaysActions()
    try testOnlineSessionServiceManagesSeatsAndReplay()
    try testOnlineClientUsesTransportBindings()
    try testOnlineHTTPRouterServesSessionFlow()
    print("Kolkhoz smoke tests passed")
} catch {
    fputs("Smoke test threw error: \(error)\n", stderr)
    exit(1)
}
