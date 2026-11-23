// The Google map (23-11-2026, his decision: "map lauya" – with the ERP's own Google Maps key, the GitHub secret MAPS_API_KEY at the
// build, as the ERP app; pictures N2–N5). FALCON's own points: you, the mess, the van, the sections. Built without the key, or
// no point has a place yet: the drawn road of before (`fallback`) – the same as the web's src/ui/GMap.tsx.
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;

import '../core/geo.dart';

/// The key was given at the build (--dart-define=GMAPS=true, with the key in the manifest)
const mapsOn = bool.fromEnvironment('GMAPS');

class Mark {
  const Mark(this.lat, this.lng, this.kind, {this.label, this.title});
  final double lat, lng;
  final String kind; // you · mess · van · stop · done · mine
  final String? label, title;
}

const _night = '[{"elementType":"geometry","stylers":[{"color":"#1F2A38"}]},{"elementType":"labels.text.fill","stylers":[{"color":"#9AA6B5"}]},'
    '{"featureType":"road","elementType":"geometry","stylers":[{"color":"#38414E"}]},{"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#746855"}]},'
    '{"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263C"}]},{"featureType":"poi","stylers":[{"visibility":"off"}]}]';

double _hue(String kind) => switch (kind) {
      'you' => gm.BitmapDescriptor.hueAzure,
      'mess' => gm.BitmapDescriptor.hueRed,
      'van' || 'mine' => gm.BitmapDescriptor.hueOrange,
      'done' => gm.BitmapDescriptor.hueGreen,
      _ => gm.BitmapDescriptor.hueViolet,
    };

class GMap extends StatefulWidget {
  const GMap({super.key, required this.marks, this.line = const [], this.ring, this.height = 240, this.dark = false, required this.label, required this.fallback, this.me});
  final List<Mark> marks;
  final List<(double, double)> line;
  final (double, double, double)? ring; // lat, lng, metres
  final double height;
  final bool dark;
  final String label;
  final Widget fallback;
  /// this phone's own place is a point too ('van' – the driver; 'you') – only while the map is on the screen
  final String? me;
  @override
  State<GMap> createState() => _GMapState();
}

class _GMapState extends State<GMap> {
  gm.GoogleMapController? _c;
  String _fitted = '';

  bool get _live => widget.me != null && mapsOn && widget.marks.isNotEmpty;
  @override
  void initState() {
    super.initState();
    if (_live) {
      Here.i.addListener(_moved);
      Here.i.use();
    }
  }

  void _moved() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    if (_live) {
      Here.i.removeListener(_moved);
      Here.i.done();
    }
    super.dispose();
  }

  List<Mark> get _marks => [...widget.marks, if (_live && Here.i.state == 'ok') Mark(Here.i.lat, Here.i.lng, widget.me!, title: 'You')];
  List<(double, double)> get _line => _live && Here.i.state == 'ok' && widget.line.isNotEmpty ? [(Here.i.lat, Here.i.lng), ...widget.line] : widget.line;

  String get _fitKey => '${_marks.map((m) => '${m.kind}${m.label ?? ''}').join('|')}:${_line.length}:${widget.ring?.$3 ?? 0}';

  void _fit() {
    final c = _c;
    if (c == null || _fitted == _fitKey) return;
    _fitted = _fitKey;
    final pts = [for (final m in _marks) (m.lat, m.lng), ..._line];
    if (widget.ring != null) {
      final r = widget.ring!, d = r.$3 * 2.2 / 111000;
      pts.addAll([(r.$1 - d, r.$2 - d), (r.$1 + d, r.$2 + d)]);
    }
    if (pts.length == 1) {
      c.moveCamera(gm.CameraUpdate.newLatLngZoom(gm.LatLng(pts.first.$1, pts.first.$2), 16));
      return;
    }
    var s = pts.first.$1, w = pts.first.$2, n = s, e = w;
    for (final p in pts) {
      if (p.$1 < s) s = p.$1;
      if (p.$1 > n) n = p.$1;
      if (p.$2 < w) w = p.$2;
      if (p.$2 > e) e = p.$2;
    }
    c.moveCamera(gm.CameraUpdate.newLatLngBounds(gm.LatLngBounds(southwest: gm.LatLng(s, w), northeast: gm.LatLng(n == s ? n + .0005 : n, e == w ? e + .0005 : e)), 48));
  }

  @override
  void didUpdateWidget(GMap old) {
    super.didUpdateWidget(old);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
  }

  @override
  Widget build(BuildContext context) {
    if (!mapsOn || widget.marks.isEmpty) return widget.fallback;
    final first = widget.marks.first;
    return Semantics(
      label: widget.label,
      child: SizedBox(
        height: widget.height,
        child: gm.GoogleMap(
          initialCameraPosition: gm.CameraPosition(target: gm.LatLng(first.lat, first.lng), zoom: 14),
          style: widget.dark ? _night : null,
          zoomControlsEnabled: false,
          myLocationButtonEnabled: false,
          mapToolbarEnabled: false,
          markers: {
            for (var i = 0; i < _marks.length; i++)
              gm.Marker(
                markerId: gm.MarkerId('m$i'),
                position: gm.LatLng(_marks[i].lat, _marks[i].lng),
                icon: gm.BitmapDescriptor.defaultMarkerWithHue(_hue(_marks[i].kind)),
                infoWindow: gm.InfoWindow(title: _marks[i].title ?? _marks[i].label),
                zIndexInt: _marks[i].kind == 'you' || _marks[i].kind == 'van' ? 10 : 5,
              ),
          },
          polylines: {
            if (_line.length > 1)
              gm.Polyline(polylineId: const gm.PolylineId('line'), points: [for (final p in _line) gm.LatLng(p.$1, p.$2)], color: widget.dark ? const Color(0xFF4A90F0) : const Color(0xFF1A73E8), width: 5),
          },
          circles: {
            if (widget.ring != null)
              gm.Circle(circleId: const gm.CircleId('area'), center: gm.LatLng(widget.ring!.$1, widget.ring!.$2), radius: widget.ring!.$3,
                  strokeColor: const Color(0xFF2F7A45), strokeWidth: 2, fillColor: const Color(0x1F2F7A45)),
          },
          onMapCreated: (c) {
            _c = c;
            WidgetsBinding.instance.addPostFrameCallback((_) => _fit());
          },
        ),
      ),
    );
  }
}
