import KolkhozCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct GameBoardView: View {
    @EnvironmentObject var store: GameStore
    @Binding var language: AppLanguage
    let onMenu: () -> Void
    @State private var selectedPanel: GamePanel?

    private var actionPanel: GamePanel {
        switch store.state.phase {
        case .assignment:
            .jobs
        case .requisition:
            .plot
        case .swap:
            .plot
        default:
            .game
        }
    }

    private var displayPanel: GamePanel {
        selectedPanel ?? actionPanel
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.kolkhozBackground, .kolkhozIron, .kolkhozBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [.kolkhozGold.opacity(0.12), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 430
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let compactPhone = proxy.size.width < 560
                let phoneLandscape = proxy.size.height < 430
                let margin: CGFloat = compactPhone ? 4 : 6
                let topInset = compactPhone || phoneLandscape ? 0 : proxy.safeAreaInsets.top
                let bottomInset = compactPhone || phoneLandscape ? 0 : proxy.safeAreaInsets.bottom
                let horizontalGutter = compactPhone || phoneLandscape ? 0 : max(24, min(42, proxy.size.width * 0.04))
                let leadingInset = horizontalGutter
                let trailingInset = horizontalGutter
                let contentWidth = max(280, proxy.size.width - leadingInset - trailingInset - margin * 2)
                let contentHeight = max(240, proxy.size.height - topInset - bottomInset - margin * 2)
                let railWidth = phoneLandscape ? 48 : min(58, max(48, contentWidth * 0.07))
                let compactNavHeight: CGFloat = 54
                let gameWidth = compactPhone ? contentWidth : max(240, contentWidth - railWidth)
                let gameHeight = compactPhone ? max(220, contentHeight - compactNavHeight) : contentHeight

                Group {
                    if compactPhone {
                        VStack(spacing: 0) {
                            CompactNavBarView(
                                activePanel: displayPanel,
                                actionPanel: actionPanel,
                                language: language,
                                onMenu: onMenu,
                                onSelectPanel: { selectedPanel = $0 },
                                onToggleLanguage: { language.toggle() }
                            )
                            .frame(width: contentWidth, height: compactNavHeight)
                            LandscapeGameAreaView(
                                displayPanel: displayPanel,
                                language: $language,
                                onReturnToLobby: onMenu,
                                onNewGame: {
                                    store.newGame()
                                    selectedPanel = nil
                                }
                            )
                            .frame(width: gameWidth, height: gameHeight)
                        }
                    } else {
                        HStack(spacing: 0) {
                            NavRailView(
                                activePanel: displayPanel,
                                actionPanel: actionPanel,
                                language: language,
                                width: railWidth,
                                onMenu: onMenu,
                                onSelectPanel: { selectedPanel = $0 },
                                onToggleLanguage: { language.toggle() }
                            )
                            LandscapeGameAreaView(
                                displayPanel: displayPanel,
                                language: $language,
                                onReturnToLobby: onMenu,
                                onNewGame: {
                                    store.newGame()
                                    selectedPanel = nil
                                }
                            )
                            .frame(width: gameWidth, height: contentHeight)
                            .layoutPriority(1)
                        }
                    }
                }
                .frame(width: contentWidth, height: contentHeight, alignment: .topLeading)
                .offset(x: leadingInset + margin, y: topInset + margin)
                .clipped()
            }
        }
        .alert("Move unavailable", isPresented: Binding(
            get: { store.lastError != nil },
            set: { if !$0 { store.lastError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.lastError ?? "")
        }
        .onChange(of: store.state.phase) { _, _ in
            selectedPanel = nil
        }
    }
}

enum GamePanel: Equatable {
    case options
    case game
    case jobs
    case north
    case plot
}

struct NavRailView: View {
    @EnvironmentObject var store: GameStore
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let language: AppLanguage
    let width: CGFloat
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void
    let onToggleLanguage: () -> Void

    var body: some View {
        VStack(spacing: 5) {
            Button { onSelectPanel(.options) } label: {
                NavButton(title: "Menu", icon: .menu, active: activePanel == .options, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
            Button { onSelectPanel(.game) } label: {
                NavButton(title: "Brigade", icon: .brigade, active: activePanel == .game, action: actionPanel == .game)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Brigade")
            Button { onSelectPanel(.jobs) } label: {
                NavButton(title: "Jobs", icon: .jobs, active: activePanel == .jobs, action: actionPanel == .jobs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jobs")
            Button { onSelectPanel(.north) } label: {
                NavButton(title: "The North", icon: .north, active: activePanel == .north, action: actionPanel == .north)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("The North")
            Button { onSelectPanel(.plot) } label: {
                NavButton(title: "Plot", icon: .plot, active: activePanel == .plot, action: actionPanel == .plot)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plot")

            Spacer(minLength: 8)

            Button(action: onToggleLanguage) {
                NavButton(title: language.rawValue, icon: .language, active: false, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Language \(language.rawValue)")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 5)
        .frame(width: width)
        .frame(maxHeight: .infinity)
        .background(CommandPanelBackground())
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.kolkhozGold.opacity(0.42))
                .frame(width: 1)
        }
    }
}

struct NavButton: View {
    let title: String
    let icon: GameIconAsset
    let active: Bool
    let action: Bool

    var body: some View {
        ZStack {
            GameIcon(icon, size: 25, muted: !active)
        }
        .foregroundStyle(active ? Color.kolkhozOnAccent : Color.kolkhozCreamDim)
        .frame(width: 40, height: 48)
        .background(
            LinearGradient(
                colors: active
                    ? [Color.kolkhozRedDark, Color.kolkhozRed, Color.kolkhozRedDark]
                    : [Color.kolkhozPanel.opacity(0.84), Color.kolkhozBlack.opacity(0.52)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 4)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 4)
                .stroke(active ? Color.kolkhozGold : Color.kolkhozSteel.opacity(0.8), lineWidth: 2)
        }
        .overlay {
            if active {
                PrintCornerFrame(cornerRadius: 4, accent: .kolkhozGold)
                    .opacity(0.9)
            }
        }
        .overlay(alignment: .topTrailing) {
            if action {
                GameIcon(.medalStar, size: 16)
                    .padding(4)
            }
        }
        .shadow(color: active ? Color.kolkhozRed.opacity(0.35) : .clear, radius: 8, y: 3)
        .help(title)
    }
}

struct CompactNavBarView: View {
    let activePanel: GamePanel
    let actionPanel: GamePanel
    let language: AppLanguage
    let onMenu: () -> Void
    let onSelectPanel: (GamePanel) -> Void
    let onToggleLanguage: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button { onSelectPanel(.options) } label: {
                NavButton(title: "Menu", icon: .menu, active: activePanel == .options, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Menu")
            Button { onSelectPanel(.game) } label: {
                NavButton(title: "Brigade", icon: .brigade, active: activePanel == .game, action: actionPanel == .game)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Brigade")
            Button { onSelectPanel(.jobs) } label: {
                NavButton(title: "Jobs", icon: .jobs, active: activePanel == .jobs, action: actionPanel == .jobs)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jobs")
            Button { onSelectPanel(.north) } label: {
                NavButton(title: "The North", icon: .north, active: activePanel == .north, action: actionPanel == .north)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("The North")
            Button { onSelectPanel(.plot) } label: {
                NavButton(title: "Plot", icon: .plot, active: activePanel == .plot, action: actionPanel == .plot)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Plot")

            Spacer(minLength: 2)

            Button(action: onToggleLanguage) {
                NavButton(title: language.rawValue, icon: .language, active: false, action: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Language \(language.rawValue)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .frame(maxWidth: .infinity)
        .background(CommandPanelBackground())
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.kolkhozGold.opacity(0.42))
                .frame(height: 1)
        }
    }
}

struct LandscapeGameAreaView: View {
    @EnvironmentObject private var store: GameStore
    let displayPanel: GamePanel
    @Binding var language: AppLanguage
    let onReturnToLobby: () -> Void
    let onNewGame: () -> Void
    @State private var playDrag: PlayCardDragState?
    @State private var flyingPlay: FlyingPlayCardState?
    @State private var activeEngineEvent: KolkhozAnimationEvent?
    @State private var activeEngineEventLanded = false
    @State private var humanPlayTarget: CGPoint?
    @State private var playSlotCenters: [Int: CGPoint] = [:]
    @State private var playerPanelCenters: [Int: CGPoint] = [:]
    @State private var jobTargets: [Suit: CGPoint] = [:]

    var body: some View {
        ZStack(alignment: .bottom) {
            TrickAreaShellView(
                displayPanel: displayPanel,
                language: $language,
                onReturnToLobby: onReturnToLobby,
                onNewGame: onNewGame,
                humanPlayTarget: $humanPlayTarget,
                playSlotCenters: $playSlotCenters,
                playerPanelCenters: $playerPanelCenters,
                jobTargets: $jobTargets,
                hiddenPlayIDs: hiddenPlayIDs
            )
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if store.state.phase == .trick && displayPanel == .game {
                PlayerHandTrayView(
                    playDrag: $playDrag,
                    playCard: animateAndPlay(_:from:)
                )
                .padding(.leading, 18)
                .padding(.trailing, 24)
                .padding(.bottom, 8)
                .zIndex(10)
            }

            if let playDrag {
                PlayCardDragGhost(drag: playDrag)
                    .zIndex(50)
            }

            if let flyingPlay {
                FlyingPlayCardGhost(flight: flyingPlay)
                    .zIndex(60)
            }

            if let activeEngineEvent {
                engineAnimationOverlay(for: activeEngineEvent)
                    .zIndex(70)
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
    }

    private var hiddenPlayIDs: Set<String> {
        var ids = Set<String>()
        for event in store.animationEvents {
            if case .cardPlayed(_, let playerID, let card) = event, playerID != 0 {
                ids.insert(playID(playerID: playerID, card: card))
            }
        }
        if case .cardPlayed(_, let playerID, let card) = activeEngineEvent, playerID != 0 {
            ids.insert(playID(playerID: playerID, card: card))
        }
        return ids
    }

    private func animateAndPlay(_ card: Card, from startCenter: CGPoint) {
        guard store.state.phase == .trick, store.validCardsForHuman().contains(card) else {
            store.play(card)
            return
        }

        guard let humanPlayTarget else {
            store.play(card)
            return
        }

        let flight = FlyingPlayCardState(card: card, startCenter: startCenter, endCenter: humanPlayTarget)
        playDrag = nil
        flyingPlay = flight

        withAnimation(.timingCurve(0.2, 0.9, 0.2, 1.0, duration: 0.42)) {
            flyingPlay?.landed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            store.play(card)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
            if flyingPlay?.id == flight.id {
                flyingPlay = nil
            }
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
            return playerID != 0 && playerPanelCenters[playerID] != nil && playSlotCenters[playerID] != nil
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

struct PlayCardDragState {
    let card: Card
    let startCenter: CGPoint
    let translation: CGSize

    var currentCenter: CGPoint {
        CGPoint(
            x: startCenter.x + translation.width,
            y: startCenter.y + translation.height
        )
    }

    var canCommit: Bool {
        translation.height < -44 && abs(translation.height) > abs(translation.width) * 0.55
    }
}

struct FlyingPlayCardState: Identifiable {
    let id = UUID()
    let card: Card
    let startCenter: CGPoint
    let endCenter: CGPoint
    var landed = false

    var currentCenter: CGPoint {
        landed ? endCenter : startCenter
    }
}

struct PlayCardDragGhost: View {
    let drag: PlayCardDragState

    var body: some View {
        CardView(card: drag.card, size: .large)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(drag.canCommit ? Color.kolkhozGreen : Color.kolkhozGold, lineWidth: 3)
            }
            .scaleEffect(1.08)
            .rotationEffect(.degrees(Double(drag.translation.width / 40)))
            .shadow(color: Color.kolkhozGold.opacity(0.55), radius: 18, y: 12)
            .position(drag.currentCenter)
            .allowsHitTesting(false)
    }
}

struct FlyingPlayCardGhost: View {
    let flight: FlyingPlayCardState

    var body: some View {
        CardView(card: flight.card, size: .large)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.kolkhozGold, lineWidth: 3)
            }
            .scaleEffect(flight.landed ? 0.98 : 1.08)
            .rotationEffect(.degrees(flight.landed ? 0 : 5))
            .opacity(flight.landed ? 0.72 : 1)
            .shadow(color: Color.kolkhozGold.opacity(0.55), radius: flight.landed ? 8 : 18, y: flight.landed ? 4 : 12)
            .position(flight.currentCenter)
            .allowsHitTesting(false)
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
                Text(valueText)
                    .font(.kolkhozDisplay(size: 30))
                    .foregroundStyle(Color.kolkhozGold)
                    .shadow(color: .black, radius: 3)
                    .transition(.scale(scale: 0.2).combined(with: .opacity))
                    .offset(y: -54)
            }
        }
        .position(center)
        .allowsHitTesting(false)
    }
}

struct RewardFlightView: View {
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
            Text("CLAIMED")
                .font(.kolkhozTitle(.caption2))
                .foregroundStyle(Color.kolkhozGreen)
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

            Text("NORTH")
                .font(.kolkhozTitle(.caption2))
                .foregroundStyle(Color.kolkhozRedBright)
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

struct TrickAreaShellView: View {
    @EnvironmentObject var store: GameStore
    let displayPanel: GamePanel
    @Binding var language: AppLanguage
    let onReturnToLobby: () -> Void
    let onNewGame: () -> Void
    @Binding var humanPlayTarget: CGPoint?
    @Binding var playSlotCenters: [Int: CGPoint]
    @Binding var playerPanelCenters: [Int: CGPoint]
    @Binding var jobTargets: [Suit: CGPoint]
    let hiddenPlayIDs: Set<String>

    var body: some View {
        VStack(spacing: 0) {
            InfoBarView(jobTargets: $jobTargets)
                .padding(.horizontal, 10)
                .padding(.top, 8)

            ZStack {
                switch displayPanel {
                case .options:
                    InGameOptionsPanel(
                        language: $language,
                        onNewGame: onNewGame,
                        onReturnToLobby: onReturnToLobby
                    )
                    .frame(maxWidth: 620)
                    .padding(.horizontal, 20)
                    .shadow(color: .black.opacity(0.5), radius: 16, y: 8)

                case .game:
                    PlayerColumnsView(
                        humanPlayTarget: $humanPlayTarget,
                        playSlotCenters: $playSlotCenters,
                        playerPanelCenters: $playerPanelCenters,
                        hiddenPlayIDs: hiddenPlayIDs
                    )
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, store.state.phase == .trick ? 112 : 10)

                    if store.state.phase != .trick && store.state.phase != .assignment {
                        PhaseActionView()
                            .frame(maxWidth: 500)
                            .padding(.horizontal, 20)
                            .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                    }

                case .jobs:
                    AssignmentJobsView(jobTargets: $jobTargets)
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                case .north:
                    NorthHistoryView()
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 10)

                case .plot:
                    Group {
                        if store.state.phase == .swap {
                            SwapPlotView()
                        } else if store.state.phase == .requisition {
                            RequisitionPlotView()
                        } else {
                            PlotOverviewView()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
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
                .stroke(Color.kolkhozGold, lineWidth: 3)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozRedDark.opacity(0.9), lineWidth: 1.5)
                .padding(6)
        }
        .overlay {
            PanelCornerOrnaments(size: 34, opacity: 0.22)
                .padding(2)
        }
        .shadow(color: .black.opacity(0.55), radius: 18, y: 8)
    }
}

struct InfoBarView: View {
    @EnvironmentObject var store: GameStore
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < 720
            let micro = proxy.size.width < 620
            HStack(spacing: 0) {
                InfoCell(label: compact ? "Y" : "Year", value: "\(store.state.year)/5", compact: compact)
                    .frame(width: micro ? 54 : (compact ? 64 : 92))
                InfoSuitCell(label: compact ? "T" : "Task", suit: store.state.trump, fallback: store.state.isFamine ? "Famine" : "-", compact: compact)
                    .frame(width: micro ? 42 : (compact ? 58 : 104))

                if let lead = store.state.currentTrick.first?.card.suit, !compact {
                    InfoSuitCell(label: "Lead", suit: lead, fallback: "-", compact: compact)
                        .frame(width: 104)
                }

                HStack(spacing: compact ? 3 : 6) {
                    ForEach(Suit.allCases) { suit in
                        InfoJobGauge(
                            suit: suit,
                            hours: store.state.workHours[suit, default: 0],
                            claimed: store.state.claimedJobs.contains(suit),
                            highlighted: store.state.trump == suit,
                            compact: compact,
                            jobTargets: $jobTargets
                        )
                        .frame(maxWidth: micro ? 42 : 58)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, micro ? 2 : (compact ? 4 : 8))

                InfoIconCell(
                    label: compact ? "" : "Cellar",
                    icon: .cellar,
                    value: "\(store.state.players[0].plot.hidden.reduce(0) { $0 + $1.value } + store.state.players[0].plot.revealed.reduce(0) { $0 + $1.value })",
                    warning: true,
                    compact: compact
                )
                .frame(width: micro ? 42 : (compact ? 52 : 116))
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
            .background(CommandPanelBackground())
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.kolkhozSteel.opacity(0.8), lineWidth: 1)
            }
        }
        .frame(height: 48)
    }
}

struct InfoCell: View {
    let label: String
    let value: String
    var warning = false
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            Text(label.uppercased())
                .font(.kolkhozLabel(.caption2))
                .foregroundStyle(warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            Text(value)
                .font(compact ? .kolkhozTitle(.caption) : .kolkhozTitle(.subheadline))
                .foregroundStyle(Color.kolkhozGold)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 6 : 10)
        .frame(height: 48)
        .background(warning ? Color.kolkhozRedDark.opacity(0.22) : Color.kolkhozBlack.opacity(0.24))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 1)
        }
    }
}

struct InfoIconCell: View {
    let label: String
    let icon: GameIconAsset
    let value: String
    var warning = false
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            GameIcon(icon, size: compact ? 17 : 20)
            if !label.isEmpty {
                Text(label.uppercased())
                    .font(.kolkhozLabel(.caption2))
                    .foregroundStyle(warning ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
            Text(value)
                .font(compact ? .kolkhozTitle(.caption) : .kolkhozTitle(.subheadline))
                .foregroundStyle(Color.kolkhozGold)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, compact ? 6 : 10)
        .frame(height: 48)
        .background(warning ? Color.kolkhozRedDark.opacity(0.22) : Color.kolkhozBlack.opacity(0.24))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 1)
        }
    }
}

struct InfoSuitCell: View {
    let label: String
    let suit: Suit?
    let fallback: String
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 6) {
            Text(label.uppercased())
                .font(.kolkhozLabel(.caption2))
                .foregroundStyle(Color.kolkhozSmoke)
            if let suit {
                SuitMark(suit: suit, size: compact ? 17 : 22)
            } else {
                Text(fallback)
                    .font(compact ? .kolkhozTitle(.caption2) : .kolkhozTitle(.caption))
                    .foregroundStyle(fallback == "Famine" ? Color.kolkhozRedBright : Color.kolkhozSmoke)
            }
        }
        .padding(.horizontal, compact ? 6 : 10)
        .frame(height: 48)
        .background(Color.kolkhozBlack.opacity(0.16))
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(Color.black.opacity(0.45))
                .frame(width: 1)
        }
    }
}

struct InfoJobGauge: View {
    let suit: Suit
    let hours: Int
    let claimed: Bool
    let highlighted: Bool
    let compact: Bool
    @Binding var jobTargets: [Suit: CGPoint]

    var body: some View {
        HStack(spacing: compact ? 2 : 4) {
            SuitMark(suit: suit, size: compact ? 15 : 19)
            if claimed {
                GameIcon(.check, size: compact ? 13 : 16)
            } else {
                Text(compact ? "\(hours)" : "\(hours)/40")
                    .font(compact ? .kolkhozTitle(.caption2) : .kolkhozTitle(.caption))
                    .foregroundStyle(Color.kolkhozSmoke)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(minWidth: compact ? 34 : 56)
        .padding(.horizontal, compact ? 4 : 7)
        .padding(.vertical, compact ? 5 : 6)
        .background(
            highlighted ? Color.kolkhozGold.opacity(0.20) : Color.kolkhozBlack.opacity(0.40),
            in: RoundedRectangle(cornerRadius: 3)
        )
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        let frame = proxy.frame(in: .named(GameBoardCoordinateSpace.main))
                        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
                    }
                    .onChange(of: proxy.frame(in: .named(GameBoardCoordinateSpace.main))) { _, frame in
                        jobTargets[suit] = CGPoint(x: frame.midX, y: frame.midY)
                    }
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(claimed ? Color.kolkhozGreen.opacity(0.8) : (highlighted ? Color.kolkhozGold : Color.kolkhozSteel.opacity(0.6)), lineWidth: 1)
        }
        .shadow(color: highlighted ? Color.kolkhozGold.opacity(0.28) : .clear, radius: 7)
    }
}

struct HeaderView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kolkhoz")
                    .font(.kolkhozDisplay(size: 20))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                Text("Five Year Plan")
                    .font(.kolkhozLabel(.caption2))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozCreamDim)
            }
            .frame(minWidth: 86, alignment: .leading)

            Spacer()

            StatusPill(title: "Year", value: "\(store.state.year)/5")
            StatusPill(title: "Phase", value: store.state.phase.rawValue.capitalized)
            StatusPill(title: "Task", value: store.state.isFamine ? "Famine" : (store.state.trump?.rawValue ?? "Unset"))

            Button {
                store.newGame()
            } label: {
                GameIcon(.gears, size: 24)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.kolkhozGold)
            .background(Color.kolkhozBlack.opacity(0.72), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.kolkhozGold.opacity(0.65), lineWidth: 1)
            }
            .accessibilityLabel("New game")
        }
        .padding(8)
        .background(CommandPanelBackground())
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.kolkhozGold, lineWidth: 2)
        }
    }
}

struct StatusPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(title.uppercased())
                .font(.kolkhozLabel(.caption2))
                .foregroundStyle(Color.kolkhozSmoke)
            Text(value)
                .font(.kolkhozTitle(.caption))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .foregroundStyle(Color.kolkhozGold)
                .shadow(color: .kolkhozGold.opacity(0.45), radius: 5)
        }
        .frame(width: 72, height: 42)
        .background(Color.kolkhozBlack.opacity(0.72), in: RoundedRectangle(cornerRadius: 3))
        .overlay {
            RoundedRectangle(cornerRadius: 3)
                .stroke(Color.kolkhozSteel.opacity(0.7), lineWidth: 1)
        }
    }
}

struct OpponentsView: View {
    @EnvironmentObject var store: GameStore

    var body: some View {
        HStack(spacing: 8) {
            ForEach(store.state.players.dropFirst()) { player in
                PlayerPanel(
                    player: player,
                    score: store.visibleScore(for: player.id),
                    active: store.state.currentPlayer == player.id,
                    human: false
                )
            }
        }
    }
}

struct PortraitView: View {
    let player: PlayerState
    let human: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: human
                            ? [Color.kolkhozGold.opacity(0.42), Color.kolkhozRedDark.opacity(0.72)]
                            : [Color.kolkhozSteel.opacity(0.58), Color.kolkhozBlack.opacity(0.82)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            portraitImage
                .resizable()
                .interpolation(.none)
            .antialiased(false)
                .scaledToFill()
                .frame(width: 32, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 3))
                .overlay {
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(Color.kolkhozBlack.opacity(0.68), lineWidth: 1)
                }
            VStack {
                HStack {
                    Spacer()
                    if human {
                        GameIcon(.medalStar, size: 9)
                    }
                }
                Spacer()
            }
            .padding(2)
        }
        .frame(width: 38, height: 42)
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(human ? Color.kolkhozGold.opacity(0.95) : Color.kolkhozSteel.opacity(0.9), lineWidth: human ? 1.5 : 1)
        }
        .overlay {
            PrintCornerFrame(cornerRadius: 6, accent: human ? .kolkhozGold : .kolkhozSteel)
                .opacity(human ? 0.8 : 0.42)
        }
        .shadow(color: human ? Color.kolkhozGold.opacity(0.26) : .black.opacity(0.38), radius: human ? 6 : 4, y: 2)
    }

    var portraitImage: Image {
        guard let url = Bundle.kolkhozAppFeatureResources.url(forResource: portraitName, withExtension: "png") else {
            return Image(systemName: "person.fill")
        }

        #if canImport(UIKit)
        if let image = UIImage(contentsOfFile: url.path) {
            return Image(uiImage: image)
        }
        #elseif canImport(AppKit)
        if let image = NSImage(contentsOf: url) {
            return Image(nsImage: image)
        }
        #endif

        return Image(systemName: "person.fill")
    }

    var portraitName: String {
        if player.isHuman {
            return "worker4"
        }
        let portraitIndex = ((max(player.id, 1) - 1) % 4) + 1
        return "worker\(portraitIndex)"
    }
}
