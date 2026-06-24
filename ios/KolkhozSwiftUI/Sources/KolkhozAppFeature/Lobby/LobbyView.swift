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
    @Environment(\.kolkhozLanguage) private var language
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
                    Text(language.text(en: "Start Game", ru: "Начать игру"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(CommandButtonStyle(prominent: true))
                Button {
                    showingRules.toggle()
                } label: {
                    Text(showingRules ? language.text(en: "Options", ru: "Настройки") : language.text(en: "Rules", ru: "Правила"))
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
                LanguageToggleButton(compact: true)
                VStack(spacing: 2) {
                    Text(language.text(en: "Game by", ru: "Автор игры"))
                    Text(language.text(en: "William Theisen", ru: "Уильям Тайсон"))
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
        KolkhozResourceImageCache.image(named: "title-card-kolkhoz") ?? Image(systemName: "rectangle.fill")
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
    @Environment(\.kolkhozLanguage) private var language
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
                    Text(language.presetTitle(preset))
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
    @Environment(\.kolkhozLanguage) private var language
    @Binding var variants: GameVariants

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker(language.text(en: "Deck", ru: "Колода"), selection: $variants.deckType) {
                Text(language.text(en: "52 cards", ru: "52 карты")).tag(52)
                Text(language.text(en: "36 cards", ru: "36 карт")).tag(36)
            }
            .pickerStyle(.segmented)

            VariantToggleRow(row: .nomenclature, isOn: $variants.nomenclature)
            VariantToggleRow(row: .allowSwap, isOn: $variants.allowSwap)
            VariantToggleRow(row: .northernStyle, isOn: $variants.northernStyle)
            VariantToggleRow(row: .miceVariant, isOn: $variants.miceVariant)
            if variants.deckType == 36 {
                VariantToggleRow(row: .ordenNachalniku, isOn: $variants.ordenNachalniku)
            }
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
            } else {
                variants.ordenNachalniku = false
            }
        }
    }
}

struct DeckSummary: View {
    @Environment(\.kolkhozLanguage) private var language
    let deckType: Int

    var body: some View {
        HStack {
            Text(language.text(en: "Deck", ru: "Колода"))
                .font(.kolkhozLabel(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozCreamDim)
            Text(language.text(en: "\(deckType) cards", ru: "\(deckType) карт"))
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
    @Environment(\.kolkhozLanguage) private var language
    let row: VariantRowData

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.title(language))
                .font(.kolkhozTitle(.caption))
                .textCase(.uppercase)
                .foregroundStyle(Color.kolkhozGold)
            Text(row.description(language))
                .font(.kolkhozLabel(.caption2))
                .foregroundStyle(Color.kolkhozSmoke)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct RulesPanel: View {
    @Environment(\.kolkhozLanguage) private var language
    let maxHeight: CGFloat

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(language.text(en: "Rules", ru: "Правила"))
                    .sectionTitle()
                RuleBlock(title: language.text(en: "Objective", ru: "Цель"), bodyText: language.text(en: "Complete collective farm jobs while protecting your private plot. Highest score wins!", ru: "Выполняйте работы колхоза, защищая свой участок. Побеждает наибольший счёт!"))
                RuleBlock(title: language.text(en: "Gameplay", ru: "Игра"), bodyText: language.text(en: "Play cards to tricks - must follow lead suit if able", ru: "Играйте карты в трюки - следуйте масти если возможно"))
                RuleBlock(title: language.text(en: "Jobs", ru: "Поля"), bodyText: language.text(en: "Jobs need 40 work hours to complete", ru: "Работы требуют 40 часов для завершения"))
                RuleBlock(title: language.text(en: "Trump Face Cards", ru: "Козырные карты"), bodyText: language.text(en: "Jack (Drunkard), Queen (Informer), and King (Official) have special powers.", ru: "Валет (Пьяница), Дама (Доносчик) и Король (Чиновник) имеют особые силы."))
                RuleBlock(title: language.text(en: "Scoring", ru: "Подсчёт очков"), bodyText: language.text(en: "Cards in your plot = your score. Highest score wins!", ru: "Карты на вашем участке = ваши очки. Побеждает тот, у кого больше!"))
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

    var id: String { "\(key)" }

    func title(_ language: KolkhozLanguage) -> String {
        switch key {
        case .nomenclature:
            language.text(en: "Nomenclature", ru: "Номенклатура")
        case .allowSwap:
            language.text(en: "Swap", ru: "Обмен")
        case .northernStyle:
            language.text(en: "Northern Style", ru: "Северный стиль")
        case .miceVariant:
            language.text(en: "Mice", ru: "Мыши")
        case .ordenNachalniku:
            language.text(en: "Order to the Boss", ru: "Орден Начальнику")
        case .medalsCount:
            language.text(en: "Medals", ru: "Медали")
        case .heroOfSovietUnion:
            language.text(en: "Hero", ru: "Герой")
        case .accumulateJobs:
            language.text(en: "Accumulation", ru: "Накопление")
        }
    }

    func description(_ language: KolkhozLanguage) -> String {
        switch key {
        case .nomenclature:
            language.text(en: "Trump face cards have special powers: Jack gets exiled, Queen exposes everyone, King doubles exile.", ru: "Козырные фигуры имеют особые силы: Валет ссылается, Дама раскрывает всех, Король удваивает ссылку.")
        case .allowSwap:
            language.text(en: "Swap cards between your hand and plot at the start of each year.", ru: "Обмен картами между рукой и участком в начале каждого года.")
        case .northernStyle:
            language.text(en: "No rewards for completing jobs - everyone stays vulnerable to requisition.", ru: "Нет наград за выполнение работ — все остаются уязвимы для реквизиции.")
        case .miceVariant:
            language.text(en: "All players reveal their entire plot during requisition, not just matching cards.", ru: "Все игроки раскрывают весь участок при реквизиции, а не только подходящие карты.")
        case .ordenNachalniku:
            language.text(en: "Cards assigned to completed jobs stack as bonus rewards.", ru: "Карты, назначенные на выполненные работы, накапливаются как бонусные награды.")
        case .medalsCount:
            language.text(en: "Trick victories count toward your final score.", ru: "Победы во взятках учитываются в итоговом счёте.")
        case .heroOfSovietUnion:
            language.text(en: "Win all 4 tricks in a year to become immune from requisition.", ru: "Выиграй все 4 взятки за год — получи иммунитет от реквизиции.")
        case .accumulateJobs:
            language.text(en: "Unclaimed job rewards carry over to the next year.", ru: "Невостребованные награды за работы переносятся на следующий год.")
        }
    }

    static let nomenclature = VariantRowData(key: .nomenclature)
    static let allowSwap = VariantRowData(key: .allowSwap)
    static let northernStyle = VariantRowData(key: .northernStyle)
    static let miceVariant = VariantRowData(key: .miceVariant)
    static let ordenNachalniku = VariantRowData(key: .ordenNachalniku)
    static let medalsCount = VariantRowData(key: .medalsCount)
    static let heroOfSovietUnion = VariantRowData(key: .heroOfSovietUnion)
    static let accumulateJobs = VariantRowData(key: .accumulateJobs)

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
