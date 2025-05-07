import json
import random
from collections import defaultdict

class Card:
    SUITS = ['Hearts', 'Diamonds', 'Clubs', 'Spades']
    VALUES = list(range(6, 14))

    def __init__(self, suit, value): 
        self.suit, self.value = suit, value

    def __repr__(self):
        face = {11:'J',12:'Q',13:'K'}.get(self.value, str(self.value))
        return f"{face} of {self.suit}"

    def __lt__(self, other):
        return self.value < other.value

    # --- serialization ---
    def to_dict(self):
        return {
            'suit': self.suit,
            'value': self.value
        }

    @classmethod
    def from_dict(cls, d):
        return cls(d['suit'], d['value'])


class Player:
    def __init__(self, idx, is_human=False):
        self.idx = idx
        self.is_human = is_human
        self.hand = []
        self.plot = defaultdict(list)
        self.brigade_leader = False

    # --- serialization ---
    def to_dict(self):
        return {
            'idx': self.idx,
            'is_human': self.is_human,
            'hand': [c.to_dict() for c in self.hand],
            'plot': {phase: [c.to_dict() for c in cards] for phase, cards in self.plot.items()},
            'brigade_leader': self.brigade_leader
        }

    @classmethod
    def from_dict(cls, d):
        p = cls(d['idx'], d['is_human'])
        p.hand = [Card.from_dict(c) for c in d['hand']]
        p.plot = defaultdict(list,
                             {phase: [Card.from_dict(c) for c in cards]
                              for phase, cards in d['plot'].items()})
        p.brigade_leader = d.get('brigade_leader', False)
        return p

class GameState:
    THRESHOLD = 40
    MAX_YEARS = 5
    def __init__(self, num_players=4):
        self.num_players=num_players
        self.players=[Player(i,i==0) for i in range(num_players)]
        self.lead,self.year,self.trump=random.randint(0, num_players - 1),1,None
        self.job_piles,self.revealed_jobs={},{}
        self.claimed_jobs=set(); 
        self.work_hours = {}
        for suit in ['Hearts', 'Diamonds', 'Clubs', 'Spades']:
            self.work_hours[suit] = 0
        self.job_buckets=defaultdict(list)
        self.current_trick=[]; self.last_trick=[]; self.last_winner=None
        self.trick_history=[]; self.requisition_log=defaultdict(list)
        self.phase='planning'; self.trick_count=0
        self.exiled = set()
        self._prepare_job_piles(); self._reveal_jobs()
        self._prepare_workers_deck(); self._deal_hands()


    def _prepare_job_piles(self):
        for s in Card.SUITS:
            pile = [Card(s,v) for v in range(1, GameState.MAX_YEARS+1)]
            random.shuffle(pile)
            self.job_piles[s] = pile

    def _reveal_jobs(self):
        self.claimed_jobs.clear()
        self.job_buckets.clear()
        self.requisition_log.clear()

        for s, pile in self.job_piles.items(): 
            self.revealed_jobs[s] = pile.pop()

    def _prepare_workers_deck(self):
        all_cards = [Card(s,v) for s in Card.SUITS for v in Card.VALUES]

        used = {c for p in self.players for c in p.plot['revealed']}
        used |= {c for p in self.players for c in p.plot['hidden']}
        used |= {c for c in self.exiled}

        self.workers_deck = []
        for c in all_cards:
            add = True
            for u in used:
                if c.suit == u.suit and c.value == u.value:
                    add = False
                    break

            if add:
                self.workers_deck.append(c)

        print(len(self.workers_deck))
        random.shuffle(self.workers_deck)

    def _deal_hands(self):
        for _ in range(5):
            for p in self.players:
                if self.workers_deck: p.hand.append(self.workers_deck.pop())

    def set_trump(self, suit=None): 
        if suit:
            self.trump=suit
        else:
            self.trump = random.choice(['Hearts', 'Diamonds', 'Clubs', 'Spades'])

    def play_card(self, pid, idx):
        if not self.current_trick and self.last_trick: self.last_trick.clear(); self.last_winner=None
        card=self.players[pid].hand.pop(idx)
        self.current_trick.append((pid, card))
        if len(self.current_trick)==self.num_players: self._resolve_trick()

    def _resolve_trick(self):
       # 1) Determine the lead suit
        lead_suit = self.current_trick[0][1].suit

        # 2) Find the winner: trump beats lead, highest value among them wins
        trump_cards = [(pid, c) for pid, c in self.current_trick if c.suit == self.trump]
        if trump_cards:
            best_pid, best_card = max(trump_cards, key=lambda x: x[1].value)
        else:
            lead_cards = [(pid, c) for pid, c in self.current_trick if c.suit == lead_suit]
            best_pid, best_card = max(lead_cards, key=lambda x: x[1].value)

        # 3) Record winner and clear the current trick
        self.last_winner = best_pid
        self.last_trick = list(self.current_trick)
        self.current_trick.clear()
        self.trick_count += 1
        self.lead = self.last_winner
        self.players[best_pid].brigade_leader = True

        # 4) Assign each card to its job bucket AND update work_hours
        if self.players[self.last_winner].is_human:
            self.phase = 'assignment'
            return
        else:
            from ai import RandomAI
            mapping = {}

            for pid, card in self.last_trick:
                if card.suit == self.trump:
                    assigned = card.suit
                else:
                    assigned = RandomAI(self.last_winner).assign_trick(self)[card]
                mapping[card] = assigned

        self.apply_assignments(mapping)

    def perform_requisition(self):
        # P'yanitsa and Partiynyy effects
        # after requisition for a job 'suit', with details list of messages
        self.trick_history.append({
            'type': 'jobs',
            'year': self.year,
            'jobs': self.work_hours.copy(),  # e.g. ['P0 sent 6♥', 'P2 sent 8♣']
        })

        # after requisition for a job 'suit', with details list of messages
        self.trick_history.append({
            'type': 'requisition',
            'year': self.year,
            'requisitions': [],
        })

        for suit, bucket in self.job_buckets.items():
            if self.work_hours[suit] < GameState.THRESHOLD:
                # skip if P'yanitsa(J) present
                drunkard = False
                for c in bucket:
                    if c.value == 11 and c.suit == self.trump:
                        self.trick_history[-1]['requisitions'].append(f"Пьяница отправить на Север")
                        self.exiled.add(c)
                        drunkard = True

                    if drunkard:
                        break

                if drunkard:
                    continue

                informator = False
                for c in bucket:    
                    if c.value == 12 and c.suit == self.trump:
                        informator = True

                for p in self.players:
                    if p.brigade_leader or informator:
                        for c in p.plot['hidden']:
                            if c.suit == suit:
                                p.plot['revealed'].append(c)
                                p.plot['hidden'].remove(c)
                        # filter matching suit
                        suit_cards = sorted([c for c in p.plot['revealed'] if c.suit == suit], reverse=True)
                        if not suit_cards: continue

                        # remove highest
                        card = suit_cards[0]
                        p.plot['revealed'].remove(card)
                        self.exiled.add(card)
                        self.trick_history[-1]['requisitions'].append(f"Player {p.idx} отправить на Север {card}")

                        # if King(trump) present remove second
                        if any(c.value==13 and c.suit==self.trump for c in bucket) and len(suit_cards)>1:
                            card2 = suit_cards[1]
                            p.plot['revealed'].remove(card2)
                            self.exiled.add(card2)
                            self.trick_history[-1]['requisitions'].append(f"Партийный чиновник: Player {p.idx} отправить на Север {card2}")

    def next_year(self):
        if self.year >= GameState.MAX_YEARS: 
            self.phase='game_over' 
            return

        self.year+=1 
        self.phase='planning' 
        self.trick_count=0 
        for suit in ['Hearts', 'Diamonds', 'Clubs', 'Spades']:
            self.work_hours[suit] = 0
        self._reveal_jobs() 
        self._prepare_workers_deck()

        for p in self.players: 
            p.hand.clear()
            p.brigade_leader = False

        self._deal_hands() 
        self.lead = random.randint(0, self.num_players - 1)
        self.set_trump()

    @property
    def scores(self): 
        return [sum(c.value for c in p.plot['revealed']) for p in self.players]

    @property
    def final_scores(self): 
        return [sum(c.value for c in p.plot['hidden']) + sum(c.value for c in p.plot['revealed']) for p in self.players]

    def apply_assignments(self, mapping):
        for card, assigned_suit in mapping.items():
            self.job_buckets[assigned_suit].append(card)

            if card.value == 11 and card.suit == self.trump:
                continue

            self.work_hours[assigned_suit] += card.value

        # Check for any new completed jobs (threshold reached)
        for suit, hours in self.work_hours.items():
            if suit not in self.claimed_jobs and hours >= GameState.THRESHOLD:
                self.players[self.last_winner].plot['revealed'].append(self.revealed_jobs[suit])
                self.claimed_jobs.add(suit)

        # Log this trick into history
        self.trick_history.append({
            'type': 'trick',
            'year': self.year,
            'plays': list(self.last_trick),
            'winner': self.last_winner,
        })

        # Clean up and either continue or trigger requisition
        self.last_trick.clear()
        self.last_winner = None
        self.phase = 'trick'

        tricks_needed = 4
        if self.year == GameState.MAX_YEARS:
            tricks_needed = 3

        if self.trick_count == tricks_needed: 
            for p in self.players:
                p.plot['hidden'].append(p.hand[0])
            self.perform_requisition()
            self.phase = 'requisition'

    # --- serialization ---
    def to_dict(self):
        return {
            'num_players': self.num_players,
            'players': [p.to_dict() for p in self.players],
            'lead': self.lead,
            'year': self.year,
            'trump': self.trump if self.trump else None,
            'job_piles': {
                suit: [c.to_dict() for c in cards]
                for suit, cards in self.job_piles.items()
            },
            'revealed_jobs': {
                pid: job.to_dict()
                for pid, job in self.revealed_jobs.items()
            },
            'claimed_jobs': list(self.claimed_jobs),
            'work_hours': self.work_hours,
            'job_buckets': {
                suit: [c.to_dict() for c in cards]
                for suit, cards in self.job_buckets.items()
            },
            'current_trick': [(pid_c[0], pid_c[1].to_dict()) for pid_c in self.current_trick],
            'last_trick': [(pid_c[0], pid_c[1].to_dict()) for pid_c in self.last_trick],
            'last_winner': self.last_winner,
            'trick_history': [
                {
                    'type': e['type'],
                    'year': e.get('year'),
                    'winner': e.get('winner'),
                    'plays': [(pid_c[0], pid_c[1].to_dict()) for pid_c in e.get('plays', [])],
                    'jobs': e.get('jobs', None),
                    'requisitions': e.get('requisitions', None)
                    # assignments as list of [Card, suit]
                }
                for e in self.trick_history
            ],
            'phase': self.phase,
            'trick_count': self.trick_count,
            'exiled': list(self.exiled),
            'THRESHOLD': 40,
            'scores': self.scores,
            'final_scores': self.final_scores
        }
