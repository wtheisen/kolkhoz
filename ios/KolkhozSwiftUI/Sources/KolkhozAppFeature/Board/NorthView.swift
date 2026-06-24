import KolkhozCore
import SwiftUI

struct NorthView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(1...5, id: \.self) { year in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        GameIcon(.year1, size: 32)
                        Spacer()
                        PixelText(text: "\(store.state.exiled[year, default: []].count)", size: .cardRank, variant: .heavy, color: .kolkhozCreamDim)
                    }
                    ScrollView {
                        VStack(spacing: -58) {
                            ForEach(store.state.exiled[year, default: []]) { card in
                                CardView(card: card, size: .medium)
                            }
                            if store.state.exiled[year, default: []].isEmpty {
                                VStack(spacing: 32) {
                                    Spacer()
                                    BadgeSealOrnament()
                                        .frame(width: 64, height: 64)
                                        .opacity(year == store.state.year ? 0.86 : 0.5)
                                    PixelText(text: "-", size: .cardRank, variant: .heavy, color: Color.kolkhozSmoke.opacity(0.72))
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
#Preview("North History") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 760, height: 300) {
        NorthView()
    }
}
#endif
