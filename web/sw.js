// Service worker de "Mis Tareas" — permite instalar la app y abrirla offline.
const CACHE = "mis-tareas-v2";
const SHELL = ["/", "/index.html", "/manifest.webmanifest", "/icon-192.png", "/icon-512.png"];

self.addEventListener("install", (e) => {
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(SHELL)).then(() => self.skipWaiting()).catch(() => self.skipWaiting())
  );
});

self.addEventListener("activate", (e) => {
  e.waitUntil(
    caches.keys()
      .then((ks) => Promise.all(ks.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener("fetch", (e) => {
  const req = e.request;
  if (req.method !== "GET") return;          // las escrituras (Supabase) van directo a la red
  const url = new URL(req.url);

  if (url.origin === location.origin) {
    // App propia: red primero, y si no hay conexión, lo cacheado (o index.html para navegar).
    e.respondWith(
      fetch(req)
        .then((res) => { const cl = res.clone(); caches.open(CACHE).then((c) => c.put(req, cl)); return res; })
        .catch(() => caches.match(req).then((r) => r || caches.match("/index.html")))
    );
  } else if (url.href.includes("supabase-js")) {
    // Librería de Supabase (CDN): caché primero, para que la app abra sin conexión.
    e.respondWith(
      caches.match(req).then((r) => r || fetch(req).then((res) => { const cl = res.clone(); caches.open(CACHE).then((c) => c.put(req, cl)); return res; }))
    );
  }
  // El resto (API de Supabase, etc.) usa la red por defecto.
});
