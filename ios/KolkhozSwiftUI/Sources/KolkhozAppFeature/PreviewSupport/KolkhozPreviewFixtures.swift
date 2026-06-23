#if DEBUG
import KolkhozCore
import SwiftUI

enum KolkhozPreviewFixtures {
    static var lobbyPreset: GamePreset { .kolkhoz }
    static var lobbyVariants: GameVariants { .kolkhoz }

    static var playerPanelOpponent: PlayerState {
        var player = player(id: 1, name: "Anna Petrova", human: false)
        player.brigadeLeader = true
        player.medals = 2
        return player
    }

    static var playerPanelHuman: PlayerState {
        var player = player(id: 0, name: "Player", human: true)
        player.medals = 1
        return player
    }

    static var planningState: KolkhozState {
        var state = baseState()
        state.phase = .planning
        state.currentPlayer = 0
        state.trumpSelector = 0
        state.trump = nil
        return state
    }

    static var trickState: KolkhozState {
        var state = baseState()
        state.phase = .trick
        state.trump = .wheat
        state.lead = 2
        state.currentPlayer = 0
        state.currentTrick = [
            TrickPlay(playerID: 2, card: Card(suit: .sunflower, value: 8)),
            TrickPlay(playerID: 3, card: Card(suit: .sunflower, value: 11))
        ]
        state.players[0].hand = [
            Card(suit: .sunflower, value: 13),
            Card(suit: .sunflower, value: 7),
            Card(suit: .wheat, value: 12),
            Card(suit: .beet, value: 10),
            Card(suit: .potato, value: 6)
        ]
        return state
    }

    static var assignmentState: KolkhozState {
        var state = baseState()
        state.phase = .assignment
        state.trump = .wheat
        state.currentPlayer = 0
        state.lastWinner = 0
        state.lead = 0
        state.trickCount = 2
        state.lastTrick = [
            TrickPlay(playerID: 0, card: Card(suit: .wheat, value: 13)),
            TrickPlay(playerID: 1, card: Card(suit: .wheat, value: 9)),
            TrickPlay(playerID: 2, card: Card(suit: .sunflower, value: 12)),
            TrickPlay(playerID: 3, card: Card(suit: .wheat, value: 6))
        ]
        state.pendingAssignments = [
            Card(suit: .wheat, value: 13).id: .wheat,
            Card(suit: .wheat, value: 9).id: .wheat
        ]
        state.workHours[.wheat] = 25
        state.workHours[.sunflower] = 18
        state.jobBuckets[.wheat] = [
            Card(suit: .wheat, value: 8),
            Card(suit: .wheat, value: 7)
        ]
        return state
    }

    static var swapState: KolkhozState {
        var state = baseState()
        state.phase = .swap
        state.year = 2
        state.trump = .beet
        state.currentPlayer = 0
        state.swapConfirmed = []
        state.swapCount = []
        state.players[0].plot.hidden = [
            Card(suit: .wheat, value: 12),
            Card(suit: .potato, value: 9),
            Card(suit: .beet, value: 7)
        ]
        state.players[0].plot.revealed = [
            Card(suit: .sunflower, value: 5),
            Card(suit: .wheat, value: 4)
        ]
        return state
    }

    static var requisitionState: KolkhozState {
        var state = baseState()
        state.phase = .requisition
        state.currentPlayer = 0
        state.trump = .potato
        state.workHours[.beet] = 28
        state.workHours[.sunflower] = 19
        state.claimedJobs = [.wheat]
        state.players[0].plot.revealed.append(contentsOf: [
            Card(suit: .beet, value: 12),
            Card(suit: .sunflower, value: 10)
        ])
        state.players[1].plot.revealed.append(Card(suit: .beet, value: 11))
        state.exiled[1] = [
            Card(suit: .beet, value: 12),
            Card(suit: .beet, value: 11)
        ]
        state.requisitionEvents = [
            RequisitionEvent(
                playerID: 0,
                suit: .beet,
                card: Card(suit: .beet, value: 12),
                message: "Player sends Q Beet north"
            ),
            RequisitionEvent(
                playerID: 1,
                suit: .beet,
                card: Card(suit: .beet, value: 11),
                message: "Anna sends J Beet north"
            ),
            RequisitionEvent(
                playerID: nil,
                suit: .sunflower,
                card: nil,
                message: "Sunflower failed; no vulnerable matching cards"
            )
        ]
        return state
    }

    static var gameOverState: KolkhozState {
        var state = requisitionState
        state.phase = .gameOver
        state.year = 6
        state.gameResult = GameResult(winnerID: 0, scores: [0: 62, 1: 45, 2: 38, 3: 41])
        return state
    }

    private static func baseState() -> KolkhozState {
        var players = [
            player(id: 0, name: "Player", human: true),
            player(id: 1, name: "Anna Petrova", human: false),
            player(id: 2, name: "Dmitri", human: false),
            player(id: 3, name: "Fyodor", human: false)
        ]
        players[0].plot.revealed = [Card(suit: .wheat, value: 3)]
        players[0].plot.hidden = [Card(suit: .potato, value: 8)]
        players[1].medals = 1
        players[2].brigadeLeader = true
        players[2].medals = 2

        var state = KolkhozState(players: players, lead: 0, trumpSelector: 0, variants: .kolkhoz)
        state.year = 1
        state.trump = .wheat
        state.revealedJobs = [
            .wheat: Card(suit: .wheat, value: 3),
            .sunflower: Card(suit: .sunflower, value: 4),
            .potato: Card(suit: .potato, value: 2),
            .beet: Card(suit: .beet, value: 5)
        ]
        state.workHours = [
            .wheat: 17,
            .sunflower: 29,
            .potato: 8,
            .beet: 34
        ]
        state.jobBuckets = [
            .wheat: [Card(suit: .wheat, value: 9)],
            .sunflower: [Card(suit: .sunflower, value: 11), Card(suit: .sunflower, value: 8)],
            .potato: [Card(suit: .potato, value: 8)],
            .beet: [Card(suit: .beet, value: 13), Card(suit: .beet, value: 10)]
        ]
        return state
    }

    private static func player(id: Int, name: String, human: Bool) -> PlayerState {
        var player = PlayerState(id: id, name: name, isHuman: human)
        player.hand = sampleHands[id, default: sampleHands[0] ?? []]
        player.plot.hidden = [
            Card(suit: Suit.allCases[id % Suit.allCases.count], value: 8 + id),
            Card(suit: Suit.allCases[(id + 1) % Suit.allCases.count], value: 6 + id)
        ]
        player.plot.revealed = [
            Card(suit: Suit.allCases[(id + 2) % Suit.allCases.count], value: 2 + id)
        ]
        return player
    }

    private static let sampleHands: [Int: [Card]] = [
        0: [
            Card(suit: .wheat, value: 13),
            Card(suit: .sunflower, value: 10),
            Card(suit: .potato, value: 8),
            Card(suit: .beet, value: 7),
            Card(suit: .wheat, value: 6)
        ],
        1: [
            Card(suit: .sunflower, value: 13),
            Card(suit: .beet, value: 12),
            Card(suit: .potato, value: 9),
            Card(suit: .wheat, value: 8)
        ],
        2: [
            Card(suit: .potato, value: 13),
            Card(suit: .wheat, value: 12),
            Card(suit: .sunflower, value: 9)
        ],
        3: [
            Card(suit: .beet, value: 13),
            Card(suit: .potato, value: 12),
            Card(suit: .wheat, value: 10),
            Card(suit: .sunflower, value: 7)
        ]
    ]
}
#endif
