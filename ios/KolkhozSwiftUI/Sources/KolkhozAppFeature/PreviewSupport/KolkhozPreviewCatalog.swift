#if DEBUG
import KolkhozCore
import SwiftUI

struct KolkhozPreviewLobbyHost: View {
    @State private var selectedPreset = KolkhozPreviewFixtures.lobbyPreset
    @State private var customVariants = KolkhozPreviewFixtures.lobbyVariants
    @State private var showingRules: Bool

    init(showingRules: Bool = false) {
        _showingRules = State(initialValue: showingRules)
        KolkhozFontRegistry.registerFonts()
    }

    var body: some View {
        LobbyView(
            selectedPreset: $selectedPreset,
            customVariants: $customVariants,
            showingRules: $showingRules,
            onStart: {}
        )
        .font(.kolkhozLabel(.body))
    }
}

struct KolkhozPreviewBoardHost: View {
    @StateObject private var store: GameStore
    @State private var language: AppLanguage

    init(state: KolkhozState, language: AppLanguage = .english) {
        _store = StateObject(wrappedValue: GameStore(previewState: state))
        _language = State(initialValue: language)
        KolkhozFontRegistry.registerFonts()
    }

    var body: some View {
        GameBoardView(language: $language, onMenu: {})
            .font(.kolkhozLabel(.body))
            .environmentObject(store)
    }
}

#Preview("00 Lobby") {
    KolkhozPreviewLobbyHost()
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("01 Lobby Rules") {
    KolkhozPreviewLobbyHost(showingRules: true)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("02 Board Planning") {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.planningState)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("03 Board Trick") {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.trickState)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("04 Board Assignment") {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.assignmentState)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("05 Board Swap") {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.swapState)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("06 Board Requisition") {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.requisitionState)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("07 Board Game Over") {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.gameOverState)
        .previewDevice("iPhone 17 Pro")
        .previewInterfaceOrientation(.landscapeLeft)
}

#Preview("08 Player Panels") {
    VStack(alignment: .leading, spacing: 14) {
        PlayerPanel(
            player: KolkhozPreviewFixtures.playerPanelOpponent,
            score: 18,
            active: true,
            human: false
        )
        .frame(width: 104, height: 56)

        PlayerPanel(
            player: KolkhozPreviewFixtures.playerPanelHuman,
            score: 24,
            active: false,
            human: true
        )
        .frame(width: 104, height: 56)

        PlayerPanel(
            player: KolkhozPreviewFixtures.playerPanelOpponent,
            score: 18,
            active: true,
            human: false
        )
        .frame(width: 280, height: 64)
    }
    .padding(18)
    .background(Color.kolkhozBackground)
    .onAppear {
        KolkhozFontRegistry.registerFonts()
    }
}
#endif
