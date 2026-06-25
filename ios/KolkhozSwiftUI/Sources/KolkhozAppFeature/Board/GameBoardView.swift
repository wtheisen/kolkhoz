import KolkhozCore
import SwiftUI

enum GameBoardLayout {
    static let minMargin: CGFloat = 4
    static let maxMargin: CGFloat = 8
    static let marginRatio: CGFloat = 0.01
    static let minHorizontalGutter: CGFloat = 0
    static let maxHorizontalGutter: CGFloat = 24
    static let horizontalGutterRatio: CGFloat = 0.025
    static let minContentWidth: CGFloat = 280
    static let minContentHeight: CGFloat = 240
    static let minNavHeight: CGFloat = 50
    static let maxNavHeight: CGFloat = 58
    static let navHeightRatio: CGFloat = 0.13
    static let minGameHeight: CGFloat = 220
    static let minGameWidth: CGFloat = 240
}

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
                let margin = max(
                    GameBoardLayout.minMargin,
                    min(GameBoardLayout.maxMargin, shorterSide * GameBoardLayout.marginRatio)
                )
                let horizontalGutter = max(
                    GameBoardLayout.minHorizontalGutter,
                    min(GameBoardLayout.maxHorizontalGutter, proxy.size.width * GameBoardLayout.horizontalGutterRatio)
                )
                let leadingInset = horizontalGutter
                let trailingInset = horizontalGutter
                let contentWidth = max(GameBoardLayout.minContentWidth, proxy.size.width - leadingInset - trailingInset - margin * 2)
                let contentHeight = max(GameBoardLayout.minContentHeight, proxy.size.height - margin * 2)
                let navHeight = max(
                    GameBoardLayout.minNavHeight,
                    min(GameBoardLayout.maxNavHeight, contentHeight * GameBoardLayout.navHeightRatio)
                )
                let gameWidth = max(GameBoardLayout.minGameWidth, contentWidth)
                let gameHeight = max(GameBoardLayout.minGameHeight, contentHeight - navHeight)
                let gameOriginX = leadingInset + margin
                let gameMaxX = gameOriginX + gameWidth
                let safeMinX = proxy.safeAreaInsets.leading
                let safeMaxX = proxy.size.width - proxy.safeAreaInsets.trailing
                let gameSafeInsets = EdgeInsets(
                    top: 0,
                    leading: max(0, safeMinX - gameOriginX),
                    bottom: 0,
                    trailing: max(0, gameMaxX - safeMaxX)
                )

                VStack(spacing: 0) {
                    TopButtonBarView(
                        activePanel: displayPanel,
                        actionPanel: actionPanel,
                        onMenu: onMenu,
                        onSelectPanel: { selectedPanel = $0 }
                    )
                    .frame(width: contentWidth, height: navHeight)

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
                .offset(x: leadingInset + margin, y: margin)
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
