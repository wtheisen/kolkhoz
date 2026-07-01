import KolkhozCore
import SwiftUI

struct TutorialLine: Equatable {
    let en: String
    let ru: String

    func text(_ language: KolkhozLanguage) -> String {
        language.text(en: en, ru: ru)
    }
}

enum TutorialRequiredAction: Equatable {
    case none
    case tapPanel(GamePanel)
    case chooseTrump(Suit)
    case playCard(Card)
    case tapJob(Suit)
    case inspectReward(Suit)
    case inspectNorthReport
}

struct TutorialStep: Identifiable {
    let id: Int
    let title: TutorialLine
    let body: TutorialLine
    let strategyTip: TutorialLine?
    let callout: TutorialLine
    let state: KolkhozState
    let panel: GamePanel
    let initialPanel: GamePanel
    let requiredAction: TutorialRequiredAction
    let icon: GameIconAsset

    var requiresInteraction: Bool {
        requiredAction != .none
    }
}

enum TutorialScenario {
    static let foremanName = TutorialLine(en: "Foreman Misha", ru: "Бригадир Миша")

    static let steps: [TutorialStep] = [
        TutorialStep(
            id: 0,
            title: TutorialLine(en: "First, read the table", ru: "Сначала стол"),
            body: TutorialLine(
                en: "Every year has four jobs. Your hand wins tricks; your cellar keeps the points that survive requisition.",
                ru: "В каждом году четыре работы. Рука выигрывает взятки, а подвал хранит очки, пережившие реквизицию."
            ),
            strategyTip: TutorialLine(
                en: "High hidden cards are your bank. Losing one to the North can swing the final score.",
                ru: "Старшие скрытые карты — ваш запас. Потеря такой карты на Север может решить счёт."
            ),
            callout: TutorialLine(en: "Tap the Cellar icon to inspect your kept card.", ru: "Нажмите значок Подвала, чтобы посмотреть сохранённую карту."),
            state: planningState,
            panel: .plot,
            initialPanel: .brigade,
            requiredAction: .tapPanel(.plot),
            icon: .plot
        ),
        TutorialStep(
            id: 1,
            title: TutorialLine(en: "Pick the trump crop", ru: "Выберите козырь"),
            body: TutorialLine(
                en: "In planning, the selector chooses one crop as trump. Trump cards can beat the led crop.",
                ru: "В плане выбирают козырную культуру. Козыри могут побить масть захода."
            ),
            strategyTip: TutorialLine(
                en: "Pick trump for the hand you expect to play, not only for the biggest card you see.",
                ru: "Выбирайте козырь под руку, которую будете играть, а не только под самую старшую карту."
            ),
            callout: TutorialLine(en: "Tap Wheat as trump.", ru: "Нажмите Пшеницу как козырь."),
            state: planningState,
            panel: .brigade,
            initialPanel: .brigade,
            requiredAction: .chooseTrump(.wheat),
            icon: .jobs
        ),
        TutorialStep(
            id: 2,
            title: TutorialLine(en: "Win the trick", ru: "Возьмите взятку"),
            body: TutorialLine(
                en: "The lead crop is Wheat, so your Wheat King is legal and strong. Follow suit when you can; highest in the winning suit takes the trick.",
                ru: "Заход в Пшеницу, значит ваш Король Пшеницы законен и силён. Если можете, ходите в масть; старшая карта берёт взятку."
            ),
            strategyTip: TutorialLine(
                en: "Winning is power, but it paints a target on your cellar for the rest of the year.",
                ru: "Победа даёт силу, но до конца года делает ваш подвал целью."
            ),
            callout: TutorialLine(en: "Tap the highlighted Wheat King.", ru: "Нажмите выделенного Короля Пшеницы."),
            state: trickState,
            panel: .brigade,
            initialPanel: .brigade,
            requiredAction: .playCard(Card(suit: .wheat, value: 13)),
            icon: .hand
        ),
        TutorialStep(
            id: 3,
            title: TutorialLine(en: "Medal now, risk later", ru: "Медаль сейчас, риск позже"),
            body: TutorialLine(
                en: "You won the trick and earned a medal. Medals break ties, but any trick win makes you vulnerable to requisition this year.",
                ru: "Вы выиграли взятку и получили медаль. Медали решают ничьи, но любая взятка делает вас уязвимым к реквизиции в этом году."
            ),
            strategyTip: TutorialLine(
                en: "Sometimes ducking a trick is correct if your cellar is holding a card you cannot afford to lose.",
                ru: "Иногда лучше не брать взятку, если в подвале лежит карта, которую нельзя потерять."
            ),
            callout: TutorialLine(en: "Continue to see where the risk lands.", ru: "Продолжайте, чтобы увидеть, куда ударит риск."),
            state: medalRiskState,
            panel: .brigade,
            initialPanel: .brigade,
            requiredAction: .none,
            icon: .medalStar
        ),
        TutorialStep(
            id: 4,
            title: TutorialLine(en: "The winner assigns work", ru: "Победитель назначает"),
            body: TutorialLine(
                en: "As brigade leader, you send captured cards into a job. Here Wheat gets protected, but your kept Potato Queen is still exposed if Potato fails.",
                ru: "Как бригадир, вы отправляете взятые карты на работу. Здесь Пшеница защищена, но ваша Дама Картофеля останется под угрозой, если Картофель провалится."
            ),
            strategyTip: TutorialLine(
                en: "Assign work to protect the suits that match your best cellar cards, not just the job closest to done.",
                ru: "Назначайте работу, чтобы защитить масти ваших лучших карт подвала, а не только ближайшую к завершению работу."
            ),
            callout: TutorialLine(en: "Tap the Jobs icon to view the work board.", ru: "Нажмите значок Работ, чтобы открыть доску работ."),
            state: assignmentState,
            panel: .jobs,
            initialPanel: .brigade,
            requiredAction: .tapPanel(.jobs),
            icon: .jobs
        ),
        TutorialStep(
            id: 5,
            title: TutorialLine(en: "Finish jobs for rewards", ru: "Закрывайте работы ради наград"),
            body: TutorialLine(
                en: "When a job reaches 40 hours, the revealed reward card goes into the winner's cellar as points.",
                ru: "Когда работа набирает 40 часов, раскрытая карта-награда уходит в подвал победителя как очки."
            ),
            strategyTip: TutorialLine(
                en: "A finished job both pays you and stops that crop from causing requisition this year.",
                ru: "Закрытая работа и даёт награду, и не вызывает реквизицию этой культуры в этом году."
            ),
            callout: TutorialLine(en: "Inspect the completed Wheat reward, then continue.", ru: "Посмотрите закрытую награду Пшеницы, затем продолжайте."),
            state: jobRewardState,
            panel: .jobs,
            initialPanel: .jobs,
            requiredAction: .inspectReward(.wheat),
            icon: .medalStar
        ),
        TutorialStep(
            id: 6,
            title: TutorialLine(en: "This is requisition", ru: "Вот реквизиция"),
            body: TutorialLine(
                en: "Potato failed. Because you won a trick, your kept Potato Queen is revealed and sent North.",
                ru: "Картофель провалился. Поскольку вы взяли взятку, ваша Дама Картофеля раскрыта и отправлена на Север."
            ),
            strategyTip: TutorialLine(
                en: "The medal may break a tie later, but losing a high cellar card hurts immediately.",
                ru: "Медаль может решить ничью позже, но потеря старшей карты подвала бьёт сразу."
            ),
            callout: TutorialLine(en: "Tap the requisition report.", ru: "Нажмите отчёт о реквизиции."),
            state: requisitionState,
            panel: .north,
            initialPanel: .north,
            requiredAction: .inspectNorthReport,
            icon: .north
        ),
        TutorialStep(
            id: 7,
            title: TutorialLine(en: "Swap before later years", ru: "Обмен в следующих годах"),
            body: TutorialLine(
                en: "From year two, you may trade one hand card with your cellar. Use it to rescue exposed value before the next requisition.",
                ru: "Со второго года можно обменять одну карту руки с подвалом. Используйте обмен, чтобы спасти ценность перед следующей реквизицией."
            ),
            strategyTip: TutorialLine(
                en: "Swap high cards into the cellar when they can stay safe; pull danger cards out before requisition.",
                ru: "Кладите старшие карты в подвал, когда их можно защитить; опасные карты вытаскивайте до реквизиции."
            ),
            callout: TutorialLine(en: "Tap the Cellar icon again before you swap.", ru: "Снова нажмите значок Подвала перед обменом."),
            state: swapState,
            panel: .plot,
            initialPanel: .brigade,
            requiredAction: .tapPanel(.plot),
            icon: .cellar
        ),
        TutorialStep(
            id: 8,
            title: TutorialLine(en: "Year five is famine", ru: "Пятый год — неурожай"),
            body: TutorialLine(
                en: "The last year has no trump and only three tricks. It is short, mean, and usually decisive.",
                ru: "В последний год нет козыря и только три взятки. Он короткий, злой и часто решающий."
            ),
            strategyTip: TutorialLine(
                en: "Save flexible high cards for famine; no trump means a bad lead is harder to escape.",
                ru: "Берегите гибкие старшие карты к неурожаю; без козыря плохой заход труднее перебить."
            ),
            callout: TutorialLine(en: "Continue when you have seen the famine board.", ru: "Продолжайте, когда увидите доску неурожая."),
            state: famineState,
            panel: .brigade,
            initialPanel: .brigade,
            requiredAction: .none,
            icon: .famine
        ),
        TutorialStep(
            id: 9,
            title: TutorialLine(en: "Highest final cellar wins", ru: "Побеждает лучший подвал"),
            body: TutorialLine(
                en: "At the end, hidden cellar cards count too. Highest cellar wins; medals break ties.",
                ru: "В конце считаются и скрытые карты подвала. Побеждает лучший подвал; медали решают ничьи."
            ),
            strategyTip: TutorialLine(
                en: "Bigger ranks mean bigger cellar points. One protected high card can decide the whole game.",
                ru: "Чем выше ранг, тем больше очков подвала. Одна защищённая старшая карта может решить игру."
            ),
            callout: TutorialLine(en: "Review the final score, then finish.", ru: "Посмотрите итоговый счёт, затем завершите."),
            state: gameOverState,
            panel: .plot,
            initialPanel: .plot,
            requiredAction: .none,
            icon: .medalStar
        )
    ]

    private static var planningState: KolkhozState {
        var state = baseState()
        state.phase = .planning
        state.currentPlayer = 0
        state.trumpSelector = 0
        state.trump = nil
        return state
    }

    private static var trickState: KolkhozState {
        var state = baseState()
        state.phase = .trick
        state.trump = .wheat
        state.lead = 2
        state.currentPlayer = 0
        state.currentTrick = [
            TrickPlay(playerID: 2, card: Card(suit: .wheat, value: 8)),
            TrickPlay(playerID: 3, card: Card(suit: .wheat, value: 11))
        ]
        state.players[0].hand = [
            Card(suit: .wheat, value: 13),
            Card(suit: .sunflower, value: 7),
            Card(suit: .beet, value: 10),
            Card(suit: .potato, value: 6),
            Card(suit: .sunflower, value: 9)
        ]
        return state
    }

    private static var medalRiskState: KolkhozState {
        var state = baseState()
        state.phase = .assignment
        state.trump = .wheat
        state.currentPlayer = 0
        state.lead = 0
        state.lastWinner = 0
        state.trickCount = 1
        state.currentTrick = scriptedWinningTrick
        state.lastTrick = scriptedWinningTrick
        state.players[0].brigadeLeader = true
        state.players[0].hasWonTrickThisYear = true
        state.players[0].medals = 1
        state.players[2].brigadeLeader = false
        state.players[2].medals = 0
        return state
    }

    private static var assignmentState: KolkhozState {
        var state = medalRiskState
        state.phase = .assignment
        state.trump = .wheat
        state.currentPlayer = 0
        state.lastWinner = 0
        state.lead = 0
        state.currentTrick = []
        state.lastTrick = scriptedWinningTrick
        state.pendingAssignments = [
            Card(suit: .wheat, value: 13).id: .wheat,
            Card(suit: .wheat, value: 11).id: .wheat,
            Card(suit: .wheat, value: 8).id: .wheat,
            Card(suit: .wheat, value: 9).id: .wheat
        ]
        state.workHours[.wheat] = 36
        state.workHours[.sunflower] = 24
        state.workHours[.potato] = 10
        state.jobBuckets[.wheat] = [
            Card(suit: .wheat, value: 13),
            Card(suit: .wheat, value: 11),
            Card(suit: .wheat, value: 9),
            Card(suit: .wheat, value: 8)
        ]
        return state
    }

    private static var jobRewardState: KolkhozState {
        var state = assignmentState
        state.workHours[.wheat] = 41
        state.claimedJobs = [.wheat]
        let reward = Card(suit: .wheat, value: 3)
        if !state.players[0].plot.revealed.contains(reward) {
            state.players[0].plot.revealed.append(reward)
        }
        return state
    }

    private static var swapState: KolkhozState {
        var state = baseState()
        state.phase = .swap
        state.year = 2
        state.trump = .beet
        state.currentPlayer = 0
        state.swapConfirmed = []
        state.swapCount = []
        state.players[0].plot.hidden = [
            Card(suit: .wheat, value: 12),
            Card(suit: .potato, value: 9),
            Card(suit: .beet, value: 7)
        ]
        state.players[0].plot.revealed = [
            Card(suit: .sunflower, value: 5),
            Card(suit: .wheat, value: 4)
        ]
        return state
    }

    private static var requisitionState: KolkhozState {
        var state = jobRewardState
        state.phase = .requisition
        state.currentPlayer = 0
        state.trump = .wheat
        state.workHours[.wheat] = 41
        state.workHours[.potato] = 10
        state.workHours[.sunflower] = 24
        state.workHours[.beet] = 34
        state.claimedJobs = [.wheat]
        let exiledCard = Card(suit: .potato, value: 12)
        state.players[0].plot.hidden.removeAll { $0 == exiledCard }
        if !state.players[0].plot.revealed.contains(exiledCard) {
            state.players[0].plot.revealed.append(exiledCard)
        }
        state.exiled[1] = [
            exiledCard
        ]
        state.requisitionEvents = [
            RequisitionEvent(playerID: 0, suit: .potato, card: exiledCard, message: "Player sends Q Potato north"),
            RequisitionEvent(playerID: nil, suit: .sunflower, card: nil, message: "Sunflower failed; no vulnerable matching cards")
        ]
        return state
    }

    private static var famineState: KolkhozState {
        var state = baseState()
        state.phase = .planning
        state.year = 5
        state.trump = nil
        state.isFamine = true
        state.players[0].hand = [
            Card(suit: .wheat, value: 11),
            Card(suit: .sunflower, value: 9),
            Card(suit: .potato, value: 8),
            Card(suit: .beet, value: 12)
        ]
        return state
    }

    private static var gameOverState: KolkhozState {
        var state = requisitionState
        state.phase = .gameOver
        state.year = 6
        state.gameResult = GameResult(winnerID: 0, scores: [0: 62, 1: 45, 2: 38, 3: 41])
        return state
    }

    private static func baseState() -> KolkhozState {
        var players = [
            player(id: 0, name: "Player", human: true),
            player(id: 1, name: "Anna", human: false),
            player(id: 2, name: "Dmitri", human: false),
            player(id: 3, name: "Fyodor", human: false)
        ]
        players[0].plot.revealed = [Card(suit: .wheat, value: 3)]
        players[0].plot.hidden = [Card(suit: .potato, value: 12)]
        players[1].medals = 1
        players[2].brigadeLeader = true
        players[2].medals = 2

        var state = KolkhozState(players: players, lead: 0, trumpSelector: 0, variants: .kolkhoz)
        state.year = 1
        state.trump = .wheat
        state.revealedJobs = [
            .wheat: Card(suit: .wheat, value: 3),
            .sunflower: Card(suit: .sunflower, value: 4),
            .potato: Card(suit: .potato, value: 2),
            .beet: Card(suit: .beet, value: 5)
        ]
        state.workHours = [
            .wheat: 17,
            .sunflower: 29,
            .potato: 8,
            .beet: 34
        ]
        state.jobBuckets = [
            .wheat: [Card(suit: .wheat, value: 9)],
            .sunflower: [Card(suit: .sunflower, value: 11), Card(suit: .sunflower, value: 8)],
            .potato: [Card(suit: .potato, value: 8)],
            .beet: [Card(suit: .beet, value: 13), Card(suit: .beet, value: 10)]
        ]
        return state
    }

    private static let scriptedWinningTrick = [
        TrickPlay(playerID: 2, card: Card(suit: .wheat, value: 8)),
        TrickPlay(playerID: 3, card: Card(suit: .wheat, value: 11)),
        TrickPlay(playerID: 0, card: Card(suit: .wheat, value: 13)),
        TrickPlay(playerID: 1, card: Card(suit: .wheat, value: 9))
    ]

    private static func player(id: Int, name: String, human: Bool) -> PlayerState {
        var player = PlayerState(id: id, name: name, isHuman: human)
        player.hand = sampleHands[id, default: sampleHands[0] ?? []]
        player.plot.hidden = [
            Card(suit: Suit.allCases[id % Suit.allCases.count], value: 8 + id),
            Card(suit: Suit.allCases[(id + 1) % Suit.allCases.count], value: 6 + id)
        ]
        player.plot.revealed = [
            Card(suit: Suit.allCases[(id + 2) % Suit.allCases.count], value: 2 + id)
        ]
        return player
    }

    private static let sampleHands: [Int: [Card]] = [
        0: [
            Card(suit: .wheat, value: 13),
            Card(suit: .sunflower, value: 10),
            Card(suit: .potato, value: 8),
            Card(suit: .beet, value: 7),
            Card(suit: .wheat, value: 6)
        ],
        1: [
            Card(suit: .sunflower, value: 13),
            Card(suit: .beet, value: 12),
            Card(suit: .potato, value: 9),
            Card(suit: .wheat, value: 8)
        ],
        2: [
            Card(suit: .potato, value: 13),
            Card(suit: .wheat, value: 12),
            Card(suit: .sunflower, value: 9)
        ],
        3: [
            Card(suit: .beet, value: 13),
            Card(suit: .potato, value: 12),
            Card(suit: .wheat, value: 10),
            Card(suit: .sunflower, value: 7)
        ]
    ]
}
