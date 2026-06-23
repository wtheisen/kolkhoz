import KolkhozCore
import SwiftUI

struct PlayerPanel: View {
    let player: PlayerState
    let score: Int
    let active: Bool
    let human: Bool
    @State private var pulse = false

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 166
            Group {
                if compact {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Text(displayName(compact: true))
                                .font(.kolkhozTitle(.caption2))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .allowsTightening(true)
                                .foregroundStyle(active ? Color.kolkhozGold : Color.kolkhozCream)
                            if player.brigadeLeader {
                                GameIcon(.medalStar, size: 10)
                            }
                        }

                        HStack(spacing: 3) {
                            Text("\(score)")
                                .font(.kolkhozLabel(.caption2))
                                .monospacedDigit()
                                .foregroundStyle(Color.kolkhozSmoke)
                            Spacer(minLength: 2)
                            if player.medals > 0 {
                                GameIcon(.medalStar, size: 9)
                                Text("\(player.medals)")
                                    .font(.kolkhozLabel(.caption2))
                                    .monospacedDigit()
                                    .foregroundStyle(Color.kolkhozSmoke)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        PortraitView(player: player, human: human)
                            .frame(width: 38, height: 42)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 4) {
                                Text(displayName(compact: false))
                                    .font(.kolkhozLabel(.caption))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                                    .allowsTightening(true)
                                    .layoutPriority(2)
                                    .foregroundStyle(active ? Color.kolkhozGold : Color.kolkhozCream)
                                if player.brigadeLeader {
                                    GameIcon(.medalStar, size: 13)
                                }
                            }
                            Text("\(score) points")
                                .font(.kolkhozLabel(.caption2))
                                .lineLimit(1)
                                .minimumScaleFactor(0.65)
                                .foregroundStyle(Color.kolkhozSmoke)
                        }
                        .layoutPriority(2)

                        Spacer(minLength: 2)

                        VStack(alignment: .trailing, spacing: 3) {
                            HStack(spacing: -3) {
                                ForEach(0..<min(player.hand.count, 4), id: \.self) { _ in
                                    CardBackThumbnail()
                                }
                            }
                            HStack(spacing: 2) {
                                ForEach(0..<4, id: \.self) { index in
                                    GameIcon(.medalStar, size: 10, muted: index >= player.medals)
                                        .opacity(index < player.medals ? 1 : 0.22)
                                }
                            }
                        }
                        .layoutPriority(0)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 46 : 54)
            .padding(compact ? 6 : 8)
            .background(
                LinearGradient(
                    colors: active
                        ? [Color.kolkhozRed.opacity(0.33), Color.kolkhozIron.opacity(0.95)]
                        : [Color.kolkhozPanel, Color.kolkhozIron.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(active || human ? Color.kolkhozGold : Color.kolkhozSteel, lineWidth: active ? 2 : 1)
            }
            .scaleEffect(active && pulse ? 1.018 : 1)
            .shadow(color: active ? Color.kolkhozGold.opacity(pulse ? 0.46 : 0.22) : .black.opacity(0.3), radius: active && pulse ? 14 : 5, y: 3)
        }
        .frame(minHeight: 54)
        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = active }
        .onChange(of: active) { _, active in
            pulse = active
        }
    }

    private func displayName(compact: Bool) -> String {
        guard !human else { return "You" }
        guard compact else { return player.name }
        let firstName = player.name.split(separator: " ").first.map(String.init) ?? player.name
        return firstName.count > 6 ? "\(firstName.prefix(6))." : firstName
    }
}

struct JobsStripView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Suit.allCases) { suit in
                JobTile(
                    suit: suit,
                    hours: store.state.workHours[suit, default: 0],
                    claimed: store.state.claimedJobs.contains(suit),
                    reward: store.state.revealedJobs[suit],
                    assignedCount: store.state.jobBuckets[suit, default: []].count,
                    highlighted: store.state.trump == suit
                )
            }
        }
    }
}

struct JobTile: View {
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let reward: Card?
    let assignedCount: Int
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                SuitBadge(suit: suit, compact: true)
                if highlighted {
                    GameIcon(.medalStar, size: 13)
                }
                Spacer()
                Text(claimed ? "DONE" : "\(hours)/40")
                    .font(.kolkhozTitle(.caption2))
                    .monospacedDigit()
                    .foregroundStyle(claimed ? Color.kolkhozGreen : Color.kolkhozGold)
            }

            ProgressBar(value: min(Double(hours) / 40.0, 1), complete: claimed)

            HStack(spacing: 6) {
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
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(assignedCount) cards")
                        .font(.kolkhozLabel(.caption2))
                        .foregroundStyle(Color.kolkhozCreamDim)
                    Text(claimed ? "Claimed" : "Drop target")
                        .font(.kolkhozLabel(.caption2))
                        .foregroundStyle(Color.kolkhozSmoke)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 98)
        .padding(8)
        .background(
            LinearGradient(
                colors: highlighted
                    ? [Color.kolkhozGold.opacity(0.18), Color.kolkhozPanel]
                    : [Color.kolkhozPanel, Color.kolkhozIron],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(claimed ? Color.kolkhozGreen : Color.kolkhozGold.opacity(highlighted ? 1 : 0.75), lineWidth: highlighted ? 2 : 1.5)
        }
        .opacity(claimed ? 0.72 : 1)
        .animation(.easeInOut(duration: 0.28), value: hours)
        .animation(.spring(response: 0.34, dampingFraction: 0.72), value: claimed)
    }
}

struct TrickTableView: View {
    @EnvironmentObject var store: GameStore

    var displayedTrick: [TrickPlay] {
        store.state.phase == .assignment ? store.state.lastTrick : store.state.currentTrick
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Brigade")
                    .font(.kolkhozTitle(.headline))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                Spacer()
                if let winner = store.state.lastWinner, store.state.phase == .assignment {
                    Text("\(store.state.players[winner].name) assigns work")
                        .font(.kolkhozLabel(.caption))
                        .foregroundStyle(Color.kolkhozCreamDim)
                } else if store.state.phase == .trick {
                    Text(turnText)
                        .font(.kolkhozLabel(.caption))
                        .foregroundStyle(Color.kolkhozCreamDim)
                }
            }
            .padding(8)
            .background(CommandPanelBackground())
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.kolkhozSteel.opacity(0.8), lineWidth: 1)
            }

            HStack(spacing: 10) {
                ForEach(0..<store.state.players.count, id: \.self) { playerID in
                    let play = displayedTrick.first { $0.playerID == playerID }
                    let player = store.state.players[playerID]
                    VStack(spacing: 8) {
                        PlayerPanel(
                            player: player,
                            score: store.visibleScore(for: playerID),
                            active: store.state.currentPlayer == playerID && play == nil,
                            human: playerID == 0
                        )
                        if let play {
                            CardView(card: play.card, size: .medium)
                        } else {
                            CardSlot(
                                active: store.state.currentPlayer == playerID && store.state.phase == .trick,
                                human: playerID == 0
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background {
            ZStack {
                Color.kolkhozTable
                LinearGradient(
                    colors: [.kolkhozGold.opacity(0.06), .clear, .kolkhozRed.opacity(0.08)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.kolkhozGold, lineWidth: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozRedDark.opacity(0.85), lineWidth: 1.5)
                .padding(6)
        }
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
    }

    var turnText: String {
        let id = store.state.currentPlayer
        return id == 0 ? "Your turn" : "\(store.state.players[id].name) thinking"
    }
}

struct PlayerColumnsView: View {
    @EnvironmentObject var store: GameStore
    @Binding var humanPlayTarget: CGPoint?
    @Binding var playSlotCenters: [Int: CGPoint]
    @Binding var playerPanelCenters: [Int: CGPoint]
    let hiddenPlayIDs: Set<String>

    var displayedTrick: [TrickPlay] {
        store.state.phase == .assignment ? store.state.lastTrick : store.state.currentTrick
    }

    var playerOrder: [Int] { [1, 2, 3, 0] }

    var body: some View {
        GeometryReader { proxy in
            let spacing: CGFloat = proxy.size.width < 620 ? 6 : 10
            let columnWidth = max(68, (proxy.size.width - spacing * CGFloat(playerOrder.count - 1)) / CGFloat(playerOrder.count))
            HStack(alignment: .top, spacing: spacing) {
                ForEach(playerOrder, id: \.self) { playerID in
                    PlayerColumnView(
                        playerID: playerID,
                        play: displayedTrick.first { $0.playerID == playerID },
                        columnWidth: columnWidth,
                        humanPlayTarget: $humanPlayTarget,
                        playSlotCenters: $playSlotCenters,
                        playerPanelCenters: $playerPanelCenters,
                        hiddenPlayIDs: hiddenPlayIDs
                    )
                    .frame(width: columnWidth)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

struct PlayerColumnView: View {
    @EnvironmentObject var store: GameStore
    let playerID: Int
    let play: TrickPlay?
    let columnWidth: CGFloat
    @Binding var humanPlayTarget: CGPoint?
    @Binding var playSlotCenters: [Int: CGPoint]
    @Binding var playerPanelCenters: [Int: CGPoint]
    let hiddenPlayIDs: Set<String>

    var player: PlayerState { store.state.players[playerID] }
    var isCurrentTurn: Bool {
        store.state.phase == .trick && store.state.currentPlayer == playerID && play == nil
    }

    var compact: Bool { columnWidth < 166 }
    var cardSize: CardSize { compact ? .medium : .large }
    var slotWidth: CGFloat { min(compact ? 58 : 76, max(44, columnWidth * 0.52)) }

    var body: some View {
        VStack(spacing: compact ? 6 : 10) {
            PlayerPanel(
                player: player,
                score: store.visibleScore(for: playerID),
                active: isCurrentTurn,
                human: playerID == 0
            )
            .frame(height: compact ? 50 : 58)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            let frame = proxy.frame(in: .named(GameBoardCoordinateSpace.main))
                            playerPanelCenters[playerID] = CGPoint(x: frame.midX, y: frame.midY)
                        }
                        .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, frame in
                            playerPanelCenters[playerID] = CGPoint(x: frame.midX, y: frame.midY)
                        }
                }
            }

            ZStack {
                if let play, !hiddenPlayIDs.contains(play.id) {
                    CardView(card: play.card, size: cardSize)
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity
                        ))
                } else {
                    CardSlot(active: isCurrentTurn, human: playerID == 0, width: slotWidth, height: slotWidth * 1.42)
                        .background {
                            GeometryReader { proxy in
                                Color.clear
                                    .onAppear {
                                        let frame = proxy.frame(in: .named(GameBoardCoordinateSpace.main))
                                        let center = CGPoint(x: frame.midX, y: frame.midY)
                                        playSlotCenters[playerID] = center
                                        if playerID == 0 {
                                            humanPlayTarget = center
                                        }
                                    }
                                    .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, frame in
                                        let center = CGPoint(x: frame.midX, y: frame.midY)
                                        playSlotCenters[playerID] = center
                                        if playerID == 0 {
                                            humanPlayTarget = center
                                        }
                                    }
                            }
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .animation(.spring(response: 0.36, dampingFraction: 0.72), value: play?.card.id)
        }
        .frame(width: columnWidth)
        .frame(maxHeight: .infinity)
    }
}

struct PhaseActionView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        Group {
            switch store.state.phase {
            case .planning:
                PlanningView()
            case .swap:
                SwapView()
            case .assignment:
                AssignmentView()
            case .requisition:
                RequisitionView()
            case .gameOver:
                GameOverView()
            case .trick:
                TurnHintView()
            }
        }
        .frame(maxWidth: .infinity)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
        .animation(.spring(response: 0.34, dampingFraction: 0.78), value: store.state.phase)
    }
}

struct PlanningView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: store.state.isFamine ? "Famine year" : "Choose the main task",
                subtitle: store.state.isFamine ? "No trump suit is used this year." : "Pick the job suit for this year.",
                icon: store.state.isFamine ? .warning : .jobs,
                urgent: store.state.isFamine
            )

            if store.state.isFamine {
                Text("No trump suit is used this year.")
                    .font(.kolkhozLabel(.subheadline))
                    .foregroundStyle(Color.kolkhozCreamDim)
            } else {
                HStack(spacing: 8) {
                    ForEach(Suit.allCases) { suit in
                        Button {
                            store.setTrump(suit)
                        } label: {
                            AssignmentTargetButton(
                                suit: suit,
                                selected: store.state.trump == suit,
                                title: suit.rawValue
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .panelStyle()
    }
}

struct SwapView: View {
    @EnvironmentObject var store: GameStore
    @State var selectedHand: Card?
    @State var selectedHidden: Card?
    @State var selectedRevealed: Card?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: "Swap before the year",
                subtitle: "Trade one hand card with your cellar.",
                icon: .cellar
            )

            Text("Hand")
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCreamDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.state.players[0].hand) { card in
                        CardButton(card: card, selected: selectedHand == card, highlighted: true) {
                            selectedHand = card
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Text("Cellar")
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCreamDim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.state.players[0].plot.hidden) { card in
                        CardButton(card: card, selected: selectedHidden == card, highlighted: true) {
                            selectedHidden = card
                            selectedRevealed = nil
                        }
                    }
                    ForEach(store.state.players[0].plot.revealed) { card in
                        CardButton(card: card, selected: selectedRevealed == card, highlighted: true) {
                            selectedRevealed = card
                            selectedHidden = nil
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Button("Swap selected") {
                    guard let hand = selectedHand else { return }
                    if let hidden = selectedHidden {
                        store.swap(handCard: hand, plotCard: hidden, revealed: false)
                    } else if let revealed = selectedRevealed {
                        store.swap(handCard: hand, plotCard: revealed, revealed: true)
                    }
                    selectedHand = nil
                    selectedHidden = nil
                    selectedRevealed = nil
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                .disabled(selectedHand == nil || (selectedHidden == nil && selectedRevealed == nil) || store.state.swapCount.contains(0))

                if store.state.swapCount.contains(0) {
                    Button("Undo") {
                        store.undoSwap()
                    }
                    .buttonStyle(CommandButtonStyle(prominent: false))
                }

                Button("Start tricks") {
                    store.confirmSwap()
                }
                .buttonStyle(CommandButtonStyle(prominent: false))
            }
        }
        .panelStyle()
    }
}

struct AssignmentView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: "Assign captured work",
                subtitle: "Send each trick card to a valid job.",
                icon: .jobs
            )

            ForEach(store.state.lastTrick) { play in
                HStack(spacing: 10) {
                    CardView(card: play.card, size: .small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.state.players[play.playerID].name)
                            .font(.kolkhozLabel(.caption))
                            .foregroundStyle(Color.kolkhozCream)
                        Text("Captured work")
                            .font(.kolkhozLabel(.caption2))
                            .foregroundStyle(Color.kolkhozSmoke)
                    }
                    .frame(width: 86, alignment: .leading)
                    ForEach(legalTargets) { suit in
                        Button {
                            store.assign(play.card, to: suit)
                        } label: {
                            AssignmentTargetButton(
                                suit: suit,
                                selected: store.state.pendingAssignments[play.card.id] == suit,
                                title: suit.shortName
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color.kolkhozBlack.opacity(0.35), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.kolkhozSteel.opacity(0.7), lineWidth: 1)
                }
            }

            Button("Submit assignments") {
                store.submitAssignments()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
            .disabled(store.state.pendingAssignments.count != store.state.lastTrick.count)
        }
        .panelStyle()
    }

    var legalTargets: [Suit] {
        Array(Set(store.state.lastTrick.map(\.card.suit))).sorted { $0.rawValue < $1.rawValue }
    }
}

struct AssignmentJobsView: View {
    @EnvironmentObject private var store: GameStore
    @Binding var jobTargets: [Suit: CGPoint]
    @State private var targetFrames: [Suit: CGRect] = [:]
    @State private var dragging: AssignmentDragState?
    @State private var hoveredSuit: Suit?

    private var isAssignmentPhase: Bool { store.state.phase == .assignment }
    private var legalTargets: [Suit] {
        Array(Set(store.state.lastTrick.map(\.card.suit))).sorted { $0.rawValue < $1.rawValue }
    }
    private var legalTargetSet: Set<Suit> { Set(legalTargets) }

    var body: some View {
        VStack(spacing: 8) {
            assignmentHeader

            GeometryReader { proxy in
                let spacing: CGFloat = proxy.size.width < 560 ? 6 : 10
                let compactGrid = proxy.size.width < 430
                let columnCount = compactGrid ? 2 : Suit.allCases.count
                let rowCount = compactGrid ? 2 : 1
                let tileHeight = max(106, (proxy.size.height - spacing * CGFloat(rowCount - 1)) / CGFloat(rowCount))
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
                            onDragChanged: updateDrag(_:startCenter:translation:),
                            onDragEnded: finishDrag(_:translation:)
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

            assignmentFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if let dragging {
                AssignmentDragGhost(drag: dragging, canDrop: hoveredSuit != nil)
                    .zIndex(80)
            }
        }
    }

    private var assignmentHeader: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 520

            HStack(spacing: compact ? 6 : 10) {
                PanelTitleRow(
                    title: isAssignmentPhase ? "Assign captured work" : "Jobs",
                    subtitle: isAssignmentPhase ? "Drag each captured card to a valid job." : "Track work progress and rewards.",
                    icon: .jobs,
                    compact: compact
                )
                .layoutPriority(1)

                if isAssignmentPhase {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: compact ? -18 : -14) {
                            ForEach(store.state.lastTrick) { play in
                                AssignmentCapturedCard(
                                    play: play,
                                    playerName: store.state.players[play.playerID].name,
                                    assignedSuit: store.state.pendingAssignments[play.card.id],
                                    dragging: dragging?.card == play.card,
                                    onDragChanged: updateDrag(_:startCenter:translation:),
                                    onDragEnded: finishDrag(_:translation:)
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                    .frame(width: min(compact ? 150 : 210, proxy.size.width * 0.38), height: compact ? 60 : 72)
                }
            }
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 6 : 8)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(CommandPanelBackground())
        }
        .frame(height: isAssignmentPhase ? 84 : 62)
    }

    private var assignmentFooter: some View {
        HStack(spacing: 8) {
            if isAssignmentPhase {
                ForEach(legalTargets) { suit in
                    SuitBadge(suit: suit, compact: true)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.kolkhozBlack.opacity(0.35), in: RoundedRectangle(cornerRadius: 5))
                }
                Spacer(minLength: 4)
                Text("\(store.state.pendingAssignments.count)/\(store.state.lastTrick.count)")
                    .font(.kolkhozTitle(.caption))
                    .monospacedDigit()
                    .foregroundStyle(Color.kolkhozGold)
                Button("Submit") {
                    store.submitAssignments()
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                .disabled(store.state.pendingAssignments.count != store.state.lastTrick.count)
            } else {
                Spacer()
            }
        }
        .frame(minHeight: 42)
        .padding(.horizontal, 10)
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
        targetFrames[suit] = frame
        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
    }

    private func updateDrag(_ card: Card, startCenter: CGPoint, translation: CGSize) {
        let drag = AssignmentDragState(card: card, startCenter: startCenter, translation: translation)
        dragging = drag
        hoveredSuit = targetFrames.first { suit, frame in
            legalTargetSet.contains(suit) && frame.contains(drag.currentCenter)
        }?.key
    }

    private func finishDrag(_ card: Card, translation: CGSize) {
        defer {
            dragging = nil
            hoveredSuit = nil
        }
        guard let drag = dragging else { return }
        if let target = targetFrames.first(where: { suit, frame in
            legalTargetSet.contains(suit) && frame.contains(drag.currentCenter)
        })?.key {
            store.assign(card, to: target)
        }
    }
}

struct AssignmentJobTile: View {
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let reward: Card?
    let assignedCards: [AssignmentDisplayCard]
    let pendingHours: Int
    let highlighted: Bool
    let validTarget: Bool
    let hovered: Bool
    let onDragChanged: (Card, CGPoint, CGSize) -> Void
    let onDragEnded: (Card, CGSize) -> Void

    private var totalHours: Int { hours + pendingHours }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                SuitMark(suit: suit, size: 16)
                if highlighted {
                    GameIcon(.medalStar, size: 12)
                }
                Spacer()
                Text(claimed ? "DONE" : "\(totalHours)/40")
                    .font(.kolkhozTitle(.caption2))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .foregroundStyle(claimed ? Color.kolkhozGreen : Color.kolkhozGold)
            }

            ProgressBar(value: min(Double(totalHours) / 40.0, 1), complete: claimed)

            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: -40) {
                    ForEach(assignedCards) { item in
                        AssignmentTileCard(
                            item: item,
                            onDragChanged: onDragChanged,
                            onDragEnded: onDragEnded
                        )
                    }
                    if assignedCards.isEmpty {
                        Text(validTarget ? "DROP" : " ")
                            .font(.kolkhozTitle(.caption2))
                            .foregroundStyle(validTarget ? Color.kolkhozGold : Color.clear)
                            .frame(maxWidth: .infinity, minHeight: 78)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                if let reward, !claimed {
                    MiniRewardCard(card: reward, claimed: totalHours >= 40)
                        .scaleEffect(1.05)
                }
            }
        }
        .padding(8)
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
    let play: TrickPlay
    let playerName: String
    let assignedSuit: Suit?
    let dragging: Bool
    let onDragChanged: (Card, CGPoint, CGSize) -> Void
    let onDragEnded: (Card, CGSize) -> Void
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
                Text(assignedSuit?.shortName ?? storeName)
                    .font(.kolkhozTitle(.caption2))
                    .foregroundStyle(assignedSuit == nil ? Color.kolkhozCreamDim : Color.kolkhozGreen)
                    .lineLimit(1)
            }
            .frame(width: 48, height: 74)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 5, coordinateSpace: .local)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { value in onDragChanged(play.card, startCenter, value.translation) }
                    .onEnded { value in onDragEnded(play.card, value.translation) }
            )
        }
        .frame(width: 48, height: 74)
    }

    private var storeName: String {
        playerName
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

struct PlotOverviewView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                PanelTitleRow(
                    title: "Private plot",
                    subtitle: "Cellar cards kept from the brigade.",
                    icon: .plot
                )

                HStack(alignment: .top, spacing: 12) {
                    PlotColumn(title: "Hidden", cards: store.state.players[0].plot.hidden, hidden: true)
                    PlotColumn(title: "Revealed", cards: store.state.players[0].plot.revealed, hidden: false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if store.state.players[0].plot.hidden.isEmpty && store.state.players[0].plot.revealed.isEmpty {
                VStack(spacing: 8) {
                    Spacer(minLength: 58)
                    PlotEmptyOrnament()
                        .frame(maxWidth: 190, maxHeight: 132)
                        .opacity(0.86)
                    Text("No cellar cards yet")
                        .font(.kolkhozLabel(.caption))
                        .textCase(.uppercase)
                        .foregroundStyle(Color.kolkhozCreamDim)
                    Spacer(minLength: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(12)
        .background(CommandPanelBackground())
    }
}

struct PlotColumn: View {
    let title: String
    let cards: [Card]
    let hidden: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .sectionTitle()
            HStack(alignment: .top, spacing: -34) {
                ForEach(cards) { card in
                    if hidden {
                        CardBackView(size: .medium)
                    } else {
                        CardView(card: card, size: .medium)
                    }
                }
                if cards.isEmpty {
                    Text("-")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.kolkhozSmoke.opacity(0.7))
                        .frame(width: 58, height: 82)
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SwapPlotView: View {
    @EnvironmentObject private var store: GameStore
    @State private var selectedHand: Card?
    @State private var selectedPlot: PlotSelection?

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                ForEach(store.state.players.dropFirst()) { player in
                    SwapBotPanel(player: player, active: store.state.currentPlayer == player.id)
                }
            }
            .frame(maxHeight: 86)

            HStack(alignment: .top, spacing: 12) {
                SwapCardColumn(
                    title: "Hand",
                    subtitle: "Choose one card",
                    cards: store.state.players[0].hand,
                    selectedCard: selectedHand,
                    hidden: false
                ) { card in
                    selectedHand = card
                }

                VStack(spacing: 10) {
                    SwapPlotColumn(
                        title: "Hidden",
                        cards: store.state.players[0].plot.hidden,
                        zone: .hidden,
                        selectedPlot: selectedPlot
                    ) { selectedPlot = $0 }

                    SwapPlotColumn(
                        title: "Revealed",
                        cards: store.state.players[0].plot.revealed,
                        zone: .revealed,
                        selectedPlot: selectedPlot
                    ) { selectedPlot = $0 }
                }
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 10) {
                Text(swapStatus)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .lineLimit(1)
                Spacer()
                if store.state.swapCount.contains(0) {
                    Button("Undo") {
                        store.undoSwap()
                        selectedHand = nil
                        selectedPlot = nil
                    }
                    .buttonStyle(CommandButtonStyle(prominent: false))
                }
                Button(store.state.swapCount.contains(0) ? "Confirm swap" : "Keep hand") {
                    store.confirmSwap()
                    selectedHand = nil
                    selectedPlot = nil
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                Button("Swap selected") {
                    guard let selectedHand, let selectedPlot else { return }
                    store.swap(handCard: selectedHand, plotCard: selectedPlot.card, revealed: selectedPlot.zone == .revealed)
                    self.selectedHand = nil
                    self.selectedPlot = nil
                }
                .buttonStyle(CommandButtonStyle(prominent: false))
                .disabled(selectedHand == nil || selectedPlot == nil || store.state.swapCount.contains(0))
            }
            .frame(minHeight: 46)
            .padding(.horizontal, 10)
        }
        .padding(12)
        .background(CommandPanelBackground())
    }

    private var swapStatus: String {
        if store.state.swapCount.contains(0) {
            "Swap staged. Confirm to start the year."
        } else {
            "Swap one hand card with your hidden or revealed plot."
        }
    }
}

struct SwapBotPanel: View {
    let player: PlayerState
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            PortraitView(player: player, human: false)
            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.caption.weight(.black))
                    .foregroundStyle(active ? Color.kolkhozGold : Color.kolkhozCream)
                HStack(spacing: -4) {
                    ForEach(0..<min(player.hand.count, 5), id: \.self) { _ in
                        CardBackThumbnail()
                    }
                }
                Text("\(player.plot.hidden.count) hidden  \(player.plot.revealed.count) revealed")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.kolkhozSmoke)
            }
            Spacer()
            if active {
                GameIcon(.gears, size: 22)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 74)
        .background(active ? Color.kolkhozRed.opacity(0.22) : Color.kolkhozBlack.opacity(0.30), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(active ? Color.kolkhozGold : Color.kolkhozSteel.opacity(0.62), lineWidth: active ? 2 : 1)
        }
    }
}

struct PlotSelection: Equatable {
    let card: Card
    let zone: PlotCardZone
}

struct SwapCardColumn: View {
    let title: String
    let subtitle: String
    let cards: [Card]
    let selectedCard: Card?
    let hidden: Bool
    let onSelect: (Card) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColumnHeader(title: title, subtitle: subtitle)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -16) {
                    ForEach(cards) { card in
                        Button { onSelect(card) } label: {
                            if hidden {
                                CardBackView(size: .medium)
                            } else {
                                CardView(card: card, size: .medium)
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedCard == card ? Color.kolkhozGreen : Color.clear, lineWidth: 3)
                        }
                    }
                }
                .padding(.vertical, 3)
                .padding(.trailing, 16)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SwapPlotColumn: View {
    let title: String
    let cards: [Card]
    let zone: PlotCardZone
    let selectedPlot: PlotSelection?
    let onSelect: (PlotSelection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ColumnHeader(title: title, subtitle: "\(cards.count) cards")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: -16) {
                    ForEach(cards) { card in
                        Button {
                            onSelect(PlotSelection(card: card, zone: zone))
                        } label: {
                            if zone == .hidden {
                                CardBackView(size: .medium)
                            } else {
                                CardView(card: card, size: .medium)
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedPlot == PlotSelection(card: card, zone: zone) ? Color.kolkhozGreen : Color.clear, lineWidth: 3)
                        }
                    }
                    if cards.isEmpty {
                        Text("-")
                            .font(.title2.weight(.black))
                            .foregroundStyle(Color.kolkhozSmoke)
                            .frame(width: 58, height: 82)
                    }
                }
                .padding(.vertical, 3)
                .padding(.trailing, 16)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.26), in: RoundedRectangle(cornerRadius: 6))
    }
}

struct RequisitionPlotView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(store.state.players) { player in
                        RequisitionPlayerPlot(player: player, exiledCards: exiledCards)
                    }
                }
                .frame(maxHeight: .infinity)
            }

            RequisitionSummaryPanel()
                .frame(width: 310)
        }
        .padding(12)
        .background(CommandPanelBackground())
    }

    private var exiledCards: Set<Card> {
        Set(store.state.exiled[store.state.year, default: []])
    }
}

struct RequisitionPlayerPlot: View {
    let player: PlayerState
    let exiledCards: Set<Card>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                PortraitView(player: player, human: player.id == 0)
                Text(player.id == 0 ? "You" : player.name)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.kolkhozCream)
                    .lineLimit(1)
            }
            HStack(alignment: .top, spacing: -28) {
                ForEach(player.plot.revealed) { card in
                    CardView(card: card, size: .small)
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(exiledCards.contains(card) ? Color.kolkhozRedBright : Color.clear, lineWidth: 3)
                        }
                        .scaleEffect(exiledCards.contains(card) ? 1.08 : 1)
                }
                ForEach(0..<player.plot.hidden.count, id: \.self) { _ in
                    CardBackView(size: .small)
                        .opacity(0.72)
                }
                if player.plot.revealed.isEmpty && player.plot.hidden.isEmpty {
                    Text("-")
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.kolkhozSmoke)
                        .frame(width: 48, height: 68)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.kolkhozBlack.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozSteel.opacity(0.62), lineWidth: 1)
        }
    }
}

struct RequisitionSummaryPanel: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: "Requisition",
                subtitle: "Unprotected plot cards may be taken.",
                icon: .warning,
                urgent: true
            )
            Text("Year \(store.state.year) audit")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.kolkhozCreamDim)

            ScrollView {
                VStack(spacing: 8) {
                    if store.state.requisitionEvents.isEmpty {
                        Text("All fields met the quota.")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.kolkhozCreamDim)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(store.state.requisitionEvents) { event in
                            RequisitionEventRow(event: event)
                        }
                    }
                }
            }

            Button(store.state.year >= 5 ? "Finish plan" : "Continue to year \(store.state.year + 1)") {
                store.continueAfterRequisition()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
        }
        .padding(10)
        .background(Color.kolkhozRedDark.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozRed.opacity(0.55), lineWidth: 1.5)
        }
    }
}

struct NorthHistoryView: View {
    @EnvironmentObject private var store: GameStore

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(1...5, id: \.self) { year in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Year \(year)")
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(year == store.state.year ? Color.kolkhozRedBright : Color.kolkhozGold)
                        Spacer()
                        Text("\(store.state.exiled[year, default: []].count)")
                            .font(.caption2.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(Color.kolkhozCreamDim)
                    }
                    ScrollView {
                        VStack(spacing: -38) {
                            ForEach(store.state.exiled[year, default: []]) { card in
                                CardView(card: card, size: .small)
                            }
                            if store.state.exiled[year, default: []].isEmpty {
                                VStack(spacing: 4) {
                                    BadgeSealOrnament()
                                        .frame(width: 34, height: 34)
                                        .opacity(year == store.state.year ? 0.56 : 0.36)
                                    Text("-")
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(Color.kolkhozSmoke.opacity(0.72))
                                }
                                .frame(maxWidth: .infinity, minHeight: 80)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.bottom, 38)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Color.kolkhozBlack.opacity(year == store.state.year ? 0.38 : 0.24), in: RoundedRectangle(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(year == store.state.year ? Color.kolkhozRedBright : Color.kolkhozSteel.opacity(0.6), lineWidth: year == store.state.year ? 2 : 1)
                }
            }
        }
        .padding(12)
        .background(CommandPanelBackground())
    }
}

struct InGameOptionsPanel: View {
    @Binding var language: AppLanguage
    let onNewGame: () -> Void
    let onReturnToLobby: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Menu")
                .sectionTitle()
            HStack(spacing: 10) {
                Button("New game", action: onNewGame)
                    .buttonStyle(CommandButtonStyle(prominent: true))
                Button("Main menu", action: onReturnToLobby)
                    .buttonStyle(CommandButtonStyle(prominent: false))
                Button("Language \(language.toggleTitle)") {
                    language.toggle()
                }
                .buttonStyle(CommandButtonStyle(prominent: false))
            }

            Divider()
                .overlay(Color.kolkhozGold.opacity(0.35))

            VStack(alignment: .leading, spacing: 7) {
                Text("Rules")
                    .font(.subheadline.weight(.black))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                Text("Play tricks, assign captured work to matching jobs, complete quotas, and protect your plot from requisition. Highest final plot score wins.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Trump face cards: Jack goes north, Queen exposes everyone, King doubles exile.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .panelStyle()
    }
}

struct ColumnHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.black))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozGold)
            Spacer()
            Text(subtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.kolkhozSmoke)
        }
    }
}

struct RequisitionView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Requisition")
                .sectionTitle(color: .kolkhozRedBright)

            if store.state.requisitionEvents.isEmpty {
                Text("All fields met the quota.")
                    .foregroundStyle(Color.kolkhozCreamDim)
            } else {
                ForEach(store.state.requisitionEvents) { event in
                    RequisitionEventRow(event: event)
                }
            }

            Button(store.state.year >= 5 ? "Finish plan" : "Continue to year \(store.state.year + 1)") {
                store.continueAfterRequisition()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
        }
        .panelStyle()
    }
}

struct GameOverView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PanelTitleRow(
                title: "Game over",
                subtitle: "Final cellar and medal scores.",
                icon: .medalStar
            )
            if let result = store.state.gameResult {
                Text("Winner: \(store.state.players[result.winnerID].name)")
                    .font(.headline)
                    .foregroundStyle(Color.kolkhozGold)
                ForEach(store.state.players) { player in
                    HStack {
                        Text(player.name)
                        Spacer()
                        Text("\(result.scores[player.id, default: 0])")
                            .monospacedDigit()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.kolkhozCream)
                }
            }
            Button("New game") {
                store.newGame()
            }
            .buttonStyle(CommandButtonStyle(prominent: true))
        }
        .panelStyle()
    }
}

struct TurnHintView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        let valid = store.validCardsForHuman()
        HStack(spacing: 10) {
            GameIcon(store.state.currentPlayer == 0 ? .playTap : .gears, size: 24)
            Text(store.state.currentPlayer == 0 ? "Play \(valid.count) legal card\(valid.count == 1 ? "" : "s")." : "AI players are resolving their turns.")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.kolkhozCream)
            Spacer()
        }
        .panelStyle()
    }
}

struct PlayerHandTrayView: View {
    @EnvironmentObject private var store: GameStore
    @Binding var playDrag: PlayCardDragState?
    let playCard: (Card, CGPoint) -> Void

    private struct CellarPreviewCard: Identifiable {
        let id: String
        let card: Card
        let hidden: Bool
    }

    private var cellarCards: [CellarPreviewCard] {
        let revealed = store.state.players[0].plot.revealed.enumerated().map { index, card in
            CellarPreviewCard(id: "revealed-\(index)-\(card.id)", card: card, hidden: false)
        }
        let hidden = store.state.players[0].plot.hidden.enumerated().map { index, card in
            CellarPreviewCard(id: "hidden-\(index)-\(card.id)", card: card, hidden: true)
        }
        return Array((revealed + hidden).prefix(4))
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 14) {
            if !cellarCards.isEmpty {
                HStack(alignment: .bottom, spacing: -44) {
                    ForEach(cellarCards) { preview in
                        if preview.hidden {
                            CardBackView(size: .large)
                        } else {
                            CardView(card: preview.card, size: .large)
                        }
                    }
                }

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .kolkhozGold, .kolkhozGold, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 3, height: 72)
                    .shadow(color: .kolkhozGold.opacity(0.6), radius: 5)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: store.state.phase == .assignment ? -42 : 10) {
                    ForEach(store.state.players[0].hand) { card in
                        let isPlayable = store.validCardsForHuman().contains(card)
                        let isMuted = store.state.phase == .trick && !isPlayable
                        CardButton(
                            card: card,
                            selected: false,
                            highlighted: store.state.phase == .trick && isPlayable,
                            muted: isMuted,
                            positionedAction: store.state.phase == .trick && isPlayable ? { startCenter in
                                playCard(card, startCenter)
                            } : nil,
                            dragAction: store.state.phase == .trick && isPlayable ? { startCenter in
                                playCard(card, startCenter)
                            } : nil,
                            dragChanged: { card, startCenter, translation in
                                playDrag = PlayCardDragState(
                                    card: card,
                                    startCenter: startCenter,
                                    translation: translation
                                )
                            },
                            dragEnded: { _, _ in
                                playDrag = nil
                            }
                        ) {
                            if isPlayable {
                                playCard(card, .zero)
                            }
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 8)
            }
            .frame(height: CardSize.large.height + 18)
        }
        .frame(minHeight: CardSize.large.height + 30)
        .frame(maxWidth: .infinity, alignment: .bottom)
        .padding(.top, 10)
        .padding(.horizontal, 16)
        .background(
            LinearGradient(
                colors: [Color.clear, Color.kolkhozGold.opacity(0.08), Color.kolkhozBlack.opacity(0.70)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

struct PlayerHandView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your hand")
                    .sectionTitle()
                Spacer()
                Text("Cellar \(store.state.players[0].plot.hidden.count + store.state.players[0].plot.revealed.count)")
                    .font(.caption.weight(.bold))
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
