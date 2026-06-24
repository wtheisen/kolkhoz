import KolkhozCore
import SwiftUI

enum PlayerHandTrayLayout {
    static let trickHeight: CGFloat = 66
    static let swapHeight: CGFloat = 66
    static let assignmentHeight: CGFloat = 70
    static let passiveHeight: CGFloat = 60
    static let horizontalPadding: CGFloat = 16
    static let topPadding: CGFloat = 4
    static let traySpacing: CGFloat = 8
    static let trayZoneIconWidth: CGFloat = 34
    static let trayZoneSpacing: CGFloat = 6
    static let trayZoneHorizontalPadding: CGFloat = 6
    static let trayZoneVerticalPadding: CGFloat = 5
    static let cellarZoneWidth: CGFloat = 92
    static let plotZoneWidth: CGFloat = 96
    static let swapControlsWidth: CGFloat = 150
    static let assignmentSubmitWidth: CGFloat = 150
    static let assignmentCardsWidth: CGFloat = 260
    static let compactPlotCardSpacing: CGFloat = -28
    static let passiveHandSpacing: CGFloat = -38
    static let assignmentHandSpacing: CGFloat = -38
    static let activeHandSpacing: CGFloat = 10
    static let handOffsetY: CGFloat = 30
    static let assignmentHandOffsetY: CGFloat = 24
}

enum PlayerHandTrayMode {
    case passive
    case trick
    case swap
    case assignment
}

struct PlayerHandTrayView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    let playCard: (Card, CGPoint) -> Void
    let mode: PlayerHandTrayMode
    @Binding var selectedSwapHand: Card?
    @Binding var selectedSwapPlot: PlotSelection?
    @Binding var assignmentDrag: AssignmentDragState?
    @Binding var hoveredAssignmentSuit: Suit?
    @Binding var selectedAssignmentCard: Card?
    let jobTargetFrames: [Suit: CGRect]
    let playDropFrame: CGRect?
    @State private var handOrder: [String] = []
    @State private var draggingHandCardID: String?
    @State private var handDragStartIndex: Int?
    @State private var handDragTranslation: CGSize = .zero

    private var cellarCards: [Card] {
        store.state.players[0].plot.hidden
    }

    private var plotCards: [Card] {
        store.state.players[0].plot.revealed
    }

    private var hasSwapTargets: Bool {
        !cellarCards.isEmpty || !plotCards.isEmpty
    }

    private var trayCardSize: CardSize {
        mode == .trick ? .large : .medium
    }

    private var visibleTrayHeight: CGFloat {
        switch mode {
        case .trick:
            return PlayerHandTrayLayout.trickHeight
        case .swap:
            return PlayerHandTrayLayout.swapHeight
        case .assignment:
            return PlayerHandTrayLayout.assignmentHeight
        case .passive:
            return PlayerHandTrayLayout.passiveHeight
        }
    }

    private var orderedHand: [Card] {
        let hand = store.state.players[0].hand
        let cardsByID = Dictionary(uniqueKeysWithValues: hand.map { ($0.id, $0) })
        let handIDs = Set(hand.map(\.id))
        let orderedIDs = handOrder.filter { handIDs.contains($0) }
        let missingIDs = hand.map(\.id).filter { !orderedIDs.contains($0) }
        return (orderedIDs + missingIDs).compactMap { cardsByID[$0] }
    }

    var body: some View {
        HStack(alignment: .top, spacing: PlayerHandTrayLayout.traySpacing) {
            trayZone(icon: .cellar, accessibilityLabel: language.text(en: "Cellar", ru: "Подвал"), width: PlayerHandTrayLayout.cellarZoneWidth) {
                compactPlotCards(cards: cellarCards, hidden: true, zone: .hidden)
            }

            trayZone(icon: .plot, accessibilityLabel: language.text(en: "Plot", ru: "Участок"), width: PlayerHandTrayLayout.plotZoneWidth) {
                compactPlotCards(cards: plotCards, hidden: false, zone: .revealed)
            }

            trayZone(icon: .hand, accessibilityLabel: language.text(en: "Hand", ru: "Рука")) {
                handCards
            }

            if mode == .swap {
                swapControls
                    .frame(width: PlayerHandTrayLayout.swapControlsWidth, height: visibleTrayHeight)
            }

            if mode == .assignment {
                assignmentControls
                    .frame(width: assignmentControlsWidth, height: visibleTrayHeight)
            }
        }
        .frame(height: visibleTrayHeight)
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.top, PlayerHandTrayLayout.topPadding)
        .padding(.horizontal, PlayerHandTrayLayout.horizontalPadding)
    }

    private func trayZone<Content: View>(
        icon: GameIconAsset,
        accessibilityLabel: String,
        width: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .top, spacing: PlayerHandTrayLayout.trayZoneSpacing) {
            GameIcon(icon, size: icon == .hand ? 32 : 24)
                .accessibilityLabel(accessibilityLabel)
                .frame(width: PlayerHandTrayLayout.trayZoneIconWidth, height: visibleTrayHeight, alignment: .top)

            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, PlayerHandTrayLayout.trayZoneHorizontalPadding)
        .padding(.vertical, PlayerHandTrayLayout.trayZoneVerticalPadding)
        .frame(width: width, height: visibleTrayHeight, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(icon == .hand ? 0.12 : 0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(icon == .hand ? 0.32 : 0.46), lineWidth: 1)
        }
    }

    private func compactPlotCards(cards: [Card], hidden: Bool, zone: PlotCardZone) -> some View {
        HStack(alignment: .top, spacing: PlayerHandTrayLayout.compactPlotCardSpacing) {
            ForEach(Array(cards.prefix(4).enumerated()), id: \.element.id) { _, card in
                Button {
                    if mode == .swap && !store.state.swapCount.contains(0) {
                        selectedSwapPlot = PlotSelection(card: card, zone: zone)
                    }
                } label: {
                    Group {
                        if hidden {
                            CardBackView(size: .small)
                        } else {
                            CardView(card: card, size: .small)
                        }
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(
                                selectedSwapPlot == PlotSelection(card: card, zone: zone) ? Color.kolkhozGreen : Color.clear,
                                lineWidth: 2
                            )
                    }
                }
                .buttonStyle(.plain)
                .disabled(mode != .swap || store.state.swapCount.contains(0))
            }

            if cards.isEmpty {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.kolkhozSteel.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(width: 34, height: 48)
                    .overlay {
                        GameIcon(hidden ? .cellar : .plot, size: 18, muted: true)
                            .opacity(0.45)
                    }
            }
        }
        .padding(.top, 2)
        .opacity(mode == .passive ? 0.82 : 1)
    }

    private var handCards: some View {
        HStack(alignment: .top, spacing: handCardSpacing) {
            let cards = orderedHand
            ForEach(cards) { card in
                let isPlayable = store.validCardsForHuman().contains(card)
                let isTrickPlayable = mode == .trick && isPlayable
                let isSwapSelectable = mode == .swap && hasSwapTargets && !store.state.swapCount.contains(0)
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
                    .opacity(mode == .assignment ? 0.74 : 1)
                    .handCardPhysicalStyle(active: isReordering, translation: handDragTranslation)
                    .simultaneousGesture(reorderGesture(for: card))
                }
            }
        }
        .padding(.horizontal, 2)
        .offset(y: mode == .assignment ? PlayerHandTrayLayout.assignmentHandOffsetY : PlayerHandTrayLayout.handOffsetY)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: visibleTrayHeight)
        .animation(.spring(response: 0.24, dampingFraction: 0.78), value: handOrder)
        .onAppear {
            syncHandOrder()
        }
        .onChange(of: store.state.players[0].hand.map(\.id)) { _, _ in
            syncHandOrder()
            if let draggingHandCardID, !store.state.players[0].hand.contains(where: { $0.id == draggingHandCardID }) {
                resetHandDrag()
            }
        }
    }

    private var handReorderStep: CGFloat {
        switch mode {
        case .trick:
            return CardSize.large.width + 10
        case .swap, .assignment:
            return CardSize.medium.width + 10
        case .passive:
            return max(18, CardSize.medium.width - 38)
        }
    }

    private var handCardSpacing: CGFloat {
        switch mode {
        case .passive:
            return PlayerHandTrayLayout.passiveHandSpacing
        case .assignment:
            return PlayerHandTrayLayout.assignmentHandSpacing
        case .trick, .swap:
            return PlayerHandTrayLayout.activeHandSpacing
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
        let ids = store.state.players[0].hand.map(\.id)
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

    private var assignmentControlsWidth: CGFloat {
        allAssignmentCardsAssigned ? PlayerHandTrayLayout.assignmentSubmitWidth : PlayerHandTrayLayout.assignmentCardsWidth
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

            if allAssignmentCardsAssigned {
                Button(language.text(en: "Submit", ru: "Подтвердить")) {
                    store.submitAssignments()
                }
                .buttonStyle(SwapCommandButtonStyle(prominent: true))
                .frame(maxHeight: .infinity, alignment: .center)
            } else {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(unassignedAssignmentPlays) { play in
                        AssignmentCapturedCard(
                            play: play,
                            playerName: language.playerName(store.state.players[play.playerID]),
                            assignedSuit: store.state.pendingAssignments[play.card.id],
                            selected: selectedAssignmentCard == play.card,
                            dragging: assignmentDrag?.card == play.card,
                            onDragChanged: updateAssignmentDrag(_:startCenter:translation:),
                            onDragEnded: finishAssignmentDrag(_:translation:),
                            onTapSelect: { selectAssignmentCard(play.card) }
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .offset(y: -8)
            }
        }
    }

    private var unassignedAssignmentPlays: [TrickPlay] {
        store.state.lastTrick.filter { store.state.pendingAssignments[$0.card.id] == nil }
    }

    private var allAssignmentCardsAssigned: Bool {
        store.state.phase == .assignment &&
            !store.state.lastTrick.isEmpty &&
            store.state.pendingAssignments.count == store.state.lastTrick.count
    }

    private var legalAssignmentTargets: Set<Suit> {
        Set(store.state.lastTrick.map(\.card.suit))
    }

    private func updateAssignmentDrag(_ card: Card, startCenter: CGPoint, translation: CGSize) {
        let drag = AssignmentDragState(card: card, startCenter: startCenter, translation: translation)
        assignmentDrag = drag
        hoveredAssignmentSuit = jobTargetFrames.first { suit, frame in
            legalAssignmentTargets.contains(suit) && frame.contains(drag.currentCenter)
        }?.key
    }

    private func finishAssignmentDrag(_ card: Card, translation: CGSize) {
        defer {
            assignmentDrag = nil
            hoveredAssignmentSuit = nil
        }
        guard let drag = assignmentDrag else { return }
        if let target = jobTargetFrames.first(where: { suit, frame in
            legalAssignmentTargets.contains(suit) && frame.contains(drag.currentCenter)
        })?.key {
            store.assign(card, to: target)
            selectedAssignmentCard = nextUnassignedAssignmentCard(after: card)
        }
    }

    private func selectAssignmentCard(_ card: Card) {
        selectedAssignmentCard = selectedAssignmentCard == card ? nil : card
    }

    private func nextUnassignedAssignmentCard(after card: Card) -> Card? {
        store.state.lastTrick
            .map(\.card)
            .first { $0 != card && store.state.pendingAssignments[$0.id] == nil }
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
        store.state.swapCount.contains(0) || (selectedSwapHand != nil && selectedSwapPlot != nil) ? language.text(en: "Swap", ru: "Обмен") : language.text(en: "Keep Hand", ru: "Оставить")
    }

    private func performPrimarySwapAction() {
        if store.state.swapCount.contains(0) {
            store.confirmSwap()
        } else if let selectedSwapHand, let selectedSwapPlot {
            store.swap(handCard: selectedSwapHand, plotCard: selectedSwapPlot.card, revealed: selectedSwapPlot.zone == .revealed)
            if store.state.swapCount.contains(0) {
                store.confirmSwap()
            }
        } else {
            store.confirmSwap()
        }
        selectedSwapHand = nil
        selectedSwapPlot = nil
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

struct PlayerHandView: View {
    @EnvironmentObject var store: GameStore
    @Environment(\.kolkhozLanguage) private var language

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(language.text(en: "Your hand", ru: "Ваша рука"))
                    .sectionTitle()
                Spacer()
                Text(language.text(en: "Cellar \(store.state.players[0].plot.hidden.count + store.state.players[0].plot.revealed.count)", ru: "Подвал \(store.state.players[0].plot.hidden.count + store.state.players[0].plot.revealed.count)"))
                    .font(.kolkhozLabel(.caption))
                    .foregroundStyle(Color.kolkhozCreamDim)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.state.players[0].hand) { card in
                        let isPlayable = store.validCardsForHuman().contains(card)
                        let isMuted = store.state.phase == .trick && !isPlayable
                        CardButton(
                            card: card,
                            selected: false,
                            highlighted: store.state.phase == .trick && isPlayable,
                            muted: isMuted,
                            dragAction: store.state.phase == .trick && isPlayable ? { _ in store.play(card) } : nil
                        ) {
                            if isPlayable {
                                store.play(card)
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [Color.kolkhozBlack.opacity(0.92), Color.kolkhozIron.opacity(0.88), Color.kolkhozGold.opacity(0.08)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.kolkhozGold.opacity(0.75), lineWidth: 2)
        }
    }
}

#if DEBUG
#Preview("Hand Tray - Trick") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 720, height: 112) {
        PlayerHandTrayPreviewHost(mode: .trick)
    }
}

#Preview("Hand Tray - Swap") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 760, height: 112) {
        PlayerHandTrayPreviewHost(mode: .swap)
    }
}

#Preview("Hand Tray - Assignment") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 820, height: 120) {
        PlayerHandTrayPreviewHost(mode: .assignment)
    }
}

private struct PlayerHandTrayPreviewHost: View {
    let mode: PlayerHandTrayMode
    @State private var selectedSwapHand: Card?
    @State private var selectedSwapPlot: PlotSelection?
    @State private var assignmentDrag: AssignmentDragState?
    @State private var hoveredAssignmentSuit: Suit?
    @State private var selectedAssignmentCard: Card?

    var body: some View {
        PlayerHandTrayView(
            playCard: { _, _ in },
            mode: mode,
            selectedSwapHand: $selectedSwapHand,
            selectedSwapPlot: $selectedSwapPlot,
            assignmentDrag: $assignmentDrag,
            hoveredAssignmentSuit: $hoveredAssignmentSuit,
            selectedAssignmentCard: $selectedAssignmentCard,
            jobTargetFrames: [:],
            playDropFrame: nil
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
