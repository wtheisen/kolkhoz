# Deployment Guide - Kolkhoz to GitHub Pages

## Quick Start

Your game is ready to deploy! Follow these steps:

### 1. Test Locally (Already Running!)

A local server is currently running at:
```
http://localhost:8000
```

Open this URL in your browser to test the game before deploying.

### 2. Commit to Git

```bash
# From the kolkhoz directory
git add docs/
git commit -m "Migrate Kolkhoz to client-side - ready for GitHub Pages"
git push origin master
```

### 3. Enable GitHub Pages

1. Go to your repository on GitHub
2. Click **Settings** → **Pages**
3. Under "Source":
   - Branch: `master`
   - Folder: `/docs`
4. Click **Save**

### 4. Access Your Game

After a few minutes, your game will be live at:
```
https://wtheisen.github.io/kolkhoz/
```

(Replace `wtheisen` with your GitHub username)

## What Was Migrated

✅ **Complete game logic** - All Python code ported to JavaScript
✅ **AI opponents** - RandomAI fully functional
✅ **Game state** - localStorage persistence
✅ **UI/Animations** - All Jinja2 templates converted
✅ **Assets** - 62 SVG cards copied
✅ **Styling** - Responsive CSS maintained

## File Structure

```
docs/
├── index.html           # Lobby page
├── game.html            # Game page
├── README.md            # Documentation
├── assets/
│   ├── cards/          # 62 SVG files
│   └── style.css       # Styling
└── js/
    ├── core/           # GameState, Card, Player
    ├── ai/             # RandomAI
    ├── ui/             # Renderer, Animator, Notifications
    ├── storage/        # localStorage
    ├── controller.js   # Game flow
    ├── lobby.js        # Lobby entry
    └── main.js         # Game entry
```

## Testing Checklist

Before deploying, test these scenarios:

- [ ] Start a new game
- [ ] Play a complete trick (all 4 players)
- [ ] Assign workers during assignment phase
- [ ] Verify follow-suit validation works
- [ ] Check trump cards win tricks
- [ ] Complete a job (reach 40 hours)
- [ ] Trigger requisition phase
- [ ] Test special cards (Jack, Queen, King)
- [ ] Play through Year 5 (3 tricks only)
- [ ] Reach game over screen
- [ ] Refresh page (game should save/load)
- [ ] Check responsive design on mobile

## Troubleshooting

### Game won't load
- Check browser console for errors
- Verify all JS files are present
- Ensure browser supports ES6 modules

### Cards not displaying
- Check that `docs/assets/cards/` contains all SVG files
- Verify image paths are correct (relative paths)

### Animations not working
- Check CSS file is loaded
- Verify `@keyframes` animations in style.css

### localStorage not working
- Try a different browser
- Check if localStorage is enabled
- Clear browser cache

## Next Steps

After deployment, you can:

1. **Share the URL** - Anyone can play!
2. **Customize styling** - Edit `docs/assets/style.css`
3. **Improve AI** - Extend `RandomAI` class
4. **Add features** - Statistics, achievements, themes
5. **Add multiplayer** - Use the network layer stub

## Performance Notes

- **No server costs** - Pure static hosting
- **Fast loading** - No backend requests
- **Offline capable** - Works without internet (after first load)
- **Small footprint** - ~2MB total (mostly SVG cards)

## Maintenance

To update the game:

1. Make changes in `docs/` directory
2. Test locally with `python3 -m http.server 8000 --directory docs`
3. Commit and push to GitHub
4. GitHub Pages auto-deploys (takes 1-5 minutes)

---

**Your game is ready to deploy!** 🚀

Visit http://localhost:8000 to test it now, then follow the steps above to deploy to GitHub Pages.
