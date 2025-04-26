# app.py
from flask import Flask, render_template, request, redirect, url_for, flash
from engine import GameState, Card
from ai import RandomAI
import random
import uuid

app = Flask(__name__)
app.secret_key = 'MEOWCAT'
GAMES = {}

def read_rules():
    with open('rules.txt', 'r') as file:
        rules = file.read()
    return rules

@app.route('/')
def lobby():
    if not GAMES:
        gid = str(uuid.uuid4())
        g = GameState()
        g.set_trump(random.choice(Card.SUITS))
        GAMES[gid] = g
    else:
        gid = next(iter(GAMES))
    rules = read_rules()
    return render_template('lobby.html', game_id=gid, rules=rules)

@app.route('/game/<game_id>')
def view(game_id):
    g = GAMES[game_id]

    # Move from planning into trick phase and choose a new trump
    if g.phase == 'planning':
        g.set_trump(random.choice(Card.SUITS))
        g.phase = 'trick'

    # Let AIs play until it's the human's turn
    while g.phase == 'trick' and len(g.current_trick) < g.num_players:
        nxt = (g.lead + len(g.current_trick)) % g.num_players
        if nxt == 0:
            break
        g.play_card(nxt, RandomAI(nxt).play(g))

    # After requisition, start next year
    if g.phase == 'requisition':
        g.next_year()
        return redirect(url_for('view', game_id=game_id))

    # Handle assignment phase
    if g.phase == 'assignment':
        return render_template(
            'game.html',
            game=g,
            game_id=game_id,
            suits=Card.SUITS,
            next_player=None
        )

    # Determine whose turn next
    next_player = None
    if g.phase == 'trick' and len(g.current_trick) < g.num_players:
        next_player = (g.lead + len(g.current_trick)) % g.num_players

    return render_template(
        'game.html',
        game=g,
        game_id=game_id,
        suits=Card.SUITS,
        next_player=next_player
    )

@app.route('/play/<game_id>/<int:ci>')
def play(game_id, ci):
    game = GAMES[game_id]

    if game.lead != 0:
        lead_suit = game.current_trick[0][1].suit
        print(lead_suit, game.players[0].hand[ci].suit)
        can_follow = False

        for c in game.players[0].hand:
            if c.suit == lead_suit:
                can_follow = True

        if can_follow and game.players[0].hand[ci].suit != lead_suit:
            flash('Please follow suit')
            return redirect(url_for('view', game_id=game_id))

    game.play_card(0, ci)
    return redirect(url_for('view', game_id=game_id))

@app.route('/assign/<game_id>', methods=['POST'])
def assign(game_id):
    g = GAMES[game_id]
    mapping = {}
    for i, (pid, card) in enumerate(g.last_trick):
        if card.suit == g.trump:
            mapping[card] = request.form[f'assign_{i}']
        else:
            mapping[card] = card.suit

    g.apply_assignments(mapping)
    return redirect(url_for('view', game_id=game_id))

if __name__ == '__main__':
    app.run(debug=True)