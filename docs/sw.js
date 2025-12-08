// Service Worker for Kolkhoz PWA
const CACHE_NAME = 'kolkhoz-v1';
const urlsToCache = [
  './',
  './index.html',
  './game.html',
  './assets/style.css',
  './assets/medal.svg',
  './assets/medal_icon.png',
  './assets/card_back.png',
  './js/main.js',
  './js/lobby.js',
  './js/controller.js',
  './js/core/GameState.js',
  './js/core/Player.js',
  './js/core/Card.js',
  './js/core/constants.js',
  './js/storage/GameStorage.js',
  './js/ui/GameRenderer.js',
  './js/ui/CardAnimator.js',
  './js/ui/NotificationManager.js',
  './js/ui/TouchHandler.js',
  './js/ai/AIPlayer.js',
  './js/ai/RandomAI.js'
];

// Install event - cache resources
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then((cache) => {
        console.log('[SW] Opened cache');
        return cache.addAll(urlsToCache);
      })
      .catch((error) => {
        console.error('[SW] Cache failed:', error);
      })
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          if (cacheName !== CACHE_NAME) {
            console.log('[SW] Deleting old cache:', cacheName);
            return caches.delete(cacheName);
          }
        })
      );
    })
  );
  return self.clients.claim();
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  event.respondWith(
    caches.match(event.request)
      .then((response) => {
        // Return cached version or fetch from network
        return response || fetch(event.request).then((response) => {
          // Don't cache non-GET requests or non-200 responses
          if (event.request.method !== 'GET' || !response || response.status !== 200) {
            return response;
          }

          // Clone the response
          const responseToCache = response.clone();

          caches.open(CACHE_NAME)
            .then((cache) => {
              cache.put(event.request, responseToCache);
            });

          return response;
        });
      })
      .catch(() => {
        // If both cache and network fail, return offline page if available
        if (event.request.destination === 'document') {
          return caches.match('./index.html');
        }
      })
  );
});

