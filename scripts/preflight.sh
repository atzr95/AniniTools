#!/usr/bin/env bash
# preflight.sh — the mechanical checks, as a script, so every run gives the same answer.
# Copied into each project as scripts/preflight.sh by anini:project-setup; other anini skills call it.
#
#   scripts/preflight.sh [secrets] [placeholders] [screens] [review] [project] [release]   (no args = first five)
#   release = secrets + placeholders + project + fresh review with recorded launch checks
#   scripts/preflight.sh tree    → print one hash for the whole working tree (tracked + untracked, minus ignored)
#
# Exit: 0 = every check PASS · 1 = any FAIL · 2 = no FAIL, but a check could NOT RUN (never a pass).
# A line that contains "preflight: allow" is skipped — the inline waiver for a value meant to ship.
set -u
git rev-parse --git-dir >/dev/null 2>&1 || { echo "NOT RUN  not a git repo"; exit 2; }
cd "$(git rev-parse --show-toplevel)"

fail=0; notrun=0
pass()   { echo "PASS     $1"; }
failed() { echo "FAIL     $1"; fail=1; }
skip()   { echo "NOT RUN  $1"; notrun=1; }

# hits <ERE> <pathspec...> — matching lines in tracked + untracked (not ignored) files, waived lines removed
hits() {
  local re=$1 found status; shift
  found=$(git grep --untracked -nIE "$re" -- "$@" 2>/dev/null); status=$?
  if [ "$status" -gt 1 ]; then printf '%s\n' PREFLIGHT_SCAN_NOT_RUN; return; fi
  printf '%s\n' "$found" | grep -v 'preflight: allow'
}
# report <label> <hits> — FAIL with file:line only (never print the value: it may be a key).
# A sentinel survives command substitutions and filters when git cannot scan.
report() {
  case "$2" in
    *PREFLIGHT_SCAN_NOT_RUN*) skip "$1: git scan failed" ;;
    '') pass "$1" ;;
    *) failed "$1: $(echo "$2" | cut -d: -f1,2 | tr '\n' ' ')" ;;
  esac
}

# Files that ship in the binary or the site. Tests, docs and markdown never count.
CONFIG=(':(glob)**/AndroidManifest.xml' ':(glob)**/src/main/res/values/*.xml' ':(glob)**/Info.plist'
        ':(glob)**/GoogleService-Info.plist' ':(glob)**/google-services.json' ':(glob)**/fastlane/Appfile'
        ':(glob)**/app/build.gradle' ':(glob)**/app/build.gradle.kts' ':(glob)**/project.pbxproj' ':(glob)**/*.xcconfig')
CODE=(':(glob)**/lib/**' ':(glob)**/src/**' ':(glob)**/app/**' ':(glob)**/pages/**'
      ':(exclude,glob)**/test/**' ':(exclude,glob)**/integration_test/**' ':(exclude,glob)**/test_driver/**'
      ':(exclude,glob)**/__tests__/**' ':(exclude,glob)**/*_test.*' ':(exclude,glob)**/*.test.*' ':(exclude,glob)**/*.spec.*'
      ':(exclude,glob)**/*.md')
# Paths whose change does not make a code review stale.
NOT_CODE=(':(exclude)store' ':(exclude)screenshots' ':(exclude)videos' ':(exclude)marketing'
          ':(exclude)design' ':(exclude)promo' ':(exclude)PUBLISH-CHECK.html' ':(exclude,glob)**/fastlane/metadata/**'
          ':(exclude,glob)**/*.md')

tree_hash() {
  local idx tree
  idx=$(mktemp) || return 2
  if [ -f "$(git rev-parse --git-path index)" ]; then
    cp "$(git rev-parse --git-path index)" "$idx" || { rm -f "$idx"; return 2; }
  else
    rm -f "$idx"
  fi
  if ! GIT_INDEX_FILE=$idx git add -A . >/dev/null 2>&1; then
    rm -f "$idx"; return 2
  fi
  tree=$(GIT_INDEX_FILE=$idx git write-tree) || { rm -f "$idx"; return 2; }
  rm -f "$idx"
  printf '%s\n' "$tree"
}

SECRET_PATTERN='(^|[^A-Za-z0-9_-])(AIza[0-9A-Za-z_-]{35}|sk-[A-Za-z0-9_-]{20,}|(sk|rk)_(live|test)_[A-Za-z0-9]{16,}|re_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{22,}|(AKIA|ASIA)[A-Z0-9]{16}|xox[baprs]-[A-Za-z0-9-]{15,})|-----BEGIN [A-Z ]*PRIVATE KEY'
check_secrets() {
  # Firebase client config holds a public AIza key by design, so those three files are left out.
  report "secrets: live keys in git" "$(hits "$SECRET_PATTERN" \
    . ':(exclude,glob)**/google-services.json' ':(exclude,glob)**/GoogleService-Info.plist' ':(exclude,glob)**/firebase_options.dart')"
  local envs
  envs=$( { git ls-files; git ls-files --others --exclude-standard; } | grep -E '(^|/)\.env' | grep -vE '\.(example|sample|template)$')
  if [ -n "$envs" ]; then failed "secrets: .env file in git or not ignored: $(echo "$envs" | tr '\n' ' ')"; else pass "secrets: .env files ignored"; fi
}

# Scan shipped values. Comment-only lines and explicit waivers are excluded.
# An environment fallback can still ship when unset, so it receives no exemption.
TEST_AD='ca-app-pub-3940256099942544'
COMMENT='^[^:]+:[0-9]+:[[:space:]]*(//|#|\*|/\*|<!--)|-->[[:space:]]*$'
BAD_VALUE='3940256099942544|localhost|127\.0\.0\.1|ngrok|YOUR_|example\.com|CHANGEME|TODO'
shipped() { hits "$@" | grep -vE "$COMMENT"; }

# A file-wide debug/environment mention cannot prove that a particular value is safe.
# Recognize only local debug guards and directly connected Dart environment fallbacks.
# Shell release commands are read, never executed; unresolved values fail closed.
code_hits() {
  local label=$1 re=$2 result status output
  command -v python3 >/dev/null 2>&1 || { skip "placeholders: $label needs python3"; return; }
  output=$(mktemp) || { skip "placeholders: cannot create temporary file"; return; }
  python3 - "$re" "${CODE[@]}" > "$output" <<'PYCODE'
import json
import re
import shlex
import subprocess
import sys
from pathlib import Path

bad_value = re.compile(r"3940256099942544|localhost|127\.0\.0\.1|10\.0\.2\.2|ngrok|YOUR_|example\.com|CHANGEME|TODO", re.I)
pattern, *paths = sys.argv[1:]
scan = subprocess.run(['git', 'grep', '--untracked', '-nIE', pattern, '--', *paths], capture_output=True, text=True)
if scan.returncode not in (0, 1):
    sys.exit(2)
files = subprocess.run(['git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'], capture_output=True, check=True).stdout.decode().split('\0')

# Only literal assignments in a script can establish values. Do not trust this
# check's own environment, or execute a project script to obtain its secrets.
def resolve(value, variables):
    def replace(match):
        return variables.get(match.group(1) or match.group(2), '$UNRESOLVED')
    value = re.sub(r'\$\{([A-Za-z_][A-Za-z0-9_]*)\}|\$([A-Za-z_][A-Za-z0-9_]*)', replace, value)
    return value if not re.search(r'[$`]', value) else None

def release_defines(app):
    builds = []
    for name in sorted(set(files)):
        if not re.search(r'(^|/)scripts/[^/]+\.sh$', name):
            continue
        # A nested application's script must not protect a different app.
        owner = name.rsplit('/scripts/', 1)[0] if '/scripts/' in name else '.'
        if owner not in ('.', app):
            continue
        variables = {}
        script = Path(name).read_text().replace('\\\n', ' ')
        # Shell branches, loops, functions and sourced/evaluated code require
        # execution context. Never treat their assignments as unconditional.
        unsupported = False
        for line in script.splitlines():
            try:
                words = shlex.split(line, comments=True)
            except ValueError:
                unsupported = True
                break
            if any(w in {'if', 'then', 'else', 'elif', 'fi', 'for', 'while', 'until', 'do', 'done', 'case', 'esac', 'function', '{', '}', '(', ')', '&&', '||', ';', '&', '|'} for w in words):
                unsupported = True
            if words[:1] and words[0] in {'source', '.', 'eval', 'read', 'unset'}:
                unsupported = True
            if re.match(r'\s*[A-Za-z_]\w*\s*\(\s*\)', line):
                unsupported = True
        if unsupported:
            if re.search(r'\bflutter\s+build\b', script):
                builds.append({})
            continue
        for line in script.splitlines():
            # shlex removes quoting. Literal dollars must never become variables.
            if re.search(r"'[^']*[$`][^']*'|\\\$", line):
                variables.clear()
                continue
            try:
                tokens = shlex.split(line, comments=True)
            except ValueError:
                continue
            assignments = tokens[1:] if tokens[:1] == ['export'] else tokens
            if len(assignments) == 1 and re.match(r'^[A-Za-z_][A-Za-z0-9_]*=', assignments[0]):
                key, value = assignments[0].split('=', 1)
                variables[key] = resolve(value, variables) or '$UNRESOLVED'
                continue
            if tokens[:1] != ['flutter']:
                continue
            at = 0
            args = tokens[at + 1:]
            if args[:1] != ['build'] or '--debug' in args or '--profile' in args:
                continue
            values = {}
            i = 1
            while i < len(args):
                token = args[i]
                i += 1
                option, separator, value = token.partition('=')
                if option not in ('--dart-define', '--dart-define-from-file'):
                    continue
                if not separator and i < len(args):
                    value = args[i]
                    i += 1
                value = resolve(value, variables)
                if not value:
                    continue
                if option == '--dart-define':
                    key, separator, definition = value.partition('=')
                    if separator:
                        values[key] = definition
                else:
                    candidates = [Path(app) / value, Path(value)]
                    source = next((p for p in candidates if p.is_file()), None)
                    if source is None:
                        continue
                    text = source.read_text()
                    try:
                        data = json.loads(text)
                        if isinstance(data, dict):
                            values.update({k: str(v) for k, v in data.items()})
                    except ValueError:
                        for entry in text.splitlines():
                            try:
                                entries = shlex.split(entry, comments=True)
                            except ValueError:
                                continue
                            if entries[:1] == ['export']:
                                entries = entries[1:]
                            if len(entries) == 1 and '=' in entries[0]:
                                key, definition = entries[0].split('=', 1)
                                values[key] = resolve(definition, {}) or ''
            builds.append(values)
    return builds

def real_define(key, app):
    builds = release_defines(app)
    return bool(builds) and all(b.get(key) and not bad_value.search(b[key]) for b in builds)

# Split a source line into statements to prevent a neighbouring debug log from
# excusing an unrelated assignment. Complex control flow needs an inline waiver.
def debug_guard(line):
    if re.search(r'if\s*\(\s*(kDebugMode|kProfileMode|!\s*kReleaseMode)\s*\)\s*(?:\{\s*)?(?:return\b|[A-Za-z_][\w.]*\s*=)', line):
        return True
    ternary = re.search(r"(?:kDebugMode|kProfileMode|!\s*kReleaseMode)\s*\?\s*(['\"])(.*?)\1\s*:", line)
    positions = [m.start() for m in re.finditer(pattern, line)]
    return bool(ternary and positions and all(ternary.start(2) <= p < ternary.end(2) for p in positions))

bad = []
for hit in scan.stdout.splitlines():
    # Git's -z output is unnecessary here: split from the right-hand numeric line
    # marker, so spaces and colons inside ordinary filenames stay intact.
    match = re.match(r'^(.*?):([0-9]+):(.*)$', hit)
    if not match:
        sys.exit(2)
    name, number, line = match.groups()
    if 'preflight: allow' in line or re.match(r'\s*(//|#|\*|/\*|<!--)', line) or re.search(r'-->\s*$', line):
        continue
    text = Path(name).read_text()
    lines = text.splitlines(keepends=True)
    offset = sum(map(len, lines[:int(number) - 1]))
    app = name.split('/lib/', 1)[0] if '/lib/' in name else '.'
    protected = False
    # Values on this line must belong to the guard's immediate statement.
    statements = line.split(';')
    offending = [s for s in statements if re.search(pattern.replace('[[:space:]]', r'\s'), s)]
    if offending and all(debug_guard(s) for s in offending):
        protected = True
    # Only an environment call enclosing the value counts as a direct default.
    for call in re.finditer(r'(?:String|bool|int)\.fromEnvironment\(\s*[\'"]([A-Za-z0-9_]+)[\'"][^()]*\)', text, re.S):
        if call.start() <= offset + len(line) and call.end() > offset and bad_value.search(call.group()) and real_define(call.group(1), app):
            # No other unsafe statement on this line may borrow its protection.
            value_positions = [offset + m.start() for m in re.finditer(pattern, line)]
            if value_positions and all(call.start() <= p < call.end() for p in value_positions):
                protected = True
    # A named test constant may be used only as the fallback of the environment
    # value. Every use must be that guarded fallback (excluding its declaration).
    declaration = re.search(r'\b(?:const|final)\s+(?:String\s+)?([A-Za-z_]\w*)\s*=', line)
    if not protected and declaration:
        test_name = declaration.group(1)
        for env in re.finditer(r'\b(?:const|final)\s+(?:String\s+)?([A-Za-z_]\w*)\s*=\s*String\.fromEnvironment\(\s*[\'"]([A-Za-z0-9_]+)[\'"]', text):
            real_name, key = env.groups()
            fallback = re.compile(r'\b' + re.escape(real_name) + r'\.isNotEmpty\s*\?\s*' + re.escape(real_name) + r'\s*:\s*' + re.escape(test_name) + r'\b')
            uses = list(re.finditer(r'\b' + re.escape(test_name) + r'\b', text))
            ranges = [(m.start(), m.end()) for m in fallback.finditer(text)]
            if len(uses) > 1 and all(u.start() == offset + declaration.start(1) or any(a <= u.start() < b for a, b in ranges) for u in uses) and real_define(key, app):
                protected = True
    if not protected:
        bad.append(f'{name}:{number}')
print(' '.join(bad))
PYCODE
  status=$?
  result=$(cat "$output")
  rm -f "$output"
  if [ "$status" != 0 ]; then skip "placeholders: $label could not be checked";
  elif [ -n "$result" ]; then failed "placeholders: $label: $result";
  else pass "placeholders: $label"; fi
}

check_placeholders() {
  report "placeholders: Google test AdMob id in shipped config" "$(shipped "$TEST_AD" "${CONFIG[@]}")"
  code_hits "Google test AdMob id with no release switch" "$TEST_AD"
  report "placeholders: com.example app id" \
    "$(shipped '(applicationId|namespace|PRODUCT_BUNDLE_IDENTIFIER|app_identifier|package=)[^,;]*com\.example' "${CONFIG[@]}" | grep -v 'RunnerTests')"
  report "placeholders: TODO/YOUR_/CHANGEME value in shipped config" \
    "$(shipped '(TODO|FIXME|CHANGEME|PLACEHOLDER|YOUR_[A-Z_]+|XXXX|<insert|example\.com)' "${CONFIG[@]}")"
  report "placeholders: cleartext traffic allowed" "$(shipped 'usesCleartextTraffic="true"' "${CONFIG[@]}")"
  # a fixed host:port is a dev server; a port filled in at runtime (localhost:$port) is an in-app server
  code_hits "dev endpoint with no release switch" "(https?|wss?)://(localhost|127\.0\.0\.1|10\.0\.2\.2)(:[0-9]|/|['\"]|\$)|ngrok"
  code_hits "test devices with no release switch" 'testDeviceIds'
  report "placeholders: release build signed with the debug key" \
    "$(shipped 'signingConfig[[:space:]=]+signingConfigs\.(debug|getByName\("debug"\))' ':(glob)**/app/build.gradle' ':(glob)**/app/build.gradle.kts')"
}

# UX.md's screen table has a Ref column; each Ref needs design/refs/<Ref>.png or <Ref>--<state>.png.
check_screens() {
  local ux="" f r refs missing="" n=0
  for f in UX.md docs/UX.md; do [ -f "$f" ] && { ux=$f; break; }; done
  [ -n "$ux" ] || { skip "screens: no UX.md"; return; }
  refs=$(awk '/^[ \t]*\|/ { n = split($0, c, "|")
      if (!col) { for (i = 2; i < n; i++) { x = c[i]; gsub(/^[ \t]+|[ \t]+$/, "", x); if (tolower(x) == "ref") col = i }; next }
      x = c[col]; gsub(/^[ \t`]+|[ \t`]+$/, "", x); if (x != "" && x !~ /^:?-+:?$/) print x; next }
    col { exit }' "$ux")
  [ -n "$refs" ] || { skip "screens: $ux has no screen table with a Ref column — check design/refs by hand"; return; }
  for r in $refs; do
    n=$((n + 1))
    [ -f "design/refs/$r.png" ] || ls "design/refs/$r--"*.png >/dev/null 2>&1 || missing="$missing $r"
  done
  if [ -n "$missing" ]; then failed "screens: no design/refs PNG for:$missing"; else pass "screens: all $n screens have a design/refs PNG"; fi
}

# Shared verification tables preserve pending gates when the host changes.
# Legacy ledgers need a new review to record the verification evidence.
check_verification() {
  local output result status
  grep -qiE '^##[[:space:]]+Verification checks[[:space:]]*$' REVIEW.md 2>/dev/null || { skip "review: legacy ledger has no verification checks — re-run review"; return 2; }
  command -v python3 >/dev/null 2>&1 || { skip "review: verification tables need python3"; return 2; }
  output=$(mktemp) || { skip "review: cannot create temporary file"; return 2; }
  python3 - "${1:-}" > "$output" <<'PYGATES'
import re
import sys
from pathlib import Path

issues = []
incomplete = False
launch_found = False
for name, heading in [('TASKS.md', 'verification gates'), ('REVIEW.md', 'verification checks')]:
    path = Path(name)
    if not path.is_file():
        continue
    active = False
    columns = None
    rows = 0
    for number, line in enumerate(path.read_text().splitlines(), 1):
        if line.startswith('## '):
            if active and not rows:
                issues.append(f'{name}: empty verification table')
                incomplete = True
            active = line[3:].strip().lower() == heading
            columns = None
            rows = 0
            continue
        if not active or not line.strip().startswith('|'):
            continue
        cells = [cell.replace(r'\|', '|').strip().strip('`').strip() for cell in re.split(r'(?<!\\)\|', line.strip().strip('|'))]
        if all(re.fullmatch(r':?-+:?', cell) for cell in cells):
            continue
        if columns is None:
            columns = [cell.lower() for cell in cells]
            if not all(key in columns for key in ['check', 'command/procedure', 'result', 'evaluation mode', 'evidence / reason']):
                issues.append(f'{name}:{number}: invalid verification columns')
                incomplete = True
                columns = []
            continue
        if not columns:
            continue
        rows += 1
        if len(cells) != len(columns):
            issues.append(f'{name}:{number}: incomplete verification row')
            incomplete = True
            continue
        row = dict(zip(columns, cells))
        if name == 'REVIEW.md' and row['check'].lower() == 'launch checks':
            launch_found = True
        result = row['result'].upper()
        mode = row['evaluation mode'].lower()
        evidence = row['evidence / reason']
        independent = 'independent' in (row['check'] + ' ' + row['command/procedure']).lower()
        if result == 'WAIVED':
            if mode != 'user' or not evidence:
                issues.append(f'{name}:{number}: waiver needs user mode and reason')
        elif result != 'PASS':
            issues.append(f'{name}:{number}: required verification is {result or "NOT RUN"}')
            if result != 'FAIL':
                incomplete = True
        elif mode not in {'executable', 'independent', 'self-review', 'user'} or not evidence or not row['command/procedure']:
            issues.append(f'{name}:{number}: PASS needs procedure, mode and evidence')
        elif independent and mode != 'independent':
            issues.append(f'{name}:{number}: independent check lacks independent evaluation')
    if active and not rows:
        issues.append(f'{name}: empty verification table')
        incomplete = True
if sys.argv[1] == 'release' and not launch_found:
    issues.append('REVIEW.md: launch checks missing — run anini:ship --prepare, then anini:review --launch')
    incomplete = True
print('; '.join(issues))
raise SystemExit(2 if incomplete else 1 if issues else 0)
PYGATES
  status=$?
  result=$(cat "$output"); rm -f "$output"
  if [ "$status" = 1 ]; then failed "review: $result"; return 1;
  elif [ "$status" = 2 ]; then skip "review: $result"; return 2;
  elif [ "$status" != 0 ]; then skip "review: verification tables could not be checked"; return 2;
  fi
}

# REVIEW.md verdict must be SAFE and the code must not have changed since its Tree hash.
check_review() {
  local t now changed legal_changed real="" f
  [ -f REVIEW.md ] || { failed "review: no REVIEW.md — run anini:review"; return; }
  grep -q '^Verdict: SAFE TO RELEASE' REVIEW.md || { failed "review: verdict is not SAFE TO RELEASE — $(grep -m1 '^Verdict:' REVIEW.md)"; return; }
  check_verification "${1:-}" || return
  t=$(sed -n 's/.*Tree: \([0-9a-f]\{40\}\).*/\1/p' REVIEW.md | head -1)
  [ -n "$t" ] || { skip "review: REVIEW.md has no Tree: hash — re-run anini:review"; return; }
  git cat-file -e "$t^{tree}" 2>/dev/null || { failed "review: the reviewed tree is gone from git — re-run anini:review"; return; }
  now=$(tree_hash) || { skip "review: could not hash the working tree"; return; }
  changed=$(git diff --name-only "$t" "$now" -- . "${NOT_CODE[@]}") || { skip "review: could not compare the reviewed tree"; return; }
  # Legal Markdown is release content even though ordinary documentation is excluded.
  legal_changed=$(git diff --name-only "$t" "$now" -- ':(icase,glob)**/*privacy*' ':(icase,glob)**/*terms*' ':(icase,glob)**/*legal*' ':(icase,glob)**/*eula*') || { skip "review: could not compare legal files"; return; }
  [ -z "$legal_changed" ] || real=" legal files: $legal_changed"
  for f in $changed; do
    case "$f" in  # a version-only bump in pubspec.yaml / package.json does not count
      pubspec.yaml|*/pubspec.yaml|package.json|*/package.json)
        git diff -U0 "$t" "$now" -- "$f" | grep -E '^[+-]' | grep -vE '^(\+\+\+|---)' \
          | grep -qvE '^[+-][[:space:]]*"?version"?[[:space:]]*:' || continue ;;
    esac
    real="$real $f"
  done
  if [ -n "$real" ]; then failed "review: code changed since the review:$real — re-run anini:review"; else pass "review: SAFE, no code change since"; fi
}

# Project checks: one line per mistake this project made twice (anini:build, anini:review, anini:debug and anini:retro add them).
# Shape: report "project: <what it catches>" "$(hits '<ERE>' "${CODE[@]}")"
check_project() { :; }

[ "${1:-}" = tree ] && { tree_hash; exit $?; }
for c in ${*:-secrets placeholders screens review project}; do
  case $c in
    secrets) check_secrets ;; placeholders) check_placeholders ;; screens) check_screens ;;
    review) check_review ;; project) check_project ;;
    release) check_secrets; check_placeholders; check_project; check_review release ;;
    *) echo "unknown check: $c (secrets placeholders screens review project release tree)" >&2; exit 64 ;;
  esac
done
[ $fail = 1 ] && exit 1
[ $notrun = 1 ] && exit 2
exit 0

