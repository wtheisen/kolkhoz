import random
from engine import Card

class RandomAI:
    def __init__(self, player_idx):
        self.player_idx = player_idx

    def play(self, game_state):
        hand = game_state.players[self.player_idx].hand
        if game_state.current_trick:
            lead = game_state.current_trick[0][1].suit
            candidates = [i for i,c in enumerate(hand) if c.suit == lead]
            if candidates:
                return random.choice(candidates)
        return random.randrange(len(hand))

    def assign_trick(self, game_state):
        mapping = {}
        valid_jobs = list(set([card.suit for _, card in game_state.last_trick]))

        for pid, card in game_state.last_trick:
            mapping[card] = random.choice(valid_jobs)

        return mapping
