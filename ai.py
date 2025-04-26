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
        for pid, card in game_state.last_trick:
            if card.suit != game_state.trump:
                mapping[card] = card.suit
            else:
                mapping[card] = random.choice(Card.SUITS)
        return mapping
