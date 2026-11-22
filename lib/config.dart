import 'dart:convert';

// FALCON's settings, given when the app is built (GitHub → Settings → Secrets and variables → Actions → Variables):
//   FALCON_SUPABASE_URL   FALCON's own Supabase project (https://<ref>.supabase.co)
//   FALCON_SUPABASE_KEY   its PUBLISHABLE key – public by design (the web page carries the same); never the secret key
//   FALCON_SERVER         FALCON's web address – its server steps (/api/…) are there
//   FALCON_COMPANY        the company (RCL)
// Nothing secret is in the app: what a person may see and do is decided by the database's own rules and FALCON's server.
class Config {
  static const supabaseUrl = String.fromEnvironment('FALCON_SUPABASE_URL');
  static const supabaseKey = String.fromEnvironment('FALCON_SUPABASE_KEY');
  static const server = String.fromEnvironment('FALCON_SERVER', defaultValue: 'https://wolf-rcl-erp.vercel.app');
  static const company = String.fromEnvironment('FALCON_COMPANY', defaultValue: 'RCL');
  static const version = String.fromEnvironment('FALCON_VERSION', defaultValue: '1.0.0');

  static final _url = RegExp(r'^https://[a-z0-9-]+\.supabase\.co$');

  /// What is missing or wrong – the app then opens the "not connected yet" page.
  static List<String> problems() {
    final p = <String>[];
    if (!_url.hasMatch(supabaseUrl)) p.add('FALCON_SUPABASE_URL');
    // a secret key must never be in an app: Supabase's secret keys start "sb_secret_"; an old service key says "service_role"
    if (supabaseKey.isEmpty || supabaseKey.startsWith('sb_secret_') || roleOf(supabaseKey) == 'service_role') p.add('FALCON_SUPABASE_KEY');
    if (!server.startsWith('https://')) p.add('FALCON_SERVER');
    return p;
  }

  static bool get ready => problems().isEmpty;

  /// The "role" written inside an old-style Supabase key (a JWT), or '' – read only to refuse a secret key.
  static String roleOf(String key) {
    final parts = key.split('.');
    if (parts.length < 2) return '';
    try {
      final j = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      return j is Map && j['role'] is String ? j['role'] as String : '';
    } catch (_) {
      return '';
    }
  }
}
