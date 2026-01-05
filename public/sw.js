const CACHE_NAME = 'kolkhoz-v6';
const STATIC_ASSETS = [
  '/',
  '/index.html',
  '/manifest.json',
  // Card assets for offline play - using crop suit names
  '/assets/cards/back.svg',
  '/assets/cards/ace_of_wheat.svg',
  '/assets/cards/ace_of_sunflower.svg',
  '/assets/cards/ace_of_potato.svg',
  '/assets/cards/ace_of_beet.svg',
  '/assets/cards/2_of_wheat.svg',
  '/assets/cards/2_of_sunflower.svg',
  '/assets/cards/2_of_potato.svg',
  '/assets/cards/2_of_beet.svg',
  '/assets/cards/3_of_wheat.svg',
  '/assets/cards/3_of_sunflower.svg',
  '/assets/cards/3_of_potato.svg',
  '/assets/cards/3_of_beet.svg',
  '/assets/cards/4_of_wheat.svg',
  '/assets/cards/4_of_sunflower.svg',
  '/assets/cards/4_of_potato.svg',
  '/assets/cards/4_of_beet.svg',
  '/assets/cards/5_of_wheat.svg',
  '/assets/cards/5_of_sunflower.svg',
  '/assets/cards/5_of_potato.svg',
  '/assets/cards/5_of_beet.svg',
  '/assets/cards/6_of_wheat.svg',
  '/assets/cards/6_of_sunflower.svg',
  '/assets/cards/6_of_potato.svg',
  '/assets/cards/6_of_beet.svg',
  '/assets/cards/7_of_wheat.svg',
  '/assets/cards/7_of_sunflower.svg',
  '/assets/cards/7_of_potato.svg',
  '/assets/cards/7_of_beet.svg',
  '/assets/cards/8_of_wheat.svg',
  '/assets/cards/8_of_sunflower.svg',
  '/assets/cards/8_of_potato.svg',
  '/assets/cards/8_of_beet.svg',
  '/assets/cards/9_of_wheat.svg',
  '/assets/cards/9_of_sunflower.svg',
  '/assets/cards/9_of_potato.svg',
  '/assets/cards/9_of_beet.svg',
  '/assets/cards/10_of_wheat.svg',
  '/assets/cards/10_of_sunflower.svg',
  '/assets/cards/10_of_potato.svg',
  '/assets/cards/10_of_beet.svg',
  '/assets/cards/jack_of_wheat.svg',
  '/assets/cards/jack_of_sunflower.svg',
  '/assets/cards/jack_of_potato.svg',
  '/assets/cards/jack_of_beet.svg',
  '/assets/cards/queen_of_wheat.svg',
  '/assets/cards/queen_of_sunflower.svg',
  '/assets/cards/queen_of_potato.svg',
  '/assets/cards/queen_of_beet.svg',
  '/assets/cards/king_of_wheat.svg',
  '/assets/cards/king_of_sunflower.svg',
  '/assets/cards/king_of_potato.svg',
  '/assets/cards/king_of_beet.svg',
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
