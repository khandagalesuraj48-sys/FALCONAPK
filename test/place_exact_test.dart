// (25-11-2026, his words: "falcon madhe pn location fetch 1 second madhe hoyla hawey"; "jar mi outside asel mess pasun at the mess option
// band asel tyala parcel gheyla lagel"; "kal pahile mess pasun 20 km lamb hoto but app sangat hote 5 km … ekdm perfect"; "falcon opening chi
// screen ti yenar nahi") – the rules, without a phone.
import 'dart:async';

import 'package:falcon/core/db.dart' show Load;
import 'package:falcon/core/geo.dart';
import 'package:falcon/embed.dart';
import 'package:falcon/screens/employee.dart' show placeMode;
import 'package:falcon/ui/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('only an exact reading (within 100 m) counts; a rough one does not push out an exact one of the last 30 s', () {
    expect(hereExact, 100);
    final t = DateTime.utc(2026, 11, 25, 5);
    expect(hereTakes(false, t, 3000, t), isTrue, reason: 'nothing exact yet: the rough one is shown as rough');
    expect(hereTakes(true, t, 12, t.add(const Duration(seconds: 5))), isTrue);
    expect(hereTakes(true, t, 3000, t.add(const Duration(seconds: 5))), isFalse, reason: 'a tower reading 5 s after an exact one: kept out');
    expect(hereTakes(true, t, 3000, t.add(const Duration(seconds: 31))), isTrue, reason: 'the exact one is old now');
  });

  test('one reading of its own at once (beside the stream): every second, the phone\'s reading of the last 15 s, within 10 s', () {
    final a = hereOnce(true) as AndroidSettings;
    expect([a.accuracy, a.intervalDuration, a.maxUpdateAge, a.timeLimit], [LocationAccuracy.high, const Duration(seconds: 1), const Duration(seconds: 15), const Duration(seconds: 10)]);
    expect(hereOnce(false) is AndroidSettings, isFalse);
  });

  test('outside the mess area: Parcel only, whatever was chosen; at the mess: the mess unless Parcel was chosen; not known: the choice', () {
    expect([placeMode(null, false), placeMode('mess', false), placeMode('parcel', false)], ['parcel', 'parcel', 'parcel']);
    expect([placeMode(null, true), placeMode('parcel', true), placeMode('mess', true)], ['mess', 'parcel', 'mess']);
    expect([placeMode(null, null), placeMode('mess', null), placeMode('parcel', null)], [null, 'mess', 'parcel']);
  });

  testWidgets('a choice that cannot be made now ("At the mess" outside) is dim and a touch does nothing', (t) async {
    final got = <String>[];
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Seg(items: const [('meal', 'At the mess'), ('parcel', 'Parcel to my site')], value: 'parcel', off: const {'meal'}, onChanged: got.add))));
    await t.tap(find.byKey(const Key('seg-meal')));
    await t.tap(find.byKey(const Key('seg-parcel')));
    expect(got, ['parcel']);
  });

  testWidgets('the home read a moment ago is shown at once – no loading screen – and read again quietly', (t) async {
    final c = Completer<int>();
    await t.pumpWidget(MaterialApp(home: Load<int>(first: 1, load: () => c.future, loading: const Text('loading'), builder: (_, v, _) => Text('home $v'))));
    expect(find.text('home 1'), findsOneWidget);
    expect(find.text('loading'), findsNothing);
    c.complete(2);
    await t.pump();
    expect(find.text('home 2'), findsOneWidget);
  });

  test('FALCON is not ready for anybody before it was made ready', () {
    expect(falconWarmFor('someone@rcl.test'), isFalse);
    expect(falconWarmFor(''), isFalse);
  });
}
