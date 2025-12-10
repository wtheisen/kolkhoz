// UIManager - handles UI overlays, modals, and notifications

export class UIManager {
  constructor(scene) {
    this.scene = scene;
    this.notifications = [];
  }

  // Show notification/toast message
  showNotification(message, type = 'info', duration = 3000) {
    const width = this.scene.cameras.main.width;
    const height = this.scene.cameras.main.height;
    const baseSize = Math.min(width, height);
    
    const colors = {
      info: '#2196F3',
      success: '#4CAF50',
      error: '#F44336',
      warning: '#FF9800'
    };

    const notificationWidth = Math.max(300, Math.min(500, width * 0.4));
    const notificationHeight = Math.max(48, Math.min(80, height * 0.06));
    const notificationY = height * 0.1;
    const fontSize = `${Math.max(14, Math.min(22, baseSize * 0.018))}px`;

    const bg = this.scene.add.rectangle(width / 2, notificationY, notificationWidth, notificationHeight, colors[type] || colors.info, 0.9);
    bg.setStrokeStyle(2, 0xffffff);
    
    const text = this.scene.add.text(width / 2, notificationY, message, {
      fontSize: fontSize,
      fill: '#ffffff',
      fontStyle: 'bold',
      wordWrap: { width: notificationWidth - 20 }
    });
    text.setOrigin(0.5, 0.5);

    // Animate in
    const targetY = notificationY + height * 0.02;
    const startY = notificationY - height * 0.02;
    bg.setAlpha(0);
    text.setAlpha(0);
    bg.setY(startY);
    text.setY(startY);
    this.scene.tweens.add({
      targets: [bg, text],
      alpha: 1,
      y: targetY,
      duration: 300,
      ease: 'Power2'
    });

    // Animate out and destroy
    this.scene.time.delayedCall(duration, () => {
      this.scene.tweens.add({
        targets: [bg, text],
        alpha: 0,
        y: startY,
        duration: 300,
        ease: 'Power2',
        onComplete: () => {
          bg.destroy();
          text.destroy();
        }
      });
    });
  }

  // Show modal overlay
  showModal(title, content, buttons = [], onClose = null) {
    const width = this.scene.cameras.main.width;
    const height = this.scene.cameras.main.height;
    
    // Backdrop
    const backdrop = this.scene.add.rectangle(width / 2, height / 2, width, height, 0x000000, 0.7);
    backdrop.setInteractive();
    
    // Modal container
    const modalWidth = Math.min(600, width * 0.9);
    const modalHeight = Math.min(400, height * 0.8);
    const modalBg = this.scene.add.rectangle(width / 2, height / 2, modalWidth, modalHeight, 0x1a1a1a, 1);
    modalBg.setStrokeStyle(2, 0xc9a961);

    const baseSize = Math.min(width, height);
    const titleFontSize = `${Math.max(22, Math.min(36, baseSize * 0.028))}px`;
    const contentFontSize = `${Math.max(14, Math.min(22, baseSize * 0.018))}px`;
    const buttonFontSize = `${Math.max(12, Math.min(20, baseSize * 0.016))}px`;
    const buttonWidth = Math.max(100, Math.min(150, width * 0.12));
    const buttonHeight = Math.max(32, Math.min(50, height * 0.04));
    
    // Title
    const titleText = this.scene.add.text(width / 2, height / 2 - modalHeight / 2 + height * 0.04, title, {
      fontSize: titleFontSize,
      fill: '#c9a961',
      fontStyle: 'bold'
    });
    titleText.setOrigin(0.5, 0.5);

    // Content (can be text or DOM element)
    let contentElement;
    if (typeof content === 'string') {
      contentElement = this.scene.add.text(width / 2, height / 2, content, {
        fontSize: contentFontSize,
        fill: '#ffffff',
        wordWrap: { width: modalWidth - 40 }
      });
      contentElement.setOrigin(0.5, 0.5);
    }

    // Buttons
    const buttonSpacing = modalWidth / (buttons.length + 1);
    const buttonY = height / 2 + modalHeight / 2 - height * 0.06;
    const createdButtons = buttons.map((button, index) => {
      const buttonX = width / 2 - modalWidth / 2 + buttonSpacing * (index + 1);
      const btnBg = this.scene.add.rectangle(buttonX, buttonY, buttonWidth, buttonHeight, 
        button.primary ? 0xc9a961 : 0x666666, 1);
      btnBg.setInteractive({ useHandCursor: true });
      
      const btnText = this.scene.add.text(buttonX, buttonY, button.label, {
        fontSize: buttonFontSize,
        fill: button.primary ? '#000000' : '#ffffff',
        fontStyle: 'bold'
      });
      btnText.setOrigin(0.5, 0.5);

      btnBg.on('pointerdown', () => {
        if (button.onClick) button.onClick();
        this.closeModal([backdrop, modalBg, titleText, contentElement, btnBg, btnText]);
        if (onClose) onClose();
      });

      btnBg.on('pointerover', () => {
        btnBg.setFillStyle(button.primary ? 0xd4b870 : 0x777777);
      });

      btnBg.on('pointerout', () => {
        btnBg.setFillStyle(button.primary ? 0xc9a961 : 0x666666);
      });

      return { bg: btnBg, text: btnText };
    });

    // Close on backdrop click
    backdrop.on('pointerdown', () => {
      this.closeModal([backdrop, modalBg, titleText, contentElement, ...createdButtons.flatMap(b => [b.bg, b.text])]);
      if (onClose) onClose();
    });

    return {
      close: () => {
        this.closeModal([backdrop, modalBg, titleText, contentElement, ...createdButtons.flatMap(b => [b.bg, b.text])]);
      }
    };
  }

  closeModal(elements) {
    this.scene.tweens.add({
      targets: elements,
      alpha: 0,
      duration: 200,
      ease: 'Power2',
      onComplete: () => {
        elements.forEach(el => el.destroy());
      }
    });
  }

  // Show year/phase indicator
  showPhaseIndicator(year, phase, trump = null) {
    // This will be integrated into GameScene UI
  }
}
