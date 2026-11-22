// The screens' addresses – the same as the web's (src/App.tsx) – and who may open what. The database checks again on every read
// and action; this only decides which screen to show.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/prefs.dart';
import 'core/session.dart';
import 'screens/start.dart' as start;
import 'ui/kit.dart';

const emp = ['employee', 'guest'];
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
        _r('/start/rcl-id', (_) => const start.RclId()),
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
      _n('/app', ['employee'], (_) => const _Soon('My meals')),
      _n('/guest', ['guest'], (_) => const _Soon('Guest')),
      _n('/owner', own, (_) => const _Soon('My mess')),
      _n('/driver', ['driver'], (_) => const _Soon('My deliveries')),
    ];

class _Soon extends StatelessWidget {
  const _Soon(this.what);
  final String what;
  @override
  Widget build(BuildContext context) => Screen(top: Top(title: what), children: const [Loading()]);
}
