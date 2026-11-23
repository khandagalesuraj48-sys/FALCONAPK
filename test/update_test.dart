// The update from inside the app (23-11-2026): which release is taken, which file, and what is never taken.
import 'package:falcon/core/update.dart';
import 'package:flutter_test/flutter_test.dart';

const _a = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _b = 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _c = 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Map<String, dynamic> release({int build = 42, bool pre = false, bool abi = true, String? notes}) => {
      'name': 'FALCON 1.0.0 (build $build)',
      'prerelease': pre,
      'draft': false,
      'body': '${notes != null ? '<!-- falcon-new -->\n$notes\n<!-- /falcon-new -->\n' : ''}'
          '<!-- falcon:{"build":$build,"version":"1.0.0","sha256":"$_a"${abi ? ',"apk":{"arm64-v8a":"$_b","armeabi-v7a":"$_c"}' : ''}} -->',
      'assets': [
        {'name': 'FALCON-1.0.0-$build.apk', 'browser_download_url': 'https://github.com/x/y/releases/download/v/FALCON-1.0.0-$build.apk'},
        if (abi) {'name': 'FALCON-1.0.0-$build.arm64-v8a.apk', 'browser_download_url': 'https://github.com/x/y/releases/download/v/FALCON-1.0.0-$build.arm64-v8a.apk'},
        if (abi) {'name': 'FALCON-1.0.0-$build.armeabi-v7a.apk', 'browser_download_url': 'https://github.com/x/y/releases/download/v/FALCON-1.0.0-$build.armeabi-v7a.apk'},
      ],
    };

void main() {
  tearDown(() => appAbi = () => 'arm64-v8a');

  test('a newer release: this phone\'s own processor\'s file and its fingerprint', () {
    appAbi = () => 'arm64-v8a';
    final u = parseRelease(release(), 40)!;
    expect(u.build, 42);
    expect(u.url, endsWith('.arm64-v8a.apk'));
    expect(u.sha256, _b);
  });

  test('a phone of 32 bits takes its own file', () {
    appAbi = () => 'armeabi-v7a';
    final u = parseRelease(release(), 40)!;
    expect(u.url, endsWith('.armeabi-v7a.apk'));
    expect(u.sha256, _c);
  });

  test('a processor not known, or a release without one-processor files: the file for every phone', () {
    appAbi = () => '';
    expect(parseRelease(release(), 40)!.url, endsWith('FALCON-1.0.0-42.apk'));
    appAbi = () => 'arm64-v8a';
    final u = parseRelease(release(abi: false), 40)!;
    expect(u.url, endsWith('FALCON-1.0.0-42.apk'));
    expect(u.sha256, _a);
  });

  test('the same build or an older one, a test build (pre-release), a release without its line: nothing', () {
    expect(parseRelease(release(), 42), isNull);
    expect(parseRelease(release(), 50), isNull);
    expect(parseRelease(release(pre: true), 1), isNull);
    expect(parseRelease({'name': 'x', 'body': 'no line', 'assets': []}, 1), isNull);
  });

  test('a file not on GitHub is never taken', () {
    final r = release(abi: false);
    (r['assets'] as List).first['browser_download_url'] = 'https://example.com/FALCON.apk';
    expect(parseRelease(r, 1), isNull);
  });

  test('what is new is shown; without it, the release\'s name', () {
    expect(parseRelease(release(notes: 'The meal screens · जेवणाची पाने'), 1)!.notes, 'The meal screens · जेवणाची पाने');
    expect(parseRelease(release(), 1)!.notes, 'FALCON 1.0.0 (build 42)');
  });

  test('offered again only after 10 minutes away', () {
    resetUpdateOffer();
    var asked = 0;
    updateAway();
    updateBack(() => asked++, now: DateTime.now().add(const Duration(minutes: 5)));
    expect(asked, 0);
    updateAway();
    updateBack(() => asked++, now: DateTime.now().add(const Duration(minutes: 11)));
    expect(asked, 1);
  });

  test('a download kept by the phone is read as it is', () {
    final s = BgUpdate.of({'id': 3, 'status': 'running', 'got': 50, 'total': 200, 'build': 42, 'version': '1.0.0', 'sha': _a, 'path': '/x.apk'})!;
    expect(s.going, isTrue);
    expect(s.percent, 25);
    expect(BgUpdate.of(const {}), isNull);
  });
}
