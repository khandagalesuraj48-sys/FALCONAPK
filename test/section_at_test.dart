// (Wolf 0017) the phone finds the section by the same rule as the server (public.section_at) – made-up places only
import 'package:flutter_test/flutter_test.dart';
import 'package:falcon/core/geo.dart';

void main() {
  final secs = <Map<String, dynamic>>[
    {'id': 'a1', 'code': 'A1', 'lat': 19.01, 'lng': 73.0, 'radius_m': 700},
    {'id': 'mjw', 'code': 'MJW', 'lat': 19.02, 'lng': 73.0, 'radius_m': 500},
    {'id': 'none', 'code': 'NOAREA', 'lat': 19.05, 'lng': 73.0, 'radius_m': null},
    {'id': 'noplace', 'code': 'X', 'lat': null, 'lng': null, 'radius_m': 300},
  ];
  test('a point inside a section is that section', () {
    expect(sectionAt(19.0205, 73.0, secs)?['id'], 'mjw');
    expect(sectionAt(19.0105, 73.0, secs)?['id'], 'a1');
  });
  test('inside two areas: the nearest', () => expect(sectionAt(19.016, 73.0, secs)?['id'], 'mjw'));
  test('a section without its metres or its place is never found by a point', () => expect(sectionAt(19.05, 73.0, secs), isNull));
  test('outside every section: none – the order brings the location', () => expect(sectionAt(19.1, 73.0, secs), isNull));
}
