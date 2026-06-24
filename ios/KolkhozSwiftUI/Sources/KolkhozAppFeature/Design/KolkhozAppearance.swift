import SwiftUI

enum KolkhozAppearance: String, CaseIterable {
    case dark
    case light

    init(storedValue: String) {
        self = KolkhozAppearance(rawValue: storedValue) ?? .dark
    }

    var next: KolkhozAppearance {
        self == .dark ? .light : .dark
    }

    var colorScheme: ColorScheme {
        self == .dark ? .dark : .light
    }

    func toggleLabel(_ language: KolkhozLanguage) -> String {
        self == .dark ? language.text(en: "Light", ru: "Свет") : language.text(en: "Dark", ru: "Тьма")
    }

    func toggleTitle(_ language: KolkhozLanguage) -> String {
        self == .dark ? language.text(en: "Switch to light mode", ru: "Включить светлую тему") : language.text(en: "Switch to dark mode", ru: "Включить тёмную тему")
    }
}

private struct KolkhozAppearanceKey: EnvironmentKey {
    static let defaultValue = KolkhozAppearance.dark
}

private struct ToggleKolkhozAppearanceKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var kolkhozAppearance: KolkhozAppearance {
        get { self[KolkhozAppearanceKey.self] }
        set { self[KolkhozAppearanceKey.self] = newValue }
    }

    var toggleKolkhozAppearance: @MainActor @Sendable () -> Void {
        get { self[ToggleKolkhozAppearanceKey.self] }
        set { self[ToggleKolkhozAppearanceKey.self] = newValue }
    }
}

struct AppearanceToggleButton: View {
    @Environment(\.kolkhozAppearance) private var appearance
    @Environment(\.kolkhozLanguage) private var language
    @Environment(\.toggleKolkhozAppearance) private var toggleAppearance
    var compact = false

    var body: some View {
        Button(action: toggleAppearance) {
            ZStack {
                GeneratedChromeImage(resourceName: "ui-nav-button-inactive")
                    .allowsHitTesting(false)
                GameIcon(.appearance, size: 25)
            }
            .frame(width: 48, height: 48)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(appearance.toggleTitle(language)))
        .help(appearance.toggleTitle(language))
    }
}
