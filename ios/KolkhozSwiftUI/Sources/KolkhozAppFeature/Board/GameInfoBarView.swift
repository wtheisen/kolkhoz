import KolkhozCore
import SwiftUI

enum GameInfoBarLayout {
    static let compactWidth: CGFloat = 720
    static let microWidth: CGFloat = 620
    static let height: CGFloat = 48
    static let rowSpacingMicro: CGFloat = 3
    static let rowSpacingCompact: CGFloat = 4
    static let rowSpacingRegular: CGFloat = 6
    static let yearWidthMicro: CGFloat = 46
    static let yearWidthCompact: CGFloat = 52
    static let yearWidthRegular: CGFloat = 92
    static let leadWidth: CGFloat = 96
    static let gaugeWidthCompact: CGFloat = 78
    static let gaugeWidthRegular: CGFloat = 84
    static let gaugeHeightCompact: CGFloat = 36
    static let gaugeHeightRegular: CGFloat = 38
    static let gaugeSpacingCompact: CGFloat = 3
    static let gaugeSpacingRegular: CGFloat = 6
    static let scoreWidthMicro: CGFloat = 54
    static let scoreWidthCompact: CGFloat = 60
    static let scoreWidthRegular: CGFloat = 84
}

struct InfoBarView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < GameInfoBarLayout.compactWidth
            let micro = proxy.size.width < GameInfoBarLayout.microWidth
            let cellarScore = store.state.players[0].plot.hidden.reduce(0) { $0 + $1.value }
            let plotScore = store.state.players[0].plot.revealed.reduce(0) { $0 + $1.value }
            let rowSpacing: CGFloat = micro ? GameInfoBarLayout.rowSpacingMicro : (compact ? GameInfoBarLayout.rowSpacingCompact : GameInfoBarLayout.rowSpacingRegular)
            let yearWidth: CGFloat = micro ? GameInfoBarLayout.yearWidthMicro : (compact ? GameInfoBarLayout.yearWidthCompact : GameInfoBarLayout.yearWidthRegular)
            let leadWidth: CGFloat = store.state.currentTrick.first?.card.suit != nil && !compact ? GameInfoBarLayout.leadWidth : 0
            let gaugeWidth: CGFloat = compact ? GameInfoBarLayout.gaugeWidthCompact : GameInfoBarLayout.gaugeWidthRegular
            let gaugeSpacing: CGFloat = compact ? GameInfoBarLayout.gaugeSpacingCompact : GameInfoBarLayout.gaugeSpacingRegular
            let gaugesWidth = gaugeWidth * CGFloat(Suit.allCases.count) + gaugeSpacing * CGFloat(Suit.allCases.count - 1)
            let scoreWidth: CGFloat = micro ? GameInfoBarLayout.scoreWidthMicro : (compact ? GameInfoBarLayout.scoreWidthCompact : GameInfoBarLayout.scoreWidthRegular)
            let visibleCellCount = leadWidth > 0 ? 5 : 4
            let preferredRowWidth = yearWidth + leadWidth + gaugesWidth + scoreWidth * 2 + rowSpacing * CGFloat(visibleCellCount - 1)
            let rowWidth = min(proxy.size.width, preferredRowWidth)

            HStack(spacing: rowSpacing) {
                InfoCell(label: compact ? "" : language.text(en: "Year", ru: "Год"), icon: compact ? yearIcon : nil, value: compact ? nil : "\(store.state.year)/5", compact: compact)
                    .frame(width: yearWidth)

                if let lead = store.state.currentTrick.first?.card.suit, !compact {
                    InfoSuitCell(label: language.text(en: "Lead", ru: "Ведёт"), suit: lead, fallback: "-", compact: compact)
                        .frame(width: leadWidth)
                }

                HStack(spacing: gaugeSpacing) {
                    ForEach(Suit.allCases) { suit in
                        InfoJobGauge(
                            suit: suit,
                            hours: store.state.workHours[suit, default: 0],
                            claimed: store.state.claimedJobs.contains(suit),
                            highlighted: store.state.trump == suit,
                            compact: compact,
                            jobTargets: $jobTargets
                        )
                        .frame(width: gaugeWidth)
                    }
                }
                .frame(width: gaugesWidth)

                InfoIconCell(
                    label: compact ? "" : language.text(en: "Cellar", ru: "Подвал"),
                    icon: .cellar,
                    value: "\(cellarScore)",
                    warning: true,
                    compact: compact
                )
                .frame(width: scoreWidth)
                InfoIconCell(
                    label: compact ? "" : language.text(en: "Plot", ru: "Участок"),
                    icon: .plot,
                    value: "\(plotScore)",
                    compact: compact
                )
                .frame(width: scoreWidth)
            }
            .frame(width: rowWidth, height: proxy.size.height)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
            .background(CommandPanelBackground())
        }
        .frame(height: GameInfoBarLayout.height)
    }

    private var yearIcon: GameIconAsset {
        switch store.state.year {
        case 1: .year1
        case 2: .year2
        case 3: .year3
        case 4: .year4
        default: .year5
        }
    }

}

struct InfoCell: View {
    let label: String
    var icon: GameIconAsset?
    let value: String?
    var warning = false
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            if let icon {
                GameIcon(icon, size: compact ? 42 : 18)
            } else if !label.isEmpty {
                PixelText(text: label.uppercased(), size: .caption2, color: warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
            if let value {
                PixelText(
                    text: value,
                    size: compact ? .caption : .headline,
                    variant: .heavy,
                    color: .kolkhozGold
                )
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .frame(height: GameInfoBarLayout.height)
        .background(warning ? Color.kolkhozRedDark.opacity(0.18) : Color.clear)
    }
}

struct InfoIconCell: View {
    let label: String
    let icon: GameIconAsset
    let value: String
    var warning = false
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            GameIcon(icon, size: compact ? 26 : 20)
            if !label.isEmpty {
                PixelText(text: label.uppercased(), size: .caption2, color: warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
            PixelText(
                text: value,
                size: compact ? .caption : .headline,
                variant: .heavy,
                color: .kolkhozGold
            )
        }
        .padding(.horizontal, compact ? 6 : 10)
        .frame(height: GameInfoBarLayout.height)
        .background(warning ? Color.kolkhozRedDark.opacity(0.18) : Color.clear)
    }
}

struct InfoSuitCell: View {
    let label: String
    var icon: GameIconAsset?
    let suit: Suit?
    let fallback: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 6) {
            if let icon {
                GameIcon(icon, size: compact ? 16 : 18, muted: true)
                PixelText(text: ":", size: .caption2, color: .kolkhozSmoke)
            } else if !label.isEmpty {
                PixelText(text: label.uppercased(), size: .caption2, color: .kolkhozSmoke)
            }
            if let suit {
                SuitMark(suit: suit, size: compact ? 17 : 22)
            } else {
                PixelText(
                    text: fallback,
                    size: compact ? .caption2 : .caption,
                    variant: .heavy,
                    color: fallback == "Famine" ? Color.kolkhozRedBright : Color.kolkhozSmoke
                )
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .frame(height: GameInfoBarLayout.height)
    }
}

struct InfoJobGauge: View {
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let highlighted: Bool
    let compact: Bool
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        let gaugeWidth: CGFloat = compact ? GameInfoBarLayout.gaugeWidthCompact : GameInfoBarLayout.gaugeWidthRegular
        let gaugeHeight: CGFloat = compact ? GameInfoBarLayout.gaugeHeightCompact : GameInfoBarLayout.gaugeHeightRegular
        HStack(spacing: 0) {
            if highlighted {
                GameIcon(trumpIcon, size: compact ? 34 : 32)
                    .frame(width: gaugeHeight, height: gaugeHeight)
            } else {
                SuitMark(suit: suit, size: compact ? 23 : 19)
                    .frame(width: gaugeHeight, height: gaugeHeight)
            }
            if claimed {
                GameIcon(.check, size: compact ? 13 : 16)
                    .frame(width: gaugeWidth - gaugeHeight, height: gaugeHeight)
            } else {
                PixelText(
                    text: "\(hours)/40",
                    size: compact ? .caption2 : .caption,
                    variant: .heavy,
                    color: highlighted ? Color.kolkhozGold : Color.kolkhozSmoke
                )
                    .frame(width: gaugeWidth - gaugeHeight, height: gaugeHeight)
            }
        }
        .frame(width: gaugeWidth, height: gaugeHeight)
        .background {
            GeneratedChromeImage(resourceName: "ui-header-counter")
                .allowsHitTesting(false)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        let frame = proxy.frame(in: .named(GameBoardCoordinateSpace.main))
                        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
                    }
                    .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, frame in
                        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
                    }
            }
        }
    }

    private var trumpIcon: GameIconAsset {
        switch suit {
        case .wheat: .trumpWheat
        case .sunflower: .trumpSunflower
        case .potato: .trumpPotato
        case .beet: .trumpBeet
        }
    }
}

#if DEBUG
#Preview("Info Bar - Regular") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 86) {
        InfoBarPreviewHost()
    }
}

#Preview("Info Bar - Compact") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 430, height: 86) {
        InfoBarPreviewHost()
    }
}

private struct InfoBarPreviewHost: View {
    @State private var jobTargets: [Suit: CGPoint] = [:]

    var body: some View {
        InfoBarView(jobTargets: $jobTargets)
            .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif

struct HeaderView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                PixelText(text: language.text(en: "KOLKHOZ", ru: "КОЛХОЗ"), size: .title, variant: .heavy, color: .kolkhozGold)
                PixelText(text: language.text(en: "FIVE YEAR PLAN", ru: "ПЯТИЛЕТКА"), size: .caption2, color: .kolkhozCreamDim)
            }
            .frame(minWidth: 86, alignment: .leading)

            Spacer()

            StatusPill(title: language.text(en: "Year", ru: "Год"), value: "\(store.state.year)/5")
            StatusPill(title: language.text(en: "Phase", ru: "Фаза"), value: language.phaseName(store.state.phase))
            StatusPill(title: language.text(en: "Task", ru: "Задача"), value: store.state.isFamine ? language.text(en: "Famine", ru: "Неурожай") : (store.state.trump.map { language.suitName($0) } ?? language.text(en: "Unset", ru: "Не выбрано")))

            Button {
                store.newGame()
            } label: {
                GameIcon(.gears, size: 24)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.kolkhozGold)
            .background(Color.kolkhozBlack.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.kolkhozGold.opacity(0.65), lineWidth: 1)
            }
            .accessibilityLabel(language.text(en: "New game", ru: "Новая игра"))
        }
        .padding(8)
        .background(CommandPanelBackground())
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozGold, lineWidth: 2)
        }
    }
}

struct StatusPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            PixelText(text: title.uppercased(), size: .caption2, color: .kolkhozSmoke)
            PixelText(text: value, size: .caption, variant: .heavy, color: .kolkhozGold)
                .shadow(color: .kolkhozGold.opacity(0.45), radius: 5)
        }
        .frame(width: 72, height: 42)
        .background(Color.kolkhozBlack.opacity(0.72), in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.kolkhozSteel.opacity(0.7), lineWidth: 1)
        }
    }
}
