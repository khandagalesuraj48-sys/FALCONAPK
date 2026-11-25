#!/usr/bin/env bash
# (25-11-2026) shorebird.yaml into pubspec.yaml's assets – ONLY in the build of FALCON's own app by Shorebird (build.yml release, patch.yml),
# never in the repository: RCL's ERP / HR app has FALCON's code inside as a package (its pubspec pin), and a new asset there would stop
# the ERP's own Shorebird patches. The release and every patch of it add it the same way, so their files are alike.
set -euo pipefail
python3 - <<'PY'
import re
p = 'pubspec.yaml'
s = open(p, encoding='utf-8').read()
if re.search(r'^\s*- shorebird\.yaml\s*$', s, re.M):
    print('shorebird.yaml is already in the assets')
    raise SystemExit
a = '  assets:\n'
if s.count(a) != 1:
    print('::error::pubspec.yaml: the "assets:" of flutter was not found once'); raise SystemExit(1)
open(p, 'w', encoding='utf-8').write(s.replace(a, a + '    - shorebird.yaml\n', 1))
print('shorebird.yaml added to the assets (this build only)')
PY
