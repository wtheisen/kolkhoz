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
        case .large: 20
        }
    }

    var cornerRankFontSize: CGFloat {
        switch self {
        case .small: 8
        case .medium: 10.5
        case .large: 24
        }
    }

    var cornerSuitSize: CGFloat {
        switch self {
        case .small: 5
        case .medium: 6
        case .large: 10
        }
    }

    var topCornerRankSuitSpacing: CGFloat {
        switch self {
        case .small: -1
        case .medium: -1
        case .large: -4
        }
    }

    var bottomCornerRankSuitSpacing: CGFloat {
        switch self {
        case .small: -1
        case .medium: -1
        case .large: 1
        }
    }

    var topCornerSuitXOffset: CGFloat {
        switch self {
        case .small: 0
        case .medium: 0
        case .large: -1
        }
    }

    var bottomCornerSuitXOffset: CGFloat {
        switch self {
        case .small: 0
        case .medium: 0
        case .large: 1
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
    var trump: Suit? = nil
    var toneOverride: CardTone?

    var tone: CardTone {
        toneOverride ?? (colorScheme == .dark ? .dark : .light)
    }

    var body: some View {
        ZStack {
            CardTemplateBackground(tone: tone)
                .frame(width: size.width, height: size.height)

            CardFaceView(card: card, size: size, tone: tone, trump: trump)
        }
        .frame(width: size.width, height: size.height)
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.cardStroke, lineWidth: 0.8)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(card.accessibilityName))
    }

}

private extension Card {
    var accessibilityName: String {
        "\(spokenRank) of \(suit.rawValue)"
    }

    var spokenRank: String {
        switch value {
        case 1: "Ace"
        case 11: "Jack"
        case 12: "Queen"
        case 13: "King"
        default: "\(value)"
        }
    }
}

struct CardFaceView: View {
    let card: Card
    let size: CardSize
    let tone: CardTone
    let trump: Suit?

    var body: some View {
        ZStack {
            if size == .small {
                CompactCardCenter(card: card, tone: tone, trump: trump)
            } else if card.value >= 11 {
                FaceCardCenter(card: card, size: size, tone: tone)
            } else {
                PipPattern(card: card, size: size)
                    .padding(.horizontal, size.width * 0.16)
                    .padding(.vertical, size.height * 0.02)
            }

            CardCornerIndex(card: card, tone: tone, size: size, placement: .top, trump: trump)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(x: size.width * 0.03, y: size.height * 0.03)

            CardCornerIndex(card: card, tone: tone, size: size, placement: .bottom, trump: trump)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: -size.width * 0.02, y: -size.height * -0.03)
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
    let trump: Suit?

    var body: some View {
        VStack(alignment: placement == .top ? .leading : .trailing, spacing: rankSuitSpacing) {
            if placement == .top {
                rankText
                suitMark
            } else {
                suitMark
                rankText
            }
        }
        .frame(width: size.cornerWidth, height: size.cornerHeight + size.cornerSuitSize + 2, alignment: placement == .top ? .topLeading : .bottomTrailing)
    }

    var rankText: some View {
        PixelText(text: card.rank, size: rankPixelSize, variant: .heavy, color: rankColor, scalesWithReadability: false)
            .frame(width: size.cornerWidth, height: size.cornerHeight, alignment: placement == .top ? .leading : .trailing)
    }

    var suitMark: some View {
        SuitMark(suit: card.suit, size: size.cornerSuitSize)
            .frame(width: size.cornerSuitSize, height: size.cornerSuitSize)
            .offset(x: suitXOffset)
    }

    var rankColor: Color {
        card.suit == trump ? Color.kolkhozRed : (tone == .dark ? Color.kolkhozCream : Color.kolkhozCardInk)
    }

    var rankSuitSpacing: CGFloat {
        switch placement {
        case .top:
            size.topCornerRankSuitSpacing
        case .bottom:
            size.bottomCornerRankSuitSpacing
        }
    }

    var suitXOffset: CGFloat {
        switch placement {
        case .top:
            size.topCornerSuitXOffset
        case .bottom:
            size.bottomCornerSuitXOffset
        }
    }

    var rankPixelSize: PixelFontSize {
        switch size {
        case .small:
            .xSmall
        case .medium:
            .caption2
        case .large:
            .headline
        }
    }
}

struct CompactCardCenter: View {
    let card: Card
    let tone: CardTone
    let trump: Suit?

    var body: some View {
        VStack(spacing: 2) {
            SuitMark(suit: card.suit, size: 14)
            PixelText(
                text: card.rank,
                size: .caption2,
                variant: .heavy,
                color: card.suit == trump ? Color.kolkhozRed : (tone == .dark ? Color.kolkhozCream : Color.kolkhozCardInk),
                scalesWithReadability: false
            )
        }
    }
}

struct FaceCardCenter: View {
    let card: Card
    let size: CardSize
    let tone: CardTone

    var body: some View {
        FaceCardArt(card: card)
            .frame(width: artWidth, height: artHeight)
            .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    var artWidth: CGFloat {
        switch size {
        case .small: 20
        case .medium: size.width * 0.45
        case .large: size.width * 0.45
        }
    }

    var artHeight: CGFloat { artWidth * 1.5 }
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
        KolkhozResourceImageCache.image(for: faceResourceNames.flatMap { resourceName in
            [
                KolkhozResourceImageCandidate(resourceName),
                KolkhozResourceImageCandidate(resourceName, subdirectory: "Cards")
            ]
        })
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
        case .small: 8
        case .medium: 10.4
        case .large: 14
        }
    }

    var pipPositions: [CGPoint] {
        switch min(max(card.value, 1), 10) {
        case 1:
            return [CGPoint(x: 0.5, y: 0.5)]
        case 2:
            return [CGPoint(x: 0.5, y: 0.20), CGPoint(x: 0.5, y: 0.80)]
        case 3:
            return [CGPoint(x: 0.5, y: 0.18), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0.5, y: 0.82)]
        case 4:
            return [
                CGPoint(x: 0.25, y: 0.22), CGPoint(x: 0.75, y: 0.22),
                CGPoint(x: 0.25, y: 0.78), CGPoint(x: 0.75, y: 0.78)
            ]
        case 5:
            return [
                CGPoint(x: 0.25, y: 0.20), CGPoint(x: 0.75, y: 0.20),
                CGPoint(x: 0.5, y: 0.5),
                CGPoint(x: 0.25, y: 0.80), CGPoint(x: 0.75, y: 0.80)
            ]
        case 6:
            return [
                CGPoint(x: 0.25, y: 0.17), CGPoint(x: 0.75, y: 0.17),
                CGPoint(x: 0.25, y: 0.50), CGPoint(x: 0.75, y: 0.50),
                CGPoint(x: 0.25, y: 0.83), CGPoint(x: 0.75, y: 0.83)
            ]
        case 7:
            return [
                CGPoint(x: 0.25, y: 0.15), CGPoint(x: 0.75, y: 0.15),
                CGPoint(x: 0.5, y: 0.31),
                CGPoint(x: 0.25, y: 0.50), CGPoint(x: 0.75, y: 0.50),
                CGPoint(x: 0.25, y: 0.85), CGPoint(x: 0.75, y: 0.85)
            ]
        case 8:
            return [
                CGPoint(x: 0.25, y: 0.14), CGPoint(x: 0.75, y: 0.14),
                CGPoint(x: 0.5, y: 0.30),
                CGPoint(x: 0.25, y: 0.46), CGPoint(x: 0.75, y: 0.46),
                CGPoint(x: 0.5, y: 0.66),
                CGPoint(x: 0.25, y: 0.86), CGPoint(x: 0.75, y: 0.86)
            ]
        case 9:
            return [
                CGPoint(x: 0.25, y: 0.13), CGPoint(x: 0.75, y: 0.13),
                CGPoint(x: 0.25, y: 0.37), CGPoint(x: 0.75, y: 0.37),
                CGPoint(x: 0.5, y: 0.50),
                CGPoint(x: 0.25, y: 0.63), CGPoint(x: 0.75, y: 0.63),
                CGPoint(x: 0.25, y: 0.87), CGPoint(x: 0.75, y: 0.87)
            ]
        default:
            return [
                CGPoint(x: 0.25, y: 0.11), CGPoint(x: 0.75, y: 0.11),
                CGPoint(x: 0.5, y: 0.27),
                CGPoint(x: 0.25, y: 0.39), CGPoint(x: 0.75, y: 0.39),
                CGPoint(x: 0.25, y: 0.61), CGPoint(x: 0.75, y: 0.61),
                CGPoint(x: 0.5, y: 0.73),
                CGPoint(x: 0.25, y: 0.89), CGPoint(x: 0.75, y: 0.89)
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
        let resourceName = tone == .dark ? "card-template-dark" : "card-template-light"
        return KolkhozResourceImageCache.image(for: [
            KolkhozResourceImageCandidate(resourceName),
            KolkhozResourceImageCandidate(resourceName, subdirectory: "Cards"),
            KolkhozResourceImageCandidate("card-template-front"),
            KolkhozResourceImageCandidate("card-template-front", subdirectory: "Cards")
        ])
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
    KolkhozResourceImageCache.image(for: [
        KolkhozResourceImageCandidate(resourceName),
        KolkhozResourceImageCandidate(resourceName, subdirectory: "Cards")
    ])
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

#Preview("8 of Wheat - Large") {
    CardPreviewStage {
        CardView(card: Card(suit: .wheat, value: 8), size: .large, toneOverride: .light)
            .scaleEffect(4)
            .frame(width: CardSize.large.width * 4, height: CardSize.large.height * 4)
    }
}

#Preview("Queen of Wheat - Large") {
    CardPreviewStage {
        CardView(card: Card(suit: .wheat, value: 12), size: .large, toneOverride: .light)
            .scaleEffect(4)
            .frame(width: CardSize.large.width * 4, height: CardSize.large.height * 4)
    }
}

#Preview("Numbered Wheat Cards") {
    CardPreviewStage {
        HStack(spacing: 18) {
            ForEach(1...10, id: \.self) { value in
                CardView(card: Card(suit: .wheat, value: value), size: .large, toneOverride: .light)
            }
        }
        .padding(24)
    }
}

#Preview("Suit Samples") {
    CardPreviewStage {
        HStack(spacing: 18) {
            ForEach(Suit.allCases) { suit in
                CardView(card: Card(suit: suit, value: 8), size: .large, toneOverride: .light)
            }
        }
        .padding(24)
    }
}

#Preview("Wheat Face Cards") {
    CardPreviewStage {
        HStack(spacing: 18) {
            ForEach([11, 12, 13], id: \.self) { value in
                CardView(card: Card(suit: .wheat, value: value), size: .large, toneOverride: .light)
            }
        }
        .padding(24)
    }
}

#Preview("All Face Cards") {
    CardPreviewStage {
        VStack(spacing: 18) {
            ForEach([11, 12, 13], id: \.self) { value in
                HStack(spacing: 18) {
                    ForEach(Suit.allCases) { suit in
                        CardView(card: Card(suit: suit, value: value), size: .large, toneOverride: .light)
                    }
                }
            }
        }
        .padding(24)
    }
}

#Preview("Face Card Sizes") {
    CardPreviewStage {
        HStack(alignment: .bottom, spacing: 22) {
            CardView(card: Card(suit: .wheat, value: 12), size: .small, toneOverride: .light)
            CardView(card: Card(suit: .wheat, value: 12), size: .medium, toneOverride: .light)
            CardView(card: Card(suit: .wheat, value: 12), size: .large, toneOverride: .light)
        }
        .padding(24)
    }
}

#Preview("Card Sizes") {
    CardPreviewStage {
        HStack(alignment: .bottom, spacing: 22) {
            CardView(card: Card(suit: .wheat, value: 8), size: .small, toneOverride: .light)
            CardView(card: Card(suit: .wheat, value: 8), size: .medium, toneOverride: .light)
            CardView(card: Card(suit: .wheat, value: 8), size: .large, toneOverride: .light)
        }
        .padding(24)
    }
}

private struct CardPreviewStage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(32)
            .background(Color.kolkhozBackground)
            .onAppear {
                KolkhozFontRegistry.registerFonts()
            }
    }
}
