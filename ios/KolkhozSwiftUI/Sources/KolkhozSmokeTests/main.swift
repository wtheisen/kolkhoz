import Foundation
import KolkhozCore

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Smoke test failed: \(message)\n", stderr)
        exit(1)
    }
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
    let inputSize = 34
    let hiddenSize = 4
    let model = KolkhozPolicyModel(
        version: 1,
        featureVersion: 1,
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

do {
    testNewGameDealsCards()
    testDefaultKolkhozDisablesNomenclature()
    testValidCardsRespectLeadSuit()
    try testEngineEmitsCardPlayAnimationEvents()
    try testGameCanReachGameOver()
    try testPolicyModelCanDriveGameOver()
    try testHotSeatStopsOnSecondHumanTurn()
    try testRequisitionUsesHumanFacingName()
    print("Kolkhoz smoke tests passed")
} catch {
    fputs("Smoke test threw error: \(error)\n", stderr)
    exit(1)
}
