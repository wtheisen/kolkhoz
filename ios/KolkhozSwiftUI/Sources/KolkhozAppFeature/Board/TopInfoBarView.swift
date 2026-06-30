import KolkhozCore
import SwiftUI

struct TopInfoBarView: View {
    @EnvironmentObject var store: GameStore
    @Binding var jobTargets: [Suit: CGPoint]
    var displayedWorkHours: [Suit: Int]? = nil
    var displayedClaimedJobs: Set<Suit>? = nil

    var body: some View {
        GeometryReader { proxy in
            let localPlayer = store.state.players[store.localPlayerID]
            let cellarScore = localPlayer.plot.hidden.reduce(0) { $0 + $1.value }
            let plotScore = localPlayer.plot.revealed.reduce(0) { $0 + $1.value }
            let rowSpacing = kolkhozClamp(proxy.size.width * 0.008, 3, 6)
            let yearWidth = kolkhozClamp(proxy.size.width * 0.2, 64, 72)
            let gaugeWidth = kolkhozClamp(proxy.size.width * 0.15, 86, 92)
            let gaugeHeight = kolkhozClamp(proxy.size.height * 0.9, 34, 38)
            let gaugeSpacing = kolkhozClamp(proxy.size.width * 0.006, 3, 6)
            let gaugeFrameWidth = gaugeWidth * 1.2
            let gaugesWidth = gaugeFrameWidth * CGFloat(Suit.allCases.count) + gaugeSpacing * CGFloat(Suit.allCases.count - 1)
            let gaugeClusterLeftOffset = -kolkhozClamp(proxy.size.width * 0.045, 34, 48)
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
                            hours: workHours[suit, default: 0],
                            claimed: claimedJobs.contains(suit),
                            reward: store.state.revealedJobs[suit],
                            highlighted: store.state.trump == suit,
                            width: gaugeWidth * 1.1,
                            height: gaugeHeight,
                            jobTargets: $jobTargets
                        )
                        .frame(width: gaugeFrameWidth)
                    }
                }
                .frame(width: gaugesWidth, alignment: .leading)
                .offset(x: gaugeClusterLeftOffset)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .center)
            .clipped()
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

    private var workHours: [Suit: Int] {
        displayedWorkHours ?? store.state.workHours
    }

    private var claimedJobs: Set<Suit> {
        displayedClaimedJobs ?? store.state.claimedJobs
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
    let reward: Card?
    let highlighted: Bool
    let width: CGFloat
    let height: CGFloat
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        HStack(spacing: 4) {
            rewardMarker
                .frame(width: height * 0.72, height: height)

            if claimed {
                GameIcon(.check, size: height * 0.4)
                    .frame(width: width - height * 0.72 - 4, height: height)
            } else {
                PixelText(
                    text: "\(hours)/40",
                    size: .title,
                    variant: .regular,
                    color: highlighted ? Color.kolkhozRed : Color.kolkhozSmoke
                )
                    .frame(width: width - height * 0.72 - 4, height: height)
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

    @ViewBuilder
    private var rewardMarker: some View {
        if let reward {
            MiniRewardCard(card: reward, claimed: claimed)
                .scaleEffect(0.84)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(Color.kolkhozGreen.opacity(0.7), lineWidth: 1)
                .frame(width: 24, height: 34)
                .overlay {
                    GameIcon(.check, size: 17)
                }
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
