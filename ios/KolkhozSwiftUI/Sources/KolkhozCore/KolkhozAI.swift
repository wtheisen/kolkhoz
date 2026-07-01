import Foundation

public struct KolkhozPolicyModel: Codable, Sendable {
    public let version: Int
    public let featureVersion: Int
    public let inputSize: Int
    public let hiddenSize: Int
    public let hiddenLayerSizes: [Int]
    public let w1: [Double]
    public let b1: [Double]
    public let hiddenWeights: [[Double]]
    public let hiddenBiases: [[Double]]
    public let w2: [Double]
    public let outputWeights: [Double]
    public let b2: Double
    public let b2s: [Double]
    public let valueWeights: [Double]
    public let valueBias: Double

    private enum CodingKeys: String, CodingKey {
        case version
        case featureVersion = "feature_version"
        case inputSize = "input_size"
        case hiddenSize = "hidden_size"
        case hiddenLayerSizes = "hidden_layers"
        case w1
        case b1
        case hiddenWeights = "hidden_weights"
        case hiddenBiases = "hidden_biases"
        case w2
        case outputWeights = "output_weights"
        case b2
        case b2s
        case valueWeights = "value_weights"
        case valueBias = "value_bias"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decode(Int.self, forKey: .version)
        self.featureVersion = try container.decode(Int.self, forKey: .featureVersion)
        self.inputSize = try container.decode(Int.self, forKey: .inputSize)
        self.hiddenSize = try container.decode(Int.self, forKey: .hiddenSize)
        self.hiddenLayerSizes = try container.decodeIfPresent([Int].self, forKey: .hiddenLayerSizes) ?? []
        self.w1 = try container.decode([Double].self, forKey: .w1)
        self.b1 = try container.decode([Double].self, forKey: .b1)
        self.hiddenWeights = try container.decodeIfPresent([[Double]].self, forKey: .hiddenWeights) ?? []
        self.hiddenBiases = try container.decodeIfPresent([[Double]].self, forKey: .hiddenBiases) ?? []
        self.w2 = try container.decodeIfPresent([Double].self, forKey: .w2) ?? []
        self.outputWeights = try container.decodeIfPresent([Double].self, forKey: .outputWeights) ?? []
        self.b2 = try container.decode(Double.self, forKey: .b2)
        self.b2s = try container.decodeIfPresent([Double].self, forKey: .b2s) ?? [self.b2]
        self.valueWeights = try container.decodeIfPresent([Double].self, forKey: .valueWeights) ?? []
        self.valueBias = try container.decodeIfPresent(Double.self, forKey: .valueBias) ?? 0
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(featureVersion, forKey: .featureVersion)
        try container.encode(inputSize, forKey: .inputSize)
        try container.encode(hiddenSize, forKey: .hiddenSize)
        if usesLayerStack {
            try container.encode(hiddenLayerSizes, forKey: .hiddenLayerSizes)
        }
        try container.encode(w1, forKey: .w1)
        try container.encode(b1, forKey: .b1)
        if usesLayerStack {
            try container.encode(hiddenWeights, forKey: .hiddenWeights)
            try container.encode(hiddenBiases, forKey: .hiddenBiases)
        }
        try container.encode(w2, forKey: .w2)
        if usesLayerStack {
            try container.encode(outputWeights, forKey: .outputWeights)
        }
        try container.encode(b2, forKey: .b2)
        try container.encode(b2s, forKey: .b2s)
        if !valueWeights.isEmpty || valueBias != 0 {
            try container.encode(valueWeights, forKey: .valueWeights)
            try container.encode(valueBias, forKey: .valueBias)
        }
    }

    public init(
        version: Int,
        featureVersion: Int,
        inputSize: Int,
        hiddenSize: Int,
        hiddenLayerSizes: [Int] = [],
        w1: [Double],
        b1: [Double],
        hiddenWeights: [[Double]] = [],
        hiddenBiases: [[Double]] = [],
        w2: [Double],
        outputWeights: [Double] = [],
        b2: Double,
        b2s: [Double]? = nil,
        valueWeights: [Double] = [],
        valueBias: Double = 0
    ) {
        self.version = version
        self.featureVersion = featureVersion
        self.inputSize = inputSize
        self.hiddenSize = hiddenSize
        self.hiddenLayerSizes = hiddenLayerSizes
        self.w1 = w1
        self.b1 = b1
        self.hiddenWeights = hiddenWeights
        self.hiddenBiases = hiddenBiases
        self.w2 = w2
        self.outputWeights = outputWeights
        self.b2 = b2
        self.b2s = b2s ?? [b2]
        self.valueWeights = valueWeights
        self.valueBias = valueBias
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
        let headCount = self.headCount
        let validHeads = headCount == 1 || headCount == KolkhozAIFeatures.actionHeadCount || headCount == KolkhozAIFeatures.seatActionHeadCount
        let legacy = !usesLayerStack
            && w2.count == hiddenSize * headCount
        let stacked = usesLayerStack
            && hiddenLayerSizes.count <= 4
            && hiddenLayerSizes.allSatisfy { $0 > 0 }
            && hiddenWeights.count == hiddenLayerSizes.count
            && hiddenBiases.count == hiddenLayerSizes.count
            && hiddenWeights.indices.allSatisfy { index in
                let inputCount = index == 0 ? inputSize : hiddenLayerSizes[index - 1]
                return hiddenWeights[index].count == hiddenLayerSizes[index] * inputCount
                    && hiddenBiases[index].count == hiddenLayerSizes[index]
            }
            && outputWeights.count == (hiddenLayerSizes.last ?? 0) * headCount
        return KolkhozAIFeatures.isSupported(featureVersion: featureVersion, inputSize: inputSize)
            && inputSize > 0
            && hiddenSize > 0
            && w1.count == hiddenSize * inputSize
            && b1.count == hiddenSize
            && validHeads
            && (legacy || stacked)
            && b2s.count == headCount
    }

    public var headCount: Int {
        max(1, b2s.count)
    }

    public var usesLayerStack: Bool {
        !hiddenLayerSizes.isEmpty
    }

    public func score(_ features: [Double]) -> Double {
        guard isCompatible, features.count == inputSize else { return 0 }
        let head = headIndex(for: features)

        if usesLayerStack {
            var previous = features
            for layer in hiddenLayerSizes.indices {
                let layerSize = hiddenLayerSizes[layer]
                let inputCount = previous.count
                let weights = hiddenWeights[layer]
                let biases = hiddenBiases[layer]
                var next = Array(repeating: 0.0, count: layerSize)
                for row in 0..<layerSize {
                    var value = biases[row]
                    let offset = row * inputCount
                    for column in 0..<inputCount {
                        value += weights[offset + column] * previous[column]
                    }
                    next[row] = max(0, value)
                }
                previous = next
            }
            var output = b2s[head]
            let headOffset = head * previous.count
            for index in 0..<previous.count {
                output += outputWeights[headOffset + index] * previous[index]
            }
            return output
        }

        var hidden = Array(repeating: 0.0, count: hiddenSize)
        for row in 0..<hiddenSize {
            var value = b1[row]
            let offset = row * inputSize
            for column in 0..<inputSize {
                value += w1[offset + column] * features[column]
            }
            hidden[row] = max(0, value)
        }

        var output = b2s[head]
        let headOffset = head * hiddenSize
        for index in 0..<hiddenSize {
            output += w2[headOffset + index] * hidden[index]
        }
        return output
    }

    private func headIndex(for features: [Double]) -> Int {
        guard headCount > 1 else { return 0 }
        let actionSlice = features.prefix(KolkhozAIFeatures.actionHeadCount)
        let selected = actionSlice.enumerated().max { $0.element < $1.element }?.offset ?? 0
        if headCount == KolkhozAIFeatures.seatActionHeadCount,
           featureVersion >= KolkhozAIFeatures.v3Version {
            let playerRange = featureVersion >= KolkhozAIFeatures.v4Version ? 4..<8 : 83..<87
            guard features.count >= playerRange.upperBound else {
                return min(max(0, selected), headCount - 1)
            }
            let playerSlice = features[playerRange]
            let player = playerSlice.enumerated().max { $0.element < $1.element }?.offset ?? 0
            return min(max(0, player * KolkhozAIFeatures.actionHeadCount + selected), headCount - 1)
        }
        return min(max(0, selected), headCount - 1)
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
                model.score(KolkhozAIFeatures.trump(state: state, playerID: playerID, suit: lhs, featureVersion: model.featureVersion))
                    < model.score(KolkhozAIFeatures.trump(state: state, playerID: playerID, suit: rhs, featureVersion: model.featureVersion))
            } ?? heuristicTrump(for: playerID)
        }
        return heuristicTrump(for: playerID)
    }

    public func chooseSwap(for playerID: Int) -> (handCard: Card, plotCard: Card, zone: PlotCardZone)? {
        if let model {
            let choice = modelSwap(for: playerID, model: model)
            if model.featureVersion >= KolkhozAIFeatures.version {
                return choice
            }
            if let choice {
                return choice
            }
        }
        return heuristicSwap(for: playerID)
    }

    public func chooseCardIndex(for playerID: Int) -> Int {
        let hand = state.players[playerID].hand
        let valid = hand.indices.filter { isValidPlay(playerID: playerID, cardIndex: $0) }
        guard !valid.isEmpty else { return 0 }

        if let model {
            return valid.max { lhs, rhs in
                model.score(KolkhozAIFeatures.playCard(state: state, playerID: playerID, card: hand[lhs], featureVersion: model.featureVersion))
                    < model.score(KolkhozAIFeatures.playCard(state: state, playerID: playerID, card: hand[rhs], featureVersion: model.featureVersion))
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
                model.score(KolkhozAIFeatures.assign(state: state, playerID: playerID, suit: lhs, featureVersion: model.featureVersion))
                    < model.score(KolkhozAIFeatures.assign(state: state, playerID: playerID, suit: rhs, featureVersion: model.featureVersion))
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
        let noSwapScore: Double
        if model.featureVersion >= KolkhozAIFeatures.version {
            noSwapScore = model.score(KolkhozAIFeatures.noSwap(state: state, playerID: playerID, featureVersion: model.featureVersion))
        } else {
            noSwapScore = 0
        }
        var candidates: [(Card, Card, PlotCardZone, Double)] = []
        for handCard in state.players[playerID].hand {
            for plotCard in state.players[playerID].plot.hidden {
                let score = model.score(KolkhozAIFeatures.swap(state: state, playerID: playerID, handCard: handCard, plotCard: plotCard, zone: .hidden, featureVersion: model.featureVersion))
                candidates.append((handCard, plotCard, .hidden, score))
            }
            for plotCard in state.players[playerID].plot.revealed {
                let score = model.score(KolkhozAIFeatures.swap(state: state, playerID: playerID, handCard: handCard, plotCard: plotCard, zone: .revealed, featureVersion: model.featureVersion))
                candidates.append((handCard, plotCard, .revealed, score))
            }
        }

        guard let best = candidates.max(by: { $0.3 < $1.3 }), best.3 > noSwapScore else {
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
    static let version = 5
    static let inputSize = 200
    static let v4Version = 4
    static let v4InputSize = 200
    static let v3Version = 3
    static let v3InputSize = 95
    static let v2Version = 2
    static let v2InputSize = 83
    static let legacyVersion = 1
    static let legacyInputSize = 34
    static let actionHeadCount = 4
    static let seatActionHeadCount = 16

    static func isSupported(featureVersion: Int, inputSize: Int) -> Bool {
        (featureVersion == version && inputSize == Self.inputSize)
            || (featureVersion == v4Version && inputSize == v4InputSize)
            || (featureVersion == v3Version && inputSize == v3InputSize)
            || (featureVersion == v2Version && inputSize == v2InputSize)
            || (featureVersion == legacyVersion && inputSize == legacyInputSize)
    }

    static func trump(state: KolkhozState, playerID: Int, suit: Suit, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .trump, suit: suit, card: nil, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
    }

    static func swap(state: KolkhozState, playerID: Int, handCard: Card, plotCard: Card, zone: PlotCardZone, featureVersion: Int = version) -> [Double] {
        features(
            state: state,
            playerID: playerID,
            action: .swap,
            suit: plotCard.suit,
            card: plotCard,
            handCard: handCard,
            zone: zone,
            swapDelta: Double(plotCard.value - handCard.value) / 13,
            featureVersion: featureVersion
        )
    }

    static func noSwap(state: KolkhozState, playerID: Int, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .swap, suit: nil, card: nil, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
    }

    static func playCard(state: KolkhozState, playerID: Int, card: Card, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .play, suit: card.suit, card: card, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
    }

    static func assign(state: KolkhozState, playerID: Int, suit: Suit, featureVersion: Int = version) -> [Double] {
        features(state: state, playerID: playerID, action: .assign, suit: suit, card: nil, handCard: nil, zone: nil, swapDelta: 0, featureVersion: featureVersion)
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
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        zone: PlotCardZone?,
        swapDelta: Double,
        featureVersion: Int
    ) -> [Double] {
        if featureVersion == version {
            return v5Features(
                state: state,
                playerID: playerID,
                action: action,
                suit: suit,
                card: card,
                handCard: handCard,
                zone: zone,
                swapDelta: swapDelta
            )
        }
        if featureVersion == v4Version {
            return v4Features(
                state: state,
                playerID: playerID,
                action: action,
                suit: suit,
                card: card,
                handCard: handCard,
                zone: zone,
                swapDelta: swapDelta
            )
        }

        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = suit.map { state.workHours[$0, default: 0] } ?? 0
        let afterWork = currentWork + trickWork
        let plotCards = player.plot.hidden + player.plot.revealed
        let suitPlotCount = suit.map { target in plotCards.filter { $0.suit == target }.count } ?? 0
        let hiddenSuitCount = suit.map { target in player.plot.hidden.filter { $0.suit == target }.count } ?? 0
        let revealedJob = suit.flatMap { state.revealedJobs[$0]?.value } ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(suit.map(suitIndex) ?? -1, count: 4))
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

        if featureVersion == legacyVersion {
            precondition(values.count == legacyInputSize, "Kolkhoz AI legacy feature size changed")
            return values
        }

        appendV2Features(
            to: &values,
            state: state,
            playerID: playerID,
            suit: suit,
            card: card,
            handCard: handCard,
            leadSuit: leadSuit
        )
        if featureVersion == v2Version {
            precondition(values.count == v2InputSize, "Kolkhoz AI v2 feature size changed")
            return values
        }

        appendV3Features(to: &values, state: state, playerID: playerID)
        precondition(values.count == v3InputSize, "Kolkhoz AI v3 feature size changed")
        return values
    }

    static func v5Features(
        state: KolkhozState,
        playerID: Int,
        action: Action,
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        zone: PlotCardZone?,
        swapDelta: Double
    ) -> [Double] {
        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = suit.map { state.workHours[$0, default: 0] } ?? 0
        let afterWork = currentWork + trickWork
        let ownVisible = visibleScore(for: playerID, state: state)
        let ownKnownScore = knownScore(for: playerID, state: state)
        let bestOpponentVisible = state.players
            .filter { $0.id != playerID }
            .map { visibleScore(for: $0.id, state: state) }
            .max() ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(playerID, count: 4))
        values.append(contentsOf: oneHot(suit.map(suitIndex) ?? -1, count: 4))
        values.append(contentsOf: oneHot(card.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(card?.value ?? 0) / 13)
        values.append(Double(handCard?.value ?? 0) / 13)
        values.append(swapDelta)
        values.append(zone == .hidden ? 1 : 0)
        values.append(zone == .revealed ? 1 : 0)
        values.append(Double(state.year) / 5)
        values.append(state.isFamine ? 1 : 0)
        values.append(Double(state.trickCount) / 4)
        values.append(Double(state.currentTrick.count) / 4)
        values.append(Double((playerID - state.lead + 4) % 4) / 3)
        values.append(Double((playerID - state.trumpSelector + 4) % 4) / 3)
        values.append(card?.suit == leadSuit ? 1 : 0)
        values.append(card?.suit == state.trump ? 1 : 0)
        values.append(wouldCurrentlyWin(card, state: state) ? 1 : 0)
        values.append(Double(currentWork) / 40)
        values.append(Double(max(0, 40 - currentWork)) / 40)
        values.append(afterWork >= 40 ? 1 : 0)
        values.append(Double(suit.flatMap { state.revealedJobs[$0]?.value } ?? 0) / 5)
        values.append(suit.map { state.claimedJobs.contains($0) } ?? false ? 1 : 0)
        values.append(Double(player.hand.count) / 5)
        values.append(Double(revealedPlotCount(for: player)) / 16)
        values.append(Double(hiddenPlotCount(for: player)) / 16)
        values.append(Double(player.plot.medals + player.medals) / 20)
        values.append(Double(ownVisible) / 100)
        values.append(Double(ownKnownScore) / 100)
        values.append(Double(bestOpponentVisible) / 100)
        values.append(Double(bestOpponentVisible) / 100)
        values.append(Double(ownKnownScore - bestOpponentVisible) / 100)
        values.append(Double(ownVisible - bestOpponentVisible) / 100)
        values.append(player.hasWonTrickThisYear ? 1 : 0)
        values.append(player.brigadeLeader ? 1 : 0)
        values.append(state.variants.nomenclature ? 1 : 0)
        values.append(state.variants.allowSwap ? 1 : 0)
        values.append(state.variants.northernStyle ? 1 : 0)
        values.append(state.variants.miceVariant ? 1 : 0)
        values.append(state.variants.ordenNachalniku ? 1 : 0)
        values.append(state.variants.medalsCount ? 1 : 0)
        values.append(state.variants.accumulateJobs ? 1 : 0)
        values.append(state.variants.heroOfSovietUnion ? 1 : 0)
        values.append(state.variants.deckType == 36 ? 1 : 0)

        for seat in 0..<4 {
            guard state.players.indices.contains(seat) else {
                values.append(contentsOf: Array(repeating: 0.0, count: 9))
                continue
            }
            let seatPlayer = state.players[seat]
            values.append(Double(seatPlayer.hand.count) / 5)
            values.append(Double(revealedPlotCount(for: seatPlayer)) / 16)
            values.append(Double(hiddenPlotCount(for: seatPlayer)) / 16)
            values.append(Double(seatPlayer.plot.medals + seatPlayer.medals) / 20)
            values.append(seatPlayer.hasWonTrickThisYear ? 1 : 0)
            values.append(seatPlayer.brigadeLeader ? 1 : 0)
            values.append(Double(visibleScore(for: seat, state: state)) / 100)
            values.append(Double(seat == playerID ? knownScore(for: seat, state: state) : visibleScore(for: seat, state: state)) / 100)
            values.append(Double(seat == playerID ? seatPlayer.hand.map(\.value).max() ?? 0 : 0) / 13)
            values.append(Double(seat == playerID ? seatPlayer.hand.map(\.value).min() ?? 0 : 0) / 13)
        }

        for target in Suit.allCases {
            values.append(Double(state.workHours[target, default: 0]) / 40)
            values.append(Double(max(0, 40 - state.workHours[target, default: 0])) / 40)
            values.append(Double(state.revealedJobs[target]?.value ?? 0) / 5)
            values.append(state.claimedJobs.contains(target) ? 1 : 0)
            let ownCards = player.hand.filter { $0.suit == target }
            values.append(Double(ownCards.count) / 5)
            values.append(Double(ownCards.map(\.value).max() ?? 0) / 13)
            values.append(Double(ownCards.map(\.value).min() ?? 0) / 13)
            values.append(Double(revealedPlotCount(for: player, suit: target)) / 8)
            values.append(Double(hiddenPlotCount(for: player, suit: target)) / 8)
            values.append(Double(state.players.reduce(0) { $0 + revealedPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.players.reduce(0) { $0 + hiddenPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.currentTrick.filter { $0.card.suit == target }.count + state.lastTrick.filter { $0.card.suit == target }.count) / 8)
        }

        appendTrickFeatures(to: &values, plays: state.currentTrick)
        appendTrickFeatures(to: &values, plays: state.lastTrick)
        precondition(values.count == inputSize, "Kolkhoz AI v5 feature size changed")
        return values
    }

    static func v4Features(
        state: KolkhozState,
        playerID: Int,
        action: Action,
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        zone: PlotCardZone?,
        swapDelta: Double
    ) -> [Double] {
        let player = state.players[playerID]
        let leadSuit = state.currentTrick.first?.card.suit
        let trickWork = state.lastTrick.reduce(0) { $0 + workValue(for: $1.card, state: state) }
        let currentWork = suit.map { state.workHours[$0, default: 0] } ?? 0
        let afterWork = currentWork + trickWork
        let ownVisible = visibleScore(for: playerID, state: state)
        let ownFinal = gameFinalScore(for: playerID, state: state)
        let bestOpponentVisible = state.players
            .filter { $0.id != playerID }
            .map { visibleScore(for: $0.id, state: state) }
            .max() ?? 0
        let bestOpponentFinal = state.players
            .filter { $0.id != playerID }
            .map { gameFinalScore(for: $0.id, state: state) }
            .max() ?? 0

        var values: [Double] = []
        values.append(contentsOf: oneHot(action.rawValue, count: 4))
        values.append(contentsOf: oneHot(playerID, count: 4))
        values.append(contentsOf: oneHot(suit.map(suitIndex) ?? -1, count: 4))
        values.append(contentsOf: oneHot(card.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(card?.value ?? 0) / 13)
        values.append(Double(handCard?.value ?? 0) / 13)
        values.append(swapDelta)
        values.append(zone == .hidden ? 1 : 0)
        values.append(zone == .revealed ? 1 : 0)
        values.append(Double(state.year) / 5)
        values.append(state.isFamine ? 1 : 0)
        values.append(Double(state.trickCount) / 4)
        values.append(Double(state.currentTrick.count) / 4)
        values.append(Double((playerID - state.lead + 4) % 4) / 3)
        values.append(Double((playerID - state.trumpSelector + 4) % 4) / 3)
        values.append(card?.suit == leadSuit ? 1 : 0)
        values.append(card?.suit == state.trump ? 1 : 0)
        values.append(wouldCurrentlyWin(card, state: state) ? 1 : 0)
        values.append(Double(currentWork) / 40)
        values.append(Double(max(0, 40 - currentWork)) / 40)
        values.append(afterWork >= 40 ? 1 : 0)
        values.append(Double(suit.flatMap { state.revealedJobs[$0]?.value } ?? 0) / 5)
        values.append(suit.map { state.claimedJobs.contains($0) } ?? false ? 1 : 0)
        values.append(Double(player.hand.count) / 5)
        values.append(Double(revealedPlotCount(for: player)) / 16)
        values.append(Double(hiddenPlotCount(for: player)) / 16)
        values.append(Double(player.plot.medals + player.medals) / 20)
        values.append(Double(ownVisible) / 100)
        values.append(Double(ownFinal) / 100)
        values.append(Double(bestOpponentVisible) / 100)
        values.append(Double(bestOpponentFinal) / 100)
        values.append(Double(ownFinal - bestOpponentFinal) / 100)
        values.append(Double(ownVisible - bestOpponentVisible) / 100)
        values.append(player.hasWonTrickThisYear ? 1 : 0)
        values.append(player.brigadeLeader ? 1 : 0)
        values.append(state.variants.nomenclature ? 1 : 0)
        values.append(state.variants.allowSwap ? 1 : 0)
        values.append(state.variants.northernStyle ? 1 : 0)
        values.append(state.variants.miceVariant ? 1 : 0)
        values.append(state.variants.ordenNachalniku ? 1 : 0)
        values.append(state.variants.medalsCount ? 1 : 0)
        values.append(state.variants.accumulateJobs ? 1 : 0)
        values.append(state.variants.heroOfSovietUnion ? 1 : 0)
        values.append(state.variants.deckType == 36 ? 1 : 0)

        for seat in 0..<4 {
            guard state.players.indices.contains(seat) else {
                values.append(contentsOf: Array(repeating: 0.0, count: 10))
                continue
            }
            let seatPlayer = state.players[seat]
            values.append(Double(seatPlayer.hand.count) / 5)
            values.append(Double(revealedPlotCount(for: seatPlayer)) / 16)
            values.append(Double(hiddenPlotCount(for: seatPlayer)) / 16)
            values.append(Double(seatPlayer.plot.medals + seatPlayer.medals) / 20)
            values.append(seatPlayer.hasWonTrickThisYear ? 1 : 0)
            values.append(seatPlayer.brigadeLeader ? 1 : 0)
            values.append(Double(visibleScore(for: seat, state: state)) / 100)
            values.append(Double(gameFinalScore(for: seat, state: state)) / 100)
            values.append(Double(seatPlayer.hand.map(\.value).max() ?? 0) / 13)
            values.append(Double(seatPlayer.hand.map(\.value).min() ?? 0) / 13)
        }

        for target in Suit.allCases {
            values.append(Double(state.workHours[target, default: 0]) / 40)
            values.append(Double(max(0, 40 - state.workHours[target, default: 0])) / 40)
            values.append(Double(state.revealedJobs[target]?.value ?? 0) / 5)
            values.append(state.claimedJobs.contains(target) ? 1 : 0)
            values.append(Double(player.hand.filter { $0.suit == target }.count) / 5)
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).max() ?? 0) / 13)
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).min() ?? 0) / 13)
            values.append(Double(revealedPlotCount(for: player, suit: target)) / 8)
            values.append(Double(hiddenPlotCount(for: player, suit: target)) / 8)
            values.append(Double(state.players.reduce(0) { $0 + revealedPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.players.reduce(0) { $0 + hiddenPlotCount(for: $1, suit: target) }) / 32)
            values.append(Double(state.currentTrick.filter { $0.card.suit == target }.count + state.lastTrick.filter { $0.card.suit == target }.count) / 8)
        }

        appendTrickFeatures(to: &values, plays: state.currentTrick)
        appendTrickFeatures(to: &values, plays: state.lastTrick)
        precondition(values.count == inputSize, "Kolkhoz AI v4 feature size changed")
        return values
    }

    static func appendV2Features(
        to values: inout [Double],
        state: KolkhozState,
        playerID: Int,
        suit: Suit?,
        card: Card?,
        handCard: Card?,
        leadSuit: Suit?
    ) {
        let player = state.players[playerID]
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target }.count) / 5)
        }
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target && $0.value >= 11 }.count) / 5)
        }
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).max() ?? 0) / 13)
        }
        for target in Suit.allCases {
            values.append(Double(player.hand.filter { $0.suit == target }.map(\.value).min() ?? 0) / 13)
        }
        for target in Suit.allCases {
            values.append(Double(player.plot.revealed.filter { $0.suit == target }.count) / 8)
        }
        for target in Suit.allCases {
            values.append(Double(player.plot.hidden.filter { $0.suit == target }.count) / 8)
        }
        for target in Suit.allCases {
            values.append(Double(state.revealedJobs[target]?.value ?? 0) / 5)
        }
        for target in Suit.allCases {
            values.append(Double(state.workHours[target, default: 0]) / 40)
        }
        for target in Suit.allCases {
            values.append(state.claimedJobs.contains(target) ? 1 : 0)
        }
        values.append(contentsOf: oneHot(handCard.map { suitIndex($0.suit) } ?? -1, count: 4))
        values.append(Double(handCard?.value ?? 0) / 13)
        values.append(card?.suit == state.trump ? 1 : 0)
        values.append(card?.suit == leadSuit ? 1 : 0)
        values.append(Double(state.players[playerID].plot.medals + state.players[playerID].medals) / 20)
        values.append(Double(state.currentTrick.count) / 4)
        let ownScore = finalScore(for: playerID, state: state)
        let bestOpponent = state.players
            .filter { $0.id != playerID }
            .map { finalScore(for: $0.id, state: state) }
            .max() ?? 0
        values.append(Double(ownScore) / 100)
        values.append(Double(bestOpponent) / 100)
        values.append(Double(ownScore - bestOpponent) / 100)
        values.append(suit == state.trump ? 1 : 0)
    }

    static func appendV3Features(to values: inout [Double], state: KolkhozState, playerID: Int) {
        values.append(contentsOf: oneHot(playerID, count: 4))
        values.append(contentsOf: oneHot((playerID - state.lead + 4) % 4, count: 4))
        values.append(contentsOf: oneHot((playerID - state.trumpSelector + 4) % 4, count: 4))
    }

    static func appendTrickFeatures(to values: inout [Double], plays: [TrickPlay]) {
        for slot in 0..<4 {
            guard plays.indices.contains(slot) else {
                values.append(contentsOf: Array(repeating: 0.0, count: 7))
                continue
            }
            let play = plays[slot]
            values.append(1)
            values.append(Double(play.playerID) / 3)
            values.append(contentsOf: oneHot(suitIndex(play.card.suit), count: 4))
            values.append(Double(play.card.value) / 13)
        }
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

    static func finalScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = visibleScore(for: playerID, state: state)
        score += player.plot.hidden.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.hidden.reduce(0) { $0 + $1.value }
        }
        return score
    }

    static func visibleScore(for playerID: Int, state: KolkhozState) -> Int {
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

    static func gameFinalScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        return visibleScore(for: playerID, state: state) + player.plot.hidden.reduce(0) { $0 + $1.value }
    }

    static func knownScore(for playerID: Int, state: KolkhozState) -> Int {
        guard state.players.indices.contains(playerID) else { return 0 }
        let player = state.players[playerID]
        var score = visibleScore(for: playerID, state: state)
        score += player.plot.hidden.reduce(0) { $0 + $1.value }
        score += player.plot.stacks.reduce(0) { total, stack in
            total + stack.hidden.reduce(0) { $0 + $1.value }
        }
        return score
    }

    static func revealedPlotCount(for player: PlayerState, suit: Suit? = nil) -> Int {
        let cards = player.plot.revealed + player.plot.stacks.flatMap(\.revealed)
        guard let suit else { return cards.count }
        return cards.filter { $0.suit == suit }.count
    }

    static func hiddenPlotCount(for player: PlayerState, suit: Suit? = nil) -> Int {
        let cards = player.plot.hidden + player.plot.stacks.flatMap(\.hidden)
        guard let suit else { return cards.count }
        return cards.filter { $0.suit == suit }.count
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
