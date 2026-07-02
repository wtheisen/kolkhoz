import KolkhozCore
import SwiftUI

public struct KolkhozRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var store: GameStore
    @State private var showingLobby: Bool
    @State private var showingOnlineLobby = false
    @State private var selectedPreset: GamePreset = .kolkhoz
    @State private var customVariants = GameVariants.kolkhoz
    @State private var playerControllers = PlayerController.defaultControllers
    @State private var showingRules = false
    @State private var showingTutorial = false
    @AppStorage("kolkhoz-lang") private var languageRawValue = KolkhozLanguage.ru.rawValue
    @AppStorage("kolkhoz-appearance") private var appearanceRawValue = KolkhozAppearance.dark.rawValue
    @AppStorage("kolkhoz-readability") private var readabilityRawValue = KolkhozReadability.standard.rawValue
    private let initialPanel: GamePanel?

    public init() {
        KolkhozFontRegistry.registerFonts()
        #if DEBUG
        if let preview = KolkhozLaunchPreview.current {
            _store = StateObject(wrappedValue: GameStore(previewState: preview.state))
            _showingLobby = State(initialValue: preview.showingLobby)
            _showingRules = State(initialValue: preview.showingRules)
            initialPanel = preview.panel
            return
        }
        #endif
        let store = GameStore()
        _store = StateObject(wrappedValue: store)
        _showingLobby = State(initialValue: !store.restoredSavedGame)
        initialPanel = nil
    }

    public var body: some View {
        ZStack {
            Color.kolkhozTable
                .ignoresSafeArea()
            Group {
                if showingLobby {
                    LobbyView(
                        selectedPreset: $selectedPreset,
                        customVariants: $customVariants,
                        playerControllers: $playerControllers,
                        showingRules: $showingRules,
                        showingOnline: $showingOnlineLobby,
                        onTutorial: showTutorial,
                        onStart: startGame,
                        onHostOnline: hostOnlineGame,
                        onJoinOnline: joinOnlineGame
                    )
                } else {
                    GameBoardView(
                        initialPanel: initialPanel,
                        onMenu: returnToLobby,
                        onTutorial: showTutorial
                    )
                }
            }

            if showingTutorial {
                TutorialWalkthroughView {
                    showingTutorial = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(200)
            }
        }
        .font(.kolkhozLabel(.body))
        .environmentObject(store)
        .environment(\.kolkhozLanguage, language)
        .environment(\.toggleKolkhozLanguage, toggleLanguage)
        .environment(\.kolkhozAppearance, appearance)
        .environment(\.toggleKolkhozAppearance, toggleAppearance)
        .environment(\.kolkhozReadability, storedReadability)
        .environment(\.toggleKolkhozReadability, toggleReadability)
        .preferredColorScheme(appearance.colorScheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: showingTutorial)
        .task(id: store.onlineSessionID) {
            await pollOnlineGame()
        }
        .task {
            await runOnlineStressIfRequested()
        }
    }

    private var language: KolkhozLanguage {
        KolkhozLanguage(storedValue: languageRawValue)
    }

    private var appearance: KolkhozAppearance {
        KolkhozAppearance(storedValue: appearanceRawValue)
    }

    private var storedReadability: KolkhozReadability {
        KolkhozReadability(storedValue: readabilityRawValue)
    }

    private var activeVariants: GameVariants {
        selectedPreset.variants ?? customVariants
    }

    private func startGame() {
        store.newGame(variants: activeVariants, controllers: playerControllers)
        showingOnlineLobby = false
        showingLobby = false
    }

    private func returnToLobby() {
        store.leaveOnlineGame()
        showingRules = false
        showingOnlineLobby = false
        showingLobby = true
    }

    private func hostOnlineGame(baseURL: URL, controllers: [PlayerController]) async throws -> String {
        let code = try await store.hostOnlineGame(baseURL: baseURL, variants: activeVariants, controllers: controllers)
        showingOnlineLobby = false
        showingLobby = false
        return code
    }

    private func joinOnlineGame(baseURL: URL, inviteCode: String, preferredPlayerID: Int32?) async throws {
        try await store.joinOnlineGame(baseURL: baseURL, inviteCode: inviteCode, preferredPlayerID: preferredPlayerID)
        showingOnlineLobby = false
        showingLobby = false
    }

    private func pollOnlineGame() async {
        guard store.onlineSessionID != nil else { return }
        while !Task.isCancelled, store.onlineSessionID != nil {
            await store.refreshOnlineGame()
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func showTutorial() {
        showingTutorial = true
    }

    private func toggleLanguage() {
        languageRawValue = language.next.rawValue
    }

    private func toggleAppearance() {
        appearanceRawValue = appearance.next.rawValue
    }

    private func toggleReadability() {
        readabilityRawValue = storedReadability.next.rawValue
    }

    private func runOnlineStressIfRequested() async {
        #if DEBUG
        guard let baseURL = ProcessInfo.processInfo.environment["KOLKHOZ_ONLINE_STRESS_URL"].flatMap(URL.init(string:)) else {
            return
        }
        let maxActions = ProcessInfo.processInfo.environment["KOLKHOZ_ONLINE_STRESS_ACTIONS"].flatMap(Int.init) ?? 24
        let seed = ProcessInfo.processInfo.environment["KOLKHOZ_ONLINE_STRESS_SEED"].flatMap(UInt64.init) ?? 20260702
        do {
            let result = try await KolkhozOnlineStressRunner.run(baseURL: baseURL, seed: seed, maxActions: maxActions)
            print("KolkhozOnlineStress: PASS session=\(result.sessionID.uuidString) player=\(result.playerID) submitted=\(result.submittedActions) actionLogCount=\(result.actionLogCount) phase=\(result.phase)")
        } catch {
            print("KolkhozOnlineStress: FAIL \(error)")
        }
        #endif
    }
}

#if DEBUG
private struct KolkhozLaunchPreview {
    let state: KolkhozState
    let showingLobby: Bool
    var showingRules = false
    let panel: GamePanel?

    static var current: KolkhozLaunchPreview? {
        guard let value = ProcessInfo.processInfo.arguments.previewArgumentValue else {
            return nil
        }

        switch value {
        case "rules":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.planningState, showingLobby: true, showingRules: true, panel: nil)
        case "planning":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.planningState, showingLobby: false, panel: nil)
        case "famine":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.faminePlanningState, showingLobby: false, panel: nil)
        case "trick":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.trickState, showingLobby: false, panel: nil)
        case "assignment":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.assignmentState, showingLobby: false, panel: nil)
        case "swap":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.swapState, showingLobby: false, panel: nil)
        case "requisition":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.requisitionState, showingLobby: false, panel: nil)
        case "north":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.requisitionState, showingLobby: false, panel: .north)
        case "options":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.trickState, showingLobby: false, panel: .options)
        case "gameOver":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.gameOverState, showingLobby: false, panel: nil)
        case "hotSeatPass":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.hotSeatPassState, showingLobby: false, panel: nil)
        default:
            return nil
        }
    }
}

private extension [String] {
    var previewArgumentValue: String? {
        guard let index = firstIndex(of: "--kolkhoz-preview"), self.indices.contains(index + 1) else {
            return nil
        }
        return self[index + 1]
    }
}
#endif
