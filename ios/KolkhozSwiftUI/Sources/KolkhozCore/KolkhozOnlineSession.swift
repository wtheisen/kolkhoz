import Foundation
import KolkhozCEngine

public enum KolkhozOnlineSessionError: Error, Equatable, Sendable {
    case sessionNotFound
    case seatUnavailable
    case seatNotJoined
    case wrongPlayer
    case illegalAction
}

public struct KolkhozOnlineCreateSessionRequest: Codable, Equatable, Sendable {
    public var seed: UInt64?
    public var variants: GameVariants
    public var controllers: [PlayerController]

    public init(
        seed: UInt64? = nil,
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = KolkhozHeadlessEngine.allHumanControllers
    ) {
        self.seed = seed
        self.variants = variants
        self.controllers = PlayerController.normalized(controllers)
    }
}

public struct KolkhozOnlineJoinSessionRequest: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var preferredPlayerID: Int32?

    public init(sessionID: UUID, preferredPlayerID: Int32? = nil) {
        self.sessionID = sessionID
        self.preferredPlayerID = preferredPlayerID
    }
}

public struct KolkhozOnlineSubmitActionRequest: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var playerID: Int32
    public var action: KolkhozEngineAction

    public init(sessionID: UUID, playerID: Int32, action: KolkhozEngineAction) {
        self.sessionID = sessionID
        self.playerID = playerID
        self.action = action
    }
}

public struct KolkhozOnlineStateRequest: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var viewerID: Int32?

    public init(sessionID: UUID, viewerID: Int32? = nil) {
        self.sessionID = sessionID
        self.viewerID = viewerID
    }
}

public struct KolkhozOnlineJoinSessionResponse: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var playerID: Int32
    public var update: KolkhozOnlineSessionUpdate

    public init(sessionID: UUID, playerID: Int32, update: KolkhozOnlineSessionUpdate) {
        self.sessionID = sessionID
        self.playerID = playerID
        self.update = update
    }
}

public typealias KolkhozOnlineCreateSessionResponse = KolkhozOnlineJoinSessionResponse

public struct KolkhozOnlineSessionUpdate: Codable, Equatable, Sendable {
    public var sessionID: UUID
    public var viewerID: Int32?
    public var actionLogCount: Int
    public var variants: GameVariants
    public var controllers: [PlayerController]
    public var snapshot: KolkhozEngineSnapshot

    public init(
        sessionID: UUID,
        viewerID: Int32?,
        actionLogCount: Int,
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = KolkhozHeadlessEngine.allHumanControllers,
        snapshot: KolkhozEngineSnapshot
    ) {
        self.sessionID = sessionID
        self.viewerID = viewerID
        self.actionLogCount = actionLogCount
        self.variants = variants
        self.controllers = PlayerController.normalized(controllers)
        self.snapshot = snapshot
    }
}

public final class KolkhozAuthoritativeSession {
    public let id: UUID
    private let engine: KolkhozCEngineAdapter

    public init(
        id: UUID = UUID(),
        seed: UInt64 = UInt64(Date().timeIntervalSince1970),
        variants: GameVariants = .kolkhoz,
        controllers: [PlayerController] = KolkhozHeadlessEngine.allHumanControllers
    ) {
        self.id = id
        self.engine = KolkhozCEngineAdapter(seed: seed, variants: variants, controllers: controllers)
    }

    public init(id: UUID = UUID(), savedGame: KolkhozCEngineSavedGame) throws {
        self.id = id
        self.engine = try KolkhozCEngineAdapter(savedGame: savedGame)
    }

    public var savedGame: KolkhozCEngineSavedGame {
        engine.savedGame
    }

    public var fullSnapshot: KolkhozEngineSnapshot {
        engine.snapshot
    }

    public func update(for viewerID: Int32?) -> KolkhozOnlineSessionUpdate {
        let savedGame = savedGame
        return KolkhozOnlineSessionUpdate(
            sessionID: id,
            viewerID: viewerID,
            actionLogCount: savedGame.actions.count,
            variants: savedGame.variants,
            controllers: savedGame.controllers,
            snapshot: fullSnapshot.redacted(for: viewerID)
        )
    }

    public func legalActions(for playerID: Int32) -> [KolkhozEngineAction] {
        engine.legalActions().compactMap { action in
            if action.playerID == playerID {
                return action
            }
            if action.kind == .continueAfterRequisition {
                var copy = action
                copy.playerID = playerID
                return copy
            }
            return nil
        }
    }

    @discardableResult
    public func submit(_ action: KolkhozEngineAction, from playerID: Int32) throws -> KolkhozOnlineSessionUpdate {
        guard action.playerID == playerID else {
            throw KolkhozOnlineSessionError.wrongPlayer
        }
        guard legalActions(for: playerID).contains(action) else {
            throw KolkhozOnlineSessionError.illegalAction
        }
        try engine.apply(action)
        return update(for: playerID)
    }
}

public final class KolkhozOnlineSessionService {
    private struct HostedSession {
        var session: KolkhozAuthoritativeSession
        var occupiedSeats: Set<Int32>
    }

    private var sessions: [UUID: HostedSession] = [:]

    public init() {}

    public func createSession(_ request: KolkhozOnlineCreateSessionRequest) throws -> KolkhozOnlineCreateSessionResponse {
        let seed = request.seed ?? UInt64(Date().timeIntervalSince1970)
        let session = KolkhozAuthoritativeSession(
            seed: seed,
            variants: request.variants,
            controllers: request.controllers
        )
        let playerID = try firstAvailableSeat(in: session, occupiedSeats: [])
        sessions[session.id] = HostedSession(session: session, occupiedSeats: [playerID])
        return KolkhozOnlineCreateSessionResponse(
            sessionID: session.id,
            playerID: playerID,
            update: session.update(for: playerID)
        )
    }

    public func joinSession(_ request: KolkhozOnlineJoinSessionRequest) throws -> KolkhozOnlineJoinSessionResponse {
        guard var hosted = sessions[request.sessionID] else {
            throw KolkhozOnlineSessionError.sessionNotFound
        }
        let playerID: Int32
        if let preferred = request.preferredPlayerID {
            guard isJoinableSeat(preferred, in: hosted.session),
                  !hosted.occupiedSeats.contains(preferred) else {
                throw KolkhozOnlineSessionError.seatUnavailable
            }
            playerID = preferred
        } else {
            playerID = try firstAvailableSeat(in: hosted.session, occupiedSeats: hosted.occupiedSeats)
        }
        hosted.occupiedSeats.insert(playerID)
        sessions[request.sessionID] = hosted
        return KolkhozOnlineJoinSessionResponse(
            sessionID: request.sessionID,
            playerID: playerID,
            update: hosted.session.update(for: playerID)
        )
    }

    public func update(_ request: KolkhozOnlineStateRequest) throws -> KolkhozOnlineSessionUpdate {
        guard let hosted = sessions[request.sessionID] else {
            throw KolkhozOnlineSessionError.sessionNotFound
        }
        return hosted.session.update(for: request.viewerID)
    }

    public func legalActions(sessionID: UUID, playerID: Int32) throws -> [KolkhozEngineAction] {
        guard let hosted = sessions[sessionID] else {
            throw KolkhozOnlineSessionError.sessionNotFound
        }
        return hosted.session.legalActions(for: playerID)
    }

    public func submitAction(_ request: KolkhozOnlineSubmitActionRequest) throws -> KolkhozOnlineSessionUpdate {
        guard let hosted = sessions[request.sessionID] else {
            throw KolkhozOnlineSessionError.sessionNotFound
        }
        guard hosted.occupiedSeats.contains(request.playerID) else {
            throw KolkhozOnlineSessionError.seatNotJoined
        }
        return try hosted.session.submit(request.action, from: request.playerID)
    }

    public func savedGame(sessionID: UUID) throws -> KolkhozCEngineSavedGame {
        guard let hosted = sessions[sessionID] else {
            throw KolkhozOnlineSessionError.sessionNotFound
        }
        return hosted.session.savedGame
    }

    public func restoreSession(id: UUID = UUID(), savedGame: KolkhozCEngineSavedGame) throws -> UUID {
        let session = try KolkhozAuthoritativeSession(id: id, savedGame: savedGame)
        sessions[id] = HostedSession(session: session, occupiedSeats: [])
        return id
    }

    private func firstAvailableSeat(in session: KolkhozAuthoritativeSession, occupiedSeats: Set<Int32>) throws -> Int32 {
        for playerID in Int32(0)..<Int32(KC_PLAYER_COUNT) where isJoinableSeat(playerID, in: session) && !occupiedSeats.contains(playerID) {
            return playerID
        }
        throw KolkhozOnlineSessionError.seatUnavailable
    }

    private func isJoinableSeat(_ playerID: Int32, in session: KolkhozAuthoritativeSession) -> Bool {
        let controllers = session.savedGame.controllers
        guard playerID >= 0, playerID < Int32(controllers.count) else { return false }
        return controllers[Int(playerID)] == .human
    }
}

public protocol KolkhozOnlineTransport: Sendable {
    func createSession(_ request: KolkhozOnlineCreateSessionRequest) async throws -> KolkhozOnlineCreateSessionResponse
    func joinSession(_ request: KolkhozOnlineJoinSessionRequest) async throws -> KolkhozOnlineJoinSessionResponse
    func fetchUpdate(_ request: KolkhozOnlineStateRequest) async throws -> KolkhozOnlineSessionUpdate
    func fetchLegalActions(sessionID: UUID, playerID: Int32) async throws -> [KolkhozEngineAction]
    func submitAction(_ request: KolkhozOnlineSubmitActionRequest) async throws -> KolkhozOnlineSessionUpdate
}

public actor KolkhozInMemoryOnlineTransport: KolkhozOnlineTransport {
    private let service: KolkhozOnlineSessionService

    public init(service: KolkhozOnlineSessionService = KolkhozOnlineSessionService()) {
        self.service = service
    }

    public func createSession(_ request: KolkhozOnlineCreateSessionRequest) throws -> KolkhozOnlineCreateSessionResponse {
        try service.createSession(request)
    }

    public func joinSession(_ request: KolkhozOnlineJoinSessionRequest) throws -> KolkhozOnlineJoinSessionResponse {
        try service.joinSession(request)
    }

    public func fetchUpdate(_ request: KolkhozOnlineStateRequest) throws -> KolkhozOnlineSessionUpdate {
        try service.update(request)
    }

    public func fetchLegalActions(sessionID: UUID, playerID: Int32) throws -> [KolkhozEngineAction] {
        try service.legalActions(sessionID: sessionID, playerID: playerID)
    }

    public func submitAction(_ request: KolkhozOnlineSubmitActionRequest) throws -> KolkhozOnlineSessionUpdate {
        try service.submitAction(request)
    }
}

public final class KolkhozOnlineClient: Sendable {
    private let transport: any KolkhozOnlineTransport

    public init(transport: any KolkhozOnlineTransport) {
        self.transport = transport
    }

    public func createSession(_ request: KolkhozOnlineCreateSessionRequest = KolkhozOnlineCreateSessionRequest()) async throws -> KolkhozOnlineCreateSessionResponse {
        try await transport.createSession(request)
    }

    public func joinSession(sessionID: UUID, preferredPlayerID: Int32? = nil) async throws -> KolkhozOnlineJoinSessionResponse {
        try await transport.joinSession(KolkhozOnlineJoinSessionRequest(sessionID: sessionID, preferredPlayerID: preferredPlayerID))
    }

    public func update(sessionID: UUID, viewerID: Int32?) async throws -> KolkhozOnlineSessionUpdate {
        try await transport.fetchUpdate(KolkhozOnlineStateRequest(sessionID: sessionID, viewerID: viewerID))
    }

    public func legalActions(sessionID: UUID, playerID: Int32) async throws -> [KolkhozEngineAction] {
        try await transport.fetchLegalActions(sessionID: sessionID, playerID: playerID)
    }

    public func submit(sessionID: UUID, playerID: Int32, action: KolkhozEngineAction) async throws -> KolkhozOnlineSessionUpdate {
        try await transport.submitAction(KolkhozOnlineSubmitActionRequest(sessionID: sessionID, playerID: playerID, action: action))
    }
}

public final class KolkhozHTTPOnlineTransport: KolkhozOnlineTransport, @unchecked Sendable {
    private let baseURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    public func createSession(_ request: KolkhozOnlineCreateSessionRequest) async throws -> KolkhozOnlineCreateSessionResponse {
        try await send(path: "sessions", method: "POST", body: request)
    }

    public func joinSession(_ request: KolkhozOnlineJoinSessionRequest) async throws -> KolkhozOnlineJoinSessionResponse {
        try await send(path: "sessions/\(request.sessionID.uuidString)/join", method: "POST", body: request)
    }

    public func fetchUpdate(_ request: KolkhozOnlineStateRequest) async throws -> KolkhozOnlineSessionUpdate {
        var components = URLComponents(url: baseURL.appendingPathComponent("sessions/\(request.sessionID.uuidString)/state"), resolvingAgainstBaseURL: false)
        if let viewerID = request.viewerID {
            components?.queryItems = [URLQueryItem(name: "viewerID", value: "\(viewerID)")]
        }
        guard let url = components?.url else {
            throw URLError(.badURL)
        }
        return try await send(url: url, method: "GET", body: Optional<Int>.none)
    }

    public func fetchLegalActions(sessionID: UUID, playerID: Int32) async throws -> [KolkhozEngineAction] {
        try await send(path: "sessions/\(sessionID.uuidString)/players/\(playerID)/actions", method: "GET", body: Optional<Int>.none)
    }

    public func submitAction(_ request: KolkhozOnlineSubmitActionRequest) async throws -> KolkhozOnlineSessionUpdate {
        try await send(path: "sessions/\(request.sessionID.uuidString)/actions", method: "POST", body: request)
    }

    private func send<Request: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: Request?
    ) async throws -> Response {
        try await send(url: baseURL.appendingPathComponent(path), method: method, body: body)
    }

    private func send<Request: Encodable, Response: Decodable>(
        url: URL,
        method: String,
        body: Request?
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body {
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return try decoder.decode(Response.self, from: data)
    }
}

public extension KolkhozEngineSnapshot {
    func redacted(for viewerID: Int32?) -> KolkhozEngineSnapshot {
        var redacted = self
        redacted.jobPiles = jobPiles.map { KolkhozEngineSuitCardsSnapshot(suit: $0.suit, cards: []) }
        redacted.accumulatedJobCards = accumulatedJobCards.map { KolkhozEngineSuitCardsSnapshot(suit: $0.suit, cards: []) }

        redacted.players = players.map { player in
            var copy = player
            let isViewer = viewerID == player.id
            if !isViewer {
                copy.hand = []
                copy.hiddenPlot = []
                copy.stacks = copy.stacks.map { stack in
                    KolkhozEnginePlotStackSnapshot(revealed: stack.revealed, hidden: [])
                }
            }
            return copy
        }

        if phase != Int32(KC_PHASE_GAME_OVER) {
            redacted.scores = scores.map { score in
                guard viewerID == score.playerID else {
                    return KolkhozEngineScoreSnapshot(
                        playerID: score.playerID,
                        visibleScore: score.visibleScore,
                        finalScore: score.visibleScore
                    )
                }
                return score
            }
        }

        if lastSwap?.playerID != viewerID {
            redacted.lastSwap = nil
        }
        return redacted
    }
}
