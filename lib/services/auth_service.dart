import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis_auth/auth_io.dart' as gapi;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'api_config.dart';

/// Outcome of a successful sign-in.
@immutable
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
  });

  final String accessToken;
  final AuthUser user;
}

@immutable
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.name,
    required this.pictureUrl,
  });

  final String id;
  final String email;
  final String name;
  final String pictureUrl;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as String?) ?? '',
        email: (json['email'] as String?) ?? '',
        name: (json['name'] as String?) ?? '',
        pictureUrl: (json['picture_url'] as String?) ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'picture_url': pictureUrl,
      };
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => 'AuthException: $message';
}

/// Persists the JWT and the cached user profile, runs the platform-appropriate
/// Google Sign-In flow, and exposes a single source of truth for "is the user
/// signed in".
class AuthService {
  AuthService({
    String? backendBaseUrl,
    FlutterSecureStorage? storage,
    http.Client? httpClient,
  })  : _baseUrl = (backendBaseUrl ?? kDefaultBackendUrl).replaceAll(
              RegExp(r'/+$'),
              '',
            ),
        _storage = storage ?? const FlutterSecureStorage(),
        _http = httpClient ?? http.Client();

  static const _kTokenKey = 'noetica.auth.jwt.v1';
  static const _kUserKey = 'noetica.auth.user.v1';

  /// DEV-ONLY: when set to "true" via --dart-define=DEV_SKIP_AUTH=true,
  /// `restore()` and `signInWithGoogle()` return a synthetic local session
  /// without contacting Google or the backend. Used for offline web/desktop
  /// previews of UI changes. Never set this in release builds.
  static const String _devSkipAuth = String.fromEnvironment(
    'DEV_SKIP_AUTH',
    defaultValue: 'false',
  );
  static bool get _skipAuth => _devSkipAuth == 'true';

  /// Web client ID — supplied at build time:
  ///   flutter build apk --dart-define=GOOGLE_OAUTH_WEB_CLIENT_ID=...
  static const String _webClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Desktop client ID + secret for the Windows installed-app PKCE flow.
  static const String _desktopClientId = String.fromEnvironment(
    'GOOGLE_OAUTH_DESKTOP_CLIENT_ID',
    defaultValue: '',
  );
  static const String _desktopClientSecret = String.fromEnvironment(
    'GOOGLE_OAUTH_DESKTOP_CLIENT_SECRET',
    defaultValue: '',
  );

  final String _baseUrl;
  final FlutterSecureStorage _storage;
  final http.Client _http;

  final _stateController = StreamController<AuthSession?>.broadcast();
  AuthSession? _current;

  /// Emits the current session every time it changes (sign-in / sign-out / cold start).
  Stream<AuthSession?> get sessionStream => _stateController.stream;
  AuthSession? get current => _current;

  Future<AuthSession?> restore() async {
    if (_skipAuth) {
      _current = _devStubSession();
      _stateController.add(_current);
      return _current;
    }
    final token = await _storage.read(key: _kTokenKey);
    final userJson = await _storage.read(key: _kUserKey);
    if (token == null || token.isEmpty || userJson == null) {
      _current = null;
      _stateController.add(null);
      return null;
    }
    try {
      final user = AuthUser.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
      _current = AuthSession(accessToken: token, user: user);
      _stateController.add(_current);
      return _current;
    } catch (_) {
      await signOut();
      return null;
    }
  }

  /// Run the platform-appropriate Google Sign-In flow, exchange the resulting
  /// ID token for a Noetica JWT, and persist both.
  Future<AuthSession> signInWithGoogle() async {
    if (_skipAuth) {
      _current = _devStubSession();
      _stateController.add(_current);
      return _current!;
    }
    final idToken = await _obtainGoogleIdToken();
    final response = await _http
        .post(
          Uri.parse('$_baseUrl/auth/google'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'id_token': idToken}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw AuthException(
        'Backend rejected sign-in (${response.statusCode}): ${response.body}',
      );
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final session = AuthSession(
      accessToken: body['access_token'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
    await _storage.write(key: _kTokenKey, value: session.accessToken);
    await _storage.write(
      key: _kUserKey,
      value: jsonEncode(session.user.toJson()),
    );
    _current = session;
    _stateController.add(session);
    return session;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _kTokenKey);
    await _storage.delete(key: _kUserKey);
    _current = null;
    _stateController.add(null);
    // On Android also revoke the cached Google account, so the user sees the
    // chooser next time instead of being silently re-signed-in.
    if (!kIsWeb) {
      try {
        if (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS) {
          await GoogleSignIn(serverClientId: _webClientId).signOut();
        }
      } catch (_) {}
    }
  }

  /// Called by API clients when the backend returns 401 on an
  /// authenticated call. The cached JWT is almost certainly stale
  /// (e.g. we switched backends or the server rotated JWT_SECRET), so
  /// we drop it and let `AuthGate` kick the user back to the sign-in
  /// screen. Keeping a stale token in storage means every LLM / sync
  /// request silently fails forever — which looks exactly like "Gemini
  /// doesn't work".
  Future<void> handleUnauthorized() async {
    if (_current == null) return;
    // DEV-ONLY: when DEV_SKIP_AUTH=true the "session" is a synthetic
    // local stub used to preview UI without a backend. Treating a 401
    // from a real network call as a sign-out kicks the dev user back
    // to the sign-in screen mid-onboarding, which makes it impossible
    // to drive the app locally for visual QA. Keep the stub alive.
    if (_skipAuth) return;
    await signOut();
  }

  Future<String> _obtainGoogleIdToken() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
         defaultTargetPlatform == TargetPlatform.iOS)) {
      return _googleSignInIdToken();
    }
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
         defaultTargetPlatform == TargetPlatform.macOS ||
         defaultTargetPlatform == TargetPlatform.linux)) {
      return _desktopInstalledAppIdToken();
    }
    if (kIsWeb) {
      return _googleSignInIdToken();
    }
    throw AuthException('Sign-in is not supported on this platform.');
  }

  Future<String> _googleSignInIdToken() async {
    if (_webClientId.isEmpty) {
      throw AuthException(
        'GOOGLE_OAUTH_WEB_CLIENT_ID is not configured at build time.',
      );
    }
    final signIn = GoogleSignIn(
      serverClientId: _webClientId,
      scopes: const ['email', 'profile', 'openid'],
    );
    final account = await signIn.signIn();
    if (account == null) {
      throw AuthException('Sign-in cancelled.');
    }
    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException(
        'Google did not return an ID token. Check that the Web client ID '
        'matches GOOGLE_OAUTH_WEB_CLIENT_ID.',
      );
    }
    return idToken;
  }

  Future<String> _desktopInstalledAppIdToken() async {
    if (_desktopClientId.isEmpty || _desktopClientSecret.isEmpty) {
      throw AuthException(
        'GOOGLE_OAUTH_DESKTOP_CLIENT_ID/_SECRET is not configured at build time.',
      );
    }
    final clientId = gapi.ClientId(_desktopClientId, _desktopClientSecret);
    // Force the openid scope so Google issues an ID token alongside the
    // access token.
    const scopes = ['email', 'profile', 'openid'];

    final credentials = await gapi.obtainAccessCredentialsViaUserConsent(
      clientId,
      scopes,
      _http,
      (url) async {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      },
    );
    final idToken = credentials.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw AuthException(
        'Google did not return an ID token. Did you include the openid scope?',
      );
    }
    return idToken;
  }

  void dispose() {
    _stateController.close();
    _http.close();
  }

  AuthSession _devStubSession() => const AuthSession(
        accessToken: 'dev-skip-auth-token',
        user: AuthUser(
          id: 'dev-local-user',
          email: 'dev@noetica.local',
          name: 'Dev',
          pictureUrl: '',
        ),
      );
}
