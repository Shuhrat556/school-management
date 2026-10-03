import 'package:flutter/material.dart';
import 'package:flutter_bounceable/flutter_bounceable.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tamdansers/services/api_models.dart';
import 'package:tamdansers/services/api_service.dart';
import 'package:tamdansers/services/oauth_service.dart';

// Settings → Security & Login: link or unlink Google and Facebook sign-in (F6).
// Linking is how a Facebook login reaches an account the school created.
class LinkedAccountsScreen extends StatefulWidget {
  // The calls can be replaced in tests; by default they go to the API and the
  // provider SDKs. link/unlink return null on success, otherwise the reason.
  const LinkedAccountsScreen({
    super.key,
    this.fetch,
    this.obtainToken,
    this.link,
    this.unlink,
  });

  final Future<ExternalLoginsDto?> Function()? fetch;
  final Future<String?> Function(String provider)? obtainToken;
  final Future<String?> Function(String provider, String token)? link;
  final Future<String?> Function(String provider)? unlink;

  @override
  State<LinkedAccountsScreen> createState() => _LinkedAccountsScreenState();
}

const _providers = [
  ('google', 'Google', Icons.g_mobiledata_rounded, Color(0xFFDB4437)),
  ('facebook', 'Facebook', Icons.facebook_rounded, Color(0xFF1877F2)),
];

class _LinkedAccountsScreenState extends State<LinkedAccountsScreen> {
  ExternalLoginsDto? _logins;
  bool _loading = true;
  String? _busy; // provider being linked or unlinked

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fetch = widget.fetch ?? () => ApiService().getExternalLogins();
    final logins = await fetch();
    if (!mounted) return;
    setState(() {
      _logins = logins;
      _loading = false;
    });
  }

  Future<void> _toggle(String provider, bool linked) async {
    setState(() => _busy = provider);
    String? error;
    try {
      if (linked) {
        final unlink = widget.unlink ?? ApiService().unlinkExternalLogin;
        error = await unlink(provider);
      } else {
        final obtainToken = widget.obtainToken ?? OAuthService().providerToken;
        final token = await obtainToken(provider);
        if (token != null) {
          final link = widget.link ?? ApiService().linkExternalLogin;
          error = await link(provider, token);
        }
      }
    } catch (e) {
      error = 'Sign-in was cancelled or failed.';
    }
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
    setState(() => _busy = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: Bounceable(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Color(0xFF0D3B66),
            ),
          ),
        ),
        title: Text(
          "Security & Login",
          style: GoogleFonts.outfit(
            color: const Color(0xFF0D3B66),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logins == null
              ? Center(
                  child: Text(
                    'Could not load your sign-in accounts.',
                    style: GoogleFonts.outfit(color: Colors.grey.shade600),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      'Sign in with these accounts as well as your password.',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 20),
                    for (final (key, name, icon, color) in _providers)
                      _providerTile(key, name, icon, color),
                  ],
                ),
    );
  }

  Widget _providerTile(String key, String name, IconData icon, Color color) {
    final linked = _logins!.isLinked(key);
    final busy = _busy == key;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0D3B66),
                  ),
                ),
                Text(
                  linked ? 'Linked' : 'Not linked',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    color: linked ? const Color(0xFF2E9E6A) : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          busy
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  key: ValueKey('${linked ? 'unlink' : 'link'}-$key'),
                  onPressed: _busy == null ? () => _toggle(key, linked) : null,
                  child: Text(linked ? 'Unlink' : 'Link'),
                ),
        ],
      ),
    );
  }
}
