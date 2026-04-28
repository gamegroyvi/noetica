/// Single source of truth for the Noetica backend URL.
///
/// Override at build time:
///   flutter build apk --dart-define=NOETICA_BACKEND_URL=https://api.example.com
///
/// Two fly apps exist in this org: `noetica-backend-rxecvoov` (current —
/// has auth + sync + roadmap + onboarding routes deployed) and
/// `noetica-backend-nzlazosh` (older — only has roadmap + onboarding,
/// missing /auth and /sync). Earlier the client had `rxecvoov` for
/// auth/sync but `nzlazosh` for roadmap/axes, which made roadmap/axes
/// hit a host that didn't recognise the JWT (auth was issued by
/// `rxecvoov`) and silently broke after-onboarding flows. We unify on
/// `rxecvoov` since it's the only one with the full surface.
const String kDefaultBackendUrl = String.fromEnvironment(
  'NOETICA_BACKEND_URL',
  defaultValue: 'https://noetica-backend-rxecvoov.fly.dev',
);
