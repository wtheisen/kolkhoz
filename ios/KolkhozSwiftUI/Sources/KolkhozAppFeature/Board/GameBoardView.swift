import KolkhozCore
import SwiftUI

struct GameBoardView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @Environment(\.kolkhozAppearance) private var appearance
    let onMenu: () -> Void
    let onTutorial: () -> Void
    let tutorialAction: TutorialRequiredAction
    let onTutorialAction: (TutorialRequiredAction) -> Void
    @State private var selectedPanel: GamePanel?

    init(
        initialPanel: GamePanel? = nil,
        onMenu: @escaping () -> Void,
        onTutorial: @escaping () -> Void = {},
        tutorialAction: TutorialRequiredAction = .none,
        onTutorialAction: @escaping (TutorialRequiredAction) -> Void = { _ in }
    ) {
        self.onMenu = onMenu
        self.onTutorial = onTutorial
        self.tutorialAction = tutorialAction
        self.onTutorialAction = onTutorialAction
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

    private var tutorialPanelTarget: GamePanel? {
        guard case .tapPanel(let panel) = tutorialAction else { return nil }
        return panel
    }

    private var hasPendingBoardAnimations: Bool {
        store.animationEvents.contains { event in
            if case .cardPlayed(_, let playerID, _) = event {
                return store.state.players.indices.contains(playerID) && !store.state.players[playerID].isHuman
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
                let railSeparatorWidth: CGFloat = 4
                let gameWidth = max(240, contentWidth - railWidth - railSeparatorWidth)
                let gameHeight = max(220, contentHeight)
                let gameOriginX = margin + railWidth + railSeparatorWidth
                let gameMaxX = gameOriginX + gameWidth
                let safeMinX = proxy.safeAreaInsets.leading
                let safeMaxX = proxy.size.width - proxy.safeAreaInsets.trailing
                let gameSafeInsets = EdgeInsets(
                    top: 0,
                    leading: max(0, safeMinX - gameOriginX),
                    bottom: 0,
                    trailing: max(0, gameMaxX - safeMaxX)
                )
                let fullHeight = proxy.size.height + proxy.safeAreaInsets.bottom
                let leftGutterWidth = proxy.safeAreaInsets.leading
                let rightGutterX = proxy.size.width - proxy.safeAreaInsets.trailing
                let rightGutterWidth = proxy.safeAreaInsets.trailing * 2

                ZStack(alignment: .topLeading) {
                    BoardGutterInfillView(appearance: appearance, side: .left)
                        .frame(width: leftGutterWidth, height: fullHeight)
                        .offset(x: -leftGutterWidth)

                    BoardGutterInfillView(appearance: appearance, side: .right)
                        .frame(width: rightGutterWidth, height: fullHeight)
                        .offset(x: rightGutterX)

                    HStack(spacing: 0) {
                        PanelSelectorRailView(
                            activePanel: displayPanel,
                            actionPanel: actionPanel,
                            tutorialTargetPanel: tutorialPanelTarget,
                            onSelectPanel: {
                                selectedPanel = $0
                                onTutorialAction(.tapPanel($0))
                            }
                        )
                        .frame(width: railWidth, height: contentHeight)

                        BoardGoldSeparatorView(orientation: .vertical)
                            .frame(width: railSeparatorWidth, height: contentHeight)
                            .allowsHitTesting(false)

                        PlayAreaView(
                            displayPanel: displayPanel,
                            gameSafeInsets: gameSafeInsets,
                            onReturnToLobby: onMenu,
                            onTutorial: onTutorial,
                            tutorialAction: tutorialAction,
                            onTutorialAction: onTutorialAction,
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

            if store.isHotSeatPrivacyRequired {
                HotSeatPrivacyOverlay(
                    player: store.state.players[store.localPlayerID],
                    phase: store.state.phase,
                    year: store.state.year,
                    onReady: store.revealLocalPlayer
                )
                .zIndex(100)
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
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
        .animation(.easeInOut(duration: 0.18), value: store.isHotSeatPrivacyRequired)
    }
}

private struct HotSeatPrivacyOverlay: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let phase: GamePhase
    let year: Int
    let onReady: () -> Void

    var body: some View {
        ZStack {
            Color.kolkhozBlack.opacity(0.96)
                .ignoresSafeArea()

            GeometryReader { proxy in
                let width = min(max(proxy.size.width * 0.58, 300), 470)
                let portraitSize = kolkhozClamp(proxy.size.height * 0.20, 58, 86)

                VStack(spacing: 14) {
                    PanelTitleRow(
                        title: language.text(en: "Pass Device", ru: "Передайте устройство"),
                        subtitle: language.text(en: "Seat \(player.id + 1) is up.", ru: "Ходит место \(player.id + 1)."),
                        icon: .passDevice
                    )
                    .frame(height: 62)

                    ResourceArtImage(resourceName: "art-pass-device-placard")
                        .scaledToFit()
                        .frame(maxWidth: 310, maxHeight: 78)
                        .opacity(0.92)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    PortraitView(player: player, human: true)
                        .frame(width: portraitSize, height: portraitSize)
                        .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                    VStack(spacing: 4) {
                        PixelText(
                            text: player.name.uppercased(),
                            size: .title,
                            variant: .heavy,
                            color: .kolkhozGold
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.64)

                        Text(phaseLine)
                            .font(.kolkhozLabel(.caption))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.kolkhozCreamDim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                    }

                    Button(action: onReady) {
                        Text(language.text(en: "Ready", ru: "Готов"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CommandButtonStyle(prominent: true))
                    .frame(maxWidth: 210)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
                .frame(width: width)
                .panelStyle()
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            }
        }
    }

    private var phaseLine: String {
        language.text(
            en: "Year \(year) - \(language.phaseName(phase))",
            ru: "Год \(year) - \(language.phaseName(phase))"
        )
    }
}

private enum BoardGutterInfillSide {
    case left
    case right
}

private struct BoardGutterInfillView: View {
    let appearance: KolkhozAppearance
    let side: BoardGutterInfillSide

    var body: some View {
        ResourceArtImage(resourceName: resourceName)
            .scaledToFill()
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .ignoresSafeArea()
    }

    private var resourceName: String {
        switch (side, appearance) {
        case (.left, .dark):
            "iphone17promax-left-gutter-infill-dark"
        case (.left, .light):
            "iphone17promax-left-gutter-infill-light"
        case (.right, .dark):
            "iphone17promax-right-gutter-infill-dark"
        case (.right, .light):
            "iphone17promax-right-gutter-infill-light"
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

#Preview("Game Board - North", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState) {
        GameBoardView(initialPanel: .north, onMenu: {})
    }
}

#Preview("Game Board - Plot", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState) {
        GameBoardView(initialPanel: .plot, onMenu: {})
    }
}

#Preview("Game Board - SE Brigade", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 667, height: 375) {
        GameBoardView(onMenu: {})
    }
}

#Preview("Game Board - SE Jobs", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 667, height: 375) {
        GameBoardView(onMenu: {})
    }
}

#Preview("Game Board - SE North", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 667, height: 375) {
        GameBoardView(initialPanel: .north, onMenu: {})
    }
}

#Preview("Game Board - SE Plot", traits: .landscapeLeft) {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 667, height: 375) {
        GameBoardView(initialPanel: .plot, onMenu: {})
    }
}
#endif
