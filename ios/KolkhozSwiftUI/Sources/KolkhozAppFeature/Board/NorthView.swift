import KolkhozCore
import SwiftUI

struct NorthView: View {
    let exiledByYear: [Int: [Card]]
    let currentYear: Int
    var tutorialAction: TutorialRequiredAction = .none
    var onTutorialAction: (TutorialRequiredAction) -> Void = { _ in }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = 10
            let columnHeight = max(120, proxy.size.height - 24)
            let headerHeight: CGFloat = 34
            let cardScrollHeight = max(70, columnHeight - headerHeight - 16)

            HStack(alignment: .top, spacing: spacing) {
                ForEach(1...5, id: \.self) { year in
                    NorthYearColumn(
                        year: year,
                        cards: exiledByYear[year, default: []],
                        currentYear: currentYear,
                        headerHeight: headerHeight,
                        cardScrollHeight: cardScrollHeight,
                        columnHeight: columnHeight
                    )
                }
            }
            .padding(12)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
            .background {
                ZStack(alignment: .bottomTrailing) {
                    CommandPanelBackground()
                    ResourceArtImage(resourceName: "art-north-requisition-banner")
                        .scaledToFit()
                        .frame(width: min(proxy.size.width * 0.44, 300), height: 58)
                        .opacity(0.16)
                        .padding(.trailing, 14)
                        .padding(.bottom, 8)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .tutorialBoardCue(active: tutorialAction == .inspectNorthReport, icon: .tutorialCueInspect, cornerRadius: 8)
            .contentShape(Rectangle())
            .onTapGesture {
                if tutorialAction == .inspectNorthReport {
                    onTutorialAction(.inspectNorthReport)
                }
            }
        }
    }
}

private struct NorthYearColumn: View {
    let year: Int
    let cards: [Card]
    let currentYear: Int
    let headerHeight: CGFloat
    let cardScrollHeight: CGFloat
    let columnHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                GameIcon(yearIcon, size: 32)
                Spacer()
                PixelText(text: "\(cards.count)", size: .cardRank, variant: .heavy, color: .kolkhozCreamDim)
            }
            .frame(height: headerHeight)

            ScrollView(.vertical, showsIndicators: cards.count > 2) {
                VStack(spacing: -58) {
                    ForEach(cards) { card in
                        CardView(card: card, size: .medium)
                    }
                    if cards.isEmpty {
                        VStack(spacing: 32) {
                            Spacer()
                            ResourceArtImage(resourceName: "art-official-crop-seal")
                                .scaledToFit()
                                .frame(width: 64, height: 64)
                                .opacity(year == currentYear ? 0.86 : 0.5)
                            PixelText(text: "-", size: .cardRank, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                        }
                        .frame(maxWidth: .infinity, minHeight: 80)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .padding(.bottom, 20)
            }
            .scrollDisabled(cards.count <= 2)
            .frame(height: cardScrollHeight, alignment: .top)
            .clipped()
        }
        .padding(.top, 3)
        .padding(.leading, 3)
        .padding(.trailing, 8)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(height: columnHeight, alignment: .top)
        .background(Color.kolkhozBlack.opacity(year == currentYear ? 0.38 : 0.24), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(year == currentYear ? Color.kolkhozRedBright : Color.kolkhozSteel.opacity(0.6), lineWidth: year == currentYear ? 2 : 1)
        }
    }

    private var yearIcon: GameIconAsset {
        switch year {
        case 1: .year1
        case 2: .year2
        case 3: .year3
        case 4: .year4
        case 5: .year5
        default: .year1
        }
    }
}

#if DEBUG
#Preview("North History") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 760, height: 300) {
        NorthPreviewHost()
    }
}

private struct NorthPreviewHost: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        NorthView(exiledByYear: store.state.exiled, currentYear: store.state.year)
    }
}
#endif
