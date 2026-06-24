import KolkhozCore
import SwiftUI

enum TopInfoBarLayout {
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

struct TopInfoBarView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < TopInfoBarLayout.compactWidth
            let micro = proxy.size.width < TopInfoBarLayout.microWidth
            let cellarScore = store.state.players[0].plot.hidden.reduce(0) { $0 + $1.value }
            let plotScore = store.state.players[0].plot.revealed.reduce(0) { $0 + $1.value }
            let rowSpacing: CGFloat = micro ? TopInfoBarLayout.rowSpacingMicro : (compact ? TopInfoBarLayout.rowSpacingCompact : TopInfoBarLayout.rowSpacingRegular)
            let yearWidth: CGFloat = micro ? TopInfoBarLayout.yearWidthMicro : (compact ? TopInfoBarLayout.yearWidthCompact : TopInfoBarLayout.yearWidthRegular)
            let leadWidth: CGFloat = store.state.currentTrick.first?.card.suit != nil && !compact ? TopInfoBarLayout.leadWidth : 0
            let gaugeWidth: CGFloat = compact ? TopInfoBarLayout.gaugeWidthCompact : TopInfoBarLayout.gaugeWidthRegular
            let gaugeSpacing: CGFloat = compact ? TopInfoBarLayout.gaugeSpacingCompact : TopInfoBarLayout.gaugeSpacingRegular
            let gaugesWidth = gaugeWidth * CGFloat(Suit.allCases.count) + gaugeSpacing * CGFloat(Suit.allCases.count - 1)
            let scoreWidth: CGFloat = micro ? TopInfoBarLayout.scoreWidthMicro : (compact ? TopInfoBarLayout.scoreWidthCompact : TopInfoBarLayout.scoreWidthRegular)
            let visibleCellCount = leadWidth > 0 ? 5 : 4
            let preferredRowWidth = yearWidth + leadWidth + gaugesWidth + scoreWidth * 2 + rowSpacing * CGFloat(visibleCellCount - 1)
            let rowWidth = min(proxy.size.width, preferredRowWidth)

            HStack(spacing: rowSpacing) {
                TopInfoCell(label: compact ? "" : language.text(en: "Year", ru: "Год"), icon: compact ? yearIcon : nil, value: compact ? nil : "\(store.state.year)/5", compact: compact, iconSize: compact ? 42 : nil)
                    .frame(width: yearWidth)

                if let lead = store.state.currentTrick.first?.card.suit, !compact {
                    TopInfoCell(label: language.text(en: "Lead", ru: "Ведёт"), suit: lead, compact: compact)
                        .frame(width: leadWidth)
                }

                HStack(spacing: gaugeSpacing) {
                    ForEach(Suit.allCases) { suit in
                        TopInfoJobGauge(
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

                TopInfoCell(
                    label: compact ? "" : language.text(en: "Cellar", ru: "Подвал"),
                    icon: .cellar,
                    value: "\(cellarScore)",
                    warning: true,
                    compact: compact
                )
                .frame(width: scoreWidth)
                TopInfoCell(
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
        .frame(height: TopInfoBarLayout.height)
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

struct TopInfoCell: View {
    let label: String
    var icon: GameIconAsset? = nil
    var suit: Suit? = nil
    var value: String? = nil
    var warning = false
    var compact = false
    var iconSize: CGFloat? = nil

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            if let icon {
                GameIcon(icon, size: iconSize ?? (compact ? 26 : 20))
            }
            if !label.isEmpty {
                PixelText(text: label.uppercased(), size: .caption2, color: warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
            if let suit {
                SuitMark(suit: suit, size: compact ? 17 : 22)
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
        .frame(height: TopInfoBarLayout.height)
        .background(warning ? Color.kolkhozRedDark.opacity(0.18) : Color.clear)
    }
}

struct TopInfoJobGauge: View {
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let highlighted: Bool
    let compact: Bool
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        let gaugeWidth: CGFloat = compact ? TopInfoBarLayout.gaugeWidthCompact : TopInfoBarLayout.gaugeWidthRegular
        let gaugeHeight: CGFloat = compact ? TopInfoBarLayout.gaugeHeightCompact : TopInfoBarLayout.gaugeHeightRegular
        HStack(spacing: 0) {
            if highlighted {
                GameIcon(trumpIcon, size: compact ? 22 : 32)
                    .frame(width: gaugeHeight, height: gaugeHeight)
            } else {
                SuitMark(suit: suit, size: compact ? 22 : 19)
                    .frame(width: gaugeHeight, height: gaugeHeight)
            }
            if claimed {
                GameIcon(.check, size: compact ? 13 : 16)
                    .frame(width: gaugeWidth - gaugeHeight, height: gaugeHeight)
            } else {
                PixelText(
                    text: "\(hours)/40",
                    size: compact ? .caption : .caption,
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
        TopInfoBarPreviewHost()
    }
}

#Preview("Info Bar - Compact") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 430, height: 86) {
        TopInfoBarPreviewHost()
    }
}

private struct TopInfoBarPreviewHost: View {
    @State private var jobTargets: [Suit: CGPoint] = [:]

    var body: some View {
        TopInfoBarView(jobTargets: $jobTargets)
            .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
