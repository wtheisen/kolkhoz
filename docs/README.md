# Kolkhoz (Колхоз) - Card Game

A pure client-side implementation of the Russian trick-taking card game Kolkhoz, playable entirely in the browser with no backend required.

## 🎮 Play the Game

**Live Demo:** Host this on GitHub Pages or any static hosting service.

**Local Testing:**
```bash
# From the kolkhoz directory
python3 -m http.server 8000 --directory docs

# Or with Node.js
npx http-server docs -p 8000

# Then visit http://localhost:8000
```

## 📖 About the Game

Kolkhoz is a trick-taking card game set during a Soviet Five-Year Plan (Пятилетка). Players compete as brigade leaders managing agricultural work across 5 years, trying to complete jobs and collect valuable cards while avoiding having their workers sent to the ГУЛАГ (gulag).

**Game Features:**
- 4 players: 1 human + 3 AI opponents
- 5-year campaign with unique mechanics each year
- Trump suits and follow-suit rules
- Special cards with powerful effects (Drunkard, Informant, Party Official)
- Requisition phase where failed jobs result in worker exile
- Strategic job assignment and plot building

## 🏗️ Architecture

This is a complete migration from Flask to pure client-side JavaScript:

- **No backend required** - All game logic runs in the browser
- **localStorage persistence** - Games save automatically
- **ES6 modules** - Modern JavaScript with clean imports
- **Zero dependencies** - Pure vanilla JavaScript
- **Responsive design** - Works on desktop and mobile

### File Structure

```
docs/
├── index.html              # Lobby page
├── game.html               # Game interface
├── assets/
│   ├── cards/              # 62 SVG card images
│   └── style.css           # Game styling
└── js/
    ├── core/               # Game engine
    │   ├── constants.js
    │   ├── Card.js
    │   ├── Player.js
    │   └── GameState.js    # Core game logic
    ├── ai/                 # AI opponents
    │   ├── AIPlayer.js
    │   └── RandomAI.js
    ├── ui/                 # User interface
    │   ├── GameRenderer.js
    │   ├── CardAnimator.js
    │   └── NotificationManager.js
    ├── storage/            # Persistence
    │   └── GameStorage.js
    ├── controller.js       # Game flow orchestration
    ├── lobby.js            # Lobby entry point
    └── main.js             # Game entry point
```

## 🎯 How to Play

1. **Start Game** - Click "Start Game" on the lobby page
2. **Play Cards** - Drag and drop cards to the trick area
3. **Follow Suit** - Must play the lead suit if you have it
4. **Win Tricks** - Highest trump or highest lead suit wins
5. **Assign Workers** - Assign won cards to job piles
6. **Complete Jobs** - Reach 40 work hours to claim a job card
7. **Avoid Requisition** - Failed jobs result in worker exile
8. **Build Your Plot** - Collect cards to maximize your final score

### Special Cards (Trump Suit Only)

- **Jack (Пьяница - Drunkard)** - Contributes 0 hours, gets exiled instead of your cards
- **Queen (Информатор - Informant)** - Reveals all hidden plots during requisition
- **King (Партийный чиновник - Party Official)** - Exiles 2 cards instead of 1

## 🚀 Deployment to GitHub Pages

1. **Commit the docs folder:**
   ```bash
   git add docs/
   git commit -m "Add client-side Kolkhoz game"
   git push origin master
   ```

2. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Source: Deploy from branch
   - Branch: `master`, folder: `/docs`
   - Save

3. **Access your game:**
   - URL: `https://yourusername.github.io/kolkhoz/`

## 🔧 Technical Details

### Browser Compatibility

- **Chrome/Edge**: 90+
- **Firefox**: 88+
- **Safari**: 14+

Requires ES6 module support, template literals, async/await, Map, Set, and localStorage.

### Game Logic

All game logic has been faithfully ported from the Python implementation:

- **Trick resolution** - Trump beats lead suit, highest value wins
- **Requisition phase** - Complex special card effects and exile logic
- **Job completion** - Threshold-based (40 hours) job claiming
- **Year transitions** - 5 years with year 5 having only 3 tricks

### Save System

Games automatically save to localStorage after every action:
- Survives page refreshes
- Can export/import save files
- Version migration support for future updates

## 🎨 Customization

### Styling

Edit `docs/assets/style.css` to customize:
- Colors and themes
- Card sizes
- Animation speeds
- Layout and spacing

### AI Difficulty

Replace `RandomAI` in `docs/js/ai/RandomAI.js` with smarter strategies:
- Prioritize high-value cards
- Track played cards
- Strategic job selection
- Defensive play to avoid requisition

## 📝 Development

### Adding Features

The codebase is designed for future expansion:

- **Multiplayer** - Network layer stub exists for WebRTC integration
- **Better AI** - Extend `AIPlayer` base class
- **Statistics** - Track wins, scores, achievements
- **Themes** - Easy CSS customization
- **Undo/Replay** - Game state is fully serializable

### Testing

Manual testing checklist:
- ✅ Complete 5-year game
- ✅ Follow-suit validation
- ✅ Trump card logic
- ✅ Special cards (J/Q/K effects)
- ✅ Job completion
- ✅ Requisition phase
- ✅ Save/load functionality
- ✅ Animation smoothness
- ✅ Year 5 (3 tricks only)
- ✅ Game over screen

## 📄 License

This game implementation is provided as-is for educational and entertainment purposes.

## 🙏 Acknowledgments

- Original game design: Traditional Russian card game
- Flask implementation: Original Python/Flask version
- Migration: Complete rewrite to client-side JavaScript

---

**Enjoy the game! Good luck avoiding the ГУЛАГ!** 🎴
