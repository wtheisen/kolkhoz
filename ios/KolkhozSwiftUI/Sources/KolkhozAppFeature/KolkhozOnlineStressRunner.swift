import Foundation
import KolkhozCore

#if DEBUG
public struct KolkhozOnlineStressResult: Sendable {
    public var sessionID: UUID
    public var playerID: Int32
    public var submittedActions: Int
    public var actionLogCount: Int
    public var phase: Int32
}

public enum KolkhozOnlineStressError: Error, Sendable {
    case noLegalAction(sessionID: UUID, playerID: Int32)
}

public enum KolkhozOnlineStressRunner {
    public static func run(baseURL: URL, seed: UInt64, maxActions: Int) async throws -> KolkhozOnlineStressResult {
        let client = KolkhozOnlineClient(transport: KolkhozHTTPOnlineTransport(baseURL: baseURL))
        let created = try await client.createSession(KolkhozOnlineCreateSessionRequest(
            seed: seed,
            controllers: [.human, .heuristicAI, .heuristicAI, .heuristicAI]
        ))
        let sessionID = created.sessionID
        let playerID = created.playerID
        var update = created.update
        var submittedActions = 0

        print("KolkhozOnlineStress: connected session=\(sessionID.uuidString) player=\(playerID) baseURL=\(baseURL.absoluteString)")

        while submittedActions < maxActions {
            update = try await client.update(sessionID: sessionID, viewerID: playerID)
            guard update.snapshot.waitingForExternalAction else {
                break
            }
            if update.snapshot.waitingPlayer != playerID {
                try await Task.sleep(nanoseconds: 50_000_000)
                continue
            }

            let actions = try await client.legalActions(sessionID: sessionID, playerID: playerID)
            guard let action = chooseAction(from: actions) else {
                throw KolkhozOnlineStressError.noLegalAction(sessionID: sessionID, playerID: playerID)
            }
            update = try await client.submit(sessionID: sessionID, playerID: playerID, action: action)
            submittedActions += 1
            print("KolkhozOnlineStress: submitted=\(submittedActions) kind=\(action.kind.rawValue) actionLogCount=\(update.actionLogCount) phase=\(update.snapshot.phase)")
        }

        return KolkhozOnlineStressResult(
            sessionID: sessionID,
            playerID: playerID,
            submittedActions: submittedActions,
            actionLogCount: update.actionLogCount,
            phase: update.snapshot.phase
        )
    }

    private static func chooseAction(from actions: [KolkhozEngineAction]) -> KolkhozEngineAction? {
        let preferredKinds: [KolkhozEngineActionKind] = [
            .confirmSwap,
            .submitAssignments,
            .continueAfterRequisition,
            .setTrump,
            .assign,
            .playCard,
            .swap
        ]
        for kind in preferredKinds {
            if let action = actions.first(where: { $0.kind == kind }) {
                return action
            }
        }
        return actions.first(where: { $0.kind != .undoSwap })
    }
}
#endif
