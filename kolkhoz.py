# app.py
from flask import Flask, render_template, request, redirect, url_for, flash, session, jsonify
import pickle
from engine import GameState, Card
from ai import RandomAI
import random
from functools import wraps

app = Flask(__name__)
app.secret_key = 'MEOWCAT'
app.config['SESSION_COOKIE_SAMESITE'] = 'Lax'
app.config['SESSION_COOKIE_SECURE'] = False

def read_rules():
    with open('rules.txt', 'r') as file:
        rules = file.read()
    return rules

def require_session(f):
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'g' not in session:
            return redirect(url_for('lobby'))
        return f(*args, **kwargs)
    return decorated_function

@app.route('/')
def lobby():
    g = GameState()
    g.set_trump(random.choice(Card.SUITS))
    rules = read_rules()

    session['g'] = pickle.dumps(g)
    return render_template('lobby.html', rules=rules)

@app.route('/game')
@require_session
def view():
    g = pickle.loads(session['g'])

    # Move from planning into trick phase and choose a new trump
    if g.phase == 'planning':
        g.set_trump(random.choice(Card.SUITS))
        g.phase = 'trick'

    # DO NOT play AI cards here!

    # After requisition, start next year
    if g.phase == 'requisition':
        g.next_year()
        session['g'] = pickle.dumps(g)
        return redirect(url_for('view'))

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
@require_session
def play(ci):
    g = pickle.loads(session['g'])

    # Only check for follow-suit if a card has already been played
    if g.lead != 0 and g.current_trick:
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
@require_session
def assign():
    g = pickle.loads(session['g'])
    mapping = {}
    valid_jobs = set([card.suit for _, card in g.last_trick])

    for i, (pid, card) in enumerate(g.last_trick):
        mapping[card] = request.form[f'assign_{i}']

    g.apply_assignments(mapping)
    session['g'] = pickle.dumps(g)
    return redirect(url_for('view'))

@app.route('/ai_play', methods=['GET'])
@require_session
def ai_play():
    g = pickle.loads(session['g'])
    # Find next AI player
    if g.phase == 'trick' and len(g.current_trick) < g.num_players:
        nxt = (g.lead + len(g.current_trick)) % g.num_players
        if nxt != 0:
            card_idx = RandomAI(nxt).play(g)
            g.play_card(nxt, card_idx)
            session['g'] = pickle.dumps(g)
            # Only return a card if there is one to return
            if g.current_trick:
                last_pid, last_card = g.current_trick[-1]
            elif g.last_trick:
                last_pid, last_card = g.last_trick[-1]
            else:
                # No card to animate, just finish
                return jsonify({'done': True})
            return jsonify({
                'player': nxt,
                'card': last_card.to_dict(),
                'current_trick': [(pid, c.to_dict()) for pid, c in g.current_trick]
            })
    return jsonify({'done': True})

if __name__ == '__main__':
    app.run(debug=True)