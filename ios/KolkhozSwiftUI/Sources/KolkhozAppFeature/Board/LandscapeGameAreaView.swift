import KolkhozCore
import SwiftUI

enum LandscapeGameAreaLayout {
    static let shellHorizontalPadding: CGFloat = 8
    static let shellTopPadding: CGFloat = 8
    static let handTrayLeadingPadding: CGFloat = 18
    static let handTrayTrailingPadding: CGFloat = 24
    static let trickHandTrayHeight: CGFloat = 78
    static let swapHandTrayHeight: CGFloat = 78
    static let assignmentHandTrayHeight: CGFloat = 82
    static let passiveHandTrayHeight: CGFloat = 70
}

enum EngineFlightLayout {
    static let cardStartScale: CGFloat = 0.52
    static let cardLandedScale: CGFloat = 0.88
    static let cardStartRotation: CGFloat = -5
    static let cardLandedOpacity: CGFloat = 0.76
    static let valueOffsetY: CGFloat = 54
    static let rewardStartScale: CGFloat = 0.75
    static let rewardLabelOffsetY: CGFloat = -48
    static let exileLandedScale: CGFloat = 0.72
    static let exileStartRotation: CGFloat = 4
    static let exileLandedRotation: CGFloat = -18
    static let exileLandedOpacity: CGFloat = 0.65
    static let exileLabelOffsetY: CGFloat = 48
}

struct LandscapeGameAreaView: View {
    @EnvironmentObject private var store: GameStore
    let displayPanel: GamePanel
    let gameSafeInsets: EdgeInsets
    let onReturnToLobby: () -> Void
    let onNewGame: () -> Void
    @State private var activeEngineEvent: KolkhozAnimationEvent?
    @State private var activeEngineEventLanded = false
    @State private var humanPlayTarget: CGPoint?
    @State private var playSlotCenters: [Int: CGPoint] = [:]
    @State private var playSlotFrames: [Int: CGRect] = [:]
    @State private var playerPanelCenters: [Int: CGPoint] = [:]
    @State private var jobTargets: [Suit: CGPoint] = [:]
    @State private var jobTargetFrames: [Suit: CGRect] = [:]
    @State private var selectedSwapHand: Card?
    @State private var selectedSwapPlot: PlotSelection?
    @State private var assignmentDrag: AssignmentDragState?
    @State private var hoveredAssignmentSuit: Suit?
    @State private var selectedAssignmentCard: Card?
    @State private var assignedFlightPlayIDs: Set<String> = []

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { proxy in
                TrickAreaShellView(
                    displayPanel: displayPanel,
                    onReturnToLobby: onReturnToLobby,
                    onNewGame: onNewGame,
                    humanPlayTarget: $humanPlayTarget,
                    playSlotCenters: $playSlotCenters,
                    playSlotFrames: $playSlotFrames,
                    playerPanelCenters: $playerPanelCenters,
                    jobTargets: $jobTargets,
                    jobTargetFrames: $jobTargetFrames,
                    assignmentDrag: $assignmentDrag,
                    hoveredAssignmentSuit: $hoveredAssignmentSuit,
                    selectedAssignmentCard: $selectedAssignmentCard,
                    hiddenPlayIDs: hiddenPlayIDs,
                    showLastTrick: isResolvingWorkAssignmentAnimations,
                    gameSafeInsets: gameSafeInsets,
                    selectedSwapPlot: $selectedSwapPlot
                )
                .padding(.horizontal, LandscapeGameAreaLayout.shellHorizontalPadding)
                .padding(.top, LandscapeGameAreaLayout.shellTopPadding)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if showsHandTray {
                PlayerHandTrayView(
                    playCard: animateAndPlay(_:from:),
                    mode: handTrayMode,
                    selectedSwapHand: $selectedSwapHand,
                    selectedSwapPlot: $selectedSwapPlot,
                    assignmentDrag: $assignmentDrag,
                    hoveredAssignmentSuit: $hoveredAssignmentSuit,
                    selectedAssignmentCard: $selectedAssignmentCard,
                    jobTargetFrames: jobTargetFrames,
                    playDropFrame: playSlotFrames[0]
                )
                .padding(.leading, LandscapeGameAreaLayout.handTrayLeadingPadding + gameSafeInsets.leading)
                .padding(.trailing, LandscapeGameAreaLayout.handTrayTrailingPadding + gameSafeInsets.trailing)
                .frame(height: handTrayHeight)
                .zIndex(10)
            }

            if let activeEngineEvent {
                engineAnimationOverlay(for: activeEngineEvent)
                    .zIndex(70)
            }

            if let assignmentDrag {
                AssignmentDragGhost(drag: assignmentDrag, canDrop: hoveredAssignmentSuit != nil)
                    .zIndex(80)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
        .onChange(of: store.animationEvents.map(\.id)) { _, _ in
            processNextEngineAnimation()
        }
        .onAppear {
            processNextEngineAnimation()
        }
        .onChange(of: store.state.phase) { _, _ in
            selectedSwapHand = nil
            selectedSwapPlot = nil
            assignmentDrag = nil
            hoveredAssignmentSuit = nil
            selectedAssignmentCard = nil
        }
        .onChange(of: store.state.lastTrick.map(\.id)) { _, _ in
            assignedFlightPlayIDs = []
        }
        .onChange(of: displayPanel) { _, _ in
            if store.state.phase != .swap {
                selectedSwapHand = nil
                selectedSwapPlot = nil
            }
        }
    }

    private var showsHandTray: Bool {
        if isResolvingCardPlayAnimations {
            return false
        }
        return displayPanel == .game || store.state.phase == .swap || store.state.phase == .assignment
    }

    private var handTrayMode: PlayerHandTrayMode {
        if isResolvingCardPlayAnimations {
            return .passive
        }
        if store.state.phase == .trick && displayPanel == .game {
            return .trick
        }
        if store.state.phase == .swap {
            return .swap
        }
        if store.state.phase == .assignment {
            return .assignment
        }
        return .passive
    }

    private var handTrayHeight: CGFloat {
        switch handTrayMode {
        case .trick:
            return LandscapeGameAreaLayout.trickHandTrayHeight
        case .swap:
            return LandscapeGameAreaLayout.swapHandTrayHeight
        case .assignment:
            return LandscapeGameAreaLayout.assignmentHandTrayHeight
        case .passive:
            return LandscapeGameAreaLayout.passiveHandTrayHeight
        }
    }

    private var isResolvingCardPlayAnimations: Bool {
        store.animationEvents.contains(where: isQueuedAICardPlay(_:)) ||
            activeEngineEvent.map(isQueuedAICardPlay(_:)) == true
    }

    private var isResolvingWorkAssignmentAnimations: Bool {
        store.animationEvents.contains(where: isWorkAssignment(_:)) ||
            activeEngineEvent.map(isWorkAssignment(_:)) == true
    }

    private var hiddenPlayIDs: Set<String> {
        var ids = assignedFlightPlayIDs
        for event in store.animationEvents {
            if shouldHidePlayedCard(for: event),
               case .cardPlayed(_, let playerID, let card) = event {
                ids.insert(playID(playerID: playerID, card: card))
            }
        }
        if let activeEngineEvent,
           shouldHidePlayedCard(for: activeEngineEvent),
           case .cardPlayed(_, let playerID, let card) = activeEngineEvent {
            ids.insert(playID(playerID: playerID, card: card))
        }
        if let activeEngineEvent,
           case .workAssigned(_, let playerID, let card, _, _) = activeEngineEvent {
            ids.insert(playID(playerID: playerID, card: card))
        }
        return ids
    }

    private func shouldHidePlayedCard(for event: KolkhozAnimationEvent) -> Bool {
        guard case .cardPlayed(_, let playerID, let card) = event,
              playerID != 0 else {
            return false
        }
        return visibleTrickContains(playerID: playerID, card: card)
    }

    private func isQueuedAICardPlay(_ event: KolkhozAnimationEvent) -> Bool {
        guard case .cardPlayed(_, let playerID, let card) = event,
              playerID != 0 else {
            return false
        }
        return visibleTrickContains(playerID: playerID, card: card)
    }

    private func visibleTrickContains(playerID: Int, card: Card) -> Bool {
        (store.state.currentTrick + store.state.lastTrick)
            .contains { $0.playerID == playerID && $0.card == card }
    }

    private func isWorkAssignment(_ event: KolkhozAnimationEvent) -> Bool {
        if case .workAssigned = event {
            return true
        }
        return false
    }

    private func animateAndPlay(_ card: Card, from _: CGPoint) {
        store.play(card)
    }

    private func processNextEngineAnimation() {
        guard activeEngineEvent == nil else { return }
        guard let event = store.animationEvents.first else { return }

        guard shouldAnimate(event) else {
            store.consumeAnimationEvent(event.id)
            DispatchQueue.main.async {
                processNextEngineAnimation()
            }
            return
        }

        if case .workAssigned(_, let playerID, let card, _, _) = event {
            assignedFlightPlayIDs.insert(playID(playerID: playerID, card: card))
        }

        activeEngineEvent = event
        activeEngineEventLanded = false

        DispatchQueue.main.async {
            withAnimation(.timingCurve(0.18, 0.88, 0.18, 1.0, duration: eventDuration(event))) {
                activeEngineEventLanded = true
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + eventDuration(event) + 0.18) {
            store.consumeAnimationEvent(event.id)
            if activeEngineEvent?.id == event.id {
                activeEngineEvent = nil
                activeEngineEventLanded = false
            }
            processNextEngineAnimation()
        }
    }

    private func shouldAnimate(_ event: KolkhozAnimationEvent) -> Bool {
        switch event {
        case .cardPlayed(_, let playerID, _):
            return isQueuedAICardPlay(event) &&
                playerPanelCenters[playerID] != nil &&
                playSlotCenters[playerID] != nil
        case .workAssigned(_, let playerID, _, let targetSuit, _):
            return playSlotCenters[playerID] != nil && jobTargets[targetSuit] != nil
        case .jobClaimed(_, let winnerID, let suit, _):
            return jobTargets[suit] != nil && playerPanelCenters[winnerID] != nil
        case .cardExiled(_, let playerID, let suit, _):
            return playerID.flatMap { playerPanelCenters[$0] } != nil || jobTargets[suit] != nil
        }
    }

    @ViewBuilder
    private func engineAnimationOverlay(for event: KolkhozAnimationEvent) -> some View {
        switch event {
        case .cardPlayed(_, let playerID, let card):
            if let source = playerPanelCenters[playerID], let target = playSlotCenters[playerID] {
                EngineFlyingCardView(
                    card: card,
                    source: source,
                    target: target,
                    landed: activeEngineEventLanded,
                    tint: .kolkhozRedBright
                )
            }
        case .workAssigned(_, let playerID, let card, let targetSuit, let value):
            if let source = playSlotCenters[playerID], let target = jobTargets[targetSuit] {
                EngineFlyingCardView(
                    card: card,
                    source: source,
                    target: target,
                    landed: activeEngineEventLanded,
                    tint: .kolkhozGold,
                    valueText: "+\(value)"
                )
            }
        case .jobClaimed(_, let winnerID, let suit, let reward):
            if let source = jobTargets[suit], let target = playerPanelCenters[winnerID] {
                RewardFlightView(
                    reward: reward,
                    suit: suit,
                    source: source,
                    target: target,
                    landed: activeEngineEventLanded
                )
            }
        case .cardExiled(_, let playerID, let suit, let card):
            let source = playerID.flatMap { playerPanelCenters[$0] } ?? jobTargets[suit]
            if let source {
                ExileFlightView(
                    card: card,
                    suit: suit,
                    source: source,
                    target: CGPoint(x: 18, y: 64),
                    landed: activeEngineEventLanded
                )
            }
        }
    }
}

enum GameBoardCoordinateSpace {
    static let main = "kolkhoz-game-area"
}

private func playID(playerID: Int, card: Card) -> String {
    "\(playerID)-\(card.id)"
}

private func eventDuration(_ event: KolkhozAnimationEvent) -> TimeInterval {
    switch event {
    case .cardPlayed:
        0.44
    case .workAssigned:
        0.58
    case .jobClaimed:
        0.54
    case .cardExiled:
        0.62
    }
}

struct EngineFlyingCardView: View {
    let card: Card
    let source: CGPoint
    let target: CGPoint
    let landed: Bool
    let tint: Color
    var valueText: String?

    private var center: CGPoint { landed ? target : source }

    var body: some View {
        ZStack {
            CardView(card: card, size: .large)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(tint, lineWidth: 3)
                }
                .scaleEffect(landed ? EngineFlightLayout.cardLandedScale : EngineFlightLayout.cardStartScale)
                .rotationEffect(.degrees(landed ? 0 : EngineFlightLayout.cardStartRotation))
                .opacity(landed ? EngineFlightLayout.cardLandedOpacity : 1)
                .shadow(color: tint.opacity(0.55), radius: landed ? 10 : 18, y: landed ? 4 : 12)

            if let valueText, landed {
                PixelText(text: valueText, size: .cardRank, variant: .heavy, color: .kolkhozGold)
                    .shadow(color: .black, radius: 3)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .offset(y: EngineFlightLayout.valueOffsetY)
            }
        }
        .position(center)
        .allowsHitTesting(false)
    }
}

struct RewardFlightView: View {
    @Environment(\.kolkhozLanguage) private var language
    let reward: Card?
    let suit: Suit
    let source: CGPoint
    let target: CGPoint
    let landed: Bool

    var body: some View {
        ZStack {
            if let reward {
                CardView(card: reward, size: .medium)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.kolkhozGreen, lineWidth: 3)
                    }
            } else {
                ZStack {
                    Circle().fill(Color.kolkhozGreen.opacity(0.9))
                    SuitMark(suit: suit, size: 26)
                }
                .frame(width: 58, height: 58)
            }
            PixelText(text: language.text(en: "CLAIMED", ru: "ГОТОВО"), size: .caption2, variant: .heavy, color: .kolkhozGreen)
                .shadow(color: .black, radius: 3)
                .offset(y: EngineFlightLayout.rewardLabelOffsetY)
                .opacity(landed ? 1 : 0)
        }
        .scaleEffect(landed ? 1 : EngineFlightLayout.rewardStartScale)
        .position(landed ? target : source)
        .shadow(color: Color.kolkhozGreen.opacity(0.55), radius: 16, y: 8)
        .allowsHitTesting(false)
    }
}

struct ExileFlightView: View {
    @Environment(\.kolkhozLanguage) private var language
    let card: Card?
    let suit: Suit
    let source: CGPoint
    let target: CGPoint
    let landed: Bool

    var body: some View {
        ZStack {
            if let card {
                CardView(card: card, size: .medium)
                    .overlay {
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(Color.kolkhozRedBright, lineWidth: 3)
                    }
            } else {
                ZStack {
                    Circle().fill(Color.kolkhozRedDark)
                    SuitMark(suit: suit, size: 24)
                }
                .frame(width: 54, height: 54)
            }

            PixelText(text: language.text(en: "NORTH", ru: "СЕВЕР"), size: .caption2, variant: .heavy, color: .kolkhozRedBright)
                .shadow(color: .black, radius: 3)
                .offset(y: EngineFlightLayout.exileLabelOffsetY)
                .opacity(landed ? 1 : 0)
        }
        .scaleEffect(landed ? EngineFlightLayout.exileLandedScale : 1)
        .rotationEffect(.degrees(landed ? EngineFlightLayout.exileLandedRotation : EngineFlightLayout.exileStartRotation))
        .opacity(landed ? EngineFlightLayout.exileLandedOpacity : 1)
        .position(landed ? target : source)
        .shadow(color: Color.kolkhozRedBright.opacity(0.55), radius: 16, y: 8)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Landscape Game Area") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 430) {
        LandscapeGameAreaView(
            displayPanel: .game,
            gameSafeInsets: EdgeInsets(),
            onReturnToLobby: {},
            onNewGame: {}
        )
    }
}

#Preview("Engine Flight Cards") {
    BoardPreviewStage(width: 640, height: 240) {
        ZStack {
            EngineFlyingCardView(
                card: Card(suit: .wheat, value: 12),
                source: CGPoint(x: 90, y: 120),
                target: CGPoint(x: 220, y: 120),
                landed: false,
                tint: .kolkhozRedBright
            )
            EngineFlyingCardView(
                card: Card(suit: .sunflower, value: 9),
                source: CGPoint(x: 250, y: 120),
                target: CGPoint(x: 370, y: 120),
                landed: true,
                tint: .kolkhozGold,
                valueText: "+9"
            )
            RewardFlightView(
                reward: Card(suit: .potato, value: 5),
                suit: .potato,
                source: CGPoint(x: 420, y: 120),
                target: CGPoint(x: 500, y: 120),
                landed: true
            )
            ExileFlightView(
                card: Card(suit: .beet, value: 12),
                suit: .beet,
                source: CGPoint(x: 540, y: 120),
                target: CGPoint(x: 600, y: 120),
                landed: true
            )
        }
    }
}
#endif
