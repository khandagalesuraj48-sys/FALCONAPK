/* (25-11-2026, his word with two pictures – FALCON "5.9 km away", Google Maps 12 km: "direction war click kel 12 km ale he as ka problem
 * udya aple live tracking map madhun honar aahe … app ase ase fake imformation denare tr kahich thik nahi chalnar") THE DISTANCE BY ROAD,
 * as Google Maps gives it – FALCON's server step /api/route (Google's Routes API; the key only there). Both points were right; the app
 * showed the straight line. The straight line is shown only until the road is there – and then it says so: "5.9 km in a straight line".
 * Asked again only when he moved about 100 m or after 5 minutes. The same as the web's src/lib/road.tsx. */
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'db.dart';
import 'geo.dart';

class Road {
  const Road(this.metres, this.seconds);
  final int metres;
  final int? seconds;
}

String minutesText(int s) {
  final m = (s / 60).round().clamp(1, 1 << 30);
  return m < 60 ? '$m min' : '${m ~/ 60} h ${(m % 60).toString().padLeft(2, '0')} min';
}

/// "12 km by road · 30 min" – or, without the road yet, "5.9 km in a straight line"
String roadLabel(Road? road, int? straight) => road != null
    ? '${distText(road.metres)} by road${road.seconds != null ? ' · ${minutesText(road.seconds!)}' : ''}'
    : straight != null ? '${distText(straight)} in a straight line' : '';

/// "12 km by road" / "5.9 km in a straight line" – for a short chip
String roadShort(Road? road, int straight) => road != null ? '${distText(road.metres)} by road' : '${distText(straight)} in a straight line';

/// The roads asked for – a screen listens and is drawn again when one comes.
class Roads extends ChangeNotifier {
  Roads._();
  static final Roads i = Roads._();
  /// (tests) instead of FALCON's server
  static Future<Rec> Function(String path, Map<String, dynamic> body)? askForTest;

  final _memo = <String, (int, Road?)>{};
  final _asking = <String>{};

  static String keyOf(double aLat, double aLng, double bLat, double bLng) =>
      '${aLat.toStringAsFixed(3)},${aLng.toStringAsFixed(3)}>${bLat.toStringAsFixed(5)},${bLng.toStringAsFixed(5)}';

  /// The road from → to, as far as known now (null: not yet / none); asked for when not known or older than 5 minutes.
  Road? of(double aLat, double aLng, double bLat, double bLng) {
    final k = keyOf(aLat, aLng, bLat, bLng), m = _memo[k], now = DateTime.now().millisecondsSinceEpoch;
    if ((m == null || now - m.$1 > 5 * 60 * 1000) && !_asking.contains(k)) {
      _asking.add(k);
      _ask(k, aLat, aLng, bLat, bLng);
    }
    return m?.$2;
  }

  Future<void> _ask(String k, double aLat, double aLng, double bLat, double bLng) async {
    try {
      final r = await (askForTest ?? api)('/api/route', {
        'from': {'lat': aLat, 'lng': aLng},
        'to': {'lat': bLat, 'lng': bLng},
      });
      final x = r['road'];
      _memo[k] = (DateTime.now().millisecondsSinceEpoch, x is Map ? Road((x['metres'] as num).round(), (x['seconds'] as num?)?.round()) : null);
      notifyListeners();
    } catch (_) {
      // no road now (no key, Google refused, no network): the straight line stays, said as one; asked again in a minute
      _memo[k] = (DateTime.now().millisecondsSinceEpoch - 4 * 60 * 1000, _memo[k]?.$2);
    } finally {
      _asking.remove(k);
    }
  }

  @visibleForTesting
  void clear() {
    _memo.clear();
    _asking.clear();
  }
}

/// A screen that shows roads (the kitchen's lists) is drawn again when one comes.
mixin RoadsRedraw<T extends StatefulWidget> on State<T> {
  void _roadCame() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    Roads.i.addListener(_roadCame);
  }

  @override
  void dispose() {
    Roads.i.removeListener(_roadCame);
    super.dispose();
  }
}
