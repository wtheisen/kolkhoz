import KolkhozCore
import SwiftUI

enum GameAreaShellLayout {
    static let verticalSpacing: CGFloat = 6
    static let panelTopPadding: CGFloat = 8
    static let panelBottomPadding: CGFloat = 10
    static let actionPanelMaxWidth: CGFloat = 500
    static let optionsPanelMaxWidth: CGFloat = 620
    static let floatingPanelHorizontalPadding: CGFloat = 20
    static let handTrayClearance: CGFloat = 78
    static let assignmentHandTrayClearance: CGFloat = 88
    static let panelCornerRadius: CGFloat = 10
}

struct TrickAreaShellView: View {
    @EnvironmentObject var store: GameStore
    let displayPanel: GamePanel
    let onReturnToLobby: () -> Void
    let onNewGame: () -> Void
    @Binding var humanPlayTarget: CGPoint?
    @Binding var playSlotCenters: [Int: CGPoint]
    @Binding var playSlotFrames: [Int: CGRect]
    @Binding var playerPanelCenters: [Int: CGPoint]
    @Binding var jobTargets: [Suit: CGPoint]
    @Binding var jobTargetFrames: [Suit: CGRect]
    @Binding var assignmentDrag: AssignmentDragState?
    @Binding var hoveredAssignmentSuit: Suit?
    @Binding var selectedAssignmentCard: Card?
    let hiddenPlayIDs: Set<String>
    let showLastTrick: Bool
    let gameSafeInsets: EdgeInsets
    @Binding var selectedSwapPlot: PlotSelection?

    var body: some View {
        GeometryReader { proxy in
            let infoLeading = gameSafeInsets.leading
            let infoTrailing = gameSafeInsets.trailing
            let playContentInset: CGFloat = 0
            let showsHandTray = displayPanel == .game || store.state.phase == .swap || store.state.phase == .assignment
            let handOverlayClearance: CGFloat = store.state.phase == .assignment ? GameAreaShellLayout.assignmentHandTrayClearance : (showsHandTray ? GameAreaShellLayout.handTrayClearance : 0)

            VStack(spacing: GameAreaShellLayout.verticalSpacing) {
                InfoBarView(jobTargets: $jobTargets)
                    .padding(.leading, infoLeading)
                    .padding(.trailing, infoTrailing)

                ZStack {
                    switch displayPanel {
                    case .options:
                        InGameOptionsPanel(
                            onNewGame: onNewGame,
                            onReturnToLobby: onReturnToLobby
                        )
                        .frame(maxWidth: GameAreaShellLayout.optionsPanelMaxWidth)
                        .padding(.horizontal, GameAreaShellLayout.floatingPanelHorizontalPadding)
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)

                    case .game:
                        PlayerColumnsView(
                            humanPlayTarget: $humanPlayTarget,
                            playSlotCenters: $playSlotCenters,
                            playSlotFrames: $playSlotFrames,
                            playerPanelCenters: $playerPanelCenters,
                            hiddenPlayIDs: hiddenPlayIDs,
                            showLastTrick: showLastTrick
                        )
                        .padding(.horizontal, playContentInset)
                        .padding(.top, GameAreaShellLayout.panelTopPadding)
                        .padding(.bottom, GameAreaShellLayout.panelBottomPadding)

                        if store.state.phase != .trick && store.state.phase != .assignment {
                            PhaseActionView()
                                .frame(maxWidth: GameAreaShellLayout.actionPanelMaxWidth)
                                .padding(.horizontal, GameAreaShellLayout.floatingPanelHorizontalPadding)
                                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                        }

                    case .jobs:
                        AssignmentJobsView(
                            jobTargets: $jobTargets,
                            jobTargetFrames: $jobTargetFrames,
                            assignmentDrag: $assignmentDrag,
                            hoveredSuit: $hoveredAssignmentSuit,
                            selectedAssignmentCard: $selectedAssignmentCard
                        )
                        .padding(.horizontal, playContentInset)
                        .padding(.top, GameAreaShellLayout.panelTopPadding)
                        .padding(.bottom, GameAreaShellLayout.panelBottomPadding)

                    case .north:
                        NorthHistoryView()
                            .padding(.horizontal, playContentInset)
                            .padding(.top, GameAreaShellLayout.panelTopPadding)
                            .padding(.bottom, GameAreaShellLayout.panelBottomPadding)

                    case .plot:
                        Group {
                            if store.state.phase == .swap {
                                SwapPlotView(selectedPlot: $selectedSwapPlot)
                            } else if store.state.phase == .requisition {
                                RequisitionPlotView()
                            } else {
                                PlotOverviewView()
                            }
                        }
                        .padding(.horizontal, playContentInset)
                        .padding(.top, GameAreaShellLayout.panelTopPadding)
                        .padding(.bottom, GameAreaShellLayout.panelBottomPadding)
                    }
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
                    .clipShape(RoundedRectangle(cornerRadius: GameAreaShellLayout.panelCornerRadius))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: GameAreaShellLayout.panelCornerRadius)
                        .stroke(Color.kolkhozRedDark.opacity(0.8), lineWidth: 2)
                }
                .padding(.leading, gameSafeInsets.leading)
                .padding(.trailing, gameSafeInsets.trailing)
                .padding(.bottom, handOverlayClearance)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

#if DEBUG
#Preview("Game Area Shell - Game") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 390) {
        TrickAreaShellPreviewHost(displayPanel: .game)
    }
}

#Preview("Game Area Shell - Jobs") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 760, height: 390) {
        TrickAreaShellPreviewHost(displayPanel: .jobs)
    }
}

#Preview("Game Area Shell - Plot") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 760, height: 390) {
        TrickAreaShellPreviewHost(displayPanel: .plot)
    }
}

private struct TrickAreaShellPreviewHost: View {
    let displayPanel: GamePanel
    @State private var humanPlayTarget: CGPoint?
    @State private var playSlotCenters: [Int: CGPoint] = [:]
    @State private var playSlotFrames: [Int: CGRect] = [:]
    @State private var playerPanelCenters: [Int: CGPoint] = [:]
    @State private var jobTargets: [Suit: CGPoint] = [:]
    @State private var jobTargetFrames: [Suit: CGRect] = [:]
    @State private var assignmentDrag: AssignmentDragState?
    @State private var hoveredAssignmentSuit: Suit?
    @State private var selectedAssignmentCard: Card?
    @State private var selectedSwapPlot: PlotSelection?

    var body: some View {
        TrickAreaShellView(
            displayPanel: displayPanel,
            onReturnToLobby: {},
            onNewGame: {},
            humanPlayTarget: $humanPlayTarget,
            playSlotCenters: $playSlotCenters,
            playSlotFrames: $playSlotFrames,
            playerPanelCenters: $playerPanelCenters,
            jobTargets: $jobTargets,
            jobTargetFrames: $jobTargetFrames,
            assignmentDrag: $assignmentDrag,
            hoveredAssignmentSuit: $hoveredAssignmentSuit,
            selectedAssignmentCard: $selectedAssignmentCard,
            hiddenPlayIDs: [],
            showLastTrick: false,
            gameSafeInsets: EdgeInsets(),
            selectedSwapPlot: $selectedSwapPlot
        )
        .coordinateSpace(name: GameBoardCoordinateSpace.main)
    }
}
#endif
