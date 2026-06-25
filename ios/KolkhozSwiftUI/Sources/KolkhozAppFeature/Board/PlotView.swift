import KolkhozCore
import SwiftUI

enum PlotViewLayout {
    static let compactWidth: CGFloat = 760
    static let denseHeight: CGFloat = 420
    static let swapTightHeight: CGFloat = 430
    static let denseOpponentHeight: CGFloat = 70
    static let regularOpponentHeight: CGFloat = 82
    static let denseSpacing: CGFloat = 8
    static let regularSpacing: CGFloat = 10
    static let compactSpacing: CGFloat = 7
    static let densePadding: CGFloat = 8
    static let regularPadding: CGFloat = 12
    static let denseColumnCardSpacing: CGFloat = -28
    static let regularColumnCardSpacing: CGFloat = -30
    static let denseOpponentCardScale: CGFloat = 0.68
    static let regularOpponentCardScale: CGFloat = 0.76
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
            let compact = proxy.size.width < PlotViewLayout.compactWidth
            let denseHeight = isInteractive ? PlotViewLayout.swapTightHeight : PlotViewLayout.denseHeight
            let dense = compact || proxy.size.height < denseHeight
            let opponentHeight: CGFloat = dense ? PlotViewLayout.denseOpponentHeight : PlotViewLayout.regularOpponentHeight
            let spacing: CGFloat = dense ? PlotViewLayout.denseSpacing : PlotViewLayout.regularSpacing

            VStack(alignment: .leading, spacing: spacing) {
                plotHeader(compact: dense)

                HStack(spacing: compact ? PlotViewLayout.compactSpacing : PlotViewLayout.regularSpacing) {
                    ForEach(store.state.players.dropFirst()) { player in
                        PlayerPlotPanel(player: player, score: store.visibleScore(for: player.id), dense: dense, exiledCards: exiledCards)
                    }
                }
                .frame(height: opponentHeight)

                HStack(alignment: .top, spacing: spacing) {
                    PlotColumn(
                        title: language.text(en: "Cellar", ru: "Подвал"),
                        icon: .cellar,
                        subtitle: "\(store.state.players[0].plot.hidden.count)",
                        cards: store.state.players[0].plot.hidden,
                        hidden: true,
                        dense: dense,
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
                        dense: dense,
                        exiledCards: exiledCards,
                        isSelected: { selectedPlot?.wrappedValue == PlotSelection(card: $0, zone: .revealed) },
                        onSelect: isInteractive ? { card in
                            selectedPlot?.wrappedValue = PlotSelection(card: card, zone: .revealed)
                        } : nil
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(dense ? PlotViewLayout.densePadding + 1 : PlotViewLayout.regularPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(CommandPanelBackground())
        }
    }

    @ViewBuilder
    private func plotHeader(compact: Bool) -> some View {
        if isRequisition {
            PanelTitleRow(
                title: language.text(en: "Requisition", ru: "Реквизиция"),
                subtitle: requisitionSubtitle,
                icon: .warning,
                urgent: true,
                compact: compact
            )
        } else {
            PanelTitleRow(
                title: language.text(en: "Private plot", ru: "Личный участок"),
                subtitle: language.text(en: "Opponent stores above, your cellar below.", ru: "Участки соперников сверху, ваш подвал снизу."),
                icon: .plot,
                compact: compact
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
    let dense: Bool
    var exiledCards: Set<Card> = []

    var body: some View {
        HStack(spacing: dense ? 6 : 8) {
            PortraitView(player: player, human: false)
                .frame(width: dense ? 34 : 42, height: dense ? 34 : 42)

            VStack(alignment: .leading, spacing: dense ? 5 : 7) {
                HStack(spacing: 5) {
                    PixelText(text: language.playerName(player), size: .caption2, variant: .heavy, color: .kolkhozCream)
                    Spacer(minLength: 0)
                    PixelText(text: "\(score)", size: .caption2, variant: .heavy, color: .kolkhozGold)
                }

                HStack(alignment: .top, spacing: dense ? -18 : -15) {
                    ForEach(Array(player.plot.revealed.prefix(dense ? 3 : 4))) { card in
                        CardView(card: card, size: .small)
                            .overlay {
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(exiledCards.contains(card) ? Color.kolkhozRedBright : Color.clear, lineWidth: 3)
                            }
                            .scaleEffect(cardScale * (exiledCards.contains(card) ? 1.08 : 1), anchor: .topLeading)
                            .frame(width: cardFrameWidth, height: cardFrameHeight, alignment: .topLeading)
                    }
                    ForEach(0..<hiddenCardCount, id: \.self) { _ in
                        CardBackView(size: .small)
                            .scaleEffect(cardScale, anchor: .topLeading)
                            .frame(width: cardFrameWidth, height: cardFrameHeight, alignment: .topLeading)
                    }
                    if player.plot.hidden.isEmpty && player.plot.revealed.isEmpty {
                        PixelText(text: "-", size: .caption, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                            .frame(height: dense ? 32 : 38)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .clipped()
            }
        }
        .padding(dense ? 7 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(0.5), lineWidth: 1)
        }
    }

    private var hiddenCardCount: Int {
        min(player.plot.hidden.count, dense ? 3 : 4)
    }

    private var cardScale: CGFloat {
        dense ? PlotViewLayout.denseOpponentCardScale : PlotViewLayout.regularOpponentCardScale
    }

    private var cardFrameWidth: CGFloat {
        dense ? 25 : 29
    }

    private var cardFrameHeight: CGFloat {
        dense ? 38 : 44
    }
}

struct PlotColumn: View {
    let title: String
    let icon: GameIconAsset
    let subtitle: String
    let cards: [Card]
    let hidden: Bool
    let dense: Bool
    var exiledCards: Set<Card> = []
    var isSelected: (Card) -> Bool = { _ in false }
    var onSelect: ((Card) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? 6 : 8) {
            HStack(alignment: .center, spacing: 5) {
                GameIcon(icon, size: dense ? 17 : 20)
                PixelText(text: title.uppercased(), size: .caption, variant: .heavy, color: .kolkhozGold)
                Spacer(minLength: 8)
                PixelText(text: subtitle, size: .caption2, color: .kolkhozSmoke)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: dense ? PlotViewLayout.denseColumnCardSpacing : PlotViewLayout.regularColumnCardSpacing) {
                    ForEach(cards) { card in
                        selectableCard(card)
                    }
                    if cards.isEmpty {
                        PixelText(text: "-", size: .title, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                            .frame(
                                width: dense ? CardSize.small.width : CardSize.medium.width,
                                height: dense ? CardSize.small.height : CardSize.medium.height
                            )
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, dense ? 20 : 28)
            }
        }
        .padding(dense ? 8 : 10)
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
                CardBackView(size: dense ? .small : .medium)
            } else {
                CardView(card: card, size: dense ? .small : .medium)
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
