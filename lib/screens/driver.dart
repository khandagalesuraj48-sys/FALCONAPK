// The driver's app – boards d01–d11 (dark): only the batches given to him; names and box contents, never prices; his place is
// sent only while his batch is on the way – the app's own screens on the same data and actions as the web's src/screens/driver.tsx.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/db.dart';
import '../core/fmt.dart';
import '../core/session.dart';
import '../ui/kit.dart';
import '../ui/look.dart';
import '../ui/road_map.dart';

const driverTabs = [TabItem('/driver', 'house', 'Home'), TabItem('/driver/trip', 'route', 'Trip'), TabItem('/driver/vehicle', 'truck', 'Vehicle')];
PillTabs _tabs(String current) => PillTabs(tabs: driverTabs, current: current, dark: true);

List<Rec> _list(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
List<Rec> stopsOf(Rec? t) => _list(t?['stops']);
List<Rec> peopleOf(Rec stop) => _list(stop['people']);
List<Rec> linesOf(Rec p) => _list(p['lines']);

String pState(Rec p) {
  final l = linesOf(p);
  if (l.isNotEmpty && l.every((x) => x['state'] == 'failed')) return 'failed';
  if (l.isNotEmpty && l.every((x) => ['delivered', 'short', 'failed'].contains(x['state']))) return 'done';
  return 'open';
}

String what(Rec p) => linesOf(p).map((l) => '${'${l['item']}'.toLowerCase()} ${l['qty']}').join(', ');

Future<List<Rec>> myBatches(Session s) => rows(sb.from('batches').select('id,code,state,meal,dispatched_at,completed_at,created_at')
    .eq('driver_id', s.personId ?? '').eq('service_date', today()).order('created_at'));

Future<Rec?> trip(String? id) async {
  if (id == null) return null;
  final r = await call<dynamic>('driver_trip', {'p_batch': id});
  return r is Map ? Map<String, dynamic>.from(r) : null;
}

Rec? current(List<Rec> list) => list.where((b) => ['on_the_way', 'loaded', 'accepted', 'assigned'].contains(b['state'])).firstOrNull;

/// The batch now and its trip (the web's useMyBatches + useTrip of the current one).
Future<(List<Rec>, Rec?)> now(Session s) async {
  final b = await myBatches(s);
  return (b, await trip(current(b)?['id'] as String?));
}

const _watch = ['batches', 'batch_stops', 'order_lines'];

/// While the batch is on the way: the van's place every 20 s (and only then).
class ShareLocation extends StatefulWidget {
  const ShareLocation({super.key, required this.trip, required this.child});
  final Rec? trip;
  final Widget child;
  @override
  State<ShareLocation> createState() => _ShareLocationState();
}

class _ShareLocationState extends State<ShareLocation> {
  StreamSubscription<Position>? _sub;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  String? _for;
  @override
  void initState() { super.initState(); _sync(); }
  @override
  void didUpdateWidget(ShareLocation old) { super.didUpdateWidget(old); _sync(); }
  @override
  void dispose() { _sub?.cancel(); super.dispose(); }
  Future<void> _sync() async {
    final t = widget.trip;
    final on = t != null && t['state'] == 'on_the_way';
    final id = on ? '${t['id']}' : null;
    if (id == _for) return;
    _for = id;
    await _sub?.cancel();
    _sub = null;
    if (id == null) return;
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever || !mounted || _for != id) return;
    _sub = Geolocator.getPositionStream(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 0)).listen((pos) {
      if (DateTime.now().difference(_last).inSeconds < 20) return;
      _last = DateTime.now();
      unawaited(call('van_position', {'p_batch': id, 'p_lat': pos.latitude, 'p_lng': pos.longitude, 'p_speed': pos.speed}).catchError((_) => null));
    }, onError: (_) {});
  }
  @override
  Widget build(BuildContext context) => widget.child;
}

Widget _gold(String text) => Chip2(text, tone: const Tone(C.gold, Color(0xFF1D1404)), height: 26);
Widget _stat(String value, String label) => FCard(dark: true, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(value, style: T.b.copyWith(fontSize: 26, color: Colors.white)), Text(label, style: T.xs.copyWith(color: C.darkSub))]));
TextStyle _w(TextStyle s) => s.copyWith(color: Colors.white);
TextStyle _sub(TextStyle s) => s.copyWith(color: C.darkSub);

// ── d01 · Driver home ──
class DriverHome extends StatelessWidget {
  const DriverHome({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(List<Rec>, Rec?)>(
      watch: _watch,
      loading: Screen(dark: true, tabs: _tabs('/driver'), children: const [Loading(dark: true)]),
      load: () => now(s),
      builder: (context, x, reload) {
        final (b, tr) = x;
        final cur = current(b), done = b.where((y) => y['state'] == 'completed').toList();
        final stops = stopsOf(tr), parcels = stops.fold<int>(0, (n, y) => n + peopleOf(y).length);
        return Screen(
          dark: true,
          top: Top(dark: true, left: Av(initials(s.name), tone: Tone.navy), title: 'Namaskar, ${firstName(s.name)}', sub: 'Mess driver · ${s.homeSite?.code ?? ''}'),
          tabs: _tabs('/driver'),
          children: [
            if (cur != null)
              FCard(dark: true, border: C.gold, onTap: () => context.push(cur['state'] == 'assigned' ? '/driver/assignments/${cur['id']}' : '/driver/trip'), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [_gold(cur['state'] == 'assigned' ? 'New trip' : '${cur['state']}'.replaceAll('_', ' ')), const Spacer(), Text(time(cur['created_at'] as String?), style: _sub(T.xs))]),
                const SizedBox(height: 12),
                Text('Batch ${cur['code']}', style: _w(T.b.copyWith(fontSize: 20))),
                Text('${mealName(cur['meal'] as String?)} · ${tr == null ? '…' : parcels} parcels · ${tr == null ? '…' : stops.length} stops${tr?['planned_km'] != null ? ' · ${tr!['planned_km']} km' : ''}', style: _sub(T.sm)),
                const SizedBox(height: 12),
                Btn(cur['state'] == 'assigned' ? 'See and accept' : 'Open the trip', kind: BtnKind.gold, onTap: () => context.push(cur['state'] == 'assigned' ? '/driver/assignments/${cur['id']}' : '/driver/trip')),
              ]))
            else const Empty(dark: true, icon: 'truck', title: 'No trip now', text: 'A new batch comes here as soon as the mess gives it to you.'),
            Row(children: [Expanded(child: _stat('${b.length}', 'Trips today')), const SizedBox(width: 10), Expanded(child: _stat('${done.length}', 'Closed'))]),
            if (done.isNotEmpty) Text('Earlier today', style: T.lbl.copyWith(color: C.darkSub)),
            for (final y in done)
              FCard(dark: true, padding: const EdgeInsets.all(12), onTap: () => context.push('/driver/summary/${y['id']}'), child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${y['code']} · ${y['meal']}', style: _w(T.b)), Text('${time(y['dispatched_at'] as String?)} – ${time(y['completed_at'] as String?)}', style: _sub(T.xs))])),
                const Ico('chevron-right', size: 18, color: Colors.white)])),
          ],
        );
      },
    );
  }
}

// ── d02 · New trip – accept ──
class Assign extends StatefulWidget {
  const Assign({super.key, required this.id});
  final String id;
  @override
  State<Assign> createState() => _AssignState();
}

class _AssignState extends State<Assign> with Act {
  bool no = false;
  final why = TextEditingController();
  @override
  void dispose() { why.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Load<Rec?>(
        watch: _watch,
        loading: const Screen(dark: true, top: Top(dark: true, title: 'New trip', back: '/driver'), children: [Loading(dark: true)]),
        load: () => trip(widget.id),
        builder: (context, tr, reload) {
          if (tr == null) return const Screen(dark: true, top: Top(dark: true, title: 'New trip', back: '/driver'), children: [Empty(dark: true, icon: 'truck', title: 'Not given to you')]);
          final people = [for (final st in stopsOf(tr)) ...peopleOf(st)];
          final tot = <String, int>{};
          for (final p in people) { for (final l in linesOf(p)) { tot['${l['item']}'] = (tot['${l['item']}'] ?? 0) + toI(l['qty']); } }
          Future<void> answer(bool ok) => act(() async {
                await call('driver_answer', {'p_batch': tr['id'], 'p_accept': ok, 'p_reason': ok ? null : why.text.trim()});
                if (context.mounted) context.go(ok ? '/driver/vehicle' : '/driver');
              });
          return Screen(
            dark: true,
            top: Top(dark: true, title: 'New trip · ${tr['meal']}', sub: 'Batch ${tr['code']} · from ${tr['mess']}', back: '/driver'),
            children: [
              Row(children: [Expanded(child: _stat('${people.length}', 'parcels')), const SizedBox(width: 10), Expanded(child: _stat('${stopsOf(tr).length}', 'stops'))]),
              Row(children: [Expanded(child: _stat('${tr['planned_km'] ?? '–'}', 'km')), const SizedBox(width: 10), Expanded(child: _stat(tr['planned_minutes'] != null ? '${tr['planned_minutes']} min' : '–', 'about'))]),
              FCard(dark: true, child: Text(tot.entries.map((e) => '${e.value} ${e.key.toLowerCase()}').join(' · '), style: _sub(T.sm))),
              const InfoLine('Your location is shared only during this trip.', icon: 'shield-check', dark: true),
              if (no) ...[
                Input(controller: why, hint: 'Why can\'t you take it?', lines: 3, dark: true, onChanged: (_) => setState(() {})),
                Btn('Send – can\'t take', kind: BtnKind.red, busy: busy, onTap: why.text.trim().length < 3 ? null : () => answer(false)),
              ],
              ErrorLine(error, dark: true),
              if (!no) Row(children: [
                Expanded(child: Btn('Can\'t take', kind: BtnKind.ghost, dark: true, onTap: () => setState(() => no = true))),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: Btn('Accept trip', kind: BtnKind.gold, busy: busy, onTap: () => answer(true))),
              ]),
            ],
          );
        },
      );
}

// ── d03 · Vehicle – the check before the trip ──
class Vehicle extends StatefulWidget {
  const Vehicle({super.key});
  @override
  State<Vehicle> createState() => _VehicleState();
}

class _VehicleState extends State<Vehicle> with Act {
  final chk = <String, bool>{};
  static const _items = [('box_clean', 'Box cleaned'), ('hot_box', 'Hot box closed and hot'), ('water', 'Water crates in'), ('papers', 'Insurance and PUC with me'), ('fuel', 'Enough diesel for the trip')];
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(List<Rec>, Rec?)>(
      watch: _watch,
      loading: Screen(dark: true, top: const Top(dark: true, title: 'My vehicle'), tabs: _tabs('/driver/vehicle'), children: const [Loading(dark: true)]),
      load: () => now(s),
      builder: (context, x, reload) {
        final (_, tr) = x;
        final v = Map<String, dynamic>.from((tr?['vehicle'] as Map?) ?? const {});
        final c = <String, bool>{...Map<String, bool>.from((tr?['vehicle_check'] as Map?)?.map((k, val) => MapEntry('$k', val == true)) ?? const {}), ...chk};
        return Screen(
          dark: true,
          top: Top(dark: true, title: 'My vehicle', sub: tr != null ? 'For batch ${tr['code']}' : 'No trip now'),
          tabs: _tabs('/driver/vehicle'),
          children: [
            if (tr == null) const Empty(dark: true, icon: 'truck', title: 'No trip now')
            else ...[
              FCard(dark: true, child: Row(children: [const Tile('truck', tone: Tone.darkTile, size: 56), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v['reg_no'] ?? ''}', style: _w(T.b.copyWith(fontSize: 19, letterSpacing: .8))), Text('${v['kind'] ?? ''}${v['capacity'] != null ? ' · ${v['capacity']} boxes' : ''}', style: _sub(T.sm))]))])),
              Text('Before the trip', style: T.lbl.copyWith(color: C.darkSub)),
              FCard(dark: true, child: Column(children: [
                for (final (k, l) in _items)
                  InkWell(onTap: () => setState(() => chk[k] = !(c[k] ?? false)), child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                    Ico(c[k] == true ? 'circle-check' : 'circle-dot', size: 18, color: c[k] == true ? C.gold : C.darkSub), const SizedBox(width: 10), Expanded(child: Text(l, style: _w(T.sm)))]))),
              ])),
              ErrorLine(error, dark: true),
              Btn(tr['state'] == 'loaded' ? 'Checked – saved again' : 'Vehicle ready', kind: BtnKind.gold, busy: busy,
                  onTap: !['accepted', 'loaded'].contains(tr['state']) ? null : () => act(() async { await call('vehicle_ready', {'p_batch': tr['id'], 'p_check': c}); reload(); })),
              if (tr['state'] == 'on_the_way') Btn('Open the trip', kind: BtnKind.ghost, dark: true, onTap: () => context.go('/driver/trip')),
            ],
          ],
        );
      },
    );
  }
}

// ── d04 · d06 · the batch and its stops ──
class TripStops extends StatelessWidget {
  const TripStops({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(List<Rec>, Rec?)>(
      watch: _watch,
      loading: Screen(dark: true, top: const Top(dark: true, title: 'Trip'), tabs: _tabs('/driver/trip'), children: const [Loading(dark: true)]),
      load: () => now(s),
      builder: (context, x, reload) {
        final (_, tr) = x;
        if (tr == null) return Screen(dark: true, top: const Top(dark: true, title: 'Trip'), tabs: _tabs('/driver/trip'), children: const [Empty(dark: true, icon: 'route', title: 'No trip on the way')]);
        final stops = stopsOf(tr), people = [for (final st in stops) ...peopleOf(st)];
        final doneN = people.where((p) => pState(p) != 'open').length;
        final next = stops.where((st) => peopleOf(st).any((p) => pState(p) == 'open')).firstOrNull;
        final allDone = people.isNotEmpty && doneN == people.length;
        final st = '${tr['state']}';
        return ShareLocation(trip: tr, child: Screen(
          dark: true,
          top: Top(dark: true, title: 'Stops · ${tr['code']}', sub: st == 'on_the_way' ? 'On the way since ${time(tr['dispatched_at'] as String?)}' : st == 'loaded' || st == 'accepted' ? 'Waiting for the mess to dispatch' : st),
          tabs: _tabs('/driver/trip'),
          children: [
            FCard(dark: true, child: Row(children: [Text('$doneN of ${people.length}', style: _w(T.big)), const SizedBox(width: 14),
              Expanded(child: Text('handed over so far · ${people.where((p) => pState(p) == 'failed').length} failed', style: _sub(T.sm)))])),
            for (final x in stops)
              Builder(builder: (_) {
                final pp = peopleOf(x), d = pp.where((p) => pState(p) != 'open').length, isNext = identical(x, next);
                return FCard(dark: true, padding: const EdgeInsets.all(12), border: isNext ? C.gold : null, onTap: () => context.push('/driver/stops/${x['section_id']}'), child: Row(children: [
                  Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(shape: BoxShape.circle, color: d == pp.length ? C.leaf : C.navy3),
                      child: d == pp.length ? const Ico('check', size: 16, color: Colors.white) : Text('${x['seq']}', style: _w(T.b.copyWith(fontSize: 13)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${x['section']}${x['km'] != null ? ' · Km ${x['km']}' : ''}', style: _w(T.b)),
                    Text('$d of ${pp.length}${x['reached_at'] != null ? ' · arrived ${time(x['reached_at'] as String?)}' : x['eta'] != null ? ' · about ${time(x['eta'] as String?)}' : ''}${x['place'] != null ? ' · ${x['place']}' : ''}', style: _sub(T.xs)),
                  ])),
                  if (isNext) _gold('Next'),
                ]));
              }),
            const InfoLine('What is in each box is set by the mess – it cannot be changed here.', dark: true),
            if (st == 'on_the_way' && next != null) Btn('Go to ${next['section']}', icon: 'navigation', kind: BtnKind.gold, onTap: () => context.push('/driver/route/${next['section_id']}')),
            if (st == 'on_the_way' && allDone) Btn('Trip summary', kind: BtnKind.gold, onTap: () => context.push('/driver/summary/${tr['id']}')),
          ],
        ));
      },
    );
  }
}

// ── d05 · Route and navigation to the next stop ──
class RouteNext extends StatefulWidget {
  const RouteNext({super.key, required this.section});
  final String section;
  @override
  State<RouteNext> createState() => _RouteNextState();
}

class _RouteNextState extends State<RouteNext> with Act {
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(List<Rec>, Rec?)>(
      watch: _watch,
      loading: const Screen(dark: true, top: Top(dark: true, title: 'Route', back: '/driver/trip'), children: [Loading(dark: true)]),
      load: () => now(s),
      builder: (context, x, reload) {
        final (_, tr) = x;
        final stops = stopsOf(tr), stop = stops.where((y) => y['section_id'] == widget.section).firstOrNull;
        if (tr == null || stop == null) return const Screen(dark: true, top: Top(dark: true, title: 'Route', back: '/driver/trip'), children: [Empty(dark: true, icon: 'route', title: 'Not a stop of your trip')]);
        final gmaps = stop['lat'] != null && stop['lng'] != null
            ? 'https://www.google.com/maps/dir/?api=1&destination=${stop['lat']},${stop['lng']}'
            : 'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent('${stop['place'] ?? stop['section']} ${stop['km'] != null ? 'Km ${stop['km']}' : ''}')}';
        return ShareLocation(trip: tr, child: Screen(
          dark: true,
          top: const Top(dark: true, title: 'Route', back: '/driver/trip'),
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(20), child: RoadMap(dark: true, sections: [for (final y in stops) MapSection('${y['section_id']}', '${y['section']}', y['km'] == null ? null : toD(y['km']))],
                mine: widget.section, done: [for (final y in stops) if (y['reached_at'] != null) '${y['section_id']}'], height: 320, label: 'The trip\'s stops on the road')),
            FCard(dark: true, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Container(width: 40, height: 40, alignment: Alignment.center, decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle), child: Text('${stop['seq']}', style: T.b.copyWith(color: const Color(0xFF1D1404)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Next stop', style: _sub(T.xs)),
                  Text('${stop['section']}${stop['km'] != null ? ' · Km ${stop['km']}' : ''}${stop['place'] != null ? ' · ${stop['place']}' : ''}', style: _w(T.b.copyWith(fontSize: 17)))])),
                Text(stop['eta'] != null ? time(stop['eta'] as String?) : '', style: _w(T.b)),
              ]),
              const SizedBox(height: 8),
              Text('${stops.where((y) => y['reached_at'] != null).length} of ${stops.length} stops done · ${peopleOf(stop).length} parcels there', style: _sub(T.xs)),
              const SizedBox(height: 8),
              ErrorLine(error, dark: true),
              Row(children: [
                Expanded(child: Btn('Google Maps', icon: 'navigation', kind: BtnKind.ghost, dark: true, onTap: () => launchUrl(Uri.parse(gmaps), mode: LaunchMode.externalApplication))),
                const SizedBox(width: 10),
                Expanded(child: Btn('I\'m here', kind: BtnKind.gold, busy: busy, onTap: () => act(() async {
                  await call('reach_stop', {'p_batch': tr['id'], 'p_section': stop['section_id']});
                  if (context.mounted) context.go('/driver/stops/${stop['section_id']}');
                }))),
              ]),
            ])),
          ],
        ));
      },
    );
  }
}

// ── d07 · Employee-wise delivery at a stop ──
class StopPeople extends StatelessWidget {
  const StopPeople({super.key, required this.section});
  final String section;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(List<Rec>, Rec?)>(
      watch: _watch,
      loading: const Screen(dark: true, top: Top(dark: true, title: 'Stop', back: '/driver/trip'), children: [Loading(dark: true)]),
      load: () => now(s),
      builder: (context, x, reload) {
        final (_, tr) = x;
        final stop = stopsOf(tr).where((y) => y['section_id'] == section).firstOrNull;
        if (stop == null) return const Screen(dark: true, top: Top(dark: true, title: 'Stop', back: '/driver/trip'), children: [Empty(dark: true, icon: 'map-pin', title: 'Not a stop of your trip')]);
        final pp = peopleOf(stop), open = pp.where((p) => pState(p) == 'open').toList(), done = pp.where((p) => pState(p) != 'open').toList();
        return ShareLocation(trip: tr, child: Screen(
          dark: true,
          top: Top(dark: true, title: '${stop['section']}${stop['km'] != null ? ' · Km ${stop['km']}' : ''}', sub: 'Stop ${stop['seq']} · ${pp.length} parcels${stop['place'] != null ? ' · ${stop['place']}' : ''}', back: '/driver/trip'),
          children: [
            Row(children: [Expanded(child: Text('To give · ${open.length}', style: _sub(T.xs))), Text('Given · ${done.length}', style: _sub(T.xs))]),
            for (final p in open)
              FCard(dark: true, padding: const EdgeInsets.all(12), onTap: () => context.push('/driver/hand/${p['order_id']}/${p['person_id']}'), child: Row(children: [
                Av(initials(p['name'] as String?), tone: Tone.navy), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['name']}', style: _w(T.b)), Text('${p['role'] ?? ''} · ${p['code']} · ${what(p)}', style: _sub(T.xs))])),
                const Ico('chevron-right', size: 18, color: Colors.white)])),
            for (final p in done)
              Opacity(opacity: .6, child: FCard(dark: true, padding: const EdgeInsets.all(12), child: Row(children: [
                Av('', tone: pState(p) == 'failed' ? Tone.red : Tone.leaf), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${p['name']}', style: _w(T.b)),
                  Text('${pState(p) == 'failed' ? 'not delivered' : p['confirmed'] == 'beneficiary_otp' ? 'code OK' : 'given – not confirmed'} · ${what(p)}', style: _sub(T.xs))])),
                Ico(pState(p) == 'failed' ? 'x' : 'check', size: 16, color: Colors.white)]))),
            const InfoLine('You see names and box contents only – no prices.', icon: 'shield-check', dark: true),
          ],
        ));
      },
    );
  }
}

// ── d08 · d09 · d10 · handing over: the person's code, done, or not delivered ──
class HandOver extends StatefulWidget {
  const HandOver({super.key, required this.order, required this.person});
  final String order, person;
  @override
  State<HandOver> createState() => _HandOverState();
}

class _HandOverState extends State<HandOver> with Act {
  String code = '', mode = 'code', why = 'Not at site';
  final note = TextEditingController();
  @override
  void dispose() { note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(List<Rec>, Rec?)>(
      watch: _watch,
      loading: const Screen(dark: true, top: Top(dark: true, title: 'Hand over', back: '/driver/trip'), children: [Loading(dark: true)]),
      load: () => now(s),
      builder: (context, x, reload) {
        final (_, tr) = x;
        Rec? stop, p;
        for (final st in stopsOf(tr)) {
          final f = peopleOf(st).where((y) => y['order_id'] == widget.order && y['person_id'] == widget.person).firstOrNull;
          if (f != null) { stop = st; p = f; break; }
        }
        if (tr == null || p == null || stop == null) return const Screen(dark: true, top: Top(dark: true, title: 'Hand over', back: '/driver/trip'), children: [Empty(dark: true, icon: 'package', title: 'Not in your trip')]);
        final pp = p, st = stop;
        Future<void> send(String c) => act(() async {
              final r = await call<dynamic>('deliver_with_code', {'p_batch': tr['id'], 'p_order': widget.order, 'p_person': widget.person, 'p_code': c});
              if (r is! Map || r['ok'] != true) { setState(() => code = ''); throw DbError('Wrong code – ${r is Map ? r['tries_left'] : '?'} tries left.'); }
              setState(() => mode = 'done');
              reload();
            });
        final nextP = peopleOf(st).where((y) => pState(y) == 'open' && !(y['order_id'] == widget.order && y['person_id'] == widget.person)).firstOrNull;
        if (mode == 'done') {
          return Screen(dark: true, padding: const EdgeInsets.fromLTRB(20, 70, 20, 26), children: [
            Center(child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: C.leaf, shape: BoxShape.circle), child: const Center(child: Ico('check', size: 32, color: Colors.white)))),
            Text('Delivered', textAlign: TextAlign.center, style: _w(T.h1)),
            Text('${pp['name']} · ${what(pp)}', textAlign: TextAlign.center, style: _sub(T.sm)),
            const SizedBox(height: 20),
            if (nextP != null) Btn('Next: ${nextP['name']}', kind: BtnKind.gold, onTap: () => context.go('/driver/hand/${nextP['order_id']}/${nextP['person_id']}'))
            else Btn('Back to the stops', kind: BtnKind.gold, onTap: () => context.go('/driver/trip')),
          ]);
        }
        return ShareLocation(trip: tr, child: Screen(
          dark: true,
          top: Top(dark: true, title: '${pp['name']}', sub: '${pp['code']} · ${what(pp)}', back: '/driver/stops/${st['section_id']}'),
          children: [
            if (mode == 'code') ...[
              FCard(dark: true, child: Column(children: [Text('Ask for his code', style: _w(T.b.copyWith(fontSize: 17))), Text('It is on his phone, in FALCON', style: _sub(T.sm))])),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 10),
                Container(width: 60, height: 72, alignment: Alignment.center, decoration: BoxDecoration(color: C.navy3, borderRadius: BorderRadius.circular(16)),
                    child: Text(i < code.length ? code[i] : '·', style: const TextStyle(fontFamily: font, fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFFF2C14E))))]]),
              GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.2, children: [
                for (final k in const ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'])
                  k.isEmpty ? const SizedBox.shrink() : FCard(dark: true, padding: EdgeInsets.zero, onTap: busy ? null : () {
                    final v = k == '⌫' ? (code.isEmpty ? '' : code.substring(0, code.length - 1)) : (code + k).substring(0, (code + k).length.clamp(0, 4));
                    setState(() => code = v);
                    if (v.length == 4 && k != '⌫') send(v);
                  }, child: Center(child: Text(k, style: _w(T.b.copyWith(fontSize: 22))))),
              ]),
              ErrorLine(error, dark: true),
              Row(children: [
                Expanded(child: Btn('No code with him', kind: BtnKind.ghost, dark: true, small: true, onTap: () => setState(() => mode = 'nocode'))),
                const SizedBox(width: 10),
                Expanded(child: Btn('Could not deliver', kind: BtnKind.ghost, dark: true, small: true, onTap: () => setState(() => mode = 'fail'))),
              ]),
            ],
            if (mode == 'nocode') ...[
              FCard(dark: true, child: Text('Given without his code: it waits for his own confirmation, or the mess calls him. Write to whom you gave it.', style: _sub(T.sm))),
              Input(controller: note, hint: 'e.g. given to the site supervisor', lines: 3, dark: true, onChanged: (_) => setState(() {})),
              ErrorLine(error, dark: true),
              Btn('Mark given', kind: BtnKind.gold, busy: busy, onTap: note.text.trim().length < 3 ? null : () => act(() async {
                await call('deliver_without_code', {'p_batch': tr['id'], 'p_order': widget.order, 'p_person': widget.person, 'p_note': note.text.trim()});
                setState(() => mode = 'done');
                reload();
              })),
              Btn('Back to the code', kind: BtnKind.ghost, dark: true, onTap: () => setState(() => mode = 'code')),
            ],
            if (mode == 'fail') ...[
              Text('Why?', style: _w(T.h2)),
              Wrap2([for (final w in const ['Not at site', 'No answer', 'Refused', 'Wrong place', 'Road blocked', 'Other']) Chip2(w, dark: true, tone: why == w ? const Tone(C.gold, Color(0xFF1D1404)) : Tone.plain, onTap: () => setState(() => why = w))]),
              Input(controller: note, hint: 'More (optional)', lines: 2, dark: true),
              InfoLine('${firstName(pp['name'] as String?)} and the mess are told. A failed parcel is not billed.', dark: true),
              ErrorLine(error, dark: true),
              Btn('Mark not delivered', kind: BtnKind.red, busy: busy, onTap: () => act(() async {
                await call('fail_delivery', {'p_batch': tr['id'], 'p_order': widget.order, 'p_person': widget.person, 'p_reason': '$why${note.text.trim().isNotEmpty ? ' – ${note.text.trim()}' : ''}'});
                if (context.mounted) context.go('/driver/stops/${st['section_id']}');
              })),
              Btn('Back', kind: BtnKind.ghost, dark: true, onTap: () => setState(() => mode = 'code')),
            ],
          ],
        ));
      },
    );
  }
}

// ── d11 · Trip summary ──
class TripSummary extends StatefulWidget {
  const TripSummary({super.key, required this.id});
  final String id;
  @override
  State<TripSummary> createState() => _TripSummaryState();
}

class _TripSummaryState extends State<TripSummary> with Act {
  @override
  Widget build(BuildContext context) => Load<Rec?>(
        watch: _watch,
        loading: const Screen(dark: true, top: Top(dark: true, title: 'Trip', back: '/driver'), children: [Loading(dark: true)]),
        load: () => trip(widget.id),
        builder: (context, tr, reload) {
          if (tr == null) return const Screen(dark: true, top: Top(dark: true, title: 'Trip', back: '/driver'), children: [Empty(dark: true, icon: 'route', title: 'Not your trip')]);
          final stops = stopsOf(tr), people = [for (final st in stops) ...peopleOf(st)];
          final failed = people.where((p) => pState(p) == 'failed').toList(), given = people.where((p) => pState(p) == 'done').toList();
          final short = [for (final p in people) ...linesOf(p).where((l) => l['state'] == 'short')];
          return Screen(
            dark: true,
            top: Top(dark: true, title: 'Trip ${tr['code']}${tr['state'] == 'completed' ? ' done' : ''}', sub: '${time(tr['dispatched_at'] as String?)} – ${tr['completed_at'] != null ? time(tr['completed_at'] as String?) : 'now'}', back: '/driver'),
            children: [
              FCard(dark: true, child: Row(children: [Text('${given.length} / ${people.length}', style: _w(T.big)), const SizedBox(width: 14), Text('delivered', style: _sub(T.sm))])),
              Row(children: [Expanded(child: _stat('${failed.length}', 'not delivered')), const SizedBox(width: 10), Expanded(child: _stat('${short.length}', 'short'))]),
              FCard(dark: true, child: Column(children: [
                for (final x in stops)
                  Builder(builder: (_) {
                    final pp = peopleOf(x), f = pp.where((p) => pState(p) == 'failed').toList();
                    return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                      Expanded(child: Text('${x['section']} · ${pp.where((p) => pState(p) == 'done').length} of ${pp.length}${f.isNotEmpty ? ' · ${f.map((p) => firstName(p['name'] as String?)).join(', ')} not delivered' : ''}', style: _w(T.sm))),
                      Text(time(x['reached_at'] as String?), style: _sub(T.xs))]));
                  }),
              ])),
              if (failed.isNotEmpty) FCard(dark: true, child: Text('Give ${failed.length} parcel${failed.length > 1 ? 's' : ''} back at the mess counter.', style: _w(T.sm))),
              const InfoLine('Your location stops being shared when you close the trip.', icon: 'shield-check', dark: true),
              ErrorLine(error, dark: true),
              if (tr['state'] == 'on_the_way') Btn('Close the trip', kind: BtnKind.gold, busy: busy, onTap: () => act(() async {
                await call('complete_batch', {'p_batch': tr['id']});
                if (context.mounted) context.go('/driver');
              })),
            ],
          );
        },
      );
}
