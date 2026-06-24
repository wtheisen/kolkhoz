import KolkhozCore
import SwiftUI

enum GameNavigationLayout {
    static let railButtonSpacing: CGFloat = 5
    static let railVerticalPadding: CGFloat = 8
    static let railHorizontalPadding: CGFloat = 5
    static let compactButtonSpacing: CGFloat = 6
    static let compactHorizontalPadding: CGFloat = 6
    static let compactVerticalPadding: CGFloat = 3
    static let buttonSize: CGFloat = 48
    static let iconSize: CGFloat = 25
}

enum GamePanel: Equatable {
    case options
    case game
    case jobs
    case north
    case plot
}

struct NavRailView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let width: CGFloat
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void

    var body: some View {
        VStack(spacing: GameNavigationLayout.railButtonSpacing) {
            Button { onSelectPanel(.options) } label: {
                NavButton(title: language.text(en: "Menu", ru: "Меню"), icon: .menu, active: activePanel == .options, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Menu", ru: "Меню"))
            Button { onSelectPanel(.game) } label: {
                NavButton(title: language.text(en: "Brigade", ru: "Бригада"), icon: .brigade, active: activePanel == .game, action: actionPanel == .game)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Brigade", ru: "Бригада"))
            Button { onSelectPanel(.jobs) } label: {
                NavButton(title: language.text(en: "Fields", ru: "Поля"), icon: .jobs, active: activePanel == .jobs, action: actionPanel == .jobs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Fields", ru: "Поля"))
            Button { onSelectPanel(.north) } label: {
                NavButton(title: language.text(en: "The North", ru: "Север"), icon: .north, active: activePanel == .north, action: actionPanel == .north)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "The North", ru: "Север"))
            Button { onSelectPanel(.plot) } label: {
                NavButton(title: language.text(en: "Cellar", ru: "Подвал"), icon: .plot, active: activePanel == .plot, action: actionPanel == .plot)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Cellar", ru: "Подвал"))
        }
        .padding(.vertical, GameNavigationLayout.railVerticalPadding)
        .padding(.horizontal, GameNavigationLayout.railHorizontalPadding)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(Color.kolkhozTable)
        .contentShape(Rectangle())
    }
}

struct NavButton: View {
    let title: String
    let icon: GameIconAsset
    let active: Bool
    let action: Bool

    var body: some View {
        ZStack {
            GeneratedChromeImage(resourceName: backgroundResourceName)
                .allowsHitTesting(false)

            GameIcon(icon, size: GameNavigationLayout.iconSize, muted: !active)
                .padding(.top, action ? 2 : 0)
        }
        .foregroundStyle(active ? Color.kolkhozOnAccent : Color.kolkhozCreamDim)
        .frame(width: GameNavigationLayout.buttonSize, height: GameNavigationLayout.buttonSize)
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

struct CompactNavBarView: View {
    @Environment(\.kolkhozLanguage) private var language
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void

    var body: some View {
        HStack(spacing: GameNavigationLayout.compactButtonSpacing) {
            Button { onSelectPanel(.options) } label: {
                NavButton(title: language.text(en: "Menu", ru: "Меню"), icon: .menu, active: activePanel == .options, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Menu", ru: "Меню"))
            Button { onSelectPanel(.game) } label: {
                NavButton(title: language.text(en: "Brigade", ru: "Бригада"), icon: .brigade, active: activePanel == .game, action: actionPanel == .game)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Brigade", ru: "Бригада"))
            Button { onSelectPanel(.jobs) } label: {
                NavButton(title: language.text(en: "Fields", ru: "Поля"), icon: .jobs, active: activePanel == .jobs, action: actionPanel == .jobs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Fields", ru: "Поля"))
            Button { onSelectPanel(.north) } label: {
                NavButton(title: language.text(en: "The North", ru: "Север"), icon: .north, active: activePanel == .north, action: actionPanel == .north)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "The North", ru: "Север"))
            Button { onSelectPanel(.plot) } label: {
                NavButton(title: language.text(en: "Cellar", ru: "Подвал"), icon: .plot, active: activePanel == .plot, action: actionPanel == .plot)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Cellar", ru: "Подвал"))
        }
        .padding(.horizontal, GameNavigationLayout.compactHorizontalPadding)
        .padding(.vertical, GameNavigationLayout.compactVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.kolkhozTable)
    }
}

#if DEBUG
#Preview("Board Nav Rail") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 92, height: 340) {
        NavRailView(
            activePanel: .jobs,
            actionPanel: .jobs,
            width: GameBoardLayout.navRailMaxWidth,
            onMenu: {},
            onSelectPanel: { _ in }
        )
    }
}

#Preview("Board Compact Nav") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 360, height: 72) {
        CompactNavBarView(
            activePanel: .plot,
            actionPanel: .plot,
            onMenu: {},
            onSelectPanel: { _ in }
        )
    }
}
#endif
