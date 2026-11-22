// Boards g01–g03: a guest coming back (his one profile, today's visit with its purpose and host), his home, his visits and orders –
// the app's own screens on the same data and actions as the web's src/screens/guest.tsx.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/db.dart';
import '../core/fmt.dart';
import '../core/meals.dart';
import '../core/session.dart';
import '../ui/kit.dart';
import '../ui/look.dart';
import 'employee.dart';

const _plum = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3B2470), Color(0xFF5B2BA0)]);

Future<Rec?> _profile(Session s) => one(sb.from('guest_profiles').select('guest_code,organisation,designation').eq('person_id', s.personId ?? '').limit(1));
Future<List<Rec>> _visits(Session s) => rows(sb.from('guest_visits').select().eq('person_id', s.personId ?? '').order('started_at', ascending: false));

// ── g01 · Welcome back, guest ──
class GuestWelcome extends StatefulWidget {
  const GuestWelcome({super.key});
  @override
  State<GuestWelcome> createState() => _GuestWelcomeState();
}

class _GuestWelcomeState extends State<GuestWelcome> with Act {
  String? site, host;
  final purpose = TextEditingController();
  @override
  void dispose() { purpose.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    site ??= s.sites.firstOrNull?.id;
    return Load<(Rec?, List<Rec>)>(
      loading: const Screen(children: [Loading()]),
      load: () async => (await _profile(s), await _visits(s)),
      builder: (context, x, reload) {
        final (prof, visits) = x;
        final last = visits.firstOrNull;
        final lastSite = s.sites.where((y) => y.id == last?['site_id']).firstOrNull;
        return Scaffold(
          backgroundColor: C.cream,
          body: ListView(padding: EdgeInsets.zero, children: [
            Container(
              padding: EdgeInsets.fromLTRB(24, 40 + MediaQuery.of(context).padding.top, 24, 30),
              decoration: const BoxDecoration(gradient: _plum, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Av(initials(s.name), size: 56, tone: const Tone(Color(0x29FFFFFF), Colors.white)), const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Guest', style: T.sm.copyWith(color: const Color(0xFFE1D4F7))),
                    Text('${visits.isNotEmpty ? 'Welcome back, ' : 'Welcome, '}${firstName(s.name)}', style: const TextStyle(fontFamily: font, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5, color: Colors.white)),
                  ])),
                ]),
                const SizedBox(height: 16),
                Wrap2([
                  Chip2('Visit ${visits.length + 1}', tone: const Tone(Color(0x24FFFFFF), Colors.white), height: 28),
                  if (last != null) Chip2('Last: ${day(last['started_at'] as String?)}${lastSite != null ? ' · ${lastSite.code}' : ''}', tone: const Tone(Color(0x24FFFFFF), Colors.white), height: 28),
                ]),
              ]),
            ),
            Padding(padding: const EdgeInsets.fromLTRB(20, 20, 20, 26), child: Load<List<Rec>>(
              key: ValueKey(site),
              load: () async {
                if (site == null) return <Rec>[];
                final r = await call<dynamic>('visit_hosts', {'p_site': site});
                return [for (final h in (r as List? ?? const [])) Map<String, dynamic>.from(h as Map)];
              },
              builder: (context, hosts, _) {
                final h = hosts.where((y) => y['person_id'] == host).firstOrNull;
                Future<void> start() => act(() async {
                      if (purpose.text.trim().length < 2) throw DbError('Write the purpose of today\'s visit.');
                      await call('start_visit', {'p_site': site, 'p_purpose': purpose.text.trim(), 'p_section': null, 'p_host': h?['person_id'], 'p_host_role': h?['role']});
                      if (context.mounted) context.go('/guest');
                    });
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  FCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Is this you?', style: T.h2), const SizedBox(height: 10),
                    _line('user', '${s.name}${prof?['designation'] != null ? ' · ${prof!['designation']}' : ''}'),
                    if (prof?['organisation'] != null) _line('building-2', '${prof!['organisation']}'),
                    _line('phone', '${maskMobile(s.me?['mobile'] as String?)} · verified'),
                  ])),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: _pick(context, 'Site', s.sites.where((y) => y.id == site).map((y) => y.code).firstOrNull, [for (final y in s.sites) (y.id, '${y.code} · ${y.name}')], (v) => setState(() { site = v; host = null; }))),
                    const SizedBox(width: 10),
                    Expanded(child: _pick(context, 'Host', h != null ? '${h['full_name']}' : 'No host', [('', 'No host'), for (final y in hosts) ('${y['person_id']}', '${y['full_name']} · ${y['role']}')], (v) => setState(() => host = v.isEmpty ? null : v))),
                  ]),
                  const SizedBox(height: 14),
                  Field('Today\'s visit – purpose', Input(controller: purpose, hint: 'e.g. quality audit at B2', maxLength: 200)),
                  const SizedBox(height: 14),
                  const InfoLine('This phone only suggests your profile. A WhatsApp code is asked on a new phone or after 30 days.', icon: 'shield-check'),
                  const SizedBox(height: 10),
                  ErrorLine(error),
                  const SizedBox(height: 10),
                  Btn('Yes, it\'s me – start today\'s visit', kind: BtnKind.plum, busy: busy, onTap: start),
                  const SizedBox(height: 10),
                  Btn('Not me', kind: BtnKind.ghost, onTap: () => s.signOut()),
                ]);
              },
            )),
          ]),
        );
      },
    );
  }
}

Widget _line(String icon, String text) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
      Ico(icon, size: 16, color: C.muted), const SizedBox(width: 8), Expanded(child: Text(text, style: T.sm.copyWith(color: C.ink))),
    ]));

Widget _pick(BuildContext context, String label, String? value, List<(String, String)> options, ValueChanged<String> onPick) => Field(label, Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line2)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final v = await sheet<String>(context, (ctx) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(label, style: T.h2),
                for (final o in options) ListTile(contentPadding: EdgeInsets.zero, title: Text(o.$2, style: T.body), onTap: () => Navigator.pop(ctx, o.$1)),
              ]));
          if (v != null) onPick(v);
        },
        child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
          Expanded(child: Text(value ?? 'Choose', maxLines: 1, overflow: TextOverflow.ellipsis, style: T.body)),
          const Ico('chevron-down', size: 18, color: C.muted),
        ])),
      ),
    ));

// ── g02 · Guest home ──
class GuestHome extends StatelessWidget {
  const GuestHome({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(Rec?, List<Rec>, MessDay, List<Rec>, List<Rec>)>(
      watch: const ['orders'],
      loading: const Screen(children: [Loading()]),
      load: () async {
        final v = await guestVisit(s.personId, s.kind);
        final d = await messDay(s);
        final menu = d.mess == null ? <Rec>[] : await rows(sb.from('menus').select('meal,dishes').eq('mess_id', d.mess!.id).eq('service_date', today()));
        final orders = v == null ? <Rec>[] : await rows(sb.from('orders').select('id,code,meal,kind,state,host_state,created_at').eq('guest_visit_id', '${v['id']}').order('created_at', ascending: false));
        return (v, await _visits(s), d, menu, orders);
      },
      builder: (context, x, reload) {
        final (v, visits, d, menu, orders) = x;
        if (v == null) return const _GoWelcome();
        final nowHm = nowHM();
        final now = ([...d.wins]..sort((a, b) => a.serveFrom.compareTo(b.serveFrom))).where((w) => nowHm.compareTo(w.serveTo) <= 0).firstOrNull;
        final site = s.sites.where((y) => y.id == v['site_id']).firstOrNull;
        final dishes = (menu.where((r) => r['meal'] == now?.meal).firstOrNull?['dishes'] as List?)?.join(', ');
        return Screen(
          top: Top(left: Av(initials(s.name), tone: Tone.plum), title: s.name, sub: 'Guest · visit ${visits.isEmpty ? 1 : visits.length} · ${site?.code ?? ''} · today',
              right: IconBox(icon: 'history', label: 'My visits', onTap: () => context.go('/guest/history'))),
          tabs: tabsFor(s, '/guest'),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: _plum, borderRadius: BorderRadius.circular(24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Chip2(now != null ? '${mealName(now.meal)} · till ${now.serveTo}' : 'No meal open now', tone: const Tone(Color(0x29FFFFFF), Colors.white), height: 26),
                const SizedBox(height: 12),
                const Text('What would you like?', style: TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(dishes ?? 'The menu is shown when the mess publishes it', style: T.xs.copyWith(color: const Color(0xFFE1D4F7))),
              ]),
            ),
            Row(children: [
              for (final (i, (to, ic, tone, l)) in const [('/app/meal', 'utensils', Tone.leaf, 'At the mess'), ('/app/parcel', 'package', Tone.sf, 'Parcel'), ('/app/section', 'truck', Tone.blue, 'Deliver to me')].indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: FCard(padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10), onTap: () => context.push(to),
                    child: Column(children: [Tile(ic, tone: tone), const SizedBox(height: 8), Text(l, textAlign: TextAlign.center, style: T.b.copyWith(fontSize: 14))]))),
              ],
            ]),
            for (final o in orders)
              FCard(onTap: () => context.push('/app/orders/${o['id']}'), child: Row(children: [
                const Tile('clock', tone: Tone.cream, size: 40), const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${mealName(o['meal'] as String?)} · ${o['kind'] == 'meal' ? 'at the mess' : o['kind']}', style: T.b),
                  Text('Asked ${time(o['created_at'] as String?)}${o['host_state'] == 'waiting' ? ' · waiting for the host\'s OK' : ''}', style: T.xs),
                ])),
                Chip2(o['host_state'] == 'waiting' ? 'Waiting' : '${o['state']}', tone: o['host_state'] == 'waiting' || o['state'] == 'requested' ? Tone.amber : o['state'] == 'delivered' ? Tone.leaf : Tone.plain, height: 26),
              ])),
            FCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Expanded(child: Text('Today\'s visit', style: T.b)), Text('started ${time(v['started_at'] as String?)}', style: T.xs)]),
              const SizedBox(height: 8),
              _line('map-pin', '${site != null ? '${site.code} · ${site.name}' : ''} · ${v['purpose']}'),
              _line('user-check', v['host_id'] != null ? 'Host: ${v['host_role'] ?? 'office'}' : 'No host – your orders go straight to the mess'),
            ])),
            const InfoLine('You see only your own visits and orders.', icon: 'shield-check'),
          ],
        );
      },
    );
  }
}

class _GoWelcome extends StatefulWidget {
  const _GoWelcome();
  @override
  State<_GoWelcome> createState() => _GoWelcomeState();
}

class _GoWelcomeState extends State<_GoWelcome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.go('/guest/welcome'); });
  }
  @override
  Widget build(BuildContext context) => const Screen(children: [Loading()]);
}

// ── g03 · My visits and orders ──
class GuestHistory extends StatefulWidget {
  const GuestHistory({super.key});
  @override
  State<GuestHistory> createState() => _GuestHistoryState();
}

class _GuestHistoryState extends State<GuestHistory> {
  String tab = 'visits';
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Load<(Rec?, List<Rec>, List<Rec>, List<Rec>)>(
      watch: const ['orders'],
      loading: Screen(top: const Top(title: 'My visits', back: '/guest'), tabs: tabsFor(s, '/guest/history'), children: const [Loading()]),
      load: () async => (await _profile(s), await _visits(s),
          await rows(sb.from('orders').select('id,code,meal,kind,state,service_date,guest_visit_id').order('created_at', ascending: false).limit(100)),
          await rows(sb.from('complaints').select('id,code,category,state,created_at').order('created_at', ascending: false))),
      builder: (context, x, reload) {
        final (prof, visits, orders, complaints) = x;
        final meals = orders.where((o) => o['state'] == 'delivered').length;
        final parcels = orders.where((o) => o['state'] == 'delivered' && o['kind'] != 'meal').length;
        return Screen(
          top: Top(title: 'My visits', sub: 'Guest ID ${prof?['guest_code'] ?? '–'}${visits.isNotEmpty ? ' · since ${day(visits.last['started_at'] as String?)}' : ''}', back: '/guest'),
          tabs: tabsFor(s, '/guest/history'),
          children: [
            Row(children: [
              for (final (i, (l, n)) in [('Visits', visits.length), ('Meals', meals), ('Parcels', parcels)].indexed) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(child: FCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: T.xs), Text('$n', style: T.b.copyWith(fontSize: 24))]))),
              ],
            ]),
            Seg(items: const [('visits', 'Visits'), ('orders', 'Orders'), ('complaints', 'Complaints')], value: tab, onChanged: (v) => setState(() => tab = v)),
            if (tab == 'visits') ...[
              if (visits.isEmpty) const Empty(icon: 'history', title: 'No visits yet'),
              for (final (i, v) in visits.indexed)
                Builder(builder: (_) {
                  final site = s.sites.where((y) => y.id == v['site_id']).firstOrNull, mine = orders.where((o) => o['guest_visit_id'] == v['id']).toList();
                  return FCard(padding: const EdgeInsets.all(12), border: v['ended_at'] == null ? const Color(0xFFC9B4EF) : null, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [Expanded(child: Text('Visit ${visits.length - i} · ${v['ended_at'] != null ? day(v['started_at'] as String?) : 'today'}', style: T.b)),
                      if (v['ended_at'] != null) Text(site?.code ?? '', style: T.xs) else const Chip2('Open', tone: Tone.plum, height: 24)]),
                    const SizedBox(height: 8),
                    Wrap2([Text('${site?.code ?? ''} · ${v['purpose']}', style: T.xs), for (final o in mine) Tag('${mealName(o['meal'] as String?)}${o['kind'] != 'meal' ? ' · ${o['kind']}' : ''}')], gap: 6),
                  ]));
                }),
            ],
            if (tab == 'orders') ...[
              if (orders.isEmpty) const Empty(icon: 'receipt', title: 'No orders yet'),
              for (final o in orders)
                FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/app/orders/${o['id']}'), child: Row(children: [
                  Expanded(child: Text('${o['code']} · ${mealName(o['meal'] as String?)}', style: T.b.copyWith(fontSize: 14))), Text('${day(o['service_date'] as String?)} · ${o['state']}', style: T.xs)])),
            ],
            if (tab == 'complaints') ...[
              if (complaints.isEmpty) const Empty(icon: 'message-square-warning', title: 'No complaints'),
              for (final c in complaints)
                FCard(padding: const EdgeInsets.all(12), onTap: () => context.push('/app/complaints/${c['id']}'), child: Row(children: [
                  Expanded(child: Text('${c['code']} · ${c['category']}', style: T.b.copyWith(fontSize: 14))), Text('${day(c['created_at'] as String?)} · ${c['state']}', style: T.xs)])),
            ],
            const InfoLine('One guest profile for every visit – never a second one.', icon: 'shield-check'),
          ],
        );
      },
    );
  }
}
