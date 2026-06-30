import KolkhozCore
import SwiftUI

struct PlotViewMetrics {
    let opponentHeight: CGFloat
    let spacing: CGFloat
    let padding: CGFloat
    let columnCardSpacing: CGFloat
    let columnTrailingPadding: CGFloat
    let opponentCardScale: CGFloat
    let opponentCardFrameWidth: CGFloat
    let opponentCardFrameHeight: CGFloat
    let opponentVisibleCardCount: Int
    let portraitSize: CGFloat
    let panelPadding: CGFloat
    let headerIconSize: CGFloat
    let emptyCardSize: CardSize
    let playerCardSize: CardSize
    let playerCardScale: CGFloat

    init(size: CGSize) {
        let shorterSide = min(size.width, size.height)
        opponentHeight = kolkhozClamp(size.height * 0.18, 70, 82)
        spacing = kolkhozClamp(shorterSide * 0.02, 7, 10)
        padding = kolkhozClamp(shorterSide * 0.025, 8, 12)
        columnCardSpacing = kolkhozClamp(-size.width * 0.04, -30, -24)
        columnTrailingPadding = kolkhozClamp(size.width * 0.035, 20, 28)
        opponentCardScale = kolkhozClamp(size.width * 0.001, 0.68, 0.76)
        opponentCardFrameWidth = kolkhozClamp(size.width * 0.04, 25, 29)
        opponentCardFrameHeight = kolkhozClamp(size.height * 0.10, 38, 44)
        opponentVisibleCardCount = Int(kolkhozClamp(size.width / 190, 3, 4))
        portraitSize = kolkhozClamp(size.width * 0.055, 34, 42)
        panelPadding = kolkhozClamp(shorterSide * 0.018, 7, 8)
        headerIconSize = kolkhozClamp(size.width * 0.026, 17, 20)
        emptyCardSize = .small
        playerCardSize = .small
        playerCardScale = 1.0
    }
}

struct PlotStorageView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    let selectedPlot: Binding<PlotSelection?>?
    var hiddenExiledPlotCards: Set<Card> = []

    private var isInteractive: Bool {
        selectedPlot != nil
    }

    private var isRequisition: Bool {
        store.state.phase == .requisition
    }

    private var exiledCards: Set<Card> {
        isRequisition ? Set(store.state.exiled[store.state.year, default: []]) : []
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = PlotViewMetrics(size: proxy.size)
            let localPlayerID = store.localPlayerID
            let localPlayer = store.state.players[localPlayerID]

            VStack(alignment: .leading, spacing: metrics.spacing) {
                plotHeader()
                    .frame(height: isRequisition ? 58 : 54)

                HStack(spacing: metrics.spacing) {
                    ForEach(store.state.players.filter { $0.id != localPlayerID }) { player in
                        PlayerPlotPanel(
                            player: player,
                            score: visibleScore(for: player),
                            metrics: metrics,
                            exiledCards: exiledCards,
                            hiddenExiledPlotCards: hiddenExiledPlotCards
                        )
                    }
                }
                .frame(height: metrics.opponentHeight)

                HStack(alignment: .top, spacing: metrics.spacing) {
                    PlotColumn(
                        title: language.text(en: "Cellar", ru: "Подвал"),
                        icon: .cellar,
                        subtitle: "\(visibleHiddenCards(for: localPlayer).count)",
                        cards: visibleHiddenCards(for: localPlayer),
                        hidden: false,
                        metrics: metrics,
                        exiledCards: exiledCards,
                        isSelected: { selectedPlot?.wrappedValue == PlotSelection(card: $0, zone: .hidden) },
                        onSelect: isInteractive ? { card in
                            selectedPlot?.wrappedValue = PlotSelection(card: card, zone: .hidden)
                        } : nil
                    )
                    PlotColumn(
                        title: language.text(en: "Plot", ru: "Участок"),
                        icon: .plot,
                        subtitle: "\(visibleRevealedCards(for: localPlayer).count)",
                        cards: visibleRevealedCards(for: localPlayer),
                        hidden: false,
                        metrics: metrics,
                        exiledCards: exiledCards,
                        isSelected: { selectedPlot?.wrappedValue == PlotSelection(card: $0, zone: .revealed) },
                        onSelect: isInteractive ? { card in
                            selectedPlot?.wrappedValue = PlotSelection(card: card, zone: .revealed)
                        } : nil
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(metrics.padding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(CommandPanelBackground())
        }
    }

    @ViewBuilder
    private func plotHeader() -> some View {
        if isRequisition {
            PanelTitleRow(
                title: language.text(en: "Requisition", ru: "Реквизиция"),
                subtitle: requisitionSubtitle,
                icon: .requisitionNorth,
                urgent: true
            )
        } else {
            PanelTitleRow(
                title: language.text(en: "Private plot", ru: "Личный участок"),
                subtitle: language.text(en: "Other stores above, active player's cellar below.", ru: "Участки других сверху, подвал активного игрока снизу."),
                icon: .plot
            )
        }
    }

    private var requisitionSubtitle: String {
        let activeExile = activeCardExileAnimation
        if let event = activeRequisitionEvent(for: activeExile) {
            return language.requisitionMessage(for: event, players: store.state.players)
        }
        if store.state.requisitionEvents.isEmpty {
            return language.text(en: "All jobs complete.", ru: "Все работы выполнены.")
        }
        if activeExile != nil {
            return language.text(en: "Resolving requisition...", ru: "Идёт реквизиция...")
        }
        return language.text(en: "Audit complete.", ru: "Проверка завершена.")
    }

    private var activeCardExileAnimation: KolkhozAnimationEvent? {
        store.animationEvents.first { event in
            if case .cardExiled = event {
                return true
            }
            return false
        }
    }

    private func activeRequisitionEvent(for animation: KolkhozAnimationEvent?) -> RequisitionEvent? {
        guard case .cardExiled(_, let playerID, let suit, let card) = animation else {
            return nil
        }
        return store.state.requisitionEvents.first {
            $0.playerID == playerID && $0.suit == suit && $0.card == card
        }
    }

    private func visibleHiddenCards(for player: PlayerState) -> [Card] {
        player.plot.hidden.filter { !hiddenExiledPlotCards.contains($0) }
    }

    private func visibleRevealedCards(for player: PlayerState) -> [Card] {
        player.plot.revealed.filter { !hiddenExiledPlotCards.contains($0) }
    }

    private func visibleScore(for player: PlayerState) -> Int {
        let hiddenValue = player.plot.revealed
            .filter { hiddenExiledPlotCards.contains($0) }
            .reduce(0) { $0 + $1.value }
        return store.visibleScore(for: player.id) - hiddenValue
    }
}

struct PlayerPlotPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let score: Int
    let metrics: PlotViewMetrics
    var exiledCards: Set<Card> = []
    var hiddenExiledPlotCards: Set<Card> = []

    var body: some View {
        HStack(alignment: .top, spacing: metrics.spacing * 0.75) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    PortraitView(player: player, human: player.isHuman)
                        .frame(width: metrics.portraitSize, height: metrics.portraitSize)
                    if hasVulnerableCard {
                        GameIcon(.statusVulnerable, size: 14)
                            .padding(.top, -3)
                            .padding(.trailing, -4)
                    }
                }
                PixelText(text: language.playerName(player), size: .caption2, variant: .heavy, color: .kolkhozCream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(width: metrics.portraitSize + 12, alignment: .top)

            VStack(alignment: .leading, spacing: metrics.spacing * 0.7) {
                HStack(alignment: .center, spacing: metrics.spacing * 0.5) {
                    OpponentPlotMiniSection(
                        icon: .cellar,
                        value: "\(visibleHiddenCards.count)",
                        cards: visibleHiddenCards,
                        hidden: true,
                        metrics: metrics,
                        exiledCards: exiledCards
                    )
                    OpponentPlotMiniSection(
                        icon: .plot,
                        value: "\(score)",
                        cards: visibleRevealedCards,
                        hidden: false,
                        metrics: metrics,
                        exiledCards: exiledCards
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
            .padding(.top, 0)
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .padding(metrics.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(0.5), lineWidth: 1)
        }
    }

    private var hasVulnerableCard: Bool {
        visibleRevealedCards.contains { exiledCards.contains($0) }
            || visibleHiddenCards.contains { exiledCards.contains($0) }
    }

    private var visibleHiddenCards: [Card] {
        player.plot.hidden.filter { !hiddenExiledPlotCards.contains($0) }
    }

    private var visibleRevealedCards: [Card] {
        player.plot.revealed.filter { !hiddenExiledPlotCards.contains($0) }
    }

}

private struct OpponentPlotMiniSection: View {
    let icon: GameIconAsset
    let value: String
    let cards: [Card]
    let hidden: Bool
    let metrics: PlotViewMetrics
    let exiledCards: Set<Card>

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            VStack(spacing: 1) {
                GameIcon(icon, size: metrics.headerIconSize)
                PixelText(text: value, size: .caption2, variant: .heavy, color: .kolkhozGold)
            }
            .frame(width: metrics.headerIconSize + 5)

            HStack(alignment: .center, spacing: metrics.columnCardSpacing * 0.56) {
                ForEach(Array(cards.prefix(2))) { card in
                    cardView(card)
                }
                if cards.isEmpty {
                    PixelText(text: "-", size: .caption, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                        .frame(width: metrics.opponentCardFrameWidth, height: metrics.opponentCardFrameHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Color.kolkhozBlack.opacity(0.12), in: RoundedRectangle(cornerRadius: 4))
    }

    @ViewBuilder
    private func cardView(_ card: Card) -> some View {
        Group {
            if hidden {
                CardBackView(size: .small)
            } else {
                CardView(card: card, size: .small)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(exiledCards.contains(card) ? Color.kolkhozRedBright : Color.clear, lineWidth: 3)
        }
        .scaleEffect(metrics.opponentCardScale * (exiledCards.contains(card) ? 1.08 : 1), anchor: .topLeading)
        .frame(width: metrics.opponentCardFrameWidth, height: metrics.opponentCardFrameHeight, alignment: .topLeading)
    }
}

struct PlotColumn: View {
    let title: String
    let icon: GameIconAsset
    let subtitle: String
    let cards: [Card]
    let hidden: Bool
    let metrics: PlotViewMetrics
    var exiledCards: Set<Card> = []
    var isSelected: (Card) -> Bool = { _ in false }
    var onSelect: ((Card) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.spacing * 0.75) {
            HStack(alignment: .center, spacing: 5) {
                GameIcon(icon, size: metrics.headerIconSize)
                PixelText(text: title.uppercased(), size: .caption, variant: .heavy, color: .kolkhozGold)
                Spacer(minLength: 8)
                PixelText(text: subtitle, size: .caption2, color: .kolkhozSmoke)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: metrics.columnCardSpacing) {
                    ForEach(cards) { card in
                        selectableCard(card)
                    }
                    if cards.isEmpty {
                        PixelText(text: "-", size: .title, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                            .frame(
                                width: metrics.playerCardSize.width * metrics.playerCardScale,
                                height: metrics.playerCardSize.height * metrics.playerCardScale
                            )
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, metrics.columnTrailingPadding)
            }
        }
        .padding(metrics.padding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(onSelect == nil ? Color.kolkhozSteel.opacity(0.5) : Color.kolkhozGold.opacity(0.58), lineWidth: onSelect == nil ? 1 : 1.5)
        }
    }

    @ViewBuilder
    private func selectableCard(_ card: Card) -> some View {
        if let onSelect {
            Button {
                onSelect(card)
            } label: {
                cardFace(card)
            }
            .buttonStyle(.plain)
        } else {
            cardFace(card)
        }
    }

    private func cardFace(_ card: Card) -> some View {
        Group {
            if hidden {
                CardBackView(size: metrics.playerCardSize)
            } else {
                CardView(card: card, size: metrics.playerCardSize)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardStrokeColor(card), lineWidth: cardStrokeWidth(card))
        }
        .scaleEffect(metrics.playerCardScale, anchor: .topLeading)
        .frame(
            width: metrics.playerCardSize.width * metrics.playerCardScale,
            height: metrics.playerCardSize.height * metrics.playerCardScale,
            alignment: .topLeading
        )
    }

    private func cardStrokeColor(_ card: Card) -> Color {
        if exiledCards.contains(card) {
            return .kolkhozRedBright
        }
        if isSelected(card) {
            return .kolkhozGreen
        }
        return .clear
    }

    private func cardStrokeWidth(_ card: Card) -> CGFloat {
        exiledCards.contains(card) || isSelected(card) ? 3 : 0
    }
}

struct PlotSelection: Equatable {
    let card: Card
    let zone: PlotCardZone
}

#if DEBUG
#Preview("Plot Overview") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 720, height: 330) {
        PlotStorageView(selectedPlot: nil)
    }
}

#Preview("Swap Plot") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 720, height: 300) {
        SwapPlotPreviewHost()
    }
}

#Preview("Requisition Plot") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 820, height: 320) {
        PlotStorageView(selectedPlot: nil)
    }
}

private struct SwapPlotPreviewHost: View {
    @State private var selectedPlot: PlotSelection?

    var body: some View {
        PlotStorageView(selectedPlot: $selectedPlot)
    }
}
#endif
