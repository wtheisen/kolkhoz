import KolkhozCore
import SwiftUI

enum KolkhozLanguage: String, CaseIterable {
    case ru
    case en

    init(storedValue: String) {
        self = KolkhozLanguage(rawValue: storedValue) ?? .ru
    }

    var next: KolkhozLanguage {
        self == .ru ? .en : .ru
    }

    var toggleLabel: String {
        self == .ru ? "EN" : "RU"
    }

    var toggleTitle: String {
        text(en: "Switch to Russian", ru: "Switch to English")
    }

    func text(en: String, ru: String) -> String {
        self == .ru ? ru : en
    }

    func suitName(_ suit: Suit) -> String {
        switch suit {
        case .wheat:
            text(en: "Wheat", ru: "Пшеница")
        case .sunflower:
            text(en: "Sunflower", ru: "Подсолнух")
        case .potato:
            text(en: "Potatoes", ru: "Картофель")
        case .beet:
            text(en: "Beets", ru: "Свёкла")
        }
    }

    func suitShortName(_ suit: Suit) -> String {
        switch suit {
        case .wheat:
            text(en: "W", ru: "Пш")
        case .sunflower:
            text(en: "S", ru: "Пд")
        case .potato:
            text(en: "P", ru: "Кр")
        case .beet:
            text(en: "B", ru: "Св")
        }
    }

    func presetTitle(_ preset: GamePreset) -> String {
        switch preset {
        case .kolkhoz:
            text(en: "Kolkhoz", ru: "Колхоз")
        case .littleKolkhoz:
            text(en: "Little Kolkhoz", ru: "Колхозик")
        case .campStyle:
            text(en: "Camp Style", ru: "Лагерный")
        case .custom:
            text(en: "Custom", ru: "Свой")
        }
    }

    func playerName(_ player: PlayerState) -> String {
        player.isHuman ? text(en: "You", ru: "Вы") : player.name
    }

    func phaseName(_ phase: GamePhase) -> String {
        switch phase {
        case .planning:
            text(en: "Planning", ru: "План")
        case .swap:
            text(en: "Swap", ru: "Обмен")
        case .trick:
            text(en: "Trick", ru: "Взятка")
        case .assignment:
            text(en: "Assignment", ru: "Работы")
        case .requisition:
            text(en: "Requisition", ru: "Реквизиция")
        case .gameOver:
            text(en: "Game Over", ru: "Итог")
        }
    }

    func requisitionMessage(for event: RequisitionEvent, players: [PlayerState]) -> String {
        guard self == .ru else { return event.message }

        if let playerID = event.playerID, let card = event.card, players.indices.contains(playerID) {
            let name = players[playerID].isHuman ? "Вы" : players[playerID].name
            return "\(name) отправляет \(card.rank) \(suitName(event.suit)) на Север"
        }

        if let playerID = event.playerID, players.indices.contains(playerID) {
            let name = players[playerID].isHuman ? "Вы защищены" : "\(players[playerID].name) защищён"
            return "\(name) после победы во всех взятках"
        }

        return "\(suitName(event.suit)) провалено; нет уязвимых подходящих карт"
    }
}

private struct KolkhozLanguageKey: EnvironmentKey {
    static let defaultValue = KolkhozLanguage.ru
}

private struct ToggleKolkhozLanguageKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    var kolkhozLanguage: KolkhozLanguage {
        get { self[KolkhozLanguageKey.self] }
        set { self[KolkhozLanguageKey.self] = newValue }
    }

    var toggleKolkhozLanguage: @MainActor @Sendable () -> Void {
        get { self[ToggleKolkhozLanguageKey.self] }
        set { self[ToggleKolkhozLanguageKey.self] = newValue }
    }
}

struct LanguageToggleButton: View {
    @Environment(\.kolkhozLanguage) private var language
    @Environment(\.toggleKolkhozLanguage) private var toggleLanguage
    var compact = false

    var body: some View {
        Button(action: toggleLanguage) {
            HStack(spacing: compact ? 5 : 7) {
                GameIcon(.language, size: compact ? 16 : 18)
                Text(language.toggleLabel)
                    .font(.kolkhozTitle(compact ? .caption2 : .caption))
                    .textCase(.uppercase)
                    .lineLimit(1)
            }
            .foregroundStyle(Color.kolkhozGold)
            .padding(.horizontal, compact ? 8 : 10)
            .frame(height: compact ? 28 : 32)
            .background(Color.kolkhozBlack.opacity(0.22), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.kolkhozGold.opacity(0.55), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(language.toggleTitle))
        .help(language.toggleTitle)
    }
}
