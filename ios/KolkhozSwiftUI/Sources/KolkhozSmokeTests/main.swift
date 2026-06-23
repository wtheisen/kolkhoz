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

do {
    testNewGameDealsCards()
    testValidCardsRespectLeadSuit()
    try testEngineEmitsCardPlayAnimationEvents()
    try testGameCanReachGameOver()
    print("Kolkhoz smoke tests passed")
} catch {
    fputs("Smoke test threw error: \(error)\n", stderr)
    exit(1)
}
