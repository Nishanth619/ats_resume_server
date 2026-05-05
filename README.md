# ATS Resume Builder

Flutter app plus Node backend for building, tailoring, scoring, and exporting ATS-friendly resumes.

## Production Configuration

Do not bundle `.env` in the Flutter app. Backend secrets such as `GEMINI_API_KEY`, `GROQ_API_KEY`, Firebase service account JSON, and LinkedIn OAuth credentials must live only on the backend host.

Build the Flutter app with public runtime values using `--dart-define`:

```sh
flutter build apk --release \
  --dart-define=BACKEND_URL=https://ats-resume-server.onrender.com \
  --dart-define=REVENUECAT_ANDROID_KEY=your_public_revenuecat_key \
  --dart-define=ADMOB_ANDROID_BANNER=your_admob_banner_id
```

Set backend environment variables on the server:

```sh
NODE_ENV=production
GEMINI_API_KEY=...
GROQ_API_KEY=...
FIREBASE_SERVICE_ACCOUNT=...
ALLOWED_ORIGINS=https://your-web-origin.example
BACKEND_URL=https://ats-resume-server.onrender.com
ATS_FREE_DAILY_LIMIT=3
DISABLE_ATS_RATE_LIMIT=false
```

In production, the backend no longer returns mock AI results when providers are missing. At least one AI provider must be configured.

For temporary testing, set `DISABLE_ATS_RATE_LIMIT=true` on the backend host and redeploy. Set it back to `false` before public launch.
