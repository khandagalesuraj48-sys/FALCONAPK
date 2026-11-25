// (23-11-2026) the server's clock: the meal of now follows it (core/fmt.dart istNow), never the phone's own time. Taken at the
// start and every 10 minutes; no answer – the last difference stays.
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import 'fmt.dart';
import 'net.dart' show netHttp;

Future<void> syncClock({http.Client? client}) async {
  try {
    final sent = DateTime.now().millisecondsSinceEpoch;
    final r = await (client ?? http.Client()).get(Uri.parse('${Config.server}/api/start')).timeout(const Duration(seconds: 10));
    final j = jsonDecode(r.body);
    final now = j is Map ? DateTime.tryParse('${j['now'] ?? ''}') : null;
    if (r.statusCode == 200 && now != null) setSkew(now.millisecondsSinceEpoch, sent, DateTime.now().millisecondsSinceEpoch);
  } catch (_) {/* the last difference stays */}
}

Timer? _every;
void keepClock() {
  // (25-11-2026 – SNI) its answer is measured too (core/net.dart)
  unawaited(syncClock(client: netHttp));
  _every ??= Timer.periodic(const Duration(minutes: 10), (_) => unawaited(syncClock(client: netHttp)));
}
