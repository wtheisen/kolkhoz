import KolkhozCore
import SwiftUI

enum PhaseOverlayLayout {
    static let panelSpacing: CGFloat = 10
    static let cardRowSpacing: CGFloat = 8
}

struct PhaseOverlayView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Group {
            switch store.state.phase {
            case .planning:
                PlanningView()
            case .gameOver:
                GameOverView()
            case .swap, .assignment, .requisition, .trick:
                EmptyView()
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
        VStack(alignment: .leading, spacing: PhaseOverlayLayout.panelSpacing) {
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
                HStack(spacing: PhaseOverlayLayout.cardRowSpacing) {
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

struct GameOverView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            PanelTitleRow(
                title: language.text(en: "Game Over!", ru: "Игра окончена!"),
                subtitle: language.text(en: "Final cellar and medal scores.", ru: "Итоговые очки участка и медалей."),
                icon: .medalStar
            )
            if let result = store.state.gameResult {
                ForEach(store.state.players) { player in
                    GameOverScoreRow(
                        player: player,
                        score: result.scores[player.id, default: 0],
                        winner: player.id == result.winnerID
                    )
                }
            }
            HStack {
                Spacer(minLength: 0)
                Button(language.text(en: "New game", ru: "Новая игра")) {
                    store.newGame()
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                Spacer(minLength: 0)
            }
        }
        .panelStyle()
    }
}

struct GameOverScoreRow: View {
    @Environment(\.kolkhozLanguage) private var language
    let player: PlayerState
    let score: Int
    let winner: Bool

    var body: some View {
        HStack(spacing: 10) {
            PortraitView(player: player, human: player.isHuman)
                .frame(width: BoardPortraitLayout.width, height: BoardPortraitLayout.height)

            HStack(spacing: 2) {
                PixelText(
                    text: language.playerName(player),
                    size: .title,
                    variant: winner ? .heavy : .regular,
                    color: winner ? .kolkhozGold : .kolkhozCream
                )
                .layoutPriority(1)
                if winner {
                    GameIcon(.medalStar, size: 32)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 8)

            PixelText(
                text: "\(score)",
                size: .title,
                variant: .heavy,
                color: winner ? .kolkhozGold : .kolkhozCream
            )
            .frame(minWidth: 28, alignment: .trailing)
        }
        .padding(.vertical, 1)
    }
}

#if DEBUG
#Preview("Phase Panel - Planning") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.planningState, width: 520) {
        PlanningView()
    }
}

#Preview("Phase Panel - Game Over") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.gameOverState, width: 520) {
        GameOverView()
    }
}
#endif
