import KolkhozCore
import SwiftUI

enum PhaseActionLayout {
    static let panelSpacing: CGFloat = 10
    static let cardRowSpacing: CGFloat = 8
    static let assignmentRowSpacing: CGFloat = 10
    static let capturedPlayerNameWidth: CGFloat = 86
}

struct PhaseActionView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Group {
            switch store.state.phase {
            case .planning:
                PlanningView()
            case .swap:
                SwapView()
            case .assignment:
                AssignmentView()
            case .requisition:
                RequisitionView()
            case .gameOver:
                GameOverView()
            case .trick:
                TurnHintView()
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: store.state.phase)
    }
}

struct PlanningView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: PhaseActionLayout.panelSpacing) {
            PanelTitleRow(
                title: store.state.isFamine ? language.text(en: "Famine year", ru: "Год неурожая") : language.text(en: "Choose Main Task", ru: "Выберите главную задачу"),
                subtitle: store.state.isFamine ? language.text(en: "No trump suit is used this year.", ru: "В этом году козырь не используется.") : language.text(en: "Pick the job suit for this year.", ru: "Выберите масть работы на этот год."),
                icon: store.state.isFamine ? .warning : .jobs,
                urgent: store.state.isFamine
            )

            if store.state.isFamine {
                Text(language.text(en: "No trump suit is used this year.", ru: "В этом году козырь не используется."))
                    .font(.kolkhozLabel(.subheadline))
                    .foregroundStyle(Color.kolkhozCreamDim)
            } else {
                HStack(spacing: PhaseActionLayout.cardRowSpacing) {
                    ForEach(Suit.allCases) { suit in
                        Button {
                            store.setTrump(suit)
                        } label: {
                            AssignmentTargetButton(
                                suit: suit,
                                selected: store.state.trump == suit,
                                title: language.suitName(suit)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .panelStyle()
    }
}

struct SwapView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @State var selectedHand: Card?
    @State var selectedHidden: Card?
    @State var selectedRevealed: Card?

    var body: some View {
        VStack(alignment: .leading, spacing: PhaseActionLayout.panelSpacing) {
            PanelTitleRow(
                title: language.text(en: "Card Swap", ru: "Обмен карт"),
                subtitle: language.text(en: "Trade one hand card with your cellar.", ru: "Обменяйте одну карту руки с подвалом."),
                icon: .cellar
            )

            Text(language.text(en: "Hand", ru: "Рука"))
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCreamDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PhaseActionLayout.cardRowSpacing) {
                    ForEach(store.state.players[0].hand) { card in
                        CardButton(card: card, selected: selectedHand == card, highlighted: true) {
                            selectedHand = card
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Text(language.text(en: "Cellar", ru: "Подвал"))
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCreamDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: PhaseActionLayout.cardRowSpacing) {
                    ForEach(store.state.players[0].plot.hidden) { card in
                        CardButton(card: card, selected: selectedHidden == card, highlighted: true) {
                            selectedHidden = card
                            selectedRevealed = nil
                        }
                    }
                    ForEach(store.state.players[0].plot.revealed) { card in
                        CardButton(card: card, selected: selectedRevealed == card, highlighted: true) {
                            selectedRevealed = card
                            selectedHidden = nil
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Button(language.text(en: "Swap selected", ru: "Обменять")) {
                    guard let hand = selectedHand else { return }
                    if let hidden = selectedHidden {
                        store.swap(handCard: hand, plotCard: hidden, revealed: false)
                    } else if let revealed = selectedRevealed {
                        store.swap(handCard: hand, plotCard: revealed, revealed: true)
                    }
                    selectedHand = nil
                    selectedHidden = nil
                    selectedRevealed = nil
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                .disabled(selectedHand == nil || (selectedHidden == nil && selectedRevealed == nil) || store.state.swapCount.contains(0))

                if store.state.swapCount.contains(0) {
                    Button(language.text(en: "Undo", ru: "Отменить")) {
                        store.undoSwap()
                    }
                    .buttonStyle(CommandButtonStyle(prominent: false))
                }

                Button(language.text(en: "Start tricks", ru: "Начать взятки")) {
                    store.confirmSwap()
                }
                .buttonStyle(CommandButtonStyle(prominent: false))
            }
        }
        .panelStyle()
    }
}

struct AssignmentView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: PhaseActionLayout.panelSpacing) {
            PanelTitleRow(
                title: language.text(en: "Assign captured work", ru: "Назначьте работу"),
                subtitle: language.text(en: "Send each trick card to a valid job.", ru: "Отправьте каждую карту взятки на допустимую работу."),
                icon: .jobs
            )

            ForEach(store.state.lastTrick) { play in
                HStack(spacing: PhaseActionLayout.assignmentRowSpacing) {
                    CardView(card: play.card, size: .small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.state.players[play.playerID].name)
                            .font(.kolkhozLabel(.caption))
                            .foregroundStyle(Color.kolkhozCream)
                        Text(language.text(en: "Captured work", ru: "Захваченная работа"))
                            .font(.kolkhozLabel(.caption2))
                            .foregroundStyle(Color.kolkhozSmoke)
                    }
                    .frame(width: PhaseActionLayout.capturedPlayerNameWidth, alignment: .leading)
                    ForEach(legalTargets) { suit in
                        Button {
                            store.assign(play.card, to: suit)
                        } label: {
                            AssignmentTargetButton(
                                suit: suit,
                                selected: store.state.pendingAssignments[play.card.id] == suit,
                                title: language.suitShortName(suit)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.kolkhozBlack.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.kolkhozSteel.opacity(0.7), lineWidth: 1)
                }
            }

            Button(language.text(en: "Submit assignments", ru: "Подтвердить")) {
                store.submitAssignments()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
            .disabled(store.state.pendingAssignments.count != store.state.lastTrick.count)
        }
        .panelStyle()
    }

    var legalTargets: [Suit] {
        Array(Set(store.state.lastTrick.map(\.card.suit))).sorted { $0.rawValue < $1.rawValue }
    }
}

struct ColumnHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.kolkhozTitle(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozGold)
            Spacer()
            Text(subtitle)
                .font(.kolkhozLabel(.caption2))
                .foregroundStyle(Color.kolkhozSmoke)
        }
    }
}

struct RequisitionView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: PhaseActionLayout.panelSpacing) {
            Text(language.text(en: "Requisition", ru: "Реквизиция"))
                .sectionTitle(color: .kolkhozRedBright)

            if store.state.requisitionEvents.isEmpty {
                Text(language.text(en: "All jobs complete!", ru: "Все работы выполнены!"))
                    .foregroundStyle(Color.kolkhozCreamDim)
            } else {
                ForEach(store.state.requisitionEvents) { event in
                    RequisitionEventRow(event: event)
                }
            }

            Button(store.state.year >= 5 ? language.text(en: "Finish plan", ru: "Завершить план") : language.text(en: "Continue to Year \(store.state.year + 1)", ru: "Продолжить к Году \(store.state.year + 1)")) {
                store.continueAfterRequisition()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
        }
        .panelStyle()
    }
}

struct GameOverView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: PhaseActionLayout.panelSpacing) {
            PanelTitleRow(
                title: language.text(en: "Game Over!", ru: "Игра окончена!"),
                subtitle: language.text(en: "Final cellar and medal scores.", ru: "Итоговые очки участка и медалей."),
                icon: .medalStar
            )
            if let result = store.state.gameResult {
                Text(language.text(en: "Winner: \(store.state.players[result.winnerID].name)", ru: "Победитель: \(language.playerName(store.state.players[result.winnerID]))"))
                    .font(.kolkhozTitle(.headline))
                    .foregroundStyle(Color.kolkhozGold)
                ForEach(store.state.players) { player in
                    HStack {
                        Text(language.playerName(player))
                        Spacer()
                        Text("\(result.scores[player.id, default: 0])")
                            .monospacedDigit()
                    }
                    .font(.kolkhozLabel(.subheadline))
                    .foregroundStyle(Color.kolkhozCream)
                }
            }
            Button(language.text(en: "New game", ru: "Новая игра")) {
                store.newGame()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
        }
        .panelStyle()
    }
}

#if DEBUG
#Preview("Phase Panel - Planning") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.planningState, width: 520) {
        PlanningView()
    }
}

#Preview("Phase Panel - Swap") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 620) {
        SwapView()
    }
}

#Preview("Phase Panel - Assignment") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 640) {
        AssignmentView()
    }
}

#Preview("Phase Panel - Requisition") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 520) {
        RequisitionView()
    }
}

#Preview("Phase Panel - Game Over") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.gameOverState, width: 520) {
        GameOverView()
    }
}
#endif

struct TurnHintView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        let valid = store.validCardsForHuman()
        HStack(spacing: 10) {
            GameIcon(store.state.currentPlayer == 0 ? .playTap : .gears, size: 24)
            Text(store.state.currentPlayer == 0 ? language.text(en: "Play \(valid.count) legal card\(valid.count == 1 ? "" : "s").", ru: "Сыграйте допустимые карты: \(valid.count).") : language.text(en: "AI players are resolving their turns.", ru: "Игроки ИИ делают ход."))
                .font(.kolkhozLabel(.subheadline))
                .foregroundStyle(Color.kolkhozCream)
            Spacer()
        }
        .panelStyle()
    }
}
