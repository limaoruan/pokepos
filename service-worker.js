// PokéPOS · service worker (instalação + abertura offline do app)
// Rede primeiro: sempre busca a versão nova e só usa o cache se estiver sem conexão.
// Só arquivos do próprio site são guardados; as chamadas ao Supabase (outro endereço) nunca passam por aqui.
const CACHE = 'pokepos-v1.1.0';
const RAIZ = self.registration.scope; // funciona em qualquer subpasta (GitHub Pages)
const SHELL = [
  './',
  'manifest.webmanifest',
  'config.js',
  'favicon.ico',
  'icon-192.png',
  'icon-512.png',
  'apple-touch-icon.png',
  'favicon-16.png',
  'favicon-32.png',
  'favicon-48.png',
  'logo.png'
];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then((c) => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);
  if (req.method !== 'GET' || url.origin !== self.location.origin) return;
  e.respondWith(
    fetch(req)
      .then((res) => {
        if (res.ok) {
          const copy = res.clone();
          caches.open(CACHE).then((c) => c.put(req.mode === 'navigate' ? RAIZ : req, copy));
        }
        return res;
      })
      .catch(() => caches.match(req.mode === 'navigate' ? RAIZ : req).then((hit) => hit || caches.match(RAIZ)))
  );
});
