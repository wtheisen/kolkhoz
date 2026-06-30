import Foundation

public struct KolkhozPolicyModel: Codable, Sendable {
    public let version: Int
    public let featureVersion: Int
    public let inputSize: Int
    public let hiddenSize: Int
    public let w1: [Double]
    public let b1: [Double]
    public let w2: [Double]
    public let b2: Double

    private enum CodingKeys: String, CodingKey {
        case version
        case featureVersion = "feature_version"
        case inputSize = "input_size"
        case hiddenSize = "hidden_size"
        case w1
        case b1
        case w2
        case b2
    }

    public init(
        version: Int,
        featureVersion: Int,
        inputSize: Int,
        hiddenSize: Int,
        w1: [Double],
        b1: [Double],
        w2: [Double],
        b2: Double
    ) {
        self.version = version
        self.featureVersion = featureVersion
        self.inputSize = inputSize
        self.hiddenSize = hiddenSize
        self.w1 = w1
        self.b1 = b1
        self.w2 = w2
        self.b2 = b2
    }

    public static func load(from url: URL) throws -> KolkhozPolicyModel {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(KolkhozPolicyModel.self, from: data)
    }

    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }

    public static func bundled(named name: String = "kolkhoz_policy") -> KolkhozPolicyModel? {
        guard let url = Bundle.kolkhozCoreResources.url(forResource: name, withExtension: "json") else {
            return nil
        }
        return try? load(from: url)
    }

    public var isCompatible: Bool {
        featureVersion == KolkhozAIFeatures.version
            && inputSize == KolkhozAIFeatures.inputSize
            && w1.count == hiddenSize * inputSize
            && b1.count == hiddenSize
            && w2.count == hiddenSize
    }

    public func score(_ features: [Double]) -> Double {
        guard isCompatible, features.count == inputSize else { return 0 }

        var hidden = Array(repeating: 0.0, count: hiddenSize)
        for row in 0..<hiddenSize {
            var value = b1[row]
            let offset = row * inputSize
            for column in 0..<inputSize {
                value += w1[offset + column] * features[column]
            }
            hidden[row] = max(0, value)
        }

        var output = b2
        for index in 0..<hiddenSize {
            output += w2[index] * hidden[index]
        }
        return output
    }
}

public struct KolkhozAIDecider {
    public let state: KolkhozState
    public let model: KolkhozPolicyModel?

    public init(state: KolkhozState, model: KolkhozPolicyModel?) {
        self.state = state
        self.model = model?.isCompatible == true ? model : nil
    }

    public func chooseTrump(for playerID: Int) -> Suit {
        if let model {
            return Suit.allCases.max { lhs, rhs in
                model.score(KolkhozAIFeatures.trump(state: state, playerID: playerID, suit: lhs))
                    < model.score(KolkhozAIFeatures.trump(state: state, playerID: playerID, suit: rhs))
            } ?? heuristicTrump(for: playerID)
        }
        return heuristicTrump(for: playerID)
    }

    public func chooseSwap(for playerID: Int) -> (handCard: Card, plotCard: Card, zone: PlotCardZone)? {
        if let model, let choice = modelSwap(for: playerID, model: model) {
            return choice
        }
        return heuristicSwap(for: playerID)
    }

    public func chooseCardIndex(for playerID: Int) -> Int {
        let hand = state.players[playerID].hand
        let valid = hand.indices.filter { isValidPlay(playerID: playerID, cardIndex: $0) }
        guard !valid.isEmpty else { return 0 }

        if let model {
            return valid.max { lhs, rhs in
                model.score(KolkhozAIFeatures.playCard(state: state, playerID: playerID, card: hand[lhs]))
                    < model.score(KolkhozAIFeatures.playCard(state: state, playerID: playerID, card: hand[rhs]))
            } ?? valid[0]
        }
        return heuristicCardIndex(for: playerID, valid: valid)
    }

    public func chooseAssignments(for playerID: Int) -> [String: Suit] {
        let legalSet = Set(state.lastTrick.map(\.card.suit))
        let legalSuits = Suit.allCases.filter { legalSet.contains($0) }
        guard let firstSuit = legalSuits.first else { return [:] }

        let bestSuit: Suit
        if let model {
            bestSuit = legalSuits.max { lhs, rhs in
                model.score(KolkhozAIFeatures.assign(state: state, playerID: playerID, suit: lhs))
                    < model.score(KolkhozAIFeatures.assign(state: state, playerID: playerID, suit: rhs))
            } ?? firstSuit
        } else {
            bestSuit = legalSuits.max { lhs, rhs in
                assignmentPriority(for: lhs, playerID: playerID) < assignmentPriority(for: rhs, playerID: playerID)
            } ?? firstSuit
        }

        return Dictionary(uniqueKeysWithValues: state.lastTrick.map { ($0.card.id, bestSuit) })
    }

    public func isValidPlay(playerID: Int, cardIndex: Int) -> Bool {
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
}

private extension KolkhozAIDecider {
    func heuristicTrump(for playerID: Int) -> Suit {
        let hand = state.players[playerID].hand
        return Suit.allCases.max { lhs, rhs in
            let leftScore = hand.filter { $0.suit == lhs }.count * 4 + hand.filter { $0.suit == lhs && $0.value >= 11 }.count * 8
            let rightScore = hand.filter { $0.suit == rhs }.count * 4 + hand.filter { $0.suit == rhs && $0.value >= 11 }.count * 8
            return leftScore < rightScore
        } ?? .wheat
    }

    func heuristicSwap(for playerID: Int) -> (handCard: Card, plotCard: Card, zone: PlotCardZone)? {
        guard !state.swapCount.contains(playerID),
              let handCard = state.players[playerID].hand.min(by: { $0.value < $1.value }) else {
            return nil
        }

        let hiddenCandidate = state.players[playerID].plot.hidden.max(by: { $0.value < $1.value }).map { ($0, PlotCardZone.hidden) }
        let revealedCandidate = state.players[playerID].plot.revealed.max(by: { $0.value < $1.value }).map { ($0, PlotCardZone.revealed) }
        let candidate = [hiddenCandidate, revealedCandidate]
            .compactMap { $0 }
            .max { lhs, rhs in lhs.0.value < rhs.0.value }

        guard let (plotCard, zone) = candidate, plotCard.value > handCard.value + 1 else {
            return nil
        }
        return (handCard, plotCard, zone)
    }

    func modelSwap(for playerID: Int, model: KolkhozPolicyModel) -> (handCard: Card, plotCard: Card, zone: PlotCardZone)? {
        guard !state.swapCount.contains(playerID) else { return nil }
        var candidates: [(Card, Card, PlotCardZone, Double)] = []
        for handCard in state.players[playerID].hand {
            for plotCard in state.players[playerID].plot.hidden {
                let score = model.score(KolkhozAIFeatures.swap(state: state, playerID: playerID, handCard: handCard, plotCard: plotCard, zone: .hidden))
                candidates.append((handCard, plotCard, .hidden, score))
            }
            for plotCard in state.players[playerID].plot.revealed {
                let score = model.score(KolkhozAIFeatures.swap(state: state, playerID: playerID, handCard: handCard, plotCard: plotCard, zone: .revealed))
                candidates.append((handCard, plotCard, .revealed, score))
            }
        }

        guard let best = candidates.max(by: { $0.3 < $1.3 }), best.3 > 0 else {
            return nil
        }
        return (best.0, best.1, best.2)
    }

    func heuristicCardIndex(for playerID: Int, valid: [Int]) -> Int {
        let hand = state.players[playerID].hand
        let wantsWin = state.players[playerID].hasWonTrickThisYear == false && state.trickCount >= 2
        if wantsWin {
            return valid.max { hand[$0].value < hand[$1].value } ?? valid[0]
        }
        return valid.min { hand[$0].value < hand[$1].value } ?? valid[0]
    }

    func assignmentPriority(for suit: Suit, playerID: Int) -> Int {
        let current = state.workHours[suit, default: 0]
        let atRisk = (state.players[playerID].plot.hidden + state.players[playerID].plot.revealed).filter { $0.suit == suit }.count
        let nearCompletion = max(0, 40 - current)
        return current + atRisk * 12 - nearCompletion / 2
    }
}

enum KolkhozAIFeatures {
    static let version = 1
    static let inputSize = 34

    static func trump(state: KolkhozState, playerID: Int, suit: Suit) -> [Double] {
        features(state: state, playerID: playerID, action: .trump, suit: suit, card: nil, zone: nil, swapDelta: 0)
    }

    static func swap(state: KolkhozState, playerID: Int, handCard: Card, plotCard: Card, zone: PlotCardZone) -> [Double] {
        features(
            state: state,
            playerID: playerID,
            action: .swap,
            suit: plotCard.suit,
            card: plotCard,
            zone: zone,
            swapDelta: Double(plotCard.value - handCard.value) / 13
        )
    }

    static func playCard(state: KolkhozState, playerID: Int, card: Card) -> [Double] {
        features(state: state, playerID: playerID, action: .play, suit: card.suit, card: card, zone: nil, swapDelta: 0)
    }

    static func assign(state: KolkhozState, playerID: Int, suit: Suit) -> [Double] {
        features(state: state, playerID: playerID, action: .assign, suit: suit, card: nil, zone: nil, swapDelta: 0)
    }
}

private extension KolkhozAIFeatures {
    enum Action: Int {
        case trump
        case swap
        case play
        case assign
    }

    static func features(
        state: KolkhozState,
        playerID: Int,
        action: Action,
        suit: Suit,
        card: Card?,
        zone: PlotCardZone?,
        swapDelta: Double
    ) -> [Double] {
        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = state.workHours[suit, default: 0]
        let afterWork = currentWork + trickWork
        let plotCards = player.plot.hidden + player.plot.revealed
        let suitPlotCount = plotCards.filter { $0.suit == suit }.count
        let hiddenSuitCount = player.plot.hidden.filter { $0.suit == suit }.count
        let revealedJob = state.revealedJobs[suit]?.value ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(suitIndex(suit), count: 4))
        values.append(contentsOf: oneHot(card.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(card?.value ?? 0) / 13)
        values.append(Double(state.year) / 5)
        values.append(Double(state.trickCount) / 4)
        values.append(Double(player.hand.count) / 5)
        values.append(player.hasWonTrickThisYear ? 1 : 0)
        values.append(contentsOf: oneHot(leadSuit.map(suitIndex) ?? -1, count: 4))
        values.append(contentsOf: oneHot(state.trump.map(suitIndex) ?? -1, count: 4))
        values.append(Double(currentWork) / 40)
        values.append(Double(afterWork >= 40 ? 1 : 0))
        values.append(Double(suitPlotCount) / 8)
        values.append(Double(hiddenSuitCount) / 8)
        values.append(Double(revealedJob) / 5)
        values.append(wouldCurrentlyWin(card, state: state) ? 1 : 0)
        values.append(zone == .hidden ? 1 : 0)
        values.append(zone == .revealed ? 1 : 0)
        values.append(swapDelta)

        precondition(values.count == inputSize, "Kolkhoz AI feature size changed")
        return values
    }

    static func oneHot(_ selected: Int, count: Int) -> [Double] {
        (0..<count).map { $0 == selected ? 1 : 0 }
    }

    static func suitIndex(_ suit: Suit) -> Int {
        switch suit {
        case .wheat: 0
        case .sunflower: 1
        case .potato: 2
        case .beet: 3
        }
    }

    static func workValue(for card: Card, state: KolkhozState) -> Int {
        if state.variants.nomenclature && card.value == 11 && card.suit == state.trump {
            return 0
        }
        return card.value
    }

    static func wouldCurrentlyWin(_ card: Card?, state: KolkhozState) -> Bool {
        guard let card, !state.currentTrick.isEmpty else { return false }
        let candidate = TrickPlay(playerID: state.currentPlayer, card: card)
        let plays = state.currentTrick + [candidate]
        let leadSuit = state.currentTrick.first?.card.suit ?? card.suit
        let trumpCards = plays.filter { $0.card.suit == state.trump }
        let contenders = trumpCards.isEmpty ? plays.filter { $0.card.suit == leadSuit } : trumpCards
        return contenders.max { $0.card.value < $1.card.value } == candidate
    }
}

private final class KolkhozCoreBundleToken {}

extension Bundle {
    static let kolkhozCoreResources: Bundle = {
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: KolkhozCoreBundleToken.self)
        #endif
    }()
}
