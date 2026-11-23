// The mess owner's app – boards o01–o16 (an operator sees the kitchen's part); everything through the database's checked functions
// – the app's own screens on the same data and actions as the web's src/screens/owner.tsx.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide Session;
import 'package:url_launcher/url_launcher.dart';

import '../core/db.dart';
import '../core/fmt.dart';
import '../core/meals.dart';
import '../core/session.dart';
import '../ui/kit.dart';
import '../ui/look.dart';
import '../ui/road_map.dart';
import '../ui/gmap.dart';
import 'employee.dart' show foot;

const ownerTabs = [
  TabItem('/owner', 'house', 'Today'), TabItem('/owner/requests', 'receipt', 'Orders'), TabItem('/owner/kitchen', 'chef-hat', 'Kitchen'),
  TabItem('/owner/live', 'truck', 'Deliveries'), TabItem('/owner/billing', 'wallet', 'Billing'),
];
PillTabs _tabs(String current) => PillTabs(tabs: ownerTabs, current: current);

List<Rec> _list(Object? v) => [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];
List<Rec> linesOf(Rec o) => _list(o['lines']);
Rec? secOf(Rec o) => o['section'] is Map ? Map<String, dynamic>.from(o['section'] as Map) : null;

/// The mess of this owner / operator (his grant names it).
class OwnerMess {
  OwnerMess(this.mess, this.owner);
  final Rec? mess;
  final bool owner;
  String get id => '${mess?['id']}';
  String get name => '${mess?['name'] ?? ''}';
  String get contractor => '${(mess?['contractors'] as Map?)?['name'] ?? mess?['name'] ?? ''}';
  double? get lat => mess?['lat'] == null ? null : toD(mess!['lat']);
  double? get lng => mess?['lng'] == null ? null : toD(mess!['lng']);
}

Future<OwnerMess> ownerMess(Session s) async {
  final g = s.grants.where((x) => (x.role == 'mess_owner' || x.role == 'mess_operator') && x.messId != null).firstOrNull;
  if (g == null) return OwnerMess(null, false);
  return OwnerMess(await one(sb.from('messes').select('id,name,site_id,contractor_id,lat,lng,contractors(name)').eq('id', g.messId!).limit(1)), g.role == 'mess_owner');
}

Future<List<Rec>> kitchen(String messId, [String? date]) async => _list(await call<dynamic>('kitchen_orders', {'p_mess': messId, 'p_date': date ?? today()}));

String curMeal(List<Win> w) => currentMeal(w);

String itemsText(Rec o) {
  final m = <String, int>{};
  for (final l in linesOf(o).where((l) => l['state'] != 'cancelled')) { m['${l['item']}'] = (m['${l['item']}'] ?? 0) + toI(l['qty']); }
  return m.entries.map((e) => '${e.key} ${e.value}').join(' · ');
}

bool _changeOpen(Rec o) => o['change_until'] != null && (DateTime.tryParse('${o['change_until']}')?.isAfter(DateTime.now()) ?? false);

const _noMess = Screen(top: Top(title: 'My mess'), children: [Denied(text: 'You are not the owner or operator of a mess. The Site Admin gives this role.')]);

Widget _row(List<Widget> c, {double gap = 8}) => Row(children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(width: gap), c[i]]]);
Widget _col(List<Widget> c, {double gap = 10}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [for (var i = 0; i < c.length; i++) ...[if (i > 0) SizedBox(height: gap), c[i]]]);
Widget _box(String label, String value, String sub, {VoidCallback? onTap, bool hot = false}) => FCard(padding: const EdgeInsets.all(12), onTap: onTap,
    color: hot ? const Color(0xFFFFFBF5) : null, border: hot ? const Color(0xFFE8B98A) : null,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: T.xs.copyWith(color: hot ? C.sfD : C.muted, fontWeight: hot ? FontWeight.w600 : FontWeight.w400)),
      Text(value, style: T.b.copyWith(fontSize: 26)), Text(sub, style: T.xs)]));
Widget _tick(bool on, {double size = 26}) => Container(width: size, height: size, decoration: BoxDecoration(color: on ? C.leaf : Colors.transparent, borderRadius: BorderRadius.circular(8),
    border: on ? null : Border.all(color: C.line2, width: 1.5)), child: on ? const Center(child: Ico('check', size: 16, color: Colors.white)) : null);

/// Loads the owner's mess first, then the screen's own data.
class _WithMess<D> extends StatelessWidget {
  const _WithMess({super.key, required this.load, required this.builder, this.watch = const [], this.title = 'My mess'});
  final Future<D> Function(OwnerMess m) load;
  final Widget Function(BuildContext context, OwnerMess m, D data, VoidCallback reload) builder;
  final List<String> watch;
  final String title;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(OwnerMess, D?)>(
      watch: watch,
      loading: Screen(top: Top(title: title), children: const [Loading()]),
      load: () async {
        final m = await ownerMess(s);
        return (m, m.mess == null ? null : await load(m));
      },
      builder: (context, x, reload) => x.$1.mess == null ? _noMess : builder(context, x.$1, x.$2 as D, reload),
    );
  }
}

// ── o01 · Owner dashboard ──
class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key});
  @override
  Widget build(BuildContext context) => _WithMess<(List<Win>, List<Rec>, Rec?, List<Rec>, Rec?, int)>(
        watch: const ['orders', 'order_lines', 'complaints', 'batches'],
        load: (m) async => (
          await windows(m.id, today()),
          await kitchen(m.id),
          await one(sb.from('complaints').select('id,code,category,due_at,people_count').eq('mess_id', m.id).eq('serious', true).neq('state', 'closed').order('due_at').limit(1)),
          await rows(sb.from('menus').select('meal,published_at').eq('mess_id', m.id).eq('service_date', today())),
          await one(sb.from('day_closings').select('state').eq('mess_id', m.id).eq('service_date', today(-1)).limit(1)),
          (await rows(sb.from('batches').select('id').eq('mess_id', m.id).eq('state', 'on_the_way'))).length,
        ),
        builder: (context, m, x, reload) {
          final (wins, k, serious, menu, yday, vans) = x;
          final meal = curMeal(wins), w = wins.where((y) => y.meal == meal).firstOrNull;
          final os = k.where((o) => o['meal'] == meal && !['cancelled', 'refused'].contains(o['state'])).toList();
          int meals(Rec o) => linesOf(o).where((l) => l['is_meal'] == true && l['state'] != 'cancelled').length;
          int count(bool Function(Rec o) f) => os.where(f).fold(0, (n, o) => n + meals(o));
          final tiles = <(String, int, String, String)>[
            ('New', count((o) => o['state'] == 'requested'), 'waiting', '/owner/requests'),
            ('Preparing', count((o) => ['accepted', 'preparing'].contains(o['state'])), 'meals', '/owner/kitchen'),
            ('Ready', count((o) => o['state'] == 'ready'), 'to send', '/owner/kitchen'),
            ('On the road', vans, 'vans', '/owner/live'),
            ('Served', os.where((o) => o['kind'] == 'meal').fold(0, (n, o) => n + linesOf(o).where((l) => l['is_meal'] == true && l['state'] == 'served').length), 'at the mess', '/owner/kitchen?tab=counter'),
            ('Delivered', os.fold(0, (n, o) => n + linesOf(o).where((l) => l['is_meal'] == true && ['delivered', 'short'].contains(l['state']) && l['confirmed'] != null).length), 'confirmed', '/owner/follow-up'),
          ];
          final newN = tiles.first.$2;
          return Screen(
            top: Top(left: Av(initials(m.contractor), tone: Tone.sf), title: m.contractor, sub: '${m.name} · ${dayLong(today())}',
                right: IconBox(icon: 'bell', label: '$newN new requests', badge: newN > 0, onTap: () => context.go('/owner/requests'))),
            tabs: _tabs('/owner'),
            children: [
              Hero2(child: _col([
                _row([Chip2('${mealName(meal)}${w != null ? ' · ${w.serveFrom} – ${w.serveTo}' : ''}', tone: Tone.sf, height: 26), const Spacer(), Text('now ${nowHM()}', style: T.xs.copyWith(color: C.heroSub))]),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${os.fold(0, (n, o) => n + meals(o))}', style: T.big.copyWith(fontSize: 44, color: Colors.white)), Text('$meal requests', style: T.xs.copyWith(color: C.heroSub))]),
                  const SizedBox(width: 18),
                  Expanded(child: Column(children: [
                    _row([Expanded(child: Text('At the mess', style: T.xs.copyWith(color: C.heroSub))), Text('${count((o) => o['kind'] == 'meal')}', style: T.b.copyWith(color: Colors.white))]),
                    _row([Expanded(child: Text('Parcels', style: T.xs.copyWith(color: C.heroSub))), Text('${count((o) => o['kind'] != 'meal')}', style: T.b.copyWith(color: Colors.white))]),
                  ])),
                ]),
              ], gap: 14)),
              GridView.count(crossAxisCount: 3, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: .95, children: [
                for (final (i, (l, n, sub, to)) in tiles.indexed) _box(l, '$n', sub, hot: i == 0 && n > 0, onTap: () => context.push(to)),
              ]),
              if (serious != null)
                FCard(padding: const EdgeInsets.all(12), color: const Color(0xFFFFF8F6), border: const Color(0xFFE8A49B), onTap: () => context.push('/owner/complaints'), child: _row([
                  const Tile('siren', tone: Tone.redTile, size: 40),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Serious complaint – ${serious['category']}', style: T.b.copyWith(fontSize: 14, color: const Color(0xFF8B1A1A))),
                    Text('${serious['code']} · ${serious['people_count']} people · ${leftText('${serious['due_at']}')}', style: T.xs)])),
                  const Ico('chevron-right', size: 18)], gap: 12)),
              _row([
                Expanded(child: FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/owner/menu'), child: _row([Ico(menu.isNotEmpty ? 'circle-check' : 'circle-dot', color: menu.isNotEmpty ? C.leaf : C.muted),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(menu.isNotEmpty ? 'Menu out' : 'Publish the menu', style: T.b.copyWith(fontSize: 14)), Text(menu.isNotEmpty ? '${menu.length} meals today' : 'not out yet', style: T.xs)]))], gap: 10))),
                Expanded(child: FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/owner/closing'), child: _row([const Ico('clipboard-check'),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Day closing', style: T.b.copyWith(fontSize: 14)), Text('yesterday ${yday?['state'] ?? 'not sent'}', style: T.xs)]))], gap: 10))),
              ], gap: 10),
              _row([
                Expanded(child: FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/owner/guests'), child: _row([const Ico('users'), Text('Guest meals', style: T.b.copyWith(fontSize: 14))], gap: 10))),
                Expanded(child: FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/owner/follow-up'), child: _row([const Ico('phone'), Text('Follow-up', style: T.b.copyWith(fontSize: 14))], gap: 10))),
              ], gap: 10),
            ],
          );
        },
      );
}

// ── o02 · New requests ──
class Requests extends StatefulWidget {
  const Requests({super.key});
  @override
  State<Requests> createState() => _RequestsState();
}

class _RequestsState extends State<Requests> with Act {
  String by = 'circle';
  @override
  Widget build(BuildContext context) => _WithMess<(List<Win>, List<Rec>)>(
        watch: const ['orders', 'order_lines'],
        load: (m) async => (await windows(m.id, today()), await kitchen(m.id)),
        builder: (context, m, x, reload) {
          final (wins, k) = x;
          final meal = curMeal(wins), w = wins.where((y) => y.meal == meal).firstOrNull;
          final waiting = k.where((o) => o['state'] == 'requested').toList();
          final ready = waiting.where((o) => !_changeOpen(o)).toList();
          String key(Rec o) {
            final sec = secOf(o);
            return switch (by) {
              'circle' => sec != null ? 'Circle ${sec['circle']}' : o['kind'] == 'meal' ? 'At the mess' : 'Collect at the mess',
              'section' => '${sec?['code'] ?? 'At the mess'}',
              'person' => '${o['requester']}',
              _ => '${o['code']}',
            };
          }
          final groups = waiting.map(key).toSet().toList();
          Future<void> acceptAll() => act(() async { for (final o in ready) { await call('kitchen_decide', {'p_order': o['id'], 'p_accept': true}); } reload(); });
          return Screen(
            top: Top(title: 'New requests · ${waiting.length}', sub: '${mealName(meal)}${w != null ? ' · they can still change for up to ${w.changeMinutes} min' : ''}', back: '/owner'),
            tabs: _tabs('/owner/requests'),
            foot: foot([_row([
              Expanded(child: Btn('Open one', kind: BtnKind.ghost, onTap: waiting.isEmpty ? null : () => context.push('/owner/requests/${waiting.first['id']}'))),
              Expanded(flex: 2, child: Btn('Accept ${ready.length} ready', icon: 'lock', kind: BtnKind.leaf, busy: busy, onTap: ready.isEmpty ? null : acceptAll)),
            ], gap: 10), const SizedBox(height: 76)]),
            children: [
              Seg(items: const [('circle', 'Circle'), ('section', 'Section'), ('person', 'Person'), ('order', 'Order')], value: by, onChanged: (v) => setState(() => by = v)),
              if (waiting.isEmpty) const Empty(icon: 'receipt', title: 'No new requests', text: 'New ones come here as they are asked.'),
              for (final g in groups) ...[
                Builder(builder: (_) {
                  final list = waiting.where((o) => key(o) == g).toList();
                  return _row([Expanded(child: Text(g, style: T.b)), Text('${list.length} requests · ${list.fold(0, (n, o) => n + linesOf(o).where((l) => l['is_meal'] == true).length)} meals', style: T.xs)]);
                }),
                for (final o in waiting.where((o) => key(o) == g))
                  Builder(builder: (_) {
                    final extras = linesOf(o).where((l) => l['is_meal'] != true && l['state'] == 'open').toList(), open = _changeOpen(o), sec = secOf(o), guest = o['guest'] == true;
                    return FCard(padding: const EdgeInsets.all(12), border: guest ? const Color(0xFFC9D7F2) : null, child: _col([
                      InkWell(onTap: () => context.push('/owner/requests/${o['id']}'), child: _row([
                        Av(initials('${o['requester']}'), tone: guest ? Tone.plum : Tone.leaf),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Wrap2([Text('${o['requester']}', style: T.b), if (guest) const Tag('Guest'), if (o['is_group'] == true) Tag('Group · ${linesOf(o).where((l) => l['is_meal'] == true).length}')], gap: 6),
                          Text('${o['requester_role'] ?? ''}${sec != null ? ' · ${sec['code']}${sec['km'] != null ? ' Km ${sec['km']}' : ''}' : ''}', style: T.xs),
                        ])),
                        Chip2(open ? leftText('${o['change_until']}') : 'Ready', icon: open ? 'timer' : null, tone: open ? Tone.amber : Tone.plain, height: 26),
                      ], gap: 12)),
                      _row([Ico(o['kind'] == 'meal' ? 'utensils' : 'package', size: 16, color: C.muted), Expanded(child: Text('${mealName(o['meal'] as String?)} ${o['kind'] == 'meal' ? 'at the mess' : 'parcel'} · ${itemsText(o)}', style: T.sm)), Tag('${o['code']}')]),
                      for (final e in extras) _row([Expanded(child: Text('Extra: ${e['item']} ${e['qty']}', style: T.xs.copyWith(color: C.sfD, fontWeight: FontWeight.w700))),
                        Btn('No extra', kind: BtnKind.ghost, small: true, onTap: () => act(() async { await call('kitchen_extra', {'p_line': e['id'], 'p_ok': false}); reload(); }))]),
                    ]));
                  }),
              ],
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── o03 · Request – accept and lock ──
class RequestDetail extends StatefulWidget {
  const RequestDetail({super.key, required this.id});
  final String id;
  @override
  State<RequestDetail> createState() => _RequestDetailState();
}

class _RequestDetailState extends State<RequestDetail> with Act {
  final reason = TextEditingController();
  @override
  void dispose() { reason.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _WithMess<List<Rec>>(
        watch: const ['orders', 'order_lines'],
        title: 'Request',
        load: (m) => kitchen(m.id),
        builder: (context, m, k, reload) {
          final o = k.where((y) => y['id'] == widget.id).firstOrNull;
          if (o == null) return const Screen(top: Top(title: 'Request', back: '/owner/requests'), children: [Empty(icon: 'receipt', title: 'Not found', text: 'It may be for another day.')]);
          final open = _changeOpen(o), sec = secOf(o);
          Future<void> decide(bool ok) => act(() async {
                await call('kitchen_decide', {'p_order': o['id'], 'p_accept': ok, 'p_reason': ok ? null : reason.text.trim()});
                if (context.mounted) context.go(ok ? '/owner/kitchen' : '/owner/requests');
              });
          return Screen(
            top: Top(title: '${o['code']}', sub: 'Asked ${time(o['created_at'] as String?)} · ${o['meal']} ${o['kind'] == 'meal' ? 'at the mess' : 'parcel'}', back: '/owner/requests'),
            foot: o['state'] != 'requested' ? null : foot([
              _row([const Tile('lock', tone: Tone.navy, size: 56), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Accept and lock?', style: T.b.copyWith(fontSize: 19)), Text(open ? 'His change window ends ${time(o['change_until'] as String?)}' : 'His change window is over.', style: T.sm)]))], gap: 12),
              const InfoLine('Nobody can change it after this – only a change request, with who and why kept.', icon: 'lock'),
              _row([
                Expanded(child: Btn('Refuse…', kind: BtnKind.ghost, onTap: () => sheet<void>(context, (ctx) => _col([
                      Text('Why refuse?', style: T.h2),
                      Input(controller: reason, hint: 'e.g. lunch over, item not available', autofocus: true),
                      Btn('Refuse with this reason', kind: BtnKind.red, onTap: () { if (reason.text.trim().length >= 3) { Navigator.pop(ctx); decide(false); } }),
                    ])))),
                Expanded(flex: 2, child: Btn('Accept and lock', icon: 'lock', kind: BtnKind.leaf, busy: busy, onTap: () => decide(true))),
              ], gap: 10),
            ]),
            children: [
              FCard(child: _row([Av(initials('${o['requester']}'), size: 56), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${o['requester']}', style: T.b.copyWith(fontSize: 17)), Text('${o['requester_role'] ?? (o['guest'] == true ? 'Guest' : 'Employee')}', style: T.sm)]))], gap: 12)),
              FCard(child: _col([
                _row([const Ico('circle-check', size: 16, color: C.leaf), Expanded(child: Text('One meal a person – checked by FALCON when it was asked', style: T.sm))]),
                if (o['guest'] == true) _row([const Ico('circle-check', size: 16, color: C.leaf), Expanded(child: Text('Guest – the host\'s OK is given', style: T.sm))]),
              ])),
              FCard(child: _col([
                for (final l in linesOf(o)) _row([Expanded(child: Text('${l['item']}${o['is_group'] == true ? ' · ${l['person']}' : ''}',
                    style: T.body.copyWith(decoration: l['state'] == 'cancelled' ? TextDecoration.lineThrough : null, color: l['state'] == 'cancelled' ? C.muted : C.ink))), Text('${l['qty']}', style: T.b)]),
                const Hr(),
                _row([const Ico('map-pin', size: 16, color: C.muted), Expanded(child: Text(sec != null ? '${sec['code']}${sec['place'] != null ? ' ${sec['place']}' : ''} · with the van' : o['kind'] == 'parcel' ? 'Collected at the mess' : 'At the mess', style: T.sm))]),
                if (o['note'] != null) _row([const Ico('message-circle', size: 16, color: C.muted), Expanded(child: Text('${o['note']}', style: T.sm))]),
              ])),
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── o04 · Kitchen: preparing · ready · the counter ──
class Kitchen extends StatefulWidget {
  const Kitchen({super.key, this.tab});
  final String? tab;
  @override
  State<Kitchen> createState() => _KitchenState();
}

class _KitchenState extends State<Kitchen> with Act {
  late String tab = widget.tab ?? 'preparing';
  final sel = <String, bool>{};
  @override
  Widget build(BuildContext context) => _WithMess<List<Rec>>(
        watch: const ['orders', 'order_lines'],
        title: 'Kitchen',
        load: (m) => kitchen(m.id),
        builder: (context, m, all, reload) {
          final prep = all.where((o) => ['accepted', 'preparing'].contains(o['state']) && o['kind'] != 'meal').toList();
          final ready = all.where((o) => o['state'] == 'ready' && o['kind'] != 'meal').toList();
          final counter = all.where((o) => o['kind'] == 'meal' && ['accepted', 'preparing', 'ready', 'delivered'].contains(o['state'])).toList();
          final tot = <String, int>{};
          for (final o in prep) { for (final l in linesOf(o).where((l) => l['state'] != 'cancelled')) { tot['${l['item']}'] = (tot['${l['item']}'] ?? 0) + toI(l['qty']); } }
          final bySec = <String, (int, int, Object?)>{};
          for (final o in [...prep, ...ready]) {
            final kk = '${secOf(o)?['code'] ?? 'Collect'}';
            final v = bySec[kk] ?? (0, 0, secOf(o)?['km']);
            bySec[kk] = (v.$1 + (o['state'] == 'ready' ? 1 : 0), v.$2 + 1, v.$3);
          }
          final chosen = prep.where((o) => sel['${o['id']}'] == true).toList();
          Future<void> markReady() => act(() async { for (final o in chosen) { await call('kitchen_step', {'p_order': o['id'], 'p_state': 'ready'}); } setState(sel.clear); reload(); });
          return Screen(
            top: Top(left: const Tile('chef-hat', tone: Tone.navy, size: 40), title: 'Kitchen', sub: m.name),
            tabs: _tabs('/owner/kitchen'),
            foot: tab == 'preparing' ? foot([Btn('Mark ${chosen.length} packed as ready', icon: 'package-check', kind: BtnKind.leaf, busy: busy, onTap: chosen.isEmpty ? null : markReady), const SizedBox(height: 76)])
                : tab == 'ready' ? foot([Btn('Make a delivery batch', icon: 'layers', kind: BtnKind.navy, onTap: () => context.push('/owner/parcels')), const SizedBox(height: 76)]) : null,
            children: [
              Seg(items: [('preparing', 'Preparing · ${prep.length}'), ('ready', 'Ready · ${ready.length}'), ('counter', 'Counter · ${counter.length}')], value: tab, onChanged: (v) => setState(() => tab = v)),
              if (tab == 'preparing') ...[
                Hero2(child: _col([
                  _row([Expanded(child: Text('To pack', style: T.b.copyWith(color: Colors.white))), Text('${prep.length} parcels', style: T.xs.copyWith(color: C.heroSub))]),
                  Row(children: [for (final (i, e) in tot.entries.take(4).indexed) ...[if (i > 0) const SizedBox(width: 8),
                    Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4), decoration: BoxDecoration(color: C.navy2, borderRadius: BorderRadius.circular(12)),
                        child: Column(children: [Text('${e.value}', style: T.b.copyWith(fontSize: 20, color: Colors.white)), Text(e.key, style: T.xs.copyWith(color: C.heroSub), maxLines: 1, overflow: TextOverflow.ellipsis)])))]]),
                ], gap: 12)),
                if (bySec.isNotEmpty) FCard(child: _col([
                  for (final e in bySec.entries) _col([
                    _row([Expanded(child: Text('${e.key}${e.value.$3 != null ? ' · Km ${e.value.$3}' : ''}', style: T.b)),
                      Chip2('${e.value.$1} / ${e.value.$2} ready', tone: e.value.$1 == e.value.$2 ? Tone.leaf : e.value.$1 > 0 ? Tone.amber : Tone.plain, height: 26)]),
                    Bar(e.value.$1 / e.value.$2, color: e.value.$1 == e.value.$2 ? C.leaf : C.sf),
                  ], gap: 6),
                ], gap: 12)),
                if (prep.isEmpty) const Empty(icon: 'chef-hat', title: 'Nothing to prepare'),
                for (final o in prep)
                  FCard(padding: const EdgeInsets.all(12), onTap: () => setState(() => sel['${o['id']}'] = !(sel['${o['id']}'] ?? false)), child: _row([
                    _tick(sel['${o['id']}'] == true),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${o['code']} · ${o['requester']}', style: T.b.copyWith(fontSize: 14)), Text('${secOf(o)?['code'] ?? 'collect'} · ${itemsText(o)}', style: T.xs)])),
                    Text(time(o['accepted_at'] as String?), style: T.xs),
                  ], gap: 12)),
              ],
              if (tab == 'ready') ...[
                if (ready.isEmpty) const Empty(icon: 'package-check', title: 'Nothing ready'),
                for (final o in ready)
                  FCard(padding: const EdgeInsets.all(12), child: _row([_tick(true),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${o['code']} · ${o['requester']}', style: T.b.copyWith(fontSize: 14)),
                      Text('${secOf(o)?['code'] ?? 'collect at the mess'} · ${itemsText(o)}${o['batch'] != null ? ' · ${o['batch']}' : ''}', style: T.xs)])),
                    Text(time(o['ready_at'] as String?), style: T.xs)], gap: 12)),
              ],
              if (tab == 'counter') ...[
                if (counter.isEmpty) const Empty(icon: 'utensils', title: 'Nobody at the counter'),
                for (final o in counter)
                  for (final l in linesOf(o).where((l) => l['state'] != 'cancelled'))
                    FCard(padding: const EdgeInsets.all(12), child: _row([
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${l['person']} · ${l['item']}${toI(l['qty']) > 1 ? ' × ${l['qty']}' : ''}', style: T.b.copyWith(fontSize: 14)), Text('${o['code']}', style: T.xs)])),
                      if (l['state'] == 'open') Btn('Served', kind: BtnKind.leaf, small: true, busy: busy, onTap: () => act(() async { await call('serve_line', {'p_line': l['id']}); reload(); }))
                      else Chip2(l['confirmed'] != null ? 'confirmed' : 'served', tone: Tone.leaf, height: 26),
                    ], gap: 12)),
              ],
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── o05 · o06 · Ready parcels by section → a delivery batch ──
class Parcels extends StatefulWidget {
  const Parcels({super.key});
  @override
  State<Parcels> createState() => _ParcelsState();
}

class _ParcelsState extends State<Parcels> with Act {
  final left = <String, bool>{};
  static const _bg = [C.leafS, C.blueS, C.sfS, C.plumS], _dot = [C.leaf, C.blue, C.saffron, C.plumD];
  @override
  Widget build(BuildContext context) => _WithMess<List<Rec>>(
        watch: const ['orders', 'order_lines'],
        title: 'Parcels for the van',
        load: (m) => kitchen(m.id),
        builder: (context, m, k, reload) {
          final ready = k.where((o) => o['kind'] == 'delivery' && ['accepted', 'preparing', 'ready'].contains(o['state']) && o['batch'] == null).toList();
          final circles = ready.map((o) => '${secOf(o)?['circle'] ?? '–'}').toSet().toList()..sort();
          final take = ready.where((o) => left['${secOf(o)?['id'] ?? ''}'] != true).toList();
          final stops = take.map((o) => secOf(o)?['code']).toSet();
          final meal = take.firstOrNull?['meal'];
          Future<void> make() => act(() async {
                final same = take.where((o) => o['meal'] == meal).toList();
                final id = await call<dynamic>('make_batch', {'p_mess': m.id, 'p_date': today(), 'p_meal': meal, 'p_orders': [for (final o in same) o['id']]});
                if (context.mounted) context.go('/owner/batches/$id/driver');
              });
          return Screen(
            top: Top(title: 'Parcels for the van · ${ready.length}', sub: 'Grouped by circle and section', back: '/owner/kitchen'),
            foot: foot([
              _row([Expanded(child: Text('${stops.length} stops', style: T.sm)), Text('${take.length} parcels', style: T.b)]),
              Btn('Make a delivery batch', icon: 'layers', kind: BtnKind.navy, busy: busy, onTap: take.isEmpty ? null : make),
            ]),
            children: [
              if (ready.isEmpty) const Empty(icon: 'package', title: 'No parcels waiting for a van'),
              for (final (ci, c) in circles.indexed)
                Builder(builder: (_) {
                  final inC = ready.where((o) => '${secOf(o)?['circle'] ?? '–'}' == c).toList();
                  final secs = <String, Rec>{for (final o in inC) if (secOf(o) != null) '${secOf(o)!['id']}': secOf(o)!}.values.toList()
                    ..sort((a, b) => toD(a['km']).compareTo(toD(b['km'])));
                  return FCard(padding: EdgeInsets.zero, child: Column(children: [
                    Container(color: _bg[ci % 4], padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), child: _row([
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: _dot[ci % 4], borderRadius: BorderRadius.circular(7)), child: const Center(child: Ico('check', size: 14, color: Colors.white))),
                      Expanded(child: Text('Circle $c', style: T.b)), Text('${inC.length}', style: T.b)], gap: 10)),
                    for (final (i, sec) in secs.indexed)
                      InkWell(onTap: () => setState(() => left['${sec['id']}'] = !(left['${sec['id']}'] ?? false)), child: Opacity(opacity: left['${sec['id']}'] == true ? .45 : 1, child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(border: i < secs.length - 1 ? const Border(bottom: BorderSide(color: C.line)) : null),
                        child: _row([Expanded(child: Text('${sec['code']}${sec['km'] != null ? ' · Km ${sec['km']}' : ''}${sec['place'] != null ? ' · ${sec['place']}' : ''}${left['${sec['id']}'] == true ? ' · next van' : ''}', style: T.sm)),
                          Text('${ready.where((o) => secOf(o)?['id'] == sec['id']).length}', style: T.b)]),
                      ))),
                  ]));
                }),
              const InfoLine('Tap a section to leave it for the next van.'),
              ErrorLine(error),
            ],
          );
        },
      );
}

/// A batch with its stops, orders, driver and vehicle (the web's useBatch).
Future<Rec?> loadBatch(String id) async {
  final b = await one(sb.from('batches').select().eq('id', id).limit(1));
  if (b == null) return null;
  final stops = await rows(sb.from('batch_stops').select('id,seq,section_id,eta,reached_at,sections(code,km,place,lat,lng)').eq('batch_id', id).order('seq'));
  final orders = await rows(sb.from('batch_orders').select('order_id,orders(to_section_id,code)').eq('batch_id', id).isFilter('removed_at', null));
  Rec? driver;
  if (b['driver_id'] != null) {
    try { final d = await call<dynamic>('batch_driver', {'p_batch': id}); driver = _list(d).firstOrNull; } catch (_) {}
  }
  final vehicle = b['vehicle_id'] != null ? await one(sb.from('vehicles').select('reg_no,kind').eq('id', '${b['vehicle_id']}').limit(1)) : null;
  return {'b': b, 'stops': stops, 'orders': orders, 'driver': driver, 'vehicle': vehicle};
}

// ── o07 · Driver and vehicle ──
class BatchDriver extends StatefulWidget {
  const BatchDriver({super.key, required this.id});
  final String id;
  @override
  State<BatchDriver> createState() => _BatchDriverState();
}

class _BatchDriverState extends State<BatchDriver> with Act {
  String? d, v;
  @override
  Widget build(BuildContext context) => _WithMess<(Rec?, List<Rec>, List<Rec>)>(
        watch: const ['batches', 'batch_stops'],
        title: 'Driver and vehicle',
        load: (m) async => (await loadBatch(widget.id), _list(await call<dynamic>('site_drivers', {'p_mess': m.id})),
            await rows(sb.from('vehicles').select('id,reg_no,kind,capacity').eq('active', true).order('reg_no'))),
        builder: (context, m, x, reload) {
          final (bt, drivers, vehicles) = x;
          final b = bt?['b'] as Rec?;
          final dd = d ?? b?['driver_id'] as String?, vv = v ?? b?['vehicle_id'] as String?;
          Future<void> go() => act(() async {
                await call('assign_batch', {'p_batch': widget.id, 'p_driver': dd, 'p_vehicle': vv});
                if (context.mounted) context.push('/owner/batches/${widget.id}/route');
              });
          return Screen(
            top: Top(title: 'Driver and vehicle', sub: b != null ? 'Batch ${b['code']} · ${(bt!['orders'] as List).length} parcels · ${(bt['stops'] as List).length} stops' : '', back: '/owner/parcels'),
            foot: foot([Btn('See the route', icon: 'arrow-right', kind: BtnKind.navy, busy: busy, onTap: dd == null || vv == null ? null : go)]),
            children: [
              if (b?['refused_reason'] != null) Failed('The driver said no: ${b!['refused_reason']}'),
              Text('Driver · on duty today', style: T.lbl),
              if (drivers.isEmpty) const Empty(icon: 'user', title: 'No driver at this site', text: 'The System Admin gives the driver role.'),
              for (final x in drivers)
                FCard(padding: const EdgeInsets.all(12), border: dd == x['person_id'] ? C.leaf : null, onTap: () => setState(() => d = '${x['person_id']}'), child: _row([
                  Av(initials('${x['full_name']}'), tone: Tone.navy),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['full_name']}', style: T.b), Text(x['busy'] != null ? 'On ${x['busy']}' : 'Free', style: T.xs)])),
                  if (dd == x['person_id']) const Ico('circle-check', color: C.leaf)], gap: 12)),
              Text('Vehicle', style: T.lbl),
              for (final x in vehicles)
                FCard(padding: const EdgeInsets.all(12), border: vv == x['id'] ? C.leaf : null, onTap: () => setState(() => v = '${x['id']}'), child: _row([
                  Tile('truck', tone: vv == x['id'] ? Tone.navy : Tone.cream, size: 40),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['reg_no']}', style: T.b.copyWith(letterSpacing: .5)), Text('${x['kind']}${x['capacity'] != null ? ' · ${x['capacity']} boxes' : ''}', style: T.xs)])),
                  if (vv == x['id']) const Ico('circle-check', color: C.leaf)], gap: 12)),
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── o08 · Route (by chainage; times suggested from the dated settings "van speed" and "minutes a stop") ──
class BatchRoute extends StatefulWidget {
  const BatchRoute({super.key, required this.id});
  final String id;
  @override
  State<BatchRoute> createState() => _BatchRouteState();
}

class _BatchRouteState extends State<BatchRoute> with Act {
  List<String>? order;
  @override
  Widget build(BuildContext context) => Load<(Rec?, Map<String, Object?>)>(
        watch: const ['batches', 'batch_stops'],
        loading: const Screen(top: Top(title: 'Route', back: ''), children: [Loading()]),
        load: () async {
          final d = today();
          final set = await rows(sb.from('settings').select('key,value').isFilter('site_id', null).inFilter('key', ['delivery.speed_kmh', 'delivery.stop_minutes'])
              .lte('valid_from', d).or('valid_to.is.null,valid_to.gte.$d'));
          return (await loadBatch(widget.id), {for (final r in set) '${r['key']}': r['value']});
        },
        builder: (context, x, reload) {
          final (bt, set) = x;
          final stops = _list(bt?['stops']), orders = _list(bt?['orders']);
          final seq = order ?? [for (final s in stops) '${s['section_id']}'];
          final list = [for (final sid in seq) ...stops.where((s) => s['section_id'] == sid)];
          double num(String k, double def) { final v = double.tryParse('${set[k] ?? ''}'); return set[k] != null && v != null ? v : def; }
          final speed = num('delivery.speed_kmh', 30).clamp(5, 1000).toDouble(), stopMin = num('delivery.stop_minutes', 4).clamp(0, 1000).toDouble();
          var km = 0.0, prev = 0.0;
          final start = DateTime.now();
          final plan = <(Rec, DateTime)>[];
          for (final (i, s) in list.indexed) {
            final k2 = (s['sections'] as Map?)?['km'] != null ? toD((s['sections'] as Map)['km']) : prev;
            km += (k2 - prev).abs(); prev = k2;
            plan.add((s, start.add(Duration(seconds: (((km / speed) * 60 + i * stopMin) * 60).round()))));
          }
          final mins = ((km / speed) * 60 + list.length * stopMin).round();
          void move(int i, int dd) { final x = [...seq]; final j = i + dd; if (j < 0 || j >= x.length) return; final t = x[i]; x[i] = x[j]; x[j] = t; setState(() => order = x); }
          Future<void> save() => act(() async {
                await call('set_route', {'p_batch': widget.id, 'p_stops': [for (final p in plan) {'section': p.$1['section_id'], 'eta': p.$2.toUtc().toIso8601String()}], 'p_km': (km * 10).round() / 10, 'p_minutes': mins});
                if (context.mounted) context.push('/owner/batches/${widget.id}/dispatch');
              });
          return Screen(
            top: const Top(title: 'Route', sub: 'In order of the road', back: ''),
            foot: foot([_row([
              Expanded(child: Btn('Reset', icon: 'refresh-cw', kind: BtnKind.ghost, onTap: () => setState(() => order = null))),
              Expanded(flex: 2, child: Btn('Next: dispatch', kind: BtnKind.navy, busy: busy, onTap: list.isEmpty ? null : save)),
            ], gap: 10)]),
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(20), child: Builder(builder: (_) {
                // (23-11-2026) the Google map when the sections have their places; the drawn road otherwise
                final marks = [for (final (i, p) in list.indexed) if ((p['sections'] as Map?)?['lat'] != null && (p['sections'] as Map?)?['lng'] != null)
                  Mark(toD((p['sections'] as Map)['lat']), toD((p['sections'] as Map)['lng']), 'stop', label: '${i + 1}', title: '${(p['sections'] as Map)['code']}')];
                return GMap(height: 220, label: 'Map: the stops of the batch', marks: marks, line: [for (final m in marks) (m.lat, m.lng)], fallback: RoadMap(sections: [for (final p in list) MapSection('${p['section_id']}', '${(p['sections'] as Map?)?['code']}', (p['sections'] as Map?)?['km'] == null ? null : toD((p['sections'] as Map)['km']))],
                  height: 220, label: 'The stops of the batch on the road'));
              })),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$mins min', style: T.big.copyWith(fontSize: 28)),
                Text('${(km * 10).round() / 10} km by chainage · estimated at ${speed.round()} km/h, ${stopMin.round()} min a stop', style: T.xs)]),
              FCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: Column(children: [
                for (final (i, (s, eta)) in plan.indexed)
                  Container(padding: const EdgeInsets.symmetric(vertical: 7), decoration: BoxDecoration(border: i < plan.length - 1 ? const Border(bottom: BorderSide(color: C.line)) : null), child: _row([
                    Av('${i + 1}', size: 26, tone: Tone.navy),
                    Expanded(child: Text('${(s['sections'] as Map?)?['code']}${(s['sections'] as Map?)?['km'] != null ? ' · Km ${(s['sections'] as Map)['km']}' : ''} · ${orders.where((o) => (o['orders'] as Map?)?['to_section_id'] == s['section_id']).length} parcels', style: T.body.copyWith(fontSize: 14))),
                    Text(time(eta.toUtc().toIso8601String()), style: T.xs.copyWith(fontWeight: FontWeight.w700)),
                    Chip2('', icon: 'chevron-down', height: 26, onTap: () => move(i, -1)),
                  ], gap: 8)),
              ])),
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── o09 · Dispatch ──
class BatchDispatch extends StatefulWidget {
  const BatchDispatch({super.key, required this.id});
  final String id;
  @override
  State<BatchDispatch> createState() => _BatchDispatchState();
}

class _BatchDispatchState extends State<BatchDispatch> with Act {
  double slide = 0;
  @override
  Widget build(BuildContext context) => Load<Rec?>(
        watch: const ['batches', 'batch_stops'],
        loading: const Screen(top: Top(title: 'Dispatch', back: ''), children: [Loading()]),
        load: () => loadBatch(widget.id),
        builder: (context, bt, reload) {
          final b = bt?['b'] as Rec?;
          if (b == null) return const Screen(top: Top(title: 'Dispatch', back: ''), children: [Denied()]);
          final accepted = ['accepted', 'loaded'].contains(b['state']);
          final stops = _list(bt!['stops']), last = stops.lastOrNull;
          final driver = bt['driver'] as Rec?, vehicle = bt['vehicle'] as Rec?;
          Future<void> go() => act(() async { await call('dispatch_batch', {'p_batch': b['id']}); if (context.mounted) context.go('/owner/live'); });
          Widget check(bool ok, String text, [String? right]) => _row([Ico(ok ? 'circle-check' : 'clock', size: 18, color: ok ? C.leaf : C.muted), Expanded(child: Text(text, style: T.sm)), if (right != null) Text(right, style: T.xs)]);
          return Screen(
            top: Top(title: 'Dispatch ${b['code']}', sub: nowHM(), back: ''),
            children: [
              Hero2(child: _col([
                _row([Av(initials(driver?['full_name'] as String?), tone: Tone.dark), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${driver?['full_name'] ?? 'No driver'}', style: T.b.copyWith(fontSize: 16, color: Colors.white)),
                  Text(vehicle != null ? '${vehicle['reg_no']} · ${vehicle['kind']}' : 'No vehicle', style: T.xs.copyWith(color: C.heroSub))]))], gap: 12),
                Row(children: [for (final (i, (v, l)) in [('${(bt['orders'] as List).length}', 'parcels'), ('${b['planned_km'] ?? '–'}', 'km'), (last?['eta'] != null ? time(last!['eta'] as String?) : '–', 'last stop')].indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: C.navy2, borderRadius: BorderRadius.circular(12)),
                      child: Column(children: [Text(v, style: T.b.copyWith(fontSize: 20, color: Colors.white)), Text(l, style: T.xs.copyWith(color: C.heroSub))])))]]),
              ], gap: 14)),
              FCard(child: _col([
                Text('Before it leaves', style: T.h2),
                check(accepted, 'The driver accepts on his phone', accepted ? 'accepted' : 'waiting'),
                check(b['state'] == 'loaded', 'The driver checked the vehicle', b['state'] == 'loaded' ? 'done' : 'waiting'),
                check(b['planned_minutes'] != null, 'Route and times set'),
              ], gap: 12)),
              const InfoLine('The people of these orders are told the van is coming.', icon: 'bell'),
              ErrorLine(error),
              _SlideToGo(enabled: accepted && !busy, label: accepted ? 'Slide to dispatch' : 'Waiting for the driver', onDone: go),
            ],
          );
        },
      );
}

class _SlideToGo extends StatefulWidget {
  const _SlideToGo({required this.enabled, required this.label, required this.onDone});
  final bool enabled;
  final String label;
  final VoidCallback onDone;
  @override
  State<_SlideToGo> createState() => _SlideToGoState();
}

class _SlideToGoState extends State<_SlideToGo> {
  double x = 0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final max = c.maxWidth - 62;
        return Container(
          height: 62,
          decoration: BoxDecoration(color: widget.enabled ? C.navy : const Color(0xFF8C9AB3), borderRadius: BorderRadius.circular(31)),
          child: Stack(alignment: Alignment.center, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [Text(widget.label, style: T.b.copyWith(color: Colors.white)), const Ico('chevron-right', size: 18, color: Colors.white)]),
            Positioned(left: 6 + x, top: 6, child: GestureDetector(
              onHorizontalDragUpdate: widget.enabled ? (d) => setState(() => x = (x + d.delta.dx).clamp(0, max)) : null,
              onHorizontalDragEnd: widget.enabled ? (_) { if (x > max * .9) { widget.onDone(); } setState(() => x = 0); } : null,
              child: Container(width: 50, height: 50, decoration: const BoxDecoration(color: C.gold, shape: BoxShape.circle), child: const Center(child: Ico('truck', size: 22, color: Color(0xFF1D1404)))),
            )),
          ]),
        );
      });
}

// ── o10 · Live deliveries ──
class Live extends StatelessWidget {
  const Live({super.key});
  @override
  Widget build(BuildContext context) => _WithMess<(List<Rec>, List<Rec>, List<Rec>)>(
        watch: const ['batches', 'batch_stops', 'order_lines', 'track_points'],
        title: 'Live',
        load: (m) async {
          final b = await rows(sb.from('batches').select('*,batch_stops(seq,reached_at,sections(code,lat,lng))').eq('mess_id', m.id).eq('service_date', today()).neq('state', 'cancelled').order('code'));
          // (23-11-2026, picture N5) each van on the road where its driver's phone last said
          final road = [for (final x in b) if (x['state'] == 'on_the_way') '${x['id']}'];
          final pts = road.isEmpty ? <Rec>[] : await rows(sb.from('track_points').select('batch_id,lat,lng,at').inFilter('batch_id', road).order('at', ascending: false).limit(200));
          return (b, await kitchen(m.id), pts);
        },
        builder: (context, m, x, reload) {
          final (batches, k, pts) = x;
          final onRoad = batches.where((b) => b['state'] == 'on_the_way').length;
          final short = [for (final o in k) for (final l in linesOf(o).where((l) => l['state'] == 'short')) (o, l)];
          return Screen(
            top: Top(title: 'Live · today', sub: '$onRoad vans on the road', right: Chip2('New batch', onTap: () => context.push('/owner/parcels'))),
            tabs: _tabs('/owner/live'),
            children: [
              Builder(builder: (_) {
                final marks = <Mark>[];
                for (final b in batches.where((b) => b['state'] == 'on_the_way')) {
                  for (final y in _list(b['batch_stops'])) {
                    final sc = y['sections'];
                    if (y['reached_at'] == null && sc is Map && sc['lat'] != null && sc['lng'] != null) marks.add(Mark(toD(sc['lat']), toD(sc['lng']), 'stop', label: '${sc['code']}', title: '${b['code']} · ${sc['code']}'));
                  }
                  final last = pts.where((p) => p['batch_id'] == b['id']).firstOrNull;
                  if (last != null) marks.add(Mark(toD(last['lat']), toD(last['lng']), 'van', label: '${b['code']}', title: '${b['code']}'));
                }
                if (marks.isEmpty || !mapsOn) return const SizedBox.shrink();
                if (m.lat != null && m.lng != null) marks.insert(0, Mark(m.lat!, m.lng!, 'mess', title: m.name));
                return ClipRRect(borderRadius: BorderRadius.circular(20), child: GMap(height: 260, label: 'Map: the vans on the road', marks: marks, fallback: const SizedBox.shrink()));
              }),
              if (batches.isEmpty) const Empty(icon: 'truck', title: 'No batches today'),
              for (final b in batches)
                Builder(builder: (_) {
                  final st = _list(b['batch_stops'])..sort((a, c) => toI(a['seq']).compareTo(toI(c['seq'])));
                  final done = st.where((y) => y['reached_at'] != null).length, state = '${b['state']}', road = state == 'on_the_way';
                  final to = state == 'draft' ? '/owner/batches/${b['id']}/driver' : ['assigned', 'accepted', 'loaded'].contains(state) ? '/owner/batches/${b['id']}/dispatch' : null;
                  return FCard(padding: const EdgeInsets.all(12), border: road ? const Color(0xFFE8B98A) : null, onTap: to == null ? null : () => context.push(to), child: _col([
                    _row([Tile(road ? 'truck' : 'layers', tone: road ? const Tone(C.saffron, Colors.white) : Tone.cream, size: 40),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${b['code']} · ${mealName(b['meal'] as String?)}', style: T.b),
                        Text('${state.replaceAll('_', ' ')}${road ? ' · stop $done of ${st.length}' : ''}${b['dispatched_at'] != null ? ' · left ${time(b['dispatched_at'] as String?)}' : ''}', style: T.xs)]))], gap: 12),
                    if (st.isNotEmpty) Row(children: [for (final (i, y) in st.indexed) ...[if (i > 0) const SizedBox(width: 4),
                      Expanded(child: Container(height: 6, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: y['reached_at'] != null ? C.leaf : const Color(0xFFE7E1D3))))]]),
                  ]));
                }),
              for (final (o, l) in short)
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: BoxDecoration(color: C.redS, borderRadius: BorderRadius.circular(14)), child: _row([
                  const Ico('package-x', size: 16, color: Color(0xFF8B1A1A)),
                  Expanded(child: Text('${secOf(o)?['code'] ?? ''} · ${o['code']}: ${l['person']} got ${l['short_qty']} ${'${l['item']}'.toLowerCase()} less', style: T.sm.copyWith(color: const Color(0xFF8B1A1A))))])),
            ],
          );
        },
      );
}

// ── o11 · Publish the menu ──
class MenuPublish extends StatefulWidget {
  const MenuPublish({super.key});
  @override
  State<MenuPublish> createState() => _MenuPublishState();
}

class _MenuPublishState extends State<MenuPublish> with Act {
  String d = today(1), meal = 'lunch';
  List<String>? dishes;
  final add = TextEditingController(), note = TextEditingController();
  @override
  void dispose() { add.dispose(); note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return _WithMess<(List<Win>, Rec?)>(
      key: ValueKey('$d-$meal'),
      title: 'Menu',
      load: (m) async => (await windows(m.id, d), await one(sb.from('menus').select('dishes,note,published_at').eq('mess_id', m.id).eq('service_date', d).eq('meal', meal).limit(1))),
      builder: (context, m, x, reload) {
        final (wins, cur) = x;
        final list = dishes ?? [for (final y in (cur?['dishes'] as List? ?? const [])) '$y'];
        final w = wins.where((y) => y.meal == meal).firstOrNull;
        Future<void> copy() => act(() async {
              final p = await one(sb.from('menus').select('dishes').eq('mess_id', m.id).eq('meal', meal).lt('service_date', d).order('service_date', ascending: false).limit(1));
              if (p == null) throw DbError('No earlier $meal menu to copy.');
              setState(() => dishes = [for (final y in (p['dishes'] as List? ?? const [])) '$y']);
            });
        Future<void> publish() => act(() async {
              if (list.isEmpty) throw DbError('Add at least one dish.');
              await sb.from('menus').upsert({'mess_id': m.id, 'service_date': d, 'meal': meal, 'dishes': list, 'note': note.text.trim().isNotEmpty ? note.text.trim() : cur?['note'],
                'published_by': s.personId, 'published_at': DateTime.now().toUtc().toIso8601String()}, onConflict: 'mess_id,service_date,meal');
              setState(() => dishes = null);
              reload();
            });
        return Screen(
          top: Top(title: d == today(1) ? 'Tomorrow\'s menu' : d == today() ? 'Today\'s menu' : 'Menu', sub: '${dayLong(d)} · ${m.name}', back: '/owner'),
          foot: foot([Btn('Publish $meal menu', kind: BtnKind.leaf, busy: busy, onTap: list.isEmpty ? null : publish)]),
          children: [
            Wrap2([for (final i in const [0, 1, 2]) Chip2(i == 0 ? 'Today' : i == 1 ? 'Tomorrow' : day(today(i)), tone: today(i) == d ? Tone.on : Tone.plain, onTap: () => setState(() { d = today(i); dishes = null; }))]),
            Seg(items: [for (final y in meals) (y, mealName(y))], value: meal, onChanged: (v) => setState(() { meal = v; dishes = null; })),
            FCard(child: _col([
              _row([Expanded(child: Text('${mealName(meal)}${w != null ? ' · ${w.serveFrom} – ${w.serveTo}' : ''}', style: T.h2)), Chip2('Copy the last one', onTap: copy)]),
              for (final (i, y) in list.indexed) _row([Expanded(child: Text(y, style: T.body)), Chip2('', icon: 'x', height: 26, onTap: () => setState(() => dishes = [...list]..removeAt(i)))]),
              _row([Expanded(child: Input(controller: add, hint: 'Add a dish')), Btn('Add', kind: BtnKind.ghost, small: true, onTap: () {
                if (add.text.trim().isNotEmpty) setState(() { dishes = [...list, add.text.trim()]; add.clear(); });
              })]),
            ])),
            Field('Note', Input(controller: note, hint: '${cur?['note'] ?? 'e.g. sweet on Friday'}', maxLength: 300)),
            if (cur != null) InfoLine('Published ${time(cur['published_at'] as String?)} – publishing again shows it as changed; the audit log keeps the old one.', icon: 'history'),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── o12 · Guest meals ──
class GuestMeals extends StatelessWidget {
  const GuestMeals({super.key});
  @override
  Widget build(BuildContext context) => _WithMess<(List<Rec>, int)>(
        watch: const ['orders'],
        title: 'Guest meals',
        load: (m) async => (await kitchen(m.id), (await rows(sb.from('orders').select('id').eq('mess_id', m.id).not('guest_visit_id', 'is', null).gte('service_date', '${today().substring(0, 8)}01').eq('state', 'delivered'))).length),
        builder: (context, m, x, reload) {
          final (k, month) = x;
          final g = k.where((o) => o['guest'] == true).toList();
          return Screen(
            top: const Top(title: 'Guest meals', sub: 'Today · their own ticket and bill line', back: '/owner'),
            children: [
              _row([Expanded(child: _box('Today', '${g.length}', 'guest orders')), Expanded(child: _box('This month', '$month', 'served'))], gap: 10),
              if (g.isEmpty) const Empty(icon: 'users', title: 'No guest orders today'),
              for (final o in g)
                FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/owner/requests/${o['id']}'), child: _col([
                  _row([Av(initials('${linesOf(o).firstOrNull?['person'] ?? ''}'), tone: Tone.plum), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${linesOf(o).firstOrNull?['person'] ?? ''}', style: T.b), Text('asked by ${o['requester']}', style: T.xs)])), Tag('${o['code']}')], gap: 12),
                  _row([Ico(o['kind'] == 'meal' ? 'utensils' : 'package', size: 16, color: C.muted),
                    Expanded(child: Text('${mealName(o['meal'] as String?)} ${o['kind'] == 'meal' ? 'at the mess' : 'parcel'}${secOf(o) != null ? ' · ${secOf(o)!['code']}' : ''}', style: T.sm)),
                    Chip2('${o['state']}', tone: o['state'] == 'delivered' ? Tone.leaf : Tone.amber, height: 24)]),
                ])),
            ],
          );
        },
      );
}

// ── o13 · Daily closing ──
class Closing extends StatefulWidget {
  const Closing({super.key});
  @override
  State<Closing> createState() => _ClosingState();
}

class _ClosingState extends State<Closing> with Act {
  String d = today();
  final remarks = TextEditingController();
  @override
  void dispose() { remarks.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _WithMess<(Rec, Rec?)>(
        key: ValueKey(d),
        watch: const ['orders', 'order_lines', 'day_closings'],
        title: 'Close the day',
        load: (m) async {
          final c = await call<dynamic>('day_counts', {'p_mess': m.id, 'p_date': d});
          return (c is Map ? Map<String, dynamic>.from(c) : <String, dynamic>{},
              await one(sb.from('day_closings').select('state,present_count,owner_remarks,submitted_at').eq('mess_id', m.id).eq('service_date', d).limit(1)));
        },
        builder: (context, m, x, reload) {
          final (c, dc) = x;
          int n(String k) => toI(c[k]);
          final byMeal = Map<String, dynamic>.from((c['by_meal'] as Map?) ?? const {});
          Widget line(String l, String v, [bool warn = false]) => Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
              child: _row([Expanded(child: Text(l, style: T.sm)), Text(v, style: T.b.copyWith(fontSize: 14, color: warn ? C.amber : C.ink))]));
          return Screen(
            top: Top(title: 'Close the day', sub: '${dayLong(d)} · ${m.name}', back: '/owner'),
            foot: foot([Btn('Send for review', kind: BtnKind.leaf, busy: busy, onTap: !m.owner || dc?['state'] == 'locked' ? null : () => act(() async {
              await call('submit_day', {'p_mess': m.id, 'p_date': d, 'p_remarks': remarks.text.trim().isEmpty ? null : remarks.text.trim()});
              reload();
            }))]),
            children: [
              Wrap2([for (final i in const [0, -1, -2]) Chip2(i == 0 ? 'Today' : i == -1 ? 'Yesterday' : day(today(i)), tone: today(i) == d ? Tone.on : Tone.plain, onTap: () => setState(() => d = today(i)))]),
              Hero2(child: _col([
                Text('Meals served or delivered', style: T.sm.copyWith(color: C.heroSub)),
                Text('${n('delivered')}', style: T.big.copyWith(color: Colors.white)),
                Wrap2([for (final y in meals) _row([Ico(mealIcon[y]!, size: 14, color: C.heroSub), Text('${byMeal[y] ?? 0}', style: T.xs.copyWith(color: C.heroSub))], gap: 4),
                  Text('Guests ${n('guests')}', style: T.xs.copyWith(color: C.heroSub))], gap: 12),
              ], gap: 6)),
              FCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
                line('Requested', '${n('requested')}'), line('Accepted', '${n('accepted')}'), line('Parcels delivered', '${n('parcels')}'),
                line('Confirmed', '${n('confirmed')}'), line('Not confirmed yet', '${n('not_confirmed')}', n('not_confirmed') > 0),
                line('Failed · cancelled', '${n('failed')} · ${n('cancelled')}'), line('Short given', '${n('short')}', n('short') > 0), line('Complaints', '${n('complaints')}'),
                line('Present (HR)', '${dc?['present_count'] ?? 'not in yet'}'),
              ])),
              if (dc?['state'] != null && dc!['state'] != 'open') Chip2(dc['state'] == 'locked' ? 'Locked by the supervisor' : 'Sent ${time(dc['submitted_at'] as String?)}', tone: Tone.leaf),
              Field('Remarks for the site supervisor', Input(controller: remarks, hint: '${dc?['owner_remarks'] ?? 'optional'}', maxLength: 1000, lines: 3)),
              const InfoLine('After the supervisor\'s review the day is locked; a correction keeps the original.'),
              ErrorLine(error),
            ],
          );
        },
      );
}

// ── o14 · Complaints ──
class OwnerComplaints extends StatefulWidget {
  const OwnerComplaints({super.key});
  @override
  State<OwnerComplaints> createState() => _OwnerComplaintsState();
}

class _OwnerComplaintsState extends State<OwnerComplaints> with Act {
  String tab = 'open';
  String? open;
  final reply = TextEditingController(), action = TextEditingController();
  @override
  void dispose() { reply.dispose(); action.dispose(); super.dispose(); }
  Future<void> media(String p) async {
    try {
      final u = await sb.storage.from('complaint-media').createSignedUrl(p, 300);
      await launchUrl(Uri.parse(u), mode: LaunchMode.externalApplication);
    } catch (_) { if (mounted) setState(() => error = 'The file could not be opened.'); }
  }
  @override
  Widget build(BuildContext context) => _WithMess<List<Rec>>(
        watch: const ['complaints'],
        title: 'Complaints',
        load: (m) => rows(sb.from('complaints').select().eq('mess_id', m.id).order('due_at')),
        builder: (context, m, list, reload) {
          final show = list.where((c) => tab == 'open' ? c['state'] == 'open' : tab == 'answered' ? ['answered', 'person_confirmed'].contains(c['state']) : c['state'] == 'closed').toList();
          return Screen(
            top: const Top(title: 'Complaints', sub: 'Answer within the time shown', back: '/owner'),
            children: [
              Seg(items: [('open', 'Open · ${list.where((c) => c['state'] == 'open').length}'), ('answered', 'Waiting'), ('closed', 'Closed')], value: tab, onChanged: (v) => setState(() => tab = v)),
              if (show.isEmpty) const Empty(icon: 'message-square-warning', title: 'Nothing here'),
              for (final c in show)
                FCard(border: c['serious'] == true && c['state'] == 'open' ? const Color(0xFFE8A49B) : null, child: _col([
                  _row([if (c['serious'] == true) const Chip2('Serious', icon: 'siren', tone: Tone.red, height: 26), const Spacer(),
                    if (c['state'] == 'open') Chip2(leftText('${c['due_at']}'), icon: 'timer', tone: Tone.amber, height: 26)]),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${c['text'] ?? c['heard_text'] ?? c['category']}', style: T.b.copyWith(fontSize: 16)),
                    Text('${c['code']} · ${c['category']} · ${c['people_count']} ${toI(c['people_count']) > 1 ? 'people' : 'person'} · ${time(c['created_at'] as String?)}', style: T.sm)]),
                  if ((c['photo_paths'] as List? ?? const []).isNotEmpty || c['voice_path'] != null) Wrap2([
                    for (final (i, p) in (c['photo_paths'] as List? ?? const []).indexed) Chip2('Photo ${i + 1}', icon: 'image', onTap: () => media('$p')),
                    if (c['voice_path'] != null) Chip2('Voice', icon: 'play', onTap: () => media('${c['voice_path']}')),
                  ]),
                  if (c['owner_reply'] != null) Text('Your reply: ${c['owner_reply']}', style: T.sm),
                  if (c['state'] == 'open') ...[
                    if (open == c['id']) ...[
                      Input(controller: reply, hint: 'Your reply'), Input(controller: action, hint: 'What you did (optional)'),
                      Btn('Send reply', kind: BtnKind.navy, busy: busy, onTap: () => act(() async {
                        await call('reply_complaint', {'p_id': c['id'], 'p_reply': reply.text.trim(), 'p_action': action.text.trim().isEmpty ? null : action.text.trim()});
                        setState(() { open = null; reply.clear(); action.clear(); });
                        reload();
                      })),
                    ] else Btn('Reply and action', kind: BtnKind.navy, small: true, onTap: () => setState(() => open = '${c['id']}')),
                  ],
                ], gap: 12)),
              ErrorLine(error),
              const InfoLine('Closed only after the person confirms it is solved.'),
            ],
          );
        },
      );
}

// ── o15 · Contractor billing ──
class OwnerBilling extends StatefulWidget {
  const OwnerBilling({super.key});
  @override
  State<OwnerBilling> createState() => _OwnerBillingState();
}

class _OwnerBillingState extends State<OwnerBilling> with Act {
  String? up;
  final number = TextEditingController(), amount = TextEditingController();
  final lines = <(TextEditingController, TextEditingController, TextEditingController)>[(TextEditingController(), TextEditingController(), TextEditingController())];
  File? file;
  static const _chain = ['invoice_uploaded', 'checked', 'site_admin_ok', 'accounts_ok', 'management_ok', 'posted', 'paid'];
  @override
  void dispose() {
    number.dispose(); amount.dispose();
    for (final l in lines) { l.$1.dispose(); l.$2.dispose(); l.$3.dispose(); }
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return _WithMess<(List<Rec>, List<Rec>)>(
      watch: const ['monthly_bills'],
      title: 'Billing',
      load: (m) async => (await rows(sb.from('monthly_bills').select().eq('mess_id', m.id).order('month', ascending: false)),
          await rows(sb.from('day_closings').select('service_date,state,counts').eq('mess_id', m.id).gte('service_date', '${today().substring(0, 8)}01'))),
      builder: (context, m, x, reload) {
        final (bills, days) = x;
        final locked = days.where((y) => y['state'] == 'locked').toList();
        Future<void> upload(String id) => act(() async {
              String? path;
              if (file != null) {
                path = '${s.me?['company_id']}/$id/${DateTime.now().millisecondsSinceEpoch}-invoice.jpg';
                try { await sb.storage.from('invoices').upload(path, file!, fileOptions: const FileOptions(contentType: 'image/jpeg')); } catch (_) { throw DbError('The file could not be sent.'); }
              }
              await call('upload_invoice', {'p_bill': id, 'p_number': number.text.trim(), 'p_path': path, 'p_amount': double.tryParse(amount.text.trim()) ?? 0,
                'p_lines': [for (final l in lines) if (l.$1.text.trim().isNotEmpty) {'item': l.$1.text.trim(), 'qty': double.tryParse(l.$2.text.trim()) ?? 0, 'rate': double.tryParse(l.$3.text.trim()) ?? 0}]});
              setState(() => up = null);
              reload();
            });
        return Screen(
          top: Top(title: 'Billing', sub: m.name, back: '/owner'),
          tabs: _tabs('/owner/billing'),
          children: [
            Hero2(child: _col([
              _row([Chip2('${monthName('${today().substring(0, 8)}01')} · verified only', tone: Tone.sf, height: 26), const Spacer(), Text('${locked.length} days closed', style: T.xs.copyWith(color: C.heroSub))]),
              Text('${locked.fold<int>(0, (n, y) => n + toI((y['counts'] as Map?)?['delivered']))}', style: T.big.copyWith(color: Colors.white)),
              Text('meals in closed days – the bill is made from them after the month', style: T.xs.copyWith(color: C.heroSub)),
            ], gap: 8)),
            if (bills.isEmpty) const Empty(icon: 'receipt', title: 'No bills yet', text: 'Accounts makes the bill after the month is over and every day is locked.'),
            for (final b in bills)
              Builder(builder: (_) {
                final at = _chain.indexOf('${b['state']}');
                final diffs = _list((b['recon'] as Map?)?['lines']).where((y) => y['why'] != 'matches').toList();
                return FCard(child: _col([
                  _row([Expanded(child: Text('${monthName('${b['month']}')} · ${b['code']}', style: T.b)), Text(inr(toD(b['net_payable'])), style: T.b)]),
                  Text('${b['invoice_number'] != null ? 'Invoice ${b['invoice_number']}' : 'No invoice yet'} · taxable ${inr(toD(b['taxable']))}', style: T.xs),
                  Wrap2([for (final (i, l) in const ['Uploaded', 'Checked', 'Site', 'Accounts', 'Approval', 'Posted', 'Paid'].indexed)
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: i <= at ? C.leafS : C.cream, borderRadius: BorderRadius.circular(8)),
                        child: Text(l, style: T.xs.copyWith(fontWeight: FontWeight.w600, color: i <= at ? C.leafD : C.muted)))], gap: 4),
                  if (b['state'] == 'sent_back') const Chip2('Sent back', tone: Tone.red, height: 26),
                  if (diffs.isNotEmpty) Text('${diffs.length} differences: ${diffs.map((y) => '${y['item']} – ${y['why']}').join('; ')}', style: T.sm.copyWith(color: const Color(0xFF8B1A1A))),
                  if (m.owner && ['draft', 'invoice_uploaded', 'checked'].contains(b['state'])) ...[
                    if (up == b['id']) ...[
                      _row([Expanded(child: Input(controller: number, hint: 'Invoice number')), Expanded(child: Input(controller: amount, hint: 'Amount before GST', keyboard: TextInputType.number))]),
                      for (final l in lines) _row([Expanded(flex: 2, child: Input(controller: l.$1, hint: 'item code')), Expanded(child: Input(controller: l.$2, hint: 'qty', keyboard: TextInputType.number)),
                        Expanded(child: Input(controller: l.$3, hint: 'rate', keyboard: TextInputType.number))], gap: 6),
                      Wrap2([
                        Chip2('Line', icon: 'plus', onTap: () => setState(() => lines.add((TextEditingController(), TextEditingController(), TextEditingController())))),
                        Chip2(file != null ? 'Invoice photo added' : 'Invoice photo', icon: 'upload', onTap: () async {
                          final f = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2000, imageQuality: 85);
                          if (f != null) setState(() => file = File(f.path));
                        }),
                      ]),
                      Btn('Upload the invoice', kind: BtnKind.navy, busy: busy, onTap: () { if (number.text.trim().isNotEmpty && amount.text.trim().isNotEmpty) upload('${b['id']}'); }),
                    ] else Btn('Upload the invoice', icon: 'upload', kind: BtnKind.ghost, small: true, onTap: () => setState(() => up = '${b['id']}')),
                  ],
                ]));
              }),
            ErrorLine(error),
          ],
        );
      },
    );
  }
}

// ── o16 · Confirmation follow-up ──
class FollowUp extends StatefulWidget {
  const FollowUp({super.key});
  @override
  State<FollowUp> createState() => _FollowUpState();
}

class _FollowUpState extends State<FollowUp> with Act {
  String? open;
  String out = 'got_all';
  final qty = TextEditingController(), note = TextEditingController();
  @override
  void dispose() { qty.dispose(); note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => _WithMess<List<Rec>>(
        watch: const ['confirmations', 'order_lines'],
        title: 'Not confirmed yet',
        load: (m) async => _list(await call<dynamic>('followups', {'p_mess': m.id, 'p_from': today(-7), 'p_to': today()})),
        builder: (context, m, list, reload) => Screen(
          top: Top(title: 'Not confirmed yet · ${list.length}', sub: 'Handed over, the person has not checked it', back: '/owner'),
          children: [
            if (list.isEmpty) const Empty(icon: 'circle-check', title: 'Everything is confirmed'),
            for (final x in list)
              FCard(child: _col([
                _row([Av(initials('${x['full_name']}')), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${x['full_name']}', style: T.b),
                  Text('${x['order_code']} · ${x['meal']} · ${day(x['service_date'] as String?)} · ${maskMobile(x['mobile'] as String?)}', style: T.xs)]))], gap: 12),
                _row([
                  if (x['mobile'] != null) Expanded(child: Btn('Call', icon: 'phone', kind: BtnKind.leaf, small: true, onTap: () => launchUrl(Uri.parse('tel:${x['mobile']}')))),
                  Expanded(child: Btn('Send reminder', kind: BtnKind.ghost, small: true, busy: busy, onTap: () => act(() async { await call('follow_up', {'p_line': x['order_line_id'], 'p_outcome': 'reminder'}); }))),
                ]),
                if (open == x['order_line_id']) ...[
                  Text('After the call he says', style: T.lbl),
                  Wrap2([for (final (v, l) in const [('got_all', 'Got all'), ('got_less', 'Got less'), ('did_not_get', 'Did not get'), ('no_answer', 'No answer')]) Chip2(l, tone: out == v ? Tone.on : Tone.plain, onTap: () => setState(() => out = v))], gap: 6),
                  if (out == 'got_less') Input(controller: qty, hint: 'How many of ${x['delivered_qty'] ?? 1}', keyboard: TextInputType.number),
                  Input(controller: note, hint: 'Note – e.g. said dal was cold'),
                  Btn('Save the follow-up', kind: BtnKind.navy, busy: busy, onTap: () => act(() async {
                    await call('follow_up', {'p_line': x['order_line_id'], 'p_outcome': out, 'p_qty': out == 'got_less' ? int.tryParse(qty.text.trim()) : null, 'p_note': note.text.trim().isEmpty ? null : note.text.trim()});
                    setState(() { open = null; note.clear(); qty.clear(); });
                    reload();
                  })),
                ] else Btn('Record the call', kind: BtnKind.ghost, small: true, onTap: () => setState(() { open = '${x['order_line_id']}'; out = 'got_all'; })),
              ])),
            ErrorLine(error),
            const InfoLine('Every call and answer is kept with who and when. A phone answer is never written as the person\'s code.'),
          ],
        ),
      );
}
