import KolkhozCore
import SwiftUI

enum PlotViewLayout {
    static let minOpponentHeight: CGFloat = 70
    static let maxOpponentHeight: CGFloat = 82
    static let minSpacing: CGFloat = 7
    static let maxSpacing: CGFloat = 10
    static let minPadding: CGFloat = 8
    static let maxPadding: CGFloat = 12
    static let minColumnCardSpacing: CGFloat = -30
    static let maxColumnCardSpacing: CGFloat = -24
    static let minOpponentCardScale: CGFloat = 0.68
    static let maxOpponentCardScale: CGFloat = 0.76
    static let minOpponentCardFrameWidth: CGFloat = 25
    static let maxOpponentCardFrameWidth: CGFloat = 29
    static let minOpponentCardFrameHeight: CGFloat = 38
    static let maxOpponentCardFrameHeight: CGFloat = 44
}

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

    init(size: CGSize) {
        let shorterSide = min(size.width, size.height)
        opponentHeight = kolkhozClamp(size.height * 0.18, PlotViewLayout.minOpponentHeight, PlotViewLayout.maxOpponentHeight)
        spacing = kolkhozClamp(shorterSide * 0.02, PlotViewLayout.minSpacing, PlotViewLayout.maxSpacing)
        padding = kolkhozClamp(shorterSide * 0.025, PlotViewLayout.minPadding, PlotViewLayout.maxPadding)
        columnCardSpacing = kolkhozClamp(-size.width * 0.04, PlotViewLayout.minColumnCardSpacing, PlotViewLayout.maxColumnCardSpacing)
        columnTrailingPadding = kolkhozClamp(size.width * 0.035, 20, 28)
        opponentCardScale = kolkhozClamp(size.width * 0.001, PlotViewLayout.minOpponentCardScale, PlotViewLayout.maxOpponentCardScale)
        opponentCardFrameWidth = kolkhozClamp(size.width * 0.04, PlotViewLayout.minOpponentCardFrameWidth, PlotViewLayout.maxOpponentCardFrameWidth)
        opponentCardFrameHeight = kolkhozClamp(size.height * 0.10, PlotViewLayout.minOpponentCardFrameHeight, PlotViewLayout.maxOpponentCardFrameHeight)
        opponentVisibleCardCount = Int(kolkhozClamp(size.width / 190, 3, 4))
        portraitSize = kolkhozClamp(size.width * 0.055, 34, 42)
        panelPadding = kolkhozClamp(shorterSide * 0.018, 7, 8)
        headerIconSize = kolkhozClamp(size.width * 0.026, 17, 20)
        emptyCardSize = .small
    }
}

struct PlotStorageView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    let selectedPlot: Binding<PlotSelection?>?

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

            VStack(alignment: .leading, spacing: metrics.spacing) {
                plotHeader()

                HStack(spacing: metrics.spacing) {
                    ForEach(store.state.players.dropFirst()) { player in
                        PlayerPlotPanel(player: player, score: store.visibleScore(for: player.id), metrics: metrics, exiledCards: exiledCards)
                    }
                }
                .frame(height: metrics.opponentHeight)

                HStack(alignment: .top, spacing: metrics.spacing) {
                    PlotColumn(
                        title: language.text(en: "Cellar", ru: "Подвал"),
                        icon: .cellar,
                        subtitle: "\(store.state.players[0].plot.hidden.count)",
                        cards: store.state.players[0].plot.hidden,
                        hidden: true,
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
                        subtitle: "\(store.state.players[0].plot.revealed.count)",
                        cards: store.state.players[0].plot.revealed,
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
                icon: .warning,
                urgent: true
            )
        } else {
            PanelTitleRow(
                title: language.text(en: "Private plot", ru: "Личный участок"),
                subtitle: language.text(en: "Opponent stores above, your cellar below.", ru: "Участки соперников сверху, ваш подвал снизу."),
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
}

struct PlayerPlotPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let score: Int
    let metrics: PlotViewMetrics
    var exiledCards: Set<Card> = []

    var body: some View {
        HStack(spacing: metrics.spacing * 0.75) {
            PortraitView(player: player, human: false)
                .frame(width: metrics.portraitSize, height: metrics.portraitSize)

            VStack(alignment: .leading, spacing: metrics.spacing * 0.7) {
                HStack(spacing: 5) {
                    PixelText(text: language.playerName(player), size: .caption2, variant: .heavy, color: .kolkhozCream)
                    Spacer(minLength: 0)
                    PixelText(text: "\(score)", size: .caption2, variant: .heavy, color: .kolkhozGold)
                }

                HStack(alignment: .top, spacing: metrics.columnCardSpacing * 0.64) {
                    ForEach(Array(player.plot.revealed.prefix(metrics.opponentVisibleCardCount))) { card in
                        CardView(card: card, size: .small)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(exiledCards.contains(card) ? Color.kolkhozRedBright : Color.clear, lineWidth: 3)
                            }
                            .scaleEffect(metrics.opponentCardScale * (exiledCards.contains(card) ? 1.08 : 1), anchor: .topLeading)
                            .frame(width: metrics.opponentCardFrameWidth, height: metrics.opponentCardFrameHeight, alignment: .topLeading)
                    }
                    ForEach(0..<hiddenCardCount, id: \.self) { _ in
                        CardBackView(size: .small)
                            .scaleEffect(metrics.opponentCardScale, anchor: .topLeading)
                            .frame(width: metrics.opponentCardFrameWidth, height: metrics.opponentCardFrameHeight, alignment: .topLeading)
                    }
                    if player.plot.hidden.isEmpty && player.plot.revealed.isEmpty {
                        PixelText(text: "-", size: .caption, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                            .frame(height: metrics.opponentCardFrameHeight)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .padding(metrics.panelPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(0.5), lineWidth: 1)
        }
    }

    private var hiddenCardCount: Int {
        min(player.plot.hidden.count, metrics.opponentVisibleCardCount)
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
                                width: metrics.emptyCardSize.width,
                                height: metrics.emptyCardSize.height
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
                CardBackView(size: metrics.emptyCardSize)
            } else {
                CardView(card: card, size: metrics.emptyCardSize)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(cardStrokeColor(card), lineWidth: cardStrokeWidth(card))
        }
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
