// The screens' addresses – the same as the web's (src/App.tsx) – and who may open what. The database checks again on every read
// and action; this only decides which screen to show.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/prefs.dart';
import 'core/session.dart';
import 'screens/employee.dart' as emp;
import 'screens/guest.dart' as guest;
import 'screens/start.dart' as start;
import 'ui/kit.dart';

const emp_ = ['employee', 'guest'];
const own = ['mess_owner', 'mess_operator'];
const waitingStates = ['pending_verification', 'mobile_pending', 'whatsapp_verified', 'id_not_found', 'new_registration'];

/// A screen for these roles only (with the session's loading, waiting and stopped states).
class Need extends StatelessWidget {
  const Need(this.roles, this.child, {super.key});
  final List<String> roles;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    switch (s.status) {
      case Status.loading: return const Screen(children: [Loading()]);
      case Status.off: return const start.Setup();
      case Status.signedout: case Status.noperson: return const start.Who();
      case Status.stopped: return const start.Stopped();
      case Status.ready: break;
    }
    if (s.needsCode) return const start.CodeAgain();
    if (waitingStates.contains(s.state) && !s.isStaff) return const start.Waiting();
    if (!s.has(roles)) return const Screen(children: [Denied()]);
    return child;
  }
}

class Root extends StatelessWidget {
  const Root({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    switch (s.status) {
      case Status.loading: return const Screen(children: [Loading()]);
      case Status.off: return const start.Setup();
      case Status.signedout: case Status.noperson: return const start.Who();
      case Status.stopped: return const start.Stopped();
      case Status.ready: break;
    }
    if (s.needsCode) return const start.CodeAgain();
    if (s.state == 'pending_verification' && !s.isStaff) return const start.Waiting();
    final h = s.homes();
    if (h.isEmpty) return const start.Waiting();
    if (h.length == 1 && h.first.path != 'web') return _Go(h.first.path);
    return start.Choose(items: h);
  }
}

/// Goes on to a path right after it is drawn (the start page of a person with one part of FALCON).
class _Go extends StatefulWidget {
  const _Go(this.path);
  final String path;
  @override
  State<_Go> createState() => _GoState();
}

class _GoState extends State<_Go> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.go(widget.path); });
  }
  @override
  Widget build(BuildContext context) => const Screen(children: [Loading()]);
}

GoRoute _r(String path, Widget Function(GoRouterState s) b) => GoRoute(path: path, builder: (c, s) => b(s));
GoRoute _n(String path, List<String> roles, Widget Function(GoRouterState s) b) => GoRoute(path: path, builder: (c, s) => Need(roles, b(s)));

GoRouter buildRouter(Session session) => GoRouter(
      refreshListenable: session,
      initialLocation: '/',
      routes: [
        _r('/', (_) => const Root()),
        _r('/setup', (_) => const start.Setup()),
        _r('/start', (_) => const start.Who()),
        _r('/start/employee', (_) => const start.RclId()),
        _r('/start/rcl-id', (_) => const start.RclId()),
        _r('/start/contractor', (_) => const start.Contractor()),
        _r('/start/found', (_) => const start.Found()),
        _r('/start/code', (_) => const start.Code()),
        _r('/start/done', (_) => const start.Done()),
        _r('/start/not-found', (_) => const start.NotFound()),
        _r('/start/new', (_) => const start.NewReg()),
        _r('/start/back', (_) => const start.Back()),
        _r('/start/temporary', (_) => const start.Waiting()),
        _r('/guest/new', (_) => const start.GuestNew()),
        // a mess counter's QR read by the phone's own camera: the mess is remembered, then the meal at that counter
        GoRoute(path: '/m/:id', redirect: (c, s) {
          final id = s.pathParameters['id'] ?? '';
          if (RegExp(r'^[0-9a-f-]{36}$', caseSensitive: false).hasMatch(id)) Prefs.mess = id;
          final n = (s.uri.queryParameters['c'] ?? '1').replaceAll(RegExp(r'\D'), '');
          return '/app/meal?counter=${n.isEmpty ? '1' : n}';
        }),
        ...appRoutes(),
      ],
      errorBuilder: (c, s) => const Root(),
    );

/// The roles' screens – added by each part of the app.
List<RouteBase> appRoutes() => [
      // the employee's app (Main, e02–e16) – a guest uses the same meal, parcel, order and complaint screens
      _n('/app', ['employee'], (_) => const emp.EmpHome()),
      _n('/app/scan', emp_, (_) => const emp.Scan()),
      _n('/app/meal', emp_, (s) => emp.MealAtMess(counter: s.uri.queryParameters['counter'])),
      _n('/app/parcel', emp_, (_) => const emp.Parcel()),
      _n('/app/section', emp_, (_) => const emp.SectionPick()),
      _n('/app/menu', emp_, (_) => const emp.Menu()),
      _n('/app/menu/poster', emp_, (s) => emp.Poster(date: s.uri.queryParameters['d'], meal: s.uri.queryParameters['m'])),
      _n('/app/orders', emp_, (_) => const emp.Orders()),
      _n('/app/orders/:id', emp_, (s) => emp.OrderStatus(id: s.pathParameters['id']!)),
      _n('/app/orders/:id/track', emp_, (s) => emp.Track(id: s.pathParameters['id']!)),
      _n('/app/orders/:id/driver', emp_, (s) => emp.DriverCard(id: s.pathParameters['id']!)),
      _n('/app/orders/:id/confirm', emp_, (s) => emp.ShowCode(id: s.pathParameters['id']!)),
      _n('/app/orders/:id/quantity', emp_, (s) => emp.Received(id: s.pathParameters['id']!)),
      _n('/app/orders/:id/review', emp_, (s) => emp.Review(id: s.pathParameters['id']!)),
      _n('/app/complaints/new', emp_, (s) => emp.Complaint(order: s.uri.queryParameters['order'], cat: s.uri.queryParameters['cat'])),
      _n('/app/complaints/:id', emp_, (s) => emp.ComplaintTicket(id: s.pathParameters['id']!)),
      _n('/app/guest', ['employee'], (_) => const emp.GuestRequest()),
      _n('/app/group', ['employee'], (_) => const emp.Group()),
      _n('/app/me', emp_, (_) => const emp.Me()),
      _n('/app/notifications', emp_, (_) => const emp.Me()),
      // the guest (g01–g03)
      _n('/guest', ['guest'], (_) => const guest.GuestHome()),
      _n('/guest/welcome', ['guest'], (_) => const guest.GuestWelcome()),
      _n('/guest/history', ['guest'], (_) => const guest.GuestHistory()),
      _n('/owner', own, (_) => const _Soon('My mess')),
      _n('/driver', ['driver'], (_) => const _Soon('My deliveries')),
    ];

class _Soon extends StatelessWidget {
  const _Soon(this.what);
  final String what;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Screen(top: Top(title: what), children: [
      Empty(
        icon: 'clock',
        title: 'Coming in the next build',
        text: 'You are signed in${s.name.isEmpty ? '' : ' as ${s.name}'}. This part of FALCON is being moved into the app – '
            'until then it is on the web.',
        action: Btn('Sign out', icon: 'log-out', kind: BtnKind.ghost, onTap: () => s.signOut()),
      ),
    ]);
  }
}
