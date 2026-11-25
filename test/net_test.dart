// (25-11-2026 – SNI) the network as MEASURED in FALCON – core/net.dart (the same rules as the ERP app's) and ui/net.dart: the chip in
// every top bar, its sheet, the line under the top bar.
import 'dart:async';

import 'package:falcon/core/net.dart';
import 'package:falcon/ui/kit.dart';
import 'package:falcon/ui/net.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late NetMonitor m;
  late DateTime t;
  setUp(() {
    t = DateTime.utc(2026, 11, 25, 12);
    m = NetMonitor()
      ..on = true
      ..now = (() => t)
      ..internetCheck = () async => 140;
    NetMonitor.i = m;
  });
  tearDown(() => NetMonitor.i = NetMonitor());

  void ok(String s, int ms) => m.record(s, ms, NetEnd.ok);

  test('nothing measured: Checking – never a state that was not measured', () {
    expect(m.state, NetState.checking);
    expect(m.worst.$1, NetState.checking);
    expect(m.middleAll, isNull);
  });

  test('the middle time of the last 10 answers of the last 2 minutes: under 800 ms GOOD, 800 ms or more WEAK, one answer over 5 s WEAK', () {
    for (final x in [200, 240, 260]) {
      ok('mech', x);
    }
    expect(m.stateOf('mech'), NetState.good);
    expect(m.middleMs('mech'), 240);
    expect(m.state, NetState.good, reason: 'the first state shows at once');
    for (final x in [900, 1200, 1800, 2000]) {
      ok('hr', x);
    }
    expect(m.stateOf('hr'), NetState.weak);
    ok('portal', 300);
    ok('portal', 5200);
    ok('portal', 310);
    expect(m.stateOf('portal'), NetState.weak, reason: 'one answer over 5 s');
    expect(m.worst, (NetState.weak, 'hr'));
    // only the last 10 count, and only those of the last 2 minutes
    for (var i = 0; i < 10; i++) {
      ok('hr', 150);
    }
    expect(m.stateOf('hr'), NetState.good);
    t = t.add(const Duration(minutes: 3));
    expect(m.servers, isEmpty, reason: 'older than 2 minutes: not counted');
    expect(m.stateOf('hr'), NetState.checking);
  });

  test('two failures among the last 10: UNSTABLE; a server error twice in a row: SERVER DOWN', () {
    ok('mech', 200);
    m.record('mech', 900, NetEnd.serverError);
    ok('mech', 210);
    m.record('mech', 15000, NetEnd.timeout);
    ok('mech', 220);
    expect(m.stateOf('mech'), NetState.unstable);
    m.record('store', 300, NetEnd.serverError);
    m.record('store', 300, NetEnd.serverError);
    expect(m.stateOf('store'), NetState.serverDown);
  });

  test('no answer: RECONNECTING while Android\'s check is asked; it answers → SERVER DOWN, it fails too → OFFLINE', () async {
    final asked = Completer<int?>();
    var n = 0;
    m.internetCheck = () {
      n++;
      return asked.future;
    };
    ok('mech', 200);
    m.record('mech', 40000, NetEnd.timeout);
    expect(m.state, NetState.reconnecting, reason: 'at once – no 3 s hold for a failure');
    expect(n, 1, reason: 'the check is asked once');
    m.record('mech', 100, NetEnd.noConnection);
    expect(n, 1, reason: 'at most once in 10 s');
    asked.complete(140);
    await Future<void>.delayed(Duration.zero);
    expect(m.internet, true);
    expect(m.stateOf('mech'), NetState.serverDown);
    expect(m.state, NetState.serverDown);
    // later: no internet at all
    t = t.add(const Duration(seconds: 20));
    m.internetCheck = () async => null;
    m.record('mech', 100, NetEnd.noConnection);
    await Future<void>.delayed(Duration.zero);
    expect(m.internet, false);
    expect(m.state, NetState.offline);
    // the network back: the next answer counts again (the failures stay among the last 10: unstable for a while)
    t = t.add(const Duration(seconds: 5));
    ok('mech', 230);
    expect(m.stateOf('mech'), NetState.unstable);
  });

  testWidgets('a better state shows after it held 3 s (no flicker); a worse one at once', (tester) async {
    for (final x in [200, 210, 220]) {
      ok('mech', x);
    }
    expect(m.state, NetState.good);
    for (final x in [3000, 3100, 3200, 3300, 3400]) {
      ok('mech', x);
    }
    expect(m.worst.$1, NetState.weak);
    expect(m.state, NetState.good, reason: 'not yet – it must hold 3 s');
    await tester.pump(const Duration(seconds: 3));
    expect(m.state, NetState.weak);
    expect(m.changedFrom, NetState.good);
  });

  test('a request on its way for more than 5 s: the "slow network" line; done: gone', () async {
    final c = Completer<int>();
    final f = m.watch<int>('mech', c.future, const Duration(seconds: 40));
    expect(m.slowest, isNull);
    t = t.add(const Duration(seconds: 6));
    expect(m.slowest, const Duration(seconds: 6));
    expect(netLineKind(m), 'slow');
    c.complete(1);
    await f;
    expect(m.slowest, isNull);
    expect(m.recent('mech').single.ms, 6000, reason: 'its real time');
  });

  testWidgets('no answer within the limit: a timeout is counted then (a later answer is not counted again)', (tester) async {
    final c = Completer<int>();
    unawaited(m.watch<int>('hr', c.future, const Duration(seconds: 40)));
    await tester.pump(const Duration(seconds: 41));
    expect(m.recent('hr').single.end, NetEnd.timeout);
    c.complete(1);
    await tester.pump();
    expect(m.recent('hr').length, 1);
  });

  test('off (the tests of the other screens, the background alarm): nothing is recorded, nothing asked', () {
    var asked = 0;
    m
      ..on = false
      ..internetCheck = () async {
        asked++;
        return 1;
      };
    m.record('mech', 100, NetEnd.noConnection);
    expect(m.servers, isEmpty);
    expect(asked, 0);
  });

  test('FALCON\'s servers by their address: its Supabase, its server; anything else is not measured', () {
    expect(falconServerOf(Uri.parse('https://files.test/x.jpg')), '');
  });

  testWidgets('the chip in every top bar says what was measured; a tap: each server; Check now asks FALCON\'s server and Android\'s check', (tester) async {
    var probes = 0, checks = 0;
    m
      ..probe = () async {
        probes++;
        ok('server', 180);
      }
      ..internetCheck = () async {
        checks++;
        return 140;
      };
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Top(title: 'Order food'))));
    expect(find.text('Checking'), findsOneWidget);
    ok('db', 240);
    ok('db', 260);
    ok('live', 310);
    await tester.pump();
    expect(find.text('260 ms'), findsOneWidget);
    await tester.tap(find.byKey(const Key('net-chip')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-server-db')), findsOneWidget);
    expect(find.byKey(const Key('net-server-live')), findsOneWidget);
    expect(find.text('FALCON database'), findsOneWidget);
    await tester.tap(find.byKey(const Key('net-check')));
    await tester.pumpAndSettle();
    expect([probes, checks], [1, 1]);
    expect(find.byKey(const Key('net-server-server')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('the line under the top bar: no internet; × hides it until the state changes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Screen(top: Top(title: 'Home'), children: [Text('body')])));
    ok('db', 200);
    m.internetCheck = () async => null;
    m.record('db', 100, NetEnd.noConnection);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-line-offline')), findsOneWidget);
    expect(find.text('Offline'), findsOneWidget, reason: 'the chip');
    await tester.tap(find.byKey(const Key('net-line-close')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('net-line-offline')), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
