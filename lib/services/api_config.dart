/// Single source of truth for the Noetica backend URL.
///
/// Override at build time:
///   flutter build apk --dart-define=NOETICA_BACKEND_URL=https://api.example.com
const String kDefaultBackendUrl = String.fromEnvironment(
  'NOETICA_BACKEND_URL',
  defaultValue: 'https://noetica-backend-glglzvme.fly.dev',
);

/// When true, API calls skip the token requirement and send requests
/// without Authorization header. The backend must also have
/// DEV_SKIP_AUTH=true to accept unauthenticated requests.
const bool kDevSkipAuth = String.fromEnvironment(
  'DEV_SKIP_AUTH',
  defaultValue: 'false',
) == 'true';
