import KolkhozCore
import SwiftUI

enum LeftButtonBarLayout {
    static let buttonSpacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 6
    static let verticalPadding: CGFloat = 3
    static let buttonSize: CGFloat = 48
    static let iconSize: CGFloat = 28
}

enum GamePanel: Equatable {
    case options
    case brigade
    case jobs
    case north
    case plot
}

struct LeftButtonBarButton: View {
    let title: String
    let icon: GameIconAsset
    let active: Bool
    let action: Bool

    var body: some View {
        ZStack {
            GeneratedChromeImage(resourceName: backgroundResourceName)
                .allowsHitTesting(false)

            GameIcon(icon, size: LeftButtonBarLayout.iconSize, muted: !active)
                .padding(.top, action ? 2 : 0)
        }
        .foregroundStyle(active ? Color.kolkhozOnAccent : Color.kolkhozCreamDim)
        .frame(width: LeftButtonBarLayout.buttonSize, height: LeftButtonBarLayout.buttonSize)
        .shadow(color: active ? Color.kolkhozRed.opacity(0.35) : .clear, radius: 8, y: 3)
        .help(title)
    }

    private var backgroundResourceName: String {
        switch (active, action) {
        case (true, true):
            "ui-nav-button-active-current"
        case (false, true):
            "ui-nav-button-inactive-current"
        case (true, false):
            "ui-nav-button-active"
        case (false, false):
            "ui-nav-button-inactive"
        }
    }
}

struct TopButtonBarView: View {
    @Environment(\.kolkhozLanguage) private var language
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void

    var body: some View {
        HStack(spacing: LeftButtonBarLayout.buttonSpacing) {
            Button { onSelectPanel(.options) } label: {
                LeftButtonBarButton(title: language.text(en: "Menu", ru: "Меню"), icon: .menu, active: activePanel == .options, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Menu", ru: "Меню"))
            Button { onSelectPanel(.brigade) } label: {
                LeftButtonBarButton(title: language.text(en: "Brigade", ru: "Бригада"), icon: .brigade, active: activePanel == .brigade, action: actionPanel == .brigade)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Brigade", ru: "Бригада"))
            Button { onSelectPanel(.jobs) } label: {
                LeftButtonBarButton(title: language.text(en: "Jobs", ru: "Работы"), icon: .jobs, active: activePanel == .jobs, action: actionPanel == .jobs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Jobs", ru: "Работы"))
            Button { onSelectPanel(.north) } label: {
                LeftButtonBarButton(title: language.text(en: "The North", ru: "Север"), icon: .north, active: activePanel == .north, action: actionPanel == .north)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "The North", ru: "Север"))
            Button { onSelectPanel(.plot) } label: {
                LeftButtonBarButton(title: language.text(en: "Cellar", ru: "Подвал"), icon: .plot, active: activePanel == .plot, action: actionPanel == .plot)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Cellar", ru: "Подвал"))
        }
        .padding(.horizontal, LeftButtonBarLayout.horizontalPadding)
        .padding(.vertical, LeftButtonBarLayout.verticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.kolkhozTable)
    }
}

#if DEBUG
#Preview("Board Nav") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 360, height: 72) {
        TopButtonBarView(
            activePanel: .plot,
            actionPanel: .plot,
            onMenu: {},
            onSelectPanel: { _ in }
        )
    }
}
#endif
