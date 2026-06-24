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

struct PortraitView: View {
    let player: PlayerState
    let human: Bool

    var body: some View {
        ZStack {
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
#endif
