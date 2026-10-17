// OMIS Entry service worker: keeps the last copy of /pass on this device so the QR
// opens at the gate without data. Network first (always the latest pass when online),
// cached copy when offline. Signing out deletes the cache (see sign-out-button.tsx).
const CACHE = "omis-pass";

self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (event) =>
  event.waitUntil(self.clients.claim()),
);

self.addEventListener("fetch", (event) => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== "GET" || url.origin !== self.location.origin) return;

  // The pass page itself: network first, fall back to the saved copy.
  if (request.mode === "navigate" && url.pathname === "/pass") {
    event.respondWith(
      fetch(request)
        .then((response) => {
          if (response.ok && !response.redirected) {
            const copy = response.clone();
            caches.open(CACHE).then((cache) => cache.put("/pass", copy));
          }
          return response;
        })
        .catch(() =>
          caches.match("/pass").then((cached) => cached || Response.error()),
        ),
    );
    return;
  }

  // Build assets and icons the page needs: cache first (file names are content-hashed).
  if (
    url.pathname.startsWith("/_next/static/") ||
    url.pathname.startsWith("/icons/") ||
    url.pathname === "/logo.png"
  ) {
    event.respondWith(
      caches.match(request).then(
        (cached) =>
          cached ||
          fetch(request).then((response) => {
            if (response.ok) {
              const copy = response.clone();
              caches.open(CACHE).then((cache) => cache.put(request, copy));
            }
            return response;
          }),
      ),
    );
  }
});
