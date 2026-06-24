#if DEBUG
import KolkhozCore
import SwiftUI

struct BoardPreviewStage<Content: View>: View {
    let width: CGFloat?
    let height: CGFloat?
    @ViewBuilder var content: Content

    init(
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.height = height
        self.content = content()
        KolkhozFontRegistry.registerFonts()
    }

    var body: some View {
        content
            .font(.kolkhozLabel(.body))
            .frame(width: width, height: height)
            .padding(18)
            .background(Color.kolkhozBackground)
    }
}

struct BoardPreviewStoreStage<Content: View>: View {
    let width: CGFloat?
    let height: CGFloat?
    @StateObject private var store: GameStore
    @ViewBuilder var content: Content

    init(
        state: KolkhozState,
        width: CGFloat? = nil,
        height: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.height = height
        _store = StateObject(wrappedValue: GameStore(previewState: state))
        self.content = content()
        KolkhozFontRegistry.registerFonts()
    }

    var body: some View {
        content
            .font(.kolkhozLabel(.body))
            .environmentObject(store)
            .frame(width: width, height: height)
            .padding(18)
            .background(Color.kolkhozBackground)
    }
}
#endif
