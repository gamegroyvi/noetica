/// Single source of truth for the Noetica backend URL.
///
/// Override at build time:
///   flutter build apk --dart-define=NOETICA_BACKEND_URL=https://api.example.com
///
/// Deployment history:
/// - `noetica-backend-nzlazosh` (original) — only had roadmap + onboarding,
///   no /auth or /sync; early builds accidentally split traffic between it
///   and `rxecvoov`, which made roadmap calls hit a host that couldn't
///   recognise the JWT issued by `rxecvoov` and silently broke
///   after-onboarding flows.
/// - `noetica-backend-rxecvoov` — first unified host (auth + sync + roadmap
///   + onboarding). Has DEEPSEEK_API_KEY as its only LLM secret, so the
///   Gemini resolver never kicked in there.
/// - `noetica-backend-agscjxvt` (current) — Devin-managed redeploy with
///   the Gemini baked-in-key path triggered. `/healthz/llm` returns
///   `provider=gemini, model=gemini-2.5-flash`. Switch the default here
///   and the Flutter client picks it up everywhere via the existing
///   `_resolveBaseUrl()` helpers in `axes_api.dart` / `roadmap_api.dart`
///   / `sync_service.dart` / `auth_service.dart`.
const String kDefaultBackendUrl = String.fromEnvironment(
  'NOETICA_BACKEND_URL',
  defaultValue: 'https://noetica-backend-agscjxvt.fly.dev',
);
