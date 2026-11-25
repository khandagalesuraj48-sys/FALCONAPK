/* (25-11-2026 – SNI, his approval: "he sagle tu dilel screen pn ok aahet asch banaw … wifi ki mobile data as nko olkhayla") THE
 * NETWORK, AS MEASURED – the same monitor as the ERP app's (rcl-mobile core/net.dart), for FALCON's own servers:
 *   – fed ONLY by the app's own requests: Supabase's (its client – Supabase.initialize httpClient), FALCON's server steps (api(),
 *     the clock) and the live updates' own heartbeat (every 25 s while a live screen is open – realtime_client's onHeartbeat);
 *   – the rules: the last 10 answers of the last 2 minutes – middle time under 800 ms GOOD, 800 ms or more (or one over 5 s) WEAK,
 *     2 failures UNSTABLE; no answer → RECONNECTING while Android's own check (connectivitycheck.gstatic.com/generate_204) is asked:
 *     it answers → SERVER DOWN, it fails too → OFFLINE; a better state shows after it held 3 s;
 *   – idle in front for 30 s: one small request to FALCON's server (/api/start); in the background nothing.
 * Nothing guessed, nothing random, no Wi-Fi / mobile reading, no new plugin – Dart only (a Shorebird patch). */
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase, RealtimeHeartbeatStatus;

import '../config.dart';


enum NetEnd { ok, serverError, timeout, noConnection }

/// From the best to the worst (the indicator shows the worst server); [checking] = nothing measured yet.
enum NetState { checking, good, weak, unstable, reconnecting, serverDown, offline }

int _bad(NetState s) => const {NetState.checking: -1, NetState.good: 0, NetState.weak: 1, NetState.unstable: 2, NetState.reconnecting: 3, NetState.serverDown: 4, NetState.offline: 5}[s]!;

class NetMark {
  NetMark(this.at, this.ms, this.end);
  final DateTime at;
  final int ms;
  final NetEnd end;
  bool get ok => end == NetEnd.ok;
}

/// FALCON speaks English (the words of the approved designs).
String w3(String en, String mr, String hi) => en;

/// "240 ms", "1.8 s".
String msText(int ms) => ms < 1000 ? '$ms ms' : '${(ms / 1000).toStringAsFixed(1)} s';

class NetMonitor extends ChangeNotifier {
  NetMonitor();
  static NetMonitor i = NetMonitor();

  /// Off in the tests (and in the background alarm): nothing is recorded, nothing is asked. main.dart switches it on.
  bool on = false;
  DateTime Function() now = DateTime.now;

  /// Android's own check: its time in ms, or null = no internet. A test puts its own.
  Future<int?> Function() internetCheck = _gstatic;

  /// One small request to FALCON's server (set by the app: its /api/start – the clock's own step).
  Future<void> Function()? probe;

  static const window = Duration(minutes: 2), keepLast = 10, hold = Duration(seconds: 3), idle = Duration(seconds: 30), slowAfter = Duration(seconds: 5);

  final Map<String, List<NetMark>> _marks = {};
  final Map<int, (String, DateTime)> _going = {};
  int _seq = 0;

  bool? internet;
  DateTime? internetAt;
  int? internetMs;
  bool _checking = false;
  DateTime? _checkedAt;
  bool _probing = false;

  NetState _shown = NetState.checking;
  Timer? _holdT;

  /// When the indicator last changed, and from what (the sheet: "Last change").
  DateTime? changedAt;
  NetState? changedFrom;

  NetState get state => _shown;

  /// The servers measured in the last 2 minutes.
  List<String> get servers => [for (final e in _marks.entries) if (recent(e.key).isNotEmpty) e.key];

  /// The last 10 answers of [server] in the last 2 minutes (oldest first).
  List<NetMark> recent(String server) {
    final t = now().subtract(window);
    final l = (_marks[server] ?? const <NetMark>[]).where((m) => m.at.isAfter(t)).toList();
    return l.length > keepLast ? l.sublist(l.length - keepLast) : l;
  }

  DateTime? get lastAt {
    DateTime? a;
    for (final l in _marks.values) {
      if (l.isNotEmpty && (a == null || l.last.at.isAfter(a))) a = l.last.at;
    }
    return a;
  }

  static int? _middle(List<int> xs) {
    if (xs.isEmpty) return null;
    final s = [...xs]..sort();
    return s.length.isOdd ? s[s.length ~/ 2] : ((s[s.length ~/ 2 - 1] + s[s.length ~/ 2]) / 2).round();
  }

  /// The middle time of [server]'s answers (null: none in the last 2 minutes).
  int? middleMs(String server) => _middle([for (final m in recent(server)) if (m.ok) m.ms]);

  /// The middle time of every answer of the last 2 minutes.
  int? get middleAll => _middle([for (final s in servers) for (final m in recent(s)) if (m.ok) m.ms]);

  /// The state of one server by the rules (above).
  NetState stateOf(String server) {
    final m = recent(server);
    if (m.isEmpty) return NetState.checking;
    final last = m.last;
    if (!last.ok) {
      if (last.end == NetEnd.timeout || last.end == NetEnd.noConnection) {
        final at = internetAt;
        final checked = at != null && (!at.isBefore(last.at) || now().difference(at) < const Duration(seconds: 15));
        if (!checked) return NetState.reconnecting;
        return internet == true ? NetState.serverDown : NetState.offline;
      }
      var trail = 0;
      for (final x in m.reversed) {
        if (x.ok) break;
        trail++;
      }
      if (trail >= 2) return NetState.serverDown;
    }
    if (m.where((x) => !x.ok).length >= 2) return NetState.unstable;
    final oks = [for (final x in m) if (x.ok) x.ms];
    if (oks.isEmpty) return NetState.unstable;
    final mid = _middle(oks)!;
    if (mid >= 800 || oks.any((x) => x > 5000)) return NetState.weak;
    return NetState.good;
  }

  /// The worst server of the last 2 minutes (and which one).
  (NetState, String) get worst {
    var w = NetState.checking;
    var who = '';
    for (final s in servers) {
      final x = stateOf(s);
      if (_bad(x) > _bad(w)) {
        w = x;
        who = s;
      }
    }
    return (w, who);
  }

  /// A request on its way for longer than 5 s (the "slow network" line): its age, or null.
  Duration? get slowest {
    Duration? d;
    final t = now();
    for (final g in _going.values) {
      final a = t.difference(g.$2);
      if (a >= slowAfter && (d == null || a > d)) d = a;
    }
    return d;
  }

  /// One answer of [server]: [ms] long, ended as [end].
  void record(String server, int ms, NetEnd end) {
    if (!on || server.isEmpty) return;
    final l = _marks.putIfAbsent(server, () => <NetMark>[]);
    l.add(NetMark(now(), ms, end));
    if (l.length > 40) l.removeRange(0, l.length - 40);
    if (end == NetEnd.timeout || end == NetEnd.noConnection) unawaited(checkInternet());
    update();
  }

  /// Watches one request of [server] (Api's client): its time to the answer; a timeout after [limit] (a later answer is not counted).
  Future<T> watch<T>(String server, Future<T> f, Duration limit, {int Function(T r)? status}) {
    if (!on || server.isEmpty) return f;
    final id = ++_seq;
    final t0 = now();
    _going[id] = (server, t0);
    var done = false;
    final timer = Timer(limit, () {
      if (done) return;
      done = true;
      _going.remove(id);
      record(server, limit.inMilliseconds, NetEnd.timeout);
    });
    void end(NetEnd e) {
      if (done) return;
      done = true;
      timer.cancel();
      _going.remove(id);
      record(server, now().difference(t0).inMilliseconds, e);
    }

    Future<T> run() async {
      try {
        final r = await f;
        final st = status == null ? 200 : status(r);
        end(st >= 500 ? NetEnd.serverError : NetEnd.ok);
        return r;
      } catch (_) {
        end(NetEnd.noConnection);
        rethrow;
      }
    }

    return run();
  }

  /// Android's check (at most once in 10 s; "Check now" asks it at once).
  Future<void> checkInternet({bool now0 = false}) async {
    if (!on || _checking) return;
    final c = _checkedAt;
    if (!now0 && c != null && now().difference(c) < const Duration(seconds: 10)) return;
    _checking = true;
    try {
      final ms = await internetCheck();
      internet = ms != null;
      internetMs = ms;
      internetAt = now();
      _checkedAt = internetAt;
    } finally {
      _checking = false;
      update();
    }
  }

  /// Every 5 s while the app is in front (NetHost): the 2 minutes move on; idle for 30 s → one small request to FALCON's server.
  void tick() {
    if (!on) return;
    update();
    final a = lastAt;
    if (_probing || probe == null || (a != null && now().difference(a) < idle)) return;
    _probing = true;
    probe!().catchError((Object _) {}).whenComplete(() => _probing = false);
  }

  /// "Check now" (the sheet): FALCON's server and Android's check, at once.
  Future<void> checkNow() async {
    if (!on) return;
    final p = probe;
    await Future.wait([if (p != null) p().catchError((Object _) {}), checkInternet(now0: true)]);
  }

  /// The state shown: worse at once; better / weak / unstable after it held 3 s.
  void update() {
    final c = worst.$1;
    if (c == _shown) {
      _holdT?.cancel();
      _holdT = null;
      notifyListeners();
      return;
    }
    final atOnce = _shown == NetState.checking || c == NetState.reconnecting || c == NetState.serverDown || c == NetState.offline;
    if (atOnce) {
      _show(c);
      return;
    }
    _holdT ??= Timer(hold, () {
      _holdT = null;
      final again = worst.$1;
      if (again != _shown) _show(again);
    });
    notifyListeners();
  }

  void _show(NetState s) {
    _holdT?.cancel();
    _holdT = null;
    changedFrom = _shown;
    changedAt = now();
    _shown = s;
    notifyListeners();
  }

  /// For the tests: everything forgotten.
  @visibleForTesting
  void reset() {
    _marks.clear();
    _going.clear();
    internet = null;
    internetAt = null;
    internetMs = null;
    _checkedAt = null;
    _checking = false;
    _probing = false;
    _holdT?.cancel();
    _holdT = null;
    _shown = NetState.checking;
    changedAt = null;
    changedFrom = null;
  }
}

/// Android's own check address (generate_204): its time, or null when it does not answer with 204 within 6 s.
Future<int?> _gstatic() async {
  final c = http.Client();
  final sw = Stopwatch()..start();
  try {
    final r = await c.get(Uri.parse('https://connectivitycheck.gstatic.com/generate_204')).timeout(const Duration(seconds: 6));
    return r.statusCode == 204 ? sw.elapsedMilliseconds : null;
  } catch (_) {
    return null;
  } finally {
    c.close();
  }
}

/// The app's client (Supabase's and FALCON's server's): each request is measured ([serverOf] names it – '' = not ours).
class NetClient extends http.BaseClient {
  NetClient(this._inner, this.serverOf, this.limit);
  final http.Client _inner;
  final String Function(Uri u) serverOf;
  final Duration limit;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    final f = _inner.send(request);
    final key = serverOf(request.url);
    if (key.isEmpty) return f;
    return NetMonitor.i.watch<http.StreamedResponse>(key, f, limit, status: (r) => r.statusCode);
  }

  @override
  void close() => _inner.close();
}

/// The name of a server in the sheet.
String serverName(String key, [String site = '']) => switch (key) {
      'db' => 'FALCON database',
      'server' => 'FALCON server',
      'live' => 'Live updates',
      _ => key,
    };

/// Which of FALCON's servers [u] is: 'db' (its Supabase), 'server' (its Vercel steps); '' = not ours.
String falconServerOf(Uri u) {
  final s = u.toString();
  if (Config.supabaseUrl.isNotEmpty && s.startsWith(Config.supabaseUrl)) return 'db';
  if (Config.server.isNotEmpty && s.startsWith(Config.server)) return 'server';
  return '';
}

/// The client of FALCON's server steps (api(), the clock) – measured.
final http.Client netHttp = NetClient(http.Client(), falconServerOf, const Duration(seconds: 25));

/// The client given to Supabase (its reads, its functions, its files, its sign-in) – measured.
http.Client supabaseHttp() => NetClient(http.Client(), falconServerOf, const Duration(seconds: 30));

bool _wired = false;
DateTime? _beatAt;

/// Switches the monitor on (the app's start, also inside RCL's app): the idle request is FALCON's /api/start; the live updates'
/// own heartbeat (every 25 s while a live screen is open) is measured too.
void startNet() {
  if (_wired) return;
  _wired = true;
  NetMonitor.i
    ..on = true
    ..probe = () async {
      await netHttp.get(Uri.parse('${Config.server}/api/start')).timeout(const Duration(seconds: 15));
    };
  try {
    Supabase.instance.client.realtime.onHeartbeat.listen((s) {
      final now = NetMonitor.i.now();
      switch (s) {
        case RealtimeHeartbeatStatus.sent:
          _beatAt = now;
        case RealtimeHeartbeatStatus.ok:
          final a = _beatAt;
          if (a != null) NetMonitor.i.record('live', now.difference(a).inMilliseconds, NetEnd.ok);
          _beatAt = null;
        case RealtimeHeartbeatStatus.timeout:
          NetMonitor.i.record('live', 25000, NetEnd.timeout);
          _beatAt = null;
        case RealtimeHeartbeatStatus.error:
          NetMonitor.i.record('live', 0, NetEnd.serverError);
          _beatAt = null;
      }
    });
  } catch (_) {/* Supabase not started (the "not connected yet" page): nothing to listen to */}
}
