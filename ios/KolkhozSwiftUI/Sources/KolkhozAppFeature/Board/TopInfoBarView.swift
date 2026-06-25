import KolkhozCore
import SwiftUI

enum TopInfoBarLayout {
    static let height: CGFloat = 48
    static let minRowSpacing: CGFloat = 3
    static let maxRowSpacing: CGFloat = 6
    static let minYearWidth: CGFloat = 46
    static let maxYearWidth: CGFloat = 62
    static let minLeadWidth: CGFloat = 50
    static let maxLeadWidth: CGFloat = 76
    static let minGaugeWidth: CGFloat = 72
    static let maxGaugeWidth: CGFloat = 86
    static let minGaugeHeight: CGFloat = 34
    static let maxGaugeHeight: CGFloat = 38
    static let minGaugeSpacing: CGFloat = 3
    static let maxGaugeSpacing: CGFloat = 6
    static let minScoreWidth: CGFloat = 54
    static let maxScoreWidth: CGFloat = 70
}

struct TopInfoBarView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        GeometryReader { proxy in
            let cellarScore = store.state.players[0].plot.hidden.reduce(0) { $0 + $1.value }
            let plotScore = store.state.players[0].plot.revealed.reduce(0) { $0 + $1.value }
            let rowSpacing = kolkhozClamp(proxy.size.width * 0.008, TopInfoBarLayout.minRowSpacing, TopInfoBarLayout.maxRowSpacing)
            let yearWidth = kolkhozClamp(proxy.size.width * 0.08, TopInfoBarLayout.minYearWidth, TopInfoBarLayout.maxYearWidth)
            let leadWidth = kolkhozClamp(proxy.size.width * 0.10, TopInfoBarLayout.minLeadWidth, TopInfoBarLayout.maxLeadWidth)
            let gaugeWidth = kolkhozClamp(proxy.size.width * 0.12, TopInfoBarLayout.minGaugeWidth, TopInfoBarLayout.maxGaugeWidth)
            let gaugeHeight = kolkhozClamp(proxy.size.height * 0.78, TopInfoBarLayout.minGaugeHeight, TopInfoBarLayout.maxGaugeHeight)
            let gaugeSpacing = kolkhozClamp(proxy.size.width * 0.006, TopInfoBarLayout.minGaugeSpacing, TopInfoBarLayout.maxGaugeSpacing)
            let gaugesWidth = gaugeWidth * CGFloat(Suit.allCases.count) + gaugeSpacing * CGFloat(Suit.allCases.count - 1)
            let scoreWidth = kolkhozClamp(proxy.size.width * 0.09, TopInfoBarLayout.minScoreWidth, TopInfoBarLayout.maxScoreWidth)
            let preferredRowWidth = yearWidth + leadWidth + gaugesWidth + scoreWidth * 2 + rowSpacing * 4
            let rowWidth = min(proxy.size.width, preferredRowWidth)

            HStack(spacing: rowSpacing) {
                TopInfoCell(icon: yearIcon, value: "\(store.state.year)", iconSize: gaugeHeight, contentSpacing: rowSpacing)
                    .frame(width: yearWidth)

                if let lead = store.state.currentTrick.first?.card.suit {
                    TopInfoCell(suit: lead, value: language.text(en: "Lead", ru: "Ведёт"), suitSize: gaugeHeight * 0.58, contentSpacing: rowSpacing)
                        .frame(width: leadWidth)
                }

                HStack(spacing: gaugeSpacing) {
                    ForEach(Suit.allCases) { suit in
                        TopInfoJobGauge(
                            suit: suit,
                            hours: store.state.workHours[suit, default: 0],
                            claimed: store.state.claimedJobs.contains(suit),
                            highlighted: store.state.trump == suit,
                            width: gaugeWidth,
                            height: gaugeHeight,
                            jobTargets: $jobTargets
                        )
                        .frame(width: gaugeWidth)
                    }
                }
                .frame(width: gaugesWidth)

                TopInfoCell(
                    icon: .cellar,
                    value: "\(cellarScore)",
                    warning: true,
                    iconSize: gaugeHeight * 0.66,
                    contentSpacing: rowSpacing
                )
                .frame(width: scoreWidth)
                TopInfoCell(
                    icon: .plot,
                    value: "\(plotScore)",
                    iconSize: gaugeHeight * 0.66,
                    contentSpacing: rowSpacing
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
    var label: String = ""
    var icon: GameIconAsset? = nil
    var suit: Suit? = nil
    var value: String? = nil
    var warning = false
    var iconSize: CGFloat? = nil
    var suitSize: CGFloat? = nil
    var contentSpacing: CGFloat = 5
    var horizontalPadding: CGFloat = 6

    var body: some View {
        HStack(spacing: contentSpacing) {
            if let icon {
                GameIcon(icon, size: iconSize ?? 24)
            }
            if !label.isEmpty {
                PixelText(text: label.uppercased(), size: .caption2, color: warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
            if let suit {
                SuitMark(suit: suit, size: suitSize ?? 22)
            }
            if let value {
                PixelText(
                    text: value,
                    size: .caption,
                    variant: .heavy,
                    color: .kolkhozGold
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: TopInfoBarLayout.height)
        .background(warning ? Color.kolkhozRedDark.opacity(0.18) : Color.clear)
    }
}

struct TopInfoJobGauge: View {
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let highlighted: Bool
    let width: CGFloat
    let height: CGFloat
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        HStack(spacing: 0) {
            if highlighted {
                GameIcon(trumpIcon, size: height * 0.72)
                    .frame(width: height, height: height)
            } else {
                SuitMark(suit: suit, size: height * 0.58)
                    .frame(width: height, height: height)
            }
            if claimed {
                GameIcon(.check, size: height * 0.4)
                    .frame(width: width - height, height: height)
            } else {
                PixelText(
                    text: "\(hours)/40",
                    size: .caption,
                    variant: .heavy,
                    color: highlighted ? Color.kolkhozGold : Color.kolkhozSmoke
                )
                    .frame(width: width - height, height: height)
            }
        }
        .frame(width: width, height: height)
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
#Preview("Info Bar - Wide") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 86) {
        TopInfoBarPreviewHost()
    }
}

#Preview("Info Bar - Narrow") {
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
