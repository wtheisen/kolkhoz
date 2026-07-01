import KolkhozCore
import SwiftUI

enum LowerHandBarMode {
    case passive
    case trick
    case swap
    case assignment
    case requisition
}

struct SwapCommandButtonStyle: ButtonStyle {
    let prominent: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.kolkhozTitle(.caption))
            .textCase(.uppercase)
            .foregroundStyle(prominent ? Color.kolkhozOnAccent : Color.kolkhozCream)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, prominent ? 20 : 16)
            .padding(.top, prominent ? 8 : 7)
            .padding(.bottom, prominent ? 6 : 5)
            .frame(minWidth: prominent ? 132 : 88, minHeight: prominent ? 36 : 32)
            .background {
                GeneratedChromeImage(resourceName: prominent ? "ui-button-primary" : "ui-button-secondary")
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .shadow(color: .black.opacity(prominent ? 0.28 : 0.18), radius: prominent ? 5 : 3, y: 2)
    }
}

struct LowerHandBarView: View {
    @Environment(\.kolkhozLanguage) private var language
    let playCard: (Card, CGPoint) -> Void
    let mode: LowerHandBarMode
    let hand: [Card]
    let validCards: Set<Card>
    let trump: Suit?
    let humanSwapStaged: Bool
    let lastTrick: [TrickPlay]
    let pendingAssignments: [String: Suit]
    let year: Int
    let hasPendingRequisitionAnimations: Bool
    @Binding var selectedSwapHand: Card?
    @Binding var selectedSwapPlot: PlotSelection?
    @Binding var assignmentDrag: AssignmentDragState?
    @Binding var hoveredAssignmentSuit: Suit?
    @Binding var selectedAssignmentCard: Card?
    let jobTargetFrames: [Suit: CGRect]
    let playDropFrame: CGRect?
    let tutorialAction: TutorialRequiredAction
    let onTutorialAction: (TutorialRequiredAction) -> Void
    let onSwapSelection: (Card, PlotSelection) -> Void
    let onConfirmSwap: () -> Void
    let onUndoSwap: () -> Void
    let onAssign: (Card, Suit) -> Void
    let onSubmitAssignments: () -> Void
    let onContinueAfterRequisition: () -> Void
    @State private var draggingHandCardID: String?
    @State private var handDragTranslation: CGSize = .zero

    private var trayCardSize: CardSize {
        .large
    }

    private var visibleTrayHeight: CGFloat {
        66
    }

    private var orderedHand: [Card] {
        hand.sorted(by: isCardSortedBefore(_:_:))
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            handTrayZone

            if mode == .swap {
                swapControls
                    .frame(width: 268, height: visibleTrayHeight)
            }

            if mode == .assignment && !allAssignmentCardsAssigned {
                assignmentControls
                    .frame(width: 290, height: visibleTrayHeight)
            }

            if mode == .assignment && allAssignmentCardsAssigned {
                assignmentSubmitControls
                    .frame(width: 150, height: visibleTrayHeight)
            }

            if mode == .requisition {
                requisitionControls
                    .frame(width: 150, height: visibleTrayHeight)
            }
        }
        .frame(height: visibleTrayHeight)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 16)
    }

    private var handTrayZone: some View {
        HStack(alignment: .top, spacing: 6) {
            GameIcon(.hand, size: 32)
                .accessibilityLabel(language.text(en: "Hand", ru: "Рука"))
                .frame(width: 34, height: visibleTrayHeight, alignment: .top)

            handCards
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 6)
        .frame(height: visibleTrayHeight, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.12), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(0.32), lineWidth: 1)
        }
    }

    private var handCards: some View {
        HStack(alignment: .top, spacing: handCardSpacing) {
            let cards = orderedHand
            ForEach(cards) { card in
                let isPlayable = validCards.contains(card)
                let isTrickPlayable = mode == .trick && isPlayable
                let isSwapSelectable = mode == .swap && !humanSwapStaged
                let isReordering = draggingHandCardID == card.id
                if mode == .trick {
                    CardButton(
                        card: card,
                        selected: false,
                        size: trayCardSize,
                        trump: trump,
                        highlighted: isTrickPlayable,
                        highlightColor: playableHighlightColor(for: card),
                        positionedAction: isTrickPlayable ? { startCenter in
                            playTutorialCard(card, from: startCenter)
                        } : nil,
                        dragAction: isTrickPlayable ? { startCenter in
                            playTutorialCard(card, from: startCenter)
                        } : nil,
                        dragChanged: { card, _, translation in
                            if isTrickPlayable && isPlayDragPreview(translation) {
                                draggingHandCardID = card.id
                                handDragTranslation = translation
                            }
                        },
                        dragEnded: { card, startCenter, translation in
                            if isTrickPlayable && shouldPlayDroppedCard(startCenter: startCenter, translation: translation) {
                                playTutorialCard(card, from: startCenter)
                            }
                            resetHandDrag()
                        }
                    ) {
                        if isTrickPlayable {
                            playTutorialCard(card, from: .zero)
                        }
                    }
                    .tutorialBoardCue(active: tutorialAction == .playCard(card) && isTrickPlayable, icon: .tutorialCueCard)
                    .handCardPhysicalStyle(active: isReordering, translation: handDragTranslation)
                } else {
                    Button {
                        if isSwapSelectable {
                            selectedSwapHand = card
                        }
                    } label: {
                        CardView(card: card, size: trayCardSize, trump: trump)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(
                                        mode == .swap && selectedSwapHand == card ? Color.kolkhozGreen : (isSwapSelectable ? Color.kolkhozRed : Color.clear),
                                        lineWidth: mode == .swap && selectedSwapHand == card ? 3 : (isSwapSelectable ? 2 : 0)
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSwapSelectable)
                    .opacity(1)
                    .handCardPhysicalStyle(active: isReordering, translation: handDragTranslation)
                }
            }
        }
        .padding(.horizontal, 2)
        .offset(y: 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: visibleTrayHeight)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: orderedHand.map(\.id))
        .onChange(of: hand.map(\.id)) { _, _ in
            if let draggingHandCardID, !hand.contains(where: { $0.id == draggingHandCardID }) {
                resetHandDrag()
            }
        }
    }

    private var handCardSpacing: CGFloat {
        10
    }

    private func playableHighlightColor(for card: Card) -> Color {
        card.suit == trump ? .kolkhozRed : .kolkhozCream
    }

    private func isCardSortedBefore(_ lhs: Card, _ rhs: Card) -> Bool {
        let lhsSuit = suitSortIndex(lhs.suit)
        let rhsSuit = suitSortIndex(rhs.suit)
        if lhsSuit != rhsSuit {
            return lhsSuit < rhsSuit
        }
        return lhs.value < rhs.value
    }

    private func suitSortIndex(_ suit: Suit) -> Int {
        Suit.allCases.firstIndex(of: suit) ?? Suit.allCases.count
    }

    private func isPlayDragPreview(_ translation: CGSize) -> Bool {
        translation.height < -8
    }

    private func shouldPlayDroppedCard(startCenter: CGPoint, translation: CGSize) -> Bool {
        let finalCenter = CGPoint(
            x: startCenter.x + translation.width,
            y: startCenter.y + translation.height
        )
        if let playDropFrame {
            let expandedDropFrame = playDropFrame.insetBy(dx: -44, dy: -44)
            if expandedDropFrame.contains(finalCenter) {
                return true
            }

            let liftedAboveTray = translation.height < -64 && finalCenter.y < expandedDropFrame.maxY
            if liftedAboveTray {
                return true
            }
        }
        return translation.height < -72 && abs(translation.height) > abs(translation.width) * 0.35
    }

    private func resetHandDrag() {
        draggingHandCardID = nil
        handDragTranslation = .zero
    }

    private func playTutorialCard(_ card: Card, from startCenter: CGPoint) {
        playCard(card, startCenter)
        onTutorialAction(.playCard(card))
    }

    private var assignmentControls: some View {
        HStack(alignment: .top, spacing: 10) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, .kolkhozGold.opacity(0.8), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2, height: visibleTrayHeight - 10)
                .padding(.top, 5)

            HStack(alignment: .top, spacing: 8) {
                ForEach(unassignedAssignmentPlays) { play in
                    AssignmentCapturedCard(
                        play: play,
                        assignedSuit: pendingAssignments[play.card.id],
                        selected: selectedAssignmentCard == play.card,
                        dragging: assignmentDrag?.card == play.card,
                        trump: trump,
                        onDragChanged: updateAssignmentDrag(_:startCenter:translation:),
                        onDragEnded: finishAssignmentDrag(_:translation:),
                        onTapSelect: { selectAssignmentCard(play.card) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: 4)
        }
    }

    private var assignmentSubmitControls: some View {
        Button(language.text(en: "Confirm", ru: "Подтвердить")) {
            onSubmitAssignments()
        }
        .buttonStyle(SwapCommandButtonStyle(prominent: true))
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var unassignedAssignmentPlays: [TrickPlay] {
        lastTrick.filter { pendingAssignments[$0.card.id] == nil }
    }

    private var allAssignmentCardsAssigned: Bool {
        mode == .assignment &&
            !lastTrick.isEmpty &&
            pendingAssignments.count == lastTrick.count
    }

    private var legalAssignmentTargets: Set<Suit> {
        Set(lastTrick.map(\.card.suit))
    }

    private func updateAssignmentDrag(_ card: Card, startCenter: CGPoint, translation: CGSize) {
        let drag = AssignmentDragState(card: card, startCenter: startCenter, translation: translation)
        assignmentDrag = drag
        hoveredAssignmentSuit = drag.targetSuit(in: jobTargetFrames, legalTargets: legalAssignmentTargets)
    }

    private func finishAssignmentDrag(_ card: Card, translation: CGSize) {
        defer {
            assignmentDrag = nil
            hoveredAssignmentSuit = nil
        }
        guard let drag = assignmentDrag else { return }
        if let target = drag.targetSuit(in: jobTargetFrames, legalTargets: legalAssignmentTargets) {
            onAssign(card, target)
            selectedAssignmentCard = nextUnassignedAssignmentCard(after: card)
        }
    }

    private func selectAssignmentCard(_ card: Card) {
        selectedAssignmentCard = selectedAssignmentCard == card ? nil : card
    }

    private func nextUnassignedAssignmentCard(after card: Card) -> Card? {
        lastTrick
            .map(\.card)
            .first { $0 != card && pendingAssignments[$0.id] == nil }
    }

    private var swapControls: some View {
        HStack(spacing: 8) {
            Button(swapActionTitle) {
                performSwapAction()
            }
            .buttonStyle(SwapCommandButtonStyle(prominent: false))
            .disabled(!canPerformSwapAction)
            .opacity(canPerformSwapAction ? 1 : 0.45)

            Button(language.text(en: "Confirm", ru: "Подтвердить")) {
                onConfirmSwap()
                selectedSwapHand = nil
                selectedSwapPlot = nil
            }
            .buttonStyle(SwapCommandButtonStyle(prominent: true))
        }
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var swapActionTitle: String {
        humanSwapStaged ? language.text(en: "Undo", ru: "Отменить") : language.text(en: "Swap", ru: "Обмен")
    }

    private var canPerformSwapAction: Bool {
        humanSwapStaged || (selectedSwapHand != nil && selectedSwapPlot != nil)
    }

    private func performSwapAction() {
        if humanSwapStaged {
            onUndoSwap()
        } else if let selectedSwapHand, let selectedSwapPlot {
            onSwapSelection(selectedSwapHand, selectedSwapPlot)
        }
        selectedSwapHand = nil
        selectedSwapPlot = nil
    }

    private var requisitionControls: some View {
        Button(requisitionContinueTitle) {
            onContinueAfterRequisition()
        }
        .buttonStyle(SwapCommandButtonStyle(prominent: true))
        .disabled(hasPendingRequisitionAnimations)
        .opacity(hasPendingRequisitionAnimations ? 0.45 : 1)
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var requisitionContinueTitle: String {
        if hasPendingRequisitionAnimations {
            return language.text(en: "Resolving", ru: "Идёт")
        }
        if year >= 5 {
            return language.text(en: "Finish", ru: "Завершить")
        }
        return language.text(en: "Year \(year + 1)", ru: "Год \(year + 1)")
    }
}

private extension View {
    func handCardPhysicalStyle(active: Bool, translation: CGSize) -> some View {
        self
            .offset(active ? translation : .zero)
            .rotationEffect(.degrees(active ? Double(max(-7, min(7, translation.width / 18))) : 0))
            .scaleEffect(active ? 1.08 : 1)
            .shadow(color: .black.opacity(active ? 0.44 : 0.16), radius: active ? 12 : 4, y: active ? 7 : 2)
            .zIndex(active ? 30 : 0)
    }
}

#if DEBUG
#Preview("Hand Tray - Trick") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 720, height: 112) {
        LowerHandBarPreviewHost(mode: .trick)
    }
}

#Preview("Hand Tray - Swap") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 760, height: 112) {
        LowerHandBarPreviewHost(mode: .swap)
    }
}

#Preview("Hand Tray - Assignment") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 820, height: 120) {
        LowerHandBarPreviewHost(mode: .assignment)
    }
}

#Preview("Hand Tray - Requisition") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.requisitionState, width: 820, height: 112) {
        LowerHandBarPreviewHost(mode: .requisition)
    }
}

private struct LowerHandBarPreviewHost: View {
    @EnvironmentObject private var store: GameStore
    let mode: LowerHandBarMode
    @State private var selectedSwapHand: Card?
    @State private var selectedSwapPlot: PlotSelection?
    @State private var assignmentDrag: AssignmentDragState?
    @State private var hoveredAssignmentSuit: Suit?
    @State private var selectedAssignmentCard: Card?

    var body: some View {
        LowerHandBarView(
            playCard: { _, _ in },
            mode: mode,
            hand: store.state.players[0].hand,
            validCards: store.validCardsForHuman(),
            trump: store.state.trump,
            humanSwapStaged: store.state.swapCount.contains(0),
            lastTrick: store.state.lastTrick,
            pendingAssignments: store.state.pendingAssignments,
            year: store.state.year,
            hasPendingRequisitionAnimations: store.animationEvents.contains { event in
                if case .cardExiled = event {
                    return true
                }
                return false
            },
            selectedSwapHand: $selectedSwapHand,
            selectedSwapPlot: $selectedSwapPlot,
            assignmentDrag: $assignmentDrag,
            hoveredAssignmentSuit: $hoveredAssignmentSuit,
            selectedAssignmentCard: $selectedAssignmentCard,
            jobTargetFrames: [:],
            playDropFrame: nil,
            tutorialAction: .none,
            onTutorialAction: { _ in },
            onSwapSelection: { _, _ in },
            onConfirmSwap: {},
            onUndoSwap: {},
            onAssign: { _, _ in },
            onSubmitAssignments: {},
            onContinueAfterRequisition: {}
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
