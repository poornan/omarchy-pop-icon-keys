#!/bin/bash
# Runs setup, uninstall and the status helper in throwaway HOME folders, with
# stand-ins for solaar, pgrep, setsid and hyprctl. Never touches your real
# config or your running Solaar.
#
#   tests/test_setup.sh                  run everything
#   POP_TEST_KEEP=1 tests/test_setup.sh  keep the sandbox folders and outputs
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pop-icon-keys-test.XXXXXX")
STUBS="$WORK/stubs"
FAILS=0
CHECKS=0

cleanup() {
  for f in "$WORK"/*/state/pid; do [[ -f $f ]] && kill "$(cat "$f")" 2>/dev/null; done
  if [[ -n ${POP_TEST_KEEP:-} ]]; then echo "outputs kept in $WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT

ok() { CHECKS=$((CHECKS + 1)); echo "  ok   $1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1)); echo "  FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

# --- stand-ins ---------------------------------------------------------------
mkdir -p "$STUBS"
# pgrep -x solaar: the fake Solaar is a real background process whose pid is in $STATE/pid.
cat >"$STUBS/pgrep" <<'EOF'
#!/bin/bash
[[ -f $STATE/pid ]] && kill -0 "$(cat "$STATE/pid")" 2>/dev/null && { cat "$STATE/pid"; exit 0; }
exit 1
EOF
# setsid -f solaar ...: start the fake Solaar (STUBBORN=1 makes it ignore SIGTERM).
cat >"$STUBS/setsid" <<'EOF'
#!/bin/bash
if [[ ${STUBBORN:-0} == 1 ]]; then
  nohup bash -c 'trap "" TERM; while :; do sleep 1; done' >/dev/null 2>&1 &
else
  nohup sleep 1000 >/dev/null 2>&1 &
fi
echo $! >"$STATE/pid"
echo start >>"$STATE/log"
EOF
cat >"$STUBS/solaar" <<'EOF'
#!/bin/bash
echo "solaar $*" >>"$STATE/log"
[[ $1 == show && -n ${FIXTURE:-} ]] && cat "$FIXTURE"
exit 0
EOF
cat >"$STUBS/hyprctl" <<'EOF'
#!/bin/bash
echo "hyprctl $*" >>"$STATE/log"
exit "${HYPR_RC:-0}"
EOF
printf '#!/bin/bash\nexit 0\n' >"$STUBS/omarchy-pkg-add"
chmod +x "$STUBS"/*

CONFIG_YAML='- 1.1.20
- _NAME: MX Keys for Mac
  divert-keys: {10: 0, 13: 0}
  fn-swap: true
- _NAME: POP Icon Keys
  _battery: 4100
  divert-keys: {110: 0, 199: 0, 200: 0, 212: 0, 231: 0,
    259: 0, 264: 0, 266: 0, 321: 0}
  fn-swap: true
- _NAME: MX Master 4
  divert-keys: {82: 0}'

RULES_YAML='%YAML 1.3
---
# my own rule
- Key: [Volume Up, pressed]
- Execute: [notify-send, up]
...'

BINDINGS_LUA='-- my bindings
o.bind("SUPER + X", "Mine", "mine")'

AUTOSTART_LUA='-- my autostart
o.launch_on_start("mako")'

# new_home NAME: a fresh sandbox with the default files; sets HOME, STATE, PATH.
new_home() {
  export HOME="$WORK/$1" STATE="$WORK/$1/state"
  unset XDG_CONFIG_HOME
  mkdir -p "$HOME/.config/solaar" "$HOME/.config/hypr" "$STATE"
  printf '%s\n' "$CONFIG_YAML" >"$HOME/.config/solaar/config.yaml"
  printf '%s\n' "$RULES_YAML" >"$HOME/.config/solaar/rules.yaml"
  printf '%s\n' "$BINDINGS_LUA" >"$HOME/.config/hypr/bindings.lua"
  printf '%s\n' "$AUTOSTART_LUA" >"$HOME/.config/hypr/autostart.lua"
  export PATH="$STUBS:$ORIG_PATH"
  STUBBORN=0 setsid -f solaar  # Solaar is running when setup starts
  : >"$STATE/log"
}
ORIG_PATH=$PATH
C() { echo "$HOME/.config/$1"; }
divert_of() { grep -A3 "_NAME: POP Icon Keys" "$(C solaar/config.yaml)" | tr -d '\n' | grep -oE "$1: [0-9]+" | head -1 | cut -d' ' -f2; }
backups() { find "$HOME/.config" -name "*.bak.pop-icon-keys.*" | wc -l; }
sums() { (cd "$HOME/.config" && sha256sum solaar/config.yaml solaar/rules.yaml hypr/bindings.lua hypr/autostart.lua); }

echo "setup twice, then uninstall"
new_home t1
cp -r "$HOME/.config" "$WORK/t1.orig"
"$ROOT/setup" --yes >"$WORK/t1.out" 2>&1; rc=$?
check "setup exits 0" "[[ $rc == 0 ]]"
check "one rules block" "[[ \$(grep -c '^# BEGIN pop-icon-keys' \"$(C solaar/rules.yaml)\") == 1 ]]"
check "user rule kept" "grep -q 'notify-send, up' \"$(C solaar/rules.yaml)\""
check "rules file still parses" "python3 -c 'import yaml,sys; list(yaml.safe_load_all(open(sys.argv[1])))' \"$(C solaar/rules.yaml)\" 2>/dev/null"
check "Dictation diverted" "[[ \$(divert_of 259) == 1 ]]"
check "Show Desktop diverted" "[[ \$(divert_of 110) == 1 ]]"
check "unrelated key kept" "[[ \$(divert_of 321) == 0 ]]"
check "other device untouched" "grep -q '{10: 0, 13: 0}' \"$(C solaar/config.yaml)\""
check "lock bind added" "grep -q 'SUPER + CTRL + Q' \"$(C hypr/bindings.lua)\""
check "autostart added" "grep -q 'solaar --window=hide' \"$(C hypr/autostart.lua)\""
check "helper installed" "[[ -x $HOME/.local/bin/pop-icon-keys-show-desktop ]]"
check "Solaar running after setup" "[[ -n \$(pgrep -x solaar) ]]"
b1=$(backups)
"$ROOT/setup" --yes >"$WORK/t1b.out" 2>&1; rc=$?
check "second setup exits 0" "[[ $rc == 0 ]]"
check "still one rules block" "[[ \$(grep -c '^# BEGIN pop-icon-keys' \"$(C solaar/rules.yaml)\") == 1 ]]"
check "still one lock block" "[[ \$(grep -c '^-- BEGIN pop-icon-keys' \"$(C hypr/bindings.lua)\") == 1 ]]"
check "no new backups when nothing changed ($b1)" "[[ \$(backups) == $b1 ]]"
"$ROOT/uninstall" --yes >"$WORK/t1c.out" 2>&1; rc=$?
check "uninstall exits 0" "[[ $rc == 0 ]]"
check "rules restored exactly" "cmp -s \"$(C solaar/rules.yaml)\" \"$WORK/t1.orig/solaar/rules.yaml\""
check "bindings restored exactly" "cmp -s \"$(C hypr/bindings.lua)\" \"$WORK/t1.orig/hypr/bindings.lua\""
check "autostart restored exactly" "cmp -s \"$(C hypr/autostart.lua)\" \"$WORK/t1.orig/hypr/autostart.lua\""
check "keys back to Regular" "[[ \$(divert_of 259) == 0 && \$(divert_of 110) == 0 ]]"
check "helper removed" "[[ ! -e $HOME/.local/bin/pop-icon-keys-show-desktop ]]"
check "Solaar running after uninstall" "[[ -n \$(pgrep -x solaar) ]]"

echo "a hand-deleted END marker stops setup before any change"
new_home t2
printf 'a=1\n-- BEGIN pop-icon-keys\nUSER_LINE_1\nUSER_LINE_2\n' >"$(C hypr/bindings.lua)"
before=$(sums)
"$ROOT/setup" --yes >"$WORK/t2.out" 2>&1; rc=$?
check "setup fails" "[[ $rc != 0 ]]"
check "explains the marker problem" "grep -q 'expected one of each' \"$WORK/t2.out\""
check "no file changed" "[[ \"\$(sums)\" == \"$before\" ]]"
check "Solaar never stopped" "! grep -q '^start' \"$STATE/log\""
"$ROOT/uninstall" --yes >"$WORK/t2b.out" 2>&1; rc=$?
check "uninstall also refuses" "[[ $rc != 0 ]] && [[ \"\$(sums)\" == \"$before\" ]]"

echo "CRLF and block position are kept"
new_home t3
printf 'top\r\n-- BEGIN pop-icon-keys\r\nold\r\n-- END pop-icon-keys\r\nbottom\r\n' >"$(C hypr/bindings.lua)"
"$ROOT/setup" --yes >"$WORK/t3.out" 2>&1
check "CRLF kept" "! grep -qv \$'\\r\$' \"$(C hypr/bindings.lua)\""
check "block stays above 'bottom'" "[[ \$(tr -d '\\r' <\"$(C hypr/bindings.lua)\" | tail -1) == bottom ]]"
check "old block content replaced" "! grep -q '^old' \"$(C hypr/bindings.lua)\""

echo "two saved entries for the keyboard, one in block style"
new_home t4
cat >"$(C solaar/config.yaml)" <<'EOF'
- 1.1.20
- _NAME: POP Icon Keys
  divert-keys:
    110: 0
    999: 1
  fn-swap: true
- _NAME: POP Icon Keys
  divert-keys: {259: 0}
EOF
"$ROOT/setup" --yes >"$WORK/t4.out" 2>&1; rc=$?
check "setup exits 0" "[[ $rc == 0 ]]"
check "both entries diverted" "[[ \$(grep -c '110: 1, 212: 1, 259: 1, 264: 1, 266: 1' \"$(C solaar/config.yaml)\") == 2 ]]"
check "block-style extra key kept" "grep -q '999: 1' \"$(C solaar/config.yaml)\""
check "config still parses" "python3 -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' \"$(C solaar/config.yaml)\""

echo "a divert-keys id that is not a number"
new_home t5
sed -i 's/{110: 0,/{foo: 1, 110: 0,/' "$(C solaar/config.yaml)"
before=$(sums)
"$ROOT/setup" --yes >"$WORK/t5.out" 2>&1; rc=$?
check "setup fails clearly" "[[ $rc != 0 ]] && grep -q 'not a number' \"$WORK/t5.out\""
check "no file changed" "[[ \"\$(sums)\" == \"$before\" ]]"
check "Solaar started again" "[[ -n \$(pgrep -x solaar) ]]"

echo "Hyprland reload fails"
new_home t6
HYPR_RC=1 "$ROOT/setup" --yes >"$WORK/t6.out" 2>&1; rc=$?
check "setup still finishes" "[[ $rc == 0 ]] && grep -q '^Done' \"$WORK/t6.out\""
check "warns about the reload" "grep -q 'could not reload Hyprland' \"$WORK/t6.out\""

echo "keyboard never seen by Solaar"
new_home t7
printf '%s\n' '- 1.1.20' '- _NAME: MX Master 4' '  divert-keys: {82: 0}' >"$(C solaar/config.yaml)"
"$ROOT/setup" --yes >"$WORK/t7.out" 2>&1; rc=$?
check "exit 2 (partly applied)" "[[ $rc == 2 ]] && grep -q 'Partly applied' \"$WORK/t7.out\""
check "Solaar running at the end" "[[ -n \$(pgrep -x solaar) ]]"

echo "Solaar refuses to stop"
new_home t8
kill "$(cat "$STATE/pid")"; STUBBORN=1 setsid -f solaar
before=$(sums)
"$ROOT/setup" --yes >"$WORK/t8.out" 2>&1; rc=$?
check "setup fails" "[[ $rc != 0 ]] && grep -q 'did not stop' \"$WORK/t8.out\""
check "no file changed" "[[ \"\$(sums)\" == \"$before\" ]]"
kill -9 "$(cat "$STATE/pid")" 2>/dev/null

echo "declining, and no terminal"
new_home t9
before=$(sums)
script -qec "$ROOT/setup" /dev/null <<<"n" >"$WORK/t9.out" 2>&1; rc=$?
check "decline exits 0" "[[ $rc == 0 ]] && grep -q 'Nothing changed' \"$WORK/t9.out\""
"$ROOT/setup" </dev/null >"$WORK/t9b.out" 2>&1; rc=$?
check "no terminal and no --yes refuses" "[[ $rc != 0 ]] && grep -q 're-run with --yes' \"$WORK/t9b.out\""
"$ROOT/setup" --dry-run >"$WORK/t9c.out" 2>&1; rc=$?
check "dry run exits 0 with a diff" "[[ $rc == 0 ]] && grep -q 'would change' \"$WORK/t9c.out\""
check "nothing changed by any of them" "[[ \"\$(sums)\" == \"$before\" ]]"
check "Solaar never stopped" "! grep -q '^start' \"$STATE/log\""

echo "rules rewritten by Solaar's editor (markers gone)"
new_home t10
cat >"$(C solaar/rules.yaml)" <<EOF
%YAML 1.3
---
- Key:
  - Dictation
  - pressed
- Execute:
  - omarchy-dictation
  - toggle
...
---
- Key:
  - Show Desktop
  - pressed
- Execute:
  - $HOME/.local/bin/pop-icon-keys-show-desktop
...
---
- Key:
  - Emoji
  - pressed
- Execute:
  - my-own-emoji-tool
...
EOF
"$ROOT/uninstall" --yes >"$WORK/t10.out" 2>&1
check "plugin copies removed" "! grep -q 'omarchy-dictation' \"$(C solaar/rules.yaml)\" && ! grep -q 'pop-icon-keys-show-desktop' \"$(C solaar/rules.yaml)\""
check "user's own Emoji rule kept" "grep -q 'my-own-emoji-tool' \"$(C solaar/rules.yaml)\""
new_home t10b
"$ROOT/setup" --yes >"$WORK/t10b.out" 2>&1
printf '%s\n' '---' '- Key:' '  - Dictation' '  - pressed' '- Execute:' '  - omarchy-dictation' '  - toggle' '...' >>"$(C solaar/rules.yaml)"
"$ROOT/setup" --yes >"$WORK/t10c.out" 2>&1
check "setup drops an earlier copy instead of warning" "[[ \$(grep -c 'omarchy-dictation' \"$(C solaar/rules.yaml)\") == 1 ]] && ! grep -q 'other rules of yours' \"$WORK/t10c.out\""

echo "backups: newest 3 kept"
new_home t11
for i in 1 2 3 4 5; do
  printf -- '-- run %s\n' "$i" >>"$(C hypr/bindings.lua)"
  "$ROOT/setup" --yes >/dev/null 2>&1
  sleep 1
done
check "at most 3 bindings backups" "[[ \$(ls \"$(C hypr)\" | grep -c 'bindings.lua.bak.pop-icon-keys') -le 3 ]]"

echo "status helper on real solaar show output"
new_home t12
for case in routed dropped not-setup; do
  FIXTURE="$ROOT/tests/fixtures/solaar-show-$case.txt" "$ROOT/bin/pop-icon-keys-status" >"$WORK/status-$case.out"
done
s() { grep "^$2=" "$WORK/status-$1.out" | cut -d= -f2-; }
all="Show Desktop,MultiPlatform Search,Dictation,Emoji,Screen Capture"
check "routed: battery 100" "[[ \$(s routed battery) == 100 ]]"
check "routed: all live" "[[ \"\$(s routed diverted)\" == \"$all\" ]]"
check "routed: nothing missing or inactive" "[[ -z \$(s routed missing) && -z \$(s routed inactive) ]]"
check "dropped: none live" "[[ -z \$(s dropped diverted) ]]"
check "dropped: all saved" "[[ \"\$(s dropped saved)\" == \"$all\" ]]"
check "dropped: all inactive, none missing" "[[ \"\$(s dropped inactive)\" == \"$all\" && -z \$(s dropped missing) ]]"
check "not-setup: two missing" "[[ \"\$(s not-setup missing)\" == 'Show Desktop,Dictation' ]]"
check "not-setup: three inactive" "[[ \"\$(s not-setup inactive)\" == 'MultiPlatform Search,Emoji,Screen Capture' ]]"
check "running detected" "[[ \$(s routed running) == 1 ]]"
FIXTURE=/dev/null "$ROOT/bin/pop-icon-keys-status" >"$WORK/status-away.out"
check "keyboard away: not connected, nothing flagged" "grep -qx 'connected=0' \"$WORK/status-away.out\" && grep -qx 'missing=' \"$WORK/status-away.out\" && grep -qx 'inactive=' \"$WORK/status-away.out\""

echo "restore helper"
"$ROOT/bin/pop-icon-keys-restore" Dictation Emoji >/dev/null
check "asks Solaar for exactly the dropped keys" "grep -qx 'solaar config POP Icon Keys divert-keys Dictation Diverted' \"$STATE/log\" && grep -qx 'solaar config POP Icon Keys divert-keys Emoji Diverted' \"$STATE/log\" && [[ \$(grep -c 'solaar config' \"$STATE/log\") == 2 ]]"

echo
if (( FAILS )); then echo "$FAILS of $CHECKS checks FAILED"; exit 1; fi
echo "ALL OK ($CHECKS checks)"
