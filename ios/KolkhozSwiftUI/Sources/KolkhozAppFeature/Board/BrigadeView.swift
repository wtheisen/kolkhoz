import KolkhozCore
import SwiftUI

struct PlayerPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let plotScore: Int
    let maxTricks: Int
    let active: Bool
    let human: Bool
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let outerInset = kolkhozClamp(proxy.size.width * 0.04, 5, 7)
            let portraitColumnWidth = min(
                max(34, proxy.size.width * 0.28),
                max(34, proxy.size.height * 1.08)
            )
            let portraitSize = kolkhozClamp(
                max(24, proxy.size.height - outerInset * 2 - 2)
                ,
                24,
                40
            )
            let rowSpacing = kolkhozClamp(proxy.size.width * 0.025, 3, 5)
            let stackSpacing = kolkhozClamp(proxy.size.width * 0.01, -1, 1)
            let statColumnWidth = kolkhozClamp(proxy.size.width * 0.22, 44, 50)
            let topPadding = kolkhozClamp(proxy.size.height * 0.07, 2, 4)

            ZStack {
                GeneratedChromeImage(resourceName: "ui-player-panel")
                    .allowsHitTesting(false)

                HStack(alignment: .center) {
                    ZStack {
                        PortraitView(player: player, human: human)
                            .frame(width: portraitSize, height: portraitSize)
                    }
                    .frame(width: portraitColumnWidth, height: max(0, proxy.size.height - outerInset * 2), alignment: .center)

                    VStack(alignment: .leading, spacing: stackSpacing) {
                        HStack(alignment: .center, spacing: rowSpacing) {
                            PixelText(
                                text: displayName,
                                size: .caption,
                                variant: .heavy,
                                color: active ? Color.kolkhozGold : Color.kolkhozCardInk
                            )
                            .layoutPriority(2)

                            Spacer(minLength: 2)

                            PlayerPlotScoreStat(score: plotScore, statColumnWidth: statColumnWidth)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .center, spacing: rowSpacing) {
                            PlayerMedalStat(medals: player.medals, maxTricks: maxTricks, statColumnWidth: statColumnWidth)

                            Spacer(minLength: 2)

                            PlayerCellarStat(cardCount: player.plot.hidden.count, statColumnWidth: statColumnWidth, cardSpacing: -kolkhozClamp(proxy.size.width * 0.03, 5, 6))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, topPadding)
                    .offset(x: -4)
                    .layoutPriority(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5)
            }
            .overlay {
                if active || human {
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(active ? Color.kolkhozGold.opacity(0.78) : Color.kolkhozRedDark.opacity(0.42), lineWidth: active ? 1.3 : 1)
                        .padding(2)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(active && pulse ? 1.018 : 1)
            .shadow(color: active ? Color.kolkhozGold.opacity(pulse ? 0.42 : 0.18) : .black.opacity(0.24), radius: active && pulse ? 12 : 4, y: 3)
        }
        .frame(minHeight: 54)
    }

    private var displayName: String {
        guard !human else { return language.text(en: "You", ru: "Вы") }
        let firstName = player.name.split(separator: " ").first.map(String.init) ?? player.name
        return firstName.count > 6 ? "\(firstName.prefix(6))." : firstName
    }
}

private struct PlayerMedalStat: View {
    let medals: Int
    let maxTricks: Int
    let statColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: -4) {
            ForEach(0..<maxTricks, id: \.self) { index in
                GameIcon(.medalStar, size: 12, muted: index >= medals)
                    .opacity(index < medals ? 1 : 0.18)
            }
        }
        .frame(minWidth: statColumnWidth * 0.72, alignment: .leading)
        .accessibilityLabel("\(medals) tricks won this year")
    }
}

private struct PlayerCellarStat: View {
    let cardCount: Int
    let statColumnWidth: CGFloat
    let cardSpacing: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            GameIcon(.cellar, size: 16)
            HStack(spacing: cardSpacing) {
                ForEach(0..<cardCount, id: \.self) { _ in
                    CardBackThumbnail()
                }
            }
        }
        .frame(width: statColumnWidth, alignment: .leading)
        .accessibilityLabel("\(cardCount) cellar cards")
    }
}

private struct PlayerPlotScoreStat: View {
    let score: Int
    let statColumnWidth: CGFloat

    var body: some View {
        HStack(spacing: 2) {
            GameIcon(.plot, size: 16)
            PixelText(text: "\(score)", size: .headline, variant: .heavy, color: .kolkhozSmoke)
        }
        .frame(width: statColumnWidth, alignment: .leading)
        .accessibilityLabel("\(score) visible plot score")
    }
}

struct BrigadeView: View {
    @EnvironmentObject var store: GameStore
    @Binding var playSlotCenters: [Int: CGPoint]
    @Binding var playSlotFrames: [Int: CGRect]
    @Binding var playerPanelCenters: [Int: CGPoint]
    let hiddenPlayIDs: Set<String>
    let showLastTrick: Bool

    var displayedTrick: [TrickPlay] {
        store.state.phase == .assignment || showLastTrick ? store.state.lastTrick : store.state.currentTrick
    }

    var playerOrder: [Int] { [1, 2, 3, 0] }

    var body: some View {
        GeometryReader { proxy in
            let spacing = kolkhozClamp(proxy.size.width * 0.012, 28, 48)
            let preferredColumnWidth = kolkhozClamp(proxy.size.width * 0.18, 96, 120)
            let maxColumnWidth = (proxy.size.width - spacing * CGFloat(playerOrder.count - 1)) / CGFloat(playerOrder.count)
            let playerPanelWidth = CardSize.medium.width * 1.6
            let columnWidth = max(playerPanelWidth, min(preferredColumnWidth, maxColumnWidth))
            let rowWidth = columnWidth * CGFloat(playerOrder.count) + spacing * CGFloat(playerOrder.count - 1)
            HStack(alignment: .top, spacing: spacing) {
                ForEach(playerOrder, id: \.self) { playerID in
                    BrigadePlayerColumnView(
                        playerID: playerID,
                        play: displayedTrick.first { $0.playerID == playerID },
                        columnWidth: columnWidth,
                        playSlotCenters: $playSlotCenters,
                        playSlotFrames: $playSlotFrames,
                        playerPanelCenters: $playerPanelCenters,
                        hiddenPlayIDs: hiddenPlayIDs
                    )
                    .frame(width: columnWidth)
                }
            }
            .frame(width: rowWidth, height: proxy.size.height, alignment: .top)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct BrigadePlayerColumnView: View {
    @EnvironmentObject var store: GameStore
    let playerID: Int
    let play: TrickPlay?
    let columnWidth: CGFloat
    @Binding var playSlotCenters: [Int: CGPoint]
    @Binding var playSlotFrames: [Int: CGRect]
    @Binding var playerPanelCenters: [Int: CGPoint]
    let hiddenPlayIDs: Set<String>

    var player: PlayerState { store.state.players[playerID] }
    var isCurrentTurn: Bool {
        store.state.phase == .trick && store.state.currentPlayer == playerID && play == nil
    }

    var cardSize: CardSize { .medium }
    var slotWidth: CGFloat { kolkhozClamp(columnWidth * 0.52, 44, 76) }
    var playAreaScale: CGFloat { 1.6 }
    var playAreaLeftOffset: CGFloat { kolkhozClamp(columnWidth * 0.06, 37, 54) }
    var playAreaTopOffset: CGFloat { kolkhozClamp(columnWidth * 0.15, 12, 24) }
    var playerPanelWidth: CGFloat { cardSize.width * playAreaScale }
    var playerPanelHeight: CGFloat { 40 }
    var playAreaWidth: CGFloat { max(cardSize.width, slotWidth) * playAreaScale }
    var playAreaHeight: CGFloat { max(cardSize.height, slotWidth * 1.2) * playAreaScale }

    var body: some View {
        VStack(spacing: -kolkhozClamp(columnWidth * 0.055, 2, 6)) {
            PlayerPanel(
                player: player,
                plotScore: store.visibleScore(for: playerID),
                maxTricks: store.state.isFamine ? 3 : 4,
                active: isCurrentTurn,
                human: playerID == 0
            )
            .frame(width: playerPanelWidth, height: playerPanelHeight)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            let frame = proxy.frame(in: .named(GameBoardCoordinateSpace.main))
                            playerPanelCenters[playerID] = CGPoint(x: frame.midX, y: frame.midY)
                        }
                        .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, frame in
                            playerPanelCenters[playerID] = CGPoint(x: frame.midX, y: frame.midY)
                        }
                }
            }

            ZStack(alignment: .top) {
                if let play, !hiddenPlayIDs.contains(play.id) {
                    CardView(card: play.card, size: cardSize)
                        .scaleEffect(playAreaScale, anchor: .top)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    CardSlot(active: isCurrentTurn, human: playerID == 0, width: slotWidth, height: slotWidth * 1.4)
                        .scaleEffect(playAreaScale, anchor: .top)
                }
            }
            .frame(width: playAreaWidth, height: playAreaHeight, alignment: .top)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            updatePlayTarget(from: proxy)
                        }
                        .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, _ in
                            updatePlayTarget(from: proxy)
                    }
                }
            }
            .padding(.leading, playAreaLeftOffset)
            .padding(.top, playAreaTopOffset)
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.36, dampingFraction: 0.72), value: play?.card.id)
        }
        .frame(width: columnWidth)
        .frame(maxHeight: .infinity)
    }

    private func updatePlayTarget(from proxy: GeometryProxy) {
        let frame = proxy.frame(in: .named(GameBoardCoordinateSpace.main))
        let center = CGPoint(x: frame.midX, y: frame.midY)
        playSlotCenters[playerID] = center
        playSlotFrames[playerID] = frame
    }
}

#if DEBUG
#Preview("Player Panel") {
    BoardPreviewStage {
        VStack(alignment: .leading, spacing: 14) {
            PlayerPanel(
                player: KolkhozPreviewFixtures.playerPanelOpponent,
                plotScore: 18,
                maxTricks: 4,
                active: true,
                human: false
            )
            .frame(width: 96, height: 54)

            PlayerPanel(
                player: KolkhozPreviewFixtures.playerPanelHuman,
                plotScore: 24,
                maxTricks: 4,
                active: false,
                human: true
            )
            .frame(width: 96, height: 54)

            PlayerPanel(
                player: KolkhozPreviewFixtures.playerPanelOpponent,
                plotScore: 18,
                maxTricks: 4,
                active: true,
                human: false
            )
            .frame(width: 260, height: 62)
        }
    }
}

#Preview("Player Columns") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 620, height: 260) {
        BrigadePreviewHost()
    }
}

private struct BrigadePreviewHost: View {
    @State private var playSlotCenters: [Int: CGPoint] = [:]
    @State private var playSlotFrames: [Int: CGRect] = [:]
    @State private var playerPanelCenters: [Int: CGPoint] = [:]

    var body: some View {
        BrigadeView(
            playSlotCenters: $playSlotCenters,
            playSlotFrames: $playSlotFrames,
            playerPanelCenters: $playerPanelCenters,
            hiddenPlayIDs: [],
            showLastTrick: false
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
