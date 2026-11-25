// (25-11-2026, his word: "otp whats app la yeto mi whats app war jaun copy krun alo ki ekde falcon madhe otp taku det nahi screen la touch
// kel tr otp box madhe kahi jat nahi") the six boxes of a code (lib/ui/kit.dart CodeBoxes) – as the ERP app's sign-in.
import 'package:falcon/ui/kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String? board; // what is on the phone's clipboard
  setUp(() {
    board = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') return board == null ? null : <String, dynamic>{'text': board};
      return null;
    });
  });
  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

  Future<List<String>> open(WidgetTester t, {bool paste = true}) async {
    final done = <String>[];
    await t.pumpWidget(MaterialApp(home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: CodeBoxes(onDone: done.add, paste: paste)))));
    await t.pump();
    return done;
  }

  // the app goes to WhatsApp and comes back – through the states Flutter allows, one by one
  Future<void> wentAwayAndBack(WidgetTester t) async {
    for (final st in const [AppLifecycleState.inactive, AppLifecycleState.hidden, AppLifecycleState.paused, AppLifecycleState.hidden, AppLifecycleState.inactive, AppLifecycleState.resumed]) {
      t.binding.handleAppLifecycleStateChanged(st);
      await t.pump();
    }
    await t.pump();
  }

  testWidgets('a touch on the boxes opens the keyboard again – also when it was put away (as after WhatsApp)', (t) async {
    await open(t);
    expect(t.testTextInput.isVisible, isTrue, reason: 'open at once');
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    expect(t.testTextInput.isVisible, isFalse);
    await t.tapAt(t.getTopLeft(find.byType(CodeBoxes)) + const Offset(20, 28)); // the first box
    await t.pump();
    expect(t.testTextInput.isVisible, isTrue, reason: 'the touch reaches the real box: the keyboard is back');
    await t.enterText(find.byKey(const Key('code-field')), '12a3');
    await t.pump();
    expect([for (final d in ['1', '2', '3']) find.text(d).evaluate().length], [1, 1, 1], reason: 'only digits');
  });

  testWidgets('back from WhatsApp ("Copy code"): the code copied fills the six boxes and is checked', (t) async {
    final done = await open(t);
    board = '482913';
    await wentAwayAndBack(t);
    expect(done, ['482913']);
    expect([for (final d in ['4', '8', '2', '9', '1', '3']) find.text(d).evaluate().length], [1, 1, 1, 1, 1, 1]);
  });

  testWidgets('back with other words on the clipboard: nothing by itself, the keyboard comes again; "Paste code" takes the six digits', (t) async {
    final done = await open(t);
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    board = 'Your FALCON code is 705218. It is valid for 10 minutes.';
    await wentAwayAndBack(t);
    expect(done, isEmpty);
    expect(t.testTextInput.isVisible, isTrue, reason: 'back in the app: the keyboard again');
    await t.tap(find.byKey(const Key('code-paste')));
    await t.pump();
    await t.pump();
    expect(done, ['705218']);
  });

  testWidgets('the same code is never taken twice by itself; nothing copied: "Paste code" only opens the keyboard', (t) async {
    final done = await open(t);
    await t.tap(find.byKey(const Key('code-paste')));
    await t.pump();
    expect(done, isEmpty);
    board = '111222';
    await wentAwayAndBack(t);
    expect(done, ['111222']);
    // the code was wrong – the screen asks again: the boxes are emptied
    await t.enterText(find.byKey(const Key('code-field')), '');
    await t.pump();
    await wentAwayAndBack(t);
    expect(done, ['111222'], reason: 'the same copied code is not put in again by itself');
  });

  testWidgets('the code a guest says to the employee: no "Paste code", nothing from the clipboard by itself', (t) async {
    final done = await open(t, paste: false);
    expect(find.byKey(const Key('code-paste')), findsNothing);
    board = '482913';
    await wentAwayAndBack(t);
    expect(done, isEmpty);
  });
}
