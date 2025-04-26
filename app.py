# app.py
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
import pickle
from engine import GameState, Card
from ai import RandomAI
import random

app = Flask(__name__)
app.secret_key = 'MEOWCAT'

def read_rules():
    with open('rules.txt', 'r') as file:
        rules = file.read()
    return rules

@app.route('/')
def lobby():
    g = GameState()
    g.set_trump(random.choice(Card.SUITS))
    rules = read_rules()

    session['g'] = pickle.dumps(g)
    return render_template('lobby.html', rules=rules)

@app.route('/game')
def view():
    g = pickle.loads(session['g'])

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
        session['g'] = pickle.dumps(g)
        return redirect(url_for('view', game=g.to_dict()))

    # Handle assignment phase
    if g.phase == 'assignment':
        session['g'] = pickle.dumps(g)
        return render_template(
            'game.html',
            game=g.to_dict(),
            suits=Card.SUITS,
            next_player=None
        )

    # Determine whose turn next
    next_player = None
    if g.phase == 'trick' and len(g.current_trick) < g.num_players:
        next_player = (g.lead + len(g.current_trick)) % g.num_players

    session['g'] = pickle.dumps(g)
    return render_template('game.html', game=g.to_dict(), suits=Card.SUITS, next_player=next_player)

@app.route('/play/<int:ci>')
def play(ci):
    g = pickle.loads(session['g'])

    if g.lead != 0:
        lead_suit = g.current_trick[0][1].suit
        print(lead_suit, g.players[0].hand[ci].suit)
        can_follow = False

        for c in g.players[0].hand:
            if c.suit == lead_suit:
                can_follow = True

        if can_follow and g.players[0].hand[ci].suit != lead_suit:
            flash('Please follow suit')
            return redirect(url_for('view'))

    g.play_card(0, ci)
    session['g'] = pickle.dumps(g)
    return redirect(url_for('view'))

@app.route('/assign', methods=['POST'])
def assign():
    g = pickle.loads(session['g'])
    mapping = {}
    for i, (pid, card) in enumerate(g.last_trick):
        if card.suit == g.trump:
            mapping[card] = request.form[f'assign_{i}']
        else:
            mapping[card] = card.suit

    g.apply_assignments(mapping)
    session['g'] = pickle.dumps(g)
    return redirect(url_for('view'))

if __name__ == '__main__':
    app.run(debug=True)