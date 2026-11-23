// (23-11-2026) a mess, section or site removed in FALCON's web leaves the phone's lists from its date – its From / Till
import 'package:falcon/core/meals.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('in use between its From and its Till; switched off is never in use', () {
    expect(inUse({'active': true}, '2026-11-23'), isTrue);
    expect(inUse({'active': true, 'valid_from': '2026-11-24'}, '2026-11-23'), isFalse, reason: 'from tomorrow');
    expect(inUse({'active': true, 'valid_to': '2026-11-23'}, '2026-11-23'), isTrue, reason: 'its last day');
    expect(inUse({'active': true, 'valid_to': '2026-11-22'}, '2026-11-23'), isFalse, reason: 'removed from today');
    expect(inUse({'active': false}, '2026-11-23'), isFalse);
  });
}
