// The approved look's building blocks for the phone (the designs' .scr, .top, .card, .chip, .btn, .tabs, .sheet, .tl …) – each
// screen is built from these, like the web's src/ui/kit.tsx.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'look.dart';

/// A phone screen: cream (or the dark navy of the driver's app), the top bar, the body that scrolls, an optional foot and tab bar.
class Screen extends StatelessWidget {
  const Screen({super.key, this.top, required this.children, this.dark = false, this.foot, this.tabs, this.padding, this.background, this.stack});
  final Widget? top;
  final List<Widget> children;
  final bool dark;
  final Widget? foot;
  final Widget? tabs;
  final EdgeInsets? padding;
  final Color? background;
  final List<Widget>? stack; // drawn over the body (a map's pins, a floating sheet)
  @override
  Widget build(BuildContext context) {
    final bg = background ?? (dark ? C.navy : C.cream);
    final body = ListView(
      padding: padding ?? EdgeInsets.fromLTRB(20, 4, 20, tabs != null ? 104 : 24),
      children: [for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 14), children[i]]],
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          bottom: false,
          child: DefaultTextStyle(
            style: T.body.copyWith(color: dark ? Colors.white : C.ink),
            child: Stack(children: [
              Column(children: [
                ?top,
                Expanded(child: body),
                if (foot != null) foot!,
              ]),
              ...?stack,
              if (tabs != null) Positioned(left: 16, right: 16, bottom: 16 + MediaQuery.of(context).padding.bottom, child: tabs!),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The top bar: back, the title and its line under it, something on the right.
class Top extends StatelessWidget {
  const Top({super.key, required this.title, this.sub, this.back, this.right, this.left, this.dark = false});
  final String title;
  final String? sub;
  final String? back; // a path, or '' = go back
  final Widget? right, left;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
      child: Row(children: [
        if (back != null)
          IconBox(icon: 'chevron-left', label: 'Back', dark: dark, onTap: () {
            if (back!.isEmpty || context.canPop()) {
              if (context.canPop()) { context.pop(); } else { context.go('/'); }
            } else {
              context.go(back!);
            }
          })
        else if (left != null)
          left!,
        if (back != null || left != null) const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(title, style: T.title.copyWith(color: dark ? Colors.white : C.ink), maxLines: 2, overflow: TextOverflow.ellipsis),
            if (sub != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(sub!, style: T.sm.copyWith(color: dark ? C.darkSub : C.muted), maxLines: 2, overflow: TextOverflow.ellipsis)),
          ]),
        ),
        if (right != null) ...[const SizedBox(width: 12), right!],
      ]),
    );
  }
}

/// The square icon button of the designs (.ib).
class IconBox extends StatelessWidget {
  const IconBox({super.key, required this.icon, this.onTap, this.label, this.dark = false, this.badge = false});
  final String icon;
  final VoidCallback? onTap;
  final String? label;
  final bool dark, badge;
  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: dark ? C.navy2 : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: dark ? C.navy3 : C.line)),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: SizedBox(width: 44, height: 44, child: Stack(alignment: Alignment.center, children: [
            Ico(icon, color: dark ? Colors.white : C.ink),
            if (badge) Positioned(right: 10, top: 10, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: C.saffron, shape: BoxShape.circle))),
          ])),
        ),
      ),
    );
  }
}

/// A white card (.card); dark on the driver's app.
class FCard extends StatelessWidget {
  const FCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.dark = false, this.color, this.border, this.lift = false, this.radius = 20});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool dark, lift;
  final Color? color, border;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: BorderSide(color: border ?? (dark ? C.navy3 : C.line)));
    return Container(
      decoration: lift ? BoxDecoration(borderRadius: BorderRadius.circular(radius), boxShadow: const [BoxShadow(color: Color(0x1418221C), blurRadius: 30, offset: Offset(0, 14))]) : null,
      child: Material(
        color: color ?? (dark ? C.navy2 : Colors.white),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      ),
    );
  }
}

/// The navy hero card (.hero).
class Hero2 extends StatelessWidget {
  const Hero2({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => FCard(color: C.navy, border: C.navy, radius: 24, padding: const EdgeInsets.all(18), onTap: onTap,
      child: DefaultTextStyle(style: T.body.copyWith(color: Colors.white), child: child));
}

/// A chip (.chip) – a label, a filter or a small button.
class Chip2 extends StatelessWidget {
  const Chip2(this.text, {super.key, this.icon, this.tone = Tone.plain, this.onTap, this.height = 30, this.dark = false});
  final String text;
  final String? icon;
  final Tone tone;
  final VoidCallback? onTap;
  final double height;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    final t = dark && identical(tone, Tone.plain) ? Tone.dark : tone;
    return Material(
      color: t.bg,
      shape: StadiumBorder(side: BorderSide(color: t.border ?? Colors.transparent)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            if (icon != null) ...[Ico(icon!, size: 14, color: t.fg), const SizedBox(width: 6)],
            Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: font, fontSize: 13, fontWeight: FontWeight.w600, color: t.fg))),
          ]),
        ),
      ),
    );
  }
}

/// A small grey tag (.tag).
class Tag extends StatelessWidget {
  const Tag(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: C.cream, borderRadius: BorderRadius.circular(8)),
        child: Text(text, style: const TextStyle(fontFamily: font, fontSize: 12, fontWeight: FontWeight.w600, color: C.muted)),
      );
}

enum BtnKind { ink, leaf, sf, navy, red, ghost, gold, whatsapp }

/// The big button (.btn) – busy shows a spinner and stops a second tap.
class Btn extends StatelessWidget {
  const Btn(this.text, {super.key, this.icon, this.kind = BtnKind.ink, this.onTap, this.busy = false, this.small = false, this.dark = false, this.expand = true});
  final String text;
  final String? icon;
  final BtnKind kind;
  final VoidCallback? onTap;
  final bool busy, small, dark, expand;
  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color? side) = switch (kind) {
      BtnKind.ink => (C.ink, Colors.white, null),
      BtnKind.leaf => (C.leaf, Colors.white, null),
      BtnKind.sf => (C.saffron, Colors.white, null),
      BtnKind.navy => (C.navy, Colors.white, null),
      BtnKind.red => (C.red, Colors.white, null),
      BtnKind.gold => (C.gold, const Color(0xFF1D1404), null),
      BtnKind.whatsapp => (C.whatsapp, Colors.white, null),
      BtnKind.ghost => dark ? (Colors.transparent, Colors.white, C.navy3) : (Colors.white, C.ink, C.line2),
    };
    final off = onTap == null || busy;
    final child = Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
      if (busy) SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: fg))
      else if (icon != null) Ico(icon!, color: fg, size: small ? 18 : 20),
      if (busy || icon != null) const SizedBox(width: 10),
      Flexible(child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontFamily: font, fontSize: small ? 14 : 16, fontWeight: FontWeight.w600, color: fg))),
    ]);
    final b = Opacity(
      opacity: off && !busy ? 0.55 : 1,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(small ? 12 : 16), side: side == null ? BorderSide.none : BorderSide(color: side)),
        child: InkWell(
          borderRadius: BorderRadius.circular(small ? 12 : 16),
          onTap: off ? null : onTap,
          child: Container(height: small ? 40 : 54, padding: const EdgeInsets.symmetric(horizontal: 14), alignment: Alignment.center, child: child),
        ),
      ),
    );
    return expand && !small ? SizedBox(width: double.infinity, child: b) : b;
  }
}

/// A segmented choice (.seg).
class Seg extends StatelessWidget {
  const Seg({super.key, required this.items, required this.value, required this.onChanged, this.dark = false});
  final List<(String, String)> items; // (value, label)
  final String value;
  final ValueChanged<String> onChanged;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: dark ? C.navy2 : C.seg, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        for (final it in items)
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(it.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: it.$1 == value ? (dark ? C.navy3 : Colors.white) : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: it.$1 == value && !dark ? const [BoxShadow(color: Color(0x1418221C), blurRadius: 6, offset: Offset(0, 2))] : null,
                ),
                alignment: Alignment.center,
                child: Text(it.$2, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600,
                        color: it.$1 == value ? (dark ? Colors.white : C.ink) : (dark ? C.darkSub : C.muted))),
              ),
            ),
          ),
      ]),
    );
  }
}

/// A round avatar with initials (.av).
class Av extends StatelessWidget {
  const Av(this.text, {super.key, this.size = 40, this.tone = Tone.leaf});
  final String text;
  final double size;
  final Tone tone;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.bg, shape: BoxShape.circle),
        child: Text(text, style: TextStyle(fontFamily: font, fontSize: size >= 56 ? 18 : size <= 28 ? 12 : 14, fontWeight: FontWeight.w700, color: tone.fg)),
      );
}

/// A rounded icon tile (.tile).
/// FALCON's logo (B – the falcon on the plate, a fork and a knife crossed behind; approved 23-11-2026).
class Logo extends StatelessWidget {
  const Logo({super.key, this.size = 64});
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
        label: 'FALCON',
        image: true,
        child: Image.asset('assets/brand/falcon-logo.png', width: size, height: size, filterQuality: FilterQuality.high),
      );
}

class Tile extends StatelessWidget {
  const Tile(this.icon, {super.key, this.tone = Tone.sf, this.size = 48, this.iconSize});
  final String icon;
  final Tone tone;
  final double size;
  final double? iconSize;
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: tone.bg, borderRadius: BorderRadius.circular(size >= 56 ? 18 : size <= 40 ? 13 : 16)),
        child: Ico(icon, color: tone.fg, size: iconSize ?? (size >= 56 ? 28 : 20)),
      );
}

class Dot extends StatelessWidget {
  const Dot({super.key, this.color = C.leaf});
  final Color color;
  @override
  Widget build(BuildContext context) => Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
}

/// A thin progress bar (.bar).
class Bar extends StatelessWidget {
  const Bar(this.value, {super.key, this.color = C.leaf, this.dark = false});
  final double value;
  final Color color;
  final bool dark;
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(height: 8, child: LinearProgressIndicator(value: value.clamp(0, 1), color: color, backgroundColor: dark ? C.navy3 : C.seg)),
      );
}

class Hr extends StatelessWidget {
  const Hr({super.key, this.dark = false});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(height: 1, color: dark ? C.navy3 : C.line, margin: const EdgeInsets.symmetric(vertical: 2));
}

/// A row of two things, the first taking the room (.row with .sp).
class Line extends StatelessWidget {
  const Line(this.left, this.right, {super.key, this.dark = false, this.strong = true});
  final String left;
  final String right;
  final bool dark, strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(left, style: T.sm.copyWith(color: dark ? C.darkSub : C.muted))),
          const SizedBox(width: 10),
          Flexible(child: Text(right, textAlign: TextAlign.right, style: TextStyle(fontFamily: font, fontSize: 14, fontWeight: strong ? FontWeight.w700 : FontWeight.w400, color: dark ? Colors.white : C.ink))),
        ]),
      );
}

/// The few dashes of the steps of a flow (registration).
class Steps extends StatelessWidget {
  const Steps(this.n, this.of, {super.key, this.last});
  final int n, of;
  final Color? last;
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < of; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(child: Container(height: 5, decoration: BoxDecoration(borderRadius: BorderRadius.circular(3),
              color: i < n ? (i == of - 1 && last != null ? last : C.leaf) : const Color(0xFFE7E1D3)))),
        ],
      ]);
}

// ── the states every screen has ──
class Loading extends StatelessWidget {
  const Loading({super.key, this.what = 'Loading', this.dark = false});
  final String what;
  final bool dark;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2.4, color: dark ? C.gold : C.leaf)),
          const SizedBox(width: 10),
          Text('$what…', style: T.sm.copyWith(color: dark ? C.darkSub : C.muted)),
        ]),
      );
}

class Failed extends StatelessWidget {
  const Failed(this.error, {super.key, this.retry});
  final String error;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => FCard(
        color: const Color(0xFFFFF6F4), border: const Color(0xFFE8A49B),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Ico('triangle-alert', size: 18, color: C.redD),
          const SizedBox(width: 10),
          Expanded(child: Text(error, style: T.sm.copyWith(color: const Color(0xFF7A1F1F)))),
          if (retry != null) ...[const SizedBox(width: 8), Chip2('Try again', onTap: retry)],
        ]),
      );
}

class Empty extends StatelessWidget {
  const Empty({super.key, this.icon = 'info', required this.title, this.text, this.action, this.dark = false});
  final String icon, title;
  final String? text;
  final Widget? action;
  final bool dark;
  @override
  Widget build(BuildContext context) => FCard(
        dark: dark,
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Tile(icon, tone: dark ? Tone.darkTile : Tone.cream, iconSize: 22),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center, style: T.b.copyWith(color: dark ? Colors.white : C.ink)),
          if (text != null) ...[const SizedBox(height: 6), Text(text!, textAlign: TextAlign.center, style: T.sm.copyWith(color: dark ? C.darkSub : C.muted))],
          if (action != null) ...[const SizedBox(height: 10), action!],
        ]),
      );
}

class Denied extends StatelessWidget {
  const Denied({super.key, this.text = 'This page is not part of your work in FALCON.'});
  final String text;
  @override
  Widget build(BuildContext context) => Empty(icon: 'lock', title: 'Not open to you', text: text, action: Chip2('Go to your start page', onTap: () => context.go('/')));
}

class ErrorLine extends StatelessWidget {
  const ErrorLine(this.error, {super.key, this.dark = false});
  final String? error;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final c = dark ? const Color(0xFFFFB4A8) : C.redD;
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Ico('triangle-alert', size: 14, color: c),
      const SizedBox(width: 6),
      Expanded(child: Text(error!, style: T.xs.copyWith(color: c))),
    ]);
  }
}

class InfoLine extends StatelessWidget {
  const InfoLine(this.text, {super.key, this.icon = 'info', this.dark = false});
  final String text, icon;
  final bool dark;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Ico(icon, size: 14, color: dark ? C.darkSub : C.muted),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: T.xs.copyWith(color: dark ? C.darkSub : C.muted))),
      ]);
}

/// A labelled field (.fld).
class Field extends StatelessWidget {
  const Field(this.label, this.child, {super.key, this.dark = false});
  final String label;
  final Widget child;
  final bool dark;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(label, style: T.lbl.copyWith(color: dark ? C.darkSub : C.muted)),
        const SizedBox(height: 6),
        child,
      ]);
}

/// A text box drawn as the design's input (.inp).
class Input extends StatelessWidget {
  const Input({super.key, required this.controller, this.hint, this.icon, this.keyboard, this.maxLength, this.big = false, this.onChanged,
      this.lines = 1, this.autofocus = false, this.dark = false, this.label, this.caps = TextCapitalization.none});
  final TextEditingController controller;
  final String? hint, icon, label;
  final TextInputType? keyboard;
  final int? maxLength;
  final bool big, autofocus, dark;
  final int lines;
  final ValueChanged<String>? onChanged;
  final TextCapitalization caps;
  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: dark ? C.navy3 : C.line2));
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLength: maxLength,
      maxLines: lines,
      minLines: 1,
      autofocus: autofocus,
      onChanged: onChanged,
      textCapitalization: caps,
      style: TextStyle(fontFamily: font, fontSize: big ? 22 : 15, fontWeight: big ? FontWeight.w700 : FontWeight.w400, color: dark ? Colors.white : C.ink, letterSpacing: big ? 1 : 0),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        labelText: label,
        hintStyle: TextStyle(fontFamily: font, color: C.faint, fontSize: big ? 20 : 15, fontWeight: FontWeight.w400),
        filled: true,
        fillColor: dark ? C.navy2 : Colors.white,
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: big ? 18 : 15),
        prefixIcon: icon == null ? null : Padding(padding: const EdgeInsets.only(left: 14, right: 8), child: Ico(icon!, size: 20, color: C.muted)),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        enabledBorder: border,
        border: border,
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.leaf, width: 1.5)),
      ),
    );
  }
}

/// The six boxes of a code.
class CodeBoxes extends StatefulWidget {
  const CodeBoxes({super.key, required this.onDone, this.length = 6, this.dark = false});
  final ValueChanged<String> onDone;
  final int length;
  final bool dark;
  @override
  State<CodeBoxes> createState() => _CodeBoxesState();
}

class _CodeBoxesState extends State<CodeBoxes> {
  final _c = TextEditingController();
  final _f = FocusNode();
  @override
  void dispose() { _c.dispose(); _f.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final v = _c.text;
    return GestureDetector(
      onTap: () => _f.requestFocus(),
      child: Stack(children: [
        Opacity(opacity: 0, child: SizedBox(height: 1, child: TextField(controller: _c, focusNode: _f, autofocus: true, keyboardType: TextInputType.number,
            maxLength: widget.length, autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (x) { setState(() {}); if (x.length == widget.length) widget.onDone(x); }))),
        Row(children: [
          for (var i = 0; i < widget.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: widget.dark ? C.navy2 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: i == v.length ? C.leaf : (widget.dark ? C.navy3 : C.line2), width: i == v.length ? 1.6 : 1),
              ),
              child: Text(i < v.length ? v[i] : '', style: TextStyle(fontFamily: font, fontSize: 24, fontWeight: FontWeight.w700, color: widget.dark ? Colors.white : C.ink)),
            )),
          ],
        ]),
      ]),
    );
  }
}

/// − n + (.step)
class Stepper2 extends StatelessWidget {
  const Stepper2({super.key, required this.value, required this.onChanged, this.min = 0, this.max = 20});
  final int value, min, max;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 40,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.line2), borderRadius: BorderRadius.circular(14)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          InkWell(onTap: value > min ? () => onChanged(value - 1) : null, child: const SizedBox(width: 38, height: 40, child: Center(child: Ico('minus', size: 18)))),
          SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontFamily: font, fontSize: 16, fontWeight: FontWeight.w700))),
          InkWell(onTap: value < max ? () => onChanged(value + 1) : null, child: const SizedBox(width: 38, height: 40, child: Center(child: Ico('plus', size: 18)))),
        ]),
      );
}

/// The floating pill tab bar (.tabs).
class TabItem {
  const TabItem(this.path, this.icon, this.label, {this.plus = false});
  final String path, icon, label;
  final bool plus;
}

class PillTabs extends StatelessWidget {
  const PillTabs({super.key, required this.tabs, required this.current, this.dark = false});
  final List<TabItem> tabs;
  final String current;
  final bool dark;
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: dark ? C.navy2 : Colors.white,
        borderRadius: BorderRadius.circular(33),
        border: Border.all(color: dark ? C.navy3 : C.line),
        boxShadow: [BoxShadow(color: dark ? const Color(0x66000000) : const Color(0x2418221C), blurRadius: 30, offset: const Offset(0, 12))],
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (final t in tabs)
          if (t.plus)
            Material(color: C.saffron, shape: const CircleBorder(), child: InkWell(customBorder: const CircleBorder(), onTap: () => context.push(t.path),
                child: SizedBox(width: 48, height: 48, child: Center(child: Ico(t.icon, size: 24, color: Colors.white)))))
          else
            _tab(context, t, current == t.path),
      ]),
    );
  }

  Widget _tab(BuildContext context, TabItem t, bool on) {
    final onBg = dark ? C.gold : C.leaf, onFg = dark ? const Color(0xFF1D1404) : Colors.white, offFg = dark ? C.darkSub : C.muted;
    return Semantics(
      button: true,
      selected: on,
      label: t.label,
      child: Material(
        color: on ? onBg : Colors.transparent,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: on ? null : () => context.go(t.path),
          child: Container(height: 46, padding: EdgeInsets.symmetric(horizontal: on ? 16 : 12), child: Row(mainAxisSize: MainAxisSize.min, children: [
            Ico(t.icon, color: on ? onFg : offFg),
            if (on) ...[const SizedBox(width: 8), Text(t.label, style: TextStyle(fontFamily: font, fontSize: 14, fontWeight: FontWeight.w600, color: onFg))],
          ])),
        ),
      ),
    );
  }
}

/// A bottom sheet in the design's shape (.sheet).
Future<R?> sheet<R>(BuildContext context, Widget Function(BuildContext) build, {bool dark = false}) {
  return showModalBottomSheet<R>(
    context: context,
    isScrollControlled: true,
    backgroundColor: dark ? C.navy2 : Colors.white,
    barrierColor: const Color(0x6B0E1B33),
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: dark ? C.navy3 : const Color(0xFFDCD5C5), borderRadius: BorderRadius.circular(3)))),
        const SizedBox(height: 14),
        DefaultTextStyle(style: T.body.copyWith(color: dark ? Colors.white : C.ink), child: build(ctx)),
      ]),
    ),
  );
}

/// The steps of a timeline (.tl).
class TlStep {
  const TlStep(this.title, {this.sub, this.state = 'next', this.icon});
  final String title;
  final String? sub, icon;
  final String state; // done | now | next | bad
}

class Timeline extends StatelessWidget {
  const Timeline(this.steps, {super.key});
  final List<TlStep> steps;
  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (var i = 0; i < steps.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(width: 28, child: Column(children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (steps[i].state) { 'done' => C.leaf, 'now' => C.saffron, 'bad' => C.red, _ => Colors.white },
                  border: Border.all(color: switch (steps[i].state) { 'done' => C.leaf, 'now' => C.saffron, 'bad' => C.red, _ => C.line2 }, width: 2),
                  boxShadow: steps[i].state == 'now' ? const [BoxShadow(color: Color(0x33E8892B), spreadRadius: 6)] : null,
                ),
                alignment: Alignment.center,
                child: steps[i].state == 'next' ? null : Ico(steps[i].icon ?? (steps[i].state == 'done' ? 'check' : steps[i].state == 'bad' ? 'x' : 'clock'), size: 14, color: Colors.white),
              ),
              if (i < steps.length - 1) Expanded(child: Container(width: 2, color: steps[i].state == 'done' ? C.leaf : C.line2)),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Padding(
              padding: const EdgeInsets.only(bottom: 16, top: 3),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(steps[i].title, style: T.b.copyWith(color: steps[i].state == 'next' ? C.muted : C.ink)),
                if (steps[i].sub != null) Padding(padding: const EdgeInsets.only(top: 1), child: Text(steps[i].sub!, style: T.sm)),
              ]),
            )),
          ]),
        ),
    ]);
  }
}

/// A short message at the bottom.
void toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// Wrap children with a gap (a .row.wrap of chips).
class Wrap2 extends StatelessWidget {
  const Wrap2(this.children, {super.key, this.gap = 8});
  final List<Widget> children;
  final double gap;
  @override
  Widget build(BuildContext context) => Wrap(spacing: gap, runSpacing: gap, children: children);
}
