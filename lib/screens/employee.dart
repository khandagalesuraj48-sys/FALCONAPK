// The employee's app – boards Main and e02–e16 – the app's own screens on the same data, actions and rules as the web's
// src/screens/employee.tsx. A guest uses the same meal, parcel, section, menu, order, tracking, confirmation, review and complaint
// screens (his own data only – the database decides).
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:url_launcher/url_launcher.dart';

import '../core/db.dart';
import '../core/fmt.dart';
import '../core/geo.dart';
import '../core/meals.dart';
import '../core/prefs.dart';
import '../core/session.dart';
import '../core/update.dart';
import '../ui/kit.dart';
import '../ui/look.dart';
import '../ui/road_map.dart';
import '../ui/gmap.dart';
import 'from_hr.dart' show hrToday, closeHrBanner;

const empTabs = [
  TabItem('/app', 'house', 'Home'), TabItem('/app/orders', 'receipt', 'Orders'), TabItem('/app/scan', 'scan-line', 'Scan mess QR', plus: true),
  TabItem('/app/menu', 'utensils', 'Menu'), TabItem('/app/me', 'user', 'Me'),
];
const guestTabs = [
  TabItem('/guest', 'house', 'Home'), TabItem('/guest/history', 'receipt', 'My orders'), TabItem('/app/menu', 'utensils', 'Menu'), TabItem('/app/me', 'user', 'Me'),
];
PillTabs tabsFor(Session s, String current) => PillTabs(tabs: s.kind == 'guest' ? guestTabs : empTabs, current: current);
String homeOf(Session s) => s.kind == 'guest' ? '/guest' : '/app';

/// The mess of this person and its meal times of a day (the web's useMyMess + useWindows).
class MessDay {
  MessDay(this.list, this.mess, this.wins);
  final List<Mess> list;
  final Mess? mess;
  final List<Win> wins;
  Win? win(String meal) => wins.where((w) => w.meal == meal).firstOrNull;
}

Future<MessDay> messDay(Session s, [String? date]) async {
  final list = await messes();
  final m = myMess(list, s.homeSiteId);
  return MessDay(list, m, await windows(m?.id, date ?? today()));
}

Widget _row(List<Widget> c, {double gap = 8}) => Row(children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(width: gap), c[i]]]);
Widget _col(List<Widget> c, {double gap = 12}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(height: gap), c[i]]]);

Widget foot(List<Widget> children) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
      child: SafeArea(top: false, child: _col(children, gap: 8)),
    );

Tone _stateTone(String st) => st == 'delivered' ? Tone.leaf : st == 'dispatched' ? Tone.blue : ['refused', 'cancelled', 'failed'].contains(st) ? Tone.red : Tone.amber;

// ── Main · Mess home ──
class EmpHome extends StatelessWidget {
  const EmpHome({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(MessDay, List<Rec>, Rec?, Rec?, int)>(
      watch: const ['orders', 'notifications'],
      loading: const Screen(children: [Loading()]),
      load: () async {
        final d = await messDay(s);
        final menus = d.mess == null ? <Rec>[] : await rows(sb.from('menus').select('meal,dishes').eq('mess_id', d.mess!.id).eq('service_date', today()));
        final active = await one(sb.from('orders').select().gte('service_date', today()).not('state', 'in', '(cancelled,refused,failed)').order('created_at', ascending: false).limit(1));
        final month = await call<dynamic>('my_month');
        final unread = await rows(sb.from('notifications').select('id').isFilter('read_at', null).limit(20));
        return (d, menus, active, month is Map ? Map<String, dynamic>.from(month) : null, unread.length);
      },
      builder: (context, x, reload) {
        final (d, menus, o, month, unread) = x;
        final meal = currentMeal(d.wins), w = d.win(meal), st = winState(w, today(), 'meal');
        String? dishes(String m) => (menus.where((r) => r['meal'] == m).firstOrNull?['dishes'] as List?)?.take(2).join(', ');
        const progress = {'requested': .15, 'accepted': .35, 'preparing': .5, 'ready': .6, 'dispatched': .8, 'delivered': 1.0};
        return Screen(
          // (23-11-2026, picture N8) opened from HR today: "‹ HR" goes back to the HR / ERP app
          top: Top(left: hrToday() != null ? Chip2('HR', icon: 'chevron-left', height: 36, onTap: () => SystemNavigator.pop()) : Av(initials(s.name)), title: '${greeting()}, ${firstName(s.name)}',
              sub: '${s.homeSite != null ? '${s.homeSite!.code} · ${s.homeSite!.name}' : ''}${d.mess != null ? ' · ${d.mess!.name}' : ''}',
              right: IconBox(icon: 'bell', label: 'Notifications', badge: unread > 0, onTap: () => context.push('/app/notifications'))),
          tabs: tabsFor(s, '/app'),
          children: [
            if (s.state == 'temporary')
              FCard(color: C.amberS, border: C.amberS, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), onTap: () => context.push('/start/temporary'),
                  child: _row([const Ico('clock-alert', size: 16, color: C.amber), Expanded(child: Text('Temporary access – waiting for the Site Admin', style: T.sm.copyWith(color: C.amber))), const Ico('chevron-right', size: 16, color: C.amber)])),
            // (23-11-2026, pictures N1, N2, N8) where he is: at the mess → "At the mess"; away → how far, the way, "Parcel"; opened from HR
            PlaceHero(s: s, d: d, meal: meal, w: w, st: st),
            if (o != null)
              FCard(lift: true, onTap: () => context.push('/app/orders/${o['id']}'), child: _col([
                _row([
                  Tile(o['state'] == 'dispatched' ? 'truck' : o['kind'] == 'meal' ? 'utensils' : 'package', tone: Tone.sf),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${mealName(o['meal'] as String?)} ${o['kind'] == 'meal' ? 'at the mess' : 'parcel'} · ${stateWord('${o['state']}')}', style: T.b),
                    Text('${o['code']}${o['service_date'] != today() ? ' · ${day(o['service_date'] as String?)}' : ''}', style: T.sm),
                  ])),
                ], gap: 12),
                Bar(progress['${o['state']}'] ?? .1, color: C.saffron),
                _row([Text(o['accepted_at'] != null ? 'Accepted ${time(o['accepted_at'] as String?)}' : 'Asked ${time(o['created_at'] as String?)}', style: T.xs), const Spacer(), Text('Open', style: T.xs)]),
              ])),
            _row([Expanded(child: Text('Today at ${d.mess?.name ?? 'the mess'}', style: T.h2)), InkWell(onTap: () => context.go('/app/menu'), child: Text('Full menu', style: T.sm.copyWith(color: C.leafD, fontWeight: FontWeight.w600)))]),
            IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              for (final m in const ['breakfast', 'lunch', 'dinner']) ...[
                if (m != 'breakfast') const SizedBox(width: 10),
                Expanded(child: Builder(builder: (_) {
                  final ww = d.win(m), cur = m == meal && st.open, t = ww == null ? null : winState(ww, today(), 'meal');
                  return FCard(padding: const EdgeInsets.all(12), color: cur ? const Color(0xFFFFFBF5) : null, border: cur ? const Color(0xFFE8B98A) : null,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Tile(mealIcon[m]!, tone: m == 'breakfast' ? Tone.cream : m == 'dinner' ? Tone.blue : Tone.sf, size: 40),
                        const SizedBox(height: 10),
                        Text(mealName(m), style: T.b.copyWith(fontSize: 14)),
                        Text(dishes(m) ?? 'Menu not out yet', style: T.xs, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 8),
                        Chip2(ww == null ? 'Not served' : cur ? 'Now' : t!.label == 'Closed' ? 'Over' : ww.serveFrom, tone: cur ? Tone.sf : Tone.cream, height: 24),
                      ]));
                })),
              ],
            ])),
            FCard(padding: const EdgeInsets.all(12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
              for (final (to, ic, tone, l) in const [('/app/orders', 'history', Tone.leaf, 'History'), ('/app/menu/poster', 'sparkles', Tone.plum, 'Poster'),
                  ('/app/complaints/new', 'message-square-warning', Tone.red, 'Complaint'), ('/app/guest', 'user-plus', Tone.blue, 'Guest')])
                InkWell(onTap: () => context.push(to), child: Padding(padding: const EdgeInsets.all(4), child: Column(children: [Tile(ic, tone: tone, size: 40), const SizedBox(height: 6), Text(l, style: T.xs.copyWith(color: C.ink))]))),
            ])),
            if (s.me?['may_group'] == true)
              FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/app/group'),
                  child: _row([const Tile('users', tone: Tone.leaf, size: 40), Expanded(child: Text('Meals for my team', style: T.b)), const Ico('chevron-right', size: 18)], gap: 12)),
            InkWell(onTap: () => context.go('/app/orders'), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _row([
              const Ico('utensils', size: 16, color: C.muted),
              Expanded(child: Text(month != null ? '${month['meals']} meals and ${month['parcels']} parcels this month' : ' ', style: T.sm)),
              const Ico('chevron-right', size: 16, color: C.muted),
            ]))),
          ],
        );
      },
    );
  }
}

// ── N1 / N2 / N8 · the top of the mess home: where he is (23-11-2026, his word: "app swata check krel user kuthe aahe – mess location
// madhe to asel tr mess ch auto yeil, mess pasun lamb asel tr mess che direction kiti lamb te dakhwel ani auto parcel ok day night auto
// select asel server time asel") – the same as the web's Home. The meal is the server's (core/fmt.dart istNow). ──
class PlaceHero extends StatefulWidget {
  const PlaceHero({super.key, required this.s, required this.d, required this.meal, required this.w, required this.st});
  final Session s;
  final MessDay d;
  final String meal;
  final Win? w;
  final WinState st;
  @override
  State<PlaceHero> createState() => _PlaceHeroState();
}

class _PlaceHeroState extends State<PlaceHero> {
  String? pick; // 'mess' | 'parcel' – his own choice over the automatic one
  bool get _hasPlace => widget.d.mess?.lat != null && widget.d.mess?.lng != null;
  @override
  void initState() {
    super.initState();
    Here.i.addListener(_moved);
    if (_hasPlace) Here.i.use();
  }

  void _moved() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    Here.i.removeListener(_moved);
    if (_hasPlace) Here.i.done();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.d.mess, meal = widget.meal, w = widget.w, st = widget.st, h = Here.i, hr = hrToday();
    final ok = _hasPlace && h.state == 'ok';
    final here = ok ? atMess(h.lat, h.lng, h.acc, m!.lat, m.lng, m.radiusM) : null;
    final away = ok ? metres(h.lat, h.lng, m!.lat!, m.lng!) : null;
    final mode = pick ?? (here == true ? 'mess' : here == false ? 'parcel' : null);
    final title = m == null ? 'Your site has no mess yet' : !st.open ? 'No meal open right now' : mode == 'mess' ? '${mealName(meal)} at the mess'
        : mode == 'parcel' ? '${mealName(meal)} parcel to your section' : 'Your $meal is ready to order';
    Widget seg() => Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(color: const Color(0xFF1F3354), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            for (final (k, l) in const [('mess', 'At the mess'), ('parcel', 'Parcel')])
              Expanded(child: Semantics(selected: mode == k, button: true, child: GestureDetector(
                key: Key('home-mode-$k'),
                onTap: () => setState(() => pick = k),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: mode == k ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(10)),
                  child: Text(l, style: TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600, color: mode == k ? C.ink : C.heroSub)),
                ),
              ))),
          ]),
        );
    return _col([
      if (hr != null && hr['banner'] == true) ...[
        FCard(color: C.leafS, border: C.leafS, padding: const EdgeInsets.fromLTRB(14, 10, 6, 10), child: _row([
          const Ico('shield-check', color: C.leafD),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Signed in through RCL HR', style: T.b.copyWith(fontSize: 14, color: C.leafD)),
            Text('${widget.s.name}${widget.s.me?['rcl_id'] != null ? ' · ${widget.s.me!['rcl_id']}' : ''} · no code needed again', style: T.xs.copyWith(color: C.leafD)),
          ])),
          IconButton(key: const Key('hr-banner-close'), tooltip: 'Close', onPressed: () => setState(closeHrBanner), icon: const Ico('x', size: 18, color: C.leafD)),
        ], gap: 10)),
        FCard(child: _col([
          Text('Comes from HR by itself', style: T.h2),
          for (final (ic, t) in const [('id-card', 'Name, employee code, site, mobile'), ('user-check', 'Present today (HR attendance)'), ('users', 'New employee or new site in HR – in the mess too')])
            _row([Ico(ic, size: 16, color: C.muted), Expanded(child: Text(t, style: T.sm)), const Ico('check', size: 16, color: C.leaf)]),
        ], gap: 10)),
      ],
      Hero2(child: _col([
        _row([
          if (here == true) Chip2('You are at ${m!.name}', icon: 'map-pin', tone: Tone.leaf, height: 26)
          else if (here == false && away != null) Chip2('${distText(away)} from ${m!.name}', icon: 'route', tone: Tone.sf, height: 26)
          else Chip2('${mealName(meal)} · ${st.open ? 'open ${st.label}' : st.label}', tone: Tone.sf, height: 26),
          const Spacer(),
          Text(mode != null ? nowHM() : dayLong(today()), style: T.xs.copyWith(color: C.heroSub)),
        ]),
        Text(title, key: const Key('home-title'), style: const TextStyle(fontFamily: font, fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.white)),
        if (w != null)
          mode != null
              ? _row([Ico(meal == 'dinner' ? 'moon' : 'sun', size: 16, color: C.heroSub), Expanded(child: Text('${mealName(meal)} by the server\'s time · ${mode == 'parcel' ? 'ask by ${w.orderBy}' : 'open till ${w.serveTo}'}', style: T.sm.copyWith(color: C.heroSub)))])
              : _row([const Ico('clock', size: 16, color: C.heroSub), Expanded(child: Text('Parcels asked by ${w.orderBy} · served ${w.serveFrom}–${w.serveTo}', style: T.sm.copyWith(color: C.heroSub)))]),
        if (hr != null && hr['in'] is String) _row([const Ico('user-check', size: 16, color: Color(0xFF7FD39A)), Expanded(child: Text('Present since ${hr['in']} · from HR attendance', style: T.sm.copyWith(color: C.heroSub)))]),
        if (mode != null) ...[
          seg(),
          mode == 'mess'
              ? Btn('Scan the counter QR', icon: 'scan-line', kind: BtnKind.gold, onTap: () => context.push('/app/scan'))
              : Btn('Ask $meal parcel', icon: 'package', kind: BtnKind.gold, onTap: () => context.push('/app/parcel')),
        ] else
          _row([
            Expanded(child: Btn('Scan QR', icon: 'scan-line', kind: BtnKind.gold, onTap: () => context.push('/app/scan'))),
            Expanded(child: Btn('Parcel', icon: 'package', kind: BtnKind.ghost, dark: true, onTap: () => context.push('/app/parcel'))),
          ], gap: 10),
      ], gap: 12)),
      if (_hasPlace && m != null)
        FCard(padding: EdgeInsets.zero, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: GMap(height: here == true ? 118 : 200, label: 'Map: you and ${m.name}', fallback: const SizedBox.shrink(), ring: (m.lat!, m.lng!, (m.radiusM ?? 100).toDouble()),
                marks: [Mark(m.lat!, m.lng!, 'mess', title: m.name), if (ok) Mark(h.lat, h.lng, 'you', title: 'You')]),
          ),
          Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 12), child: ok && away != null
              ? (here == true
                  ? _row([const Tile('circle-check', tone: Tone.leaf, size: 40), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Inside the mess area', key: const Key('home-place'), style: T.b), Text('${distText(away)} from the mess · by your phone\'s location', style: T.xs)]))], gap: 12)
                  : _row([
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${distText(away)} away', key: const Key('home-place'), style: T.b), Text('Going to the mess? Meal at the mess comes by itself there.', style: T.xs)])),
                      Btn('Directions', icon: 'navigation', kind: BtnKind.ghost, small: true, expand: false, onTap: () => launchUrl(directionsUrl(m.lat!, m.lng!), mode: LaunchMode.externalApplication)),
                    ], gap: 10))
              : h.state == 'asking'
                  ? Text('Finding where you are…', style: T.xs)
                  : _row([
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Location is off', key: const Key('home-place'), style: T.b), Text('Turn it on – the app then chooses "At the mess" or "Parcel" by itself.', style: T.xs)])),
                      Btn('Try again', kind: BtnKind.ghost, small: true, expand: false, onTap: () => Here.i.ask()),
                    ], gap: 10)),
        ])),
    ], gap: 14);
  }
}

// ── e02 · Scan the mess QR ──
class Scan extends StatefulWidget {
  const Scan({super.key});
  @override
  State<Scan> createState() => _ScanState();
}

class _ScanState extends State<Scan> {
  List<Mess> list = [];
  ({Mess mess, String counter})? found;
  List<Win> wins = [];
  String msg = 'Reading… hold the phone steady';
  final cam = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  @override
  void initState() {
    super.initState();
    messes().then((l) { if (mounted) setState(() => list = l); }).catchError((Object e) { if (mounted) setState(() => msg = words(e)); });
  }
  @override
  void dispose() { unawaited(cam.dispose()); super.dispose(); }
  void pick(Mess m, String counter) {
    Prefs.mess = m.id;
    setState(() => found = (mess: m, counter: counter));
    windows(m.id, today()).then((w) { if (mounted) setState(() => wins = w); }).catchError((_) {});
  }
  void detect(BarcodeCapture c) {
    if (found != null) return;
    final v = c.barcodes.firstOrNull?.rawValue ?? '';
    final m = RegExp(r'/m/([0-9a-f-]{36})(?:\?c=(\d+))?', caseSensitive: false).firstMatch(v);
    final mess = m == null ? null : list.where((x) => x.id == m.group(1)!.toLowerCase()).firstOrNull;
    if (mess != null) { pick(mess, m!.group(2) ?? '1'); unawaited(cam.stop()); } else if (v.isNotEmpty) { setState(() => msg = 'This is not a FALCON mess QR.'); }
  }
  @override
  Widget build(BuildContext context) {
    final meal = currentMeal(wins), w = wins.where((x) => x.meal == meal).firstOrNull;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1D21),
      body: SafeArea(child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Row(children: [
          IconBox(icon: 'chevron-left', label: 'Back', dark: true, onTap: () => context.canPop() ? context.pop() : context.go('/app')),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scan the mess QR', style: T.title.copyWith(color: Colors.white)), Text('On the counter or the mess door', style: T.sm.copyWith(color: const Color(0xFFC9D1DA))),
          ])),
        ])),
        const SizedBox(height: 24),
        Center(child: ClipRRect(borderRadius: BorderRadius.circular(28), child: SizedBox(width: 260, height: 260, child: Stack(children: [
          if (found == null) MobileScanner(controller: cam, onDetect: detect,
              errorBuilder: (c, e) => Center(child: Padding(padding: const EdgeInsets.all(16), child: Text('The camera is not allowed – choose the mess below.', textAlign: TextAlign.center, style: T.sm.copyWith(color: Colors.white)))))
          else Container(color: const Color(0xFF22262B), alignment: Alignment.center, child: const Ico('badge-check', size: 64, color: C.leafS)),
          for (final a in const [Alignment.topLeft, Alignment.topRight, Alignment.bottomLeft, Alignment.bottomRight])
            Align(alignment: a, child: Container(width: 54, height: 54, decoration: BoxDecoration(border: Border(
              left: a.x < 0 ? const BorderSide(color: Color(0xFFF2A54A), width: 5) : BorderSide.none,
              right: a.x > 0 ? const BorderSide(color: Color(0xFFF2A54A), width: 5) : BorderSide.none,
              top: a.y < 0 ? const BorderSide(color: Color(0xFFF2A54A), width: 5) : BorderSide.none,
              bottom: a.y > 0 ? const BorderSide(color: Color(0xFFF2A54A), width: 5) : BorderSide.none,
            )))),
        ])))),
        const SizedBox(height: 18),
        Text(found != null ? 'Read' : msg, style: T.sm.copyWith(color: const Color(0xFFD6DCE4))),
        const SizedBox(height: 18),
        Expanded(child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
            if (found != null) _col([
              _row([const Tile('badge-check', tone: Tone.leaf), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${found!.mess.name} · Counter ${found!.counter}', style: T.b.copyWith(fontSize: 17)),
                Text(w != null ? '${mealName(meal)} till ${w.serveTo}' : 'No meal open now', style: T.sm),
              ]))], gap: 12),
              const InfoLine('A scan only asks for your meal. It counts when the mess marks it served.'),
              Btn('Eat at the mess', icon: 'utensils', kind: BtnKind.leaf, onTap: () => context.go('/app/meal?counter=${found!.counter}')),
              Btn('Take a parcel', icon: 'package', kind: BtnKind.ghost, onTap: () => context.go('/app/parcel')),
            ])
            else _col([
              Text('Or choose the mess', style: T.h2),
              if (list.isEmpty) const Loading(),
              for (final m in list)
                FCard(padding: const EdgeInsets.all(12), onTap: () => pick(m, '1'),
                    child: _row([const Tile('store', tone: Tone.leaf, size: 40), Expanded(child: Text(m.name, style: T.b)), const Ico('chevron-right', size: 18)], gap: 12)),
            ], gap: 10),
          ]),
        )),
      ])),
    );
  }
}

// ── e03 · Meal at the mess ──
class MealAtMess extends StatefulWidget {
  const MealAtMess({super.key, this.counter});
  final String? counter;
  @override
  State<MealAtMess> createState() => _MealAtMessState();
}

class _MealAtMessState extends State<MealAtMess> with Act {
  String? meal;
  final extra = <String, int>{};
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(MessDay, List<Rec>, List<Rec>, Rec?)>(
      loading: const Screen(top: Top(title: 'Meal at the mess', back: ''), children: [Loading()]),
      load: () async {
        final d = await messDay(s);
        return (d, await items(),
            await rows(sb.from('order_lines').select('meal,order_id').eq('person_id', s.personId ?? '').eq('service_date', today()).eq('is_meal', true).neq('state', 'cancelled')),
            await guestVisit(s.personId, s.kind));
      },
      builder: (context, x, reload) {
        final (d, its, mine, visit) = x;
        final m = meal ?? currentMeal(d.wins), w = d.win(m), st = winState(w, today(), 'meal');
        final had = mine.where((r) => r['meal'] == m).firstOrNull;
        final mealItem = its.where((i) => i['kind'] == 'meal' && i['meal'] == m).firstOrNull;
        final extras = its.where((i) => i['kind'] == 'extra').toList();
        final n = extra.values.fold<int>(0, (a, b) => a + b);
        Future<void> ask() => act(() async {
              final lines = [{'item': mealItem!['code']}, for (final e in extra.entries) if (e.value > 0) {'item': e.key, 'qty': e.value}];
              final r = await call<dynamic>('request_order', {'p_mess': d.mess!.id, 'p_date': today(), 'p_meal': m, 'p_kind': 'meal', 'p_lines': lines,
                'p_note': widget.counter != null ? 'Counter ${widget.counter}' : null, 'p_visit': visit?['id']});
              final id = r['order_id'] ?? (r['existing'] as List).first['order_id'];
              if (context.mounted) context.go('/app/orders/$id');
            });
        return Screen(
          top: Top(title: 'Meal at the mess', sub: '${d.mess?.name ?? ''}${widget.counter != null ? ' · Counter ${widget.counter}' : ''}', back: ''),
          foot: foot([
            InfoLine('Change or cancel for ${w?.changeMinutes ?? 0} min – until the mess accepts', icon: 'timer'),
            Btn('Ask for $m · 1 ${(mealItem?['name'] as String? ?? 'meal').toLowerCase()}${n > 0 ? ', $n extra' : ''}', kind: BtnKind.leaf, busy: busy,
                onTap: !st.open || had != null || mealItem == null || d.mess == null ? null : ask),
          ]),
          children: [
            Row(children: [
              for (final xm in meals) ...[
                if (xm != meals.first) const SizedBox(width: 8),
                Expanded(child: Builder(builder: (_) {
                  final t = winState(d.win(xm), today(), 'meal'), on = xm == m;
                  return Opacity(opacity: on || t.open ? 1 : .55, child: FCard(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), color: on ? C.ink : null, border: on ? C.ink : null,
                      onTap: () => setState(() => meal = xm),
                      child: Column(children: [
                        Ico(mealIcon[xm]!, color: on ? Colors.white : C.ink),
                        const SizedBox(height: 4),
                        Text(mealName(xm), style: T.b.copyWith(fontSize: 13, color: on ? Colors.white : C.ink)),
                        Text(t.label, style: T.xs.copyWith(color: on ? const Color(0xFFC9D2C9) : C.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ])));
                })),
              ],
            ]),
            FCard(child: _col([
              _row([Expanded(child: Text(had != null ? 'You have $m already' : st.open ? 'You can take $m' : '${mealName(m)} is closed', style: T.h2)),
                Chip2('Checked', icon: 'shield-check', tone: had != null || !st.open ? Tone.amber : Tone.leaf, height: 26)]),
              _row([Ico(had != null ? 'circle-x' : 'circle-check', size: 18, color: C.muted), Expanded(child: Text(had != null ? 'One $m a day – yours is in your orders' : 'No $m taken yet today', style: T.sm)), Text('Mess', style: T.xs)]),
              _row([const Ico('info', size: 18, color: C.muted), Expanded(child: Text('Attendance and leave come from HR when it is connected', style: T.sm)), Text('HR', style: T.xs)]),
            ], gap: 10)),
            if (mealItem != null) FCard(child: _col([
              _row([Tile(mealIcon[m]!, tone: Tone.sf, size: 40), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${mealItem['name']}', style: T.b), Text('One a person', style: T.xs)])), const Chip2('1', height: 28)], gap: 12),
              if (extras.isNotEmpty) const Hr(),
              for (final e in extras)
                _row([Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${e['name']}', style: T.b), Text('Extra items need the mess\'s OK', style: T.xs)])),
                  Stepper2(value: extra['${e['code']}'] ?? 0, max: 10, onChanged: (v) => setState(() => extra['${e['code']}'] = v))]),
            ])),
            if (m != 'dinner') InkWell(onTap: () => setState(() => meal = 'dinner'), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _row([
              const Ico('clock-alert', size: 16, color: C.leafD), Expanded(child: Text('Working late? Ask for dinner', style: T.sm.copyWith(color: C.leafD, fontWeight: FontWeight.w600))), const Ico('chevron-right', size: 16, color: C.leafD)]))),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── e04 · Parcel ──
class Parcel extends StatefulWidget {
  const Parcel({super.key});
  @override
  State<Parcel> createState() => _ParcelState();
}

class _ParcelState extends State<Parcel> with Act {
  String? meal;
  final extra = <String, int>{};
  String how = 'delivery';
  final note = TextEditingController();
  @override
  void dispose() { note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (s.state == 'temporary') {
      return const Screen(top: Top(title: 'Parcel', back: ''), children: [Denied(text: 'Your temporary access is for meals at your own site\'s mess only.')]);
    }
    return Load<(MessDay, List<Rec>, List<Rec>, Rec?)>(
      loading: const Screen(top: Top(title: 'Parcel', back: ''), children: [Loading()]),
      load: () async {
        final d = await messDay(s);
        return (d, await items(), await sections(d.mess?.siteId), await guestVisit(s.personId, s.kind));
      },
      builder: (context, x, reload) {
        final (d, its, secs, visit) = x;
        final m = meal ?? currentMeal(d.wins), w = d.win(m), st = winState(w, today(), 'parcel');
        final secId = pickedSection ?? visit?['section_id'] as String? ?? s.me?['home_section_id'] as String?;
        final sec = secs.where((r) => r['id'] == secId).firstOrNull;
        final mealItem = its.where((i) => i['kind'] == 'meal' && i['meal'] == m).firstOrNull;
        final extras = its.where((i) => i['kind'] == 'extra').toList();
        final n = extra.values.fold<int>(0, (a, b) => a + b);
        Future<void> ask() => act(() async {
              if (how == 'delivery' && sec == null) throw DbError('Choose where to deliver.');
              final lines = [{'item': mealItem!['code']}, for (final e in extra.entries) if (e.value > 0) {'item': e.key, 'qty': e.value}];
              final r = await call<dynamic>('request_order', {'p_mess': d.mess!.id, 'p_date': today(), 'p_meal': m, 'p_kind': how, 'p_lines': lines,
                'p_section': how == 'delivery' ? sec!['id'] : null, 'p_note': note.text.trim().isEmpty ? null : note.text.trim(), 'p_visit': visit?['id']});
              final id = r['order_id'] ?? (r['existing'] as List).first['order_id'];
              if (context.mounted) context.go('/app/orders/$id');
            });
        final circle = (sec?['circles'] as Map?)?['code'];
        return Screen(
          top: Top(title: '${mealName(m)} parcel', sub: w != null ? 'Order by ${w.orderBy}' : 'No parcels for this meal', back: ''),
          foot: foot([
            _row([Expanded(child: Text('1 ${(mealItem?['name'] as String? ?? 'meal').toLowerCase()}${n > 0 ? ' · $n extra' : ''}', style: T.sm)), Text('Change or cancel for ${w?.changeMinutes ?? 0} min', style: T.xs)]),
            Btn('Ask for the parcel', icon: 'package-check', kind: BtnKind.sf, busy: busy, onTap: !st.open || mealItem == null || d.mess == null ? null : ask),
          ]),
          children: [
            Seg(items: const [('meal', 'At the mess'), ('parcel', 'Parcel to my site')], value: 'parcel', onChanged: (v) { if (v == 'meal') context.go('/app/meal'); }),
            Wrap2([for (final xm in meals) Chip2(mealName(xm), tone: xm == m ? Tone.on : Tone.plain, onTap: () => setState(() => meal = xm))], gap: 6),
            if (how == 'delivery')
              FCard(onTap: () async { await context.push('/app/section'); if (mounted) setState(() {}); }, child: _row([
                const Tile('map-pin', tone: Tone.navy),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Deliver to${secId == s.me?['home_section_id'] ? ' · your work place' : ''}', style: T.xs),
                  Text(sec != null ? 'Circle ${circle ?? ''} · Section ${sec['code']}' : 'Choose the section', style: T.b),
                  Text(sec != null ? '${sec['km'] != null ? 'Km ${sec['km']}' : ''}${sec['place'] != null ? ' · ${sec['place']}' : ''}' : ' ', style: T.sm),
                ])),
                Text('Change', style: T.sm.copyWith(color: C.leafD, fontWeight: FontWeight.w600)),
              ], gap: 12)),
            FCard(child: _col([
              if (mealItem != null) _row([Tile(mealIcon[m]!, tone: Tone.sf, size: 40), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${mealItem['name']}', style: T.b), Text('Packed · one a person', style: T.xs)])), const Chip2('1', height: 28)], gap: 12),
              for (final e in extras)
                _row([Tile('${e['code']}'.startsWith('water') ? 'glass-water' : 'salad', tone: '${e['code']}'.startsWith('water') ? Tone.blue : Tone.leaf, size: 40),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${e['name']}', style: T.b), Text('Extra – needs the mess\'s OK', style: T.xs)])),
                  Stepper2(value: extra['${e['code']}'] ?? 0, max: 10, onChanged: (v) => setState(() => extra['${e['code']}'] = v))], gap: 12),
            ])),
            Field('When', Wrap2([
              Chip2('With the van', tone: how == 'delivery' ? Tone.on : Tone.plain, onTap: () => setState(() => how = 'delivery')),
              Chip2('I\'ll collect', tone: how == 'parcel' ? Tone.on : Tone.plain, onTap: () => setState(() => how = 'parcel')),
            ])),
            Field('Note for the mess', Input(controller: note, hint: 'e.g. no onion, leave at the site office', maxLength: 300)),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── e05 · Circle / section ──
class SectionPick extends StatefulWidget {
  const SectionPick({super.key});
  @override
  State<SectionPick> createState() => _SectionPickState();
}

class _SectionPickState extends State<SectionPick> {
  String circle = '';
  String? sel;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    sel ??= pickedSection ?? s.me?['home_section_id'] as String?;
    return Load<List<Rec>>(
      loading: const Screen(top: Top(title: 'Where are you working?', back: ''), children: [Loading()]),
      load: () async {
        final d = await messDay(s);
        return sections(d.mess?.siteId ?? s.homeSiteId);
      },
      builder: (context, secs, reload) {
        final map = toMap(secs);
        final list = secs.where((x) => circle.isEmpty || (x['circles'] as Map?)?['code'] == circle).toList();
        final chosen = secs.where((x) => x['id'] == sel).firstOrNull;
        final groups = list.map((x) => '${(x['circles'] as Map?)?['code'] ?? ''}').toSet().toList();
        return Screen(
          top: Top(title: 'Where are you working?', sub: s.homeSite?.code, back: ''),
          foot: foot([Btn('Deliver to ${chosen != null ? '${chosen['code']}${chosen['km'] != null ? ' · Km ${chosen['km']}' : ''}' : '…'}', kind: BtnKind.leaf,
              onTap: chosen == null ? null : () { pickedSection = sel; context.pop(); })]),
          children: [
            ClipRRect(borderRadius: BorderRadius.circular(20), child: GMap(height: 220, label: 'Map: the site\'s sections',
                marks: [for (final x in secs) if (x['lat'] != null && x['lng'] != null) Mark(toD(x['lat']), toD(x['lng']), x['id'] == sel ? 'mine' : 'stop', label: '${x['code']}', title: '${x['name']}')],
                fallback: RoadMap(sections: map.sections, circles: map.circles, mine: sel, height: 220, label: 'The road with its sections'))),
            Wrap2([
              Chip2('All', tone: circle.isEmpty ? Tone.on : Tone.plain, onTap: () => setState(() => circle = '')),
              for (final c in map.circles) Chip2('Circle ${c.code}', tone: circle == c.code ? Tone.on : Tone.plain, onTap: () => setState(() => circle = c.code)),
            ]),
            if (list.isEmpty) const Empty(icon: 'map', title: 'No sections yet', text: 'The Site Admin adds the sections of the road.'),
            for (final g in groups) ...[
              Text('Circle $g', style: T.xs.copyWith(fontWeight: FontWeight.w600)),
              for (final (i, x) in list.where((y) => '${(y['circles'] as Map?)?['code'] ?? ''}' == g).indexed)
                FCard(padding: const EdgeInsets.all(12), border: x['id'] == sel ? C.leaf : null, onTap: () => setState(() => sel = x['id'] as String),
                    child: _row([Av('${i + 1}', size: 34, tone: Tone.navy), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${x['code']}${x['km'] != null ? ' · Km ${x['km']}' : ''}', style: T.b), Text('${x['place'] ?? x['name']}', style: T.xs)])),
                      Ico(x['id'] == sel ? 'circle-check' : 'circle-dot', size: 18, color: x['id'] == sel ? C.leaf : C.muted)], gap: 12)),
            ],
            const InfoLine('A place other than your work place is shown to the Site Admin.'),
          ],
        );
      },
    );
  }
}

// ── e06 · Menu ──
class Menu extends StatefulWidget {
  const Menu({super.key});
  @override
  State<Menu> createState() => _MenuState();
}

class _MenuState extends State<Menu> {
  String d = today();
  String meal = 'lunch';
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final days = [for (var i = 0; i < 5; i++) today(i)];
    return Load<(MessDay, Rec?)>(
      key: ValueKey('$d-$meal'),
      loading: Screen(top: const Top(title: 'Menu'), tabs: tabsFor(s, '/app/menu'), children: const [Loading()]),
      load: () async {
        final md = await messDay(s, d);
        final menu = md.mess == null ? null : await one(sb.from('menus').select('dishes,note,published_at').eq('mess_id', md.mess!.id).eq('service_date', d).eq('meal', meal).limit(1));
        return (md, menu);
      },
      builder: (context, x, reload) {
        final (md, menu) = x;
        final w = md.win(meal);
        return Screen(
          top: Top(title: 'Menu', sub: md.mess?.name ?? '', back: homeOf(s), right: IconBox(icon: 'sparkles', label: 'Menu poster', onTap: () => context.push('/app/menu/poster?d=$d&m=$meal'))),
          tabs: tabsFor(s, '/app/menu'),
          children: [
            Row(children: [
              for (final (i, x) in days.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: Opacity(opacity: x == d || i <= 2 ? 1 : .6, child: FCard(padding: const EdgeInsets.symmetric(vertical: 8), color: x == d ? C.ink : null, border: x == d ? C.ink : null,
                    onTap: () => setState(() => d = x),
                    child: Column(children: [
                      Text(dayLong(x).split(' ').first, style: T.xs.copyWith(color: x == d ? const Color(0xFFC9D2C9) : C.muted)),
                      Text(dayLong(x).split(' ')[1], style: T.b.copyWith(fontSize: 18, color: x == d ? Colors.white : C.ink)),
                    ])))),
              ],
            ]),
            Seg(items: [for (final m in meals) (m, mealName(m))], value: meal, onChanged: (v) => setState(() => meal = v)),
            if (menu == null) const Empty(icon: 'utensils', title: 'The menu is not out yet', text: 'The mess publishes it before the meal.')
            else FCard(lift: true, child: _col([
              Text('${mealName(meal)}${w != null ? ' · ${w.serveFrom} – ${w.serveTo}' : ''}', style: T.h2),
              Text('Published ${time(menu['published_at'] as String?)}', style: T.xs),
              const Hr(),
              for (final dish in (menu['dishes'] as List? ?? const []))
                _row([Container(width: 14, height: 14, decoration: BoxDecoration(border: Border.all(color: C.leaf, width: 1.5), borderRadius: BorderRadius.circular(3)),
                    alignment: Alignment.center, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: C.leaf, shape: BoxShape.circle))),
                  Expanded(child: Text('$dish', style: T.body))], gap: 10),
            ], gap: 10)),
            if (menu?['note'] != null)
              FCard(color: const Color(0xFFFFFBF5), border: const Color(0xFFF1D3B0), child: _row([const Ico('history', size: 18), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('From the mess', style: T.b.copyWith(fontSize: 14)), Text('${menu!['note']}', style: T.sm)]))], gap: 12)),
            if (menu != null) Btn('See the poster', icon: 'sparkles', kind: BtnKind.navy, onTap: () => context.push('/app/menu/poster?d=$d&m=$meal')),
          ],
        );
      },
    );
  }
}

// ── e07 · Today's poster (drawn from the published menu – the text decides what is served) ──
class Poster extends StatelessWidget {
  const Poster({super.key, this.date, this.meal});
  final String? date, meal;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final d = date ?? today(), m = meal ?? 'lunch';
    return Load<(MessDay, Rec?)>(
      loading: const Screen(top: Top(title: 'Today\'s poster', back: ''), children: [Loading()]),
      load: () async {
        final md = await messDay(s, d);
        final menu = md.mess == null ? null : await one(sb.from('menus').select('dishes').eq('mess_id', md.mess!.id).eq('service_date', d).eq('meal', m).limit(1));
        return (md, menu);
      },
      builder: (context, x, reload) {
        final (md, menu) = x;
        final w = md.win(m);
        final dishes = [for (final x in (menu?['dishes'] as List? ?? const [])) '$x'];
        final head = '${md.mess?.name ?? ''} · ${dayLong(d)}'.toUpperCase();
        final share = 'https://wa.me/?text=${Uri.encodeComponent('${md.mess?.name ?? ''} – ${mealName(m)}, ${day(d)}:\n${dishes.join(', ')}${w != null ? '\n${w.serveFrom}–${w.serveTo}' : ''}')}';
        return Screen(
          background: const Color(0xFFE9E4D8),
          top: const Top(title: 'Today\'s poster', sub: 'Drawn from the published menu', back: ''),
          children: [
            if (menu == null) const Empty(icon: 'sparkles', title: 'No menu to draw', text: 'The poster is drawn once the mess publishes the menu.')
            else ...[
              Container(
                constraints: const BoxConstraints(minHeight: 460),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), gradient: const RadialGradient(center: Alignment(0, -.25), radius: 1.0, colors: [Color(0xFF1C3157), Color(0xFF0E1B33), Color(0xFF0A1428)], stops: [0, .62, 1]),
                    boxShadow: const [BoxShadow(color: Color(0x590E1B33), blurRadius: 50, offset: Offset(0, 24))]),
                child: Container(
                  margin: const EdgeInsets.all(14),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x73D99E39))),
                  child: Column(children: [
                    Text(head, textAlign: TextAlign.center, style: const TextStyle(fontFamily: font, fontSize: 12, letterSpacing: 1.4, color: Color(0xFFD9B26A), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Today\'s $m', textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'serif', fontSize: 40, height: 1.02, color: Color(0xFFF6E7C8))),
                    const SizedBox(height: 18),
                    Container(width: 180, height: 180, decoration: const BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(center: Alignment(-.2, -.3), colors: [Color(0xFFF4F1EA), Color(0xFFD9D3C5), Color(0xFFB9B1A0)]),
                        boxShadow: [BoxShadow(color: Color(0x73000000), blurRadius: 34, offset: Offset(0, 18))]),
                        child: Stack(children: const [
                          Positioned(left: 22, top: 26, child: _Bowl(58, [Color(0xFFF2C14E), Color(0xFFD79A1E)])),
                          Positioned(left: 92, top: 18, child: _Bowl(62, [Color(0xFFD8A24A), Color(0xFFA8661C)])),
                          Positioned(left: 102, top: 92, child: _Bowl(54, [Color(0xFFFFFFFF), Color(0xFFE8E2D2)])),
                          Positioned(left: 26, top: 94, child: _Bowl(66, [Color(0xFFFFFDF7), Color(0xFFEDE6D3)])),
                        ])),
                    const SizedBox(height: 20),
                    Wrap(spacing: 18, runSpacing: 6, alignment: WrapAlignment.center, children: [for (final dish in dishes) Text(dish, style: const TextStyle(fontFamily: font, fontSize: 15, color: Colors.white))]),
                    if (w != null) ...[const SizedBox(height: 20), Text('${w.serveFrom} – ${w.serveTo}', style: const TextStyle(fontFamily: font, fontSize: 13, color: Color(0xFFD9B26A)))],
                  ]),
                ),
              ),
              const InfoLine('The menu text decides what is served – the picture only shows it.', icon: 'shield-check'),
              Btn('Share on WhatsApp', icon: 'message-circle', kind: BtnKind.whatsapp, onTap: () => launchUrl(Uri.parse(share), mode: LaunchMode.externalApplication)),
            ],
          ],
        );
      },
    );
  }
}

class _Bowl extends StatelessWidget {
  const _Bowl(this.size, this.colors);
  final double size;
  final List<Color> colors;
  @override
  Widget build(BuildContext context) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle,
      gradient: RadialGradient(center: const Alignment(-.1, -.2), colors: colors), border: Border.all(color: const Color(0xFFC9C2B2), width: 5)));
}

// ── My orders (the Orders tab's list – each opens e08) ──
class Orders extends StatelessWidget {
  const Orders({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<List<Rec>>(
      watch: const ['orders'],
      loading: Screen(top: const Top(title: 'My orders'), tabs: tabsFor(s, '/app/orders'), children: const [Loading()]),
      load: () => rows(sb.from('orders').select().order('created_at', ascending: false).limit(40)),
      builder: (context, list, reload) => Screen(
        top: Top(title: 'My orders', sub: 'Meals, parcels and deliveries', back: homeOf(s)),
        tabs: tabsFor(s, '/app/orders'),
        children: [
          if (list.isEmpty) const Empty(icon: 'receipt', title: 'No orders yet', text: 'Scan the mess QR or ask for a parcel.'),
          for (final o in list)
            FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/app/orders/${o['id']}'), child: _row([
              Tile(o['kind'] == 'meal' ? 'utensils' : 'package', tone: Tone.sf, size: 40),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['code']}', style: T.b),
                Text('${mealName(o['meal'] as String?)} · ${o['kind'] == 'meal' ? 'at the mess' : o['kind']} · ${day(o['service_date'] as String?)}${o['is_group'] == true ? ' · group' : ''}', style: T.xs),
              ])),
              Chip2(stateWord('${o['state']}'), tone: _stateTone('${o['state']}'), height: 26),
            ], gap: 12)),
        ],
      ),
    );
  }
}

/// An order with everything its screens show (the web's useOrder).
class OrderData {
  OrderData(this.o, this.lines, this.code, this.mess, this.sec, this.conf);
  final Rec o;
  final List<Rec> lines, conf;
  final Rec? code, mess, sec;
}

Future<OrderData?> loadOrder(String id) async {
  final o = await one(sb.from('orders').select().eq('id', id).limit(1));
  if (o == null) return null;
  final lines = rows(sb.from('order_lines').select('*,items(name,code)').eq('order_id', id));
  final code = one(sb.from('delivery_codes').select('code,used_at').eq('order_id', id).limit(1));
  final mess = one(sb.from('messes').select('name').eq('id', '${o['mess_id']}').limit(1));
  final sec = o['to_section_id'] != null ? one(sb.from('sections').select('code,km,place').eq('id', '${o['to_section_id']}').limit(1)) : Future<Rec?>.value(null);
  final conf = rows(sb.from('confirmations').select('order_line_id,kind,qty_received,at'));
  return OrderData(o, await lines, await code, await mess, await sec, await conf);
}

Future<Rec?> loadVan(String id) async {
  final r = await call<dynamic>('my_van', {'p_order': id});
  return r is Map ? Map<String, dynamic>.from(r) : null;
}

List<Rec> _stops(Rec? v) => [for (final x in (v?['stops'] as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

// ── e08 · Order status ──
class OrderStatus extends StatefulWidget {
  const OrderStatus({super.key, required this.id});
  final String id;
  @override
  State<OrderStatus> createState() => _OrderStatusState();
}

class _OrderStatusState extends State<OrderStatus> with Act {
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(OrderData?, Rec?)>(
      watch: const ['orders', 'order_lines', 'batches', 'batch_stops'],
      loading: const Screen(top: Top(title: 'Order', back: ''), children: [Loading()]),
      load: () async {
        final r = await loadOrder(widget.id);
        final van = r != null && ['dispatched', 'delivered'].contains(r.o['state']) ? await loadVan(widget.id) : null;
        return (r, van);
      },
      builder: (context, x, reload) {
        final (r, van) = x;
        if (r == null) return const Screen(top: Top(title: 'Order', back: ''), children: [Denied(text: 'This order is not yours.')]);
        final o = r.o, st = '${o['state']}';
        final mine = r.lines.where((l) => l['person_id'] == s.personId).toList();
        final what = mine.map((l) => '${l['qty']} ${'${(l['items'] as Map?)?['name'] ?? ''}'.toLowerCase()}').join(' · ');
        final myStop = _stops(van).where((x) => x['mine'] == true).firstOrNull;
        final changeOpen = o['change_until'] != null && (DateTime.tryParse('${o['change_until']}')?.isAfter(DateTime.now()) ?? false);
        final canCancel = o['requested_by'] == s.personId && (st == 'requested' || (st == 'accepted' && changeOpen));
        final delivered = mine.any((l) => ['served', 'delivered', 'short'].contains(l['state']));
        final confirmed = mine.isNotEmpty && mine.every((l) => r.conf.any((c) => c['order_line_id'] == l['id']));
        final steps = <(String, String, bool)>[
          ('Asked', '${time(o['created_at'] as String?)} · from the app', true),
          (st == 'refused' ? 'Refused by the mess' : 'Accepted by the mess',
              o['accepted_at'] != null ? '${time(o['accepted_at'] as String?)}${st == 'refused' ? ' · ${o['refused_reason'] ?? ''}' : ' · change window ${changeOpen ? 'open' : 'closed'}'}' : o['host_state'] == 'waiting' ? 'waiting for the host\'s OK' : 'waiting',
              o['accepted_at'] != null),
          ('Preparing · Ready', o['ready_at'] != null ? 'ready ${time(o['ready_at'] as String?)}' : '', ['ready', 'dispatched', 'delivered'].contains(st)),
          if (o['kind'] == 'delivery') ('On the way', van?['dispatched_at'] != null ? '${time(van!['dispatched_at'] as String?)} · ${van['driver'] ?? ''} · ${van['vehicle'] ?? ''}' : 'with the van', ['dispatched', 'delivered'].contains(st)),
          (o['kind'] == 'meal' ? 'Served' : 'Delivered', o['kind'] == 'meal' ? 'At the counter' : 'Give the driver your code, check the quantity', delivered),
          ('Closed', 'After your confirmation', delivered && confirmed),
        ];
        final nowAt = steps.indexWhere((x) => !x.$3);
        final sec = r.sec;
        return Screen(
          top: Top(title: '${o['code']}', sub: '${mealName(o['meal'] as String?)} ${o['kind'] == 'meal' ? 'at the mess' : 'parcel'} · ${dayLong('${o['service_date']}')}', back: ''),
          children: [
            FCard(child: _row([
              Tile(o['kind'] == 'meal' ? 'utensils' : 'package', tone: Tone.sf),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(what.isNotEmpty ? what : '${r.lines.length} people', style: T.b),
                Text(o['kind'] == 'delivery' && sec != null ? 'To ${sec['code']}${sec['km'] != null ? ' · Km ${sec['km']}' : ''}${sec['place'] != null ? ' · ${sec['place']}' : ''}' : '${r.mess?['name'] ?? ''}', style: T.sm),
              ])),
              Chip2(stateWord(st), tone: _stateTone(st), height: 26),
            ], gap: 12)),
            FCard(padding: const EdgeInsets.fromLTRB(16, 18, 16, 4), child: Timeline([
              for (final (i, (t, sub, done)) in steps.indexed)
                TlStep(t, sub: sub.isEmpty ? null : sub, state: done ? 'done' : i == nowAt ? 'now' : 'next', icon: !done && i == nowAt && st == 'dispatched' ? 'truck' : null),
            ])),
            if (r.code != null || myStop?['eta'] != null)
              Row(children: [
                if (r.code != null) Expanded(child: FCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Your code', style: T.xs), Text('${r.code!['code']}'.split('').join(' '), style: T.b.copyWith(fontSize: 24, letterSpacing: 2))]))),
                if (r.code != null && myStop?['eta'] != null) const SizedBox(width: 10),
                if (myStop?['eta'] != null) Expanded(child: FCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Arrives about', style: T.xs), Text(time(myStop!['eta'] as String?), style: T.b.copyWith(fontSize: 24, color: C.sfD))]))),
              ]),
            if (st == 'dispatched') Btn('Track live', icon: 'navigation', kind: BtnKind.sf, onTap: () => context.push('/app/orders/${o['id']}/track')),
            if (st == 'dispatched' && r.code != null && r.code!['used_at'] == null) Btn('The van is here – show my code', icon: 'package-check', kind: BtnKind.ghost, onTap: () => context.push('/app/orders/${o['id']}/confirm')),
            if (delivered && !confirmed) Btn('Check what I got', icon: 'package-check', kind: BtnKind.leaf, onTap: () => context.push('/app/orders/${o['id']}/quantity')),
            if (delivered && confirmed) Btn('Review (optional)', icon: 'star', kind: BtnKind.ghost, onTap: () => context.push('/app/orders/${o['id']}/review')),
            if (canCancel) Btn('Take it back', icon: 'x', kind: BtnKind.ghost, busy: busy, onTap: () => act(() async { await call('cancel_order', {'p_order': o['id'], 'p_reason': 'Taken back by the person'}); reload(); })),
            if (!['cancelled', 'refused'].contains(st)) Btn('Something wrong? Complaint', icon: 'message-square-warning', kind: BtnKind.ghost, onTap: () => context.push('/app/complaints/new?order=${o['id']}')),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── e09 · Live tracking ──
class Track extends StatelessWidget {
  const Track({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(Rec?, List<Rec>, OrderData?, Mess?)>(
      watch: const ['batches', 'batch_stops', 'track_points'],
      loading: const Screen(top: Top(title: 'Track', back: ''), children: [Loading()]),
      load: () async {
        final d = await messDay(s);
        return (await loadVan(id), await sections(d.mess?.siteId), await loadOrder(id), d.mess);
      },
      builder: (context, x, reload) {
        final (v, secs, r, mess) = x;
        if (v == null) return const Screen(top: Top(title: 'Track', back: ''), children: [Empty(icon: 'truck', title: 'Not on the way', text: 'The van\'s place is shown only while your parcel is on the way.')]);
        final stops = _stops(v), mine = stops.where((x) => x['mine'] == true).firstOrNull;
        final reached = stops.where((x) => x['reached_at'] != null).toList();
        final last = reached.lastOrNull, nextKm = stops.where((x) => x['reached_at'] == null).firstOrNull?['km'];
        final vanKm = last?['km'] != null && nextKm != null ? (toD(last!['km']) + toD(nextKm)) / 2 : (stops.firstOrNull?['km'] != null ? toD(stops.first['km']) : null);
        final map = toMap(secs);
        final mineId = secs.where((x) => x['code'] == mine?['section']).firstOrNull?['id'] as String?;
        final lastAt = (v['last'] as Map?)?['at'] as String?;
        final ago = lastAt == null ? null : DateTime.now().difference(DateTime.tryParse(lastAt) ?? DateTime.now()).inSeconds.clamp(0, 1 << 30);
        final mins = mine?['eta'] == null ? null : minutesLeft('${mine!['eta']}').clamp(0, 1 << 30);
        return Screen(
          top: Top(title: 'Track', sub: ago != null ? 'Live · updated ${ago < 60 ? '$ago s' : '${(ago / 60).round()} min'} ago' : 'Waiting for the van\'s place', back: ''),
          children: [
            // (23-11-2026, picture N3) the Google map: the mess, the stops with a place, the van where its driver's phone last said
            Builder(builder: (_) {
              Rec? sec(Object? code) => secs.where((y) => y['code'] == code && y['lat'] != null && y['lng'] != null).firstOrNull;
              final last = v['state'] == 'on_the_way' && v['last'] is Map && (v['last'] as Map)['lat'] != null ? v['last'] as Map : null;
              final stopMarks = [for (final y in stops) if (sec(y['section']) != null) Mark(toD(sec(y['section'])!['lat']), toD(sec(y['section'])!['lng']), y['mine'] == true ? 'mine' : y['reached_at'] != null ? 'done' : 'stop', label: '${y['section']}', title: 'Section ${y['section']}')];
              final marks = stopMarks.isEmpty && last == null ? <Mark>[] : [
                if (mess?.lat != null && mess?.lng != null) Mark(mess!.lat!, mess.lng!, 'mess', title: mess.name),
                ...stopMarks,
                if (last != null) Mark(toD(last['lat']), toD(last['lng']), 'van', title: '${v['vehicle'] ?? 'Van'}'),
              ];
              return ClipRRect(borderRadius: BorderRadius.circular(20), child: GMap(height: 300, label: 'Map: the van, the mess and the stops', marks: marks,
                  line: last == null ? const [] : [(toD(last['lat']), toD(last['lng'])), for (final y in stops) if (y['reached_at'] == null && sec(y['section']) != null) (toD(sec(y['section'])!['lat']), toD(sec(y['section'])!['lng']))],
                  fallback: RoadMap(sections: map.sections, circles: map.circles, mine: mineId, van: v['state'] == 'on_the_way' ? vanKm : null,
                      done: [for (final x in secs) if (stops.any((y) => y['section'] == x['code'] && y['reached_at'] != null)) '${x['id']}'], height: 300, label: 'The van on the road')));
            }),
            FCard(child: _col([
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Arriving in', style: T.sm),
                  Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                    Text(mins != null ? '$mins min' : '–', style: T.big), const SizedBox(width: 8), Text(mine?['eta'] != null ? '· ${time(mine!['eta'] as String?)}' : '', style: T.sm)]),
                ])),
                Text('stop ${mine?['seq'] ?? '–'} of ${stops.length}', style: T.xs),
              ]),
              Row(children: [for (final (i, x) in stops.indexed) ...[if (i > 0) const SizedBox(width: 6),
                Expanded(child: Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: x['reached_at'] != null ? C.leaf : x['mine'] == true ? C.saffron : const Color(0xFFE7E1D3))))]]),
              _row([Expanded(child: Text('${reached.length} of ${stops.length} stops done', style: T.xs)), Text('${r?.o['code'] ?? ''}', style: T.xs)]),
              FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/app/orders/$id/driver'), child: _row([
                Av(initials(v['driver'] as String?), tone: Tone.navy),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${v['driver'] ?? ''}', style: T.b), Text('${v['vehicle'] ?? ''} · stop ${mine?['seq'] ?? '–'} of ${stops.length} is yours', style: T.xs)])),
                const Tile('phone', tone: Tone.leaf, size: 40),
              ], gap: 12)),
            ])),
          ],
        );
      },
    );
  }
}

// ── e10 · Driver details ──
class DriverCard extends StatelessWidget {
  const DriverCard({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) => Load<Rec?>(
        watch: const ['batch_stops'],
        loading: const Screen(top: Top(title: 'Driver', back: ''), children: [Loading()]),
        load: () => loadVan(id),
        builder: (context, v, reload) {
          if (v == null) return const Screen(top: Top(title: 'Driver', back: ''), children: [Empty(icon: 'truck', title: 'Not on the way')]);
          final tel = v['driver_mobile'] as String?;
          final stops = _stops(v);
          return Screen(
            top: const Top(title: 'Driver', back: ''),
            children: [
              _row([Av(initials(v['driver'] as String?), size: 56, tone: Tone.navy), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v['driver'] ?? ''}', style: T.b.copyWith(fontSize: 19)), Text('Mess driver · batch ${v['code'] ?? ''}', style: T.sm)]))], gap: 14),
              _row([
                Expanded(child: Btn('Call', icon: 'phone', kind: BtnKind.leaf, onTap: tel == null ? null : () => launchUrl(Uri.parse('tel:$tel')))),
                Expanded(child: Btn('Message', icon: 'message-circle', kind: BtnKind.ghost, onTap: tel == null ? null : () => launchUrl(Uri.parse('https://wa.me/${tel.replaceAll(RegExp(r'\D'), '')}'), mode: LaunchMode.externalApplication))),
              ], gap: 10),
              FCard(padding: const EdgeInsets.all(12), color: C.cream, child: _row([const Tile('truck', tone: Tone.navy, size: 40), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${v['vehicle'] ?? ''}', style: T.b.copyWith(letterSpacing: .6)), Text('${v['vehicle_kind'] ?? ''}', style: T.xs)]))], gap: 12)),
              Text('This trip · ${stops.length} stops', style: T.lbl),
              FCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: [
                for (final (i, x) in stops.indexed)
                  Builder(builder: (_) {
                    final now = x['reached_at'] == null && stops.take(i).every((y) => y['reached_at'] != null);
                    return Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(border: i < stops.length - 1 ? const Border(bottom: BorderSide(color: C.line)) : null),
                        child: _row([
                          Dot(color: x['reached_at'] != null ? C.leaf : x['mine'] == true ? C.saffron : now ? C.blue : C.line2),
                          Expanded(child: Text('${x['seq']} · ${x['section']}${x['km'] != null ? ' Km ${x['km']}' : ''}${x['mine'] == true ? ' – you' : ''}',
                              style: x['mine'] == true ? T.b.copyWith(fontSize: 14) : T.body.copyWith(fontSize: 14, color: x['reached_at'] != null || now ? C.ink : C.muted))),
                          Text(x['reached_at'] != null ? 'Reached ${time(x['reached_at'] as String?)}' : now ? 'Next' : x['eta'] != null ? time(x['eta'] as String?) : '',
                              style: T.xs.copyWith(color: x['mine'] == true ? C.sfD : now ? C.blueD : C.muted, fontWeight: x['mine'] == true || now ? FontWeight.w700 : FontWeight.w400)),
                        ], gap: 10));
                  }),
              ])),
              const InfoLine('His place and number are shown only during this trip and stop when it ends.', icon: 'shield-check'),
            ],
          );
        },
      );
}

// ── e11 · Delivery confirmation (show the code) ──
class ShowCode extends StatelessWidget {
  const ShowCode({super.key, required this.id});
  final String id;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(OrderData?, Rec?)>(
      watch: const ['delivery_codes', 'order_lines'],
      loading: const Screen(top: Top(title: 'Your parcel', back: ''), children: [Loading()]),
      load: () async => (await loadOrder(id), await loadVan(id)),
      builder: (context, x, reload) {
        final (r, van) = x;
        if (r == null) return const Screen(top: Top(title: 'Your parcel', back: ''), children: [Denied()]);
        final mine = r.lines.where((l) => l['person_id'] == s.personId).toList();
        final used = r.code?['used_at'] != null;
        final digits = '${r.code?['code'] ?? '----'}'.split('');
        return Screen(
          top: Top(title: used ? 'Code taken' : 'Your parcel is here', sub: '${r.o['code']}', back: ''),
          children: [
            Hero2(child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Av(initials(van?['driver'] as String?), size: 34, tone: Tone.dark), const SizedBox(width: 8),
                Text('${van?['driver'] ?? 'The driver'} has your parcel', style: T.sm.copyWith(color: C.heroSub))]),
              const SizedBox(height: 18),
              Text(used ? 'He has typed your code – it is delivered' : 'Show this code to the driver', style: T.sm.copyWith(color: const Color(0xFFC9D2E0))),
              const SizedBox(height: 8),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final (i, dg) in digits.indexed) ...[if (i > 0) const SizedBox(width: 10),
                Container(width: 60, height: 72, alignment: Alignment.center, decoration: BoxDecoration(color: C.navy3, borderRadius: BorderRadius.circular(16)),
                    child: Text(dg, style: const TextStyle(fontFamily: font, fontSize: 36, fontWeight: FontWeight.w700, color: Color(0xFFF2C14E))))]]),
              const SizedBox(height: 14),
              Text('He types it in his app – that proves you got it.', style: T.xs.copyWith(color: C.heroSub)),
            ])),
            FCard(child: _col([
              Text('He is handing over', style: T.h2),
              for (final l in mine) _row([Tile(l['is_meal'] == true ? 'soup' : 'glass-water', tone: l['is_meal'] == true ? Tone.sf : Tone.blue, size: 40),
                Expanded(child: Text('${(l['items'] as Map?)?['name'] ?? ''}', style: T.body)), Text('× ${l['qty']}', style: T.b)], gap: 12),
            ])),
            Btn('I have it – check what I got', icon: 'package-check', kind: BtnKind.leaf, onTap: used ? () => context.push('/app/orders/$id/quantity') : null),
            Btn('Not with me – report', kind: BtnKind.ghost, onTap: () => context.push('/app/complaints/new?order=$id&cat=missing')),
          ],
        );
      },
    );
  }
}

// ── e12 · Quantity received ──
class Received extends StatefulWidget {
  const Received({super.key, required this.id});
  final String id;
  @override
  State<Received> createState() => _ReceivedState();
}

class _ReceivedState extends State<Received> with Act {
  final qty = <String, int>{};
  String food = 'hot', box = 'sealed';
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<OrderData?>(
      loading: const Screen(top: Top(title: 'What did you get?', back: ''), children: [Loading()]),
      load: () => loadOrder(widget.id),
      builder: (context, r, reload) {
        if (r == null) return const Screen(top: Top(title: 'What did you get?', back: ''), children: [Denied()]);
        final o = r.o;
        final mine = r.lines.where((l) => l['person_id'] == s.personId && ['served', 'delivered', 'short'].contains(l['state'])).toList();
        int handed(Rec l) => toI(l['delivered_qty'] ?? l['qty']);
        int got(Rec l) => qty['${l['id']}'] ?? handed(l);
        String nm(Rec l) => '${(l['items'] as Map?)?['name'] ?? ''}'.toLowerCase();
        final short = mine.where((l) => got(l) < handed(l)).toList();
        Future<void> confirm() => act(() async {
              for (final l in mine) {
                await call('report_received', {'p_line': l['id'], 'p_qty': got(l), 'p_food': o['kind'] == 'meal' ? null : food, 'p_box': o['kind'] == 'meal' ? null : box});
              }
              if (context.mounted) context.go('/app/orders/${o['id']}/review');
            });
        return Screen(
          top: Top(title: 'What did you get?', sub: '${o['code']}', back: ''),
          foot: foot([Btn('Confirm · ${mine.map((l) => '${got(l)} ${nm(l)}').join(', ')}', kind: BtnKind.sf, busy: busy, onTap: mine.isEmpty ? null : confirm)]),
          children: [
            if (mine.isEmpty) const Empty(icon: 'package', title: 'Nothing handed over yet')
            else FCard(child: _col([
              for (final (i, l) in mine.indexed) ...[
                if (i > 0) const Hr(),
                _row([Tile(l['is_meal'] == true ? 'soup' : 'glass-water', tone: l['is_meal'] == true ? Tone.sf : Tone.blue, size: 40),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${(l['items'] as Map?)?['name'] ?? ''}', style: T.b), Text('Handed over ${handed(l)}', style: T.xs)])),
                  Stepper2(value: got(l), max: handed(l), onChanged: (v) => setState(() => qty['${l['id']}'] = v))], gap: 12),
              ],
              if (short.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: C.redS, borderRadius: BorderRadius.circular(12)),
                  child: _row([const Ico('package-x', size: 18, color: Color(0xFF8B1A1A)), Expanded(child: Text('${short.map((l) => '${handed(l) - got(l)} ${nm(l)}').join(', ')} short – the mess is told at once', style: T.sm.copyWith(color: const Color(0xFF8B1A1A))))])),
            ], gap: 14)),
            if (o['kind'] != 'meal') ...[
              Field('The food was', Wrap2([for (final f in const ['hot', 'warm', 'cold']) Chip2(mealName(f), icon: f == 'hot' ? 'thermometer' : null, tone: food == f ? Tone.on : Tone.plain, onTap: () => setState(() => food = f))])),
              Field('The box was', Wrap2([for (final b in const ['sealed', 'open', 'leaking']) Chip2(mealName(b), tone: box == b ? Tone.on : Tone.plain, onTap: () => setState(() => box = b))])),
            ],
            const InfoLine('Only what you received is billed to the contractor.'),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── e13 · Review (optional – never stops anything) ──
class Review extends StatefulWidget {
  const Review({super.key, required this.id});
  final String id;
  @override
  State<Review> createState() => _ReviewState();
}

class _ReviewState extends State<Review> with Act {
  final stars = <String, int>{'overall': 4, 'taste': 4, 'quantity': 4, 'hot': 4, 'delivery': 4};
  final liked = <String>{};
  final comment = TextEditingController();
  static const _words = ['', 'Poor', 'Not good', 'OK', 'Good', 'Very good'];
  static const _tags = ['Tasty', 'On time', 'Clean box', 'Fresh chapati', 'Polite driver'];
  @override
  void dispose() { comment.dispose(); super.dispose(); }
  Widget starsOf(String k, {bool big = false}) => Row(mainAxisSize: MainAxisSize.min, children: [
        for (var n = 1; n <= 5; n++)
          InkWell(onTap: () => setState(() => stars[k] = n), child: Padding(padding: EdgeInsets.symmetric(horizontal: big ? 3 : 1),
              child: Ico('star', size: big ? 32 : 18, color: n <= (stars[k] ?? 0) ? C.gold : const Color(0xFFDCD5C5)))),
      ]);
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<OrderData?>(
      loading: const Screen(top: Top(title: 'Review', back: ''), children: [Loading()]),
      load: () => loadOrder(widget.id),
      builder: (context, r, reload) {
        final delivery = r?.o['kind'] == 'delivery';
        Future<void> send() => act(() async {
              await call('review_order', {'p_order': widget.id, 'p_overall': stars['overall'], 'p_taste': stars['taste'], 'p_quantity': stars['quantity'], 'p_hot': stars['hot'],
                'p_delivery': delivery ? stars['delivery'] : null, 'p_liked': liked.toList(), 'p_comment': comment.text.trim().isEmpty ? null : comment.text.trim()});
              if (context.mounted) context.go(homeOf(s));
            });
        return Screen(
          top: Top(title: 'How was ${r?.o['meal'] ?? 'it'}?', sub: '${r?.mess?['name'] ?? ''}', back: ''),
          children: [
            FCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), child: Column(children: [
              starsOf('overall', big: true), const SizedBox(height: 10), Text(_words[stars['overall']!], style: T.b.copyWith(fontSize: 18)), Text('Tap the stars', style: T.xs)])),
            FCard(child: _col([
              for (final (k, l) in [('taste', 'Taste'), ('quantity', 'Quantity'), ('hot', 'Hot when it came'), if (delivery) ('delivery', 'Delivery')])
                _row([Expanded(child: Text(l, style: T.body)), starsOf(k)]),
            ])),
            Field('What was good', Wrap2([for (final t in _tags) Chip2(t, tone: liked.contains(t) ? Tone.on : Tone.plain, onTap: () => setState(() => liked.contains(t) ? liked.remove(t) : liked.add(t)))])),
            Input(controller: comment, hint: 'Anything for the mess? (optional)', maxLength: 500, lines: 3),
            InkWell(onTap: () => context.push('/app/complaints/new?order=${widget.id}'), child: _row([const Ico('message-square-warning', size: 16, color: C.redD),
              Expanded(child: Text('Something wrong? Make a complaint', style: T.sm.copyWith(color: C.redD, fontWeight: FontWeight.w600))), const Ico('chevron-right', size: 16, color: C.redD)])),
            ErrorLine(error),
            Btn('Send review', kind: BtnKind.leaf, busy: busy, onTap: send),
            Btn('Skip', kind: BtnKind.ghost, onTap: () => context.go(homeOf(s))),
          ],
        );
      },
    );
  }
}

// ── e14 · Complaint – photo, voice ──
const _cats = [('quality', 'Food quality'), ('taste', 'Taste'), ('quantity', 'Quantity'), ('temperature', 'Temperature'), ('cleanliness', 'Cleanliness'),
  ('water', 'Water'), ('delay', 'Delay'), ('missing', 'Missing meal'), ('other', 'Other')];

class Complaint extends StatefulWidget {
  const Complaint({super.key, this.order, this.cat});
  final String? order, cat;
  @override
  State<Complaint> createState() => _ComplaintState();
}

class _ComplaintState extends State<Complaint> with Act {
  late String cat = widget.cat ?? 'quality';
  bool serious = false;
  final text = TextEditingController();
  final photos = <File>[];
  final rec = AudioRecorder();
  String? voicePath;
  bool recording = false;
  int secs = 0;
  Timer? _t;
  @override
  void dispose() { _t?.cancel(); text.dispose(); unawaited(rec.dispose()); super.dispose(); }

  Future<void> record() async {
    if (recording) {
      final p = await rec.stop();
      _t?.cancel();
      setState(() { recording = false; voicePath = p; });
      return;
    }
    if (!await rec.hasPermission()) { setState(() => error = 'The microphone is not allowed – write it instead.'); return; }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/falcon-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await rec.start(const RecordConfig(numChannels: 1, bitRate: 64000), path: path);
    secs = 0;
    _t = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() => secs++); });
    setState(() { recording = true; voicePath = null; });
  }

  Future<void> photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1600, imageQuality: 80);
    if (x != null && mounted) setState(() => photos.add(File(x.path)));
  }

  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(Rec?, Mess?)>(
      loading: const Screen(top: Top(title: 'Complaint', back: ''), children: [Loading()]),
      load: () async {
        final ord = widget.order == null ? null : await one(sb.from('orders').select('code,meal,service_date,mess_id').eq('id', widget.order!).limit(1));
        final d = await messDay(s);
        return (ord, d.mess);
      },
      builder: (context, x, reload) {
        final (ord, mess) = x;
        final hot = serious || cat == 'cleanliness';
        Future<void> send() => act(() async {
              final messId = ord?['mess_id'] as String? ?? mess?.id;
              if (messId == null) throw DbError('Choose the mess first.');
              if (text.text.trim().isEmpty && photos.isEmpty && voicePath == null) throw DbError('Say, write or show what is wrong.');
              final uid = sb.auth.currentUser!.id, base = '${s.me?['company_id']}/$uid/${DateTime.now().millisecondsSinceEpoch}';
              Future<String> up(File f, String name, String type) async {
                final p = '$base-$name';
                try { await sb.storage.from('complaint-media').upload(p, f, fileOptions: FileOptions(contentType: type)); } catch (_) { throw DbError('A photo could not be sent – try again.'); }
                return p;
              }
              final paths = <String>[for (final (i, f) in photos.indexed) await up(f, 'photo$i.jpg', 'image/jpeg')];
              final vp = voicePath == null ? null : await up(File(voicePath!), 'voice.m4a', 'audio/mp4');
              final r = await call<dynamic>('raise_complaint', {'p_mess': messId, 'p_category': cat, 'p_text': text.text.trim().isEmpty ? null : text.text.trim(), 'p_heard': null,
                'p_photos': paths, 'p_voice': vp, 'p_order': widget.order, 'p_people': 1, 'p_serious': serious});
              if (context.mounted) context.go('/app/complaints/${r['id']}');
            });
        return Screen(
          top: Top(title: 'Complaint', sub: ord != null ? 'About ${ord['code']} · ${ord['meal']}, ${day(ord['service_date'] as String?)}' : mess?.name ?? '', back: ''),
          foot: foot([Btn('Send complaint', icon: 'send', kind: BtnKind.red, busy: busy, onTap: send)]),
          children: [
            Wrap2([for (final (v, l) in _cats) Chip2(l, tone: cat == v ? Tone.on : Tone.plain, onTap: () => setState(() => cat = v))]),
            FCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), color: hot ? const Color(0xFFFFF8F6) : null, border: hot ? const Color(0xFFE8A49B) : null,
                onTap: () => setState(() => serious = !serious),
                child: _row([const Tile('siren', tone: Tone.redTile, size: 40), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Serious – health or a foreign object', style: T.b.copyWith(color: const Color(0xFF8B1A1A))), Text('Site Admin and the mess are alerted now', style: T.xs)])),
                  Switch(value: hot, activeTrackColor: C.red, onChanged: (v) => setState(() => serious = v))], gap: 12)),
            FCard(child: _col([
              _row([
                Material(color: recording ? C.red : C.leaf, borderRadius: BorderRadius.circular(13), child: InkWell(borderRadius: BorderRadius.circular(13), onTap: record,
                    child: SizedBox(width: 40, height: 40, child: Center(child: Ico(recording ? 'square' : 'mic', color: Colors.white))))),
                Expanded(child: Text(recording ? 'Listening… tap to stop' : voicePath != null ? 'Voice kept' : 'Tap and say it (Marathi, Hindi or English)', style: T.sm)),
                Text(recording || voicePath != null ? '0:${secs.toString().padLeft(2, '0')}' : '', style: T.xs),
              ], gap: 12),
              Input(controller: text, hint: 'Or write it', maxLength: 1000, lines: 3),
            ])),
            Row(children: [
              for (final f in photos) ...[ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.file(f, width: 96, height: 96, fit: BoxFit.cover)), const SizedBox(width: 10)],
              if (photos.length < 3) InkWell(onTap: photo, borderRadius: BorderRadius.circular(16), child: Container(width: 96, height: 96,
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line2, width: 1.5)), child: const Center(child: Ico('camera', size: 24, color: C.muted)))),
            ]),
            const InfoLine('A ticket opens; you confirm when it is solved.', icon: 'ticket'),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// A complaint's own page (the ticket): its state, the mess's reply, and "solved / not yet".
class ComplaintTicket extends StatefulWidget {
  const ComplaintTicket({super.key, required this.id});
  final String id;
  @override
  State<ComplaintTicket> createState() => _ComplaintTicketState();
}

class _ComplaintTicketState extends State<ComplaintTicket> with Act {
  @override
  Widget build(BuildContext context) => Load<Rec?>(
        watch: const ['complaints'],
        loading: const Screen(top: Top(title: 'Complaint', back: ''), children: [Loading()]),
        load: () => one(sb.from('complaints').select().eq('id', widget.id).limit(1)),
        builder: (context, x, reload) {
          if (x == null) return const Screen(top: Top(title: 'Complaint', back: ''), children: [Denied()]);
          final st = '${x['state']}', replied = x['owner_reply'] != null;
          return Screen(
            top: Top(title: '${x['code']}', sub: '${x['category']}${x['serious'] == true ? ' · serious' : ''}', back: ''),
            children: [
              FCard(padding: const EdgeInsets.fromLTRB(14, 16, 14, 2), child: Timeline([
                TlStep('Raised', state: 'done', sub: '${time(x['created_at'] as String?)} · ${x['text'] ?? x['heard_text'] ?? ''}'),
                TlStep('The mess\'s reply', state: replied ? 'done' : 'now', sub: replied ? '${x['owner_reply']}${x['owner_action'] != null ? ' · ${x['owner_action']}' : ''}' : 'due ${time(x['due_at'] as String?)}'),
                TlStep(st == 'closed' ? 'Closed${x['found_true'] != null ? ' · ${x['found_true'] == true ? 'found true' : 'not found true'}' : ''}' : 'You say if it is solved',
                    state: st == 'closed' ? 'done' : st == 'answered' ? 'now' : 'next', sub: 'then the supervisor closes it'),
              ])),
              if (st == 'answered') _row([
                Expanded(child: Btn('Solved', kind: BtnKind.leaf, busy: busy, onTap: () => act(() async { await call('complaint_solved', {'p_id': x['id'], 'p_solved': true}); reload(); }))),
                Expanded(child: Btn('Not yet', kind: BtnKind.ghost, busy: busy, onTap: () => act(() async { await call('complaint_solved', {'p_id': x['id'], 'p_solved': false}); reload(); }))),
              ], gap: 10),
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── e15 · Guest request (a guest without the app) ──
class GuestRequest extends StatefulWidget {
  const GuestRequest({super.key});
  @override
  State<GuestRequest> createState() => _GuestRequestState();
}

class _GuestRequestState extends State<GuestRequest> with Act {
  int step = 1;
  final name = TextEditingController(), mobile = TextEditingController(), org = TextEditingController(), desig = TextEditingController(), purpose = TextEditingController();
  String kind = 'Visitor';
  String? token, meal;
  Rec? visit;
  @override
  void dispose() { for (final c in [name, mobile, org, desig, purpose]) { c.dispose(); } super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (!['verified', 'linked', 'id_assigned'].contains(s.state)) {
      return const Screen(top: Top(title: 'Food as a guest', back: ''), children: [Denied(text: 'A checked employee brings a guest.')]);
    }
    return Load<MessDay>(
      loading: const Screen(top: Top(title: 'Food as a guest', back: ''), children: [Loading()]),
      load: () => messDay(s),
      builder: (context, d, reload) {
        final m = meal ?? currentMeal(d.wins);
        Future<void> sendCode() => act(() async { final r = await api('/api/guest-pass', {'mobile': mobile.text}); setState(() => token = r['token'] as String?); });
        Future<void> check(String c) => act(() async {
              final r = await api('/api/guest-pass', {'token': token, 'code': c, 'name': name.text.trim(), 'organisation': org.text.trim().isEmpty ? kind : org.text.trim(),
                'designation': desig.text.trim(), 'purpose': purpose.text.trim(), 'site': d.mess?.siteId});
              setState(() { visit = r; step = 2; });
            });
        Future<void> order(String k) => act(() async {
              final r = await call<dynamic>('order_for_guest', {'p_visit': visit!['visit'], 'p_mess': d.mess!.id, 'p_date': today(), 'p_meal': m, 'p_kind': k});
              if (context.mounted) context.go('/app/orders/${r['order_id']}');
            });
        return Screen(
          top: Top(title: 'Food as a guest', sub: '${d.mess?.name ?? ''} · no employee code needed', back: ''),
          children: [
            _row([Expanded(child: Chip2('1 · Who the guest is', tone: step == 1 ? Tone.on : Tone.plain)), Expanded(child: Chip2('2 · Meal and place', tone: step == 2 ? Tone.on : Tone.plain))]),
            if (step == 1) ...[
              Field('Full name', Input(controller: name, hint: 'Guest\'s name', caps: TextCapitalization.words)),
              Field('Mobile number', Input(controller: mobile, hint: '10 digits', keyboard: TextInputType.phone, maxLength: 14, icon: 'phone')),
              if (token != null) Field('The code the guest got on WhatsApp', CodeBoxes(onDone: check))
              else Btn('Send the guest a code', icon: 'message-circle', kind: BtnKind.ghost, busy: busy, onTap: sendCode),
              Field('The guest is', Wrap2([for (final k in const ['Company guest', 'Client', 'Govt officer', 'Visitor', 'Subcontractor', 'Vendor']) Chip2(k, tone: kind == k ? Tone.on : Tone.plain, onTap: () => setState(() => kind = k))], gap: 6)),
              _row([Expanded(child: Field('Company', Input(controller: org, hint: 'optional'))), Expanded(child: Field('Designation', Input(controller: desig, hint: 'optional')))], gap: 10),
              Field('Purpose of visit', Input(controller: purpose, hint: 'e.g. shuttering work at B2')),
              const InfoLine('One guest profile for every visit – his own ticket and bill line.', icon: 'shield-check'),
            ] else ...[
              FCard(child: _row([Av(initials(visit?['name'] as String?), tone: Tone.plum), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${visit?['name'] ?? ''}', style: T.b), Text('Guest · your visit', style: T.xs)])), const Chip2('Code OK', icon: 'check', tone: Tone.leaf, height: 26)], gap: 12)),
              Wrap2([for (final x in meals) Chip2(mealName(x), tone: x == m ? Tone.on : Tone.plain, onTap: () => setState(() => meal = x))], gap: 6),
              Btn('${mealName(m)} at the mess', icon: 'utensils', kind: BtnKind.leaf, busy: busy, onTap: () => order('meal')),
              Btn('${mealName(m)} parcel', icon: 'package', kind: BtnKind.ghost, busy: busy, onTap: () => order('parcel')),
            ],
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── e16 · Group request ──
class Group extends StatefulWidget {
  const Group({super.key});
  @override
  State<Group> createState() => _GroupState();
}

class _GroupState extends State<Group> with Act {
  String kind = 'delivery';
  String? sec, meal;
  final sel = <String, bool>{};
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (s.me?['may_group'] != true) {
      return const Screen(top: Top(title: 'Meals for my team', back: ''), children: [Denied(text: 'Asking for others needs the Site Admin\'s permission.')]);
    }
    sec ??= s.me?['home_section_id'] as String?;
    return Load<(MessDay, List<Rec>)>(
      loading: const Screen(top: Top(title: 'Meals for my team', back: ''), children: [Loading()]),
      load: () async { final d = await messDay(s); return (d, await sections(d.mess?.siteId)); },
      builder: (context, x, reload) {
        final (d, secs) = x;
        final m = meal ?? currentMeal(d.wins);
        final secRow = secs.where((r) => r['id'] == sec).firstOrNull;
        return Load<List<Rec>>(
          key: ValueKey('$sec-$m'),
          load: () async {
            if (sec == null) return <Rec>[];
            final r = await call<dynamic>('team_for_group', {'p_section': sec, 'p_date': today(), 'p_meal': m});
            return [for (final x in (r as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
          },
          builder: (context, team, reloadTeam) {
            final can = team.where((p) => p['has_meal'] != true && p['state'] != 'temporary').toList();
            final chosen = can.where((p) => sel['${p['person_id']}'] ?? true).toList();
            final temps = team.where((p) => p['state'] == 'temporary').toList();
            Future<void> ask() => act(() async {
                  final lines = [for (final p in chosen) {'person': p['person_id'] == s.personId ? '' : p['person_id'], 'item': m}];
                  final r = await call<dynamic>('request_order', {'p_mess': d.mess!.id, 'p_date': today(), 'p_meal': m, 'p_kind': kind, 'p_lines': lines, 'p_section': kind == 'delivery' ? sec : null});
                  final id = r['order_id'] ?? (r['existing'] as List).first['order_id'];
                  if (context.mounted) context.go('/app/orders/$id');
                });
            return Screen(
              top: Top(title: '${mealName(m)} for my team', sub: '${s.name} · allowed by Site Admin', back: ''),
              foot: foot([Btn('Ask for ${chosen.length} ${kind == 'delivery' ? 'parcels' : 'at the mess'}', icon: 'users', kind: BtnKind.sf, busy: busy, onTap: chosen.isEmpty || d.mess == null ? null : ask)]),
              children: [
                Wrap2([
                  Chip2('Parcel to ${secRow?['code'] ?? 'section'}', tone: kind == 'delivery' ? Tone.on : Tone.plain, onTap: () => setState(() => kind = 'delivery')),
                  Chip2('At the mess', tone: kind == 'meal' ? Tone.on : Tone.plain, onTap: () => setState(() => kind = 'meal')),
                  Chip2('Section ${secRow?['code'] ?? '–'}', icon: 'chevron-down', onTap: () async {
                    final v = await sheet<String>(context, (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('The section', style: T.h2),
                      for (final x in secs) ListTile(contentPadding: EdgeInsets.zero, title: Text('${x['code']}${x['km'] != null ? ' · Km ${x['km']}' : ''}', style: T.body), onTap: () => Navigator.pop(ctx, '${x['id']}')),
                    ]));
                    if (v != null) setState(() => sec = v);
                  }),
                ]),
                Wrap2([for (final x in meals) Chip2(mealName(x), tone: x == m ? Tone.on : Tone.plain, onTap: () => setState(() => meal = x))], gap: 6),
                _row([Expanded(child: Text('My team · ${secRow?['code'] ?? ''}', style: T.b)), InkWell(onTap: () => setState(sel.clear), child: Text('All', style: T.sm.copyWith(color: C.leafD, fontWeight: FontWeight.w600)))]),
                if (team.isEmpty) const Empty(icon: 'users', title: 'Nobody at this section')
                else FCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: [
                  for (final (i, p) in team.indexed)
                    Builder(builder: (_) {
                      final off = p['has_meal'] == true || p['state'] == 'temporary', on = !off && (sel['${p['person_id']}'] ?? true);
                      return InkWell(onTap: off ? null : () => setState(() => sel['${p['person_id']}'] = !on), child: Opacity(opacity: off ? .5 : 1, child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(border: i < team.length - 1 ? const Border(bottom: BorderSide(color: C.line)) : null),
                        child: _row([
                          Container(width: 24, height: 24, decoration: BoxDecoration(color: on ? C.leaf : Colors.transparent, borderRadius: BorderRadius.circular(7), border: on ? null : Border.all(color: C.line2, width: 1.5)),
                              child: on ? const Center(child: Ico('check', size: 14, color: Colors.white)) : null),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${p['full_name']}', style: T.b.copyWith(fontSize: 14)),
                            Text('${p['work_role'] ?? 'Employee'}${p['has_meal'] == true ? ' · has it already (${p['existing_order']})' : p['state'] == 'temporary' ? ' · temporary' : ''}', style: T.xs),
                          ])),
                        ], gap: 12),
                      )));
                    }),
                ])),
                if (temps.isNotEmpty) Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: C.amberS, borderRadius: BorderRadius.circular(14)),
                    child: _row([const Ico('info', size: 16, color: C.amber), Expanded(child: Text('${temps.map((t) => firstName(t['full_name'] as String?)).join(', ')} ${temps.length > 1 ? 'are' : 'is'} temporary – the meal is at the mess, asked by himself.', style: T.sm.copyWith(color: C.amber)))])),
                const InfoLine('Each meal is in that person\'s own record. You confirm for those without a phone.', icon: 'users'),
                ErrorLine(error),
              ],
            );
          },
        );
      },
    );
  }
}

// "Me": who he is, his notifications, sign out.
class Me extends StatefulWidget {
  const Me({super.key});
  @override
  State<Me> createState() => _MeState();
}

class _MeState extends State<Me> {
  bool _marked = false;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<List<Rec>>(
      watch: const ['notifications'],
      loading: Screen(top: const Top(title: 'Me'), tabs: tabsFor(s, '/app/me'), children: const [Loading()]),
      load: () => rows(sb.from('notifications').select().order('created_at', ascending: false).limit(30)),
      builder: (context, notes, reload) {
        if (!_marked && notes.any((n) => n['read_at'] == null)) {
          _marked = true;
          unawaited(call('mark_read', {'p_id': null}).catchError((_) => null));
        }
        return Screen(
          top: Top(left: Av(initials(s.name)), title: s.name, sub: [s.me?['rcl_id'], s.homeSite?.code, s.state].where((x) => x != null && '$x'.isNotEmpty).join(' · ')),
          tabs: tabsFor(s, '/app/me'),
          children: [
            Text('Notifications', style: T.h2),
            if (notes.isEmpty) const Empty(icon: 'bell', title: 'Nothing new'),
            for (final n in notes)
              FCard(padding: const EdgeInsets.all(12), onTap: n['link'] is String && '${n['link']}'.startsWith('/') ? () => context.push('${n['link']}') : null,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: Dot(color: n['read_at'] != null ? C.line2 : C.saffron)), const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${n['title']}', style: T.b.copyWith(fontSize: 14)), if (n['body'] != null) Text('${n['body']}', style: T.xs)])),
                    Text(time(n['created_at'] as String?), style: T.xs),
                  ])),
            // (23-11-2026) the version on this phone and "Check for update" (core/update.dart)
            FutureBuilder<(String, int)>(
              future: appVersion(),
              builder: (context, v) => FCard(padding: const EdgeInsets.all(12), child: Row(children: [
                const Tile('refresh-cw', tone: Tone.leaf, size: 40), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('FALCON ${v.data?.$1 ?? ''}', style: T.b), Text(v.data == null ? ' ' : 'Build ${v.data!.$2}', style: T.xs)])),
                Btn('Check for update', kind: BtnKind.ghost, small: true, onTap: () => checkNow(context)),
              ])),
            ),
            Btn('Sign out', icon: 'log-out', kind: BtnKind.ghost, onTap: () => s.signOut()),
          ],
        );
      },
    );
  }
}
