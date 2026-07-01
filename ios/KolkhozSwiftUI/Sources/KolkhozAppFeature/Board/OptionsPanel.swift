import KolkhozCore
import SwiftUI

struct InGameOptionsPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let onNewGame: () -> Void
    let onReturnToLobby: () -> Void
    let onTutorial: () -> Void
    @State private var pendingMenuAction: PendingMenuAction?

    var body: some View {
        GeometryReader { proxy in
            let stackSpacing = kolkhozClamp(proxy.size.height * 0.035, 7, 10)

            ScrollView(.vertical, showsIndicators: false) {
                menuContent(spacing: stackSpacing)
                    .padding(.bottom, 6)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .frame(minHeight: 206, idealHeight: 300, maxHeight: 360)
        .panelStyle()
        .alert(confirmTitle, isPresented: Binding(
            get: { pendingMenuAction != nil },
            set: { if !$0 { pendingMenuAction = nil } }
        )) {
            Button(language.text(en: "Cancel", ru: "Отмена"), role: .cancel) {
                pendingMenuAction = nil
            }
            Button(confirmButtonTitle, role: .destructive) {
                let action = pendingMenuAction
                pendingMenuAction = nil
                switch action {
                case .newGame:
                    onNewGame()
                case .mainMenu:
                    onReturnToLobby()
                case nil:
                    break
                }
            }
        } message: {
            Text(confirmMessage)
        }
    }

    private var confirmTitle: String {
        switch pendingMenuAction {
        case .newGame:
            language.text(en: "Start a new game?", ru: "Начать новую игру?")
        case .mainMenu:
            language.text(en: "Return to main menu?", ru: "Вернуться в главное меню?")
        case nil:
            language.text(en: "Discard current game?", ru: "Сбросить текущую игру?")
        }
    }

    private var confirmButtonTitle: String {
        switch pendingMenuAction {
        case .newGame:
            language.text(en: "New Game", ru: "Новая игра")
        case .mainMenu:
            language.text(en: "Main Menu", ru: "Главное меню")
        case nil:
            language.text(en: "Discard", ru: "Сбросить")
        }
    }

    private var confirmMessage: String {
        language.text(en: "The current game will be discarded.", ru: "Текущая игра будет сброшена.")
    }

    private func menuContent(spacing: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            menuActions
            Divider()
                .overlay(Color.kolkhozGold.opacity(0.35))
            menuRules
        }
    }

    private var menuActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                GameIcon(.menu, size: 18)
                Text(language.text(en: "Menu", ru: "Меню"))
                    .sectionTitle()
            }

            Text(language.text(en: "Game controls", ru: "Управление игрой"))
                .font(.kolkhozLabel(.caption2))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozSmoke)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Spacer(minLength: 0)
                    Button(language.text(en: "New game", ru: "Новая игра")) {
                        pendingMenuAction = .newGame
                    }
                    .buttonStyle(CommandButtonStyle(prominent: true))
                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        onTutorial()
                    } label: {
                        HStack(spacing: 7) {
                            GameIcon(.tutorial, size: 15, muted: true)
                            Text(language.text(en: "How to play", ru: "Как играть"))
                                .font(.kolkhozTitle(.caption))
                                .textCase(.uppercase)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.kolkhozCreamDim)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .frame(maxWidth: 170, alignment: .leading)
                        .background(Color.kolkhozBlack.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.kolkhozGold.opacity(0.42), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer(minLength: 0)
                    Button {
                        pendingMenuAction = .mainMenu
                    } label: {
                        HStack(spacing: 7) {
                            GameIcon(.menu, size: 15, muted: true)
                            Text(language.text(en: "Main menu", ru: "Главное меню"))
                                .font(.kolkhozTitle(.caption))
                                .textCase(.uppercase)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.kolkhozCreamDim)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .frame(maxWidth: 170, alignment: .leading)
                        .background(Color.kolkhozBlack.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))
                        .overlay {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.kolkhozSteel.opacity(0.5), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 0)
                }
                
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    LanguageToggleButton()
                    AppearanceToggleButton()
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var menuRules: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(language.text(en: "Rules", ru: "Правила"))
                    .font(.kolkhozTitle(.subheadline))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
            }

            MenuRuleRow(icon: .jobs, title: language.text(en: "Work", ru: "Работы"), bodyText: language.text(en: "Win tricks, then assign captured cards to matching jobs.", ru: "Выигрывайте взятки и назначайте карты на подходящие работы."))
            MenuRuleRow(icon: .plot, title: language.text(en: "Protect", ru: "Защита"), bodyText: language.text(en: "Keep plot cards safe from failed-job requisition.", ru: "Берегите карты участка от реквизиции за проваленные работы."))
            MenuRuleRow(icon: .warning, title: language.text(en: "Trump faces", ru: "Козырные карты"), bodyText: language.text(en: "Jack goes north, Queen exposes, King doubles exile.", ru: "Валет уходит на Север, Дама раскрывает, Король удваивает ссылку."))
        }
    }
}

#if DEBUG
#Preview("Options Panel") {
    BoardPreviewStage(width: 640, height: 300) {
        InGameOptionsPanel(onNewGame: {}, onReturnToLobby: {}, onTutorial: {})
    }
}
#endif

private enum PendingMenuAction: String, Identifiable {
    case newGame
    case mainMenu

    var id: String { rawValue }
}

struct MenuRuleRow: View {
    let icon: GameIconAsset
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            GameIcon(icon, size: 17, muted: true)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.kolkhozTitle(.caption))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                Text(bodyText)
                    .font(.kolkhozLabel(.caption))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kolkhozBlack.opacity(0.16), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.kolkhozSteel.opacity(0.45), lineWidth: 1)
        }
    }
}
