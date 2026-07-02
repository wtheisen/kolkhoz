import Foundation

public struct KolkhozHTTPRouteResponse: Sendable {
    public var statusCode: Int
    public var body: Data
    public var contentType: String

    public init(statusCode: Int, body: Data = Data(), contentType: String = "application/json") {
        self.statusCode = statusCode
        self.body = body
        self.contentType = contentType
    }
}

public final class KolkhozOnlineHTTPRouter {
    private let service: KolkhozOnlineSessionService
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(service: KolkhozOnlineSessionService = KolkhozOnlineSessionService()) {
        self.service = service
    }

    public func handle(method: String, path: String, queryItems: [URLQueryItem] = [], body: Data = Data()) -> KolkhozHTTPRouteResponse {
        do {
            let response = try route(method: method.uppercased(), path: path, queryItems: queryItems, body: body)
            return response
        } catch let error as KolkhozOnlineSessionError {
            return errorResponse(error, statusCode: statusCode(for: error))
        } catch {
            return errorResponse(error, statusCode: 400)
        }
    }

    private func route(method: String, path: String, queryItems: [URLQueryItem], body: Data) throws -> KolkhozHTTPRouteResponse {
        let parts = path.split(separator: "/").map(String.init)
        if method == "GET", parts == ["health"] {
            return try json(["status": "ok"])
        }

        if method == "POST", parts == ["sessions"] {
            let request = body.isEmpty ? KolkhozOnlineCreateSessionRequest() : try decoder.decode(KolkhozOnlineCreateSessionRequest.self, from: body)
            return try json(service.createSession(request))
        }

        guard parts.count >= 2, parts[0] == "sessions", let sessionID = UUID(uuidString: parts[1]) else {
            return errorResponse("route not found", statusCode: 404)
        }

        if method == "POST", parts.count == 3, parts[2] == "join" {
            let request = body.isEmpty
                ? KolkhozOnlineJoinSessionRequest(sessionID: sessionID)
                : try decoder.decode(KolkhozOnlineJoinSessionRequest.self, from: body)
            return try json(service.joinSession(request))
        }

        if method == "GET", parts.count == 3, parts[2] == "state" {
            let viewerID = queryItems.first(where: { $0.name == "viewerID" })?.value.flatMap(Int32.init)
            return try json(service.update(KolkhozOnlineStateRequest(sessionID: sessionID, viewerID: viewerID)))
        }

        if method == "GET", parts.count == 5, parts[2] == "players", parts[4] == "actions", let playerID = Int32(parts[3]) {
            return try json(service.legalActions(sessionID: sessionID, playerID: playerID))
        }

        if method == "POST", parts.count == 3, parts[2] == "actions" {
            let request = try decoder.decode(KolkhozOnlineSubmitActionRequest.self, from: body)
            return try json(service.submitAction(request))
        }

        return errorResponse("route not found", statusCode: 404)
    }

    private func json<T: Encodable>(_ value: T, statusCode: Int = 200) throws -> KolkhozHTTPRouteResponse {
        KolkhozHTTPRouteResponse(statusCode: statusCode, body: try encoder.encode(value))
    }

    private func errorResponse(_ error: Error, statusCode: Int) -> KolkhozHTTPRouteResponse {
        errorResponse(String(describing: error), statusCode: statusCode)
    }

    private func errorResponse(_ message: String, statusCode: Int) -> KolkhozHTTPRouteResponse {
        let body = (try? encoder.encode(["error": message])) ?? Data()
        return KolkhozHTTPRouteResponse(statusCode: statusCode, body: body)
    }

    private func statusCode(for error: KolkhozOnlineSessionError) -> Int {
        switch error {
        case .sessionNotFound:
            return 404
        case .seatUnavailable, .seatNotJoined, .wrongPlayer, .illegalAction:
            return 409
        }
    }
}
