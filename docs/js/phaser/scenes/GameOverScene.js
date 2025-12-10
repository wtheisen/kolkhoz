// GameOverScene - displays final scores and winner

export class GameOverScene extends Phaser.Scene {
  constructor() {
    super({ key: 'GameOverScene' });
  }

  init(data) {
    this.gameState = data.gameState;
  }

  create() {
    const width = this.cameras.main.width;
    const height = this.cameras.main.height;
    const baseSize = Math.min(width, height);
    
    // Background overlay
    const overlay = this.add.rectangle(width / 2, height / 2, width, height, 0x000000, 0.8);
    
    // Responsive font sizes
    const titleFontSize = `${Math.max(36, Math.min(60, baseSize * 0.048))}px`;
    const winnerFontSize = `${Math.max(24, Math.min(40, baseSize * 0.032))}px`;
    const playerFontSize = `${Math.max(18, Math.min(30, baseSize * 0.024))}px`;
    const buttonFontSize = `${Math.max(18, Math.min(30, baseSize * 0.024))}px`;
    const buttonWidth = Math.max(160, Math.min(250, width * 0.2));
    const buttonHeight = Math.max(40, Math.min(60, height * 0.05));
    
    // Title
    const title = this.add.text(width / 2, height * 0.2, 'Game Over', {
      fontSize: titleFontSize,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    title.setOrigin(0.5, 0.5);

    // Final scores
    const finalScores = this.gameState.finalScores;
    const sortedPlayers = this.gameState.players.map((player, idx) => ({
      name: player.name,
      score: finalScores[idx],
      idx: idx
    })).sort((a, b) => b.score - a.score);

    let yOffset = height * 0.35;
    const playerSpacing = height * 0.06;
    const winnerSpacing = height * 0.08;
    sortedPlayers.forEach((player, rank) => {
      const isWinner = rank === 0;
      const color = isWinner ? '#ffd700' : '#ffffff';
      const fontSize = isWinner ? winnerFontSize : playerFontSize;
      const rankText = isWinner ? '🏆' : `#${rank + 1}`;
      
      const playerText = this.add.text(width / 2, yOffset, 
        `${rankText} ${player.name}: ${player.score}`, {
        fontSize: fontSize,
        fill: color
      });
      playerText.setOrigin(0.5, 0.5);
      
      yOffset += isWinner ? winnerSpacing : playerSpacing;
    });

    // New Game button
    const newGameButton = this.add.rectangle(width / 2, height * 0.8, buttonWidth, buttonHeight, 0xc9a961);
    newGameButton.setInteractive({ useHandCursor: true });
    
    const newGameText = this.add.text(width / 2, height * 0.8, 'New Game', {
      fontSize: buttonFontSize,
      fill: '#000000',
      fontStyle: 'bold'
    });
    newGameText.setOrigin(0.5, 0.5);

    newGameButton.on('pointerdown', () => {
      // Clear storage and return to lobby
      if (window.GameStorage) {
        window.GameStorage.clear();
      }
      window.location.href = 'index.html';
    });

    newGameButton.on('pointerover', () => {
      newGameButton.setFillStyle(0xd4b870);
    });

    newGameButton.on('pointerout', () => {
      newGameButton.setFillStyle(0xc9a961);
    });
  }
}
