/* THE UPDATE FROM INSIDE THE APP (23-11-2026, his word: "app madhech in app update karaych ahe pratek veli new nahi download krnar ani
 * ha same hr app erp app update kashi hote tas karaych aahe") – the same as the ERP app's (rcl-mobile lib/core/update.dart):
 *   * the app looks at the newest RELEASE of this repository (GitHub "latest" – a release of main; a test build is a pre-release and
 *     never offered). The release carries the APK and, in its notes, its build number and fingerprint (SHA-256):
 *       <!-- falcon:{"build":42,"version":"1.0.0","sha256":"…","apk":{"arm64-v8a":"…","armeabi-v7a":"…"}} -->
 *     and one APK per processor: a phone downloads only its own (about half of the file for every phone);
 *   * OFFERED, NEVER FORCED (the ERP's rule since 19-11-2026): at every opening of the app (started, or back after 10 minutes away) a
 *     newer version is offered – "Update to …?" with Update / Close; what is new is shown (between <!-- falcon-new --> and
 *     <!-- /falcon-new --> of the notes);
 *   * Update: Android's own Download Manager downloads it in the background (UpdateKit.kt) – the app is used meanwhile, and it goes on
 *     when the app is left or closed, never again from 0; when it is there and its fingerprint is right: "Install?" over whatever screen
 *     is open (or the notification "Update ready – tap to install" when the app is away). Later: asked again at the next opening;
 *   * Android installs it only when it carries the SAME key as the app on the phone – FALCON's permanent key (build.yml).
 * No network, or GitHub not reached: nothing is known – the app works on. iPhone: not made yet. */
import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../ui/kit.dart';
import '../ui/look.dart';

const kReleasesApi = 'https://api.github.com/repos/khandagalesuraj48-sys/FALCONAPK/releases/latest';

class AppUpdate {
  const AppUpdate({required this.build, required this.version, this.notes = '', this.url = '', this.sha256 = ''});
  final int build;
  final String version, notes, url, sha256;
}

/// This app's version and build ('' / 0 when the phone does not say).
Future<(String, int)> appVersion() async {
  try {
    final p = await PackageInfo.fromPlatform();
    return (p.version, int.tryParse(p.buildNumber) ?? 0);
  } catch (_) {
    return ('', 0);
  }
}

/// The processor this app runs on – its own file of the release; '' = not known (the file for every phone).
String Function() appAbi = () => switch (Abi.current()) { Abi.androidArm64 => 'arm64-v8a', Abi.androidArm => 'armeabi-v7a', _ => '' };

/// The ends of the one-processor files – never taken as the file for every phone.
const kAbiFiles = ['.arm64-v8a.apk', '.armeabi-v7a.apk', '.x86_64.apk'];

final _sha = RegExp(r'^[0-9a-f]{64}$');

/// The update in a GitHub Release (its JSON from the GitHub API) when it is newer than [currentBuild] – else null.
AppUpdate? parseRelease(Map<String, dynamic> j, int currentBuild) {
  final m = RegExp(r'<!-- falcon:(\{.*?\}) -->').firstMatch('${j['body'] ?? ''}');
  if (m == null || j['draft'] == true || j['prerelease'] == true) return null;
  Map<String, dynamic> meta;
  try {
    meta = (jsonDecode(m.group(1)!) as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
  final b = meta['build'], sha = '${meta['sha256'] ?? ''}'.toLowerCase();
  if (b is! num || b <= currentBuild || !_sha.hasMatch(sha)) return null;
  final assets = (j['assets'] as List? ?? const []).whereType<Map>().toList();
  String name(Map a) => '${a['name'] ?? ''}'.toLowerCase();
  String link(Map a) => '${a['browser_download_url'] ?? ''}';
  AppUpdate made(String url, String fingerprint) => AppUpdate(build: b.toInt(), version: '${meta['version'] ?? ''}', notes: releaseNotes(j), url: url, sha256: fingerprint);
  // a phone: its own processor's file, when the release has it
  final abi = appAbi(), own = meta['apk'];
  if (abi.isNotEmpty && own is Map) {
    final osha = '${own[abi] ?? ''}'.toLowerCase(), f = assets.firstWhere((a) => name(a).endsWith('.$abi.apk'), orElse: () => const {});
    if (_sha.hasMatch(osha) && link(f).startsWith('https://github.com/')) return made(link(f), osha);
  }
  final file = assets.firstWhere((a) => name(a).endsWith('.apk') && !kAbiFiles.any(name(a).endsWith), orElse: () => const {});
  return link(file).startsWith('https://github.com/') ? made(link(file), sha) : null;
}

/// What is new in the release (as written); a release without it: its name.
String releaseNotes(Map<String, dynamic> j) {
  final m = RegExp(r'<!-- falcon-new -->([\s\S]*?)<!-- /falcon-new -->').firstMatch('${j['body'] ?? ''}');
  final t = (m?.group(1) ?? '').replaceAll('\r', '').trim();
  return t.isNotEmpty ? t : '${j['name'] ?? ''}';
}

/// (a test) GitHub's answer
Future<http.Response> Function(Uri u) releasesGet = (u) => http.get(u, headers: const {'Accept': 'application/vnd.github+json'}).timeout(const Duration(seconds: 15));

/// A newer version than the one on this phone, or null (also when it cannot be asked – the app works on).
Future<AppUpdate?> checkUpdate() async {
  if (!Platform.isAndroid) return null;
  try {
    final (_, mine) = await appVersion();
    final r = await releasesGet(Uri.parse(kReleasesApi));
    if (r.statusCode != 200) return null;
    return parseRelease((jsonDecode(utf8.decode(r.bodyBytes)) as Map).cast<String, dynamic>(), mine);
  } catch (_) {
    return null;
  }
}

// ── offered at every opening ──
const kOfferAgainAfter = Duration(minutes: 10);
bool _offered = false; // asked in this opening
DateTime? _awaySince;

/// The app was left (paused) – an opening is counted again when it comes back after [kOfferAgainAfter].
void updateAway() => _awaySince ??= DateTime.now();

/// The app came back: away long enough – a new opening: the update is offered again ([offerAgain]).
void updateBack(void Function() offerAgain, {DateTime? now}) {
  final a = _awaySince;
  _awaySince = null;
  if (a != null && (now ?? DateTime.now()).difference(a) >= kOfferAgainAfter) {
    _offered = false;
    offerAgain();
  }
}

/// (a test) a new opening
void resetUpdateOffer() {
  _offered = false;
  _awaySince = null;
}

/// Looks for a newer version and offers it – once in an opening; nothing while a download of it goes on or is ready.
Future<void> offerNewest() async {
  if (_offered || !bgUpdates()) return;
  final u = await checkUpdate();
  final ctx = updateContext();
  if (u == null || _offered || ctx == null || !ctx.mounted) return;
  _offered = true;
  final s = await _bgState();
  if (s != null && s.build == u.build && (s.going || s.status == 'done')) return;
  final c = updateContext();
  if (c != null && c.mounted) await runUpdate(c, u);
}

/// A question with two buttons in FALCON's look; true = [yes].
Future<bool> _ask(BuildContext context, String title, String text, {String notes = '', String yes = 'OK', String no = 'Close'}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      title: Text(title, style: T.h2),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text, style: T.sm.copyWith(height: 1.45)),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(14)),
              child: Text(notes, style: T.sm.copyWith(color: C.ink, height: 1.45))),
        ],
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.of(c).pop(false), child: Text(no, style: T.b.copyWith(color: C.muted))),
        FilledButton(onPressed: () => Navigator.of(c).pop(true), style: FilledButton.styleFrom(backgroundColor: C.leaf), child: Text(yes, style: T.b.copyWith(color: Colors.white))),
      ],
    ),
  );
  return r == true;
}

/// "Update to …?" – Update: the download in the background (or, where Android's Download Manager cannot be used, inside the app).
Future<void> runUpdate(BuildContext context, AppUpdate u) async {
  final s = await _bgState();
  if (!context.mounted) return;
  if (s != null && s.build == u.build && s.sha.toLowerCase() == u.sha256.toLowerCase() && (s.going || s.status == 'done')) {
    _bgLater = 0;
    await updateWatch();
    if (s.going && context.mounted) _bgDialog(context);
    return;
  }
  final ok = await _ask(context, 'Update to ${u.version}?',
      'The update downloads in the background – keep working, or leave the app. When it is ready, the app asks you to install it.\n\n'
          'अपडेट मागे (background ला) डाउनलोड होईल – काम चालू ठेवा किंवा ॲपमधून बाहेर जा. तयार झाले की ॲप install विचारेल.',
      notes: u.notes, yes: 'Update', no: 'Close');
  if (!ok || !context.mounted) return;
  final bg = await startBgUpdate(u);
  if (!context.mounted) return;
  if (bg != 'failed') {
    if (bg != 'done') _bgDialog(context);
    return;
  }
  // a phone whose Download Manager cannot be used: the download inside the app
  final progress = ValueNotifier<String>('Starting…');
  unawaited(showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      title: Text('Updating', style: T.h2),
      content: ValueListenableBuilder<String>(
        valueListenable: progress,
        builder: (_, v, _) => Column(mainAxisSize: MainAxisSize.min, children: [
          LinearProgressIndicator(value: double.tryParse(v) == null ? null : double.parse(v) / 100, color: C.leaf),
          const SizedBox(height: 12),
          Text(double.tryParse(v) == null ? v : 'Downloading… $v%', style: T.sm),
        ]),
      ),
    ),
  ));
  void close(String? msg) {
    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (msg != null) toast(context, msg);
  }

  try {
    OtaUpdate().execute(u.url, destinationFilename: 'falcon-${u.version}-${u.build}.apk', sha256checksum: u.sha256.isEmpty ? null : u.sha256).listen(
      (e) {
        switch (e.status) {
          case OtaStatus.DOWNLOADING:
            progress.value = e.value ?? '';
          case OtaStatus.INSTALLING:
          case OtaStatus.INSTALLATION_DONE:
          case OtaStatus.CANCELED:
            close(null);
          case OtaStatus.CHECKSUM_ERROR:
            close('The download was not complete or not genuine – nothing was installed. Try again.');
          case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            close('Allow "Install unknown apps" for FALCON in Android settings, then try again.');
          default:
            close('The update could not be finished (${e.status.name}). Try again.');
        }
      },
      onError: (_) => close('The update could not be downloaded – check the internet and try again.'),
    );
  } catch (_) {
    close('The update could not be started – try again.');
  }
}

/* ---------- the update in the background (Android – UpdateKit.kt) ---------- */

/// A download of an update kept by Android's Download Manager. [status]: pending | running | paused | done | failed | gone.
class BgUpdate {
  const BgUpdate({required this.status, this.got = 0, this.total = -1, this.path = '', this.version = '', this.build = 0, this.sha = ''});
  final String status, path, version, sha;
  final int got, total, build;
  bool get going => status == 'pending' || status == 'running' || status == 'paused';
  int get percent => total > 0 ? (got * 100 ~/ total).clamp(0, 100).toInt() : -1;

  /// From the phone's answer; null = no download kept.
  static BgUpdate? of(Object? m) {
    if (m is! Map || m['id'] == null) return null;
    int n(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
    return BgUpdate(status: '${m['status'] ?? 'gone'}', got: n(m['got']), total: m['total'] == null ? -1 : n(m['total']), path: '${m['path'] ?? ''}',
        version: '${m['version'] ?? ''}', build: n(m['build']), sha: '${m['sha'] ?? ''}');
  }
}

const _bgChannel = MethodChannel('falcon/update');

/// (a test) the phone's side (UpdateKit.kt)
Future<Object?> Function(String method, [Map<String, Object?>? args]) bgCall = (m, [a]) => _bgChannel.invokeMethod<Object?>(m, a);

/// (a test) the build of this app
Future<int> Function() appBuild = () async => (await appVersion()).$2;

/// (a test) a file's fingerprint (SHA-256), worked out in the background
Future<String> Function(String path) fileSha = (p) => Isolate.run(() async => (await sha256.bind(File(p).openRead()).first).toString());

/// (main.dart) the screen open now – the box "Install?" comes over it, whatever it is
BuildContext? Function() updateContext = () => null;

/// (a test) this phone's updates go through the Download Manager (Android)
bool Function() bgUpdates = () => Platform.isAndroid;

/// The background update now (the progress box listens to it); null = none.
final bgUpdateNow = ValueNotifier<BgUpdate?>(null);

Timer? _bgTimer;
bool _bgBusy = false, _bgAsking = false;
int _bgLater = 0; // the build put off with "Later" – asked again when the app is opened again
String _bgChecked = ''; // the file whose fingerprint was found right
DialogRoute<void>? _bgRoute; // the progress box

Future<BgUpdate?> _bgState() async {
  if (!bgUpdates()) return null;
  try {
    return BgUpdate.of(await bgCall('state'));
  } catch (_) {
    return null;
  }
}

Future<void> _bgForget() async {
  _bgChecked = '';
  try {
    await bgCall('forget');
  } catch (_) {/* nothing kept */}
}

void _bgStop() {
  _bgTimer?.cancel();
  _bgTimer = null;
}

void _bgClose() {
  final r = _bgRoute;
  _bgRoute = null;
  if (r != null && r.isActive) r.navigator?.removeRoute(r);
}

/// (a test) the watch stopped and forgotten
void resetBgUpdate() {
  _bgStop();
  _bgBusy = _bgAsking = false;
  _bgLater = 0;
  _bgChecked = '';
  _bgRoute = null;
  bgUpdateNow.value = null;
}

/// Starts the background download of [u] – or keeps the one already going (or done) for it: never again from 0.
/// → 'started' | 'going' | 'done' | 'failed' (the Download Manager cannot be used on this phone).
Future<String> startBgUpdate(AppUpdate u) async {
  if (!bgUpdates()) return 'failed';
  final s = await _bgState();
  if (s != null && s.build == u.build && s.sha.toLowerCase() == u.sha256.toLowerCase() && (s.going || s.status == 'done')) {
    _bgLater = 0;
    await updateWatch();
    return s.going ? 'going' : 'done';
  }
  try {
    await bgCall('start', {'url': u.url, 'file': 'falcon-${u.version}-${u.build}.apk', 'version': u.version, 'build': u.build, 'sha': u.sha256.toLowerCase()});
  } catch (_) {
    return 'failed';
  }
  _bgLater = 0;
  _bgChecked = '';
  await updateWatch();
  return 'started';
}

/// Looks at the background update – when the app is opened or comes back ([opened]: "Later" is asked again), and every 2 s while it
/// downloads. Ready and right → "Install?" over the screen that is open; gone wrong → said once (Update starts it again).
Future<void> updateWatch({bool opened = false}) async {
  if (!bgUpdates() || _bgBusy) return;
  _bgBusy = true;
  try {
    if (opened) _bgLater = 0;
    final s = await _bgState();
    if (s == null) {
      _bgStop();
      _bgClose();
      bgUpdateNow.value = null;
      return;
    }
    if (s.build <= await appBuild()) {
      // installed (or an older one): its file goes
      _bgStop();
      _bgClose();
      bgUpdateNow.value = null;
      await _bgForget();
      return;
    }
    bgUpdateNow.value = s;
    if (s.going) {
      _bgTimer ??= Timer.periodic(const Duration(seconds: 2), (_) => updateWatch());
      return;
    }
    _bgStop();
    _bgClose();
    if (s.status == 'done') {
      unawaited(_bgOffer(s));
      return;
    }
    await _bgForget();
    bgUpdateNow.value = null;
    final ctx = updateContext();
    if (ctx != null && ctx.mounted) toast(ctx, 'The update could not be downloaded – check the internet and try again.');
  } finally {
    _bgBusy = false;
  }
}

/// The download is there: its fingerprint checked (once), then "Install?" over the screen that is open.
Future<void> _bgOffer(BgUpdate s) async {
  if (_bgAsking || _bgLater == s.build) return;
  final ctx = updateContext();
  if (ctx == null || !ctx.mounted) return; // asked when a screen is there (the app opened again)
  _bgAsking = true;
  try {
    if (_bgChecked != s.path) {
      var got = '';
      try {
        got = await fileSha(s.path);
      } catch (_) {/* not readable: as not right */}
      if (s.sha.isEmpty || got.toLowerCase() != s.sha.toLowerCase()) {
        await _bgForget();
        bgUpdateNow.value = null;
        final c = updateContext();
        if (c != null && c.mounted) toast(c, 'The download was not complete or not genuine – nothing was installed. Try again.');
        return;
      }
      _bgChecked = s.path;
    }
    try {
      await bgCall('clearNote');
    } catch (_) {/* no notification */}
    final c = updateContext();
    if (c == null || !c.mounted) return;
    final yes = await _ask(c, 'Update ${s.version} is ready', 'Install it now? Android asks once more – press Install there.\n\nआता install करायचे? Android पुन्हा एकदा विचारेल – तिथे Install दाबा.',
        yes: 'Install', no: 'Later');
    if (!yes) {
      _bgLater = s.build;
      return;
    }
    var r = '';
    try {
      r = '${await bgCall('install', {'path': s.path})}';
    } catch (_) {
      r = 'error';
    }
    final c2 = updateContext();
    if (c2 == null || !c2.mounted) return;
    if (r == 'permission') {
      toast(c2, 'Allow "Install unknown apps" for FALCON, then come back – Install is asked again.');
    } else if (r == 'missing') {
      await _bgForget();
      bgUpdateNow.value = null;
      final c3 = updateContext();
      if (c3 != null && c3.mounted) toast(c3, 'The download was not complete or not genuine – nothing was installed. Try again.');
    } else if (r != 'ok') {
      toast(c2, 'The update could not be finished ($r). Try again.');
    }
  } finally {
    _bgAsking = false;
  }
}

/// The progress of the background download – it may be closed: the download goes on ("Keep working").
void _bgDialog(BuildContext context) {
  _bgClose();
  final r = DialogRoute<void>(
    context: context,
    builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      title: Text('Updating', style: T.h2),
      content: ValueListenableBuilder<BgUpdate?>(
        valueListenable: bgUpdateNow,
        builder: (_, s, _) {
          final p = s?.percent ?? -1;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            LinearProgressIndicator(value: p < 0 ? null : p / 100, color: C.leaf),
            const SizedBox(height: 12),
            Text(p < 0 ? 'Starting…' : 'Downloading… $p%', style: T.sm),
            const SizedBox(height: 10),
            Text('It goes on in the background – you may close this or leave the app.\nहे मागे (background ला) चालूच राहील – हे बंद करा किंवा ॲपमधून बाहेर जा.', style: T.xs),
          ]);
        },
      ),
      actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: Text('Keep working', style: T.b.copyWith(color: C.leafD)))],
    ),
  );
  _bgRoute = r;
  Navigator.of(context, rootNavigator: true).push(r);
}

/// Me → "Check for update": the newest version is offered now (or "You have the newest version").
Future<void> checkNow(BuildContext context) async {
  final u = await checkUpdate();
  if (!context.mounted) return;
  if (u == null) {
    toast(context, 'No newer version · नवीन version नाही');
    return;
  }
  _offered = true;
  await runUpdate(context, u);
}
