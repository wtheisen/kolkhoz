import KolkhozCore
import SwiftUI

enum AppLanguage: String, CaseIterable {
    case english = "EN"
    case russian = "RU"

    var toggleTitle: String {
        self == .english ? "RU" : "EN"
    }

    mutating func toggle() {
        self = self == .english ? .russian : .english
    }
}

public struct KolkhozRootView: View {
    @StateObject private var store = GameStore()
    @State private var showingLobby = true
    @State private var selectedPreset: GamePreset = .kolkhoz
    @State private var customVariants = GameVariants.kolkhoz
    @State private var showingRules = false
    @State private var language: AppLanguage = .english

    public init() {}

    public var body: some View {
        Group {
            if showingLobby {
                LobbyView(
                    selectedPreset: $selectedPreset,
                    customVariants: $customVariants,
                    showingRules: $showingRules,
                    onStart: startGame
                )
            } else {
                GameBoardView(language: $language) {
                    showingLobby = true
                }
            }
        }
            .environmentObject(store)
    }

    private var activeVariants: GameVariants {
        selectedPreset.variants ?? customVariants
    }

    private func startGame() {
        store.newGame(variants: activeVariants)
        showingLobby = false
    }
}
