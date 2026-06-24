import KolkhozCore
import SwiftUI

enum GameBoardLayout {
    static let compactPhoneWidth: CGFloat = 560
    static let phoneLandscapeHeight: CGFloat = 430
    static let compactMargin: CGFloat = 4
    static let regularMargin: CGFloat = 6
    static let minHorizontalGutter: CGFloat = 24
    static let maxHorizontalGutter: CGFloat = 42
    static let horizontalGutterRatio: CGFloat = 0.04
    static let minContentWidth: CGFloat = 280
    static let minContentHeight: CGFloat = 240
    static let compactNavHeight: CGFloat = 54
    static let compactGameMinHeight: CGFloat = 220
    static let minGameWidth: CGFloat = 240
    static let navRailMaxWidth: CGFloat = 58
    static let navRailMinWidth: CGFloat = 48
    static let navRailWidthRatio: CGFloat = 0.07
    static let navRailGap: CGFloat = 18
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
                let compactPhone = proxy.size.width < GameBoardLayout.compactPhoneWidth
                let phoneLandscape = proxy.size.height < GameBoardLayout.phoneLandscapeHeight
                let margin: CGFloat = compactPhone ? GameBoardLayout.compactMargin : GameBoardLayout.regularMargin
                let topInset = compactPhone || phoneLandscape ? 0 : proxy.safeAreaInsets.top
                let bottomInset = compactPhone || phoneLandscape ? 0 : proxy.safeAreaInsets.bottom
                let horizontalGutter = compactPhone || phoneLandscape ? 0 : max(
                    GameBoardLayout.minHorizontalGutter,
                    min(GameBoardLayout.maxHorizontalGutter, proxy.size.width * GameBoardLayout.horizontalGutterRatio)
                )
                let leadingInset = horizontalGutter
                let trailingInset = horizontalGutter
                let contentWidth = max(GameBoardLayout.minContentWidth, proxy.size.width - leadingInset - trailingInset - margin * 2)
                let contentHeight = max(GameBoardLayout.minContentHeight, proxy.size.height - topInset - bottomInset - margin * 2)
                let railWidth = phoneLandscape ? GameBoardLayout.navRailMaxWidth : min(
                    GameBoardLayout.navRailMaxWidth,
                    max(GameBoardLayout.navRailMinWidth, contentWidth * GameBoardLayout.navRailWidthRatio)
                )
                let railGap: CGFloat = compactPhone ? 0 : GameBoardLayout.navRailGap
                let compactNavHeight = GameBoardLayout.compactNavHeight
                let gameWidth = compactPhone ? contentWidth : max(GameBoardLayout.minGameWidth, contentWidth - railWidth - railGap)
                let gameHeight = compactPhone ? max(GameBoardLayout.compactGameMinHeight, contentHeight - compactNavHeight) : contentHeight
                let gameOriginX = leadingInset + margin + (compactPhone ? 0 : railWidth + railGap)
                let gameMaxX = gameOriginX + gameWidth
                let safeMinX = proxy.safeAreaInsets.leading
                let safeMaxX = proxy.size.width - proxy.safeAreaInsets.trailing
                let gameSafeInsets = EdgeInsets(
                    top: 0,
                    leading: max(0, safeMinX - gameOriginX),
                    bottom: 0,
                    trailing: max(0, gameMaxX - safeMaxX)
                )

                Group {
                    if compactPhone {
                        VStack(spacing: 0) {
                            CompactButtonBarView(
                                activePanel: displayPanel,
                                actionPanel: actionPanel,
                                onMenu: onMenu,
                                onSelectPanel: { selectedPanel = $0 }
                            )
                            .frame(width: contentWidth, height: compactNavHeight)
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
                    } else {
                        ZStack(alignment: .topLeading) {
                            LeftButtonBarView(
                                activePanel: displayPanel,
                                actionPanel: actionPanel,
                                width: railWidth,
                                onMenu: onMenu,
                                onSelectPanel: { selectedPanel = $0 }
                            )
                            .zIndex(20)

                            PlayAreaView(
                                displayPanel: displayPanel,
                                gameSafeInsets: gameSafeInsets,
                                onReturnToLobby: onMenu,
                                onNewGame: {
                                    store.newGame()
                                    selectedPanel = nil
                                }
                            )
                            .frame(width: gameWidth, height: contentHeight)
                            .offset(x: railWidth + railGap)
                            .zIndex(0)
                        }
                    }
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .offset(x: leadingInset + margin, y: topInset + margin)
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
