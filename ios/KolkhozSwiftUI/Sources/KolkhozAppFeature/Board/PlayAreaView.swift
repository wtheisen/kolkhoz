import KolkhozCore
import SwiftUI

struct PlayAreaView: View {
    @EnvironmentObject private var store: GameStore
    let displayPanel: GamePanel
    let gameSafeInsets: EdgeInsets
    let onReturnToLobby: () -> Void
    let onNewGame: () -> Void
    @State private var activeEngineEvent: KolkhozAnimationEvent?
    @State private var activeEngineEventLanded = false
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
        ZStack {
            GeometryReader { proxy in
                playAreaShell
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

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

    private var playAreaShell: some View {
        VStack(spacing: 0) {
            TopInfoBarView(jobTargets: $jobTargets)
                .padding(.leading, gameSafeInsets.leading)
                .padding(.trailing, gameSafeInsets.trailing)

            ZStack {
                panelContent
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                ZStack {
                    Color.kolkhozTable
                    LinearGradient(
                        colors: [.kolkhozGold.opacity(0.04), .clear, .kolkhozRed.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.kolkhozRedDark.opacity(0.8), lineWidth: 2)
            }
            .padding(.leading, gameSafeInsets.leading)
            .padding(.trailing, gameSafeInsets.trailing)

            lowerHandBar
                .padding(.leading, 18 + gameSafeInsets.leading)
                .padding(.trailing, 24 + gameSafeInsets.trailing)
                .frame(height: handTrayHeight, alignment: .top)
                .zIndex(20)
        }
    }

    @ViewBuilder
    private var panelContent: some View {
        switch displayPanel {
        case .options:
            InGameOptionsPanel(
                onNewGame: onNewGame,
                onReturnToLobby: onReturnToLobby
            )
            .frame(maxWidth: 620)
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)

        case .brigade:
            BrigadeView(
                playSlotCenters: $playSlotCenters,
                playSlotFrames: $playSlotFrames,
                playerPanelCenters: $playerPanelCenters,
                hiddenPlayIDs: hiddenPlayIDs,
                showLastTrick: isResolvingWorkAssignmentAnimations
            )
            .padding(.horizontal, 0)
            .padding(.top, 8)
            .padding(.bottom, panelContentBottomPadding)

            if store.state.phase == .planning || store.state.phase == .gameOver {
                PhaseOverlayView()
                    .frame(maxWidth: 500)
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
            }

        case .jobs:
            JobsView(
                jobTargets: $jobTargets,
                jobTargetFrames: $jobTargetFrames,
                assignmentDrag: $assignmentDrag,
                hoveredSuit: $hoveredAssignmentSuit,
                selectedAssignmentCard: $selectedAssignmentCard,
                isAssignmentPhase: store.state.phase == .assignment,
                lastTrick: store.state.lastTrick,
                workHours: store.state.workHours,
                claimedJobs: store.state.claimedJobs,
                revealedJobs: store.state.revealedJobs,
                jobBuckets: store.state.jobBuckets,
                pendingAssignments: store.state.pendingAssignments,
                trump: store.state.trump,
                onAssign: store.assign(_:to:)
            )
            .padding(.horizontal, 0)
            .padding(.top, 8)
            .padding(.bottom, panelContentBottomPadding)

        case .north:
            NorthView(exiledByYear: store.state.exiled, currentYear: store.state.year)
                .padding(.horizontal, 0)
                .padding(.top, 8)
                .padding(.bottom, panelContentBottomPadding)

        case .plot:
            PlotStorageView(selectedPlot: store.state.phase == .swap ? $selectedSwapPlot : nil)
            .padding(.horizontal, 0)
            .padding(.top, 8)
            .padding(.bottom, panelContentBottomPadding)
        }
    }

    private var panelContentBottomPadding: CGFloat {
        10
    }

    private var lowerHandBar: some View {
        LowerHandBarView(
            playCard: animateAndPlay(_:from:),
            mode: handTrayMode,
            hand: store.state.players[0].hand,
            validCards: store.validCardsForHuman(),
            humanSwapStaged: store.state.swapCount.contains(0),
            lastTrick: store.state.lastTrick,
            pendingAssignments: store.state.pendingAssignments,
            year: store.state.year,
            hasPendingRequisitionAnimations: hasPendingRequisitionAnimations,
            selectedSwapHand: $selectedSwapHand,
            selectedSwapPlot: $selectedSwapPlot,
            assignmentDrag: $assignmentDrag,
            hoveredAssignmentSuit: $hoveredAssignmentSuit,
            selectedAssignmentCard: $selectedAssignmentCard,
            jobTargetFrames: jobTargetFrames,
            playDropFrame: playSlotFrames[0],
            onSwapSelection: swapAndConfirm(_:plotSelection:),
            onConfirmSwap: store.confirmSwap,
            onAssign: store.assign(_:to:),
            onSubmitAssignments: store.submitAssignments,
            onContinueAfterRequisition: store.continueAfterRequisition
        )
    }

    private var handTrayMode: LowerHandBarMode {
        if isResolvingCardPlayAnimations {
            return .passive
        }
        if store.state.phase == .trick && displayPanel == .brigade {
            return .trick
        }
        if store.state.phase == .swap {
            return .swap
        }
        if store.state.phase == .assignment {
            return .assignment
        }
        if store.state.phase == .requisition {
            return .requisition
        }
        return .passive
    }

    private var handTrayHeight: CGFloat {
        52
    }

    private var hasPendingRequisitionAnimations: Bool {
        store.animationEvents.contains { event in
            if case .cardExiled = event {
                return true
            }
            return false
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

    private func swapAndConfirm(_ handCard: Card, plotSelection: PlotSelection) {
        store.swap(
            handCard: handCard,
            plotCard: plotSelection.card,
            revealed: plotSelection.zone == .revealed
        )
        if store.state.swapCount.contains(0) {
            store.confirmSwap()
        }
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
                .scaleEffect(landed ? 0.88 : 0.52)
                .rotationEffect(.degrees(landed ? 0 : -5))
                .opacity(landed ? 0.76 : 1)
                .shadow(color: tint.opacity(0.55), radius: landed ? 10 : 18, y: landed ? 4 : 12)

            if let valueText, landed {
                PixelText(text: valueText, size: .cardRank, variant: .heavy, color: .kolkhozGold)
                    .shadow(color: .black, radius: 3)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .offset(y: 54)
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
                .offset(y: -48)
                .opacity(landed ? 1 : 0)
        }
        .scaleEffect(landed ? 1 : 0.75)
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
                .offset(y: 48)
                .opacity(landed ? 1 : 0)
        }
        .scaleEffect(landed ? 0.72 : 1)
        .rotationEffect(.degrees(landed ? -18 : 4))
        .opacity(landed ? 0.65 : 1)
        .position(landed ? target : source)
        .shadow(color: Color.kolkhozRedBright.opacity(0.55), radius: 16, y: 8)
        .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Landscape Game Area") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 430) {
        PlayAreaView(
            displayPanel: .brigade,
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
