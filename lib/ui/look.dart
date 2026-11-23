// The approved look (the design canvas "FALCON – app and web design", approved 23-11-2026) – the same colours, type and shapes as
// the web's src/styles/design.css. Change only with his OK.
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../embed.dart';

class C {
  static const cream = Color(0xFFFAF8F2), paper = Color(0xFFFFFFFF), ink = Color(0xFF18221C), muted = Color(0xFF55625A);
  static const faint = Color(0xFF7C8780), line = Color(0xFFECE6D9), line2 = Color(0xFFE2DBCB);
  static const leaf = Color(0xFF2F7A45), leafD = Color(0xFF1E5A33), leafS = Color(0xFFE3F1E6);
  static const sf = Color(0xFFE8892B), sfD = Color(0xFF9A4A06), sfS = Color(0xFFFDEEDC), saffron = Color(0xFFC2560E);
  static const navy = Color(0xFF0E1B33), navy2 = Color(0xFF172A4C), navy3 = Color(0xFF22385F);
  static const gold = Color(0xFFD99E39), goldI = Color(0xFFB07A1E);
  static const red = Color(0xFFC62828), redS = Color(0xFFFCE4E0), redD = Color(0xFF9B1C1C);
  static const blue = Color(0xFF1E63D6), blueS = Color(0xFFE1EBFB), blueD = Color(0xFF1747A6);
  static const amber = Color(0xFF8A5300), amberS = Color(0xFFFDEFD5);
  static const plum = Color(0xFF7B3FD0), plumS = Color(0xFFEFE6FB), plumD = Color(0xFF5B2BA0);
  static const whatsapp = Color(0xFF128C4A);
  static const seg = Color(0xFFEFEADF), darkSub = Color(0xFFA9B6CC), heroSub = Color(0xFFB8C3D6);
}

// (23-11-2026) one name for the family in the FALCON app and inside RCL's app: pubspec.yaml declares it under this name too
// (inside another app Flutter names a package's font "packages/falcon/Schibsted" – so this one name works in both)
const font = 'packages/falcon/Schibsted';

/// The text styles of the designs (.h1, .h2, .lbl, .sm, .xs, .big).
class T {
  static const h1 = TextStyle(fontFamily: font, fontSize: 27, fontWeight: FontWeight.w700, letterSpacing: -0.67, height: 1.12, color: C.ink);
  static const h2 = TextStyle(fontFamily: font, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.17, color: C.ink);
  static const title = TextStyle(fontFamily: font, fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.19, height: 1.2, color: C.ink);
  static const body = TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w400, color: C.ink, height: 1.35);
  static const b = TextStyle(fontFamily: font, fontSize: 15, fontWeight: FontWeight.w700, color: C.ink);
  static const lbl = TextStyle(fontFamily: font, fontSize: 13, fontWeight: FontWeight.w600, color: C.muted);
  static const sm = TextStyle(fontFamily: font, fontSize: 13, color: C.muted, height: 1.35);
  static const xs = TextStyle(fontFamily: font, fontSize: 12, color: C.muted, height: 1.35);
  static const big = TextStyle(fontFamily: font, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1.0, height: 1.0, color: C.ink);
}

ThemeData falconTheme() {
  final base = ThemeData(useMaterial3: true, fontFamily: font, colorScheme: ColorScheme.fromSeed(seedColor: C.leaf, surface: C.cream));
  return base.copyWith(
    scaffoldBackgroundColor: C.cream,
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink, fontFamily: font),
    splashFactory: InkRipple.splashFactory,
    snackBarTheme: const SnackBarThemeData(backgroundColor: C.ink, contentTextStyle: TextStyle(fontFamily: font, color: Colors.white)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: C.leaf),
  );
}

/// An icon of the approved designs (Lucide, ISC licence – assets/icons/<name>.svg), drawn in the given colour.
class Ico extends StatelessWidget {
  const Ico(this.name, {super.key, this.size = 20, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c = color ?? DefaultTextStyle.of(context).style.color ?? C.ink;
    return SvgPicture.asset('assets/icons/$name.svg', package: assetPackage, width: size, height: size,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn), placeholderBuilder: (_) => SizedBox(width: size, height: size),
        errorBuilder: (_, _, _) => SizedBox(width: size, height: size));
  }
}

/// A tone of a chip / tile / avatar: its background and its text colour.
class Tone {
  const Tone(this.bg, this.fg, [this.border]);
  final Color bg, fg;
  final Color? border;
  static const plain = Tone(Colors.white, C.ink, C.line2);
  static const on = Tone(C.ink, Colors.white);
  static const leaf = Tone(C.leafS, C.leafD);
  static const sf = Tone(C.sfS, C.sfD);
  static const red = Tone(C.redS, C.redD);
  static const blue = Tone(C.blueS, C.blueD);
  static const amber = Tone(C.amberS, C.amber);
  static const navy = Tone(C.navy, Colors.white);
  static const plum = Tone(C.plumS, C.plumD);
  static const cream = Tone(C.cream, C.ink);
  static const dark = Tone(C.navy2, Colors.white, C.navy3);
  static const darkTile = Tone(C.navy3, C.gold);
  static const navyTile = Tone(C.navy, C.gold);
  static const redTile = Tone(C.redS, C.red);
  static Tone of(String? name) => switch (name) {
        'on' => on, 'leaf' => leaf, 'sf' => sf, 'red' => red, 'blue' => blue, 'amber' => amber, 'navy' => navy, 'plum' => plum,
        'cream' => cream, _ => plain };
}
