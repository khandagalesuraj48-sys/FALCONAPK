// (23-11-2026, pictures N1, N2, N8) where he is, the server's clock, the pass from HR – the rules, without a phone.
import 'package:falcon/core/fmt.dart';
import 'package:falcon/core/geo.dart';
import 'package:falcon/core/meals.dart';
import 'package:falcon/screens/from_hr.dart' show passShape;
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('at the mess: inside its metres, the phone\'s uncertainty counted up to 50 m; a mess without a place: not known', () {
    expect(metres(18.52, 73.8567, 18.5203, 73.8567), inInclusiveRange(32, 35));
    expect(atMess(18.52, 73.8567, 12, 18.5203, 73.8567, 100), isTrue);
    expect(atMess(18.55, 73.8567, 12, 18.5203, 73.8567, 100), isFalse);
    expect(atMess(18.5212, 73.8567, 200, 18.5203, 73.8567, null), isTrue, reason: '100 m when none is set, + 50 m at most');
    expect(atMess(18.5222, 73.8567, 200, 18.5203, 73.8567, 100), isFalse);
    expect(atMess(18.52, 73.8567, 12, null, null, 100), isNull);
    expect([distText(33), distText(3280), distText(12500)], ['33 m', '3.3 km', '13 km']);
    expect(directionsUrl(18.5203, 73.8567).toString(), 'https://www.google.com/maps/dir/?api=1&destination=18.520300,73.856700');
  });
  test('the meal follows the SERVER\'s clock, not the phone\'s', () {
    final wins = [
      Win({'meal': 'lunch', 'serve_from': '12:00:00', 'serve_to': '14:30:00', 'order_by': '11:30:00', 'change_minutes': 0}),
      Win({'meal': 'dinner', 'serve_from': '19:30:00', 'serve_to': '22:00:00', 'order_by': '19:00:00', 'change_minutes': 0}),
    ];
    addTearDown(() => skewMs = 0);
    final now = DateTime.now().millisecondsSinceEpoch;
    // the server says 13:00 India
    final d = DateTime.now().toUtc();
    final at13 = DateTime.utc(d.year, d.month, d.day, 7, 30).millisecondsSinceEpoch;
    setSkew(at13, now, now);
    expect(nowHM(), '13:00');
    expect(currentMeal(wins), 'lunch');
    // the server says 18:00 India – dinner, whatever the phone's own clock says
    setSkew(DateTime.utc(d.year, d.month, d.day, 12, 30).millisecondsSinceEpoch, now, now);
    expect(nowHM(), '18:00');
    expect(currentMeal(wins), 'dinner');
  });
  test('only a pass of HR\'s shape is sent to FALCON\'s server', () {
    expect(passShape.hasMatch('v1.eyJjIjoiRTAwMDEyIn0.${'A' * 43}'), isTrue);
    for (final bad in ['', 'v2.x.${'A' * 43}', 'v1.eyJ.short', 'v1.a b.${'A' * 43}']) {
      expect(passShape.hasMatch(bad), isFalse, reason: bad);
    }
  });
}
