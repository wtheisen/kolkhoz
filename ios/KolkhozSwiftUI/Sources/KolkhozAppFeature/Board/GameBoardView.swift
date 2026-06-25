import KolkhozCore
import SwiftUI

struct GameBoardView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    let onMenu: () -> Void
    @State private var selectedPanel: GamePanel?

    init(initialPanel: GamePanel? = nil, onMenu: @escaping () -> Void) {
        self.onMenu = onMenu
        _selectedPanel = State(initialValue: initialPanel)
    }

    private var actionPanel: GamePanel {
        if hasPendingBoardAnimations {
            return .brigade
        }
        switch store.state.phase {
        case .assignment:
            return .jobs
        case .requisition:
            return .plot
        case .swap:
            return .plot
        default:
            return .brigade
        }
    }

    private var displayPanel: GamePanel {
        selectedPanel ?? actionPanel
    }

    private var hasPendingBoardAnimations: Bool {
        store.animationEvents.contains { event in
            if case .cardPlayed(_, let playerID, _) = event {
                return playerID != 0
            }
            if case .workAssigned = event {
                return true
            }
            return false
        }
    }

    var body: some View {
        ZStack {
            Color.kolkhozTable
                .ignoresSafeArea()
            RadialGradient(
                colors: [.kolkhozGold.opacity(0.16), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 430
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let shorterSide = min(proxy.size.width, proxy.size.height)
                let margin = kolkhozClamp(shorterSide * 0.01, 4, 8)
                let contentWidth = max(280, proxy.size.width - margin * 2)
                let contentHeight = max(240, proxy.size.height - margin * 2)
                let railWidth = kolkhozClamp(contentWidth * 0.07, 60, 72)
                let gameWidth = max(240, contentWidth - railWidth)
                let gameHeight = max(220, contentHeight)
                let gameOriginX = margin + railWidth
                let gameMaxX = gameOriginX + gameWidth
                let safeMinX = proxy.safeAreaInsets.leading
                let safeMaxX = proxy.size.width - proxy.safeAreaInsets.trailing
                let gameSafeInsets = EdgeInsets(
                    top: 0,
                    leading: max(0, safeMinX - gameOriginX),
                    bottom: 0,
                    trailing: max(0, gameMaxX - safeMaxX)
                )

                HStack(spacing: 0) {
                    PanelSelectorRailView(
                        activePanel: displayPanel,
                        actionPanel: actionPanel,
                        onSelectPanel: { selectedPanel = $0 }
                    )
                    .frame(width: railWidth, height: contentHeight)

                    PlayAreaView(
                        displayPanel: displayPanel,
                        gameSafeInsets: gameSafeInsets,
                        onReturnToLobby: onMenu,
                        onNewGame: {
                            store.newGame()
                            selectedPanel = nil
                        }
                    )
                    .frame(width: gameWidth, height: gameHeight)
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .offset(x: margin, y: margin)
                .clipped()
            }
        }
        .alert(language.text(en: "Move unavailable", ru: "Ход недоступен"), isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button(language.text(en: "OK", ru: "ОК"), role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
        .onChange(of: store.state.phase) { _, _ in
            selectedPanel = nil
        }
    }
}

#if DEBUG
#Preview("Game Board - Brigade", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState) {
        GameBoardView(onMenu: {})
    }
}

#Preview("Game Board - Jobs", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState) {
        GameBoardView(onMenu: {})
    }
}
#endif
