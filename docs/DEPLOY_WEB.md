# Web Production Release Guide

## Configure API endpoint
- For production, use the provided config at `assets/config/app_config.prod.json` (set to `https://ami.planetapplis.fr/api/`).
- Alternatively, edit `assets/config/app_config.json` for local/dev.

## Build (release)
Run from the project root:
```powershell
cd C:\wamp64\www\gesplanet_01\ami
flutter pub get
flutter build web --release --dart-define=APP_CONFIG_ASSET=assets/config/app_config.prod.json
```
- If deploying under a subpath (e.g. `/smartbizapp/`), add:
```powershell
flutter build web --release --base-href /smartbizapp/ --dart-define=APP_CONFIG_ASSET=assets/config/app_config.prod.json
```

## Deploy
- Upload the contents of `build/web/` to your web server at the path `/www/ami`.
- If using Apache/WAMP:
  - Enable compression (gzip/brotli) for `.js`, `.json`, `.css`, `.wasm`.
  - Set caching for static assets (long max-age) and for `index.html` (no-cache).
  - Suggested headers (Apache):
```
<IfModule mod_headers.c>
  Header set X-Content-Type-Options "nosniff"
  Header set X-Frame-Options "SAMEORIGIN"
  Header set Referrer-Policy "strict-origin-when-cross-origin"
  Header set Content-Security-Policy "default-src 'self' https:; img-src 'self' data: https:; style-src 'self' 'unsafe-inline' https:; script-src 'self' 'unsafe-inline' https:; connect-src 'self' https: http:;"
</IfModule>
```

## Verify
- Open the deployed URL in a fresh browser profile: `https://ami.planetapplis.fr/`.
- Check network calls point to your production API (`apiBaseUrl`).
- Ensure service worker `flutter_service_worker.js` is served and caching works.

## Troubleshooting
- 404 after deployment: Ensure `base-href` matches the deployed subpath.
- API calls still hitting localhost: Confirm `assets/config/app_config.json` was included in the build and served.
- White screen: Check console for CSP violations or missing `canvaskit/` resources; try `--web-renderer html`.
