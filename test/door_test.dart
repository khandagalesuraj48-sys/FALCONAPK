// The first screen's code (23-11-2026): only what the server gave is kept, and only a code of 2–12 letters and numbers.
import 'package:falcon/core/door.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a company and a contractor are read from the server\'s answer', () {
    final c = Door.from({'kind': 'company', 'code': 'TST', 'name': 'Test Company', 'company': 'TST', 'company_name': 'Test Company'})!;
    expect(c.isContractor, isFalse);
    expect(c.toJson()['company_name'], 'Test Company');
    final k = Door.from({'kind': 'contractor', 'code': 'TCAT', 'name': 'Test Caterers', 'company': 'TST', 'company_name': 'Test Company'})!;
    expect(k.isContractor, isTrue);
    expect(k.company, 'TST');
  });
  test('anything else is not taken', () {
    expect(Door.from(null), isNull);
    expect(Door.from({'kind': 'other', 'code': 'TST'}), isNull);
    expect(Door.from({'kind': 'company', 'code': 'a b'}), isNull);
    expect(Door.from({'kind': 'company', 'code': 'TOOLONGCODE123'}), isNull);
  });
}
