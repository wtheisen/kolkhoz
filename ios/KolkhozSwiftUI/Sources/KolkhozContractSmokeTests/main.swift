import Foundation

enum ContractSmokeTestError: Error, CustomStringConvertible {
    case missingPath(String)
    case failed(String)

    var description: String {
        switch self {
        case .missingPath(let path): "Missing path: \(path)"
        case .failed(let message): message
        }
    }
}

struct TableViewModel: Decodable {
    let contractVersion: Int
    let engineBoundary: EngineBoundary
    let viewer: Viewer
    let table: Table
    let panels: Panels
    let selection: Selection?
    let legalActions: [LegalAction]
}

struct EngineBoundary: Decodable {
    let snapshotRevision: Int
    let actionRevision: Int
    let source: String
    let actionLogCount: Int?
    let redacted: Bool?
}

struct Viewer: Decodable {
    let seatID: Int?
    let isOnline: Bool
    let privacyMode: String
    let connection: String?
}

struct Table: Decodable {
    let year: Int
    let phase: String
    let phasePrompt: Prompt
    let currentPlayerID: Int
    let leadPlayerID: Int
    let trump: String?
    let isFamine: Bool
    let trickCount: Int
    let maxTricks: Int
    let seats: [Seat]
    let jobs: [Job]
    let trick: Trick
    let lastTrick: Trick
    let scoreboard: [Score]
    let requisitionEvents: [RequisitionEvent]?
}

struct Prompt: Decodable {
    let title: String
    let body: String
    let tone: String
    let primaryActionID: String?
}

struct Seat: Decodable {
    let id: Int
    let name: String
    let controller: String
    let isViewer: Bool
    let isCurrentTurn: Bool
    let isBrigadeLeader: Bool
    let isProtected: Bool?
    let hand: [ContractCard]
    let hiddenHandCount: Int
    let plot: Plot
    let medals: Int
    let bankedMedals: Int?
    let visibleScore: Int
}

struct Plot: Decodable {
    let revealed: [ContractCard]
    let hidden: [ContractCard]
    let hiddenCount: Int
    let stacks: [PlotStack]
}

struct PlotStack: Decodable {
    let revealed: [ContractCard]
    let hiddenCount: Int
}

struct Job: Decodable {
    let suit: String
    let hours: Int
    let requiredHours: Int
    let claimed: Bool
    let reward: ContractCard?
    let assignedCards: [ContractCard]
    let validAssignmentTarget: Bool
    let highlighted: Bool?
}

struct Trick: Decodable {
    let plays: [TrickPlay]
    let winnerSeatID: Int?
}

struct TrickPlay: Decodable {
    let seatID: Int
    let card: ContractCard
}

struct ContractCard: Decodable {
    let id: String
    let suit: String
    let value: Int
    let rank: String
    let zone: String
    let visible: Bool
    let ownerSeatID: Int?
    let selected: Bool?
    let disabled: Bool?
    let highlighted: Bool?
    let pending: Bool?
    let exiled: Bool?
}

struct Score: Decodable {
    let seatID: Int
    let visibleScore: Int
    let finalScore: Int?
}

struct RequisitionEvent: Decodable {
    let seatID: Int?
    let suit: String
    let card: ContractCard?
    let message: String
}

struct Panels: Decodable {
    let active: String
    let suggested: String?
    let available: [String]
    let rightInfo: RightInfo
}

struct RightInfo: Decodable {
    let mode: String
    let title: String
    let sections: [InfoSection]
}

struct InfoSection: Decodable {
    let title: String
    let body: String
}

struct Selection: Decodable {
    let handCardID: String?
    let plotCardID: String?
    let assignmentCardID: String?
    let hoveredSuit: String?
}

struct LegalAction: Decodable {
    let id: String
    let kind: String
    let label: String?
    let enabled: Bool
    let targets: [String]?
    let engineAction: EngineAction
}

struct EngineAction: Decodable {
    let kind: String
    let playerID: Int
}

struct DesignTokens: Decodable {
    let version: Int
    let color: [String: JSONValue]
    let spacing: [String: JSONValue]
    let radius: [String: JSONValue]
    let typography: TypographyTokens
    let card: CardTokens
    let layout: [String: JSONValue]
    let motion: [String: JSONValue]
}

struct TypographyTokens: Decodable {
    let family: String
    let textScale: [String: Double]
}

struct CardTokens: Decodable {
    let aspectRatio: Double
    let sizes: [String: CardSizeTokens]
}

struct CardSizeTokens: Decodable {
    let width: Double
    let height: Double
}

enum JSONValue: Decodable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else {
            self = .array(try container.decode([JSONValue].self))
        }
    }
}

let decoder = JSONDecoder()

do {
    let root = try repoRoot()
    let fixturesURL = root.appendingPathComponent("shared/app-contracts/fixtures", isDirectory: true)
    let tokensURL = root.appendingPathComponent("shared/design/tokens.json")
    let fixtures = try fixtureURLs(at: fixturesURL)

    var decodedFixtureCount = 0
    for fixtureURL in fixtures {
        let fixture = try decoder.decode(TableViewModel.self, from: Data(contentsOf: fixtureURL))
        try validate(fixture, named: fixtureURL.lastPathComponent)
        decodedFixtureCount += 1
    }

    let tokens = try decoder.decode(DesignTokens.self, from: Data(contentsOf: tokensURL))
    try validate(tokens)

    print("Kolkhoz contract smoke tests passed (\(decodedFixtureCount) fixtures)")
} catch {
    fputs("Kolkhoz contract smoke tests failed: \(error)\n", stderr)
    exit(1)
}

func repoRoot() throws -> URL {
    let fileManager = FileManager.default
    var url = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    for _ in 0..<8 {
        let marker = url.appendingPathComponent("shared/app-contracts/fixtures", isDirectory: true).path
        if fileManager.fileExists(atPath: marker) {
            return url
        }
        url.deleteLastPathComponent()
    }
    throw ContractSmokeTestError.missingPath("shared/app-contracts/fixtures")
}

func fixtureURLs(at directory: URL) throws -> [URL] {
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    guard !urls.isEmpty else {
        throw ContractSmokeTestError.missingPath(directory.path)
    }
    return urls
}

func validate(_ fixture: TableViewModel, named name: String) throws {
    try expect(fixture.contractVersion == 1, "\(name): unexpected contract version")
    try expect(fixture.engineBoundary.snapshotRevision >= 1, "\(name): missing snapshot revision")
    try expect(fixture.engineBoundary.actionRevision >= 1, "\(name): missing action revision")
    try expect((1...5).contains(fixture.table.year), "\(name): year outside 1...5")
    try expect([3, 4].contains(fixture.table.maxTricks), "\(name): maxTricks must be 3 or 4")
    try expect(fixture.table.seats.count == 4, "\(name): expected four seats")
    try expect(Set(fixture.table.seats.map(\.id)) == Set(0...3), "\(name): seat IDs must be 0...3")
    try expect(fixture.table.jobs.count == 4, "\(name): expected four jobs")
    try expect(Set(fixture.table.jobs.map(\.suit)) == Set(["wheat", "sunflower", "potato", "beet"]), "\(name): jobs must cover all suits")
    try expect(fixture.table.scoreboard.count == 4, "\(name): expected four scores")
    try expect(fixture.panels.available.contains(fixture.panels.active), "\(name): active panel is unavailable")

    if let suggested = fixture.panels.suggested {
        try expect(fixture.panels.available.contains(suggested), "\(name): suggested panel is unavailable")
    }

    let legalActionIDs = Set(fixture.legalActions.map(\.id))
    if let primaryActionID = fixture.table.phasePrompt.primaryActionID {
        try expect(legalActionIDs.contains(primaryActionID), "\(name): primary action is not legal")
    }

    for action in fixture.legalActions {
        try expect(action.kind == action.engineAction.kind, "\(name): action kind does not match engine action for \(action.id)")
        try expect((0...3).contains(action.engineAction.playerID), "\(name): action playerID outside 0...3 for \(action.id)")
    }

    let visibleCardIDs = collectCardIDs(from: fixture)
    if let selection = fixture.selection {
        for selectedID in [selection.handCardID, selection.plotCardID, selection.assignmentCardID].compactMap({ $0 }) {
            try expect(visibleCardIDs.contains(selectedID), "\(name): selected card \(selectedID) is not visible in the fixture")
        }
    }
}

func validate(_ tokens: DesignTokens) throws {
    try expect(tokens.version == 1, "tokens: unexpected version")
    try expect(tokens.typography.family == "Handjet", "tokens: expected Handjet typography family")
    try expect(tokens.card.aspectRatio > 1, "tokens: card aspect ratio should be portrait")
    for (name, size) in tokens.card.sizes {
        let expectedHeight = size.width * tokens.card.aspectRatio
        try expect(abs(size.height - expectedHeight) < 0.01, "tokens: card size \(name) does not match aspect ratio")
    }
}

func collectCardIDs(from fixture: TableViewModel) -> Set<String> {
    var ids = Set<String>()
    for seat in fixture.table.seats {
        ids.formUnion(seat.hand.map(\.id))
        ids.formUnion(seat.plot.revealed.map(\.id))
        ids.formUnion(seat.plot.hidden.map(\.id))
        for stack in seat.plot.stacks {
            ids.formUnion(stack.revealed.map(\.id))
        }
    }
    for job in fixture.table.jobs {
        if let reward = job.reward { ids.insert(reward.id) }
        ids.formUnion(job.assignedCards.map(\.id))
    }
    ids.formUnion(fixture.table.trick.plays.map(\.card.id))
    ids.formUnion(fixture.table.lastTrick.plays.map(\.card.id))
    ids.formUnion(fixture.table.requisitionEvents?.compactMap(\.card?.id) ?? [])
    return ids
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else {
        throw ContractSmokeTestError.failed(message)
    }
}
