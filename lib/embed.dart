// FALCON INSIDE ANOTHER APP (23-11-2026, his word: "falcon seprate pn chalayla pahije … ani erp hr madeh pn chalayla pahije";
// "jas ki bgh erp app madhe apan mark in button diley te dable ki hr pn tya madhech open hot"). RCL's ERP / HR app opens FALCON
// here when the FALCON app is not on the phone: the SAME screens, the same database rules and server steps – this file only
// starts them with HR's pass (no second sign-in) and gives the way back to the app around it. The FALCON app itself (main.dart)
// does not use this file and is unchanged.
//   await falconStart();                       once, before the first screen (FALCON's database, settings, clock)
//   FalconInApp(pass: <HR's pass>, onLeave: …)  a page of the other app: FALCON's screens from /hr?p=<pass>
//   (25-11-2026) await falconWarm(<HR's pass>, who)  while the other app opens: started, signed in, his home read – then
//   FalconInApp(pass: '', …) opens straight on FALCON's home (falconWarmFor(who)); falconForget() when he signs out there.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;

import 'config.dart';
import 'core/clock.dart';
import 'core/db.dart' show sb;
import 'core/net.dart' show startNet, supabaseHttp;
import 'core/prefs.dart';
import 'core/session.dart';
import 'routes.dart';
import 'screens/employee.dart' show homeData;
import 'screens/from_hr.dart' show passShape, signInFromHr;
import 'ui/look.dart';
import 'ui/net.dart' show NetHost;

/// true while FALCON runs inside another app – its pictures are then read from this package's files, the "back to the app"
/// line is shown on FALCON's home pages, and FALCON's own sign-up pages are not offered.
bool falconEmbedded = false;

/// The way back to the app around FALCON (set by FalconInApp).
VoidCallback? falconLeave;

/// This package's name – the other app finds FALCON's pictures under it.
const falconPackage = 'falcon';

/// The package for a picture of FALCON's own files: null in the FALCON app, 'falcon' inside another app.
String? get assetPackage => falconEmbedded ? falconPackage : null;

/// The pages where FALCON starts (a person's home): there "back" leaves FALCON.
const falconHomes = ['/', '/app', '/owner', '/driver', '/guest'];

bool _started = false;
Session? _session;

/// Can FALCON open here? (the app around it was built with FALCON's settings – else it opens FALCON's web as before)
bool get falconReady => Config.ready;

/// FALCON's database, settings and clock – once.
Future<void> falconStart() async {
  falconEmbedded = true;
  if (_started) return;
  if (Config.ready) {
    await Supabase.initialize(url: Config.supabaseUrl, anonKey: Config.supabaseKey, httpClient: supabaseHttp()); // (SNI) measured
    startNet();
  }
  await Prefs.init();
  keepClock();
  _session = Session()..start();
  _started = true;
}

String _warmWho = '';

/// (25-11-2026, his word: "hr aso erp aso app open zalel zale tyache maghe auto falcon pn on hoil jene krun user jewa hr or erp madhun
/// mess order kade jato tya weli ek screen yete falcon opening chi ti yenar nahi") FALCON made ready BEHIND the other app as it opens:
/// started, signed in with HR's pass (as the page /hr does), his person and his home read – so Mess opens straight on FALCON's home.
/// [who]: the person of the other app (his sign-in there). true = ready. Nothing is shown; a failure leaves the page /hr to do it.
Future<bool> falconWarm(String pass, String who) async {
  await falconStart();
  if (!Config.ready || !passShape.hasMatch(pass) || who.isEmpty) return false;
  try {
    await signInFromHr(pass);
    await _session!.load();
    if (_session!.me == null) return false;
    _warmWho = who;
    try {
      await homeData(_session!);
    } catch (_) {/* the home reads it when opened */}
    return true;
  } catch (_) {
    _warmWho = '';
    return false;
  }
}

/// FALCON is ready for [who] (signed in by [falconWarm] in this run of the app, still signed in).
bool falconWarmFor(String who) => _started && who.isNotEmpty && who == _warmWho && sb.auth.currentSession != null && _session?.me != null;

/// He signed out of the other app: FALCON's sign-in on this phone ends too.
Future<void> falconForget() async {
  _warmWho = '';
  if (!_started) return;
  try {
    await sb.auth.signOut();
  } catch (_) {/* signed out already */}
}

/// FALCON's screens as one page of the other app, opened with HR's pass – or, made ready by [falconWarm] (pass ''), on its home.
class FalconInApp extends StatefulWidget {
  const FalconInApp({super.key, required this.pass, required this.onLeave});
  final String pass;
  final VoidCallback onLeave;
  @override
  State<FalconInApp> createState() => _FalconInAppState();
}

class _FalconInAppState extends State<FalconInApp> {
  late final Session session = _session ?? (Session()..start());
  late final GoRouter router = buildRouter(session, initial: widget.pass.isEmpty ? '/' : '/hr?p=${Uri.encodeQueryComponent(widget.pass)}');

  @override
  void initState() {
    super.initState();
    falconEmbedded = true;
    falconLeave = widget.onLeave;
  }

  @override
  void dispose() {
    if (falconLeave == widget.onLeave) falconLeave = null;
    router.dispose();
    super.dispose();
  }

  /// The phone's back: a page back inside FALCON; on a page of its own, FALCON's home; on the home, out to the app around it.
  void _back() {
    if (router.canPop()) {
      router.pop();
      return;
    }
    final at = router.routerDelegate.currentConfiguration.uri.path;
    if (falconHomes.contains(at) || at == '/hr' || at.startsWith('/start')) {
      widget.onLeave();
    } else {
      router.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: SessionScope(
        session: session,
        child: MaterialApp.router(
          title: 'FALCON',
          debugShowCheckedModeBanner: false,
          theme: falconTheme(),
          routerConfig: router,
          builder: (context, child) => NetHost(child: child ?? const SizedBox()), // (SNI)
        ),
      ),
    );
  }
}

/// On a FALCON home inside another app: one line at the top – back to that app.
class LeaveLine extends StatelessWidget {
  const LeaveLine({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final leave = falconLeave;
    if (!falconEmbedded || leave == null) return const SizedBox.shrink();
    final c = dark ? Colors.white : C.ink;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: const Key('falcon-leave'),
          onPressed: leave,
          style: TextButton.styleFrom(foregroundColor: c, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), minimumSize: Size.zero),
          icon: Icon(Icons.chevron_left_rounded, size: 20, color: c),
          label: Text('Back to RCL app', style: T.lbl.copyWith(color: c)),
        ),
      ),
    );
  }
}
