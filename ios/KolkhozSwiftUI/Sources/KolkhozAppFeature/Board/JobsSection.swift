import KolkhozCore
import SwiftUI

enum JobsSectionLayout {
    static let stripSpacing: CGFloat = 8
    static let tileMinHeight: CGFloat = 98
    static let tilePadding: CGFloat = 8
    static let tileCornerRadius: CGFloat = 4
}

struct JobsStripView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: JobsSectionLayout.stripSpacing) {
            ForEach(Suit.allCases) { suit in
                JobTile(
                    suit: suit,
                    hours: store.state.workHours[suit, default: 0],
                    claimed: store.state.claimedJobs.contains(suit),
                    reward: store.state.revealedJobs[suit],
                    assignedCount: store.state.jobBuckets[suit, default: []].count,
                    highlighted: store.state.trump == suit
                )
            }
        }
    }
}

struct JobTile: View {
    @Environment(\.kolkhozLanguage) private var language
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let reward: Card?
    let assignedCount: Int
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                SuitBadge(suit: suit, compact: true)
                if highlighted {
                    GameIcon(.medalStar, size: 13)
                }
                Spacer()
                PixelText(
                    text: claimed ? language.text(en: "DONE", ru: "ГОТОВО") : "\(hours)/40",
                    size: .caption2,
                    variant: .heavy,
                    color: claimed ? Color.kolkhozGreen : Color.kolkhozGold
                )
            }

            ProgressBar(value: min(Double(hours) / 40.0, 1), complete: claimed)

            HStack(spacing: 6) {
                if let reward {
                    MiniRewardCard(card: reward, claimed: claimed)
                } else {
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.kolkhozGreen.opacity(0.7), lineWidth: 1)
                        .frame(width: 24, height: 34)
                        .overlay {
                            GameIcon(.check, size: 18)
                        }
                }
                VStack(alignment: .leading, spacing: 2) {
                    PixelText(text: language.text(en: "\(assignedCount) cards", ru: "\(assignedCount) карт"), size: .caption2, color: .kolkhozCreamDim)
                    PixelText(text: claimed ? language.text(en: "Claimed", ru: "Выполнено") : language.text(en: "Drop target", ru: "Цель"), size: .caption2, color: .kolkhozSmoke)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: JobsSectionLayout.tileMinHeight)
        .padding(JobsSectionLayout.tilePadding)
        .background(
            LinearGradient(
                colors: highlighted
                    ? [Color.kolkhozGold.opacity(0.18), Color.kolkhozPanel]
                    : [Color.kolkhozPanel, Color.kolkhozIron],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: JobsSectionLayout.tileCornerRadius)
        )
        .overlay {
            RoundedRectangle(cornerRadius: JobsSectionLayout.tileCornerRadius)
                .stroke(claimed ? Color.kolkhozGreen : Color.kolkhozGold.opacity(highlighted ? 1 : 0.75), lineWidth: highlighted ? 2 : 1.5)
        }
        .opacity(claimed ? 0.72 : 1)
        .animation(.easeInOut(duration: 0.28), value: hours)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: claimed)
    }
}

#if DEBUG
#Preview("Jobs Strip") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 720, height: 150) {
        JobsStripView()
    }
}

#Preview("Job Tile States") {
    BoardPreviewStage(width: 680, height: 150) {
        HStack(spacing: JobsSectionLayout.stripSpacing) {
            JobTile(
                suit: .wheat,
                hours: 17,
                claimed: false,
                reward: Card(suit: .wheat, value: 3),
                assignedCount: 1,
                highlighted: true
            )
            JobTile(
                suit: .sunflower,
                hours: 40,
                claimed: true,
                reward: Card(suit: .sunflower, value: 4),
                assignedCount: 4,
                highlighted: false
            )
            JobTile(
                suit: .potato,
                hours: 8,
                claimed: false,
                reward: nil,
                assignedCount: 0,
                highlighted: false
            )
        }
    }
}
#endif
