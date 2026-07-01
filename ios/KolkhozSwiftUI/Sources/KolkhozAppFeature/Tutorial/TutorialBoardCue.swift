import SwiftUI

struct TutorialBoardCue: View {
    let icon: GameIconAsset
    var cornerRadius: CGFloat = 7
    @State private var pulsing = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.kolkhozGoldBright.opacity(pulsing ? 0.35 : 0.95), lineWidth: 2)
                .scaleEffect(pulsing ? 1.10 : 1)

            GameIcon(icon, size: 24)
                .background(Color.kolkhozBlack.opacity(0.74), in: RoundedRectangle(cornerRadius: 4))
                .offset(x: 8, y: -8)
        }
        .allowsHitTesting(false)
        .onAppear {
            pulsing = true
        }
        .animation(.easeInOut(duration: 0.78).repeatForever(autoreverses: true), value: pulsing)
    }
}

extension View {
    func tutorialBoardCue(
        active: Bool,
        icon: GameIconAsset = .tutorialCueTap,
        cornerRadius: CGFloat = 7
    ) -> some View {
        overlay {
            if active {
                TutorialBoardCue(icon: icon, cornerRadius: cornerRadius)
            }
        }
    }
}
