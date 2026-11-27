/* (25-11-2026 – SNI, his approval of the five pictures: "he sagle tu dilel screen pn ok aahet asch banaw") WHAT THE PERSON SEES OF
 * THE NETWORK in FALCON – the same as the ERP app's pictures, in FALCON's own look:
 *   [NetChip]  – in every top bar (Top): a dot and the measured time; see-through on the driver's dark screens; a tap → [NetSheet];
 *   [NetSheet] – each server measured apart (the database, the server, the live updates), Android's check, the last change, "Check now";
 *   [NetLine]  – one line under the top bar when it matters: slow (a request waiting over 5 s), reconnecting, server down, no internet;
 *                × hides it until the state changes;
 *   [NetHost]  – the monitor's rhythm while the app is in front (nothing in the background).
 * Everything from core/net.dart (real requests only); before the first answer: "Checking". */
import 'dart:async';

import 'package:flutter/material.dart';

import '../core/net.dart';
import 'look.dart';

Color netColor(NetState s) => switch (s) {
      NetState.good => C.leaf,
      NetState.weak => C.amber,
      NetState.unstable || NetState.reconnecting => C.sf,
      NetState.serverDown => C.red,
      NetState.offline => const Color(0xFF667085),
      NetState.checking => const Color(0xFF98A2B3),
    };

String netChipText(NetMonitor m) {
  final s = m.state, mid = m.middleAll;
  return switch (s) {
    NetState.good => mid == null ? 'Good' : msText(mid),
    NetState.weak => 'Weak${mid == null ? '' : ' · ${msText(mid)}'}',
    NetState.unstable => 'Unstable',
    NetState.reconnecting => 'Reconnecting',
    NetState.serverDown => 'Server down',
    NetState.offline => 'Offline',
    NetState.checking => 'Checking',
  };
}

String _word(NetState s) => switch (s) {
      NetState.good => 'Good',
      NetState.weak => 'Weak',
      NetState.unstable => 'Unstable',
      NetState.reconnecting => 'Reconnecting',
      NetState.serverDown => 'Server not reachable',
      NetState.offline => 'No internet',
      NetState.checking => 'Checking',
    };

/// The chip in the top bar. [dark]: the driver's navy screens (see-through, white words).
class NetChip extends StatelessWidget {
  const NetChip({super.key, this.dark = false});
  final bool dark;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NetMonitor.i,
        builder: (context, _) {
          final m = NetMonitor.i, s = m.state, col = netColor(s);
          final lead = s == NetState.reconnecting
              ? SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: dark ? Colors.white : C.sf, backgroundColor: (dark ? Colors.white : C.sf).withValues(alpha: .25)))
              : Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: s == NetState.checking ? Colors.transparent : col,
                    shape: BoxShape.circle,
                    border: s == NetState.checking ? Border.all(color: dark ? Colors.white70 : col, width: 1.6) : (dark ? Border.all(color: Colors.white, width: 1.4) : null),
                  ),
                );
          return Semantics(
            button: true,
            label: 'Network: ${netChipText(m)}',
            child: GestureDetector(
              key: const Key('net-chip'),
              behavior: HitTestBehavior.opaque,
              onTap: () => showNetSheet(context),
              child: Container(
                height: 28,
                padding: const EdgeInsets.fromLTRB(10, 0, 11, 0),
                decoration: BoxDecoration(
                  color: dark ? Colors.white.withValues(alpha: .10) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: dark ? C.navy3 : C.line),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  lead,
                  const SizedBox(width: 6),
                  Text(netChipText(m), maxLines: 1, style: TextStyle(fontFamily: font, fontSize: 12.5, fontWeight: FontWeight.w600, height: 1, color: dark ? Colors.white : C.ink)),
                ]),
              ),
            ),
          );
        },
      );
}

Future<void> showNetSheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (c) => const NetSheet(),
    );

class NetSheet extends StatefulWidget {
  const NetSheet({super.key});
  @override
  State<NetSheet> createState() => _NetSheetState();
}

class _NetSheetState extends State<NetSheet> {
  bool _busy = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 5), (_) => NetMonitor.i.tick());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _hm(DateTime t) => MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(t));

  String _why(NetMonitor m) {
    final (s, who) = m.worst;
    final name = serverName(who);
    final r = who.isEmpty ? const <NetMark>[] : m.recent(who);
    final fails = r.where((x) => !x.ok).length;
    return switch (s) {
      NetState.checking => 'Nothing measured yet – it shows after the app\'s first answer.',
      NetState.good || NetState.weak => 'Measured from the app\'s own work – no test traffic.',
      NetState.unstable => '$fails of the last ${r.length} requests to the $name failed.',
      NetState.reconnecting => 'A request to the $name got no answer – checking the internet.',
      NetState.serverDown => 'Your internet works. The $name is not answering ($fails of the last ${r.length}). The app asks again by itself.',
      NetState.offline => 'No internet – mobile data is off or has no signal. The app asks again by itself.',
    };
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NetMonitor.i,
        builder: (context, _) {
          final m = NetMonitor.i, s = m.state, mid = m.middleAll, ch = m.changedAt, from = m.changedFrom;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Expanded(child: Text('Network', style: TextStyle(fontFamily: font, fontSize: 20, fontWeight: FontWeight.w700, color: C.ink))),
                  OutlinedButton(
                    key: const Key('net-check'),
                    style: OutlinedButton.styleFrom(foregroundColor: C.leaf, side: const BorderSide(color: C.leafS, width: 1.5), shape: const StadiumBorder()),
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await NetMonitor.i.checkNow();
                            if (mounted) setState(() => _busy = false);
                          },
                    child: _busy
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.leaf))
                        : const Text('Check now', style: TextStyle(fontFamily: font, fontWeight: FontWeight.w700)),
                  ),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Container(width: 12, height: 12, decoration: BoxDecoration(color: netColor(s), shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Flexible(child: Text(_word(s), key: const Key('net-word'), style: const TextStyle(fontFamily: font, fontSize: 22, fontWeight: FontWeight.w700, color: C.ink))),
                  if ((s == NetState.good || s == NetState.weak) && mid != null) ...[
                    const SizedBox(width: 10),
                    Text('middle time ${msText(mid)}\nthe last 2 minutes', style: T.sm),
                  ],
                ]),
                const SizedBox(height: 8),
                Text(_why(m), style: T.sm),
                if (m.servers.isNotEmpty) ...[
                  _sec('Servers'),
                  for (final k in m.servers) _server(m, k),
                ],
                _sec('This phone'),
                if (m.internetAt != null)
                  _row('Internet', m.internet == true ? 'works' : 'no answer', m.internet == true ? C.leaf : C.red,
                      'check ${_hm(m.internetAt!)}${m.internetMs == null ? '' : ' · ${msText(m.internetMs!)}'}')
                else
                  _row('Internet', 'not checked', null, 'only when a server fails'),
                if (ch != null && from != null && from != NetState.checking) _row('Last change', _hm(ch), null, '${_word(from)} → ${_word(s)}'),
              ]),
            ),
          );
        },
      );

  Widget _sec(String t) => Padding(padding: const EdgeInsets.fromLTRB(0, 16, 0, 4), child: Text(t, style: T.lbl));

  Widget _server(NetMonitor m, String k) {
    final r = m.recent(k), st = m.stateOf(k), mid = m.middleMs(k), fails = r.where((x) => !x.ok).length;
    final down = st == NetState.serverDown || st == NetState.offline || st == NetState.reconnecting;
    return _row(serverName(k), down ? 'no answer' : (mid == null ? '–' : msText(mid)), netColor(st), '${r.length - fails} answers · $fails failed', key: Key('net-server-$k'));
  }

  Widget _row(String name, String value, Color? dot, String small, {Key? key}) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: Row(children: [
          Expanded(child: Text(name, style: const TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600, color: C.ink))),
          SizedBox(
            width: 104,
            child: Row(children: [
              if (dot != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
              Flexible(child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w700, color: dot == C.red ? C.red : C.ink))),
            ]),
          ),
          SizedBox(width: 120, child: Text(small, textAlign: TextAlign.right, style: T.xs)),
        ]),
      );
}

/// Which line is shown under the top bar now ('' = none).
String netLineKind(NetMonitor m) {
  final s = m.state;
  if (s == NetState.offline) return 'offline';
  if (s == NetState.serverDown) return 'server';
  if (s == NetState.reconnecting) return 'reconnect';
  if (m.slowest != null) return 'slow';
  return '';
}

String _closed = '';

/// The line under the top bar (Screen puts it there on every screen).
class NetLine extends StatefulWidget {
  const NetLine({super.key});
  @override
  State<NetLine> createState() => _NetLineState();
}

class _NetLineState extends State<NetLine> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    // the "slow" line follows a request that is still waiting – looked at every second while the screen is shown
    if (NetMonitor.i.on) _t = Timer.periodic(const Duration(seconds: 1), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: NetMonitor.i,
        builder: (context, _) {
          final k = netLineKind(NetMonitor.i);
          if (k != _closed) _closed = '';
          Widget line = const SizedBox(width: double.infinity);
          if (k.isNotEmpty && k != _closed) {
            final (bg, fg, icon) = switch (k) {
              'slow' => (C.amberS, C.amber, Icons.speed_rounded),
              'reconnect' => (C.sfS, C.sfD, Icons.sync_rounded),
              'server' => (C.redS, C.redD, Icons.dns_rounded),
              _ => (const Color(0xFFEEF0F3), const Color(0xFF344054), Icons.wifi_off_rounded),
            };
            final who = serverName(NetMonitor.i.worst.$2);
            final (title, body) = switch (k) {
              'slow' => ('Slow network – still waiting for the server', 'Do not press again – it goes on by itself.'),
              'reconnect' => ('No answer – trying again', 'What you see was read before; it updates when the answer comes.'),
              'server' => ('The $who is not answering', 'Your internet works. The app asks again by itself.'),
              _ => ('No internet', 'Mobile data is off or has no signal. The app asks again by itself.'),
            };
            line = Container(
              key: Key('net-line-$k'),
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.fromLTRB(13, 10, 4, 10),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: k == 'reconnect'
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg, backgroundColor: fg.withValues(alpha: .25)))
                      : Icon(icon, size: 18, color: fg),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () => showNetSheet(context),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(title, style: TextStyle(fontFamily: font, fontSize: 13.5, fontWeight: FontWeight.w700, color: fg, height: 1.3)),
                      Text(body, style: TextStyle(fontFamily: font, fontSize: 13, color: fg, height: 1.35)),
                    ]),
                  ),
                ),
                IconButton(
                  key: const Key('net-line-close'),
                  tooltip: 'Hide',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.close_rounded, color: fg, size: 18),
                  onPressed: () => setState(() => _closed = k),
                ),
              ]),
            );
          }
          return AnimatedSize(duration: const Duration(milliseconds: 220), curve: Curves.easeOut, alignment: Alignment.topCenter, child: line);
        },
      );
}

/// The monitor's rhythm while the app is in front: every 5 s (the 2 minutes move on; idle for 30 s → one small request); nothing in
/// the background.
class NetHost extends StatefulWidget {
  const NetHost({super.key, required this.child});
  final Widget child;
  @override
  State<NetHost> createState() => _NetHostState();
}

class _NetHostState extends State<NetHost> with WidgetsBindingObserver {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _t?.cancel();
    super.dispose();
  }

  void _start() {
    if (!NetMonitor.i.on) return;
    _t?.cancel();
    _t = Timer.periodic(const Duration(seconds: 5), (_) => NetMonitor.i.tick());
    NetMonitor.i.tick();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _start();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _t?.cancel();
      _t = null;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
