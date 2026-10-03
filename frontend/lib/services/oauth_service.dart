import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';

class OAuthService {
  static final OAuthService _instance = OAuthService._internal();
  factory OAuthService() => _instance;
  OAuthService._internal();

  final _apiService = ApiService();

  // FIX: Access the singleton instance
  final _googleSignIn = GoogleSignIn.instance;

  // set up the Google Sign-In plugin (required once before calling signIn)
  Future<void> initializeGoogle() async {
    await _googleSignIn.initialize(
      serverClientId:
          const String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID'),
    );
  }

  // open the Google sign-in dialog and return its ID token
  // (users cancelling will throw a GoogleSignInException)
  Future<String> googleIdToken() async {
    await initializeGoogle();
    final account = await _googleSignIn.authenticate(
      scopeHint: ['email', 'profile'],
    );

    // In v7+, 'authentication' is a synchronous getter
    final idToken = account.authentication.idToken;
    if (idToken == null) throw Exception('Failed to get Google ID token');
    return idToken;
  }

  // open the Facebook login dialog and return its access token (null if cancelled)
  Future<String?> facebookAccessToken() async {
    final result = await FacebookAuth.instance.login(
      permissions: ['email', 'public_profile'],
    );

    if (result.status == LoginStatus.cancelled) return null;
    if (result.status != LoginStatus.success) {
      throw Exception(result.message ?? 'Facebook login failed');
    }

    final token = result.accessToken;
    if (token == null) throw Exception('Failed to get Facebook token');

    // flutter_facebook_auth v7: tokenString is on classic (non-limited) tokens
    final tokenString = token.tokenString;
    if (tokenString.isEmpty) throw Exception('Facebook token is empty');
    return tokenString;
  }

  // the provider's token for "google" or "facebook" (null if the user cancelled)
  Future<String?> providerToken(String provider) =>
      provider == 'google' ? googleIdToken() : facebookAccessToken();

  // sign in with Google: get the ID token, send it to our backend
  Future<AuthResponseDto?> signInWithGoogle() async =>
      _apiService.authenticateWithGoogle(await googleIdToken());

  // sign in with Facebook: get the access token, send it to our backend
  Future<AuthResponseDto?> signInWithFacebook() async {
    final token = await facebookAccessToken();
    if (token == null) return null;
    return _apiService.authenticateWithFacebook(token);
  }
}
