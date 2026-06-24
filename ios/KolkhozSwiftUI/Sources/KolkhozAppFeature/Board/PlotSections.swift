import KolkhozCore
import SwiftUI

enum PlotSectionLayout {
    static let compactWidth: CGFloat = 760
    static let denseHeight: CGFloat = 420
    static let swapTightHeight: CGFloat = 430
    static let denseOpponentHeight: CGFloat = 70
    static let regularOpponentHeight: CGFloat = 82
    static let denseSpacing: CGFloat = 8
    static let regularSpacing: CGFloat = 10
    static let compactSpacing: CGFloat = 7
    static let swapBotHeightCompact: CGFloat = 66
    static let swapBotHeightRegular: CGFloat = 76
    static let densePadding: CGFloat = 8
    static let regularPadding: CGFloat = 12
    static let denseColumnCardSpacing: CGFloat = -28
    static let regularColumnCardSpacing: CGFloat = -30
    static let denseOpponentCardScale: CGFloat = 0.68
    static let regularOpponentCardScale: CGFloat = 0.76
}

struct PlotOverviewView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < PlotSectionLayout.compactWidth
            let dense = compact || proxy.size.height < PlotSectionLayout.denseHeight
            let opponentHeight: CGFloat = dense ? PlotSectionLayout.denseOpponentHeight : PlotSectionLayout.regularOpponentHeight
            let spacing: CGFloat = dense ? PlotSectionLayout.denseSpacing : PlotSectionLayout.regularSpacing

            VStack(alignment: .leading, spacing: spacing) {
                PanelTitleRow(
                    title: language.text(en: "Private plot", ru: "Личный участок"),
                    subtitle: language.text(en: "Opponent stores above, your cellar below.", ru: "Участки соперников сверху, ваш подвал снизу."),
                    icon: .plot,
                    compact: dense
                )

                HStack(spacing: compact ? PlotSectionLayout.compactSpacing : PlotSectionLayout.regularSpacing) {
                    ForEach(store.state.players.dropFirst()) { player in
                        PlotOpponentPanel(player: player, score: store.visibleScore(for: player.id), dense: dense)
                    }
                }
                .frame(height: opponentHeight)

                HStack(alignment: .top, spacing: spacing) {
                    PlotColumn(
                        title: language.text(en: "Hidden", ru: "Скрытые"),
                        subtitle: "\(store.state.players[0].plot.hidden.count)",
                        cards: store.state.players[0].plot.hidden,
                        hidden: true,
                        dense: dense
                    )
                    PlotColumn(
                        title: language.text(en: "Rewards", ru: "Награды"),
                        subtitle: "\(store.state.players[0].plot.revealed.count)",
                        cards: store.state.players[0].plot.revealed,
                        hidden: false,
                        dense: dense
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(dense ? PlotSectionLayout.densePadding + 1 : PlotSectionLayout.regularPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background(CommandPanelBackground())
        }
    }
}

struct PlotOpponentPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let score: Int
    let dense: Bool

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
                            .scaleEffect(dense ? PlotSectionLayout.denseOpponentCardScale : PlotSectionLayout.regularOpponentCardScale, anchor: .topLeading)
                            .frame(width: dense ? 25 : 29, height: dense ? 38 : 44, alignment: .topLeading)
                    }
                    ForEach(0..<min(player.plot.hidden.count, dense ? 3 : 4), id: \.self) { _ in
                        CardBackView(size: .small)
                            .scaleEffect(dense ? PlotSectionLayout.denseOpponentCardScale : PlotSectionLayout.regularOpponentCardScale, anchor: .topLeading)
                            .frame(width: dense ? 25 : 29, height: dense ? 38 : 44, alignment: .topLeading)
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
}

struct PlotColumn: View {
    let title: String
    let subtitle: String
    let cards: [Card]
    let hidden: Bool
    let dense: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? 6 : 8) {
            HStack(alignment: .firstTextBaseline) {
                PixelText(text: title.uppercased(), size: .caption, variant: .heavy, color: .kolkhozGold)
                Spacer(minLength: 8)
                PixelText(text: subtitle, size: .caption2, color: .kolkhozSmoke)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: dense ? PlotSectionLayout.denseColumnCardSpacing : PlotSectionLayout.regularColumnCardSpacing) {
                    ForEach(cards) { card in
                        if hidden {
                            CardBackView(size: dense ? .small : .medium)
                        } else {
                            CardView(card: card, size: dense ? .small : .medium)
                        }
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
                .stroke(Color.kolkhozSteel.opacity(0.5), lineWidth: 1)
        }
    }
}

struct SwapPlotView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @Binding var selectedPlot: PlotSelection?

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < PlotSectionLayout.compactWidth
            let tightHeight = proxy.size.height < PlotSectionLayout.swapTightHeight
            let dense = compact || tightHeight
            let rowSpacing: CGFloat = compact ? PlotSectionLayout.compactSpacing : PlotSectionLayout.regularSpacing - 1

            VStack(spacing: rowSpacing) {
                HStack(spacing: compact ? PlotSectionLayout.compactSpacing : PlotSectionLayout.regularSpacing) {
                    ForEach(store.state.players.dropFirst()) { player in
                        SwapBotPanel(player: player, active: store.state.currentPlayer == player.id)
                    }
                }
                .frame(height: compact ? PlotSectionLayout.swapBotHeightCompact : PlotSectionLayout.swapBotHeightRegular)

                HStack(spacing: rowSpacing) {
                    SwapCardBand(
                        title: language.text(en: "Cellar", ru: "Подвал"),
                        subtitle: language.text(en: "Hidden score cards", ru: "Скрытые карты очков"),
                        icon: .cellar,
                        cards: store.state.players[0].plot.hidden,
                        hidden: true,
                        dense: dense,
                        selected: { selectedPlot == PlotSelection(card: $0, zone: .hidden) }
                    ) { card in
                        selectedPlot = PlotSelection(card: card, zone: .hidden)
                    }

                    SwapCardBand(
                        title: language.text(en: "Plot", ru: "Участок"),
                        subtitle: language.text(en: "Visible score cards", ru: "Открытые карты очков"),
                        icon: .plot,
                        cards: store.state.players[0].plot.revealed,
                        hidden: false,
                        dense: dense,
                        selected: { selectedPlot == PlotSelection(card: $0, zone: .revealed) }
                    ) { card in
                        selectedPlot = PlotSelection(card: card, zone: .revealed)
                    }
                }
            }
            .padding(dense ? PlotSectionLayout.densePadding : PlotSectionLayout.regularPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }
}

struct SwapCommandButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kolkhozTitle(.caption))
            .textCase(.uppercase)
            .foregroundStyle(prominent ? Color.kolkhozOnAccent : Color.kolkhozCream)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, prominent ? 20 : 16)
            .padding(.top, prominent ? 8 : 7)
            .padding(.bottom, prominent ? 6 : 5)
            .frame(minWidth: prominent ? 132 : 88, minHeight: prominent ? 36 : 32)
            .background {
                GeneratedChromeImage(resourceName: prominent ? "ui-button-primary" : "ui-button-secondary")
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .shadow(color: .black.opacity(prominent ? 0.28 : 0.18), radius: prominent ? 5 : 3, y: 2)
    }
}

struct SwapBotPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            PortraitView(player: player, human: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(language.playerName(player))
                    .font(.kolkhozTitle(.caption))
                    .foregroundStyle(active ? Color.kolkhozGold : Color.kolkhozCream)
                HStack(spacing: -4) {
                    ForEach(0..<min(player.hand.count, 5), id: \.self) { _ in
                        CardBackThumbnail()
                    }
                }
                Text(language.text(en: "\(player.plot.hidden.count) hidden  \(player.plot.revealed.count) revealed", ru: "\(player.plot.hidden.count) скрыто  \(player.plot.revealed.count) открыто"))
                    .font(.kolkhozLabel(.caption2))
                    .foregroundStyle(Color.kolkhozSmoke)
            }
            Spacer()
            if active {
                GameIcon(.gears, size: 22)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(active ? Color.kolkhozRed.opacity(0.18) : Color.kolkhozBlack.opacity(0.14), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            if active {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.kolkhozGold.opacity(0.9), lineWidth: 1.5)
            }
        }
    }
}

struct PlotSelection: Equatable {
    let card: Card
    let zone: PlotCardZone
}

struct SwapCardBand: View {
    let title: String
    let subtitle: String
    var icon: GameIconAsset?
    let cards: [Card]
    let hidden: Bool
    var cardSize: CardSize = .medium
    var dense = false
    let selected: (Card) -> Bool
    let onSelect: (Card) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: dense ? 5 : 7) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 5) {
                    if let icon {
                        GameIcon(icon, size: dense ? 16 : 18)
                    }
                    Text(title)
                        .font(.kolkhozTitle(.caption))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.kolkhozGold)
                }
                Spacer(minLength: 8)
                Text(subtitle)
                    .font(.kolkhozLabel(.caption2))
                    .foregroundStyle(Color.kolkhozSmoke)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: dense ? -18 : -16) {
                    ForEach(cards) { card in
                        Button { onSelect(card) } label: {
                            if hidden {
                                CardBackView(size: cardSize)
                            } else {
                                CardView(card: card, size: cardSize)
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected(card) ? Color.kolkhozGreen : Color.clear, lineWidth: 3)
                        }
                    }
                    if cards.isEmpty {
                        Text("-")
                            .font(.kolkhozTitle(.title2))
                            .foregroundStyle(Color.kolkhozSmoke)
                            .frame(width: cardSize.width, height: cardSize.height)
                    }
                }
                .padding(.vertical, dense ? 1 : 3)
                .padding(.trailing, cardSize.width * 0.30)
            }
        }
        .padding(dense ? 7 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.10), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct RequisitionPlotView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(store.state.players) { player in
                        RequisitionPlayerPlot(player: player, exiledCards: exiledCards)
                    }
                }
                .frame(maxHeight: .infinity)
            }

            RequisitionSummaryPanel()
                .frame(width: 310)
        }
        .padding(12)
        .background(CommandPanelBackground())
    }

    private var exiledCards: Set<Card> {
        Set(store.state.exiled[store.state.year, default: []])
    }
}

struct RequisitionPlayerPlot: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let exiledCards: Set<Card>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                PortraitView(player: player, human: player.id == 0)
                Text(language.playerName(player))
                    .font(.kolkhozTitle(.caption))
                    .foregroundStyle(Color.kolkhozCream)
                    .lineLimit(1)
            }
            HStack(alignment: .top, spacing: -28) {
                ForEach(player.plot.revealed) { card in
                    CardView(card: card, size: .small)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(exiledCards.contains(card) ? Color.kolkhozRedBright : Color.clear, lineWidth: 3)
                        }
                        .scaleEffect(exiledCards.contains(card) ? 1.08 : 1)
                }
                ForEach(0..<player.plot.hidden.count, id: \.self) { _ in
                    CardBackView(size: .small)
                        .opacity(0.72)
                }
                if player.plot.revealed.isEmpty && player.plot.hidden.isEmpty {
                    Text("-")
                        .font(.kolkhozTitle(.title3))
                        .foregroundStyle(Color.kolkhozSmoke)
                        .frame(width: 48, height: 68)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(0.62), lineWidth: 1)
        }
    }
}

struct RequisitionSummaryPanel: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: language.text(en: "Requisition", ru: "Реквизиция"),
                subtitle: language.text(en: "Unprotected plot cards may be taken.", ru: "Незащищённые карты участка могут забрать."),
                icon: .warning,
                urgent: true
            )
            Text(language.text(en: "Year \(store.state.year) audit", ru: "Проверка: год \(store.state.year)"))
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCreamDim)

            ScrollView {
                VStack(spacing: 8) {
                    if store.state.requisitionEvents.isEmpty {
                        Text(language.text(en: "All jobs complete!", ru: "Все работы выполнены!"))
                            .font(.kolkhozLabel(.caption))
                            .foregroundStyle(Color.kolkhozCreamDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(store.state.requisitionEvents) { event in
                            RequisitionEventRow(event: event)
                        }
                    }
                }
            }

            Button(store.state.year >= 5 ? language.text(en: "Finish plan", ru: "Завершить план") : language.text(en: "Continue to Year \(store.state.year + 1)", ru: "Продолжить к Году \(store.state.year + 1)")) {
                store.continueAfterRequisition()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
        }
        .padding(10)
        .background(Color.kolkhozRedDark.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozRed.opacity(0.55), lineWidth: 1.5)
        }
    }
}

struct NorthHistoryView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(1...5, id: \.self) { year in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        PixelText(
                            text: language.text(en: "YEAR \(year)", ru: "ГОД \(year)"),
                            size: .caption,
                            variant: .heavy,
                            color: year == store.state.year ? Color.kolkhozRedBright : Color.kolkhozGold
                        )
                        Spacer()
                        PixelText(text: "\(store.state.exiled[year, default: []].count)", size: .caption2, variant: .heavy, color: .kolkhozCreamDim)
                    }
                    ScrollView {
                        VStack(spacing: -38) {
                            ForEach(store.state.exiled[year, default: []]) { card in
                                CardView(card: card, size: .small)
                            }
                            if store.state.exiled[year, default: []].isEmpty {
                                VStack(spacing: 4) {
                                    BadgeSealOrnament()
                                        .frame(width: 34, height: 34)
                                        .opacity(year == store.state.year ? 0.56 : 0.36)
                                    PixelText(text: "-", size: .caption, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                                }
                                .frame(maxWidth: .infinity, minHeight: 80)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.bottom, 38)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.kolkhozBlack.opacity(year == store.state.year ? 0.38 : 0.24), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(year == store.state.year ? Color.kolkhozRedBright : Color.kolkhozSteel.opacity(0.6), lineWidth: year == store.state.year ? 2 : 1)
                }
            }
        }
        .padding(12)
        .background(CommandPanelBackground())
    }
}

#if DEBUG
#Preview("Plot Overview") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 720, height: 330) {
        PlotOverviewView()
    }
}

#Preview("Swap Plot") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 720, height: 300) {
        SwapPlotPreviewHost()
    }
}

#Preview("Requisition Plot") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 820, height: 320) {
        RequisitionPlotView()
    }
}

#Preview("North History") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 760, height: 300) {
        NorthHistoryView()
    }
}

private struct SwapPlotPreviewHost: View {
    @State private var selectedPlot: PlotSelection?

    var body: some View {
        SwapPlotView(selectedPlot: $selectedPlot)
    }
}
#endif
