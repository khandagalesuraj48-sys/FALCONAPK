// Where the person is (23-11-2026, his word: "app swata check krel user kuthe aahe – mess location madhe to asel tr mess ch auto
// yeil, mess pasun lamb asel tr mess che direction kiti lamb te dakhwel ani auto parcel"; pictures N1, N2). The phone's own
// location, read only while a screen that needs it is open – the same as the web's src/lib/geo.ts. It leaves the phone only with a van
// order (Wolf part 0017, his word: "only section … section che baheun koni kel asel tr … location direction he sagle hot jail"): the
// server finds the section whose area holds it, and keeps the point with that order only when it is inside no section.
import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// metres between two points (the straight line – the road may be longer)
int metres(double aLat, double aLng, double bLat, double bLng) {
  const r = 6371000.0, d = math.pi / 180;
  final dLat = (bLat - aLat) * d, dLng = (bLng - aLng) * d;
  final h = math.pow(math.sin(dLat / 2), 2) + math.cos(aLat * d) * math.cos(bLat * d) * math.pow(math.sin(dLng / 2), 2);
  return (2 * r * math.asin(math.min(1, math.sqrt(h)))).round();
}

String distText(int m) => m < 1000 ? '$m m' : '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';

/// At the mess: inside its area (the metres the Site Admin set, 100 when none), the phone's own uncertainty counted up to 50 m.
/// null – the mess has no place.
bool? atMess(double lat, double lng, double acc, double? mLat, double? mLng, int? radius) {
  if (mLat == null || mLng == null) return null;
  return metres(lat, lng, mLat, mLng) - math.min(acc, 50) <= (radius ?? 100);
}

/// The section whose area (its point + metres) holds the point – the nearest when two do; null: inside no section. The server's own
/// rule (public.section_at); a section without its place or its metres is never found by a point.
Map<String, dynamic>? sectionAt(double lat, double lng, List<Map<String, dynamic>> secs) {
  Map<String, dynamic>? best;
  var bd = 1 << 30;
  for (final x in secs) {
    final sLat = x['lat'], sLng = x['lng'], r = x['radius_m'];
    if (sLat == null || sLng == null || r == null) continue;
    final d = metres(lat, lng, (sLat as num).toDouble(), (sLng as num).toDouble());
    if (d <= (r as num) && (d < bd || (d == bd && best != null && '${x['code']}'.compareTo('${best['code']}') < 0))) {
      best = x;
      bd = d;
    }
  }
  return best;
}

/// Google Maps' own directions page – the Maps app on the phone; only the point it goes to is in it.
Uri directionsUrl(double lat, double lng) => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}');

/// (25-11-2026, his word: "location fetching la time ghetey location on asla tri sudha he khup fast hoyla haw") the place is asked
/// EVERY SECOND on Android (the plugin asked once in 5 s when no interval was given), and the phone may give its reading of the last
/// 15 s at once (Android 13+); elsewhere as before. The same as RCL's ERP / HR app (its lib/core/gps_fast.dart).
LocationSettings hereSettings(bool android) => android
    ? AndroidSettings(accuracy: LocationAccuracy.high, distanceFilter: 5, intervalDuration: const Duration(seconds: 1), maxUpdateAge: const Duration(seconds: 15))
    : const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);

/// (25-11-2026) the one reading asked for at once, apart from the stream: Android – every second, the phone's reading of the last 15 s
/// at once (Android 13+); within 10 s.
LocationSettings hereOnce(bool android) => android
    ? AndroidSettings(accuracy: LocationAccuracy.high, intervalDuration: const Duration(seconds: 1), maxUpdateAge: const Duration(seconds: 15), timeLimit: const Duration(seconds: 10))
    : const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10));

/// A new reading of [acc] m is taken – unless the one there is exact ([wasExact]) and of the last 30 s ([at]) and the new one is not exact.
bool hereTakes(bool wasExact, DateTime at, double acc, DateTime now) =>
    !wasExact || (acc >= 0 && acc <= hereExact) || now.difference(at) > const Duration(seconds: 30);

/// A reading of the phone [at] is of the last 15 s by the phone's clock [now] (ahead of the clock by more than 2 s: no).
bool hereYoung(DateTime at, DateTime now) {
  final a = now.difference(at);
  return a >= const Duration(seconds: -2) && a <= const Duration(seconds: 15);
}

/// (25-11-2026, his word: "kal pahile mess pasun 20 km lamb hoto but app sangat hote 5 km lamb ahe … refresh … band krun chalu kel tri
/// 5 km … ekdm perfect") A reading is EXACT when the phone says it is within this many metres – a reading by the mobile towers alone
/// (indoors, no GPS yet) can be kilometres off, and it gave a wrong distance. Only an exact reading tells how far the mess is, whether
/// he is at it, which section he is in and where the van goes; a rough one only says "finding your exact place (± …)".
const hereExact = 100.0;

/// The phone's place while a screen listens: 'asking' → 'ok' (lat, lng, acc) or 'off' (switched off / refused).
class Here extends ChangeNotifier {
  Here._();
  static final Here i = Here._();
  String state = 'asking';
  double lat = 0, lng = 0, acc = 0;
  DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);

  /// (25-11-2026) the reading is exact (within [hereExact] m) – only then a distance, "at the mess" or a place for the van
  bool get exact => state == 'ok' && acc >= 0 && acc <= hereExact;
  StreamSubscription<Position>? _sub;
  int _users = 0;

  void use() {
    if (_users++ == 0) unawaited(_start());
  }

  void done() {
    if (--_users <= 0) {
      _users = 0;
      unawaited(_sub?.cancel());
      _sub = null;
    }
  }

  Future<void> ask() async {
    state = 'asking';
    notifyListeners();
    if (!await Geolocator.isLocationServiceEnabled()) await Geolocator.openLocationSettings();
    await _start();
  }

  Future<void> _start() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _off();
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied || p == LocationPermission.deniedForever) return _off();
      // (25-11-2026) the phone's own reading of the last 15 s is shown at once – the new ones follow
      try {
        final l = await Geolocator.getLastKnownPosition();
        if (l != null && hereYoung(l.timestamp, DateTime.now())) _take(l);
      } catch (_) {/* this phone gives none: the readings below */}
      await _sub?.cancel();
      _sub = Geolocator.getPositionStream(locationSettings: hereSettings(Platform.isAndroid)).listen(_take, onError: (_) => _off());
      // (25-11-2026, "falcon madhe pn location fetch 1 second madhe hoyla hawey") one reading of its own as well, at once: inside RCL's
      // ERP / HR app the phone's stream of places may be the one of the HR tracking (a point in minutes) – this one does not wait for it
      unawaited(Geolocator.getCurrentPosition(locationSettings: hereOnce(Platform.isAndroid)).then(_take, onError: (Object _) {}));
    } catch (_) {
      _off();
    }
  }

  void _take(Position pos) {
    // (25-11-2026) a rough reading does not push out an exact one of the last 30 s (the phone gives a tower's reading now and then)
    if (!hereTakes(exact, _at, pos.accuracy, DateTime.now())) return;
    state = 'ok';
    lat = pos.latitude;
    lng = pos.longitude;
    acc = pos.accuracy;
    _at = DateTime.now();
    notifyListeners();
  }

  void _off() {
    state = 'off';
    notifyListeners();
  }
}
