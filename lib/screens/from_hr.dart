// FALCON opened from RCL's HR app (23-11-2026, his decision: "falcon la erp madhe nahi hr madhe jodaych … falcon hr madhe asel";
// picture N8 approved: "ho banaw"). The HR / ERP app opens falcon://app/hr?p=<HR's pass> – only this app's package can take it.
// The pass is checked by FALCON's server (signed by HR, 2 minutes, once) and he is in: no company code, no WhatsApp code; this
// phone counts as proven. What HR said for today (his first punch-in) is kept for the home's "Present since" line.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/db.dart';
import '../core/fmt.dart';
import '../core/prefs.dart';
import '../core/session.dart';
import '../embed.dart';
import '../ui/kit.dart';

final passShape = RegExp(r'^v1\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]{43}$');

class FromHr extends StatefulWidget {
  const FromHr({super.key, required this.pass});
  final String pass;
  @override
  State<FromHr> createState() => _FromHrState();
}

class _FromHrState extends State<FromHr> {
  String err = '';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _go());
  }

  Future<void> _go() async {
    if (!passShape.hasMatch(widget.pass)) {
      setState(() => err = 'This link is not from HR – open Mess from the HR app again.');
      return;
    }
    try {
      final r = await api('/api/hr', {'pass': widget.pass, 'device_hash': await deviceHash()}, withToken: false);
      final ses = r['session'];
      if (ses is! Map || '${ses['refresh_token'] ?? ''}'.isEmpty) throw DbError('FALCON could not sign you in – try again.', 'session');
      await sb.auth.setSession('${ses['refresh_token']}');
      final hr = r['hr'] is Map ? r['hr'] as Map : const {};
      Prefs.hr = jsonEncode({'day': '${hr['day'] ?? today()}', 'in': hr['in'], 'banner': true});
      if (!mounted) return;
      await SessionScope.read(context).load();
      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) setState(() => err = words(e));
    }
  }

  @override
  Widget build(BuildContext context) => Screen(children: [
        const SizedBox(height: 60),
        const Center(child: Logo(size: 96)),
        if (err.isEmpty)
          const Loading(what: 'Opening FALCON from HR')
        else ...[
          Failed(err),
          if (falconEmbedded && falconLeave != null)
            Btn('Back to RCL app', kind: BtnKind.ghost, onTap: falconLeave!)
          else
            Btn('Use FALCON\'s own sign-in', kind: BtnKind.ghost, onTap: () => context.go('/start')),
        ],
      ]);
}

/// What HR said for today: {day, in, banner} – null on another day.
Map<String, dynamic>? hrToday() {
  try {
    final v = jsonDecode(Prefs.hr ?? 'null');
    if (v is Map && v['day'] == today()) return Map<String, dynamic>.from(v);
  } catch (_) {}
  return null;
}

void closeHrBanner() {
  final v = hrToday();
  if (v == null) return;
  v['banner'] = false;
  Prefs.hr = jsonEncode(v);
}

/// Inside RCL's ERP / HR app, signed out of FALCON (his sign-in there ended): Mess is opened again from that app – FALCON's own
/// sign-up pages are for the FALCON app and its web.
class HrAgain extends StatelessWidget {
  const HrAgain({super.key});
  @override
  Widget build(BuildContext context) => Screen(children: [
        const SizedBox(height: 60),
        const Center(child: Logo(size: 96)),
        const Failed('Your FALCON sign-in has ended – open Mess again from the HR / ERP app.'),
        if (falconLeave != null) Btn('Back to RCL app', kind: BtnKind.ghost, onTap: falconLeave!),
      ]);
}
