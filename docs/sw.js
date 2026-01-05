const CACHE_NAME = 'kolkhoz-v4';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  // Card assets for offline play
  '/assets/cards/back.svg',
  '/assets/cards/ace_of_clubs.svg',
  '/assets/cards/ace_of_diamonds.svg',
  '/assets/cards/ace_of_hearts.svg',
  '/assets/cards/ace_of_spades.svg',
  '/assets/cards/2_of_clubs.svg',
  '/assets/cards/2_of_diamonds.svg',
  '/assets/cards/2_of_hearts.svg',
  '/assets/cards/2_of_spades.svg',
  '/assets/cards/3_of_clubs.svg',
  '/assets/cards/3_of_diamonds.svg',
  '/assets/cards/3_of_hearts.svg',
  '/assets/cards/3_of_spades.svg',
  '/assets/cards/4_of_clubs.svg',
  '/assets/cards/4_of_diamonds.svg',
  '/assets/cards/4_of_hearts.svg',
  '/assets/cards/4_of_spades.svg',
  '/assets/cards/5_of_clubs.svg',
  '/assets/cards/5_of_diamonds.svg',
  '/assets/cards/5_of_hearts.svg',
  '/assets/cards/5_of_spades.svg',
  '/assets/cards/6_of_clubs.svg',
  '/assets/cards/6_of_diamonds.svg',
  '/assets/cards/6_of_hearts.svg',
  '/assets/cards/6_of_spades.svg',
  '/assets/cards/7_of_clubs.svg',
  '/assets/cards/7_of_diamonds.svg',
  '/assets/cards/7_of_hearts.svg',
  '/assets/cards/7_of_spades.svg',
  '/assets/cards/8_of_clubs.svg',
  '/assets/cards/8_of_diamonds.svg',
  '/assets/cards/8_of_hearts.svg',
  '/assets/cards/8_of_spades.svg',
  '/assets/cards/9_of_clubs.svg',
  '/assets/cards/9_of_diamonds.svg',
  '/assets/cards/9_of_hearts.svg',
  '/assets/cards/9_of_spades.svg',
  '/assets/cards/10_of_clubs.svg',
  '/assets/cards/10_of_diamonds.svg',
  '/assets/cards/10_of_hearts.svg',
  '/assets/cards/10_of_spades.svg',
  '/assets/cards/jack_of_clubs.svg',
  '/assets/cards/jack_of_diamonds.svg',
  '/assets/cards/jack_of_hearts.svg',
  '/assets/cards/jack_of_spades.svg',
  '/assets/cards/queen_of_clubs.svg',
  '/assets/cards/queen_of_diamonds.svg',
  '/assets/cards/queen_of_hearts.svg',
  '/assets/cards/queen_of_spades.svg',
  '/assets/cards/king_of_clubs.svg',
  '/assets/cards/king_of_diamonds.svg',
  '/assets/cards/king_of_hearts.svg',
  '/assets/cards/king_of_spades.svg',
  // Suit icons
  '/assets/suits/wheat.svg',
  '/assets/suits/sunflower.svg',
  '/assets/suits/potato.svg',
  '/assets/suits/beet.svg',
];

// Install event - cache static assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(STATIC_ASSETS);
    })
  );
  self.skipWaiting();
});

// Activate event - clean up old caches
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames
          .filter((name) => name !== CACHE_NAME)
          .map((name) => caches.delete(name))
      );
    })
  );
  self.clients.claim();
});

// Fetch event - serve from cache, fallback to network
self.addEventListener('fetch', (event) => {
  // Skip non-GET requests
  if (event.request.method !== 'GET') return;

  // Skip cross-origin requests (like Google Fonts)
  if (!event.request.url.startsWith(self.location.origin)) return;

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        // Return cached response and update cache in background
        event.waitUntil(
          fetch(event.request).then((response) => {
            if (response.ok) {
              caches.open(CACHE_NAME).then((cache) => {
                cache.put(event.request, response);
              });
            }
          }).catch(() => {})
        );
        return cachedResponse;
      }

      // Not in cache - fetch from network and cache
      return fetch(event.request).then((response) => {
        if (response.ok) {
          const responseClone = response.clone();
          caches.open(CACHE_NAME).then((cache) => {
            cache.put(event.request, responseClone);
          });
        }
        return response;
      });
    })
  );
});
