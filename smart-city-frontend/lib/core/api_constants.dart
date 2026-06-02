// ─── Backend API host ────────────────────────────────────────────────────────
//
// HOW TO UPDATE when the backend URL changes:
//   1. Android emulator (local dev)  → use  http://10.0.2.2:8080
//   2. Physical device on same Wi-Fi → use  http://<your-machine-LAN-IP>:8080
//   3. Cloudflare tunnel             → run: cloudflared tunnel --url http://localhost:8080
//                                      then paste the printed *.trycloudflare.com URL here
//   4. Azure VM / production         → use the VM's public IP or domain  e.g. http://20.x.x.x:8080
//
// After changing this value also update APP_BASE_URL in backend/.env so that
// the email-verification links embedded in outgoing emails point to the same host.
// ─────────────────────────────────────────────────────────────────────────────
const String kApiHost = 'https://utilization-refuse-sought-sticky.trycloudflare.com';
// Cloudflare tunnel — works for both emulator and real device.
// Replace with a new tunnel URL each time you restart cloudflared.

// MapTiler API key — get a free key at https://maptiler.com
const String kMapTilerKey = 'T1F9sGhskfSK6lJGRyHK';

const String kMapTilerStyleUrl =
    'https://api.maptiler.com/maps/streets-v2/style.json?key=$kMapTilerKey';