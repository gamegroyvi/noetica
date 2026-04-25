/// Single source of truth for the Noetica backend URL.
///
/// Override at build time:
///   flutter build apk --dart-define=NOETICA_BACKEND_URL=https://api.example.com
const String kDefaultBackendUrl = String.fromEnvironment(
  'NOETICA_BACKEND_URL',
  defaultValue: 'https://noetica-backend-rxecvoov.fly.dev',
);
