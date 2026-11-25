// (25-11-2026, his word with two pictures – FALCON "5.9 km away", Google Maps 12 km: "app ase ase fake imformation denare tr kahich thik
// nahi chalnar") the distance BY ROAD (core/road.dart) – made-up places only, no server.
import 'package:falcon/core/road.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => Roads.i.clear());
  tearDown(() => Roads.askForTest = null);

  test('the words: by road with the minutes; until then the straight line, said as one', () {
    expect(roadLabel(const Road(12034, 1820), 5900), '12 km by road · 30 min');
    expect(roadLabel(const Road(850, null), 600), '850 m by road');
    expect(roadLabel(null, 5900), '5.9 km in a straight line');
    expect(roadLabel(null, null), '');
    expect([roadShort(const Road(12034, 1820), 5900), roadShort(null, 5900)], ['12 km by road', '5.9 km in a straight line']);
    expect([minutesText(20), minutesText(3700)], ['1 min', '1 h 02 min']);
  });

  test('a road is asked for once, kept, and the screens are told when it comes; his place to about 100 m', () async {
    final asked = <Map<String, dynamic>>[];
    Roads.askForTest = (path, body) async {
      asked.add({'path': path, ...body});
      return {'road': {'metres': 12034, 'seconds': 1820}};
    };
    var told = 0;
    void hear() => told++;
    Roads.i.addListener(hear);
    addTearDown(() => Roads.i.removeListener(hear));
    expect(Roads.i.of(19.29871, 73.05432, 19.30219, 73.11876), isNull, reason: 'not yet – the straight line meanwhile');
    expect(Roads.i.of(19.29875, 73.05429, 19.30219, 73.11876), isNull, reason: 'the same way: not asked twice');
    await Future<void>.delayed(Duration.zero);
    expect(asked.length, 1);
    expect(asked.single['path'], '/api/route');
    expect(told, 1);
    expect(Roads.i.of(19.29871, 73.05432, 19.30219, 73.11876)?.metres, 12034);
  });

  test('no road now (no key / no network): the straight line stays', () async {
    Roads.askForTest = (path, body) async => throw Exception('The distance by road is not connected yet');
    expect(Roads.i.of(19.1, 73.1, 19.2, 73.2), isNull);
    await Future<void>.delayed(Duration.zero);
    expect(Roads.i.of(19.1, 73.1, 19.2, 73.2), isNull);
    expect(roadLabel(Roads.i.of(19.1, 73.1, 19.2, 73.2), 11200), '11 km in a straight line');
  });
}
