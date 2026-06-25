import KolkhozCore
import SwiftUI

struct NorthView: View {
    @Environment(\.kolkhozLanguage) private var language
    let exiledByYear: [Int: [Card]]
    let currentYear: Int

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(1...5, id: \.self) { year in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        GameIcon(yearIcon(for: year), size: 32)
                        Spacer()
                        PixelText(text: "\(exiledByYear[year, default: []].count)", size: .cardRank, variant: .heavy, color: .kolkhozCreamDim)
                    }
                    ScrollView {
                        VStack(spacing: -58) {
                            ForEach(exiledByYear[year, default: []]) { card in
                                CardView(card: card, size: .medium)
                            }
                            if exiledByYear[year, default: []].isEmpty {
                                VStack(spacing: 32) {
                                    Spacer()
                                    BadgeSealOrnament()
                                        .frame(width: 64, height: 64)
                                        .opacity(year == currentYear ? 0.86 : 0.5)
                                    PixelText(text: "-", size: .cardRank, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
                                }
                                .frame(maxWidth: .infinity, minHeight: 80)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.bottom, 38)
                    }
                }
                .padding(.top, 3)
                .padding(.leading, 3)
                .padding(.trailing, 8)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.kolkhozBlack.opacity(year == currentYear ? 0.38 : 0.24), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(year == currentYear ? Color.kolkhozRedBright : Color.kolkhozSteel.opacity(0.6), lineWidth: year == currentYear ? 2 : 1)
                }
            }
        }
        .padding(12)
        .background(CommandPanelBackground())
    }

    private func yearIcon(for year: Int) -> GameIconAsset {
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
