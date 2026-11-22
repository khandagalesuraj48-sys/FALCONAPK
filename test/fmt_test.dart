import 'package:falcon/config.dart';
import 'package:falcon/core/fmt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('numbers and money in the Indian way', () {
    expect(numf(1234567), '12,34,567');
    expect(numf(999), '999');
    expect(numf(null), '–');
    expect(inr(326), '₹326');
    expect(inr(1500.5), '₹1,500.5');
  });
  test('a mobile typed in any way becomes +91…, or nothing', () {
    expect(phoneE164('98000 00044'), '+919800000044');
    expect(phoneE164('+91 9800000044'), '+919800000044');
    expect(phoneE164('12345'), isNull);
    expect(phoneE164('5800000044'), isNull);
  });
  test('masked mobile, initials, meal names', () {
    expect(maskMobile('+919800000044'), '+91 98XXX XX044');
    expect(initials('ganesh shinde'), 'GS');
    expect(mealName('lunch'), 'Lunch');
    expect(hm('12:30:00'), '12:30');
  });
  test('days on the site\'s clock', () {
    expect(day('2026-11-23'), '23 Nov');
    expect(dayLong('2026-11-23'), 'Mon 23 Nov');
    expect(monthName('2026-11-01'), 'November 2026');
    expect(RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(today()), isTrue);
  });
  test('a secret key is never taken into the app', () {
    expect(Config.roleOf('x.eyJyb2xlIjoic2VydmljZV9yb2xlIn0.y'), 'service_role');
    expect(Config.roleOf('sb_publishable_abc'), '');
  });
}
