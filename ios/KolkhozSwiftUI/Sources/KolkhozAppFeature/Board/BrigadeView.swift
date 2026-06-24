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
    static let compactThumbnails = 3
    static let regularThumbnails = 4
    static let minPanelHeight: CGFloat = 54
    static let compactColumnBreakpoint: CGFloat = 108
    static let narrowColumnsBreakpoint: CGFloat = 500
    static let tightColumnsBreakpoint: CGFloat = 620
    static let minColumnWidth: CGFloat = 68
    static let playAreaScale: CGFloat = 1.6
}

struct PlayerPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let score: Int
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
            let nameHeight = max(compact ? PlayerPanelLayout.compactNameHeight : PlayerPanelLayout.regularNameHeight, proxy.size.height * PlayerPanelLayout.nameHeightRatio)
            let thumbnailCount = min(player.hand.count, compact ? PlayerPanelLayout.compactThumbnails : PlayerPanelLayout.regularThumbnails)

            ZStack {
                GeneratedChromeImage(resourceName: "ui-player-panel")
                    .allowsHitTesting(false)

                HStack(alignment: .top, spacing: compact ? 4 : 7) {
                    ZStack {
                        PortraitView(player: player, human: human)
                            .frame(width: portraitSize, height: portraitSize)
                    }
                    .frame(width: portraitColumnWidth, height: max(0, proxy.size.height - outerInset * 2), alignment: .center)

                    VStack(alignment: .leading, spacing: compact ? 1 : 2) {
                        HStack(spacing: compact ? 3 : 4) {
                            PixelText(
                                text: displayName(compact: compact),
                                size: compact ? .caption : .caption,
                                variant: compact ? .heavy : .regular,
                                color: active ? Color.kolkhozGold : Color.kolkhozCardInk
                            )
                                .layoutPriority(2)
                            if player.brigadeLeader {
                                GameIcon(.medalStar, size: compact ? 15 : 20)
                            }
                        }
                        .frame(height: nameHeight, alignment: .leading)

                        HStack(spacing: compact ? 4 : 6) {
                            PixelText(text: compact ? "\(score)" : language.text(en: "\(score) points", ru: "\(score) очк"), size: .caption, color: .kolkhozSmoke)

                            Spacer(minLength: 2)

                            if thumbnailCount > 0 {
                                HStack(spacing: -3) {
                                    ForEach(0..<thumbnailCount, id: \.self) { _ in
                                        CardBackThumbnail()
                                    }
                                }
                            }

                            if player.medals > 0 {
                                HStack(spacing: 2) {
                                    GameIcon(.medalStar, size: compact ? 9 : 10)
                                    PixelText(text: "\(player.medals)", size: .caption2, variant: .heavy, color: .kolkhozGold)
                                }
                            } else if !compact {
                                HStack(spacing: 2) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        GameIcon(.medalStar, size: 9, muted: true)
                                            .opacity(0.18)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                    }
                    .layoutPriority(1)
                }
                .padding(.horizontal, outerInset)
                .padding(.vertical, outerInset)
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
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = active }
        .onChange(of: active) { _, active in
            pulse = active
        }
    }

    private func displayName(compact: Bool) -> String {
        guard !human else { return language.text(en: "You", ru: "Вы") }
        guard compact else { return player.name }
        let firstName = player.name.split(separator: " ").first.map(String.init) ?? player.name
        return firstName.count > 6 ? "\(firstName.prefix(6))." : firstName
    }
}

struct BrigadeView: View {
    @EnvironmentObject var store: GameStore
    @Binding var humanPlayTarget: CGPoint?
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
                        humanPlayTarget: $humanPlayTarget,
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
    @Binding var humanPlayTarget: CGPoint?
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
    var playAreaTopOffset: CGFloat { compact ? 10 : 14 }
    var playerPanelWidth: CGFloat { cardSize.width * playAreaScale }
    var playAreaWidth: CGFloat { max(cardSize.width, slotWidth) * playAreaScale }
    var playAreaHeight: CGFloat { max(cardSize.height, slotWidth * 1.42) * playAreaScale }

    var body: some View {
        VStack(spacing: compact ? 1 : -6) {
            PlayerPanel(
                player: player,
                score: store.visibleScore(for: playerID),
                active: isCurrentTurn,
                human: playerID == 0
            )
            .frame(width: playerPanelWidth, height: compact ? 50 : 58)
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
        if playerID == 0 {
            humanPlayTarget = center
        }
    }
}

#if DEBUG
#Preview("Player Panel") {
    BoardPreviewStage {
        VStack(alignment: .leading, spacing: 14) {
            PlayerPanel(
                player: KolkhozPreviewFixtures.playerPanelOpponent,
                score: 18,
                active: true,
                human: false
            )
            .frame(width: 96, height: 54)

            PlayerPanel(
                player: KolkhozPreviewFixtures.playerPanelHuman,
                score: 24,
                active: false,
                human: true
            )
            .frame(width: 96, height: 54)

            PlayerPanel(
                player: KolkhozPreviewFixtures.playerPanelOpponent,
                score: 18,
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
    @State private var humanPlayTarget: CGPoint?
    @State private var playSlotCenters: [Int: CGPoint] = [:]
    @State private var playSlotFrames: [Int: CGRect] = [:]
    @State private var playerPanelCenters: [Int: CGPoint] = [:]

    var body: some View {
        BrigadeView(
            humanPlayTarget: $humanPlayTarget,
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
