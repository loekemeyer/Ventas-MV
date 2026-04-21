const CACHE = 'ventas-mv-v20';
const CORE = ['./manifest.json', './icon-192.png', './icon-512.png', './logo.jpg'];

self.addEventListener('install', (e) => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(CORE)));
  self.skipWaiting();
});

self.addEventListener('activate', (e) => {
  e.waitUntil(caches.keys().then(keys =>
    Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)))
  ));
  self.clients.claim();
});

// Network-first para index.html (evita quedar pegado a una SW vieja cuando desplegamos)
// Cache-first para íconos y assets estáticos
self.addEventListener('fetch', (e) => {
  if (e.request.method !== 'GET') return;
  const url = new URL(e.request.url);
  const isIndex = url.pathname.endsWith('/') || url.pathname.endsWith('index.html');
  if (isIndex) {
    e.respondWith(
      fetch(e.request).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return res;
      }).catch(() => caches.match(e.request))
    );
    return;
  }
  e.respondWith(
    caches.match(e.request).then(cached =>
      cached || fetch(e.request).then(res => {
        const copy = res.clone();
        caches.open(CACHE).then(c => c.put(e.request, copy));
        return res;
      }).catch(() => cached)
    )
  );
});

// Push: muestra notificación nativa, excepto si la app está abierta y focused (dedupe con realtime)
self.addEventListener('push', (e) => {
  const data = (() => {
    try { return e.data ? e.data.json() : {}; } catch { return {}; }
  })();
  e.waitUntil((async () => {
    const list = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    const focused = list.some(c => c.focused);
    if (focused) return; // el realtime ya mostró el toast in-app
    await self.registration.showNotification(data.t || 'Ventas MV', {
      body: data.b || 'Nueva venta',
      icon: './icon-192.png',
      badge: './icon-192.png',
      data: { id: data.v || '' },
      tag: data.v ? 'venta-' + data.v : 'venta',
      renotify: false,
    });
  })());
});

self.addEventListener('notificationclick', (e) => {
  e.notification.close();
  e.waitUntil((async () => {
    const all = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });
    // Preferir una tab ya abierta bajo nuestro scope
    const target = all.find(c => c.url.includes(self.registration.scope) || c.url.includes('/Ventas-MV/'));
    if (target) { await target.focus(); return; }
    await self.clients.openWindow(self.registration.scope || './');
  })());
});
