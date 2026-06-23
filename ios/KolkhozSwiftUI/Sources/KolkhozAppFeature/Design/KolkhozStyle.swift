import KolkhozCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                ZStack {
                    LinearGradient(
                        colors: [Color.kolkhozPanel, Color.kolkhozIron.opacity(0.96), Color.kolkhozBlack.opacity(0.94)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    LinearGradient(
                        colors: [Color.kolkhozGold.opacity(0.16), .clear, Color.kolkhozRedDark.opacity(0.18)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.kolkhozGold.opacity(0.72), lineWidth: 1.5)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.kolkhozRedDark.opacity(0.62), lineWidth: 1)
                    .padding(5)
            }
            .overlay {
                PrintCornerFrame(cornerRadius: 8)
            }
            .overlay {
                PanelCornerOrnaments(size: 46, opacity: 0.58)
                    .padding(2)
            }
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
    }
}

struct PrintCornerFrame: View {
    var cornerRadius: CGFloat = 6
    var accent: Color = .kolkhozGold

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(accent.opacity(0.42), lineWidth: 1)
            VStack {
                HStack {
                    PrintCornerMark(accent: accent)
                    Spacer()
                    PrintCornerMark(accent: accent).rotationEffect(.degrees(90))
                }
                Spacer()
                HStack {
                    PrintCornerMark(accent: accent).rotationEffect(.degrees(-90))
                    Spacer()
                    PrintCornerMark(accent: accent).rotationEffect(.degrees(180))
                }
            }
            .padding(6)
        }
        .allowsHitTesting(false)
    }
}

private struct PrintCornerMark: View {
    let accent: Color

    var body: some View {
        ZStack(alignment: .topLeading) {
            Capsule()
                .fill(accent.opacity(0.85))
                .frame(width: 15, height: 2)
            Capsule()
                .fill(accent.opacity(0.85))
                .frame(width: 2, height: 15)
            Capsule()
                .fill(Color.kolkhozRed.opacity(0.76))
                .frame(width: 6, height: 2)
                .offset(x: 4, y: 4)
        }
        .frame(width: 15, height: 15)
    }
}

extension View {
    func panelStyle() -> some View {
        modifier(PanelModifier())
    }

    func sectionTitle(color: Color = .kolkhozGold) -> some View {
        self
            .font(.kolkhozTitle(.headline))
            .textCase(.uppercase)
            .foregroundStyle(color)
    }

    func variantRowBackground(active: Bool) -> some View {
        self
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(active ? Color.kolkhozGold.opacity(0.08) : Color.kolkhozBlack.opacity(0.24), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(active ? Color.kolkhozGold.opacity(0.35) : Color.kolkhozSteel.opacity(0.5), lineWidth: 1)
            }
    }
}

extension Font {
    static func kolkhozDisplay(size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .monospaced)
    }

    static func kolkhozTitle(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced).weight(.black)
    }

    static func kolkhozLabel(_ style: Font.TextStyle) -> Font {
        .system(style, design: .monospaced).weight(.bold)
    }
}

final class KolkhozAppFeatureBundleToken {}

extension Bundle {
    #if SWIFT_PACKAGE
    static let kolkhozAppFeatureResources = Bundle.module
    #else
    static let kolkhozAppFeatureResources = Bundle(for: KolkhozAppFeatureBundleToken.self)
    #endif
}

extension Color {
    static var kolkhozBackground: Color {
        adaptive(dark: RGB(0.04, 0.04, 0.04), light: RGB(0.90, 0.86, 0.76))
    }

    static var kolkhozBlack: Color {
        adaptive(dark: RGB(0.03, 0.03, 0.03), light: RGB(0.96, 0.92, 0.82))
    }

    static var kolkhozIron: Color {
        adaptive(dark: RGB(0.10, 0.09, 0.08), light: RGB(0.84, 0.78, 0.66))
    }

    static var kolkhozPanel: Color {
        adaptive(dark: RGB(0.14, 0.13, 0.11), light: RGB(0.91, 0.86, 0.74))
    }

    static var kolkhozSteel: Color {
        adaptive(dark: RGB(0.31, 0.29, 0.25), light: RGB(0.49, 0.41, 0.29))
    }

    static var kolkhozGold: Color {
        adaptive(dark: RGB(0.83, 0.66, 0.34), light: RGB(0.59, 0.38, 0.10))
    }

    static var kolkhozGoldBright: Color {
        adaptive(dark: RGB(1.00, 0.84, 0.00), light: RGB(0.72, 0.47, 0.08))
    }

    static var kolkhozRed: Color {
        adaptive(dark: RGB(0.77, 0.12, 0.23), light: RGB(0.69, 0.07, 0.16))
    }

    static var kolkhozRedDark: Color {
        adaptive(dark: RGB(0.55, 0.00, 0.00), light: RGB(0.78, 0.18, 0.16))
    }

    static var kolkhozRedBright: Color {
        adaptive(dark: RGB(0.86, 0.08, 0.24), light: RGB(0.64, 0.03, 0.13))
    }

    static var kolkhozCream: Color {
        adaptive(dark: RGB(0.91, 0.86, 0.77), light: RGB(0.15, 0.12, 0.09))
    }

    static var kolkhozCreamDim: Color {
        adaptive(dark: RGB(0.76, 0.69, 0.58), light: RGB(0.35, 0.28, 0.19))
    }

    static var kolkhozSmoke: Color {
        adaptive(dark: RGB(0.55, 0.51, 0.46), light: RGB(0.43, 0.36, 0.27))
    }

    static var kolkhozGreen: Color {
        adaptive(dark: RGB(0.30, 0.69, 0.31), light: RGB(0.16, 0.47, 0.20))
    }

    static var kolkhozTable: Color {
        adaptive(dark: RGB(0.10, 0.10, 0.10), light: RGB(0.79, 0.72, 0.60))
    }

    static var kolkhozOnAccent: Color {
        Color(red: 0.96, green: 0.91, blue: 0.80)
    }

    static var kolkhozCardInk: Color {
        Color(red: 0.06, green: 0.05, blue: 0.04)
    }

    static var cardFill: Color {
        Color(red: 0.98, green: 0.96, blue: 0.89)
    }

    static var cardStroke: Color {
        Color.black.opacity(0.38)
    }

    struct RGB {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    private static func adaptive(dark: RGB, light: RGB) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: dark.red, green: dark.green, blue: dark.blue, alpha: 1)
                : UIColor(red: light.red, green: light.green, blue: light.blue, alpha: 1)
        })
        #elseif canImport(AppKit)
        Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let rgb = isDark ? dark : light
            return NSColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
        #else
        Color(red: dark.red, green: dark.green, blue: dark.blue)
        #endif
    }
}

extension Suit {
    var iconAsset: GameIconAsset {
        switch self {
        case .wheat: .wheat
        case .sunflower: .sunflower
        case .potato: .potato
        case .beet: .beet
        }
    }

    var displayColor: Color {
        switch self {
        case .wheat, .sunflower: .kolkhozCream
        case .potato, .beet: .kolkhozRed
        }
    }

    var cardInkColor: Color {
        switch self {
        case .wheat, .sunflower: .kolkhozCardInk
        case .potato, .beet: .kolkhozRedBright
        }
    }
}
