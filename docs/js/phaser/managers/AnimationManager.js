// AnimationManager - handles all game animations

export class AnimationManager {
  constructor(scene) {
    this.scene = scene;
  }

  // Animate card flip
  flipCard(cardSprite, onComplete = null) {
    this.scene.tweens.add({
      targets: cardSprite,
      scaleX: 0,
      duration: 150,
      ease: 'Power2',
      onComplete: () => {
        cardSprite.flip();
        this.scene.tweens.add({
          targets: cardSprite,
          scaleX: 1,
          duration: 150,
          ease: 'Power2',
          onComplete: onComplete
        });
      }
    });
  }

  // Animate card movement
  moveCard(cardSprite, targetX, targetY, targetRotation = 0, duration = 300, onComplete = null) {
    return cardSprite.moveTo(targetX, targetY, targetRotation, duration, onComplete);
  }

  // Animate multiple cards in sequence
  moveCardsSequentially(cards, targets, duration = 300, delay = 50) {
    const tweens = [];
    cards.forEach((card, index) => {
      const tween = this.scene.tweens.add({
        targets: card,
        x: targets[index].x,
        y: targets[index].y,
        rotation: targets[index].rotation || 0,
        duration: duration,
        delay: index * delay,
        ease: 'Power2'
      });
      tweens.push(tween);
    });
    return tweens;
  }

  // Animate trick resolution (highlight winner)
  highlightTrickWinner(winnerCard, onComplete = null) {
    const originalScale = winnerCard.scaleX;
    this.scene.tweens.add({
      targets: winnerCard,
      scaleX: originalScale * 1.3,
      scaleY: originalScale * 1.3,
      duration: 200,
      yoyo: true,
      repeat: 2,
      ease: 'Power2',
      onComplete: onComplete
    });
  }

  // Animate cards to gulag
  exileCards(cards, gulagPosition, onComplete = null) {
    const baseSize = Math.min(this.scene.cameras.main.width, this.scene.cameras.main.height);
    const spacingX = Math.max(16, Math.min(24, baseSize * 0.02));
    const spacingY = Math.max(24, Math.min(36, baseSize * 0.03));
    
    const tweens = cards.map((card, index) => {
      return this.scene.tweens.add({
        targets: card,
        x: gulagPosition.x + (index % 5) * spacingX,
        y: gulagPosition.y + Math.floor(index / 5) * spacingY,
        alpha: 0.7,
        scale: 0.5,
        duration: 500,
        delay: index * 50,
        ease: 'Power2'
      });
    });

    if (onComplete) {
      const lastTween = tweens[tweens.length - 1];
      lastTween.on('complete', onComplete);
    }

    return tweens;
  }

  // Animate year transition
  yearTransition(year, onComplete = null) {
    const width = this.scene.cameras.main.width;
    const height = this.scene.cameras.main.height;
    const baseSize = Math.min(width, height);
    
    const overlay = this.scene.add.rectangle(width / 2, height / 2, width, height, 0x000000, 0.9);
    overlay.setAlpha(0);
    
    const fontSize = `${Math.max(48, Math.min(80, baseSize * 0.064))}px`;
    const yearText = this.scene.add.text(width / 2, height / 2, `года ${year}`, {
      fontSize: fontSize,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    yearText.setOrigin(0.5, 0.5);
    yearText.setAlpha(0);

    this.scene.tweens.add({
      targets: [overlay, yearText],
      alpha: 1,
      duration: 300,
      ease: 'Power2',
      onComplete: () => {
        this.scene.tweens.add({
          targets: [overlay, yearText],
          alpha: 0,
          duration: 300,
          delay: 1000,
          ease: 'Power2',
          onComplete: () => {
            overlay.destroy();
            yearText.destroy();
            if (onComplete) onComplete();
          }
        });
      }
    });
  }

  // Stagger animation for fanning cards
  fanCards(cards, positions, duration = 300) {
    return cards.map((card, index) => {
      return this.scene.tweens.add({
        targets: card,
        x: positions[index].x,
        y: positions[index].y,
        rotation: positions[index].rotation || 0,
        duration: duration,
        delay: index * 30,
        ease: 'Power2'
      });
    });
  }
}
