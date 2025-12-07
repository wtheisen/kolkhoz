// CardAnimator - animation logic for card movements
// Ported from game.html:352-386

export class CardAnimator {
  static animateHumanCard(cardElement, targetElement) {
    return new Promise(resolve => {
      const cardRect = cardElement.getBoundingClientRect();
      const targetRect = targetElement.getBoundingClientRect();

      const offsetX = targetRect.left + targetRect.width / 2
        - (cardRect.left + cardRect.width / 2);
      const offsetY = targetRect.top + targetRect.height / 2
        - (cardRect.top + cardRect.height / 2);

      cardElement.style.setProperty('--trick-x', offsetX + 'px');
      cardElement.style.setProperty('--trick-y', offsetY + 'px');
      cardElement.classList.add('card-fly');

      setTimeout(() => {
        cardElement.classList.remove('card-fly');
        resolve();
      }, 600);
    });
  }

  static animateAICard(playerIndex, cardData) {
    return new Promise(resolve => {
      const hand = document.getElementById(`player-${playerIndex}-hand`);
      const trickArea = document.getElementById('trick-area');

      if (!hand || !trickArea) {
        resolve();
        return;
      }

      // Build the card face image
      const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
      const rank = faces[cardData.value] || cardData.value;
      const file = `${rank}_of_${cardData.suit.toLowerCase()}.svg`;

      const img = document.createElement('img');
      img.src = `assets/cards/${file}`;
      img.className = 'card-image';
      img.style.position = 'fixed';

      // Position at the AI hand
      const cardBack = hand.querySelector('img.card-image');
      if (!cardBack) {
        resolve();
        return;
      }

      const startRect = cardBack.getBoundingClientRect();
      const endRect = trickArea.getBoundingClientRect();

      img.style.left = startRect.left + 'px';
      img.style.top = startRect.top + 'px';
      img.style.zIndex = '2000';
      img.style.transition = 'all 1.2s cubic-bezier(.4,2,.6,1)';
      img.style.opacity = '1';

      document.body.appendChild(img);

      setTimeout(() => {
        img.style.left = (endRect.left + endRect.width / 2 - startRect.width / 2) + 'px';
        img.style.top = (endRect.top + endRect.height / 2 - startRect.height / 2) + 'px';
        img.style.transform = 'scale(1.2)';
      }, 10);

      setTimeout(() => {
        img.remove();
        resolve();
      }, 1250);
    });
  }

  static updateTrickArea(currentTrick, players) {
    const trickArea = document.getElementById('trick-area');
    if (!trickArea) return;

    trickArea.innerHTML = '';

    currentTrick.forEach(([pid, card]) => {
      const cardDiv = document.createElement('div');
      cardDiv.className = 'card';

      const playerDiv = document.createElement('div');
      playerDiv.className = 'card-player';
      playerDiv.textContent = players[pid].name;
      cardDiv.appendChild(playerDiv);

      // Build the card image path
      const faces = { 1: 'ace', 11: 'jack', 12: 'queen', 13: 'king' };
      const rank = faces[card.value] || card.value;
      const file = `${rank}_of_${card.suit.toLowerCase()}.svg`;

      const img = document.createElement('img');
      img.src = `assets/cards/${file}`;
      img.className = 'card-image';
      cardDiv.appendChild(img);

      trickArea.appendChild(cardDiv);
    });
  }
}
