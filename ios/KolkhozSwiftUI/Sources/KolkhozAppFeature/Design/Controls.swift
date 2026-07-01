import KolkhozCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

func kolkhozClamp(_ value: CGFloat, _ lower: CGFloat, _ upper: CGFloat) -> CGFloat {
    min(upper, max(lower, value))
}

struct CommandPanelBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.kolkhozPanel,
                    Color.kolkhozIron,
                    Color.kolkhozBlack
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            LinearGradient(
                colors: [
                    Color.kolkhozGold.opacity(0.14),
                    .clear,
                    Color.kolkhozRedDark.opacity(0.14)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozGold.opacity(0.26), lineWidth: 1)
        }
    }
}

struct GeneratedChromeImage: View {
    let resourceName: String
    var capInsets: EdgeInsets?
    var resizingMode: Image.ResizingMode = .stretch

    @ViewBuilder
    var body: some View {
        if let image = KolkhozResourceImageCache.image(named: resourceName) {
            if let capInsets {
                image
                    .resizable(capInsets: capInsets, resizingMode: resizingMode)
                    .interpolation(.none)
                    .antialiased(false)
            } else {
                switch resizingMode {
                case .tile:
                    image
                        .resizable(capInsets: EdgeInsets(), resizingMode: .tile)
                        .interpolation(.none)
                        .antialiased(false)
                case .stretch:
                    image
                        .resizable()
                        .interpolation(.none)
                        .antialiased(false)
                @unknown default:
                    image
                        .resizable()
                        .interpolation(.none)
                        .antialiased(false)
                }
            }
        } else {
            Color.clear
        }
    }
}

enum BoardGoldSeparatorOrientation {
    case vertical
    case horizontal
}

struct BoardGoldSeparatorView: View {
    let orientation: BoardGoldSeparatorOrientation

    var body: some View {
        ZStack {
            fallback
            GeneratedChromeImage(resourceName: resourceName, resizingMode: .tile)
        }
        .accessibilityHidden(true)
    }

    private var resourceName: String {
        switch orientation {
        case .vertical:
            "ui-left-rail-separator-tile"
        case .horizontal:
            "ui-play-area-separator-horizontal-tile"
        }
    }

    @ViewBuilder
    private var fallback: some View {
        switch orientation {
        case .vertical:
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: separatorColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(maxWidth: 8)
        case .horizontal:
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: separatorColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(maxHeight: 8)
        }
    }

    private var separatorColors: [Color] {
        [
            .kolkhozBlack.opacity(0.44),
            .kolkhozGold,
            .kolkhozGoldBright,
            .kolkhozGold,
            .kolkhozBlack.opacity(0.44)
        ]
    }
}

struct ResourceArtImage: View {
    let resourceName: String

    var body: some View {
        image
            .resizable()
            .interpolation(.none)
            .antialiased(false)
    }

    private var image: Image {
        KolkhozResourceImageCache.image(for: [
            KolkhozResourceImageCandidate(resourceName),
            KolkhozResourceImageCandidate(resourceName, subdirectory: "Embellishments")
        ]) ?? Image(systemName: "rectangle.fill")
    }
}

struct PanelDividerOrnament: View {
    var body: some View {
        ResourceArtImage(resourceName: "panel-divider-pixel")
            .scaledToFit()
            .opacity(0.58)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct BadgeSealOrnament: View {
    var body: some View {
        ResourceArtImage(resourceName: "badge-seal-pixel")
            .scaledToFit()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

struct PanelTitleRow: View {
    let title: String
    var subtitle: String?
    var icon: GameIconAsset = .medalStar
    var urgent = false

    var body: some View {
        GeometryReader { proxy in
            let scale = kolkhozClamp(proxy.size.width / 520, 0.78, 1)
            let iconBox = 40 * scale
            let iconSize = 24 * scale
            let horizontalPadding = 9 * scale
            let verticalPadding = 7 * scale
            let spacing = 10 * scale
            let ornamentOpacity = kolkhozClamp((proxy.size.width - 320) / 180, 0, urgent ? 0.42 : 0.52)

            HStack(spacing: spacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: urgent
                                    ? [Color.kolkhozRedDark, Color.kolkhozRed.opacity(0.82)]
                                    : [Color.kolkhozBlack.opacity(0.58), Color.kolkhozSteel.opacity(0.36)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    GameIcon(icon, size: iconSize)
                }
                .frame(width: iconBox, height: iconBox)
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(urgent ? Color.kolkhozRedBright : Color.kolkhozGold.opacity(0.8), lineWidth: 1.5)
                }

                VStack(alignment: .leading, spacing: 2) {
                    PixelText(
                        text: title.uppercased(),
                        size: .caption,
                        variant: .heavy,
                        color: urgent ? Color.kolkhozRedBright : Color.kolkhozGold
                    )
                    if let subtitle {
                        PixelText(text: subtitle, size: .caption, color: .kolkhozCreamDim)
                    }
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
            .background(Color.kolkhozBlack.opacity(0.28), in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.kolkhozGold.opacity(0.28), lineWidth: 1)
            }
            .overlay(alignment: .trailing) {
                PanelDividerOrnament()
                    .frame(width: 104, height: 24)
                    .padding(.trailing, 8)
                    .opacity(ornamentOpacity)
            }
        }
    }
}

struct ProgressBar: View {
    let value: Double
    let complete: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.kolkhozBlack)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Color.kolkhozSteel.opacity(0.8), lineWidth: 1)
                    }
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: complete ? [.kolkhozGreen, .kolkhozGold] : [Color(red: 0.54, green: 0.41, blue: 0.08), .kolkhozGold],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, proxy.size.width * value / 2))
            }
        }
        .frame(height: 8)
    }
}

struct MiniRewardCard: View {
    let card: Card
    let claimed: Bool

    var body: some View {
        VStack(spacing: -6) {
            PixelText(text: card.rank, size: .caption, variant: .heavy, color: .kolkhozCardInk)
            SuitMark(suit: card.suit, size: 18)
        }
        .frame(width: 24, height: 34)
        .background(Color.cardFill, in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(claimed ? Color.kolkhozGreen : Color.cardStroke, lineWidth: claimed ? 2 : 1)
        }
    }
}

struct CardSlot: View {
    @Environment(\.kolkhozLanguage) private var language
    let active: Bool
    let human: Bool
    var width: CGFloat = 58
    var height: CGFloat = 82
    @State private var pulse = false

    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
            .foregroundStyle(active ? (human ? Color.kolkhozGold : Color.kolkhozRed) : Color.kolkhozSteel.opacity(0.35))
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(active ? (human ? Color.kolkhozGold.opacity(0.10) : Color.kolkhozRed.opacity(0.12)) : Color.clear)
            )
            .frame(width: width, height: height)
            .overlay {
                if active {
                    PixelText(
                        text: human ? language.text(en: "PLAY", ru: "ХОД") : language.text(en: "WAIT", ru: "ЖДИТЕ"),
                        size: .caption2,
                        variant: .heavy,
                        color: human ? Color.kolkhozGold : Color.kolkhozRedBright
                    )
                }
            }
            .scaleEffect(active && pulse ? 1.035 : 1)
            .shadow(color: active ? (human ? Color.kolkhozGold.opacity(pulse ? 0.58 : 0.28) : Color.kolkhozRed.opacity(pulse ? 0.48 : 0.22)) : .clear, radius: active && pulse ? 18 : 10)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
            .onAppear { pulse = active }
            .onChange(of: active) { _, active in
                pulse = active
            }
    }
}

struct CommandButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kolkhozTitle(.subheadline))
            .textCase(.uppercase)
            .foregroundStyle(prominent ? Color.kolkhozOnAccent : Color.kolkhozCardInk)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .shadow(color: prominent ? Color.kolkhozBlack.opacity(0.8) : Color.kolkhozCream.opacity(0.55), radius: prominent ? 2 : 1, y: prominent ? 1 : 1)
            .padding(.horizontal, prominent ? 42 : 36)
            .padding(.top, prominent ? 14 : 12)
            .padding(.bottom, prominent ? 10 : 9)
            .frame(maxWidth: .infinity, minHeight: prominent ? 58 : 52)
            .background {
                GeneratedChromeImage(resourceName: prominent ? "ui-button-primary" : "ui-button-secondary")
                    .aspectRatio(4, contentMode: .fit)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .shadow(color: .black.opacity(prominent ? 0.34 : 0.24), radius: prominent ? 8 : 5, y: 3)
    }
}

struct CardButton: View {
    @Environment(\.kolkhozLanguage) private var language
    let card: Card
    let selected: Bool
    var size: CardSize = .large
    var trump: Suit? = nil
    var highlighted = false
    var highlightColor: Color = .kolkhozRed
    var positionedAction: ((CGPoint) -> Void)?
    var dragAction: ((CGPoint) -> Void)?
    var dragChanged: ((Card, CGPoint, CGSize) -> Void)?
    var dragEnded: ((Card, CGPoint, CGSize) -> Void)?
    let action: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let startCenter = CGPoint(
                x: proxy.frame(in: .named(GameBoardCoordinateSpace.main)).midX,
                y: proxy.frame(in: .named(GameBoardCoordinateSpace.main)).midY
            )

            interactiveCard(startCenter: startCenter)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(card.accessibilityName(language)))
            .accessibilityHint(dragAction == nil ? Text("") : Text(language.text(en: "Drag up or tap to play.", ru: "Потяните вверх или нажмите, чтобы сыграть.")))
        }
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func interactiveCard(startCenter: CGPoint) -> some View {
        if let dragAction {
            cardFace
                .contentShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    activate(startCenter: startCenter)
                }
                .gesture(playDragGesture(startCenter: startCenter, action: dragAction))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction {
                    activate(startCenter: startCenter)
                }
        } else {
            Button {
                activate(startCenter: startCenter)
            } label: {
                cardFace
            }
            .buttonStyle(.plain)
        }
    }

    private var cardFace: some View {
        CardView(card: card, size: size, trump: trump)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        selected ? Color.kolkhozGreen : (highlighted ? highlightColor : Color.clear),
                        lineWidth: selected ? 3 : (highlighted ? 3 : 0)
                    )
            }
            .shadow(color: highlighted ? highlightColor.opacity(0.34) : .clear, radius: 9)
    }

    private func activate(startCenter: CGPoint) {
        if let positionedAction {
            positionedAction(startCenter)
        } else {
            action()
        }
    }

    private func playDragGesture(startCenter: CGPoint, action: @escaping (CGPoint) -> Void) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                let translation = value.translation
                if translation.height < -4 {
                    dragChanged?(card, startCenter, translation)
                }
            }
            .onEnded { value in
                let translation = value.translation
                if let dragEnded {
                    dragEnded(card, startCenter, translation)
                } else if isPlayDrag(translation, minimumLift: 42, horizontalAllowance: 0.35) {
                    action(startCenter)
                }
            }
    }

    private func isPlayDrag(_ translation: CGSize, minimumLift: CGFloat, horizontalAllowance: CGFloat) -> Bool {
        translation.height < -minimumLift &&
            abs(translation.height) > abs(translation.width) * horizontalAllowance
    }
}

private extension Card {
    func accessibilityName(_ language: KolkhozLanguage) -> String {
        language.text(en: "\(spokenRank(language)) of \(suit.rawValue)", ru: "\(spokenRank(language)) \(language.suitName(suit))")
    }

    func spokenRank(_ language: KolkhozLanguage) -> String {
        switch value {
        case 1:
            language.text(en: "Ace", ru: "Туз")
        case 11:
            language.text(en: "Jack", ru: "Валет")
        case 12:
            language.text(en: "Queen", ru: "Дама")
        case 13:
            language.text(en: "King", ru: "Король")
        default: "\(value)"
        }
    }
}
