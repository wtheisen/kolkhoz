import KolkhozCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum CardSize {
    case small
    case medium
    case large

    var width: CGFloat {
        switch self {
        case .small: 42
        case .medium: 58
        case .large: 70
        }
    }

    var height: CGFloat { width * 1.42 }

    var faceInset: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large: 7
        }
    }

    var cornerWidth: CGFloat {
        switch self {
        case .small: 15
        case .medium: 19
        case .large: 24
        }
    }

    var cornerHeight: CGFloat {
        switch self {
        case .small: 10
        case .medium: 13
        case .large: 16
        }
    }

    var cornerRankFontSize: CGFloat {
        switch self {
        case .small: 8
        case .medium: 10.5
        case .large: 13.5
        }
    }

    var cornerSuitSize: CGFloat {
        switch self {
        case .small: 4
        case .medium: 5
        case .large: 6
        }
    }
}

enum CardTone {
    case light
    case dark
}

struct CardView: View {
    @Environment(\.colorScheme) var colorScheme

    let card: Card
    let size: CardSize
    var toneOverride: CardTone?

    var tone: CardTone {
        toneOverride ?? (colorScheme == .dark ? .dark : .light)
    }

    var body: some View {
        ZStack {
            CardTemplateBackground(tone: tone)
                .frame(width: size.width, height: size.height)

            CardFaceView(card: card, size: size, tone: tone)
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.cardStroke, lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.38), radius: 5, y: 3)
    }

}

struct CardFaceView: View {
    let card: Card
    let size: CardSize
    let tone: CardTone

    var body: some View {
        ZStack {
            if size == .small {
                CompactCardCenter(card: card, tone: tone)
            } else if card.value >= 11 {
                FaceCardCenter(card: card, size: size, tone: tone)
            } else {
                PipPattern(card: card, size: size)
                    .padding(.horizontal, size.width * 0.17)
                    .padding(.vertical, size.height * 0.18)
            }

            CardCornerIndex(card: card, tone: tone, size: size, placement: .top)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: -size.width * 0.02, y: size.height * 0.01)

            CardCornerIndex(card: card, tone: tone, size: size, placement: .bottom)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: size.width * 0.035, y: -size.height * 0.02)
        }
        .padding(size.faceInset)
    }
}

enum CardCornerPlacement {
    case top
    case bottom
}

struct CardCornerIndex: View {
    let card: Card
    let tone: CardTone
    let size: CardSize
    let placement: CardCornerPlacement

    var body: some View {
        HStack(spacing: 1) {
            rankText
            suitMark
        }
        .frame(width: size.cornerWidth, height: size.cornerHeight)
        .clipped()
    }

    var rankText: some View {
        Text(card.rank)
            .font(rankFont)
            .monospacedDigit()
            .foregroundStyle(rankColor)
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .allowsTightening(true)
            .frame(maxWidth: .infinity, maxHeight: size.cornerHeight)
    }

    var suitMark: some View {
        SuitMark(suit: card.suit, size: size.cornerSuitSize)
            .frame(width: size.cornerSuitSize, height: size.cornerSuitSize)
    }

    var rankFont: Font {
        .kolkhozDisplay(size: card.rank.count > 1 ? size.cornerRankFontSize * 0.82 : size.cornerRankFontSize)
    }

    var rankColor: Color {
        tone == .dark ? Color.kolkhozCream : card.suit.cardInkColor
    }
}

struct CompactCardCenter: View {
    let card: Card
    let tone: CardTone

    var body: some View {
        VStack(spacing: 2) {
            SuitMark(suit: card.suit, size: 14)
            Text(card.rank)
                .font(.kolkhozTitle(.caption2))
                .monospacedDigit()
                .foregroundStyle(tone == .dark ? Color.kolkhozCream : card.suit.cardInkColor)
        }
    }
}

struct FaceCardCenter: View {
    let card: Card
    let size: CardSize
    let tone: CardTone

    var body: some View {
        FaceCardArt(card: card)
            .frame(width: artSide, height: artSide)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(alignment: .bottomTrailing) {
                SuitMark(suit: card.suit, size: max(10, size.width * 0.20))
                    .padding(3)
                    .background(
                        Circle()
                            .fill(tone == .dark ? Color.kolkhozBlack.opacity(0.72) : Color.cardFill.opacity(0.82))
                    )
                    .padding(3)
            }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(tone == .dark ? Color.kolkhozGold.opacity(0.44) : card.suit.cardInkColor.opacity(0.32), lineWidth: 1)
        }
    }

    var artSide: CGFloat {
        switch size {
        case .small: 24
        case .medium: size.width * 0.66
        case .large: size.width * 0.68
        }
    }
}

struct FaceCardArt: View {
    let card: Card

    var body: some View {
        if let image {
            image
                .resizable()
                .interpolation(.none)
            .antialiased(false)
                .scaledToFill()
        } else {
            SuitMark(suit: card.suit, size: 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.kolkhozPanel)
        }
    }

    var image: Image? {
        let bundle = Bundle.kolkhozAppFeatureResources
        for resourceName in faceResourceNames {
            let url = bundle.url(forResource: resourceName, withExtension: "png")
                ?? bundle.url(forResource: resourceName, withExtension: "png", subdirectory: "Cards")

            guard let url else {
                continue
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
        }

        return nil
    }

    var faceResourceNames: [String] {
        let rankName: String
        switch card.value {
        case 11:
            rankName = "jack"
        case 12:
            rankName = "queen"
        case 13:
            rankName = "king"
        default:
            rankName = "jack"
        }

        let suitName: String
        switch card.suit {
        case .wheat:
            suitName = "wheat"
        case .sunflower:
            suitName = "sunflower"
        case .potato:
            suitName = "potato"
        case .beet:
            suitName = "beet"
        }

        return ["face-\(rankName)-\(suitName)", "face-\(rankName)"]
    }
}

struct PipPattern: View {
    let card: Card
    let size: CardSize

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(Array(pipPositions.enumerated()), id: \.offset) { _, point in
                    SuitMark(suit: card.suit, size: pipSize)
                        .frame(width: pipSize, height: pipSize)
                        .rotationEffect(point.y > 0.5 ? .degrees(180) : .zero)
                        .position(
                            x: proxy.size.width * point.x,
                            y: proxy.size.height * point.y
                        )
                }
            }
        }
    }

    var pipSize: CGFloat {
        switch size {
        case .small: 10
        case .medium: 13
        case .large: 16
        }
    }

    var pipPositions: [CGPoint] {
        switch min(max(card.value, 1), 10) {
        case 1:
            return [CGPoint(x: 0.5, y: 0.5)]
        case 2:
            return [CGPoint(x: 0.5, y: 0.25), CGPoint(x: 0.5, y: 0.75)]
        case 3:
            return [CGPoint(x: 0.5, y: 0.22), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.78)]
        case 4:
            return [
                CGPoint(x: 0.32, y: 0.25), CGPoint(x: 0.68, y: 0.25),
                CGPoint(x: 0.32, y: 0.75), CGPoint(x: 0.68, y: 0.75)
            ]
        case 5:
            return [
                CGPoint(x: 0.32, y: 0.23), CGPoint(x: 0.68, y: 0.23),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.32, y: 0.77), CGPoint(x: 0.68, y: 0.77)
            ]
        case 6:
            return [
                CGPoint(x: 0.32, y: 0.20), CGPoint(x: 0.68, y: 0.20),
                CGPoint(x: 0.32, y: 0.50), CGPoint(x: 0.68, y: 0.50),
                CGPoint(x: 0.32, y: 0.80), CGPoint(x: 0.68, y: 0.80)
            ]
        case 7:
            return [
                CGPoint(x: 0.32, y: 0.18), CGPoint(x: 0.68, y: 0.18),
                CGPoint(x: 0.5, y: 0.34),
                CGPoint(x: 0.32, y: 0.50), CGPoint(x: 0.68, y: 0.50),
                CGPoint(x: 0.32, y: 0.82), CGPoint(x: 0.68, y: 0.82)
            ]
        case 8:
            return [
                CGPoint(x: 0.32, y: 0.17), CGPoint(x: 0.68, y: 0.17),
                CGPoint(x: 0.5, y: 0.32),
                CGPoint(x: 0.32, y: 0.47), CGPoint(x: 0.68, y: 0.47),
                CGPoint(x: 0.5, y: 0.63),
                CGPoint(x: 0.32, y: 0.83), CGPoint(x: 0.68, y: 0.83)
            ]
        case 9:
            return [
                CGPoint(x: 0.32, y: 0.16), CGPoint(x: 0.68, y: 0.16),
                CGPoint(x: 0.32, y: 0.38), CGPoint(x: 0.68, y: 0.38),
                CGPoint(x: 0.5, y: 0.50),
                CGPoint(x: 0.32, y: 0.62), CGPoint(x: 0.68, y: 0.62),
                CGPoint(x: 0.32, y: 0.84), CGPoint(x: 0.68, y: 0.84)
            ]
        default:
            return [
                CGPoint(x: 0.32, y: 0.14), CGPoint(x: 0.68, y: 0.14),
                CGPoint(x: 0.5, y: 0.28),
                CGPoint(x: 0.32, y: 0.40), CGPoint(x: 0.68, y: 0.40),
                CGPoint(x: 0.32, y: 0.60), CGPoint(x: 0.68, y: 0.60),
                CGPoint(x: 0.5, y: 0.72),
                CGPoint(x: 0.32, y: 0.86), CGPoint(x: 0.68, y: 0.86)
            ]
        }
    }
}

struct CardTemplateBackground: View {
    let tone: CardTone

    var body: some View {
        template
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var template: some View {
        if let image {
            image
                .resizable()
                .interpolation(.none)
            .antialiased(false)
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.cardFill)
        }
    }

    var image: Image? {
        let bundle = Bundle.kolkhozAppFeatureResources
        let resourceName = tone == .dark ? "card-template-dark" : "card-template-light"
        let url = bundle.url(forResource: resourceName, withExtension: "png")
            ?? bundle.url(forResource: resourceName, withExtension: "png", subdirectory: "Cards")
            ?? bundle.url(forResource: "card-template-front", withExtension: "png")
            ?? bundle.url(forResource: "card-template-front", withExtension: "png", subdirectory: "Cards")

        guard let url else {
            return nil
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

        return nil
    }
}

struct CardBackView: View {
    let size: CardSize

    var body: some View {
        cardBackImage
            .frame(width: size.width, height: size.height)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.cardStroke, lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.38), radius: 5, y: 3)
            .accessibilityHidden(true)
    }
}

struct CardBackThumbnail: View {
    var body: some View {
        cardBackIconImage
            .frame(width: 10, height: 15)
            .clipShape(RoundedRectangle(cornerRadius: 2))
            .overlay {
                RoundedRectangle(cornerRadius: 2)
                    .stroke(Color.kolkhozGold.opacity(0.62), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }
}

@ViewBuilder
var cardBackIconImage: some View {
    if let image = cardBackIconResourceImage {
        image
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 2))
    } else {
        cardBackImage
    }
}

@ViewBuilder
var cardBackImage: some View {
    if let image = cardBackResourceImage {
        image
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFill()
            .clipShape(RoundedRectangle(cornerRadius: 8))
    } else {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.kolkhozIron)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.kolkhozGold, lineWidth: 1)
            }
    }
}

var cardBackIconResourceImage: Image? {
    loadCardBackResourceImage(named: "card-back-icon")
}

var cardBackResourceImage: Image? {
    loadCardBackResourceImage(named: "card-back")
}

private func loadCardBackResourceImage(named resourceName: String) -> Image? {
    let bundle = Bundle.kolkhozAppFeatureResources
    let url = bundle.url(forResource: resourceName, withExtension: "png")
        ?? bundle.url(forResource: resourceName, withExtension: "png", subdirectory: "Cards")

    guard let url else {
        return nil
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

    return nil
}

struct SuitBadge: View {
    let suit: Suit
    let compact: Bool

    var body: some View {
        HStack(spacing: 5) {
            SuitMark(suit: suit, size: compact ? 18 : 22)
            Text(compact ? suit.shortName : suit.rawValue)
                .font(compact ? .kolkhozTitle(.caption) : .kolkhozLabel(.caption))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(Color.kolkhozCream)
    }
}

struct SuitMark: View {
    let suit: Suit
    let size: CGFloat

    var body: some View {
        GameIcon(suit.iconAsset, size: size)
            .frame(width: size, height: size)
            .shadow(color: suit.displayColor.opacity(size > 17 ? 0.34 : 0), radius: size > 17 ? 3 : 0)
    }
}
