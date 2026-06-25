import KolkhozCore
import SwiftUI

enum PlayerPanelLayout {
    static let compactWidth: CGFloat = 166
    static let compactOuterInset: CGFloat = 5
    static let regularOuterInset: CGFloat = 7
    static let compactPortraitColumnWidth: CGFloat = 34
    static let regularPortraitColumnWidth: CGFloat = 46
    static let portraitColumnWidthRatio: CGFloat = 0.28
    static let portraitColumnHeightRatio: CGFloat = 1.08
    static let compactPortraitSize: CGFloat = 30
    static let regularPortraitSize: CGFloat = 40
    static let minPortraitSize: CGFloat = 24
    static let compactNameHeight: CGFloat = 20
    static let regularNameHeight: CGFloat = 24
    static let nameHeightRatio: CGFloat = 0.51
    static let minPanelHeight: CGFloat = 54
    static let compactColumnBreakpoint: CGFloat = 108
    static let narrowColumnsBreakpoint: CGFloat = 500
    static let tightColumnsBreakpoint: CGFloat = 620
    static let minColumnWidth: CGFloat = 68
    static let playAreaScale: CGFloat = 1.6
    static let compactStatColumnWidth: CGFloat = 44
    static let regularStatColumnWidth: CGFloat = 50
}

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
            let compact = proxy.size.width < PlayerPanelLayout.compactWidth
            let outerInset: CGFloat = compact ? PlayerPanelLayout.compactOuterInset : PlayerPanelLayout.regularOuterInset
            let portraitColumnWidth = min(
                max(compact ? PlayerPanelLayout.compactPortraitColumnWidth : PlayerPanelLayout.regularPortraitColumnWidth, proxy.size.width * PlayerPanelLayout.portraitColumnWidthRatio),
                max(PlayerPanelLayout.compactPortraitColumnWidth, proxy.size.height * PlayerPanelLayout.portraitColumnHeightRatio)
            )
            let portraitSize = min(
                compact ? PlayerPanelLayout.compactPortraitSize : PlayerPanelLayout.regularPortraitSize,
                max(PlayerPanelLayout.minPortraitSize, proxy.size.height - outerInset * 2 - 2)
            )

            ZStack {
                GeneratedChromeImage(resourceName: "ui-player-panel")
                    .allowsHitTesting(false)

                HStack(alignment: .center) {
                    ZStack {
                        PortraitView(player: player, human: human)
                            .frame(width: portraitSize, height: portraitSize)
                    }
                    .frame(width: portraitColumnWidth, height: max(0, proxy.size.height - outerInset * 2), alignment: .center)

                    VStack(alignment: .leading, spacing: compact ? -1 : 1) {
                        HStack(alignment: .center, spacing: compact ? 3 : 5) {
                            PixelText(
                                text: displayName(compact: compact),
                                size: compact ? .caption : .title,
                                variant: compact ? .heavy : .regular,
                                color: active ? Color.kolkhozGold : Color.kolkhozCardInk
                            )
                            .layoutPriority(2)

                            Spacer(minLength: 2)

                            PlayerPlotScoreStat(score: plotScore, compact: compact)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(alignment: .center, spacing: compact ? 3 : 5) {
                            PlayerMedalStat(medals: player.medals, maxTricks: maxTricks, compact: compact)

                            Spacer(minLength: 2)

                            PlayerCellarStat(cardCount: player.plot.hidden.count, compact: compact)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.top, compact ? 2 : 4)
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
        .frame(minHeight: PlayerPanelLayout.minPanelHeight)
    }

    private func displayName(compact: Bool) -> String {
        guard !human else { return language.text(en: "You", ru: "Вы") }
        guard compact else { return player.name }
        let firstName = player.name.split(separator: " ").first.map(String.init) ?? player.name
        return firstName.count > 6 ? "\(firstName.prefix(6))." : firstName
    }
}

private struct PlayerMedalStat: View {
    let medals: Int
    let maxTricks: Int
    let compact: Bool

    var body: some View {
        HStack(spacing: -4) {
            ForEach(0..<maxTricks, id: \.self) { index in
                GameIcon(.medalStar, size: compact ? 12 : 12, muted: index >= medals)
                    .opacity(index < medals ? 1 : 0.18)
            }
        }
        .frame(minWidth: compact ? 28 : 36, alignment: .leading)
        .accessibilityLabel("\(medals) tricks won this year")
    }
}

private struct PlayerCellarStat: View {
    let cardCount: Int
    let compact: Bool

    var body: some View {
        HStack(spacing: 2) {
            GameIcon(.cellar, size: compact ? 16 : 16)
            HStack(spacing: compact ? -6 : -5) {
                ForEach(0..<cardCount, id: \.self) { _ in
                    CardBackThumbnail()
                }
            }
        }
        .frame(width: statColumnWidth, alignment: .leading)
        .accessibilityLabel("\(cardCount) cellar cards")
    }

    private var statColumnWidth: CGFloat {
        compact ? PlayerPanelLayout.compactStatColumnWidth : PlayerPanelLayout.regularStatColumnWidth
    }
}

private struct PlayerPlotScoreStat: View {
    let score: Int
    let compact: Bool

    var body: some View {
        HStack(spacing: 2) {
            GameIcon(.plot, size: compact ? 16 : 16)
            PixelText(text: "\(score)", size: .headline, variant: .heavy, color: .kolkhozSmoke)
        }
        .frame(width: statColumnWidth, alignment: .leading)
        .accessibilityLabel("\(score) visible plot score")
    }

    private var statColumnWidth: CGFloat {
        compact ? PlayerPanelLayout.compactStatColumnWidth : PlayerPanelLayout.regularStatColumnWidth
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
            let spacing: CGFloat = proxy.size.width < PlayerPanelLayout.tightColumnsBreakpoint ? 6 : 8
            let compactCards = proxy.size.width < PlayerPanelLayout.narrowColumnsBreakpoint
            let preferredCardWidth = compactCards ? CardSize.medium.width : CardSize.large.width
            let preferredColumnWidth = preferredCardWidth * 1.6 + (compactCards ? 4 : 8)
            let maxColumnWidth = (proxy.size.width - spacing * CGFloat(playerOrder.count - 1)) / CGFloat(playerOrder.count)
            let columnWidth = max(PlayerPanelLayout.minColumnWidth, min(preferredColumnWidth, maxColumnWidth))
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
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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

    var compact: Bool { columnWidth < PlayerPanelLayout.compactColumnBreakpoint }
    var cardSize: CardSize { compact ? .medium : .large }
    var slotWidth: CGFloat { min(compact ? 58 : 76, max(44, columnWidth * 0.52)) }
    var playAreaScale: CGFloat { PlayerPanelLayout.playAreaScale }
    var playAreaTopOffset: CGFloat { compact ? 1 : 14 }
    var playerPanelWidth: CGFloat { cardSize.width * playAreaScale }
    var playAreaWidth: CGFloat { max(cardSize.width, slotWidth) * playAreaScale }
    var playAreaHeight: CGFloat { max(cardSize.height, slotWidth * 1.42) * playAreaScale }

    var body: some View {
        VStack(spacing: compact ? -6 : -2) {
            PlayerPanel(
                player: player,
                plotScore: store.visibleScore(for: playerID),
                maxTricks: store.state.isFamine ? 3 : 4,
                active: isCurrentTurn,
                human: playerID == 0
            )
            .frame(width: playerPanelWidth, height: compact ? 40 : 40)
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
                    CardSlot(active: isCurrentTurn, human: playerID == 0, width: slotWidth, height: slotWidth * 1.55)
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
