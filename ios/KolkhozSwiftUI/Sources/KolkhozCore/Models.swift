import Foundation

public enum Suit: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case wheat = "Wheat"
    case sunflower = "Sunflower"
    case potato = "Potato"
    case beet = "Beet"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .wheat: "W"
        case .sunflower: "S"
        case .potato: "P"
        case .beet: "B"
        }
    }
}

public struct GameVariants: Codable, Hashable, Sendable {
    public var deckType: Int
    public var nomenclature: Bool
    public var allowSwap: Bool
    public var northernStyle: Bool
    public var miceVariant: Bool
    public var ordenNachalniku: Bool
    public var medalsCount: Bool
    public var accumulateJobs: Bool
    public var heroOfSovietUnion: Bool

    public init(
        deckType: Int = 52,
        nomenclature: Bool = true,
        allowSwap: Bool = true,
        northernStyle: Bool = false,
        miceVariant: Bool = false,
        ordenNachalniku: Bool = false,
        medalsCount: Bool = false,
        accumulateJobs: Bool = false,
        heroOfSovietUnion: Bool = true
    ) {
        self.deckType = deckType
        self.nomenclature = nomenclature
        self.allowSwap = allowSwap
        self.northernStyle = northernStyle
        self.miceVariant = miceVariant
        self.ordenNachalniku = ordenNachalniku
        self.medalsCount = medalsCount
        self.accumulateJobs = accumulateJobs
        self.heroOfSovietUnion = heroOfSovietUnion
    }

    public static let kolkhoz = GameVariants(nomenclature: false)

    public static let littleKolkhoz = GameVariants(
        deckType: 36,
        nomenclature: true,
        allowSwap: true,
        northernStyle: false,
        miceVariant: false,
        ordenNachalniku: true,
        medalsCount: false,
        accumulateJobs: false,
        heroOfSovietUnion: false
    )

    public static let campStyle = GameVariants(
        deckType: 36,
        nomenclature: true,
        allowSwap: true,
        northernStyle: true,
        miceVariant: true,
        ordenNachalniku: false,
        medalsCount: false,
        accumulateJobs: false,
        heroOfSovietUnion: true
    )
}

public enum PlayerController: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case human
    case heuristicAI
    case neuralAI

    public var id: String { rawValue }

    public static let defaultControllers: [PlayerController] = [
        .human,
        .neuralAI,
        .neuralAI,
        .neuralAI
    ]

    public static func normalized(_ controllers: [PlayerController]) -> [PlayerController] {
        var normalized = (0..<4).map { index in
            controllers.indices.contains(index) ? controllers[index] : defaultControllers[index]
        }
        if !normalized.contains(.human) {
            normalized[0] = .human
        }
        return normalized
    }
}

public enum GamePreset: String, CaseIterable, Codable, Identifiable, Sendable {
    case kolkhoz
    case littleKolkhoz
    case campStyle
    case custom

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .kolkhoz: "Kolkhoz"
        case .littleKolkhoz: "Little Kolkhoz"
        case .campStyle: "Camp Style"
        case .custom: "Custom"
        }
    }

    public var variants: GameVariants? {
        switch self {
        case .kolkhoz: .kolkhoz
        case .littleKolkhoz: .littleKolkhoz
        case .campStyle: .campStyle
        case .custom: nil
        }
    }
}

public struct Card: Codable, Hashable, Identifiable, Sendable {
    public let suit: Suit
    public let value: Int

    public init(suit: Suit, value: Int) {
        self.suit = suit
        self.value = value
    }

    public var id: String { "\(suit.rawValue)-\(value)" }

    public var rank: String {
        switch value {
        case 1: "A"
        case 11: "J"
        case 12: "Q"
        case 13: "K"
        default: "\(value)"
        }
    }
}

public struct Plot: Codable, Hashable, Sendable {
    public var revealed: [Card] = []
    public var hidden: [Card] = []
    public var medals: Int = 0
    public var stacks: [PlotStack] = []

    public init() {}
}

public struct PlotStack: Codable, Hashable, Sendable {
    public var revealed: [Card]
    public var hidden: [Card]

    public init(revealed: [Card] = [], hidden: [Card] = []) {
        self.revealed = revealed
        self.hidden = hidden
    }
}

public struct PlayerState: Codable, Hashable, Identifiable, Sendable {
    public let id: Int
    public var name: String
    public var isHuman: Bool
    public var hand: [Card]
    public var plot: Plot
    public var brigadeLeader: Bool
    public var hasWonTrickThisYear: Bool
    public var medals: Int

    public init(id: Int, name: String, isHuman: Bool) {
        self.id = id
        self.name = name
        self.isHuman = isHuman
        self.hand = []
        self.plot = Plot()
        self.brigadeLeader = false
        self.hasWonTrickThisYear = false
        self.medals = 0
    }
}

public struct TrickPlay: Codable, Hashable, Identifiable, Sendable {
    public let playerID: Int
    public let card: Card

    public init(playerID: Int, card: Card) {
        self.playerID = playerID
        self.card = card
    }

    public var id: String { "\(playerID)-\(card.id)" }
}

public enum GamePhase: String, Codable, Sendable {
    case planning
    case swap
    case trick
    case assignment
    case requisition
    case gameOver
}

public struct RequisitionEvent: Codable, Hashable, Identifiable, Sendable {
    public let id: UUID
    public let playerID: Int?
    public let suit: Suit
    public let card: Card?
    public let message: String

    public init(playerID: Int?, suit: Suit, card: Card?, message: String) {
        self.id = UUID()
        self.playerID = playerID
        self.suit = suit
        self.card = card
        self.message = message
    }
}

public enum PlotCardZone: String, Codable, Hashable, Sendable {
    case hidden
    case revealed
}

public struct SwapRecord: Codable, Hashable, Sendable {
    public let playerID: Int
    public let plotZone: PlotCardZone
    public let plotIndex: Int
    public let handIndex: Int
    public let newPlotCard: Card

    public init(playerID: Int, plotZone: PlotCardZone, plotIndex: Int, handIndex: Int, newPlotCard: Card) {
        self.playerID = playerID
        self.plotZone = plotZone
        self.plotIndex = plotIndex
        self.handIndex = handIndex
        self.newPlotCard = newPlotCard
    }
}

public struct GameResult: Codable, Hashable, Sendable {
    public let winnerID: Int
    public let scores: [Int: Int]

    public init(winnerID: Int, scores: [Int: Int]) {
        self.winnerID = winnerID
        self.scores = scores
    }
}

public enum KolkhozAnimationEvent: Identifiable, Equatable, Sendable {
    case cardPlayed(id: UUID, playerID: Int, card: Card)
    case workAssigned(id: UUID, playerID: Int, card: Card, targetSuit: Suit, value: Int)
    case jobClaimed(id: UUID, winnerID: Int, suit: Suit, reward: Card?)
    case cardExiled(id: UUID, playerID: Int?, suit: Suit, card: Card?)

    public var id: UUID {
        switch self {
        case .cardPlayed(let id, _, _),
             .workAssigned(let id, _, _, _, _),
             .jobClaimed(let id, _, _, _),
             .cardExiled(let id, _, _, _):
            id
        }
    }
}

public struct KolkhozState: Codable, Sendable {
    public var players: [PlayerState]
    public var lead: Int
    public var year: Int
    public var trump: Suit?
    public var jobPiles: [Suit: [Card]]
    public var revealedJobs: [Suit: Card]
    public var claimedJobs: Set<Suit>
    public var workHours: [Suit: Int]
    public var jobBuckets: [Suit: [Card]]
    public var currentTrick: [TrickPlay]
    public var lastTrick: [TrickPlay]
    public var lastWinner: Int?
    public var trickCount: Int
    public var exiled: [Int: [Card]]
    public var isFamine: Bool
    public var phase: GamePhase
    public var currentPlayer: Int
    public var trumpSelector: Int
    public var pendingAssignments: [String: Suit]
    public var requisitionEvents: [RequisitionEvent]
    public var gameResult: GameResult?
    public var variants: GameVariants
    public var accumulatedJobCards: [Suit: [Card]]
    public var drunkardReplacements: [Card]
    public var swapConfirmed: Set<Int>
    public var swapCount: Set<Int>
    public var lastSwap: SwapRecord?

    public init(players: [PlayerState], lead: Int, trumpSelector: Int, variants: GameVariants = .kolkhoz) {
        self.players = players
        self.lead = lead
        self.year = 1
        self.trump = nil
        self.jobPiles = [:]
        self.revealedJobs = [:]
        self.claimedJobs = []
        self.workHours = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, 0) })
        self.jobBuckets = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, []) })
        self.currentTrick = []
        self.lastTrick = []
        self.lastWinner = nil
        self.trickCount = 0
        self.exiled = [:]
        self.isFamine = false
        self.phase = .planning
        self.currentPlayer = trumpSelector
        self.trumpSelector = trumpSelector
        self.pendingAssignments = [:]
        self.requisitionEvents = []
        self.gameResult = nil
        self.variants = variants
        self.accumulatedJobCards = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, []) })
        self.drunkardReplacements = []
        self.swapConfirmed = []
        self.swapCount = []
        self.lastSwap = nil
    }

    public var numPlayers: Int { players.count }
    public var humanPlayer: PlayerState { players.first(where: \.isHuman) ?? players[0] }
}

public enum KolkhozMoveError: Error, Equatable {
    case wrongPhase
    case wrongPlayer
    case invalidCard
    case invalidAssignment
}
