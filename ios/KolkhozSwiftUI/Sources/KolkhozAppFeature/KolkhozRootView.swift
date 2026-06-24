import KolkhozCore
import SwiftUI

public struct KolkhozRootView: View {
    @StateObject private var store: GameStore
    @State private var showingLobby: Bool
    @State private var selectedPreset: GamePreset = .kolkhoz
    @State private var customVariants = GameVariants.kolkhoz
    @State private var showingRules = false
    @AppStorage("kolkhoz-lang") private var languageRawValue = KolkhozLanguage.ru.rawValue
    private let initialPanel: GamePanel?

    public init() {
        KolkhozFontRegistry.registerFonts()
        #if DEBUG
        if let preview = KolkhozLaunchPreview.current {
            _store = StateObject(wrappedValue: GameStore(previewState: preview.state))
            _showingLobby = State(initialValue: preview.showingLobby)
            initialPanel = preview.panel
            return
        }
        #endif
        _store = StateObject(wrappedValue: GameStore())
        _showingLobby = State(initialValue: true)
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
                        showingRules: $showingRules,
                        onStart: startGame
                    )
                } else {
                    GameBoardView(initialPanel: initialPanel) {
                        returnToLobby()
                    }
                }
            }
        }
        .font(.kolkhozLabel(.body))
        .environmentObject(store)
        .environment(\.kolkhozLanguage, language)
        .environment(\.toggleKolkhozLanguage, toggleLanguage)
    }

    private var language: KolkhozLanguage {
        KolkhozLanguage(storedValue: languageRawValue)
    }

    private var activeVariants: GameVariants {
        selectedPreset.variants ?? customVariants
    }

    private func startGame() {
        store.newGame(variants: activeVariants)
        showingLobby = false
    }

    private func returnToLobby() {
        showingRules = false
        showingLobby = true
    }

    private func toggleLanguage() {
        languageRawValue = language.next.rawValue
    }
}

#if DEBUG
private struct KolkhozLaunchPreview {
    let state: KolkhozState
    let showingLobby: Bool
    let panel: GamePanel?

    static var current: KolkhozLaunchPreview? {
        guard let value = ProcessInfo.processInfo.arguments.previewArgumentValue else {
            return nil
        }

        switch value {
        case "planning":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.planningState, showingLobby: false, panel: nil)
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
        case "gameOver":
            return KolkhozLaunchPreview(state: KolkhozPreviewFixtures.gameOverState, showingLobby: false, panel: nil)
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
