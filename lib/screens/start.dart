// Boards r01–r08 (first time: who are you, RCL ID, found in HR, the WhatsApp code, done / not found / new registration /
// temporary), the guest's first registration, signing in again with the mobile, a code again, "where you stand" and choosing –
// the app's own screens on the same server steps as the web (src/screens/start.tsx).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config.dart';
import '../core/db.dart';
import '../core/fmt.dart';
import '../core/session.dart';
import '../ui/kit.dart';
import '../ui/look.dart';

/// What the steps carry from one board to the next (this run of the app only).
class Flow {
  static String? mode; // rcl | new | guest | back
  static String? rcl, token, result, phone, site, section, sentTo;
  static Rec hr = {};
  static Map<String, String> form = {};
  static File? photo;
  static void clear() { mode = rcl = token = result = phone = site = section = sentTo = null; hr = {}; form = {}; photo = null; }
}

const _whatsappCode = 'Wait a minute before asking a new code.';

Future<Rec?> _places() async {
  final r = await call<dynamic>('start_places', {'p_company': Config.company});
  return r is Map ? Map<String, dynamic>.from(r) : null;
}

List<Rec> _sitesOf(Rec? p) => ((p?['sites'] as List?) ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
List<Rec> _sectionsOf(Rec? site) => ((site?['sections'] as List?) ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();

/// Choose one of a few in a sheet (the web's <select>).
Future<String?> choose(BuildContext context, String title, List<(String, String)> options) {
  return sheet<String>(context, (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
        Text(title, style: T.h2),
        const SizedBox(height: 10),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.55),
          child: ListView(shrinkWrap: true, children: [
            for (final o in options)
              ListTile(contentPadding: EdgeInsets.zero, title: Text(o.$2, style: T.body), trailing: const Ico('chevron-right', size: 18), onTap: () => Navigator.pop(ctx, o.$1)),
          ]),
        ),
      ]));
}

/// A field that opens a choice (looks like the design's input).
class PickField extends StatelessWidget {
  const PickField({super.key, required this.label, required this.value, required this.onTap, this.hint = 'Choose'});
  final String label;
  final String? value;
  final String hint;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Field(label, Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: C.line2)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(height: 48, padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
            Expanded(child: Text(value ?? hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: font, fontSize: 15, color: value == null ? C.faint : C.ink))),
            const Ico('chevron-down', size: 18, color: C.muted),
          ])),
        ),
      ));
}

Widget _foot(List<Widget> children) => Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: C.line))),
      child: SafeArea(top: false, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]]])),
    );

// ── r01 · First time – who are you? ──
class Who extends StatelessWidget {
  const Who({super.key, this.error});
  final String? error;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.cream,
      body: ListView(padding: EdgeInsets.zero, children: [
        Container(
          padding: EdgeInsets.fromLTRB(24, 40 + MediaQuery.of(context).padding.top, 24, 34),
          decoration: const BoxDecoration(color: C.navy, borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Logo(size: 64),
            SizedBox(height: 18),
            Text('Welcome to\nFALCON', style: TextStyle(fontFamily: font, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.75, height: 1.1, color: Colors.white)),
            SizedBox(height: 10),
            Text('Food & Site Operations', style: TextStyle(fontFamily: font, fontSize: 15, color: Color(0xFFC9D2E0))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 26),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (error != null) ...[Failed(error!), const SizedBox(height: 14)],
            Text('First time here – who are you?', style: T.h2.copyWith(fontSize: 19)),
            const SizedBox(height: 14),
            _BigChoice(icon: 'hard-hat', tone: Tone.leaf, title: 'I work for RCL', sub: 'Staff, operator, driver, labour – with or without an RCL ID',
                onTap: () { Flow.clear(); context.push('/start/rcl-id'); }),
            const SizedBox(height: 14),
            _BigChoice(icon: 'user-plus', tone: Tone.plum, title: 'I am a guest or visitor', sub: 'Client, officer, subcontractor, vendor, visitor',
                onTap: () { Flow.clear(); context.push('/guest/new'); }),
            const SizedBox(height: 14),
            FCard(radius: 16, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
              const Ico('shield-check', size: 18, color: C.muted), const SizedBox(width: 10),
              Expanded(child: Text('Asked once. After this the app knows you – your mobile is checked by a WhatsApp code.', style: T.sm)),
            ])),
            const SizedBox(height: 40),
            TextButton(onPressed: () { Flow.clear(); context.push('/start/back'); },
                child: Text('Been here before? Your mobile number brings you back.', textAlign: TextAlign.center, style: T.xs)),
          ]),
        ),
      ]),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.icon, required this.tone, required this.title, required this.sub, required this.onTap});
  final String icon, title, sub;
  final Tone tone;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => FCard(
        lift: true, onTap: onTap, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(children: [
          Tile(icon, tone: tone, size: 56),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: T.b.copyWith(fontSize: 18)), const SizedBox(height: 2), Text(sub, style: T.sm),
          ])),
          const Ico('chevron-right'),
        ]),
      );
}

// ── r02 · Your RCL ID ──
class RclId extends StatefulWidget {
  const RclId({super.key});
  @override
  State<RclId> createState() => _RclIdState();
}

class _RclIdState extends State<RclId> with Act {
  final id = TextEditingController(text: Flow.rcl ?? '');
  @override
  void dispose() { id.dispose(); super.dispose(); }
  Future<void> find() => act(() async {
        final rcl = id.text.trim().toUpperCase();
        if (!RegExp(r'^[A-Z0-9-]{2,20}$').hasMatch(rcl)) throw DbError('Type the ID as on your card – letters, numbers and "-".');
        final r = await api('/api/start', {'rcl_id': rcl}, withToken: false);
        Flow.mode = 'rcl'; Flow.rcl = rcl; Flow.result = '${r['result']}'; Flow.token = r['token'] as String?; Flow.hr = r;
        if (!mounted) return;
        context.push(r['result'] == 'found' ? '/start/found' : '/start/not-found');
      });
  @override
  Widget build(BuildContext context) => Screen(
        top: const Top(title: 'Your RCL ID', sub: 'Step 1 of 3 · RCL employee', back: '/start'),
        children: [
          const Steps(1, 3),
          Text('Enter your employee ID', style: T.h1.copyWith(fontSize: 26)),
          Text('It is on your ID card and salary slip.', style: T.sm),
          Input(controller: id, big: true, icon: 'id-card', hint: 'VTR-0000', maxLength: 20, autofocus: true, caps: TextCapitalization.characters, onChanged: (_) => setState(() {})),
          const InfoLine('Looked up in the RCL HR employee list – nothing else is asked if it is there.'),
          ErrorLine(error),
          Btn('Find me', icon: 'search', kind: BtnKind.leaf, busy: busy, onTap: id.text.trim().isEmpty ? null : find),
          FCard(
            padding: const EdgeInsets.all(14),
            onTap: () { Flow.mode = 'new'; Flow.rcl = id.text.trim().isEmpty ? null : id.text.trim().toUpperCase(); context.push('/start/new'); },
            child: Row(children: [
              const Tile('user-plus', tone: Tone.cream, size: 40), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('No RCL ID yet?', style: T.b), Text('New joiner or HR has not added you – register here', style: T.xs),
              ])),
              const Ico('chevron-right', size: 18),
            ]),
          ),
        ],
      );
}

// ── r03 · Is this you? (from RCL HR) ──
class Found extends StatefulWidget {
  const Found({super.key});
  @override
  State<Found> createState() => _FoundState();
}

class _FoundState extends State<Found> with Act {
  String? section = Flow.section;
  Rec? places;
  @override
  void initState() {
    super.initState();
    _places().then((p) { if (mounted) setState(() => places = p); }).catchError((_) {});
  }
  Rec? get site {
    final code = '${Flow.hr['site'] ?? ''}'.toUpperCase();
    return _sitesOf(places).where((s) => s['code'] == code || s['name'] == Flow.hr['site']).firstOrNull;
  }
  Future<void> send() => act(() async {
        final r = await api('/api/start', {'token': Flow.token, 'send': true}, withToken: false);
        Flow.site = site?['id'] as String?; Flow.section = section; Flow.sentTo = r['sent_to'] as String?;
        if (mounted) context.push('/start/code');
      });
  @override
  Widget build(BuildContext context) {
    if (Flow.token == null || Flow.hr.isEmpty) return const Gone();
    final hr = Flow.hr, st = site, secs = _sectionsOf(st);
    final secName = secs.where((x) => x['id'] == section).map((x) => '${x['circle']} · ${x['code']}').firstOrNull;
    Widget row(String k, String? v, {bool last = false}) => Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(border: last ? null : const Border(bottom: BorderSide(color: C.line))),
          child: Row(children: [Expanded(child: Text(k, style: T.sm)), Text(v == null || v.isEmpty ? '–' : v, style: T.b.copyWith(fontSize: 14)), const SizedBox(width: 8), const Ico('lock', size: 14, color: C.muted)]),
        );
    return Screen(
      top: const Top(title: 'Is this you?', sub: 'Step 2 of 3 · from RCL HR', back: '/start/rcl-id'),
      foot: _foot([Btn('Yes – send code on WhatsApp', icon: 'message-circle', kind: BtnKind.whatsapp, busy: busy, onTap: send)]),
      children: [
        const Steps(2, 3),
        FCard(child: Row(children: [
          Av(initials('${hr['name']}'), size: 56),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('${hr['name']}', style: T.b.copyWith(fontSize: 19)), Text('RCL ID ${Flow.rcl}', style: T.sm)])),
          const Chip2('Found', icon: 'badge-check', tone: Tone.leaf, height: 26),
        ])),
        FCard(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4), child: Column(children: [
          row('Designation', hr['designation'] as String?),
          row('Department', hr['department'] as String?),
          row('Category', hr['category'] as String?),
          row('Site', st != null ? '${st['code']} · ${st['name']}' : hr['site'] as String?),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
            child: Row(children: [
              Expanded(child: Text('Circle · section', style: T.sm)),
              if (secs.isNotEmpty)
                Chip2(secName ?? 'Pick', tone: Tone.leaf, onTap: () async {
                  final v = await choose(context, 'Your circle and section', [for (final x in secs) ('${x['id']}', '${x['circle']} · ${x['code']} – ${x['name']}')]);
                  if (v != null) setState(() => section = v);
                })
              else
                const Chip2('Not in HR', tone: Tone.amber, height: 26),
            ]),
          ),
          row('WhatsApp', hr['mobile_masked'] as String?, last: true),
        ])),
        const InfoLine('Locked details come from HR. Your pick of circle is checked by the Site Admin.'),
        const InfoLine('Something wrong? Tell HR – they correct it', icon: 'message-circle'),
        ErrorLine(error),
      ],
    );
  }
}

// ── r04 · Enter the code ──
class Code extends StatefulWidget {
  const Code({super.key});
  @override
  State<Code> createState() => _CodeState();
}

class _CodeState extends State<Code> with Act {
  int wait = 60;
  bool _ticking = true;
  @override
  void initState() {
    super.initState();
    _tick();
  }
  Future<void> _tick() async {
    while (_ticking && mounted && wait > 0) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => wait--);
    }
  }
  @override
  void dispose() { _ticking = false; super.dispose(); }

  Future<void> verify(String c) => act(() async {
        final s = SessionScope.read(context);
        if (Flow.mode == 'rcl') {
          final r = await api('/api/start', {'token': Flow.token, 'code': c}, withToken: false);
          final ses = Map<String, dynamic>.from(r['session'] as Map);
          await sb.auth.setSession('${ses['refresh_token']}');
        } else {
          final r = await sb.auth.verifyOTP(phone: Flow.phone!, token: c, type: OtpType.sms);
          if (r.session == null) throw DbError('This code is not right or has expired.');
        }
        final uid = sb.auth.currentUser!.id;
        // who is this? – already in FALCON, made by the office, an active HR employee (by his mobile), or the first System Admin
        Rec w;
        try { w = await api('/api/welcome', {}); } catch (_) { w = {}; }
        if (w['person'] != null) { await s.refresh(); if (mounted) context.go('/'); return; }
        if (Flow.mode == 'back') {
          await sb.auth.signOut();
          throw DbError('This mobile is not in FALCON or in HR yet – go back and register.');
        }
        final exists = await one(sb.from('people').select('id').eq('auth_user_id', uid).limit(1));
        if (exists == null) {
          String? photo;
          if (Flow.photo != null) {
            final p = await _places();
            final path = '${p!['company']}/$uid/photo-${DateTime.now().millisecondsSinceEpoch}.jpg';
            try {
              await sb.storage.from('registration-photos').upload(path, Flow.photo!, fileOptions: const FileOptions(contentType: 'image/jpeg'));
              photo = path;
            } catch (_) {/* registered without the photo */}
          }
          final f = Flow.form;
          await api('/api/register', Flow.mode == 'guest'
              ? {'kind': 'guest', 'full_name': f['name'], 'organisation': f['organisation'], 'designation': f['designation']}
              : {'kind': 'employee', 'full_name': Flow.mode == 'rcl' ? Flow.hr['name'] : f['name'], 'rcl_id': Flow.rcl, 'site': Flow.site, 'section': Flow.section,
                 'category': f['category'], 'work_role': f['work_role'], 'works_with': f['works_with'], 'photo': photo});
        }
        await s.refresh();
        if (mounted) context.go(Flow.mode == 'guest' ? '/guest/welcome' : '/start/done');
      });

  Future<void> again() => act(() async {
        if (Flow.mode == 'rcl') {
          await api('/api/start', {'token': Flow.token, 'send': true}, withToken: false);
        } else {
          try { await sb.auth.signInWithOtp(phone: Flow.phone!); } catch (_) { throw DbError(_whatsappCode); }
        }
        setState(() => wait = 60);
        _tick();
      });

  @override
  Widget build(BuildContext context) {
    final sentTo = Flow.mode == 'rcl' ? (Flow.sentTo ?? '') : maskMobile(Flow.phone);
    return Screen(
      top: Top(title: 'Enter the code', sub: Flow.mode == 'rcl' ? 'Step 3 of 3 · WhatsApp' : 'WhatsApp', back: ''),
      children: [
        if (Flow.mode == 'rcl') const Steps(3, 3, last: C.whatsapp),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: const Color(0xFFF1F9F4), borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            const Tile('message-circle', tone: Tone(C.whatsapp, Colors.white), size: 40), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Sent to $sentTo', style: T.b), Text('From Sketchline Industries on WhatsApp', style: T.xs),
            ])),
          ]),
        ),
        CodeBoxes(onDone: (c) => verify(c)),
        Row(children: [
          Expanded(child: Text(busy ? 'Checking…' : 'Checked as soon as the 6th digit is in', style: T.sm)),
          if (wait > 0) Text('Send again 0:${wait.toString().padLeft(2, '0')}', style: T.sm) else Chip2('Send again', onTap: again),
        ]),
        ErrorLine(error),
        FCard(padding: const EdgeInsets.all(14), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Ico('info', size: 18, color: C.muted), const SizedBox(width: 12),
          Expanded(child: Text('The code proves the phone is yours. That you work for RCL is proved by HR\'s record – both are kept apart.', style: T.sm.copyWith(height: 1.45))),
        ])),
        const InfoLine('Not your number any more? HR changes it', icon: 'phone'),
      ],
    );
  }
}

// ── r05 · Registered – verified employee (or where it waits) ──
class Done extends StatelessWidget {
  const Done({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (s.status != Status.ready && s.status != Status.stopped) return const Screen(children: [Loading()]);
    if (!['verified', 'linked', 'id_assigned'].contains(s.state)) return const Waiting();
    return Screen(
      padding: const EdgeInsets.fromLTRB(20, 70, 20, 26),
      children: [
        Center(child: Container(width: 132, height: 132, decoration: const BoxDecoration(color: C.leafS, shape: BoxShape.circle), alignment: Alignment.center,
            child: Container(width: 96, height: 96, decoration: const BoxDecoration(color: C.leaf, shape: BoxShape.circle), alignment: Alignment.center,
                child: const Ico('check', size: 52, color: Colors.white)))),
        Text('You\'re in, ${firstName(s.name)}', textAlign: TextAlign.center, style: T.h1),
        Text('FALCON knows you from now on – no sign-up again.', textAlign: TextAlign.center, style: T.sm),
        Center(child: Wrap2([
          const Chip2('WhatsApp verified', icon: 'message-circle', tone: Tone.leaf),
          const Chip2('Verified employee', icon: 'badge-check', tone: Tone.leaf),
          if (s.me?['rcl_id'] != null) Chip2('Linked to HR · ${s.me!['rcl_id']}'),
        ])),
        FCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('You can now', style: T.b),
          const SizedBox(height: 10),
          const _Can('utensils', 'Take meals at your site\'s mess'),
          const _Can('package', 'Ask for parcels to your section'),
          if (s.me?['home_section_id'] == null) const _Can('clock-alert', 'Your circle and section wait for the Site Admin\'s OK'),
        ])),
        const SizedBox(height: 20),
        Btn('Open FALCON', kind: BtnKind.leaf, onTap: () => context.go('/')),
      ],
    );
  }
}

class _Can extends StatelessWidget {
  const _Can(this.icon, this.text);
  final String icon, text;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
        Ico(icon, size: 16, color: C.muted), const SizedBox(width: 10), Expanded(child: Text(text, style: T.sm)),
      ]));
}

// ── r06 · Employee record not found ──
class NotFound extends StatelessWidget {
  const NotFound({super.key});
  @override
  Widget build(BuildContext context) {
    final notChecked = Flow.result == 'not_checked' || Flow.result == 'no_mobile';
    final id = Flow.rcl ?? 'this ID';
    return Screen(
      top: Top(title: notChecked ? 'HR could not be checked' : 'Not found in HR', sub: 'RCL ID ${Flow.rcl ?? ''}', back: '/start/rcl-id'),
      children: [
        const Align(alignment: Alignment.centerLeft, child: Tile('search', tone: Tone.amber, size: 56)),
        Text(notChecked ? 'HR could not check $id now' : 'We could not find $id', style: T.h1.copyWith(fontSize: 25)),
        Text(notChecked
            ? (Flow.result == 'no_mobile' ? 'HR has no WhatsApp number for you. Register here – the Site Admin checks you.' : 'HR\'s list has not come to FALCON yet. Register here – the Site Admin checks you.')
            : 'This happens when you joined recently, HR has not added you yet, or the ID is typed wrong.', style: T.sm.copyWith(height: 1.5)),
        const FCard(child: Column(children: [
          _Can('check', 'You can still register and eat today'),
          _Can('check', 'The Site Admin and HR are told about you'),
          _Can('check', 'When HR adds you, all your meals move to your record'),
          _Can('x', 'No RCL ID is made up for you'),
        ])),
        const SizedBox(height: 10),
        Btn('Check the ID again', icon: 'pencil', kind: BtnKind.ghost, onTap: () => context.go('/start/rcl-id')),
        Btn('Continue with new registration', icon: 'arrow-right', kind: BtnKind.leaf, onTap: () => context.push('/start/new')),
      ],
    );
  }
}

// ── r07 · New registration ──
const _cats = [('staff', 'Staff'), ('operator', 'Operator'), ('driver', 'Driver'), ('labour', 'Labour')];

class NewReg extends StatefulWidget {
  const NewReg({super.key});
  @override
  State<NewReg> createState() => _NewRegState();
}

class _NewRegState extends State<NewReg> with Act {
  final name = TextEditingController(), mobile = TextEditingController(), work = TextEditingController(), worksWith = TextEditingController();
  late final rcl = TextEditingController(text: Flow.rcl ?? '');
  String category = 'labour';
  String? site = Flow.site, section = Flow.section;
  File? photo = Flow.photo;
  Rec? places;
  String? placesError;
  @override
  void initState() {
    super.initState();
    _places().then((p) { if (mounted) setState(() => places = p); }).catchError((Object e) { if (mounted) setState(() => placesError = words(e)); });
  }
  @override
  void dispose() { for (final c in [name, mobile, work, worksWith, rcl]) { c.dispose(); } super.dispose(); }
  Rec? get st => _sitesOf(places).where((x) => x['id'] == site).firstOrNull;

  Future<void> send() => act(() async {
        if (name.text.trim().length < 2) throw DbError('Write your full name.');
        final phone = phoneE164(mobile.text);
        if (phone == null) throw DbError('Type your 10-digit WhatsApp mobile.');
        if (site == null) throw DbError('Choose your site.');
        try { await sb.auth.signInWithOtp(phone: phone); } on AuthException catch (e) { throw DbError(e.statusCode == '429' ? _whatsappCode : 'The code could not be sent – check the number.'); }
        Flow.mode = 'new'; Flow.phone = phone; Flow.site = site; Flow.section = section; Flow.photo = photo;
        Flow.rcl = rcl.text.trim().isEmpty ? null : rcl.text.trim().toUpperCase();
        Flow.form = {'name': name.text.trim(), 'work_role': work.text.trim(), 'category': category, 'works_with': worksWith.text.trim()};
        if (mounted) context.push('/start/code');
      });

  Future<void> takePhoto() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front, maxWidth: 900, imageQuality: 80);
    if (x != null && mounted) setState(() => photo = File(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final sites = _sitesOf(places), here = st, secs = _sectionsOf(here);
    return Screen(
      top: Top(title: 'New registration', sub: 'For people not yet in HR${here != null ? ' · ${here['code']}' : ''}', back: ''),
      foot: _foot([
        const InfoLine('A WhatsApp code checks your mobile. HR checks the rest.', icon: 'shield-check'),
        Btn('Send code and register', icon: 'message-circle', kind: BtnKind.whatsapp, busy: busy, onTap: send),
      ]),
      children: [
        if (placesError != null) Failed(placesError!),
        Field('Full name', Input(controller: name, hint: 'As on your ID', caps: TextCapitalization.words)),
        Field('WhatsApp mobile', Input(controller: mobile, hint: '10 digits', keyboard: TextInputType.phone, maxLength: 14, icon: 'phone')),
        Row(children: [
          Expanded(child: Field('Work role', Input(controller: work, hint: 'e.g. Welder'))),
          const SizedBox(width: 10),
          Expanded(child: Field('RCL ID, if given', Input(controller: rcl, hint: 'optional', caps: TextCapitalization.characters))),
        ]),
        Field('Category', Wrap2([for (final c in _cats) Chip2(c.$2, tone: category == c.$1 ? Tone.on : Tone.plain, onTap: () => setState(() => category = c.$1))], gap: 6)),
        Row(children: [
          Expanded(child: PickField(label: 'Site', value: here?['code'] as String?, onTap: () async {
            final v = await choose(context, 'Your site', [for (final x in sites) ('${x['id']}', '${x['code']} · ${x['name']}')]);
            if (v != null) setState(() { site = v; section = null; });
          })),
          const SizedBox(width: 10),
          Expanded(child: PickField(label: 'Circle · section', value: secs.where((x) => x['id'] == section).map((x) => '${x['circle']} · ${x['code']}').firstOrNull,
              onTap: secs.isEmpty ? null : () async {
                final v = await choose(context, 'Your circle and section', [for (final x in secs) ('${x['id']}', '${x['circle']} · ${x['code']} – ${x['name']}')]);
                if (v != null) setState(() => section = v);
              })),
        ]),
        Field('Contractor / subcontractor (if not on RCL\'s roll)', Input(controller: worksWith, hint: 'optional')),
        InkWell(
          onTap: takePhoto,
          child: Row(children: [
            Container(width: 56, height: 56, clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: C.line2, width: 1.5)),
                child: photo != null ? Image.file(photo!, fit: BoxFit.cover) : const Center(child: Ico('camera', color: C.muted))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your photo', style: T.b.copyWith(fontSize: 14)), Text('Asked by the site\'s rule', style: T.xs)])),
          ]),
        ),
        ErrorLine(error),
      ],
    );
  }
}

// ── r08 · Temporary – waiting for the check ──
class Waiting extends StatefulWidget {
  const Waiting({super.key});
  @override
  State<Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<Waiting> with Act {
  final answer = TextEditingController();
  @override
  void dispose() { answer.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    if (s.me == null) return const Screen(children: [Loading()]);
    final temp = s.state == 'temporary';
    return Load<Rec?>(
      watch: const ['registrations'],
      load: () => one(sb.from('registrations').select('id,code,typed_rcl_id,hr_result,info_asked,info_answer,created_at').order('created_at', ascending: false).limit(1)),
      loading: const Screen(children: [Loading()]),
      builder: (context, r, reload) => Screen(
        top: Top(left: Av(initials(s.name), tone: Tone.sf), title: s.name, sub: '${r?['code'] ?? 'Registration'}${temp ? ' · temporary' : ' · waiting'}'),
        children: [
          FCard(color: C.amberS, border: const Color(0xFFEFD7A6), child: Row(children: [
            const Ico('clock-alert', size: 24, color: C.amber), const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Waiting for the Site Admin', style: T.b),
              Text(temp ? 'Limited use till ${day(s.me?['temporary_until'] as String?)}' : 'Nothing can be ordered until he checks you', style: T.xs.copyWith(color: const Color(0xFF6B4A0A))),
            ])),
          ])),
          FCard(padding: const EdgeInsets.fromLTRB(14, 16, 14, 2), child: Timeline([
            TlStep('WhatsApp verified', state: 'done', sub: '${r != null ? '${day(r['created_at'] as String?)} ${time(r['created_at'] as String?)}' : ''} · ${maskMobile(s.me?['mobile'] as String?)}'),
            TlStep(r?['hr_result'] == 'not_found' ? 'Not found in HR – new registration' : 'New registration', state: 'done',
                sub: '${r?['typed_rcl_id'] != null ? '${r!['typed_rcl_id']} typed · ' : ''}Site Admin and HR told'),
            const TlStep('Site Admin checks you', state: 'now', icon: 'user-check', sub: 'Is he working here? Which section?'),
            const TlStep('HR adds you or links you', sub: 'Your meals here move to that record'),
          ])),
          if (r?['info_asked'] != null && r?['info_answer'] == null)
            FCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('The Site Admin asks: ${r!['info_asked']}', style: T.b.copyWith(fontSize: 14)),
              const SizedBox(height: 8),
              Input(controller: answer, hint: 'Your answer'),
              const SizedBox(height: 8),
              ErrorLine(error),
              Btn('Send', kind: BtnKind.leaf, small: true, busy: busy, onTap: () => act(() async { await call('answer_registration', {'p_reg': r['id'], 'p_answer': answer.text}); reload(); })),
            ])),
          IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: FCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('You can', style: T.b.copyWith(fontSize: 14, color: C.leafD)), const SizedBox(height: 6),
              Text(temp ? 'Meals at your own site\'s mess, for yourself' : 'Wait for the check', style: T.xs.copyWith(height: 1.6)),
            ]))),
            const SizedBox(width: 10),
            Expanded(child: FCard(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Not yet', style: T.b.copyWith(fontSize: 14, color: C.redD)), const SizedBox(height: 6),
              Text('Parcels, delivery, group or guest requests, other sites', style: T.xs.copyWith(height: 1.6)),
            ]))),
          ])),
          const SizedBox(height: 10),
          if (temp) Btn('Open FALCON', kind: BtnKind.leaf, onTap: () => context.go('/app'))
          else Btn('Check again', icon: 'refresh-cw', kind: BtnKind.ghost, onTap: () => s.refresh()),
          Btn('Sign out', kind: BtnKind.ghost, onTap: () => s.signOut()),
        ],
      ),
    );
  }
}

// ── a guest's first time (r07's form for a guest) ──
class GuestNew extends StatefulWidget {
  const GuestNew({super.key});
  @override
  State<GuestNew> createState() => _GuestNewState();
}

class _GuestNewState extends State<GuestNew> with Act {
  final name = TextEditingController(), mobile = TextEditingController(), org = TextEditingController(), work = TextEditingController();
  @override
  void dispose() { for (final c in [name, mobile, org, work]) { c.dispose(); } super.dispose(); }
  Future<void> send() => act(() async {
        if (name.text.trim().length < 2) throw DbError('Write your full name.');
        final phone = phoneE164(mobile.text);
        if (phone == null) throw DbError('Type your 10-digit WhatsApp mobile.');
        try { await sb.auth.signInWithOtp(phone: phone); } on AuthException catch (e) { throw DbError(e.statusCode == '429' ? _whatsappCode : 'The code could not be sent – check the number.'); }
        Flow.mode = 'guest'; Flow.phone = phone;
        Flow.form = {'name': name.text.trim(), 'organisation': org.text.trim(), 'designation': work.text.trim()};
        if (mounted) context.push('/start/code');
      });
  @override
  Widget build(BuildContext context) => Screen(
        top: const Top(title: 'Guest or visitor', sub: 'Once – after this the app knows you', back: '/start'),
        foot: _foot([Btn('Send code on WhatsApp', icon: 'message-circle', kind: BtnKind.whatsapp, busy: busy, onTap: send)]),
        children: [
          Field('Full name', Input(controller: name, hint: 'Your name', caps: TextCapitalization.words)),
          Field('WhatsApp mobile', Input(controller: mobile, hint: '10 digits', keyboard: TextInputType.phone, maxLength: 14, icon: 'phone')),
          Field('Company / organisation', Input(controller: org, hint: 'optional')),
          Field('Your work', Input(controller: work, hint: 'e.g. quality auditor')),
          FCard(radius: 16, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), child: Row(children: [
            const Ico('shield-check', size: 18, color: C.muted), const SizedBox(width: 10),
            Expanded(child: Text('One profile for every visit. You see only your own visits and orders.', style: T.sm)),
          ])),
          ErrorLine(error),
        ],
      );
}

// ── coming back (or the first time, for an RCL employee who is in HR): the mobile and a code ──
class Back extends StatefulWidget {
  const Back({super.key});
  @override
  State<Back> createState() => _BackState();
}

class _BackState extends State<Back> with Act {
  final mobile = TextEditingController();
  @override
  void dispose() { mobile.dispose(); super.dispose(); }
  Future<void> send() => act(() async {
        final phone = phoneE164(mobile.text);
        if (phone == null) throw DbError('Type your 10-digit WhatsApp mobile.');
        try { await sb.auth.signInWithOtp(phone: phone, shouldCreateUser: true); } on AuthException catch (e) { throw DbError(e.statusCode == '429' ? _whatsappCode : 'The code could not be sent – try again.'); }
        Flow.mode = 'back'; Flow.phone = phone;
        if (mounted) context.push('/start/code');
      });
  @override
  Widget build(BuildContext context) => Screen(
        top: const Top(title: 'Welcome back', sub: 'Your mobile brings you back', back: '/start'),
        children: [
          Text('Your WhatsApp mobile', style: T.h1.copyWith(fontSize: 26)),
          Input(controller: mobile, big: true, icon: 'phone', hint: '10 digits', keyboard: TextInputType.phone, maxLength: 14, autofocus: true),
          ErrorLine(error),
          Btn('Send code on WhatsApp', icon: 'message-circle', kind: BtnKind.whatsapp, busy: busy, onTap: send),
          const InfoLine('Working for RCL? Your mobile in HR is enough – the code comes on WhatsApp.'),
        ],
      );
}

// A code again (a new phone, or 30 days since the last one) – the session alone is not proof of who holds the phone.
class CodeAgain extends StatefulWidget {
  const CodeAgain({super.key});
  @override
  State<CodeAgain> createState() => _CodeAgainState();
}

class _CodeAgainState extends State<CodeAgain> with Act {
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Screen(
      top: const Top(title: 'Is this you?', sub: 'A new phone, or a month since your last code'),
      children: [
        FCard(child: Row(children: [
          Av(initials(s.name), size: 56, tone: Tone.plum), const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(s.name, style: T.b.copyWith(fontSize: 18)), Text(maskMobile(s.me?['mobile'] as String?), style: T.sm)])),
        ])),
        const InfoLine('This phone only suggests who you are. A WhatsApp code proves it.', icon: 'shield-check'),
        ErrorLine(error),
        Btn('Send code on WhatsApp', icon: 'message-circle', kind: BtnKind.whatsapp, busy: busy, onTap: () => act(() async {
          final ph = sb.auth.currentUser?.phone;
          final phone = ph != null && ph.isNotEmpty ? '+${ph.replaceFirst('+', '')}' : s.me?['mobile'] as String?;
          if (phone == null) throw DbError('No mobile on this sign-in.');
          await s.signOut();
          try { await sb.auth.signInWithOtp(phone: phone, shouldCreateUser: false); } catch (_) { throw DbError(_whatsappCode); }
          Flow.mode = 'back'; Flow.phone = phone;
          if (context.mounted) context.go('/start/code');
        })),
        Btn('Not me', kind: BtnKind.ghost, onTap: () => s.signOut()),
      ],
    );
  }
}

// Where he stands when he may not go on: rejected, suspended, temporary access over.
class Stopped extends StatelessWidget {
  const Stopped({super.key});
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    final why = s.state == 'rejected' ? 'Your registration was not accepted' : s.state == 'suspended' ? 'Your FALCON access is stopped' : 'Your temporary access has ended';
    return Screen(padding: const EdgeInsets.fromLTRB(20, 60, 20, 26), children: [
      const Align(alignment: Alignment.centerLeft, child: Tile('lock', tone: Tone.redTile, size: 56)),
      Text(why, style: T.h1.copyWith(fontSize: 25)),
      if (s.me?['state_reason'] != null) FCard(child: Text('Reason: ${s.me!['state_reason']}', style: T.sm)),
      Text('Speak to your Site Admin. When he changes it, open FALCON again.', style: T.sm),
      Btn('Check again', icon: 'refresh-cw', kind: BtnKind.ghost, onTap: () => s.refresh()),
      Btn('Sign out', kind: BtnKind.ghost, onTap: () => s.signOut()),
    ]);
  }
}

// When a step was opened without the one before it.
class Gone extends StatelessWidget {
  const Gone({super.key});
  @override
  Widget build(BuildContext context) => Screen(top: const Top(title: 'Start again', back: '/start'), children: [
        const Failed('This step has expired – start again.'),
        Btn('Start', kind: BtnKind.leaf, onTap: () => context.go('/start')),
      ]);
}

// More than one part of FALCON: he chooses (his roles decide what is listed). The office's pages open on the web.
class Choose extends StatelessWidget {
  const Choose({super.key, required this.items});
  final List<Home> items;
  @override
  Widget build(BuildContext context) {
    final s = SessionScope.of(context);
    return Screen(
      top: Top(left: Av(initials(s.name)), title: s.name, sub: 'Where do you want to go?'),
      children: [
        for (final i in items)
          FCard(lift: true, onTap: () {
            if (i.path == 'web') { launchUrl(Uri.parse('${Config.server}/admin'), mode: LaunchMode.externalApplication); } else { context.go(i.path); }
          }, child: Row(children: [
            Tile(i.icon, tone: Tone.leaf, iconSize: 22), const SizedBox(width: 14),
            Expanded(child: Text(i.label, style: T.b.copyWith(fontSize: 16))),
            Ico(i.path == 'web' ? 'external-link' : 'chevron-right'),
          ])),
        const SizedBox(height: 20),
        Btn('Sign out', icon: 'log-out', kind: BtnKind.ghost, onTap: () => s.signOut()),
      ],
    );
  }
}

// Not connected yet (the app was built without FALCON's settings).
class Setup extends StatelessWidget {
  const Setup({super.key});
  @override
  Widget build(BuildContext context) => Screen(
        top: const Top(left: Tile('utensils', tone: Tone.navyTile, size: 40), title: 'FALCON', sub: 'Food & Site Operations · not connected'),
        children: [
          FCard(child: Column(children: [
            for (final n in ['FALCON_SUPABASE_URL', 'FALCON_SUPABASE_KEY', 'FALCON_SERVER'])
              Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
                Expanded(child: Text(n, style: T.sm.copyWith(color: C.ink))),
                Chip2(Config.problems().contains(n) ? 'not set' : 'set', tone: Config.problems().contains(n) ? Tone.red : Tone.leaf, height: 26),
              ])),
          ])),
          const InfoLine('This app was built without FALCON\'s settings. They are given to the build (GitHub → Settings → Variables).'),
        ],
      );
}
