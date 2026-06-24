import KolkhozCore
import SwiftUI

enum PlayAreaShellLayout {
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

struct PlayAreaShellView: View {
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
            let showsHandTray = displayPanel == .brigade || store.state.phase == .swap || store.state.phase == .assignment
            let handOverlayClearance: CGFloat = store.state.phase == .assignment ? PlayAreaShellLayout.assignmentHandTrayClearance : (showsHandTray ? PlayAreaShellLayout.handTrayClearance : 0)

            VStack(spacing: PlayAreaShellLayout.verticalSpacing) {
                TopInfoBarView(jobTargets: $jobTargets)
                    .padding(.leading, infoLeading)
                    .padding(.trailing, infoTrailing)

                ZStack {
                    switch displayPanel {
                    case .options:
                        InGameOptionsPanel(
                            onNewGame: onNewGame,
                            onReturnToLobby: onReturnToLobby
                        )
                        .frame(maxWidth: PlayAreaShellLayout.optionsPanelMaxWidth)
                        .padding(.horizontal, PlayAreaShellLayout.floatingPanelHorizontalPadding)
                        .shadow(color: .black.opacity(0.5), radius: 16, y: 8)

                    case .brigade:
                        BrigadeView(
                            humanPlayTarget: $humanPlayTarget,
                            playSlotCenters: $playSlotCenters,
                            playSlotFrames: $playSlotFrames,
                            playerPanelCenters: $playerPanelCenters,
                            hiddenPlayIDs: hiddenPlayIDs,
                            showLastTrick: showLastTrick
                        )
                        .padding(.horizontal, playContentInset)
                        .padding(.top, PlayAreaShellLayout.panelTopPadding)
                        .padding(.bottom, PlayAreaShellLayout.panelBottomPadding)

                        if store.state.phase == .planning || store.state.phase == .gameOver {
                            PhaseOverlayView()
                                .frame(maxWidth: PlayAreaShellLayout.actionPanelMaxWidth)
                                .padding(.horizontal, PlayAreaShellLayout.floatingPanelHorizontalPadding)
                                .shadow(color: .black.opacity(0.5), radius: 16, y: 8)
                        }

                    case .jobs:
                        JobsView(
                            jobTargets: $jobTargets,
                            jobTargetFrames: $jobTargetFrames,
                            assignmentDrag: $assignmentDrag,
                            hoveredSuit: $hoveredAssignmentSuit,
                            selectedAssignmentCard: $selectedAssignmentCard
                        )
                        .padding(.horizontal, playContentInset)
                        .padding(.top, PlayAreaShellLayout.panelTopPadding)
                        .padding(.bottom, PlayAreaShellLayout.panelBottomPadding)

                    case .north:
                        NorthView()
                            .padding(.horizontal, playContentInset)
                            .padding(.top, PlayAreaShellLayout.panelTopPadding)
                            .padding(.bottom, PlayAreaShellLayout.panelBottomPadding)

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
                        .padding(.top, PlayAreaShellLayout.panelTopPadding)
                        .padding(.bottom, PlayAreaShellLayout.panelBottomPadding)
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
                    .clipShape(RoundedRectangle(cornerRadius: PlayAreaShellLayout.panelCornerRadius))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: PlayAreaShellLayout.panelCornerRadius)
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
#Preview("Play Area Shell - Brigade") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.trickState, width: 760, height: 390) {
        PlayAreaShellPreviewHost(displayPanel: .brigade)
    }
}

#Preview("Play Area Shell - Jobs") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.assignmentState, width: 760, height: 390) {
        PlayAreaShellPreviewHost(displayPanel: .jobs)
    }
}

#Preview("Play Area Shell - Plot") {
    BoardPreviewStoreStage(state: KolkhozPreviewFixtures.swapState, width: 760, height: 390) {
        PlayAreaShellPreviewHost(displayPanel: .plot)
    }
}

private struct PlayAreaShellPreviewHost: View {
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
        PlayAreaShellView(
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
