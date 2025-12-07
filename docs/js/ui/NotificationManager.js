// NotificationManager - replaces Flask flash messages

export class NotificationManager {
  static show(message, type = 'info') {
    const div = document.createElement('div');
    div.className = `notification notification-${type}`;
    div.textContent = message;
    div.style.position = 'fixed';
    div.style.top = '20px';
    div.style.right = '20px';
    div.style.padding = '12px 20px';
    div.style.background = type === 'error' ? '#f44336' : '#4CAF50';
    div.style.color = '#fff';
    div.style.borderRadius = '4px';
    div.style.zIndex = '10000';
    div.style.boxShadow = '0 4px 12px rgba(0,0,0,0.2)';
    div.style.fontSize = '14px';
    div.style.fontWeight = 'bold';
    div.style.maxWidth = '300px';
    div.style.wordWrap = 'break-word';

    document.body.appendChild(div);

    setTimeout(() => {
      div.style.transition = 'opacity 0.3s';
      div.style.opacity = '0';
      setTimeout(() => {
        div.remove();
      }, 300);
    }, 3000);
  }
}
