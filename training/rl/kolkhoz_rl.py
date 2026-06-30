#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import random
from dataclasses import dataclass, field
from pathlib import Path

import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.distributions import Categorical

SUITS = range(4)
WHEAT, SUNFLOWER, POTATO, BEET = SUITS
MAX_YEARS = 5
WORK_THRESHOLD = 40
FEATURE_VERSION = 1
INPUT_SIZE = 34


Card = tuple[int, int]


@dataclass
class Player:
    hand: list[Card] = field(default_factory=list)
    revealed: list[Card] = field(default_factory=list)
    hidden: list[Card] = field(default_factory=list)
    medals: int = 0
    won_this_year: bool = False


@dataclass
class Game:
    rng: random.Random
    players: list[Player] = field(default_factory=lambda: [Player() for _ in range(4)])
    year: int = 1
    lead: int = 0
    current_player: int = 0
    trump_selector: int = 0
    trump: int | None = None
    job_piles: dict[int, list[Card]] = field(default_factory=dict)
    revealed_jobs: dict[int, Card | None] = field(default_factory=dict)
    work_hours: dict[int, int] = field(default_factory=lambda: {s: 0 for s in SUITS})
    current_trick: list[tuple[int, Card]] = field(default_factory=list)
    last_trick: list[tuple[int, Card]] = field(default_factory=list)
    last_winner: int | None = None
    trick_count: int = 0
    exiled: list[Card] = field(default_factory=list)
    game_over: bool = False

    @classmethod
    def new(cls, seed: int) -> Game:
        game = cls(rng=random.Random(seed))
        game.lead = game.rng.randrange(4)
        game.trump_selector = game.rng.randrange(4)
        game.current_player = game.trump_selector
        game.job_piles = {s: [(s, value) for value in range(1, MAX_YEARS + 1)] for s in SUITS}
        for pile in game.job_piles.values():
            game.rng.shuffle(pile)
        game.reveal_jobs()
        game.deal_hands()
        return game

    @property
    def is_famine(self) -> bool:
        return self.year == MAX_YEARS

    def reveal_jobs(self) -> None:
        self.revealed_jobs = {s: self.job_piles[s].pop() if self.job_piles[s] else None for s in SUITS}

    def worker_deck(self) -> list[Card]:
        used = set(self.exiled)
        for player in self.players:
            used.update(player.hand)
            used.update(player.revealed)
            used.update(player.hidden)
        deck = [(s, value) for s in SUITS for value in range(6, 14) if (s, value) not in used]
        self.rng.shuffle(deck)
        return deck

    def deal_hands(self) -> None:
        deck = self.worker_deck()
        cards_per_player = 4 if self.is_famine else 5
        for player in self.players:
            player.hand = []
        for _ in range(cards_per_player):
            for player in self.players:
                if deck:
                    player.hand.append(deck.pop())

    def legal_cards(self, player_id: int) -> list[Card]:
        hand = self.players[player_id].hand
        if not self.current_trick:
            return list(hand)
        lead_suit = self.current_trick[0][1][0]
        follows = [card for card in hand if card[0] == lead_suit]
        return follows or list(hand)

    def play_card(self, player_id: int, card: Card) -> None:
        self.players[player_id].hand.remove(card)
        self.current_trick.append((player_id, card))
        if len(self.current_trick) == 4:
            self.resolve_trick()
        else:
            self.current_player = (player_id + 1) % 4

    def resolve_trick(self) -> None:
        lead_suit = self.current_trick[0][1][0]
        trump_cards = [play for play in self.current_trick if play[1][0] == self.trump]
        candidates = trump_cards or [play for play in self.current_trick if play[1][0] == lead_suit]
        self.last_winner = max(candidates, key=lambda play: play[1][1])[0]
        self.last_trick = self.current_trick
        self.current_trick = []
        self.trick_count += 1
        self.lead = self.last_winner
        self.current_player = self.last_winner
        self.players[self.last_winner].won_this_year = True
        self.players[self.last_winner].medals += 1

    def assign_trick(self, suit: int) -> None:
        for _, card in self.last_trick:
            self.work_hours[suit] += card[1]
        if self.work_hours[suit] >= WORK_THRESHOLD and self.revealed_jobs.get(suit) is not None:
            self.players[self.last_winner or 0].revealed.append(self.revealed_jobs[suit])
            self.revealed_jobs[suit] = None

    def year_complete(self) -> bool:
        expected = 3 if self.is_famine else 4
        return (
            self.trick_count >= expected
            or any(not player.hand for player in self.players)
            or all(len(player.hand) == 1 for player in self.players)
        )

    def end_year(self) -> None:
        for player in self.players:
            player.hidden.extend(player.hand)
            player.hand = []
        self.requisition()
        for suit, job in self.revealed_jobs.items():
            if job is not None:
                self.exiled.append(job)
        self.year += 1
        if self.year > MAX_YEARS:
            self.game_over = True
            return

        self.trick_count = 0
        self.current_trick = []
        self.last_trick = []
        self.last_winner = None
        self.trump = None
        self.work_hours = {s: 0 for s in SUITS}
        for player in self.players:
            player.won_this_year = False
        self.reveal_jobs()
        self.trump_selector = (self.trump_selector + 1) % 4
        self.current_player = self.trump_selector
        self.deal_hands()

    def requisition(self) -> None:
        for suit in SUITS:
            if self.work_hours[suit] >= WORK_THRESHOLD:
                continue
            for player in self.players:
                if not player.won_this_year:
                    continue
                matching = [card for card in player.hidden if card[0] == suit]
                if not matching:
                    continue
                revealed = max(matching, key=lambda card: card[1])
                player.hidden.remove(revealed)
                self.exiled.append(revealed)

    def final_scores(self) -> list[int]:
        return [sum(card[1] for card in player.revealed + player.hidden) for player in self.players]


class PolicyNet(nn.Module):
    def __init__(self, hidden_size: int = 64):
        super().__init__()
        self.fc1 = nn.Linear(INPUT_SIZE, hidden_size)
        self.fc2 = nn.Linear(hidden_size, 1)

    def forward(self, features: torch.Tensor) -> torch.Tensor:
        return self.fc2(F.relu(self.fc1(features))).squeeze(-1)

    def export_json(self, path: Path) -> None:
        path.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "version": 1,
            "feature_version": FEATURE_VERSION,
            "input_size": INPUT_SIZE,
            "hidden_size": self.fc1.out_features,
            "w1": self.fc1.weight.detach().cpu().flatten().tolist(),
            "b1": self.fc1.bias.detach().cpu().tolist(),
            "w2": self.fc2.weight.detach().cpu().flatten().tolist(),
            "b2": float(self.fc2.bias.detach().cpu()[0]),
        }
        path.write_text(json.dumps(payload, indent=2) + "\n")

    @classmethod
    def from_json(cls, path: Path) -> PolicyNet:
        payload = json.loads(path.read_text())
        model = cls(hidden_size=payload["hidden_size"])
        with torch.no_grad():
            model.fc1.weight.copy_(torch.tensor(payload["w1"]).view(payload["hidden_size"], payload["input_size"]))
            model.fc1.bias.copy_(torch.tensor(payload["b1"]))
            model.fc2.weight.copy_(torch.tensor(payload["w2"]).view(1, payload["hidden_size"]))
            model.fc2.bias.copy_(torch.tensor([payload["b2"]]))
        return model


def one_hot(selected: int | None, count: int) -> list[float]:
    return [1.0 if selected == index else 0.0 for index in range(count)]


def features(
    game: Game,
    player_id: int,
    action: int,
    suit: int,
    card: Card | None = None,
    zone: str | None = None,
    swap_delta: float = 0.0,
) -> list[float]:
    player = game.players[player_id]
    lead_suit = game.current_trick[0][1][0] if game.current_trick else None
    trick_work = sum(card_value for _, (_, card_value) in game.last_trick)
    current_work = game.work_hours[suit]
    after_work = current_work + trick_work
    plot_cards = player.hidden + player.revealed
    revealed_job = game.revealed_jobs.get(suit)

    values = []
    values.extend(one_hot(action, 4))
    values.extend(one_hot(suit, 4))
    values.extend(one_hot(card[0] if card else None, 4))
    values.append((card[1] if card else 0) / 13)
    values.append(game.year / 5)
    values.append(game.trick_count / 4)
    values.append(len(player.hand) / 5)
    values.append(1.0 if player.won_this_year else 0.0)
    values.extend(one_hot(lead_suit, 4))
    values.extend(one_hot(game.trump, 4))
    values.append(current_work / 40)
    values.append(1.0 if after_work >= WORK_THRESHOLD else 0.0)
    values.append(sum(1 for plot_card in plot_cards if plot_card[0] == suit) / 8)
    values.append(sum(1 for plot_card in player.hidden if plot_card[0] == suit) / 8)
    values.append((revealed_job[1] if revealed_job else 0) / 5)
    values.append(1.0 if card and would_currently_win(game, card) else 0.0)
    values.append(1.0 if zone == "hidden" else 0.0)
    values.append(1.0 if zone == "revealed" else 0.0)
    values.append(swap_delta)
    assert len(values) == INPUT_SIZE
    return values


def would_currently_win(game: Game, card: Card) -> bool:
    if not game.current_trick:
        return False
    candidate = (game.current_player, card)
    plays = game.current_trick + [candidate]
    lead_suit = game.current_trick[0][1][0]
    trump_cards = [play for play in plays if play[1][0] == game.trump]
    contenders = trump_cards or [play for play in plays if play[1][0] == lead_suit]
    return max(contenders, key=lambda play: play[1][1]) == candidate


def choose_policy(
    model: PolicyNet,
    candidates: list[tuple[object, list[float]]],
    train: bool,
    fixed_pass_logit: bool = False,
) -> tuple[object, torch.Tensor | None, torch.Tensor | None]:
    if fixed_pass_logit and len(candidates) == 1:
        return candidates[0][0], None, None

    feature_rows = [row for _, row in candidates if row]
    logits = model(torch.tensor(feature_rows, dtype=torch.float32))
    if fixed_pass_logit:
        logits = torch.cat([torch.zeros(1), logits])

    if train:
        dist = Categorical(logits=logits)
        index = int(dist.sample())
        return candidates[index][0], dist.log_prob(torch.tensor(index)), dist.entropy()

    index = int(torch.argmax(logits).item())
    return candidates[index][0], None, None


def choose_heuristic(game: Game, player_id: int, kind: str):
    player = game.players[player_id]
    if kind == "trump":
        return max(SUITS, key=lambda suit: sum(4 + (8 if card[1] >= 11 else 0) for card in player.hand if card[0] == suit))
    if kind == "swap":
        if not player.hidden and not player.revealed:
            return None
        hand_card = min(player.hand, key=lambda card: card[1])
        plot_options = [(card, "hidden") for card in player.hidden] + [(card, "revealed") for card in player.revealed]
        plot_card, zone = max(plot_options, key=lambda item: item[0][1])
        return (hand_card, plot_card, zone) if plot_card[1] > hand_card[1] + 1 else None
    if kind == "play":
        legal = game.legal_cards(player_id)
        wants_win = not player.won_this_year and game.trick_count >= 2
        return max(legal, key=lambda card: card[1]) if wants_win else min(legal, key=lambda card: card[1])
    if kind == "assign":
        legal_suits = list({card[0] for _, card in game.last_trick})
        return max(
            legal_suits,
            key=lambda suit: game.work_hours[suit]
            + 12 * sum(1 for card in player.hidden + player.revealed if card[0] == suit)
            - max(0, WORK_THRESHOLD - game.work_hours[suit]) // 2,
        )
    raise ValueError(kind)


def play_episode(model: PolicyNet | None, seed: int, train: bool) -> tuple[list[int], list[list[torch.Tensor]], list[torch.Tensor]]:
    game = Game.new(seed)
    log_probs: list[list[torch.Tensor]] = [[] for _ in range(4)]
    entropies: list[torch.Tensor] = []

    while not game.game_over:
        if game.is_famine:
            game.trump = None
        elif model is None:
            game.trump = choose_heuristic(game, game.current_player, "trump")
        else:
            candidates = [(suit, features(game, game.current_player, 0, suit)) for suit in SUITS]
            choice, log_prob, entropy = choose_policy(model, candidates, train)
            game.trump = int(choice)
            if log_prob is not None:
                log_probs[game.current_player].append(log_prob)
                entropies.append(entropy)

        if game.year > 1:
            for player_id, player in enumerate(game.players):
                if model is None:
                    choice = choose_heuristic(game, player_id, "swap")
                else:
                    candidates: list[tuple[object, list[float]]] = [(None, [])]
                    for hand_card in player.hand:
                        for plot_card in player.hidden:
                            candidates.append(((hand_card, plot_card, "hidden"), features(game, player_id, 1, plot_card[0], plot_card, "hidden", (plot_card[1] - hand_card[1]) / 13)))
                        for plot_card in player.revealed:
                            candidates.append(((hand_card, plot_card, "revealed"), features(game, player_id, 1, plot_card[0], plot_card, "revealed", (plot_card[1] - hand_card[1]) / 13)))
                    choice, log_prob, entropy = choose_policy(model, candidates, train, fixed_pass_logit=True)
                    if log_prob is not None:
                        log_probs[player_id].append(log_prob)
                        entropies.append(entropy)
                if choice is None:
                    continue
                hand_card, plot_card, zone = choice
                player.hand[player.hand.index(hand_card)] = plot_card
                if zone == "hidden":
                    player.hidden[player.hidden.index(plot_card)] = hand_card
                else:
                    player.revealed[player.revealed.index(plot_card)] = hand_card

        while not game.year_complete():
            game.current_player = game.lead
            while game.current_trick or game.current_player == game.lead:
                player_id = game.current_player
                if model is None:
                    card = choose_heuristic(game, player_id, "play")
                else:
                    legal = game.legal_cards(player_id)
                    candidates = [(card, features(game, player_id, 2, card[0], card)) for card in legal]
                    card, log_prob, entropy = choose_policy(model, candidates, train)
                    if log_prob is not None:
                        log_probs[player_id].append(log_prob)
                        entropies.append(entropy)
                game.play_card(player_id, card)
                if not game.current_trick:
                    break

            winner = game.last_winner or 0
            if model is None:
                target = choose_heuristic(game, winner, "assign")
            else:
                legal_suits = list({card[0] for _, card in game.last_trick})
                candidates = [(suit, features(game, winner, 3, suit)) for suit in legal_suits]
                target, log_prob, entropy = choose_policy(model, candidates, train)
                if log_prob is not None:
                    log_probs[winner].append(log_prob)
                    entropies.append(entropy)
            game.assign_trick(int(target))

        game.end_year()

    return game.final_scores(), log_probs, entropies


def train(args: argparse.Namespace) -> None:
    torch.manual_seed(args.seed)
    model = PolicyNet(hidden_size=args.hidden_size)
    optimizer = torch.optim.Adam(model.parameters(), lr=args.lr)
    moving = 0.0

    for episode in range(1, args.episodes + 1):
        scores, log_probs, entropies = play_episode(model, args.seed + episode, train=True)
        mean_score = sum(scores) / len(scores)
        loss = torch.tensor(0.0)
        for player_id, player_log_probs in enumerate(log_probs):
            advantage = scores[player_id] - mean_score
            for log_prob in player_log_probs:
                loss = loss - log_prob * advantage
        if entropies:
            loss = loss - args.entropy * torch.stack(entropies).mean()

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        moving = 0.95 * moving + 0.05 * mean_score if episode > 1 else mean_score
        if episode % args.report_every == 0:
            print(f"episode={episode} mean_score={mean_score:.2f} moving={moving:.2f} loss={float(loss.detach()):.3f}")

    model.export_json(Path(args.output))
    print(f"exported {args.output}")
    evaluate_model(model, args.seed + 100_000, args.eval_games)


def evaluate_model(model: PolicyNet, seed: int, games: int) -> None:
    policy_wins = 0
    heuristic_wins = 0
    policy_margin = 0.0
    for index in range(games):
        policy_scores, _, _ = play_episode(model, seed + index, train=False)
        heuristic_scores, _, _ = play_episode(None, seed + index, train=False)
        policy_wins += int(max(policy_scores) > max(heuristic_scores))
        heuristic_wins += int(max(heuristic_scores) > max(policy_scores))
        policy_margin += max(policy_scores) - max(heuristic_scores)
    print(
        f"eval_games={games} policy_wins={policy_wins} "
        f"heuristic_wins={heuristic_wins} avg_best_score_margin={policy_margin / max(1, games):.2f}"
    )


def evaluate(args: argparse.Namespace) -> None:
    model = PolicyNet.from_json(Path(args.model))
    evaluate_model(model, args.seed, args.games)


def main() -> None:
    parser = argparse.ArgumentParser(description="Train or evaluate the Kolkhoz RL policy.")
    subparsers = parser.add_subparsers(required=True)

    train_parser = subparsers.add_parser("train")
    train_parser.add_argument("--episodes", type=int, default=1000)
    train_parser.add_argument("--hidden-size", type=int, default=64)
    train_parser.add_argument("--lr", type=float, default=0.003)
    train_parser.add_argument("--entropy", type=float, default=0.01)
    train_parser.add_argument("--seed", type=int, default=7)
    train_parser.add_argument("--report-every", type=int, default=100)
    train_parser.add_argument("--eval-games", type=int, default=100)
    train_parser.add_argument("--output", default="ios/KolkhozSwiftUI/Sources/KolkhozCore/Resources/kolkhoz_policy.json")
    train_parser.set_defaults(func=train)

    eval_parser = subparsers.add_parser("eval")
    eval_parser.add_argument("--model", default="ios/KolkhozSwiftUI/Sources/KolkhozCore/Resources/kolkhoz_policy.json")
    eval_parser.add_argument("--games", type=int, default=200)
    eval_parser.add_argument("--seed", type=int, default=50_000)
    eval_parser.set_defaults(func=evaluate)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
