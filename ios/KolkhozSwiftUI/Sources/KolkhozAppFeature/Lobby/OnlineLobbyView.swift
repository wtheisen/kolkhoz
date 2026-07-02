import KolkhozCore
import SwiftUI

struct OnlineLobbyPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let variants: GameVariants
    let onHost: (URL, [PlayerController]) async throws -> String
    let onJoin: (URL, String, Int32?) async throws -> Void

    @State private var mode: OnlineLobbyMode = .host
    @State private var serverURLText = ProcessInfo.processInfo.environment["KOLKHOZ_ONLINE_SERVER_URL"] ?? "http://127.0.0.1:8787"
    @State private var inviteCode = ""
    @State private var preferredSeat = 0
    @State private var seatChoices: [OnlineSeatChoice] = [.local, .ai, .ai, .ai]
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            modeSelector
            serverField
            Divider().overlay(Color.kolkhozGold.opacity(0.32))
            ScrollView(.vertical, showsIndicators: true) {
                Group {
                    switch mode {
                    case .host:
                        hostOptions
                    case .join:
                        joinOptions
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            actionButton
        }
        .alert(language.text(en: "Online play unavailable", ru: "Онлайн игра недоступна"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(language.text(en: "OK", ru: "ОК"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            GameIcon(.playTap, size: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text(en: "Online Play", ru: "Онлайн игра"))
                    .font(.kolkhozTitle(.caption))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                Text(language.text(en: "Host with AI seats or join by invite code.", ru: "Создайте стол с ИИ или войдите по коду."))
                    .font(.kolkhozLabel(.caption2))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 4)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(Color.kolkhozBlack.opacity(0.30), in: RoundedRectangle(cornerRadius: 5))
        .overlay {
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.kolkhozGold.opacity(0.28), lineWidth: 1)
        }
    }

    private var modeSelector: some View {
        HStack(spacing: 6) {
            ForEach(OnlineLobbyMode.allCases) { option in
                Button {
                    mode = option
                    errorMessage = nil
                } label: {
                    ZStack {
                        GeneratedChromeImage(resourceName: mode == option ? "ui-tab-selected" : "ui-tab-unselected")
                            .aspectRatio(4, contentMode: .fit)
                        Text(option.title(language))
                            .font(.kolkhozDisplay(size: 8.5))
                            .textCase(.uppercase)
                            .foregroundStyle(mode == option ? Color.kolkhozOnAccent : Color.kolkhozCardInk)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                            .padding(.horizontal, 15)
                            .padding(.top, 3)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var serverField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(language.text(en: "Server URL", ru: "Адрес сервера"))
                .font(.kolkhozTitle(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozGold)
            TextField("http://127.0.0.1:8787", text: $serverURLText)
                .font(.kolkhozLabel(.body))
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
        }
    }

    private var hostOptions: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                GameIcon(.brigade, size: 18)
                Text(language.text(en: "Seats", ru: "Места"))
                    .font(.kolkhozTitle(.caption))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                Spacer()
                Text(language.text(en: "Open seats can be joined later.", ru: "Открытые места можно занять позже."))
                    .font(.kolkhozLabel(.caption2))
                    .foregroundStyle(Color.kolkhozCreamDim)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .background(Color.kolkhozBlack.opacity(0.30), in: RoundedRectangle(cornerRadius: 5))

            ForEach(0..<4, id: \.self) { playerID in
                OnlineSeatRow(
                    playerID: playerID,
                    selection: seatBinding(for: playerID)
                )
            }
        }
    }

    private var joinOptions: some View {
        VStack(alignment: .leading, spacing: 9) {
            VStack(alignment: .leading, spacing: 5) {
                Text(language.text(en: "Invite Code", ru: "Код приглашения"))
                    .font(.kolkhozTitle(.caption))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozGold)
                TextField("XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX", text: $inviteCode)
                    .font(.kolkhozLabel(.body))
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
            }

            HStack(spacing: 7) {
                Text(language.text(en: "Preferred seat", ru: "Желаемое место"))
                    .font(.kolkhozLabel(.caption))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.kolkhozCreamDim)
                Picker(language.text(en: "Preferred seat", ru: "Желаемое место"), selection: $preferredSeat) {
                    Text(language.text(en: "Any", ru: "Любое")).tag(-1)
                    ForEach(0..<4, id: \.self) { playerID in
                        Text(language.text(en: "P\(playerID + 1)", ru: "И\(playerID + 1)")).tag(playerID)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var actionButton: some View {
        Button {
            Task { await submit() }
        } label: {
            if isWorking {
                ProgressView()
                    .tint(Color.kolkhozOnAccent)
                    .frame(maxWidth: .infinity)
            } else {
                Text(mode == .host ? language.text(en: "Host & Play", ru: "Создать и играть") : language.text(en: "Join & Play", ru: "Войти и играть"))
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(CommandButtonStyle(prominent: true))
        .disabled(isWorking)
        .opacity(isWorking ? 0.72 : 1)
    }

    private func submit() async {
        guard let baseURL = URL(string: serverURLText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorMessage = language.text(en: "Enter a valid server URL.", ru: "Введите правильный адрес сервера.")
            return
        }
        isWorking = true
        errorMessage = nil
        do {
            switch mode {
            case .host:
                _ = try await onHost(baseURL, hostControllers)
            case .join:
                try await onJoin(baseURL, inviteCode, preferredSeat >= 0 ? Int32(preferredSeat) : nil)
            }
        } catch {
            errorMessage = String(describing: error)
        }
        isWorking = false
    }

    private func seatBinding(for playerID: Int) -> Binding<OnlineSeatChoice> {
        Binding(
            get: {
                seatChoices.indices.contains(playerID) ? seatChoices[playerID] : .ai
            },
            set: { choice in
                var next = seatChoices
                if !next.indices.contains(playerID) {
                    next = [.local, .ai, .ai, .ai]
                }
                next[playerID] = playerID == 0 ? .local : choice
                seatChoices = next
            }
        )
    }

    private var hostControllers: [PlayerController] {
        seatChoices.enumerated().map { index, choice in
            index == 0 || choice != .ai ? .human : .heuristicAI
        }
    }
}

private enum OnlineLobbyMode: String, CaseIterable, Identifiable {
    case host
    case join

    var id: String { rawValue }

    func title(_ language: KolkhozLanguage) -> String {
        switch self {
        case .host:
            language.text(en: "Host Game", ru: "Создать игру")
        case .join:
            language.text(en: "Join Game", ru: "Войти в игру")
        }
    }
}

private enum OnlineSeatChoice: String, CaseIterable, Identifiable {
    case local
    case open
    case ai

    var id: String { rawValue }

    func title(_ language: KolkhozLanguage) -> String {
        switch self {
        case .local:
            language.text(en: "Local", ru: "Здесь")
        case .open:
            language.text(en: "Open", ru: "Открыто")
        case .ai:
            language.text(en: "AI", ru: "ИИ")
        }
    }

    var icon: GameIconAsset {
        switch self {
        case .local, .open:
            .humanSeat
        case .ai:
            .basicAI
        }
    }
}

private struct OnlineSeatRow: View {
    let playerID: Int
    @Binding var selection: OnlineSeatChoice

    var body: some View {
        HStack(spacing: 9) {
            SeatNumberBadge(playerID: playerID, active: selection != .ai)
                .frame(width: 48)
            HStack(spacing: 5) {
                ForEach(choices) { choice in
                    OnlineSeatSegment(choice: choice, selected: selection == choice) {
                        selection = playerID == 0 ? .local : choice
                    }
                    .disabled(playerID == 0 && choice != .local)
                    .opacity(playerID == 0 && choice != .local ? 0.42 : 1)
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(Color.kolkhozBlack.opacity(0.24), in: RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(selection == .ai ? Color.kolkhozSteel.opacity(0.42) : Color.kolkhozGold.opacity(0.36), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
    }

    private var choices: [OnlineSeatChoice] {
        playerID == 0 ? [.local, .open, .ai] : OnlineSeatChoice.allCases.filter { $0 != .local }
    }
}

private struct OnlineSeatSegment: View {
    @Environment(\.kolkhozLanguage) private var language
    let choice: OnlineSeatChoice
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                GeneratedChromeImage(resourceName: selected ? "ui-tab-selected" : "ui-tab-unselected")
                    .aspectRatio(4, contentMode: .fit)
                HStack(spacing: 5) {
                    GameIcon(choice.icon, size: 15, muted: !selected)
                    Text(choice.title(language))
                        .font(.kolkhozTitle(.caption))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                }
                .textCase(.uppercase)
                .foregroundStyle(selected ? Color.kolkhozOnAccent : Color.kolkhozCardInk)
                .padding(.horizontal, 14)
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#if DEBUG
#Preview("Online Lobby Panel", traits: .landscapeLeft) {
    OnlineLobbyPanel(
        variants: .kolkhoz,
        onHost: { _, _ in UUID().uuidString },
        onJoin: { _, _, _ in }
    )
    .padding(14)
    .panelStyle()
    .font(.kolkhozLabel(.body))
    .environment(\.kolkhozLanguage, .en)
    .frame(width: 520, height: 360)
}
#endif
