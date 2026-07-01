import KolkhozCore
import SwiftUI

struct TutorialWalkthroughView: View {
    @Environment(\.kolkhozLanguage) private var language
    let onClose: () -> Void
    @StateObject private var tutorialStore: GameStore
    @State private var stepIndex = 0
    @State private var completedStepIDs: Set<Int> = []

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _tutorialStore = StateObject(wrappedValue: GameStore(scriptedState: TutorialScenario.steps[0].state))
    }

    private var steps: [TutorialStep] { TutorialScenario.steps }
    private var step: TutorialStep { steps[stepIndex] }
    private var stepComplete: Bool {
        !step.requiresInteraction || completedStepIDs.contains(step.id)
    }
    private var activeTutorialAction: TutorialRequiredAction {
        stepComplete ? .none : step.requiredAction
    }

    var body: some View {
        ZStack {
            GameBoardView(
                initialPanel: step.initialPanel,
                onMenu: onClose,
                onTutorial: {},
                tutorialAction: activeTutorialAction,
                onTutorialAction: completeIfNeeded(_:)
            )
            .id(step.id)
            .environmentObject(tutorialStore)

            Color.kolkhozBlack.opacity(0.12)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                VStack {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom) {
                        Spacer(minLength: 0)
                        ForemanDialoguePanel(
                            step: step,
                            index: stepIndex,
                            count: steps.count,
                            completed: stepComplete,
                            onBack: goBack,
                            onNext: goNext,
                            onClose: onClose
                        )
                        .frame(width: min(520, max(390, proxy.size.width * 0.54)))
                    }
                }
                .padding(.horizontal, proxy.size.width < 720 ? 10 : 16)
                .padding(.vertical, proxy.size.height < 420 ? 8 : 14)
            }
        }
        .font(.kolkhozLabel(.body))
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: stepIndex)
        .onReceive(tutorialStore.$state) { state in
            completeIfStateMatches(state)
        }
        .onChange(of: stepIndex) { _, newValue in
            tutorialStore.loadScriptedState(steps[newValue].state)
        }
    }

    private func completeIfNeeded(_ action: TutorialRequiredAction) {
        guard action == step.requiredAction else { return }
        completedStepIDs.insert(step.id)
    }

    private func completeIfStateMatches(_ state: KolkhozState) {
        switch step.requiredAction {
        case .chooseTrump(let suit):
            if state.trump == suit, state.phase != .planning {
                completedStepIDs.insert(step.id)
            }
        case .playCard(let card):
            let played = state.currentTrick.contains { $0.playerID == 0 && $0.card == card } ||
                state.lastTrick.contains { $0.playerID == 0 && $0.card == card }
            let noLongerInHand = state.players.first?.hand.contains(card) == false
            if played || noLongerInHand {
                completedStepIDs.insert(step.id)
            }
        default:
            break
        }
    }

    private func goBack() {
        guard stepIndex > 0 else { return }
        stepIndex -= 1
    }

    private func goNext() {
        guard stepComplete else { return }
        if stepIndex == steps.count - 1 {
            onClose()
        } else {
            stepIndex += 1
        }
    }
}

private struct ForemanDialoguePanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let step: TutorialStep
    let index: Int
    let count: Int
    let completed: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ResourceArtImage(resourceName: "art-tutorial-foreman")
                .scaledToFit()
                .frame(width: 92, height: 108)
                .shadow(color: Color.kolkhozGold.opacity(0.26), radius: 9, y: 4)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    GameIcon(step.icon, size: 23)
                    VStack(alignment: .leading, spacing: 1) {
                        PixelText(
                            text: TutorialScenario.foremanName.text(language).uppercased(),
                            size: .caption,
                            variant: .heavy,
                            color: .kolkhozGold
                        )
                        Text(step.title.text(language))
                            .font(.kolkhozTitle(.subheadline))
                            .textCase(.uppercase)
                            .foregroundStyle(Color.kolkhozCream)
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                    Spacer(minLength: 0)
                    Button(action: onClose) {
                        PixelText(text: "X", size: .caption, variant: .heavy, color: .kolkhozCreamDim)
                            .frame(width: 28, height: 28)
                            .background(Color.kolkhozBlack.opacity(0.25), in: RoundedRectangle(cornerRadius: 4))
                            .overlay {
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.kolkhozSteel.opacity(0.56), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(language.text(en: "Close tutorial", ru: "Закрыть обучение"))
                }

                Text(step.body.text(language))
                    .font(.kolkhozLabel(.subheadline))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)

                if let strategyTip = step.strategyTip {
                    TutorialStrategyTipView(tip: strategyTip)
                }

                HStack(alignment: .top, spacing: 8) {
                    TutorialSpark()
                        .frame(width: 20, height: 20)
                    Text(completed ? language.text(en: "Good. Advance when ready.", ru: "Хорошо. Продолжайте, когда готовы.") : step.callout.text(language))
                        .font(.kolkhozTitle(.caption))
                        .textCase(.uppercase)
                        .foregroundStyle(completed ? Color.kolkhozGreen : Color.kolkhozGoldBright)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.kolkhozBlack.opacity(0.26), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(completed ? Color.kolkhozGreen.opacity(0.55) : Color.kolkhozGold.opacity(0.55), lineWidth: 1)
                }

                TutorialProgressDots(index: index, count: count)

                HStack(spacing: 8) {
                    Button(language.text(en: "Back", ru: "Назад")) {
                        onBack()
                    }
                    .buttonStyle(SwapCommandButtonStyle(prominent: false))
                    .disabled(index == 0)
                    .opacity(index == 0 ? 0.45 : 1)

                    Button(index == count - 1 ? language.text(en: "Done", ru: "Готово") : language.text(en: "Next", ru: "Дальше")) {
                        onNext()
                    }
                    .buttonStyle(SwapCommandButtonStyle(prominent: true))
                    .disabled(!completed)
                    .opacity(completed ? 1 : 0.48)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 146, alignment: .leading)
        .background {
            ZStack {
                LinearGradient(
                    colors: [Color.kolkhozPanel, Color.kolkhozIron.opacity(0.96), Color.kolkhozBlack.opacity(0.94)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                LinearGradient(
                    colors: [Color.kolkhozGold.opacity(0.12), .clear, Color.kolkhozRedDark.opacity(0.14)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.kolkhozGold.opacity(0.66), lineWidth: 1.5)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.kolkhozRedDark.opacity(0.55), lineWidth: 1)
                .padding(5)
        }
        .shadow(color: .black.opacity(0.28), radius: 7, y: 3)
    }
}

private struct TutorialStrategyTipView: View {
    @Environment(\.kolkhozLanguage) private var language
    let tip: TutorialLine

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            PixelText(
                text: language.text(en: "TIP", ru: "СОВЕТ"),
                size: .caption2,
                variant: .heavy,
                color: .kolkhozRedBright
            )
            .padding(.horizontal, 5)
            .padding(.vertical, 3)
            .background(Color.kolkhozRedDark.opacity(0.34), in: RoundedRectangle(cornerRadius: 4))
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.kolkhozRedBright.opacity(0.58), lineWidth: 1)
            }

            Text(tip.text(language))
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCream)
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.kolkhozBlack.opacity(0.2), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.kolkhozRedDark.opacity(0.46), lineWidth: 1)
        }
    }
}

private struct TutorialProgressDots: View {
    let index: Int
    let count: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { dotIndex in
                Capsule()
                    .fill(dotIndex <= index ? Color.kolkhozGold : Color.kolkhozSteel.opacity(0.45))
                    .frame(width: dotIndex == index ? 22 : 8, height: 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 2)
    }
}

private struct TutorialSpark: View {
    var body: some View {
        ResourceArtImage(resourceName: "tutorial-focus-spark")
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

#if DEBUG
#Preview("Tutorial Walkthrough", traits: .landscapeLeft) {
    KolkhozFontRegistry.registerFonts()
    return TutorialWalkthroughView(onClose: {})
        .environment(\.kolkhozLanguage, .en)
}
#endif
