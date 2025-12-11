# Kolkhoz (Колхоз) - Browser Card Game

A fully functional, client-side implementation of the Russian trick-taking card game **Kolkhoz**, playable entirely in the browser with no backend required. This game simulates a Soviet Five-Year Plan (Пятилетка) where players compete as brigade leaders managing agricultural work across 5 years, trying to complete jobs and collect valuable cards while avoiding having their workers sent to the ГУЛАГ (gulag).

## 🎮 Current Status

**✅ Fully Playable** - The game is complete and fully functional with:
- Complete game logic implementation
- 4-player gameplay (1 human + 3 AI opponents)
- Full 5-year campaign with all game mechanics
- Automatic save/load via localStorage
- Responsive UI with card animations
- All special card effects implemented

## 🚀 Quick Start

### Play Locally

```bash
# From the project root directory
cd docs
python3 -m http.server 8000

# Or with Node.js
npx http-server docs -p 8000

# Then visit http://localhost:8000
```

### Deploy to GitHub Pages

The game is ready for deployment. See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed instructions.

1. Push the `docs/` folder to your repository
2. Enable GitHub Pages in repository settings
3. Set source to `master` branch, `/docs` folder
4. Access at `https://yourusername.github.io/kolkhoz/`

## 📖 About the Game

**Kolkhoz** is a strategic trick-taking card game set during a Soviet Five-Year Plan. Players take turns as the Central Planner (Центральный Плановик), revealing job assignments and managing workers across four agricultural jobs:

- **Hearts (Пахота - Plowing)** - Agricultural work
- **Diamonds (Жатва - Harvesting)** - Harvest collection
- **Clubs (Мастерская - Workshop)** - Craftsmanship
- **Spades (Зерно - Grain)** - Grain production

### Game Flow

1. **Planning Phase** - The Central Planner reveals job cards (Ace-5) for each of the four jobs and declares a trump suit
2. **Trick-Taking Phase** - Four tricks are played (three in Year 5). Players must follow suit if able
3. **Job Assignment** - The trick winner (Brigade Leader) assigns workers to jobs. Trump cards can be assigned to any job
4. **Job Completion** - If a job reaches 40 work hours, the Brigade Leader claims the job card
5. **Personal Plot Selection** - Each player keeps one card from their hand for their hidden Personal Plot
6. **Requisition Phase** - Failed jobs (under 40 hours) trigger requisition, where players may lose cards from their Personal Plot
7. **Year Transition** - After 5 years, players sum their Personal Plot cards. Highest score wins!

### Special Cards (Trump Suit Only)

- **Jack (Пьяница - Drunkard)** - Contributes 0 work hours. If the job fails, the Drunkard is exiled instead of your cards
- **Queen (Информатор - Informant)** - If the job fails, ALL players reveal their Personal Plots (not just Brigade Leaders)
- **King (партийец - Party Official)** - If the job is requisitioned, TWO cards are exiled instead of one

## 🏗️ Architecture

This is a **pure client-side implementation** with zero dependencies:

- **No backend required** - All game logic runs in the browser
- **ES6 modules** - Modern JavaScript with clean imports
- **localStorage persistence** - Games save automatically after every action
- **Zero dependencies** - Pure vanilla JavaScript (no frameworks)
- **Responsive design** - Works on desktop and mobile devices
- **SVG card graphics** - 62 high-quality card images

### Project Structure

```
kolkhoz/
├── docs/                      # Deployable game files
│   ├── index.html            # Lobby page
│   ├── game.html             # Main game interface
│   ├── assets/
│   │   ├── cards/            # 62 SVG card images
│   │   ├── medal.svg         # Game icon
│   │   └── style.css         # Game styling
│   └── js/
│       ├── core/             # Game engine
│       │   ├── constants.js  # Game constants
│       │   ├── Card.js       # Card class
│       │   ├── Player.js     # Player class
│       │   └── GameState.js  # Core game logic (500+ lines)
│       ├── ai/               # AI opponents
│       │   ├── AIPlayer.js   # Base AI class
│       │   └── RandomAI.js   # Random strategy AI
│       ├── ui/               # User interface
│       │   ├── GameRenderer.js      # Main renderer
│       │   ├── CardAnimator.js      # Card animations
│       │   └── NotificationManager.js # Game notifications
│       ├── storage/          # Persistence
│       │   └── GameStorage.js # localStorage management
│       ├── controller.js     # Game flow orchestration
│       ├── lobby.js          # Lobby entry point
│       └── main.js           # Game entry point
├── static/                   # Legacy Flask assets (deprecated)
├── templates/                # Legacy Flask templates (deprecated)
├── rules.txt                 # Game rules documentation
├── DEPLOYMENT.md             # Deployment guide
└── README.md                 # This file
```

## 🎯 Key Features

### Game Mechanics

- ✅ **Complete trick-taking logic** - Follow suit, trump cards, trick resolution
- ✅ **Job assignment system** - Strategic worker placement
- ✅ **Work hour tracking** - 40-hour threshold for job completion
- ✅ **Requisition phase** - Complex exile logic with special card effects
- ✅ **5-year campaign** - Year 5 has unique mechanics (3 tricks, no trump)
- ✅ **Personal Plot management** - Hidden cards that contribute to final score

### User Experience

- ✅ **Drag-and-drop card play** - Intuitive card interaction
- ✅ **Smooth animations** - Card movements and transitions
- ✅ **Auto-save** - Game state persists across page refreshes
- ✅ **Visual feedback** - Clear indication of game state and valid moves
- ✅ **Responsive layout** - Adapts to different screen sizes
- ✅ **Game notifications** - Important events are clearly communicated

### AI Opponents

- ✅ **RandomAI** - Fully functional random strategy AI
- ✅ **Extensible architecture** - Easy to add smarter AI strategies
- ✅ **Base AIPlayer class** - Framework for future AI improvements

## 🔧 Technical Details

### Browser Compatibility

- **Chrome/Edge**: 90+
- **Firefox**: 88+
- **Safari**: 14+

Requires ES6 module support, template literals, async/await, Map, Set, and localStorage.

### Game Logic Implementation

All game logic has been faithfully ported from the original Python/Flask implementation:

- **Trick resolution** - Trump beats lead suit, highest value wins
- **Follow-suit validation** - Enforced during trick-taking phase
- **Job completion** - Threshold-based (40 hours) job claiming
- **Requisition phase** - Complex special card effects and exile logic
- **Year transitions** - Proper state management across 5 years
- **Year 5 mechanics** - 3 tricks only, no trump suit

### Save System

Games automatically save to localStorage after every action:
- Survives page refreshes
- Can export/import save files (future feature)
- Version migration support for future updates
- Save state includes complete game state serialization

## 🎨 Customization

### Styling

Edit `docs/assets/style.css` to customize:
- Colors and themes
- Card sizes and spacing
- Animation speeds
- Layout and responsive breakpoints

### AI Difficulty

The AI system is designed for easy extension. To add smarter AI:

1. Extend the `AIPlayer` base class in `docs/js/ai/AIPlayer.js`
2. Implement strategic decision-making:
   - Prioritize high-value cards
   - Track played cards
   - Strategic job selection
   - Defensive play to avoid requisition
3. Replace `RandomAI` in the game initialization

## 📝 Development

### Code Quality

- **Modular architecture** - Clean separation of concerns
- **ES6 classes** - Object-oriented design
- **Comprehensive game state** - Fully serializable state management
- **Error handling** - Graceful degradation and user feedback

### Future Enhancements

The codebase is designed for future expansion:

- **Multiplayer support** - Network layer stub exists for WebRTC integration
- **Better AI** - Extend `AIPlayer` base class with strategic algorithms
- **Statistics tracking** - Track wins, scores, achievements
- **Themes** - Easy CSS customization for different visual styles
- **Undo/Replay** - Game state is fully serializable
- **Export/Import saves** - Share game states between devices
- **Tutorial mode** - Interactive guide for new players

### Testing Checklist

Manual testing has verified:
- ✅ Complete 5-year game completion
- ✅ Follow-suit validation
- ✅ Trump card logic
- ✅ Special cards (J/Q/K effects)
- ✅ Job completion mechanics
- ✅ Requisition phase logic
- ✅ Save/load functionality
- ✅ Animation smoothness
- ✅ Year 5 (3 tricks only, no trump)
- ✅ Game over screen and scoring

## 📄 Files Overview

- **`docs/`** - Complete deployable game (use this for GitHub Pages)
- **`rules.txt`** - Detailed game rules in English
- **`DEPLOYMENT.md`** - Step-by-step deployment guide
- **`static/`** - Legacy Flask assets (not used in current implementation)
- **`templates/`** - Legacy Flask templates (not used in current implementation)

## 🙏 Acknowledgments

- **Original game design**: Traditional Russian card game "Колхоз"
- **Game rules**: Based on the documented rules in `rules.txt`
- **Implementation**: Complete rewrite from Python/Flask to client-side JavaScript
- **Card graphics**: SVG card images for all 62 cards

## 📚 Additional Resources

- See `rules.txt` for complete game rules
- See `docs/README.md` for detailed technical documentation
- See `DEPLOYMENT.md` for deployment instructions

---

**Enjoy the game! Good luck avoiding the ГУЛАГ!** 🎴

*For questions, issues, or contributions, please refer to the project repository.*
