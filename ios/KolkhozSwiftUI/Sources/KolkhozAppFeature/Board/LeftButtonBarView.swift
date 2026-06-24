import KolkhozCore
import SwiftUI

enum LeftButtonBarLayout {
    static let railButtonSpacing: CGFloat = 5
    static let railVerticalPadding: CGFloat = 8
    static let railHorizontalPadding: CGFloat = 5
    static let compactButtonSpacing: CGFloat = 6
    static let compactHorizontalPadding: CGFloat = 6
    static let compactVerticalPadding: CGFloat = 3
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

struct LeftButtonBarView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let width: CGFloat
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void

    var body: some View {
        VStack(spacing: LeftButtonBarLayout.railButtonSpacing) {
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
        .padding(.vertical, LeftButtonBarLayout.railVerticalPadding)
        .padding(.horizontal, LeftButtonBarLayout.railHorizontalPadding)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(Color.kolkhozTable)
        .contentShape(Rectangle())
    }
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

struct CompactButtonBarView: View {
    @Environment(\.kolkhozLanguage) private var language
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void

    var body: some View {
        HStack(spacing: LeftButtonBarLayout.compactButtonSpacing) {
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
        .padding(.horizontal, LeftButtonBarLayout.compactHorizontalPadding)
        .padding(.vertical, LeftButtonBarLayout.compactVerticalPadding)
        .frame(maxWidth: .infinity)
        .background(Color.kolkhozTable)
    }
}

#if DEBUG
#Preview("Board Nav Rail") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 92, height: 340) {
        LeftButtonBarView(
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
        CompactButtonBarView(
            activePanel: .plot,
            actionPanel: .plot,
            onMenu: {},
            onSelectPanel: { _ in }
        )
    }
}
#endif
