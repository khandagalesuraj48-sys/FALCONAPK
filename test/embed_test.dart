// (23-11-2026) FALCON inside RCL's ERP / HR app (lib/embed.dart): the same screens as one page of that app – a pass that is not
// HR's is said and leads back; the phone's back on FALCON's first page leaves FALCON; the FALCON app itself is unchanged.
import 'package:falcon/embed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    falconEmbedded = false;
    falconLeave = null;
  });

  Future<void> openFalcon(WidgetTester t, void Function() left) async {
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (c) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => FalconInApp(pass: 'not-a-pass', onLeave: () {
                  left();
                  Navigator.of(c).pop();
                }))),
            child: const Text('Open Mess'),
          ),
        ),
      ),
    ));
    await t.tap(find.text('Open Mess'));
    await t.pumpAndSettle();
  }

  testWidgets('a pass that is not HR\'s: said, and "Back to RCL app" returns to the app around FALCON', (t) async {
    var left = 0;
    await openFalcon(t, () => left++);
    expect(falconEmbedded, isTrue);
    expect(find.textContaining('not from HR'), findsOneWidget);
    expect(find.text('Use FALCON\'s own sign-in'), findsNothing, reason: 'FALCON\'s own sign-up is for the FALCON app');
    await t.tap(find.text('Back to RCL app'));
    await t.pumpAndSettle();
    expect(left, 1);
    expect(find.text('Open Mess'), findsOneWidget);
  });

  testWidgets('the phone\'s back on FALCON\'s first page leaves FALCON (not the whole app)', (t) async {
    var left = 0;
    await openFalcon(t, () => left++);
    expect(find.textContaining('not from HR'), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(left, 1);
    expect(find.text('Open Mess'), findsOneWidget);
  });

  test('a picture of FALCON is read from this package only inside another app', () {
    falconEmbedded = false;
    expect(assetPackage, isNull);
    falconEmbedded = true;
    expect(assetPackage, 'falcon');
  });
}
