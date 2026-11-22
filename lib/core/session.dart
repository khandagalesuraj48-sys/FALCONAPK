// Who is signed in, his roles and sites – the same as the web's src/lib/session.tsx. The database checks again on every read and
// action; this only decides which screens to show.
import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'db.dart';
import 'fmt.dart';

enum Status { loading, off, signedout, noperson, ready, stopped }

const staffRoles = ['mess_owner', 'mess_operator', 'mess_supervisor', 'driver', 'site_admin', 'accounts', 'management', 'system_admin'];
const officeRoles = ['system_admin', 'management', 'accounts', 'site_admin', 'mess_supervisor'];

class Grant {
  Grant(Rec r) : role = '${r['role']}', siteId = r['site_id'] as String?, messId = r['mess_id'] as String?, from = '${r['valid_from']}', to = r['valid_to'] as String?;
  final String role, from;
  final String? siteId, messId, to;
}

class Site {
  Site(Rec r) : id = '${r['id']}', code = '${r['code']}', name = '${r['name']}';
  final String id, code, name;
}

class Home {
  const Home(this.path, this.label, this.icon);
  final String path, label, icon;
}

class Session extends ChangeNotifier {
  Status status = Config.ready ? Status.loading : Status.off;
  Rec? me;
  List<Grant> grants = [];
  List<Site> sites = [];
  String companyCode = '';
  bool needsCode = false;
  StreamSubscription<AuthState>? _sub;

  String? get personId => me?['id'] as String?;
  String get state => '${me?['state'] ?? ''}';
  String get kind => '${me?['kind'] ?? ''}';
  String get name => '${me?['full_name'] ?? ''}';
  String? get homeSiteId => me?['home_site_id'] as String?;
  Site? get homeSite => sites.where((s) => s.id == homeSiteId).firstOrNull;

  Set<String> get roles {
    final r = grants.map((g) => g.role).toSet();
    if (kind == 'employee') r.add('employee');
    if (kind == 'guest') r.add('guest');
    return r;
  }

  bool has(Object r, {String? site}) {
    final want = r is List ? r.map((x) => '$x').toList() : ['$r'];
    return want.any((w) => (w == 'employee' || w == 'guest')
        ? roles.contains(w)
        : grants.any((g) => g.role == w && (site == null || g.siteId == null || g.siteId == site)));
  }

  bool get isStaff => staffRoles.any(roles.contains);

  /// Where a person starts: his own part of FALCON by his roles (more than one → he chooses). The office's pages are the web's.
  List<Home> homes() {
    final r = roles, out = <Home>[];
    if (r.contains('mess_owner') || r.contains('mess_operator')) out.add(const Home('/owner', 'My mess', 'chef-hat'));
    if (r.contains('driver')) out.add(const Home('/driver', 'My deliveries', 'truck'));
    if (r.contains('employee')) out.add(const Home('/app', 'My meals', 'utensils'));
    if (r.contains('guest')) out.add(const Home('/guest', 'Guest', 'users'));
    if (officeRoles.any(r.contains)) out.add(const Home('web', 'Office (on the web)', 'layout-grid'));
    return out;
  }

  void start() {
    if (!Config.ready) return;
    _sub = sb.auth.onAuthStateChange.listen((s) {
      if (s.event == AuthChangeEvent.signedIn || s.event == AuthChangeEvent.signedOut || s.event == AuthChangeEvent.userUpdated) {
        unawaited(load());
      }
    });
    unawaited(load());
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> refresh() => load();

  Future<void> signOut() async {
    await sb.auth.signOut();
    await load();
  }

  Future<void> load() async {
    try {
      final s = sb.auth.currentSession;
      if (s == null) {
        me = null; grants = []; status = Status.signedout; notifyListeners(); return;
      }
      var p = await one(sb.from('people').select().eq('auth_user_id', s.user.id).limit(1));
      if (p == null && (s.user.phone ?? '').isNotEmpty) {
        // signed in, not in FALCON yet: an active HR employee is known by his mobile; the first System Admin is made
        try {
          final w = await api('/api/welcome', {});
          if (w['person'] != null) p = await one(sb.from('people').select().eq('auth_user_id', s.user.id).limit(1));
        } catch (_) {/* he registers */}
      }
      if (p == null) {
        final st = await call<dynamic>('my_standing');
        if (st is Map) {
          me = {'full_name': st['name'], 'state': st['state'], 'state_reason': st['reason'], 'temporary_until': st['until']};
          status = Status.stopped; notifyListeners(); return;
        }
        me = null; status = Status.noperson; notifyListeners(); return;
      }
      final stt = '${p['state']}';
      final until = p['temporary_until'] as String?;
      if (stt == 'rejected' || stt == 'suspended' || (stt == 'temporary' && until != null && until.compareTo(today()) < 0)) {
        me = p; status = Status.stopped; notifyListeners(); return;
      }
      final res = await Future.wait([
        rows(sb.from('role_grants').select('id,role,site_id,mess_id,valid_from,valid_to').eq('person_id', p['id'] as String).isFilter('revoked_at', null)),
        rows(sb.from('sites').select('id,code,name').eq('active', true).order('code')),
        rows(sb.from('companies').select('code').limit(1)),
      ]);
      final t = today();
      grants = res[0].map(Grant.new).where((g) => g.from.compareTo(t) <= 0 && (g.to == null || g.to!.compareTo(t) >= 0)).toList();
      sites = res[1].map(Site.new).toList();
      companyCode = res[2].isEmpty ? '' : '${res[2].first['code']}';
      me = p;
      status = Status.ready;
      notifyListeners();
      if (p['portal_user'] == null) {
        try {
          final d = await api('/api/device', {'device_hash': await deviceHash()});
          needsCode = d['code_needed'] == true;
        } catch (_) {
          needsCode = false;
        }
        notifyListeners();
      }
    } catch (e) {
      // no network at the start: keep what was there; a person without any data sees the sign-in
      if (me == null) status = sb.auth.currentSession == null ? Status.signedout : Status.noperson;
      notifyListeners();
    }
  }
}

/// This phone's own random token – only its fingerprint (SHA-256) leaves the phone; it only SUGGESTS who is there.
Future<String> deviceHash() async {
  final p = await SharedPreferences.getInstance();
  var t = p.getString('falcon.device') ?? '';
  if (t.isEmpty) {
    final r = Random.secure();
    t = List.generate(32, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await p.setString('falcon.device', t);
  }
  return sha256.convert(utf8.encode(t)).toString();
}

/// The session for the whole app.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);
  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;
  static Session read(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}
