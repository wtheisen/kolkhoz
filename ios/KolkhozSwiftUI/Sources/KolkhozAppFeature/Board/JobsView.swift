import KolkhozCore
import SwiftUI

enum JobsViewLayout {
    static let minGridSpacing: CGFloat = 6
    static let maxGridSpacing: CGFloat = 10
    static let minTileWidth: CGFloat = 132
    static let assignmentTileMinHeight: CGFloat = 88
    static let displayTileMinHeight: CGFloat = 106
    static let assignmentHeaderHeight: CGFloat = 58
    static let displayHeaderHeight: CGFloat = 62
    static let minHeaderHorizontalPadding: CGFloat = 8
    static let maxHeaderHorizontalPadding: CGFloat = 10
    static let minHeaderVerticalPadding: CGFloat = 5
    static let maxHeaderVerticalPadding: CGFloat = 6
    static let tileCardStackSpacing: CGFloat = -34
    static let tilePadding: CGFloat = 8
}

struct JobsView: View {
    @Environment(\.kolkhozLanguage) private var language
    @Binding var jobTargets: [Suit: CGPoint]
    @Binding var jobTargetFrames: [Suit: CGRect]
    @Binding var assignmentDrag: AssignmentDragState?
    @Binding var hoveredSuit: Suit?
    @Binding var selectedAssignmentCard: Card?
    let isAssignmentPhase: Bool
    let lastTrick: [TrickPlay]
    let workHours: [Suit: Int]
    let claimedJobs: Set<Suit>
    let revealedJobs: [Suit: Card]
    let jobBuckets: [Suit: [Card]]
    let pendingAssignments: [String: Suit]
    let trump: Suit?
    let onAssign: (Card, Suit) -> Void

    private var legalTargets: [Suit] {
        Array(Set(lastTrick.map(\.card.suit))).sorted { $0.rawValue < $1.rawValue }
    }
    private var legalTargetSet: Set<Suit> { Set(legalTargets) }

    var body: some View {
        VStack(spacing: 8) {
            assignmentHeader

            GeometryReader { proxy in
                let spacing = kolkhozClamp(proxy.size.width * 0.016, JobsViewLayout.minGridSpacing, JobsViewLayout.maxGridSpacing)
                let tileMinWidth = kolkhozClamp(proxy.size.width * 0.24, JobsViewLayout.minTileWidth, proxy.size.width)
                let columnCount = max(1, min(Suit.allCases.count, Int((proxy.size.width + spacing) / (tileMinWidth + spacing))))
                let rowCount = Int(ceil(Double(Suit.allCases.count) / Double(columnCount)))
                let minTileHeight: CGFloat = isAssignmentPhase ? JobsViewLayout.assignmentTileMinHeight : JobsViewLayout.displayTileMinHeight
                let tileHeight = max(minTileHeight, (proxy.size.height - spacing * CGFloat(rowCount - 1)) / CGFloat(rowCount))
                let columns = [GridItem(.adaptive(minimum: tileMinWidth), spacing: spacing)]

                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(Suit.allCases) { suit in
                        AssignmentJobTile(
                            suit: suit,
                            hours: workHours[suit, default: 0],
                            claimed: claimedJobs.contains(suit),
                            reward: revealedJobs[suit],
                            assignedCards: assignedCards(for: suit),
                            highlighted: trump == suit,
                            validTarget: isAssignmentPhase && legalTargetSet.contains(suit),
                            hovered: hoveredSuit == suit,
                            selectedCard: selectedAssignmentCard,
                            onDragChanged: updateDrag(_:startCenter:translation:),
                            onDragEnded: finishDrag(_:translation:),
                            onTapAssign: { assignSelectedCard(to: suit) }
                        )
                        .frame(height: tileHeight)
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear { updateTarget(suit, frame: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) }
                                    .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, frame in
                                        updateTarget(suit, frame: frame)
                                    }
                            }
                        }
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var assignmentHeader: some View {
        GeometryReader { proxy in
            let horizontalPadding = kolkhozClamp(proxy.size.width * 0.018, JobsViewLayout.minHeaderHorizontalPadding, JobsViewLayout.maxHeaderHorizontalPadding)
            let verticalPadding = kolkhozClamp(proxy.size.height * 0.10, JobsViewLayout.minHeaderVerticalPadding, JobsViewLayout.maxHeaderVerticalPadding)

            HStack(spacing: kolkhozClamp(proxy.size.width * 0.016, JobsViewLayout.minGridSpacing, JobsViewLayout.maxGridSpacing)) {
                PanelTitleRow(
                    title: isAssignmentPhase ? language.text(en: "Assign to jobs", ru: "Назначьте на работы") : language.text(en: "Jobs", ru: "Работы"),
                    subtitle: isAssignmentPhase ? language.text(en: "Drag cards from the hand tray into a valid suit column.", ru: "Перетащите карты из руки в допустимую колонку.") : language.text(en: "Track work progress and rewards.", ru: "Следите за работами и наградами."),
                    icon: .jobs
                )
                .layoutPriority(1)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(CommandPanelBackground())
        }
        .frame(height: isAssignmentPhase ? JobsViewLayout.assignmentHeaderHeight : JobsViewLayout.displayHeaderHeight)
    }

    private func assignedCards(for suit: Suit) -> [AssignmentDisplayCard] {
        guard isAssignmentPhase else {
            return jobBuckets[suit, default: []].map { AssignmentDisplayCard(card: $0, draggable: false) }
        }
        let alreadyBucketed = jobBuckets[suit, default: []].map { AssignmentDisplayCard(card: $0, draggable: false) }
        let pending = lastTrick
            .map(\.card)
            .filter { pendingAssignments[$0.id] == suit }
            .map { AssignmentDisplayCard(card: $0, draggable: true) }
        return alreadyBucketed + pending
    }

    private func updateTarget(_ suit: Suit, frame: CGRect) {
        jobTargetFrames[suit] = frame
        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func updateDrag(_ card: Card, startCenter: CGPoint, translation: CGSize) {
        let drag = AssignmentDragState(card: card, startCenter: startCenter, translation: translation)
        assignmentDrag = drag
        hoveredSuit = drag.targetSuit(in: jobTargetFrames, legalTargets: legalTargetSet)
    }

    private func finishDrag(_ card: Card, translation: CGSize) {
        defer {
            assignmentDrag = nil
            hoveredSuit = nil
        }
        guard let drag = assignmentDrag else { return }
        if let target = drag.targetSuit(in: jobTargetFrames, legalTargets: legalTargetSet) {
            onAssign(card, target)
        }
    }

    private func selectAssignmentCard(_ card: Card) {
        selectedAssignmentCard = selectedAssignmentCard == card ? nil : card
    }

    private func assignSelectedCard(to suit: Suit) {
        guard legalTargetSet.contains(suit), let card = selectedAssignmentCard else { return }
        let nextCard = lastTrick
            .map(\.card)
            .first { $0 != card && pendingAssignments[$0.id] == nil }
        onAssign(card, suit)
        selectedAssignmentCard = nextCard
    }
}

struct AssignmentJobTile: View {
    @Environment(\.kolkhozLanguage) private var language
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let reward: Card?
    let assignedCards: [AssignmentDisplayCard]
    let highlighted: Bool
    let validTarget: Bool
    let hovered: Bool
    let selectedCard: Card?
    let onDragChanged: (Card, CGPoint, CGSize) -> Void
    let onDragEnded: (Card, CGSize) -> Void
    let onTapAssign: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    if let reward {
                        MiniRewardCard(card: reward, claimed: claimed)
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.kolkhozGreen.opacity(0.7), lineWidth: 1)
                            .frame(width: 24, height: 34)
                            .overlay {
                                GameIcon(.check, size: 18)
                            }
                    }
                    ProgressBar(value: min(Double(hours) / 40.0, 1), complete: claimed)
                    PixelText(
                        text: claimed ? language.text(en: "DONE", ru: "ГОТОВО") : "\(hours)/40",
                        size: .headline,
                        variant: .heavy,
                        color: claimed ? Color.kolkhozGreen : Color.kolkhozGold
                    )
                }
            }

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: JobsViewLayout.tileCardStackSpacing) {
                    ForEach(assignedCards) { item in
                        AssignmentTileCard(
                            item: item,
                            onDragChanged: onDragChanged,
                            onDragEnded: onDragEnded
                        )
                    }
                    if assignedCards.isEmpty {
                        PixelText(
                            text: validTarget && selectedCard != nil ? emptyTargetText : " ",
                            size: .caption2,
                            variant: .heavy,
                            color: validTarget && selectedCard != nil ? Color.kolkhozGold : Color.clear,
                            alignment: .center
                        )
                            .frame(maxWidth: .infinity, minHeight: 42, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(JobsViewLayout.tilePadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: hovered
                    ? [Color.kolkhozGreen.opacity(0.24), Color.kolkhozPanel]
                    : highlighted
                        ? [Color.kolkhozGold.opacity(0.18), Color.kolkhozPanel]
                        : [Color.kolkhozPanel, Color.kolkhozIron],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(alignment: .bottomTrailing) {
            SuitMark(suit: suit, size: 54)
                .opacity(0.08)
                .padding(8)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    hovered ? Color.kolkhozGreen : (validTarget ? Color.kolkhozGold : Color.kolkhozSteel.opacity(0.55)),
                    style: StrokeStyle(lineWidth: hovered ? 3 : 1.5, dash: validTarget && !hovered ? [6] : [])
                )
        }
        .shadow(color: hovered ? Color.kolkhozGreen.opacity(0.42) : (validTarget ? Color.kolkhozGold.opacity(0.16) : .black.opacity(0.25)), radius: hovered ? 14 : 5, y: 3)
        .opacity(claimed ? 0.68 : 1)
        .contentShape(Rectangle())
        .onTapGesture {
            if validTarget, selectedCard != nil {
                onTapAssign()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityHint(Text(accessibilityHint))
        .accessibilityAddTraits(validTarget && selectedCard != nil ? .isButton : [])
    }

    private var emptyTargetText: String {
        language.text(en: "TAP TO ASSIGN", ru: "НАЗНАЧИТЬ")
    }

    private var accessibilityLabel: String {
        if validTarget, let selectedCard {
            language.text(en: "\(suit.rawValue) job, tap to assign \(selectedCard.rank) of \(selectedCard.suit.rawValue)", ru: "\(language.suitName(suit)): назначить \(selectedCard.rank) \(language.suitName(selectedCard.suit))")
        } else {
            language.text(en: "\(suit.rawValue) job", ru: "\(language.suitName(suit))")
        }
    }

    private var accessibilityHint: String {
        validTarget ? language.text(en: "Valid assignment target.", ru: "Допустимая цель.") : language.text(en: "Not valid for this trick.", ru: "Недопустимо для этой взятки.")
    }
}

struct AssignmentDisplayCard: Identifiable, Equatable {
    let card: Card
    let draggable: Bool

    var id: String { "\(card.id)-\(draggable ? "pending" : "bucket")" }
}

struct AssignmentTileCard: View {
    let item: AssignmentDisplayCard
    let onDragChanged: (Card, CGPoint, CGSize) -> Void
    let onDragEnded: (Card, CGSize) -> Void
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let startCenter = CGPoint(
                x: proxy.frame(in: .named(GameBoardCoordinateSpace.main)).midX,
                y: proxy.frame(in: .named(GameBoardCoordinateSpace.main)).midY
            )
            CardView(card: item.card, size: .small)
                .opacity(isDragging ? 0.32 : 1)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(item.draggable ? Color.kolkhozGreen.opacity(0.85) : Color.kolkhozGold.opacity(0.8), lineWidth: item.draggable ? 2 : 1)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: item.draggable ? 5 : 1_000, coordinateSpace: .local)
                        .updating($isDragging) { _, state, _ in state = item.draggable }
                        .onChanged { value in
                            guard item.draggable else { return }
                            onDragChanged(item.card, startCenter, value.translation)
                        }
                        .onEnded { value in
                            guard item.draggable else { return }
                            onDragEnded(item.card, value.translation)
                        }
                )
        }
        .frame(width: CardSize.small.width, height: CardSize.small.height)
    }
}

struct AssignmentCapturedCard: View {
    @Environment(\.kolkhozLanguage) private var language
    let play: TrickPlay
    let assignedSuit: Suit?
    let selected: Bool
    let dragging: Bool
    let onDragChanged: (Card, CGPoint, CGSize) -> Void
    let onDragEnded: (Card, CGSize) -> Void
    let onTapSelect: () -> Void
    @GestureState private var isDragging = false

    var body: some View {
        GeometryReader { proxy in
            let startCenter = CGPoint(
                x: proxy.frame(in: .named(GameBoardCoordinateSpace.main)).midX,
                y: proxy.frame(in: .named(GameBoardCoordinateSpace.main)).midY
            )
            CardView(card: play.card, size: .medium)
                .opacity(isDragging || dragging ? 0.32 : 1)
                .scaleEffect(isDragging || dragging ? 1.05 : 1)
                .shadow(color: highlightColor.opacity(selected || assignedSuit != nil ? 0.38 : 0.16), radius: selected || assignedSuit != nil ? 9 : 4, y: 2)
                .frame(width: CardSize.medium.width, height: CardSize.medium.height)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(highlightColor, lineWidth: selected || assignedSuit != nil ? 3 : 0)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTapSelect)
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in onDragChanged(play.card, startCenter, value.translation) }
                    .onEnded { value in onDragEnded(play.card, value.translation) }
                )
        }
        .frame(width: CardSize.medium.width, height: CardSize.medium.height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(language.text(en: "\(play.card.rank) of \(play.card.suit.rawValue)", ru: "\(play.card.rank) \(language.suitName(play.card.suit))")))
        .accessibilityValue(Text(assignedSuit.map { language.text(en: "Assigned to \($0.rawValue)", ru: "Назначено на \(language.suitName($0))") } ?? (selected ? language.text(en: "Selected", ru: "Выбрано") : language.text(en: "Unassigned", ru: "Не назначено"))))
        .accessibilityHint(Text(language.text(en: "Tap to select for assignment, or drag to a valid job.", ru: "Нажмите для выбора или перетащите на допустимую работу.")))
        .accessibilityAddTraits(.isButton)
    }

    private var highlightColor: Color {
        if assignedSuit != nil {
            return Color.kolkhozGreen
        }
        return selected ? Color.kolkhozGold : Color.clear
    }
}

struct AssignmentDragState {
    let card: Card
    let startCenter: CGPoint
    let translation: CGSize

    var currentCenter: CGPoint {
        CGPoint(x: startCenter.x + translation.width, y: startCenter.y + translation.height)
    }

    func targetSuit(in frames: [Suit: CGRect], legalTargets: Set<Suit>) -> Suit? {
        frames.first { suit, frame in
            legalTargets.contains(suit) && frame.contains(currentCenter)
        }?.key
    }
}

struct AssignmentDragGhost: View {
    let drag: AssignmentDragState
    let canDrop: Bool

    var body: some View {
        CardView(card: drag.card, size: .medium)
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(canDrop ? Color.kolkhozGreen : Color.kolkhozGold, lineWidth: 3)
            }
            .scaleEffect(1.1)
            .rotationEffect(.degrees(Double(drag.translation.width / 42)))
            .shadow(color: (canDrop ? Color.kolkhozGreen : Color.kolkhozGold).opacity(0.55), radius: 16, y: 9)
            .position(drag.currentCenter)
            .allowsHitTesting(false)
    }
}

#if DEBUG
#Preview("Assignment Jobs") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 760, height: 320) {
        JobsPreviewHost()
    }
}

#Preview("Assignment Jobs - Narrow") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 430, height: 360) {
        JobsPreviewHost()
    }
}

private struct JobsPreviewHost: View {
    @EnvironmentObject private var store: GameStore
    @State private var jobTargets: [Suit: CGPoint] = [:]
    @State private var jobTargetFrames: [Suit: CGRect] = [:]
    @State private var assignmentDrag: AssignmentDragState?
    @State private var hoveredSuit: Suit?
    @State private var selectedAssignmentCard: Card? = Card(suit: .sunflower, value: 12)

    var body: some View {
        JobsView(
            jobTargets: $jobTargets,
            jobTargetFrames: $jobTargetFrames,
            assignmentDrag: $assignmentDrag,
            hoveredSuit: $hoveredSuit,
            selectedAssignmentCard: $selectedAssignmentCard,
            isAssignmentPhase: store.state.phase == .assignment,
            lastTrick: store.state.lastTrick,
            workHours: store.state.workHours,
            claimedJobs: store.state.claimedJobs,
            revealedJobs: store.state.revealedJobs,
            jobBuckets: store.state.jobBuckets,
            pendingAssignments: store.state.pendingAssignments,
            trump: store.state.trump,
            onAssign: { _, _ in }
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
