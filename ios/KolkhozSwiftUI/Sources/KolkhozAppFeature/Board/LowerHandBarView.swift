import KolkhozCore
import SwiftUI

enum LowerHandBarLayout {
    static let trickHeight: CGFloat = 66
    static let swapHeight: CGFloat = 66
    static let assignmentHeight: CGFloat = 70
    static let requisitionHeight: CGFloat = 66
    static let passiveHeight: CGFloat = 60
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 4
    static let traySpacing: CGFloat = 8
    static let trayZoneIconWidth: CGFloat = 34
    static let trayZoneSpacing: CGFloat = 6
    static let trayZoneHorizontalPadding: CGFloat = 6
    static let trayZoneVerticalPadding: CGFloat = 5
    static let swapControlsWidth: CGFloat = 150
    static let requisitionControlsWidth: CGFloat = 150
    static let assignmentSubmitWidth: CGFloat = 150
    static let assignmentCardsWidth: CGFloat = 290
    static let passiveHandSpacing: CGFloat = -38
    static let assignmentHandSpacing: CGFloat = -38
    static let activeHandSpacing: CGFloat = 10
    static let handOffsetY: CGFloat = 30
}

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
    let onSwapSelection: (Card, PlotSelection) -> Void
    let onConfirmSwap: () -> Void
    let onAssign: (Card, Suit) -> Void
    let onSubmitAssignments: () -> Void
    let onContinueAfterRequisition: () -> Void
    @State private var handOrder: [String] = []
    @State private var draggingHandCardID: String?
    @State private var handDragStartIndex: Int?
    @State private var handDragTranslation: CGSize = .zero

    private var trayCardSize: CardSize {
        mode == .trick ? .large : .medium
    }

    private var visibleTrayHeight: CGFloat {
        switch mode {
        case .trick:
            return LowerHandBarLayout.trickHeight
        case .swap:
            return LowerHandBarLayout.swapHeight
        case .assignment:
            return LowerHandBarLayout.assignmentHeight
        case .requisition:
            return LowerHandBarLayout.requisitionHeight
        case .passive:
            return LowerHandBarLayout.passiveHeight
        }
    }

    private var orderedHand: [Card] {
        let cardsByID = Dictionary(uniqueKeysWithValues: hand.map { ($0.id, $0) })
        let handIDs = Set(hand.map(\.id))
        let orderedIDs = handOrder.filter { handIDs.contains($0) }
        let missingIDs = hand.map(\.id).filter { !orderedIDs.contains($0) }
        return (orderedIDs + missingIDs).compactMap { cardsByID[$0] }
    }

    var body: some View {
        HStack(alignment: .top, spacing: LowerHandBarLayout.traySpacing) {
            handTrayZone

            if mode == .swap {
                swapControls
                    .frame(width: LowerHandBarLayout.swapControlsWidth, height: visibleTrayHeight)
            }

            if mode == .assignment && !allAssignmentCardsAssigned {
                assignmentControls
                    .frame(width: LowerHandBarLayout.assignmentCardsWidth, height: visibleTrayHeight)
            }

            if mode == .assignment && allAssignmentCardsAssigned {
                assignmentSubmitControls
                    .frame(width: LowerHandBarLayout.assignmentSubmitWidth, height: visibleTrayHeight)
            }

            if mode == .requisition {
                requisitionControls
                    .frame(width: LowerHandBarLayout.requisitionControlsWidth, height: visibleTrayHeight)
            }
        }
        .frame(height: visibleTrayHeight)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, LowerHandBarLayout.topPadding)
        .padding(.horizontal, LowerHandBarLayout.horizontalPadding)
    }

    private var handTrayZone: some View {
        HStack(alignment: .top, spacing: LowerHandBarLayout.trayZoneSpacing) {
            GameIcon(.hand, size: 32)
                .accessibilityLabel(language.text(en: "Hand", ru: "Рука"))
                .frame(width: LowerHandBarLayout.trayZoneIconWidth, height: visibleTrayHeight, alignment: .top)

            handCards
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, LowerHandBarLayout.trayZoneHorizontalPadding)
        .padding(.vertical, LowerHandBarLayout.trayZoneVerticalPadding)
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
                let isMuted = mode == .trick && !isPlayable
                let isReordering = draggingHandCardID == card.id
                if mode == .trick {
                    CardButton(
                        card: card,
                        selected: false,
                        size: trayCardSize,
                        highlighted: isTrickPlayable,
                        muted: isMuted,
                        positionedAction: isTrickPlayable ? { startCenter in
                            playCard(card, startCenter)
                        } : nil,
                        dragAction: isTrickPlayable ? { startCenter in
                            playCard(card, startCenter)
                        } : nil,
                        dragChanged: { card, _, translation in
                            if isTrickPlayable && isPlayDragPreview(translation) {
                                draggingHandCardID = card.id
                                handDragStartIndex = nil
                                handDragTranslation = translation
                            }
                        },
                        dragEnded: { card, startCenter, translation in
                            if isTrickPlayable && shouldPlayDroppedCard(startCenter: startCenter, translation: translation) {
                                playCard(card, startCenter)
                            }
                            resetHandDrag()
                        }
                    ) {
                        if isTrickPlayable {
                            playCard(card, .zero)
                        }
                    }
                    .handCardPhysicalStyle(active: isReordering, translation: handDragTranslation)
                    .simultaneousGesture(reorderGesture(for: card))
                } else {
                    Button {
                        if isSwapSelectable {
                            selectedSwapHand = card
                        }
                    } label: {
                        CardView(card: card, size: trayCardSize)
                            .overlay {
                                RoundedRectangle(cornerRadius: 7)
                                    .stroke(
                                        mode == .swap && selectedSwapHand == card ? Color.kolkhozGreen : (isSwapSelectable ? Color.kolkhozGold : Color.clear),
                                        lineWidth: mode == .swap && selectedSwapHand == card ? 3 : (isSwapSelectable ? 2 : 0)
                                    )
                            }
                            .opacity(mode == .passive ? 0.92 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSwapSelectable)
                    .opacity(1)
                    .handCardPhysicalStyle(active: isReordering, translation: handDragTranslation)
                    .simultaneousGesture(reorderGesture(for: card))
                }
            }
        }
        .padding(.horizontal, 2)
        .offset(y: LowerHandBarLayout.handOffsetY)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: visibleTrayHeight)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: handOrder)
        .onAppear {
            syncHandOrder()
        }
        .onChange(of: hand.map(\.id)) { _, _ in
            syncHandOrder()
            if let draggingHandCardID, !hand.contains(where: { $0.id == draggingHandCardID }) {
                resetHandDrag()
            }
        }
    }

    private var handReorderStep: CGFloat {
        switch mode {
        case .trick:
            return CardSize.large.width + 10
        case .swap, .assignment, .requisition:
            return CardSize.medium.width + 10
        case .passive:
            return max(18, CardSize.medium.width - 38)
        }
    }

    private var handCardSpacing: CGFloat {
        switch mode {
        case .passive:
            return LowerHandBarLayout.passiveHandSpacing
        case .assignment:
            return LowerHandBarLayout.assignmentHandSpacing
        case .trick, .swap, .requisition:
            return LowerHandBarLayout.activeHandSpacing
        }
    }

    private func reorderGesture(for card: Card) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 0.85 else {
                    if draggingHandCardID == card.id {
                        handDragTranslation = value.translation
                    }
                    return
                }

                if draggingHandCardID != card.id {
                    draggingHandCardID = card.id
                    handDragStartIndex = orderedHand.firstIndex(of: card)
                }

                handDragTranslation = value.translation
            }
            .onEnded { value in
                withAnimation(.spring(response: 0.22, dampingFraction: 0.74)) {
                    if let startIndex = handDragStartIndex {
                        let offset = Int((value.translation.width / handReorderStep).rounded())
                        let targetIndex = min(max(startIndex + offset, 0), max(orderedHand.count - 1, 0))
                        moveHandCard(card, toDisplayedIndex: targetIndex)
                    }
                    resetHandDrag()
                }
            }
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

    private func syncHandOrder() {
        let ids = hand.map(\.id)
        let idSet = Set(ids)
        var next = handOrder.filter { idSet.contains($0) }
        for id in ids where !next.contains(id) {
            next.append(id)
        }
        if next != handOrder {
            handOrder = next
        }
    }

    private func moveHandCard(_ card: Card, toDisplayedIndex targetIndex: Int) {
        var ids = orderedHand.map(\.id)
        guard let currentIndex = ids.firstIndex(of: card.id), currentIndex != targetIndex else { return }
        let movedID = ids.remove(at: currentIndex)
        ids.insert(movedID, at: min(targetIndex, ids.count))
        handOrder = ids
    }

    private func resetHandDrag() {
        draggingHandCardID = nil
        handDragStartIndex = nil
        handDragTranslation = .zero
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
                            onDragChanged: updateAssignmentDrag(_:startCenter:translation:),
                        onDragEnded: finishAssignmentDrag(_:translation:),
                        onTapSelect: { selectAssignmentCard(play.card) }
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .offset(y: LowerHandBarLayout.handOffsetY)
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
        Button(primarySwapTitle) {
            performPrimarySwapAction()
        }
        .buttonStyle(SwapCommandButtonStyle(prominent: true))
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .center)
    }

    private var primarySwapTitle: String {
        humanSwapStaged || (selectedSwapHand != nil && selectedSwapPlot != nil) ? language.text(en: "Swap", ru: "Обмен") : language.text(en: "Keep Hand", ru: "Оставить")
    }

    private func performPrimarySwapAction() {
        if humanSwapStaged {
            onConfirmSwap()
        } else if let selectedSwapHand, let selectedSwapPlot {
            onSwapSelection(selectedSwapHand, selectedSwapPlot)
        } else {
            onConfirmSwap()
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
            onSwapSelection: { _, _ in },
            onConfirmSwap: {},
            onAssign: { _, _ in },
            onSubmitAssignments: {},
            onContinueAfterRequisition: {}
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
