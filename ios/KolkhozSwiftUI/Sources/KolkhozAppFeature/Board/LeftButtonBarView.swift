import KolkhozCore
import SwiftUI

enum GamePanel: Equatable {
    case options
    case brigade
    case jobs
    case north
    case plot
}

enum BoardRailButtonMetrics {
    static let size: CGFloat = 42
    static let panelIconSize: CGFloat = 28
    static let utilityIconSize: CGFloat = 28
    static let spacing: CGFloat = 6
}

struct PanelSelectorButton: View {
    let title: String
    let icon: GameIconAsset
    let active: Bool
    let action: Bool

    var body: some View {
        ZStack {
            GeneratedChromeImage(resourceName: backgroundResourceName)
                .allowsHitTesting(false)

            GameIcon(icon, size: BoardRailButtonMetrics.panelIconSize, muted: !active)
                .padding(.top, action ? 2 : 0)
        }
        .foregroundStyle(active ? Color.kolkhozOnAccent : Color.kolkhozCreamDim)
        .frame(width: BoardRailButtonMetrics.size, height: BoardRailButtonMetrics.size)
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

struct PanelSelectorRailView: View {
    @Environment(\.kolkhozLanguage) private var language
    let activePanel: GamePanel
    let actionPanel: GamePanel
    var tutorialTargetPanel: GamePanel?
    let onSelectPanel: (GamePanel) -> Void

    var body: some View {
        VStack(spacing: BoardRailButtonMetrics.spacing) {
            Button { onSelectPanel(.options) } label: {
                PanelSelectorButton(title: language.text(en: "Menu", ru: "Меню"), icon: .menu, active: activePanel == .options, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Menu", ru: "Меню"))
            .accessibilityAddTraits(activePanel == .options ? .isSelected : [])
            Button { onSelectPanel(.brigade) } label: {
                PanelSelectorButton(title: language.text(en: "Brigade", ru: "Бригада"), icon: .brigade, active: activePanel == .brigade, action: actionPanel == .brigade)
                    .tutorialBoardCue(active: tutorialTargetPanel == .brigade, icon: .tutorialCueTap, cornerRadius: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Brigade", ru: "Бригада"))
            .accessibilityAddTraits(activePanel == .brigade ? .isSelected : [])
            Button { onSelectPanel(.jobs) } label: {
                PanelSelectorButton(title: language.text(en: "Jobs", ru: "Работы"), icon: .jobs, active: activePanel == .jobs, action: actionPanel == .jobs)
                    .tutorialBoardCue(active: tutorialTargetPanel == .jobs, icon: .tutorialCueTap, cornerRadius: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Jobs", ru: "Работы"))
            .accessibilityAddTraits(activePanel == .jobs ? .isSelected : [])
            Button { onSelectPanel(.north) } label: {
                PanelSelectorButton(title: language.text(en: "The North", ru: "Север"), icon: .north, active: activePanel == .north, action: actionPanel == .north)
                    .tutorialBoardCue(active: tutorialTargetPanel == .north, icon: .tutorialCueTap, cornerRadius: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "The North", ru: "Север"))
            .accessibilityAddTraits(activePanel == .north ? .isSelected : [])
            Button { onSelectPanel(.plot) } label: {
                PanelSelectorButton(title: language.text(en: "Cellar", ru: "Подвал"), icon: .plot, active: activePanel == .plot, action: actionPanel == .plot)
                    .tutorialBoardCue(active: tutorialTargetPanel == .plot, icon: .tutorialCueTap, cornerRadius: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(language.text(en: "Cellar", ru: "Подвал"))
            .accessibilityAddTraits(activePanel == .plot ? .isSelected : [])

            LanguageToggleButton(buttonSize: BoardRailButtonMetrics.size, iconSize: BoardRailButtonMetrics.utilityIconSize)
            AppearanceToggleButton(buttonSize: BoardRailButtonMetrics.size, iconSize: BoardRailButtonMetrics.utilityIconSize)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color.kolkhozTable)
    }
}

#if DEBUG
#Preview("Board Nav") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 86, height: 360) {
        PanelSelectorRailView(
            activePanel: .plot,
            actionPanel: .plot,
            tutorialTargetPanel: .jobs,
            onSelectPanel: { _ in }
        )
    }
}
#endif
