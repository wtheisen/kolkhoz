import Foundation
import KolkhozCore
import Network

@main
struct KolkhozOnlineServerMain {
    static func main() throws {
        let portValue = UInt16(ProcessInfo.processInfo.environment["PORT"] ?? "8787") ?? 8787
        let server = try KolkhozOnlineHTTPServer(port: portValue)
        server.start()
        print("KolkhozOnlineServer listening on http://127.0.0.1:\(portValue)")
        dispatchMain()
    }
}

final class KolkhozOnlineHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "kolkhoz.online.server")
    private let router = KolkhozOnlineHTTPRouter()

    init(port: UInt16) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw URLError(.badURL)
        }
        listener = try NWListener(using: .tcp, on: nwPort)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection)
        }
        listener.start(queue: queue)
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        receive(from: connection, buffered: Data())
    }

    private func receive(from connection: NWConnection, buffered: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var nextBuffer = buffered
            if let data {
                nextBuffer.append(data)
            }
            if let request = HTTPRequest(data: nextBuffer) {
                let response = self.route(request)
                connection.send(content: response.httpData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
                return
            }
            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(from: connection, buffered: nextBuffer)
        }
    }

    private func route(_ request: HTTPRequest) -> HTTPResponse {
        let routeResponse = routeOnWorker(request)
        return HTTPResponse(
            statusCode: routeResponse.statusCode,
            contentType: routeResponse.contentType,
            body: routeResponse.body
        )
    }

    private func routeOnWorker(_ request: HTTPRequest) -> KolkhozHTTPRouteResponse {
        let box = RouteResponseBox()
        let semaphore = DispatchSemaphore(value: 0)
        let thread = Thread {
            let response = self.router.handle(
                method: request.method,
                path: request.path,
                queryItems: request.queryItems,
                body: request.body
            )
            box.set(response)
            semaphore.signal()
        }
        thread.stackSize = 16 * 1024 * 1024
        thread.start()
        semaphore.wait()
        return box.get() ?? KolkhozHTTPRouteResponse(statusCode: 500)
    }
}

final class RouteResponseBox: @unchecked Sendable {
    private let lock = NSLock()
    private var response: KolkhozHTTPRouteResponse?

    func set(_ response: KolkhozHTTPRouteResponse) {
        lock.lock()
        self.response = response
        lock.unlock()
    }

    func get() -> KolkhozHTTPRouteResponse? {
        lock.lock()
        defer { lock.unlock() }
        return response
    }
}

struct HTTPRequest {
    var method: String
    var path: String
    var queryItems: [URLQueryItem]
    var body: Data

    init?(data: Data) {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else { return nil }
        let headerData = data[..<headerRange.lowerBound]
        guard let headerText = String(data: headerData, encoding: .utf8) else { return nil }
        let lines = headerText.split(separator: "\r\n", omittingEmptySubsequences: false)
        guard let requestLine = lines.first else { return nil }
        let requestParts = requestLine.split(separator: " ")
        guard requestParts.count >= 2 else { return nil }

        var contentLength = 0
        for line in lines.dropFirst() {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0].lowercased() == "content-length" {
                contentLength = Int(parts[1]) ?? 0
            }
        }

        let bodyStart = headerRange.upperBound
        guard data.count >= bodyStart + contentLength else { return nil }

        method = String(requestParts[0])
        let rawTarget = String(requestParts[1])
        let components = URLComponents(string: rawTarget)
        path = components?.path ?? rawTarget
        queryItems = components?.queryItems ?? []
        body = data[bodyStart..<(bodyStart + contentLength)]
    }
}

struct HTTPResponse {
    var statusCode: Int
    var contentType: String
    var body: Data

    var httpData: Data {
        var data = Data()
        data.append(Data("HTTP/1.1 \(statusCode) \(reasonPhrase)\r\n".utf8))
        data.append(Data("Content-Type: \(contentType)\r\n".utf8))
        data.append(Data("Content-Length: \(body.count)\r\n".utf8))
        data.append(Data("Connection: close\r\n".utf8))
        data.append(Data("\r\n".utf8))
        data.append(body)
        return data
    }

    private var reasonPhrase: String {
        switch statusCode {
        case 200: "OK"
        case 400: "Bad Request"
        case 404: "Not Found"
        case 409: "Conflict"
        default: "Error"
        }
    }
}
