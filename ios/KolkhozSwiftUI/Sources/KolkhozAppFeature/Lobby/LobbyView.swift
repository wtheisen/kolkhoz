import KolkhozCore
import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct LobbyView: View {
    @Binding var selectedPreset: GamePreset
    @Binding var customVariants: GameVariants
    @Binding var showingRules: Bool
    let onStart: () -> Void

    var activeVariants: GameVariants {
        selectedPreset.variants ?? customVariants
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.kolkhozBackground, .kolkhozIron, .kolkhozBlack],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            GeometryReader { proxy in
                let insets = proxy.safeAreaInsets
                let usableWidth = max(280, proxy.size.width - insets.leading - insets.trailing)
                let usableHeight = max(280, proxy.size.height - insets.top - insets.bottom)
                let outerPadding: CGFloat = 10
                let contentWidth = max(260, usableWidth - outerPadding * 2)
                let compactPhone = contentWidth < 560
                let titleWidth = compactPhone ? contentWidth : min(210, max(154, contentWidth * 0.26))
                let titleHeight = compactPhone ? min(326, max(310, usableHeight * 0.40)) : usableHeight - outerPadding * 2
                let panelWidth = compactPhone ? contentWidth : max(300, contentWidth - titleWidth - 14)
                let panelHeight = compactPhone ? max(320, usableHeight - titleHeight - outerPadding * 3) : usableHeight - outerPadding * 2

                Group {
                    if compactPhone {
                        ScrollView(.vertical, showsIndicators: false) {
                            VStack(spacing: 10) {
                                LobbyTitleColumn(
                                    showingRules: $showingRules,
                                    onStart: onStart,
                                    width: titleWidth,
                                    height: titleHeight
                                )
                                LobbyPanel(
                                    selectedPreset: $selectedPreset,
                                    customVariants: $customVariants,
                                    variants: activeVariants,
                                    showingRules: showingRules,
                                    width: panelWidth,
                                    maxHeight: panelHeight
                                )
                            }
                            .padding(.horizontal, insets.leading + outerPadding)
                            .padding(.top, insets.top + outerPadding)
                            .padding(.bottom, insets.bottom + outerPadding)
                            .frame(width: proxy.size.width, alignment: .top)
                        }
                    } else {
                        HStack(alignment: .top, spacing: 14) {
                            LobbyTitleColumn(
                                showingRules: $showingRules,
                                onStart: onStart,
                                width: titleWidth,
                                height: titleHeight
                            )
                            LobbyPanel(
                                selectedPreset: $selectedPreset,
                                customVariants: $customVariants,
                                variants: activeVariants,
                                showingRules: showingRules,
                                width: panelWidth,
                                maxHeight: panelHeight
                            )
                        }
                        .padding(.leading, insets.leading + outerPadding)
                        .padding(.trailing, insets.trailing + outerPadding)
                        .padding(.top, insets.top + outerPadding)
                        .padding(.bottom, insets.bottom + outerPadding)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .leading)
                .clipped()
            }
        }
    }
}

struct LobbyTitleColumn: View {
    @Binding var showingRules: Bool
    let onStart: () -> Void
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        VStack(spacing: 10) {
            TitleCardImage()
                .frame(width: width, height: titleCardHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.kolkhozGold.opacity(0.72), lineWidth: 1.5)
                }
                .shadow(color: .black.opacity(0.28), radius: 7, y: 3)

            VStack(spacing: 9) {
                Button(action: onStart) {
                    Text("Start Game")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                Button {
                    showingRules.toggle()
                } label: {
                    Text(showingRules ? "Options" : "Rules")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CommandButtonStyle(prominent: false))
            }
            .frame(maxWidth: .infinity)

            GeneratedChromeImage(resourceName: "ui-divider-crops")
                .aspectRatio(contentMode: .fit)
                .frame(width: min(width * 0.88, 170), height: 34)
                .allowsHitTesting(false)

            Spacer(minLength: 2)

            HStack(spacing: 7) {
                GameIcon(.medalStar, size: 18)
                VStack(spacing: 2) {
                    Text("Game by")
                    Text("William Theisen")
                }
                .font(.kolkhozTitle(.caption2))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.62)
                .foregroundStyle(Color.kolkhozGold)
            }
        }
        .frame(width: width, height: height)
    }

    private var titleCardHeight: CGFloat {
        min(176, max(92, width * 0.50))
    }
}

struct TitleCardImage: View {
    var body: some View {
        titleImage
            .resizable()
            .interpolation(.none)
            .antialiased(false)
            .scaledToFill()
    }

    private var titleImage: Image {
        guard let url = Bundle.kolkhozAppFeatureResources.url(forResource: "title-card-kolkhoz", withExtension: "png") else {
            return Image(systemName: "rectangle.fill")
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

        return Image(systemName: "rectangle.fill")
    }
}

struct LobbyPanel: View {
    @Binding var selectedPreset: GamePreset
    @Binding var customVariants: GameVariants
    let variants: GameVariants
    let showingRules: Bool
    let width: CGFloat
    let maxHeight: CGFloat

    var body: some View {
        let contentHeight = max(180, maxHeight - 24)

        Group {
            if showingRules {
                RulesPanel(maxHeight: contentHeight)
            } else {
                VariantPanel(
                    selectedPreset: $selectedPreset,
                    customVariants: $customVariants,
                    variants: variants,
                    maxHeight: contentHeight
                )
            }
        }
        .frame(width: width, alignment: .topLeading)
        .frame(height: contentHeight, alignment: .top)
        .panelStyle()
        .overlay(alignment: .bottomTrailing) {
            GeneratedChromeImage(resourceName: "ui-corner-crops")
                .aspectRatio(contentMode: .fit)
                .frame(width: min(68, width * 0.17))
                .scaleEffect(x: -1, y: -1)
                .opacity(0.7)
                .offset(x: 13, y: 12)
                .allowsHitTesting(false)
        }
    }
}

struct VariantPanel: View {
    @Binding var selectedPreset: GamePreset
    @Binding var customVariants: GameVariants
    let variants: GameVariants
    let maxHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            PresetSelector(selectedPreset: $selectedPreset, customVariants: $customVariants)
                .layoutPriority(2)

            Divider()
                .overlay(Color.kolkhozGold.opacity(0.35))

            ScrollView(.vertical, showsIndicators: true) {
                if selectedPreset == .custom {
                    CustomVariantOptions(variants: $customVariants)
                } else {
                    PresetSummary(variants: variants)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxHeight: maxHeight, alignment: .top)
    }
}

struct PresetSelector: View {
    @Binding var selectedPreset: GamePreset
    @Binding var customVariants: GameVariants

    var body: some View {
        HStack(spacing: 6) {
            ForEach(GamePreset.allCases) { preset in
                Button {
                    selectedPreset = preset
                    if let variants = preset.variants {
                        customVariants = variants
                    }
                } label: {
                    Text(preset.title)
                        .font(.kolkhozDisplay(size: 8.5))
                        .textCase(.uppercase)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .allowsTightening(true)
                        .padding(.top, 8)
                    .foregroundStyle(selectedPreset == preset ? Color.kolkhozGold : Color.kolkhozCreamDim)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 5)
                    .background {
                        GeneratedChromeImage(resourceName: selectedPreset == preset ? "ui-tab-selected" : "ui-tab-unselected")
                    }
                    .overlay(alignment: .top) {
                        if selectedPreset == preset {
                            Rectangle()
                                .fill(Color.kolkhozGoldBright.opacity(0.7))
                                .frame(width: 28, height: 2)
                                .offset(y: 5)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct PresetSummary: View {
    let variants: GameVariants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            DeckSummary(deckType: variants.deckType)
            ForEach(enabledVariantRows) { row in
                VariantReadOnlyRow(row: row)
            }
        }
    }

    var enabledVariantRows: [VariantRowData] {
        VariantRowData.all.filter { row in
            switch row.key {
            case .nomenclature: variants.nomenclature
            case .allowSwap: variants.allowSwap
            case .northernStyle: variants.northernStyle
            case .miceVariant: variants.miceVariant
            case .ordenNachalniku: variants.ordenNachalniku
            case .medalsCount: variants.medalsCount
            case .heroOfSovietUnion: variants.heroOfSovietUnion
            case .accumulateJobs: variants.accumulateJobs
            }
        }
    }
}

struct CustomVariantOptions: View {
    @Binding var variants: GameVariants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Deck", selection: $variants.deckType) {
                Text("52 cards").tag(52)
                Text("36 cards").tag(36)
            }
            .pickerStyle(.segmented)

            VariantToggleRow(row: .nomenclature, isOn: $variants.nomenclature)
            VariantToggleRow(row: .allowSwap, isOn: $variants.allowSwap)
            VariantToggleRow(row: .northernStyle, isOn: $variants.northernStyle)
            VariantToggleRow(row: .miceVariant, isOn: $variants.miceVariant)
            VariantToggleRow(row: .ordenNachalniku, isOn: $variants.ordenNachalniku)
            VariantToggleRow(row: .medalsCount, isOn: $variants.medalsCount)
            VariantToggleRow(row: .heroOfSovietUnion, isOn: $variants.heroOfSovietUnion)
            if variants.deckType != 36 {
                VariantToggleRow(row: .accumulateJobs, isOn: $variants.accumulateJobs)
            }
        }
        .padding(.bottom, 10)
        .onChange(of: variants.deckType) { _, deckType in
            if deckType == 36 {
                variants.accumulateJobs = false
            }
        }
    }
}

struct DeckSummary: View {
    let deckType: Int

    var body: some View {
        HStack {
            Text("Deck")
                .font(.kolkhozLabel(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozCreamDim)
            Text("\(deckType) cards")
                .font(.kolkhozTitle(.caption))
                .foregroundStyle(Color.kolkhozGold)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.kolkhozBlack.opacity(0.32), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct VariantReadOnlyRow: View {
    let row: VariantRowData

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            GameIcon(.check, size: 16)
            VariantText(row: row)
        }
        .variantRowBackground(active: true)
    }
}

struct VariantToggleRow: View {
    let row: VariantRowData
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VariantText(row: row)
        }
        .toggleStyle(.switch)
        .variantRowBackground(active: isOn)
    }
}

struct VariantText: View {
    let row: VariantRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
                .font(.kolkhozTitle(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozGold)
            Text(row.description)
                .font(.kolkhozLabel(.caption2))
                .foregroundStyle(Color.kolkhozSmoke)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RulesPanel: View {
    let maxHeight: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rules")
                    .sectionTitle()
                RuleBlock(title: "Objective", bodyText: "Complete collective farm jobs while protecting your private plot. Highest score wins.")
                RuleBlock(title: "Gameplay", bodyText: "Play cards into tricks, follow the lead suit if able, then let the trick winner assign captured work to jobs.")
                RuleBlock(title: "Jobs", bodyText: "Each job needs 40 work hours. Completed jobs can award crop cards to the brigade leader.")
                RuleBlock(title: "Nomenclature", bodyText: "Trump Jack is the Drunkard, trump Queen is the Informant, and trump King is the Party Official.")
                RuleBlock(title: "Scoring", bodyText: "Revealed and hidden plot cards count at the end. Medals count only when that variant is enabled.")
            }
        }
        .frame(maxHeight: max(190, maxHeight))
    }
}

struct RuleBlock: View {
    let title: String
    let bodyText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.kolkhozTitle(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozGold)
            Text(bodyText)
                .font(.kolkhozLabel(.caption))
                .foregroundStyle(Color.kolkhozCreamDim)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

enum VariantKey {
    case nomenclature
    case allowSwap
    case northernStyle
    case miceVariant
    case ordenNachalniku
    case medalsCount
    case heroOfSovietUnion
    case accumulateJobs
}

struct VariantRowData: Identifiable {
    let key: VariantKey
    let title: String
    let description: String

    var id: String { title }

    static let nomenclature = VariantRowData(key: .nomenclature, title: "Nomenclature", description: "Trump face cards have special powers.")
    static let allowSwap = VariantRowData(key: .allowSwap, title: "Swap", description: "Exchange a hand card with a plot card at the start of each later year.")
    static let northernStyle = VariantRowData(key: .northernStyle, title: "Northern Style", description: "No job rewards; everyone remains vulnerable to requisition.")
    static let miceVariant = VariantRowData(key: .miceVariant, title: "Mice", description: "Reveal all matching plot cards during requisition.")
    static let ordenNachalniku = VariantRowData(key: .ordenNachalniku, title: "Order to the Boss", description: "Completed 36-card jobs stack assigned cards as bonus rewards.")
    static let medalsCount = VariantRowData(key: .medalsCount, title: "Medals", description: "Trick wins add to the final score.")
    static let heroOfSovietUnion = VariantRowData(key: .heroOfSovietUnion, title: "Hero", description: "Winning every trick in a year grants requisition immunity.")
    static let accumulateJobs = VariantRowData(key: .accumulateJobs, title: "Accumulation", description: "Unclaimed job rewards carry over to the next year.")

    static let all = [
        nomenclature,
        allowSwap,
        northernStyle,
        miceVariant,
        ordenNachalniku,
        medalsCount,
        heroOfSovietUnion,
        accumulateJobs
    ]
}
