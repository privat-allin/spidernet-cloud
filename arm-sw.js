// Service worker מינימלי — נדרש כדי שהדפדפן יציע "התקן אפליקציה". לא שומר כלום במטמון:
// מצב הדריכה חייב להיות תמיד עדכני מהרשת.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", e => e.waitUntil(self.clients.claim()));
self.addEventListener("fetch", () => {});
