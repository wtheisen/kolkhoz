import SwiftUI

enum KolkhozReadability: String {
    case standard
    case clear

    init(storedValue: String) {
        if storedValue == "large" {
            self = .clear
            return
        }
        self = KolkhozReadability(rawValue: storedValue) ?? .standard
    }

    var next: KolkhozReadability {
        self == .standard ? .clear : .standard
    }

    func toggleTitle(_ language: KolkhozLanguage) -> String {
        self == .standard
            ? language.text(en: "Use clearer text", ru: "Четкий текст")
            : language.text(en: "Use pixel text", ru: "Пиксельный текст")
    }
}

private struct KolkhozReadabilityKey: EnvironmentKey {
    static let defaultValue = KolkhozReadability.standard
}

private struct ToggleKolkhozReadabilityKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var kolkhozReadability: KolkhozReadability {
        get { self[KolkhozReadabilityKey.self] }
        set { self[KolkhozReadabilityKey.self] = newValue }
    }

    var toggleKolkhozReadability: @MainActor @Sendable () -> Void {
        get { self[ToggleKolkhozReadabilityKey.self] }
        set { self[ToggleKolkhozReadabilityKey.self] = newValue }
    }
}

struct ReadabilityToggleButton: View {
    @Environment(\.kolkhozReadability) private var readability
    @Environment(\.kolkhozLanguage) private var language
    @Environment(\.toggleKolkhozReadability) private var toggleReadability

    var body: some View {
        Button(action: toggleReadability) {
            HStack(spacing: 7) {
                Text("Aa")
                    .font(.kolkhozTitle(.caption))
                    .textCase(.none)
                    .frame(width: 24, alignment: .center)
                Text(readability == .clear ? language.text(en: "Pixel text", ru: "Пиксельный") : language.text(en: "Clear text", ru: "Четкий текст"))
                    .font(.kolkhozTitle(.caption))
                    .textCase(.uppercase)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .foregroundStyle(Color.kolkhozCreamDim)
            .padding(.horizontal, 12)
            .frame(height: 34)
            .frame(maxWidth: 190, alignment: .leading)
            .background(Color.kolkhozBlack.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.kolkhozGold.opacity(readability == .clear ? 0.72 : 0.42), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(readability.toggleTitle(language)))
        .accessibilityAddTraits(readability == .clear ? .isSelected : [])
        .help(readability.toggleTitle(language))
    }
}
