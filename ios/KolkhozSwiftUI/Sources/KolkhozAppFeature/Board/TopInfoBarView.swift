import KolkhozCore
import SwiftUI

struct TopInfoBarView: View {
    @EnvironmentObject var store: GameStore
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        GeometryReader { proxy in
            let cellarScore = store.state.players[0].plot.hidden.reduce(0) { $0 + $1.value }
            let plotScore = store.state.players[0].plot.revealed.reduce(0) { $0 + $1.value }
            let rowSpacing = kolkhozClamp(proxy.size.width * 0.008, 3, 6)
            let yearWidth = kolkhozClamp(proxy.size.width * 0.2, 64, 72)
            let gaugeWidth = kolkhozClamp(proxy.size.width * 0.15, 86, 92)
            let gaugeHeight = kolkhozClamp(proxy.size.height * 0.9, 34, 38)
            let gaugeSpacing = kolkhozClamp(proxy.size.width * 0.006, 3, 6)
            let gaugesWidth = gaugeWidth * CGFloat(Suit.allCases.count) + gaugeSpacing * CGFloat(Suit.allCases.count - 1)
            let scoreWidth = kolkhozClamp(proxy.size.width * 0.04, 54, 70)
            let scoreGroupWidth = scoreWidth * 2 + rowSpacing

            ZStack {
                HStack(spacing: rowSpacing) {
                    TopInfoCell(icon: yearIcon, iconSize: gaugeHeight * 1.3, contentSpacing: rowSpacing)
                        .frame(width: yearWidth, alignment: .leading)

                    Spacer(minLength: 0)

                    HStack(spacing: rowSpacing) {
                        TopInfoCell(
                            icon: .cellar,
                            value: "\(cellarScore)",
                            iconSize: gaugeHeight * 0.8,
                            contentSpacing: rowSpacing
                        )
                        .frame(width: scoreWidth)
                        TopInfoCell(
                            icon: .plot,
                            value: "\(plotScore)",
                            iconSize: gaugeHeight * 0.8,
                            contentSpacing: rowSpacing
                        )
                        .frame(width: scoreWidth)
                    }
                    .frame(width: scoreGroupWidth, alignment: .trailing)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)

                HStack(spacing: gaugeSpacing) {
                    ForEach(Suit.allCases) { suit in
                        TopInfoJobGauge(
                            suit: suit,
                            hours: store.state.workHours[suit, default: 0],
                            claimed: store.state.claimedJobs.contains(suit),
                            highlighted: store.state.trump == suit,
                            width: gaugeWidth * 1.1,
                            height: gaugeHeight,
                            jobTargets: $jobTargets
                        )
                        .frame(width: gaugeWidth * 1.2)
                    }
                }
                .frame(width: gaugesWidth)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
            .background(CommandPanelBackground())
        }
        .frame(height: 48)
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
                PixelText(text: label.uppercased(), size: .title, color: warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
            if let suit {
                SuitMark(suit: suit, size: suitSize ?? 22)
            }
            if let value {
                PixelText(
                    text: value,
                    size: .cardRank,
                    variant: .heavy,
                    color: .kolkhozGold
                )
            }
        }
        .padding(.horizontal, horizontalPadding)
        .frame(height: 48)
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
                    size: .title,
                    variant: .regular,
                    color: highlighted ? Color.kolkhozRed : Color.kolkhozSmoke
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
#Preview("Info Bar") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 86) {
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
