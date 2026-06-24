import Foundation

private let maxYears = 5
private let workThreshold = 40
private let playerNames = ["Ivan", "Dmitri", "Alyosha", "Fyodor", "Grushenka", "Katerina"]

public final class KolkhozEngine {
    public private(set) var state: KolkhozState
    private var random: SeededGenerator
    private var animationEvents: [KolkhozAnimationEvent] = []

    public init(seed: UInt64 = UInt64(Date().timeIntervalSince1970), variants: GameVariants = .kolkhoz) {
        self.random = SeededGenerator(seed: seed)
        let players = KolkhozEngine.makePlayers(random: &random)
        let lead = Int(random.next() % UInt64(players.count))
        let selector = Int(random.next() % UInt64(players.count))
        self.state = KolkhozState(players: players, lead: lead, trumpSelector: selector, variants: variants)
        setupDecks()
        processAutomaticTurns()
    }

    public init(testing state: KolkhozState) {
        self.random = SeededGenerator(seed: 1)
        self.state = state
    }

    public func newGame(seed: UInt64 = UInt64(Date().timeIntervalSince1970), variants: GameVariants? = nil) {
        animationEvents = []
        random = SeededGenerator(seed: seed)
        let players = KolkhozEngine.makePlayers(random: &random)
        let lead = Int(random.next() % UInt64(players.count))
        let selector = Int(random.next() % UInt64(players.count))
        state = KolkhozState(players: players, lead: lead, trumpSelector: selector, variants: variants ?? state.variants)
        setupDecks()
        processAutomaticTurns()
    }

    public func drainAnimationEvents() -> [KolkhozAnimationEvent] {
        let events = animationEvents
        animationEvents = []
        return events
    }

    public func setTrump(_ suit: Suit) throws {
        guard state.phase == .planning else { throw KolkhozMoveError.wrongPhase }
        guard state.currentPlayer == 0 else { throw KolkhozMoveError.wrongPlayer }
        state.trump = suit
        advanceFromPlanning()
        processAutomaticTurns()
    }

    public func playCard(_ card: Card) throws {
        guard state.phase == .trick else { throw KolkhozMoveError.wrongPhase }
        guard state.currentPlayer == 0 else { throw KolkhozMoveError.wrongPlayer }
        guard let cardIndex = state.players[0].hand.firstIndex(of: card), isValidPlay(playerID: 0, cardIndex: cardIndex) else {
            throw KolkhozMoveError.invalidCard
        }
        playCard(playerID: 0, cardIndex: cardIndex)
        processAutomaticTurns()
    }

    public func swap(handCard: Card, plotCard: Card, revealed: Bool) throws {
        guard state.phase == .swap else { throw KolkhozMoveError.wrongPhase }
        guard state.currentPlayer == 0 else { throw KolkhozMoveError.wrongPlayer }
        guard !state.swapCount.contains(0) else { throw KolkhozMoveError.invalidCard }
        try swapCard(playerID: 0, handCard: handCard, plotCard: plotCard, zone: revealed ? .revealed : .hidden)
    }

    public func undoSwap() throws {
        guard state.phase == .swap else { throw KolkhozMoveError.wrongPhase }
        guard state.currentPlayer == 0 else { throw KolkhozMoveError.wrongPlayer }
        guard let lastSwap = state.lastSwap,
              lastSwap.playerID == 0,
              state.swapCount.contains(0),
              state.players[0].hand.indices.contains(lastSwap.handIndex) else {
            throw KolkhozMoveError.invalidCard
        }

        switch lastSwap.plotZone {
        case .hidden:
            guard state.players[0].plot.hidden.indices.contains(lastSwap.plotIndex) else { throw KolkhozMoveError.invalidCard }
            let temporary = state.players[0].plot.hidden[lastSwap.plotIndex]
            state.players[0].plot.hidden[lastSwap.plotIndex] = state.players[0].hand[lastSwap.handIndex]
            state.players[0].hand[lastSwap.handIndex] = temporary
        case .revealed:
            guard state.players[0].plot.revealed.indices.contains(lastSwap.plotIndex) else { throw KolkhozMoveError.invalidCard }
            let temporary = state.players[0].plot.revealed[lastSwap.plotIndex]
            state.players[0].plot.revealed[lastSwap.plotIndex] = state.players[0].hand[lastSwap.handIndex]
            state.players[0].hand[lastSwap.handIndex] = temporary
        }

        state.swapCount.remove(0)
        state.lastSwap = nil
    }

    public func confirmSwap() throws {
        guard state.phase == .swap else { throw KolkhozMoveError.wrongPhase }
        guard state.currentPlayer == 0 else { throw KolkhozMoveError.wrongPlayer }
        confirmSwap(playerID: 0)
        processAutomaticTurns()
    }

    public func assign(card: Card, to suit: Suit) throws {
        guard state.phase == .assignment else { throw KolkhozMoveError.wrongPhase }
        guard state.lastWinner == 0 else { throw KolkhozMoveError.wrongPlayer }
        let legalTargets = Set(state.lastTrick.map(\.card.suit))
        guard legalTargets.contains(suit), state.lastTrick.contains(where: { $0.card == card }) else {
            throw KolkhozMoveError.invalidAssignment
        }
        state.pendingAssignments[card.id] = suit
    }

    public func submitAssignments() throws {
        guard state.phase == .assignment else { throw KolkhozMoveError.wrongPhase }
        guard state.lastWinner == 0 else { throw KolkhozMoveError.wrongPlayer }
        guard state.pendingAssignments.count == state.lastTrick.count else {
            throw KolkhozMoveError.invalidAssignment
        }
        applyAssignments(state.pendingAssignments)
        state.pendingAssignments = [:]
        advanceAfterAssignments()
        processAutomaticTurns()
    }

    public func continueAfterRequisition() {
        guard state.phase == .requisition else { return }
        removeExiledCards()
        transitionToNextYear()
        processAutomaticTurns()
    }

    public func validCardsForHuman() -> Set<Card> {
        guard state.phase == .trick, state.currentPlayer == 0 else { return [] }
        return Set(state.players[0].hand.enumerated().compactMap { index, card in
            isValidPlay(playerID: 0, cardIndex: index) ? card : nil
        })
    }

    public func visibleScore(for playerID: Int) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = player.plot.revealed.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.revealed.reduce(0) { $0 + $1.value }
        }
        if state.variants.medalsCount {
            score += player.plot.medals + player.medals
        }
        return score
    }

    public func finalScore(for playerID: Int) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        return visibleScore(for: playerID) + player.plot.hidden.reduce(0) { $0 + $1.value }
    }
}

private extension KolkhozEngine {
    static func makePlayers(random: inout SeededGenerator) -> [PlayerState] {
        var names = playerNames
        var players = [PlayerState(id: 0, name: "Player", isHuman: true)]

        for id in 1..<4 {
            let index = Int(random.next() % UInt64(names.count))
            let name = names.remove(at: index)
            players.append(PlayerState(id: id, name: name, isHuman: false))
        }

        return players
    }

    func setupDecks() {
        state.jobPiles = Dictionary(uniqueKeysWithValues: Suit.allCases.map { suit in
            let cards = state.variants.deckType == 36
                ? [Card(suit: suit, value: 1)]
                : (1...maxYears).map { Card(suit: suit, value: $0) }.shuffled(using: &random)
            return (suit, cards)
        })
        revealJobs()
        state.isFamine = state.year == maxYears
        dealHands()
    }

    func revealJobs() {
        state.revealedJobs = [:]
        for suit in Suit.allCases {
            if state.variants.deckType == 36 {
                state.revealedJobs[suit] = state.jobPiles[suit]?.first
            } else {
                state.revealedJobs[suit] = state.jobPiles[suit]?.popLast()
            }
        }
    }

    func makeWorkerDeck() -> [Card] {
        var cards: [Card] = []
        for suit in Suit.allCases {
            for value in 6...13 {
                cards.append(Card(suit: suit, value: value))
            }
        }

        var usedCards = Set(state.players.flatMap { player in
            player.hand + player.plot.revealed + player.plot.hidden + player.plot.stacks.flatMap { $0.revealed + $0.hidden }
        })
        if !state.variants.ordenNachalniku {
            usedCards.formUnion(Set(state.exiled.values.flatMap { $0 }))
        }

        return (cards + state.drunkardReplacements)
            .filter { !usedCards.contains($0) || state.drunkardReplacements.contains($0) }
            .shuffled(using: &random)
    }

    func dealHands() {
        var deck = makeWorkerDeck()
        let cardsPerPlayer = state.isFamine ? 4 : 5
        for playerID in state.players.indices {
            state.players[playerID].hand = []
        }
        for _ in 0..<cardsPerPlayer {
            for playerID in state.players.indices {
                if let card = deck.popLast() {
                    state.players[playerID].hand.append(card)
                }
            }
        }
    }

    func processAutomaticTurns() {
        var guardCount = 0
        while guardCount < 200 {
            guardCount += 1

            switch state.phase {
            case .planning where state.isFamine:
                advanceFromPlanning()

            case .planning where state.currentPlayer != 0:
                state.trump = chooseTrump(for: state.currentPlayer)
                advanceFromPlanning()

            case .swap:
                if state.currentPlayer == 0 {
                    return
                }
                performAISwapIfUseful(playerID: state.currentPlayer)
                confirmSwap(playerID: state.currentPlayer)

            case .trick where state.currentPlayer != 0:
                let playerID = state.currentPlayer
                let cardIndex = chooseCardIndex(for: playerID)
                playCard(playerID: playerID, cardIndex: cardIndex)

            case .assignment where state.lastWinner != 0:
                let assignments = chooseAssignments(for: state.lastWinner ?? 0)
                applyAssignments(assignments)
                advanceAfterAssignments()

            default:
                return
            }
        }
    }

    func advanceFromPlanning() {
        if state.isFamine {
            state.trump = nil
        } else if state.trump == nil {
            state.trump = Suit.allCases[Int(random.next() % UInt64(Suit.allCases.count))]
        }

        if state.variants.allowSwap && state.year > 1 {
            state.phase = .swap
            state.currentPlayer = 0
            state.swapConfirmed = []
            state.swapCount = []
            state.lastSwap = nil
        } else {
            state.phase = .trick
            state.currentPlayer = state.lead
        }
    }

    func swapCard(playerID: Int, handCard: Card, plotCard: Card, zone: PlotCardZone) throws {
        guard let handIndex = state.players[playerID].hand.firstIndex(of: handCard) else { throw KolkhozMoveError.invalidCard }
        let plotIndex: Int
        switch zone {
        case .hidden:
            guard let index = state.players[playerID].plot.hidden.firstIndex(of: plotCard) else { throw KolkhozMoveError.invalidCard }
            plotIndex = index
            state.players[playerID].plot.hidden[index] = handCard
        case .revealed:
            guard let index = state.players[playerID].plot.revealed.firstIndex(of: plotCard) else { throw KolkhozMoveError.invalidCard }
            plotIndex = index
            state.players[playerID].plot.revealed[index] = handCard
        }

        state.players[playerID].hand[handIndex] = plotCard
        state.swapCount.insert(playerID)
        state.lastSwap = SwapRecord(
            playerID: playerID,
            plotZone: zone,
            plotIndex: plotIndex,
            handIndex: handIndex,
            newPlotCard: handCard
        )
    }

    func confirmSwap(playerID: Int) {
        state.swapConfirmed.insert(playerID)
        if state.swapConfirmed.count >= state.numPlayers {
            state.phase = .trick
            state.currentPlayer = state.lead
            state.swapConfirmed = []
            state.swapCount = []
            return
        }

        state.currentPlayer = min(playerID + 1, state.numPlayers - 1)
    }

    func performAISwapIfUseful(playerID: Int) {
        guard !state.swapCount.contains(playerID),
              let handCard = state.players[playerID].hand.min(by: { $0.value < $1.value }) else {
            return
        }

        let hiddenCandidate = state.players[playerID].plot.hidden.max(by: { $0.value < $1.value }).map { ($0, PlotCardZone.hidden) }
        let revealedCandidate = state.players[playerID].plot.revealed.max(by: { $0.value < $1.value }).map { ($0, PlotCardZone.revealed) }
        let candidate = [hiddenCandidate, revealedCandidate]
            .compactMap { $0 }
            .max { lhs, rhs in lhs.0.value < rhs.0.value }

        guard let (plotCard, zone) = candidate, plotCard.value > handCard.value + 1 else {
            return
        }

        try? swapCard(playerID: playerID, handCard: handCard, plotCard: plotCard, zone: zone)
    }

    func playCard(playerID: Int, cardIndex: Int) {
        let card = state.players[playerID].hand.remove(at: cardIndex)
        state.currentTrick.append(TrickPlay(playerID: playerID, card: card))
        animationEvents.append(.cardPlayed(id: UUID(), playerID: playerID, card: card))

        if state.currentTrick.count == state.numPlayers {
            resolveCurrentTrick()
        } else {
            state.currentPlayer = (playerID + 1) % state.numPlayers
        }
    }

    func resolveCurrentTrick() {
        let winner = trickWinner()
        state.lastWinner = winner
        state.lastTrick = state.currentTrick
        state.currentTrick = []
        state.trickCount += 1
        state.lead = winner

        for playerID in state.players.indices {
            state.players[playerID].brigadeLeader = playerID == winner
        }
        state.players[winner].hasWonTrickThisYear = true
        state.players[winner].medals += 1

        if winner == 0 {
            state.phase = .assignment
            state.currentPlayer = 0
            state.pendingAssignments = [:]
        } else {
            state.phase = .assignment
            state.currentPlayer = winner
        }
    }

    func trickWinner() -> Int {
        let leadSuit = state.lastOrCurrentTrickLeadSuit
        let plays = state.currentTrick
        let trumpCards = plays.filter { $0.card.suit == state.trump }
        let candidates = trumpCards.isEmpty ? plays.filter { $0.card.suit == leadSuit } : trumpCards
        return candidates.max { $0.card.value < $1.card.value }?.playerID ?? state.lead
    }

    func isValidPlay(playerID: Int, cardIndex: Int) -> Bool {
        guard state.players.indices.contains(playerID),
              state.players[playerID].hand.indices.contains(cardIndex) else {
            return false
        }
        guard let leadSuit = state.currentTrick.first?.card.suit else {
            return true
        }
        let hand = state.players[playerID].hand
        let hasLeadSuit = hand.contains { $0.suit == leadSuit }
        return !hasLeadSuit || hand[cardIndex].suit == leadSuit
    }

    func chooseTrump(for playerID: Int) -> Suit {
        let hand = state.players[playerID].hand
        return Suit.allCases.max { lhs, rhs in
            let leftScore = hand.filter { $0.suit == lhs }.count * 4 + hand.filter { $0.suit == lhs && $0.value >= 11 }.count * 8
            let rightScore = hand.filter { $0.suit == rhs }.count * 4 + hand.filter { $0.suit == rhs && $0.value >= 11 }.count * 8
            return leftScore < rightScore
        } ?? .wheat
    }

    func chooseCardIndex(for playerID: Int) -> Int {
        let hand = state.players[playerID].hand
        let valid = hand.indices.filter { isValidPlay(playerID: playerID, cardIndex: $0) }
        guard !valid.isEmpty else { return 0 }

        let wantsWin = state.players[playerID].hasWonTrickThisYear == false && state.trickCount >= 2
        if wantsWin {
            return valid.max { hand[$0].value < hand[$1].value } ?? valid[0]
        }
        return valid.min { hand[$0].value < hand[$1].value } ?? valid[0]
    }

    func chooseAssignments(for playerID: Int) -> [String: Suit] {
        let legalSuits = Array(Set(state.lastTrick.map(\.card.suit)))
        let bestSuit = legalSuits.max { lhs, rhs in
            let left = assignmentPriority(for: lhs, playerID: playerID)
            let right = assignmentPriority(for: rhs, playerID: playerID)
            return left < right
        } ?? legalSuits[0]

        return Dictionary(uniqueKeysWithValues: state.lastTrick.map { ($0.card.id, bestSuit) })
    }

    func assignmentPriority(for suit: Suit, playerID: Int) -> Int {
        let current = state.workHours[suit, default: 0]
        let atRisk = (state.players[playerID].plot.hidden + state.players[playerID].plot.revealed).filter { $0.suit == suit }.count
        let nearCompletion = max(0, 40 - current)
        return current + atRisk * 12 - nearCompletion / 2
    }

    func applyAssignments(_ assignments: [String: Suit]) {
        for play in state.lastTrick {
            guard let targetSuit = assignments[play.card.id] else { continue }
            animationEvents.append(.workAssigned(
                id: UUID(),
                playerID: play.playerID,
                card: play.card,
                targetSuit: targetSuit,
                value: workValue(for: play.card)
            ))
            state.jobBuckets[targetSuit, default: []].append(play.card)
            state.workHours[targetSuit, default: 0] += workValue(for: play.card)
        }

        for suit in Suit.allCases where state.workHours[suit, default: 0] >= workThreshold && !state.claimedJobs.contains(suit) {
            state.claimedJobs.insert(suit)
            guard let winner = state.lastWinner else { continue }

            if state.variants.deckType == 36 && state.variants.ordenNachalniku {
                let bucket = state.jobBuckets[suit, default: []]
                guard let lowest = bucket.min(by: { $0.value < $1.value }) else { continue }
                let hidden = bucket
                    .filter { $0 != lowest }
                    .sorted { $0.value < $1.value }
                state.players[winner].plot.stacks.append(PlotStack(revealed: [lowest], hidden: hidden))
                state.jobBuckets[suit] = []
                animationEvents.append(.jobClaimed(id: UUID(), winnerID: winner, suit: suit, reward: lowest))
            } else if state.variants.deckType != 36, !state.variants.northernStyle, let reward = state.revealedJobs[suit] {
                if state.variants.accumulateJobs {
                    let rewards = state.accumulatedJobCards[suit, default: []] + [reward]
                    state.players[winner].plot.revealed.append(contentsOf: rewards)
                    state.accumulatedJobCards[suit] = []
                } else {
                    state.players[winner].plot.revealed.append(reward)
                }
                state.revealedJobs[suit] = nil
                animationEvents.append(.jobClaimed(id: UUID(), winnerID: winner, suit: suit, reward: reward))
            }
        }
    }

    func workValue(for card: Card) -> Int {
        if state.variants.nomenclature && card.value == 11 && card.suit == state.trump {
            return 0
        }
        return card.value
    }

    func advanceAfterAssignments() {
        if isYearComplete {
            moveRemainingHandsToPlots()
            performRequisition()
        } else {
            state.phase = .trick
            state.currentPlayer = state.lead
        }
    }

    var isYearComplete: Bool {
        let expectedTricks = state.isFamine ? 3 : 4
        return state.trickCount >= expectedTricks || state.players.contains { $0.hand.isEmpty } || state.players.allSatisfy { $0.hand.count == 1 }
    }

    func moveRemainingHandsToPlots() {
        for playerID in state.players.indices {
            state.players[playerID].plot.hidden.append(contentsOf: state.players[playerID].hand)
            state.players[playerID].hand = []
        }
    }

    func performRequisition() {
        state.phase = .requisition
        state.currentPlayer = 0
        state.requisitionEvents = []

        let heroID = state.variants.heroOfSovietUnion ? heroPlayerID() : nil
        for suit in Suit.allCases where state.workHours[suit, default: 0] < workThreshold {
            if handleDrunkard(in: suit) {
                continue
            }
            let bucket = state.jobBuckets[suit, default: []]
            let informant = state.variants.nomenclature && bucket.contains { $0.value == 12 && $0.suit == state.trump }
            let partyOfficial = state.variants.nomenclature && bucket.contains { $0.value == 13 && $0.suit == state.trump }
            var exiledForSuit = false
            for playerID in state.players.indices {
                if heroID == playerID { continue }
                let isVulnerable = state.variants.northernStyle || state.variants.miceVariant || informant || state.players[playerID].hasWonTrickThisYear
                guard isVulnerable else { continue }
                revealHiddenCards(playerID: playerID, suit: suit, revealAll: state.variants.miceVariant || informant)

                let revealedCards = state.players[playerID].plot.revealed
                    .filter { $0.suit == suit }
                    .sorted { $0.value > $1.value }
                for card in revealedCards.prefix(partyOfficial ? 2 : 1) {
                    state.exiled[state.year, default: []].append(card)
                    state.requisitionEvents.append(RequisitionEvent(
                        playerID: playerID,
                        suit: suit,
                        card: card,
                        message: requisitionExileMessage(playerID: playerID, card: card, suit: suit)
                    ))
                    animationEvents.append(.cardExiled(id: UUID(), playerID: playerID, suit: suit, card: card))
                    exiledForSuit = true
                }
            }

            if !exiledForSuit {
                state.requisitionEvents.append(RequisitionEvent(
                    playerID: nil,
                    suit: suit,
                    card: nil,
                    message: "\(suit.rawValue) failed; no vulnerable matching cards"
                ))
            }
        }

        if let heroID {
            state.requisitionEvents.insert(RequisitionEvent(
                playerID: heroID,
                suit: .wheat,
                card: nil,
                message: heroImmunityMessage(playerID: heroID)
            ), at: 0)
        }
    }

    func requisitionExileMessage(playerID: Int, card: Card, suit: Suit) -> String {
        if state.players[playerID].isHuman {
            return "You send \(card.rank) \(suit.rawValue) north"
        }
        return "\(state.players[playerID].name) sends \(card.rank) \(suit.rawValue) north"
    }

    func heroImmunityMessage(playerID: Int) -> String {
        if state.players[playerID].isHuman {
            return "You are immune after winning every trick"
        }
        return "\(state.players[playerID].name) is immune after winning every trick"
    }

    func heroPlayerID() -> Int? {
        let required = state.isFamine ? 3 : 4
        return state.players.first(where: { $0.medals == required })?.id
    }

    func handleDrunkard(in suit: Suit) -> Bool {
        guard state.variants.nomenclature,
              let trump = state.trump,
              let drunkard = state.jobBuckets[suit, default: []].first(where: { $0.value == 11 && $0.suit == trump }) else {
            return false
        }
        state.exiled[state.year, default: []].append(drunkard)
        if let reward = state.revealedJobs[suit] {
            state.drunkardReplacements.append(reward)
        }
        state.requisitionEvents.append(RequisitionEvent(
            playerID: nil,
            suit: suit,
            card: drunkard,
            message: "Drunkard \(drunkard.rank) \(drunkard.suit.rawValue) goes north"
        ))
        animationEvents.append(.cardExiled(id: UUID(), playerID: nil, suit: suit, card: drunkard))
        return true
    }

    func revealHiddenCards(playerID: Int, suit: Suit, revealAll: Bool) {
        let matching = state.players[playerID].plot.hidden.filter { $0.suit == suit }
        let cardsToReveal: [Card]
        if revealAll {
            cardsToReveal = matching
        } else if let highest = matching.max(by: { $0.value < $1.value }) {
            cardsToReveal = [highest]
        } else {
            return
        }
        for card in cardsToReveal {
            guard let index = state.players[playerID].plot.hidden.firstIndex(of: card) else { continue }
            state.players[playerID].plot.hidden.remove(at: index)
            state.players[playerID].plot.revealed.append(card)
        }
    }

    func removeExiledCards() {
        let cards = state.exiled[state.year, default: []]
        for card in cards {
            for playerID in state.players.indices {
                if let index = state.players[playerID].plot.revealed.firstIndex(of: card) {
                    state.players[playerID].plot.revealed.remove(at: index)
                    break
                }
            }
        }
    }

    func transitionToNextYear() {
        for suit in Suit.allCases {
            guard state.variants.deckType != 36, !state.variants.northernStyle else { continue }
            if let unclaimed = state.revealedJobs[suit] {
                if state.variants.accumulateJobs {
                    state.accumulatedJobCards[suit, default: []].append(unclaimed)
                } else {
                    state.exiled[state.year, default: []].append(unclaimed)
                }
            }
        }

        state.year += 1
        if state.year > maxYears {
            finishGame()
            return
        }

        state.trickCount = 0
        state.currentTrick = []
        state.lastTrick = []
        state.lastWinner = nil
        state.trump = nil
        state.claimedJobs = []
        state.requisitionEvents = []
        state.swapConfirmed = []
        state.swapCount = []
        state.lastSwap = nil
        state.workHours = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, 0) })
        state.jobBuckets = Dictionary(uniqueKeysWithValues: Suit.allCases.map { ($0, []) })
        if state.variants.ordenNachalniku && state.variants.deckType == 36 {
            for playerID in state.players.indices {
                for stack in state.players[playerID].plot.stacks {
                    state.players[playerID].plot.revealed.append(contentsOf: stack.revealed)
                }
                state.players[playerID].plot.stacks = []
            }
        }
        revealJobs()
        state.isFamine = state.year == maxYears

        for playerID in state.players.indices {
            state.players[playerID].plot.medals += state.players[playerID].medals
            state.players[playerID].medals = 0
            state.players[playerID].hasWonTrickThisYear = false
            state.players[playerID].brigadeLeader = false
        }

        state.trumpSelector = (state.trumpSelector + 1) % state.numPlayers
        state.currentPlayer = state.trumpSelector
        state.phase = .planning
        dealHands()
    }

    func finishGame() {
        let scores = Dictionary(uniqueKeysWithValues: state.players.map { ($0.id, finalScore(for: $0.id)) })
        let winner = scores.max { $0.value < $1.value }?.key ?? 0
        state.gameResult = GameResult(winnerID: winner, scores: scores)
        state.phase = .gameOver
        state.currentPlayer = 0
    }
}

private extension KolkhozState {
    var lastOrCurrentTrickLeadSuit: Suit {
        currentTrick.first?.card.suit ?? lastTrick.first?.card.suit ?? .wheat
    }
}

private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed == 0 ? 1 : seed
    }

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}
