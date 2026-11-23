// Where the person is (23-11-2026, his word: "app swata check krel user kuthe aahe – mess location madhe to asel tr mess ch auto
// yeil, mess pasun lamb asel tr mess che direction kiti lamb te dakhwel ani auto parcel"; pictures N1, N2). The phone's own
// location, read only while a screen that needs it is open; nothing of it is saved or sent – the same as the web's src/lib/geo.ts.
import 'dart:async';
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

/// Google Maps' own directions page – the Maps app on the phone; only the mess's point is in it.
Uri directionsUrl(double lat, double lng) => Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}');

/// The phone's place while a screen listens: 'asking' → 'ok' (lat, lng, acc) or 'off' (switched off / refused).
class Here extends ChangeNotifier {
  Here._();
  static final Here i = Here._();
  String state = 'asking';
  double lat = 0, lng = 0, acc = 0;
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
      await _sub?.cancel();
      _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5)).listen((pos) {
        state = 'ok';
        lat = pos.latitude;
        lng = pos.longitude;
        acc = pos.accuracy;
        notifyListeners();
      }, onError: (_) => _off());
    } catch (_) {
      _off();
    }
  }

  void _off() {
    state = 'off';
    notifyListeners();
  }
}
