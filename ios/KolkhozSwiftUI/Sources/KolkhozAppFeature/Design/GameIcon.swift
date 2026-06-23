import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum GameIconAsset: String {
    case menu = "icon-menu"
    case brigade = "icon-brigade"
    case jobs = "icon-jobs"
    case north = "icon-north"
    case plot = "icon-plot"
    case language = "icon-language"
    case medalStar = "icon-medal-star"
    case check = "icon-check"
    case warning = "icon-warning"
    case playTap = "icon-play-tap"
    case gears = "icon-gears"
    case wheat = "icon-wheat"
    case sunflower = "icon-sunflower"
    case potato = "icon-potato"
    case beet = "icon-beet"
    case cellar = "icon-cellar"
}

struct GameIcon: View {
    let asset: GameIconAsset
    let size: CGFloat
    var muted = false

    init(_ asset: GameIconAsset, size: CGFloat, muted: Bool = false) {
        self.asset = asset
        self.size = size
        self.muted = muted
    }

    var body: some View {
        image
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(muted ? 0.7 : 1)
            .opacity(muted ? 0.82 : 1)
            .accessibilityHidden(true)
    }

    private var image: Image {
        let bundle = Bundle.kolkhozAppFeatureResources
        let url = bundle.url(forResource: asset.rawValue, withExtension: "png")
            ?? bundle.url(forResource: asset.rawValue, withExtension: "png", subdirectory: "Icons")

        guard let url else {
            return Image(systemName: "square.fill")
        }

        #if canImport(UIKit)
        if let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
        #elseif canImport(AppKit)
        if let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        #endif

        return Image(systemName: "square.fill")
    }
}
