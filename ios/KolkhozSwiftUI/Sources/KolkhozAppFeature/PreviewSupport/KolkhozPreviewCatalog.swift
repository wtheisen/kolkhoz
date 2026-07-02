#if DEBUG
import KolkhozCore
import SwiftUI

struct KolkhozPreviewLobbyHost: View {
    @State private var selectedPreset = KolkhozPreviewFixtures.lobbyPreset
    @State private var customVariants = KolkhozPreviewFixtures.lobbyVariants
    @State private var playerControllers = PlayerController.defaultControllers
    @State private var showingRules: Bool
    @State private var showingOnline = false

    init(showingRules: Bool = false) {
        _showingRules = State(initialValue: showingRules)
        KolkhozFontRegistry.registerFonts()
    }

    var body: some View {
        LobbyView(
            selectedPreset: $selectedPreset,
            customVariants: $customVariants,
            playerControllers: $playerControllers,
            showingRules: $showingRules,
            showingOnline: $showingOnline,
            onTutorial: {},
            onStart: {},
            onHostOnline: { _, _ in UUID().uuidString },
            onJoinOnline: { _, _, _ in }
        )
        .font(.kolkhozLabel(.body))
    }
}

struct KolkhozPreviewBoardHost: View {
    @StateObject private var store: GameStore

    init(state: KolkhozState) {
        _store = StateObject(wrappedValue: GameStore(previewState: state))
        KolkhozFontRegistry.registerFonts()
    }

    var body: some View {
        ZStack {
            Color.kolkhozTable
                .ignoresSafeArea()
            GameBoardView(onMenu: {}, onTutorial: {})
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .font(.kolkhozLabel(.body))
        .environmentObject(store)
    }
}

#Preview("00 Lobby", traits: .landscapeLeft) {
    KolkhozPreviewLobbyHost()
}

#Preview("01 Lobby Rules", traits: .landscapeLeft) {
    KolkhozPreviewLobbyHost(showingRules: true)
}

#Preview("02 Board Planning", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.planningState)
}

#Preview("03 Board Trick", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.trickState)
}

#Preview("03a Board Trick iPhone SE", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.trickState)
        .frame(width: 667, height: 375)
}

#Preview("04 Board Assignment", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.assignmentState)
}

#Preview("05 Board Swap", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.swapState)
}

#Preview("06 Board Requisition", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.requisitionState)
}

#Preview("07 Board Game Over", traits: .landscapeLeft) {
    KolkhozPreviewBoardHost(state: KolkhozPreviewFixtures.gameOverState)
}

#Preview("08 Player Panels") {
    VStack(alignment: .leading, spacing: 14) {
        PlayerPanel(
            player: KolkhozPreviewFixtures.playerPanelOpponent,
            plotScore: 18,
            maxTricks: 4,
            active: true,
            human: false
        )
        .frame(width: 104, height: 56)

        PlayerPanel(
            player: KolkhozPreviewFixtures.playerPanelHuman,
            plotScore: 24,
            maxTricks: 4,
            active: false,
            human: true
        )
        .frame(width: 104, height: 56)

        PlayerPanel(
            player: KolkhozPreviewFixtures.playerPanelOpponent,
            plotScore: 18,
            maxTricks: 4,
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
