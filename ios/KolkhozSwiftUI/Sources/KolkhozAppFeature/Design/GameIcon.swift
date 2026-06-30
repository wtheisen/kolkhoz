import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum GameIconAsset: String {
    case menu = "icon-menu"
    case year1 = "icon-year-1"
    case year2 = "icon-year-2"
    case year3 = "icon-year-3"
    case year4 = "icon-year-4"
    case year5 = "icon-year-5"
    case brigade = "icon-brigade"
    case jobs = "icon-jobs"
    case north = "icon-north"
    case plot = "icon-plot"
    case language = "icon-language"
    case languageEN = "icon-language-en"
    case languageRU = "icon-language-ru"
    case appearance = "icon-appearance"
    case medalStar = "icon-medal-star"
    case check = "icon-check"
    case warning = "icon-warning"
    case playTap = "icon-play-tap"
    case humanSeat = "icon-human-seat"
    case basicAI = "icon-basic-ai"
    case neuralAI = "icon-neural-ai"
    case passDevice = "icon-pass-device"
    case famine = "icon-famine"
    case requisitionNorth = "icon-requisition-north"
    case neuralBadge = "icon-neural-badge"
    case rulesScroll = "icon-rules-scroll"
    case cropSeal = "icon-crop-seal"
    case panelMenu = "icon-panel-menu"
    case panelBrigade = "icon-panel-brigade"
    case panelJobs = "icon-panel-jobs"
    case panelNorth = "icon-panel-north"
    case panelPlot = "icon-panel-plot"
    case panelRules = "icon-panel-rules"
    case statusBrigadeLeader = "icon-status-brigade-leader"
    case statusCurrentTurn = "icon-status-current-turn"
    case statusAIThinking = "icon-status-ai-thinking"
    case statusProtected = "icon-status-protected"
    case statusRewardClaimed = "icon-status-reward-claimed"
    case statusVulnerable = "icon-status-vulnerable"
    case gears = "icon-gears"
    case wheat = "icon-wheat"
    case sunflower = "icon-sunflower"
    case potato = "icon-potato"
    case beet = "icon-beet"
    case trumpWheat = "icon-trump-wheat"
    case trumpSunflower = "icon-trump-sunflower"
    case trumpPotato = "icon-trump-potato"
    case trumpBeet = "icon-trump-beet"
    case cellar = "icon-cellar"
    case hand = "icon-hand"
}

struct GameIcon: View {
    let asset: GameIconAsset
    let size: CGFloat
    var muted = false

    init(_ asset: GameIconAsset, size: CGFloat, muted: Bool = false) {
        self.asset = asset
        self.size = size
        self.muted = muted
    }

    var body: some View {
        image
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFit()
            .frame(width: size, height: size)
            .saturation(muted ? 0.7 : 1)
            .opacity(muted ? 0.82 : 1)
            .accessibilityHidden(true)
    }

    private var image: Image {
        KolkhozResourceImageCache.image(for: [
            KolkhozResourceImageCandidate(asset.rawValue),
            KolkhozResourceImageCandidate(asset.rawValue, subdirectory: "Icons")
        ]) ?? Image(systemName: "square.fill")
    }
}
