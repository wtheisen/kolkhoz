import KolkhozCore
import SwiftUI

enum BoardPortraitLayout {
    static let opponentsSpacing: CGFloat = 8
    static let cornerRadius: CGFloat = 6
    static let imageCornerRadius: CGFloat = 3
    static let imageWidth: CGFloat = 32
    static let imageHeight: CGFloat = 36
    static let width: CGFloat = 38
    static let height: CGFloat = 42
    static let humanBadgeSize: CGFloat = 9
}

struct OpponentsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: BoardPortraitLayout.opponentsSpacing) {
            ForEach(store.state.players.dropFirst()) { player in
                PlayerPanel(
                    player: player,
                    score: store.visibleScore(for: player.id),
                    active: store.state.currentPlayer == player.id,
                    human: false
                )
            }
        }
    }
}

struct PortraitView: View {
    let player: PlayerState
    let human: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: human
                            ? [Color.kolkhozGold.opacity(0.42), Color.kolkhozRedDark.opacity(0.72)]
                            : [Color.kolkhozSteel.opacity(0.58), Color.kolkhozBlack.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            portraitImage
                .resizable()
                .interpolation(.none)
            .antialiased(false)
                .scaledToFill()
                .frame(width: BoardPortraitLayout.imageWidth, height: BoardPortraitLayout.imageHeight)
                .clipShape(RoundedRectangle(cornerRadius: BoardPortraitLayout.imageCornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: BoardPortraitLayout.imageCornerRadius)
                        .stroke(Color.kolkhozBlack.opacity(0.68), lineWidth: 1)
                }
            VStack {
                HStack {
                    Spacer()
                    if human {
                        GameIcon(.medalStar, size: BoardPortraitLayout.humanBadgeSize)
                    }
                }
                Spacer()
            }
            .padding(2)
        }
        .frame(width: BoardPortraitLayout.width, height: BoardPortraitLayout.height)
        .overlay {
            RoundedRectangle(cornerRadius: BoardPortraitLayout.cornerRadius)
                .stroke(human ? Color.kolkhozGold.opacity(0.95) : Color.kolkhozSteel.opacity(0.9), lineWidth: human ? 1.5 : 1)
        }
        .shadow(color: human ? Color.kolkhozGold.opacity(0.26) : .black.opacity(0.38), radius: human ? 6 : 4, y: 2)
    }

    var portraitImage: Image {
        KolkhozResourceImageCache.image(named: portraitName) ?? Image(systemName: "person.fill")
    }

    var portraitName: String {
        if player.isHuman {
            return "worker4"
        }
        let portraitIndex = ((max(player.id, 1) - 1) % 4) + 1
        return "worker\(portraitIndex)"
    }
}

#if DEBUG
#Preview("Portraits") {
    BoardPreviewStage {
        HStack(spacing: 18) {
            PortraitView(player: KolkhozPreviewFixtures.playerPanelHuman, human: true)
            PortraitView(player: KolkhozPreviewFixtures.playerPanelOpponent, human: false)
            PortraitView(player: KolkhozPreviewFixtures.trickState.players[2], human: false)
            PortraitView(player: KolkhozPreviewFixtures.trickState.players[3], human: false)
        }
    }
}

#Preview("Opponents") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 520, height: 92) {
        OpponentsView()
    }
}
#endif
