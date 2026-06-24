import KolkhozCore
import SwiftUI

enum AssignmentSectionLayout {
    static let gridCompactWidth: CGFloat = 500
    static let gridTightWidth: CGFloat = 560
    static let headerCompactWidth: CGFloat = 520
    static let compactSpacing: CGFloat = 6
    static let regularSpacing: CGFloat = 10
    static let assignmentTileMinHeight: CGFloat = 88
    static let displayTileMinHeight: CGFloat = 106
    static let assignmentHeaderHeight: CGFloat = 58
    static let displayHeaderHeight: CGFloat = 62
    static let compactHeaderHorizontalPadding: CGFloat = 8
    static let regularHeaderHorizontalPadding: CGFloat = 10
    static let compactHeaderVerticalPadding: CGFloat = 5
    static let regularHeaderVerticalPadding: CGFloat = 6
    static let tileCardStackSpacing: CGFloat = -34
    static let tilePadding: CGFloat = 8
}

struct AssignmentJobsView: View {
    @EnvironmentObject private var store: GameStore
    @Environment(\.kolkhozLanguage) private var language
    @Binding var jobTargets: [Suit: CGPoint]
    @Binding var jobTargetFrames: [Suit: CGRect]
    @Binding var assignmentDrag: AssignmentDragState?
    @Binding var hoveredSuit: Suit?
    @Binding var selectedAssignmentCard: Card?

    private var isAssignmentPhase: Bool { store.state.phase == .assignment }
    private var legalTargets: [Suit] {
        Array(Set(store.state.lastTrick.map(\.card.suit))).sorted { $0.rawValue < $1.rawValue }
    }
    private var legalTargetSet: Set<Suit> { Set(legalTargets) }

    var body: some View {
        VStack(spacing: 8) {
            assignmentHeader

            GeometryReader { proxy in
                let spacing: CGFloat = proxy.size.width < AssignmentSectionLayout.gridTightWidth ? AssignmentSectionLayout.compactSpacing : AssignmentSectionLayout.regularSpacing
                let compactGrid = proxy.size.width < AssignmentSectionLayout.gridCompactWidth
                let columnCount = compactGrid ? 2 : Suit.allCases.count
                let rowCount = compactGrid ? 2 : 1
                let minTileHeight: CGFloat = isAssignmentPhase ? AssignmentSectionLayout.assignmentTileMinHeight : AssignmentSectionLayout.displayTileMinHeight
                let tileHeight = max(minTileHeight, (proxy.size.height - spacing * CGFloat(rowCount - 1)) / CGFloat(rowCount))
                let columns = Array(
                    repeating: GridItem(.flexible(minimum: 0), spacing: spacing),
                    count: columnCount
                )

                LazyVGrid(columns: columns, alignment: .leading, spacing: spacing) {
                    ForEach(Suit.allCases) { suit in
                        AssignmentJobTile(
                            suit: suit,
                            hours: store.state.workHours[suit, default: 0],
                            claimed: store.state.claimedJobs.contains(suit),
                            reward: store.state.revealedJobs[suit],
                            assignedCards: assignedCards(for: suit),
                            pendingHours: pendingHours(for: suit),
                            highlighted: store.state.trump == suit,
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
            let compact = proxy.size.width < AssignmentSectionLayout.headerCompactWidth

            HStack(spacing: compact ? AssignmentSectionLayout.compactSpacing : AssignmentSectionLayout.regularSpacing) {
                PanelTitleRow(
                    title: isAssignmentPhase ? language.text(en: "Assign to jobs", ru: "Назначьте на работы") : language.text(en: "Fields", ru: "Поля"),
                    subtitle: isAssignmentPhase ? language.text(en: "Drag cards from the hand tray into a valid suit column.", ru: "Перетащите карты из руки в допустимую колонку.") : language.text(en: "Track work progress and rewards.", ru: "Следите за работами и наградами."),
                    icon: .jobs,
                    compact: compact
                )
                .layoutPriority(1)
            }
            .padding(.horizontal, compact ? AssignmentSectionLayout.compactHeaderHorizontalPadding : AssignmentSectionLayout.regularHeaderHorizontalPadding)
            .padding(.vertical, compact ? AssignmentSectionLayout.compactHeaderVerticalPadding : AssignmentSectionLayout.regularHeaderVerticalPadding)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(CommandPanelBackground())
        }
        .frame(height: isAssignmentPhase ? AssignmentSectionLayout.assignmentHeaderHeight : AssignmentSectionLayout.displayHeaderHeight)
    }

    private func assignedCards(for suit: Suit) -> [AssignmentDisplayCard] {
        guard isAssignmentPhase else {
            return store.state.jobBuckets[suit, default: []].map { AssignmentDisplayCard(card: $0, draggable: false) }
        }
        let alreadyBucketed = store.state.jobBuckets[suit, default: []].map { AssignmentDisplayCard(card: $0, draggable: false) }
        let pending = store.state.lastTrick
            .map(\.card)
            .filter { store.state.pendingAssignments[$0.id] == suit }
            .map { AssignmentDisplayCard(card: $0, draggable: true) }
        return alreadyBucketed + pending
    }

    private func pendingHours(for suit: Suit) -> Int {
        guard isAssignmentPhase else { return 0 }
        return store.state.lastTrick
            .map(\.card)
            .filter { store.state.pendingAssignments[$0.id] == suit }
            .reduce(0) { $0 + workValue(for: $1) }
    }

    private func workValue(for card: Card) -> Int {
        if store.state.variants.nomenclature, card.suit == store.state.trump, card.value == 11 {
            return 0
        }
        return card.value
    }

    private func updateTarget(_ suit: Suit, frame: CGRect) {
        jobTargetFrames[suit] = frame
        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func updateDrag(_ card: Card, startCenter: CGPoint, translation: CGSize) {
        let drag = AssignmentDragState(card: card, startCenter: startCenter, translation: translation)
        assignmentDrag = drag
        hoveredSuit = jobTargetFrames.first { suit, frame in
            legalTargetSet.contains(suit) && frame.contains(drag.currentCenter)
        }?.key
    }

    private func finishDrag(_ card: Card, translation: CGSize) {
        defer {
            assignmentDrag = nil
            hoveredSuit = nil
        }
        guard let drag = assignmentDrag else { return }
        if let target = jobTargetFrames.first(where: { suit, frame in
            legalTargetSet.contains(suit) && frame.contains(drag.currentCenter)
        })?.key {
            store.assign(card, to: target)
        }
    }

    private func selectAssignmentCard(_ card: Card) {
        selectedAssignmentCard = selectedAssignmentCard == card ? nil : card
    }

    private func assignSelectedCard(to suit: Suit) {
        guard legalTargetSet.contains(suit), let card = selectedAssignmentCard else { return }
        let nextCard = store.state.lastTrick
            .map(\.card)
            .first { $0 != card && store.state.pendingAssignments[$0.id] == nil }
        store.assign(card, to: suit)
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
    let pendingHours: Int
    let highlighted: Bool
    let validTarget: Bool
    let hovered: Bool
    let selectedCard: Card?
    let onDragChanged: (Card, CGPoint, CGSize) -> Void
    let onDragEnded: (Card, CGSize) -> Void
    let onTapAssign: () -> Void

    private var totalHours: Int { hours + pendingHours }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                SuitMark(suit: suit, size: 16)
                if highlighted {
                    GameIcon(.medalStar, size: 12)
                }
                Spacer()
                PixelText(
                    text: claimed ? language.text(en: "DONE", ru: "ГОТОВО") : "\(totalHours)/40",
                    size: .caption2,
                    variant: .heavy,
                    color: claimed ? Color.kolkhozGreen : Color.kolkhozGold
                )
            }

            ProgressBar(value: min(Double(totalHours) / 40.0, 1), complete: claimed)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: AssignmentSectionLayout.tileCardStackSpacing) {
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

                if let reward, !claimed {
                    MiniRewardCard(card: reward, claimed: totalHours >= 40)
                        .scaleEffect(1.05)
                }
            }
        }
        .padding(AssignmentSectionLayout.tilePadding)
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
    let playerName: String
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
            VStack(spacing: 3) {
                CardView(card: play.card, size: .small)
                    .opacity(isDragging || dragging ? 0.32 : 1)
                Text(statusText)
                    .font(.kolkhozTitle(.caption2))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .frame(width: 42, height: 12)
                    .background(statusBackground, in: Capsule())
            }
            .frame(width: 48, height: 74)
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? Color.kolkhozGold : Color.clear, lineWidth: 2)
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
        .frame(width: 48, height: 74)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(language.text(en: "\(play.card.rank) of \(play.card.suit.rawValue), captured by \(playerName)", ru: "\(play.card.rank) \(language.suitName(play.card.suit)), взял \(playerName)")))
        .accessibilityValue(Text(assignedSuit.map { language.text(en: "Assigned to \($0.rawValue)", ru: "Назначено на \(language.suitName($0))") } ?? (selected ? language.text(en: "Selected", ru: "Выбрано") : language.text(en: "Unassigned", ru: "Не назначено"))))
        .accessibilityHint(Text(language.text(en: "Tap to select for assignment, or drag to a valid job.", ru: "Нажмите для выбора или перетащите на допустимую работу.")))
        .accessibilityAddTraits(.isButton)
    }

    private var statusText: String {
        if let assignedSuit {
            return language.suitShortName(assignedSuit)
        }
        return selected ? language.text(en: "SEL", ru: "ВЫБ") : ownerBadgeText
    }

    private var ownerBadgeText: String {
        if play.playerID == 0 {
            return language.text(en: "YOU", ru: "ВЫ")
        }
        let prefix = playerName.prefix(3)
        return String(prefix).uppercased()
    }

    private var statusColor: Color {
        if assignedSuit != nil {
            return Color.kolkhozGreen
        }
        return selected ? Color.kolkhozGold : Color.kolkhozCreamDim
    }

    private var statusBackground: Color {
        if assignedSuit != nil {
            return Color.kolkhozGreen.opacity(0.16)
        }
        return selected ? Color.kolkhozGold.opacity(0.18) : Color.kolkhozBlack.opacity(0.34)
    }
}

struct AssignmentDragState {
    let card: Card
    let startCenter: CGPoint
    let translation: CGSize

    var currentCenter: CGPoint {
        CGPoint(x: startCenter.x + translation.width, y: startCenter.y + translation.height)
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
        AssignmentJobsPreviewHost()
    }
}

#Preview("Assignment Jobs - Compact") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 430, height: 360) {
        AssignmentJobsPreviewHost()
    }
}

private struct AssignmentJobsPreviewHost: View {
    @State private var jobTargets: [Suit: CGPoint] = [:]
    @State private var jobTargetFrames: [Suit: CGRect] = [:]
    @State private var assignmentDrag: AssignmentDragState?
    @State private var hoveredSuit: Suit?
    @State private var selectedAssignmentCard: Card? = Card(suit: .sunflower, value: 12)

    var body: some View {
        AssignmentJobsView(
            jobTargets: $jobTargets,
            jobTargetFrames: $jobTargetFrames,
            assignmentDrag: $assignmentDrag,
            hoveredSuit: $hoveredSuit,
            selectedAssignmentCard: $selectedAssignmentCard
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
