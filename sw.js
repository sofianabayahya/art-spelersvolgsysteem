// Minimale service worker: alleen nodig zodat de browser de app "installeerbaar"
// vindt (App toevoegen aan beginscherm). Bewust GEEN caching van pagina's, zodat
// iedereen na een update altijd meteen de nieuwste versie ziet.
self.addEventListener("install", function(event){
  self.skipWaiting();
});

self.addEventListener("activate", function(event){
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", function(event){
  event.respondWith(fetch(event.request));
});
