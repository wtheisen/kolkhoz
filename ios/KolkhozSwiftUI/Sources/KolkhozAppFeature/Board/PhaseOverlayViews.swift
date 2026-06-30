import KolkhozCore
import SwiftUI

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
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: store.state.isFamine ? language.text(en: "Famine year", ru: "Год неурожая") : language.text(en: "Choose Trump", ru: "Выберите козырь"),
                subtitle: store.state.isFamine ? language.text(en: "No trump suit is used this year.", ru: "В этом году козырь не используется.") : language.text(en: "Pick the trump suit for this year.", ru: "Выберите козырную масть на этот год."),
                icon: store.state.isFamine ? .famine : .jobs,
                urgent: store.state.isFamine
            )

            if store.state.isFamine {
                ResourceArtImage(resourceName: "art-famine-banner")
                    .scaledToFit()
                    .frame(maxWidth: 270, maxHeight: 68)
                    .opacity(0.9)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                Text(language.text(en: "No trump suit is used this year.", ru: "В этом году козырь не используется."))
                    .font(.kolkhozLabel(.subheadline))
                    .foregroundStyle(Color.kolkhozCreamDim)
            } else {
                LazyVGrid(
                    columns: Array(
                        repeating: GridItem(.fixed(54), spacing: 8),
                        count: 2
                    ),
                    spacing: 8
                ) {
                    ForEach(Suit.allCases) { suit in
                        Button {
                            store.setTrump(suit)
                        } label: {
                            TrumpSelectionButton(
                                suit: suit,
                                title: language.suitName(suit),
                                selected: store.state.trump == suit
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(language.text(en: "\(language.suitName(suit)) trump", ru: "\(language.suitName(suit)) козырь"))
                    }
                }
                .frame(width: 54 * 2 + 8)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .panelStyle()
    }
}

struct TrumpSelectionButton: View {
    let suit: Suit
    let title: String
    let selected: Bool

    var body: some View {
        ZStack {
            GeneratedChromeImage(resourceName: backgroundResourceName)
                .allowsHitTesting(false)

            GameIcon(trumpIcon, size: 34)
                .padding(.top, selected ? 2 : 0)
        }
        .frame(width: 54, height: 54)
        .foregroundStyle(selected ? Color.kolkhozOnAccent : Color.kolkhozCreamDim)
        .shadow(color: selected ? Color.kolkhozRed.opacity(0.38) : Color.kolkhozGold.opacity(0.16), radius: selected ? 8 : 4, y: 3)
        .help(title)
    }

    private var backgroundResourceName: String {
        selected ? "ui-nav-button-active-current" : "ui-nav-button-inactive-current"
    }

    private var trumpIcon: GameIconAsset {
        switch suit {
        case .wheat: .trumpWheat
        case .sunflower: .trumpSunflower
        case .potato: .trumpPotato
        case .beet: .trumpBeet
        }
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
                .frame(width: 38, height: 42)

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
