import KolkhozCore
import SwiftUI

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
                .frame(width: 32, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.kolkhozBlack.opacity(0.68), lineWidth: 1)
                }
            VStack {
                HStack {
                    Spacer()
                    if human {
                        GameIcon(.medalStar, size: 9)
                    }
                }
                Spacer()
            }
            .padding(2)
        }
        .frame(width: 38, height: 42)
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
