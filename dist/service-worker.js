// I keep this worker at the root of dist/ on purpose. A service
// worker can only control pages at or below the folder it is served
// from, and an earlier copy of this file sat under dist/static/,
// which limited it to that subtree and left the newspaper itself
// outside its scope. The registration in the themed page points at
// service-worker.js relative to the page, so this file's location
// and that registration have to stay in step.
// Hackers-Den Service Worker
// The name below has stayed at v1 since I wrote it. Nothing in this
// file deletes old caches: there is no activate handler at all, and
// caches.match in the fetch handler searches every cache on the
// origin, so entries stored under an older name would still be
// served. If I ever change the list below, I have to change this
// name too and accept that the old cache stays on readers' machines.
const CACHE_NAME = 'hackers-den-cache-v1';
// I wrote these paths from the domain root. That lines up only if
// the site is served from the root of its domain. Served from a
// subpath, the way a GitHub Pages project site is, each of these
// points outside the site, and the install below fails on them.
// The list also has to name files that exist. cache.addAll is all
// or nothing: one bad entry rejects the whole install and the
// worker never activates. That is how the earlier version of this
// list broke, when it named a font file that was never in the repo.
const urlsToCache = [
  '/',
  '/index.html',
  '/static/css/main.css',
  '/static/css/desktop.css',
  '/static/css/mobile.css',
  '/static/css/normalize.css',
  '/static/fonts/Newsreader-VariableFont_opsz,wght.woff2',
  '/static/img/newsreader-not-cover.png'
];

self.addEventListener('install', event => {
  event.waitUntil(
    caches.open(CACHE_NAME)
      .then(cache => {
        console.log('Opened cache');
        return cache.addAll(urlsToCache);
      })
  );
});

// The fetch handler serves the cache first and the network second.
// A page this worker has cached is served from the cache on every
// later visit, and the network copy is never compared, so a reader
// can keep seeing a cached newspaper until the cache name changes.
// Responses fetched from the network are stored below, which is how
// pages beyond the install list get cached at all.
self.addEventListener('fetch', event => {
  event.respondWith(
    caches.match(event.request)
      .then(response => {
        if (response) {
          return response;
        }
        return fetch(event.request).then(
          response => {
            if(!response || response.status !== 200 || response.type !== 'basic') {
              return response;
            }
            // The clone matters: a response body can be read once,
            // and the original is returned to the page below. Without
            // the clone, storing it and returning it would fight over
            // the same body. The put itself is not returned or
            // awaited, so the fetch finishes without waiting for the
            // cache write, and nothing here reports it if it fails.
            const responseToCache = response.clone();
            caches.open(CACHE_NAME)
              .then(cache => {
                cache.put(event.request, responseToCache);
              });
            return response;
          }
        );
      })
  );
});
