#!/bin/bash
# Runs setup, uninstall and the helpers in throwaway HOME folders, with
# stand-ins for solaar, pgrep, setsid and hyprctl. Never touches your real
# config or your running Solaar: the stand-in pgrep only reports the fake
# Solaar processes started from this test's own folder.
#
#   tests/test_setup.sh                  run everything (about a minute)
#   POP_TEST_KEEP=1 tests/test_setup.sh  keep the sandbox folders and outputs
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/pop-icon-keys-test.XXXXXX")
STUBS="$WORK/stubs"
NOSOLAAR="$WORK/stubs-nosolaar"
NOYAML="$WORK/stubs-noyaml"
FAILS=0
CHECKS=0
REAL_PKILL=$(command -v pkill)

cleanup() {
  "$REAL_PKILL" -KILL -f "$STUBS/daemon/solaar" 2>/dev/null
  "$REAL_PKILL" -KILL -f "$STUBS/solaar show" 2>/dev/null
  chmod -R u+w "$WORK" 2>/dev/null
  if [[ -n ${POP_TEST_KEEP:-} ]]; then echo "outputs kept in $WORK"; else rm -rf "$WORK"; fi
}
trap cleanup EXIT

ok() { CHECKS=$((CHECKS + 1)); echo "  ok   $1"; }
fail() { CHECKS=$((CHECKS + 1)); FAILS=$((FAILS + 1)); echo "  FAIL $1"; }
check() { if eval "$2"; then ok "$1"; else fail "$1"; fi; }

# --- stand-ins ---------------------------------------------------------------
mkdir -p "$STUBS/daemon" "$NOSOLAAR" "$NOYAML"

# The fake Solaar daemon. Its command line is "bash <stubs>/daemon/solaar --window=hide",
# so it is found the way the real one is (a program named solaar, options only).
#   STUBBORN=1  ignores SIGTERM (only SIGKILL stops it)
#   SLOW=N      takes N seconds to exit after SIGTERM, then writes $STATE/saved
cat >"$STUBS/daemon/solaar" <<'EOF'
#!/bin/bash
if [[ ${STUBBORN:-0} == 1 ]]; then
  trap '' TERM
elif [[ ${SLOW:-0} != 0 ]]; then
  trap 'sleep "$SLOW"; echo saved >>"$STATE/saved"; exit 0' TERM
else
  trap 'exit 0' TERM
fi
while :; do sleep 0.2; done
EOF
# pgrep -u UID -x solaar: this test's fake Solaar processes (daemon and CLI runs) only.
cat >"$STUBS/pgrep" <<'EOF'
#!/bin/bash
found=1
for f in /proc/[0-9]*/cmdline; do
  pid=${f#/proc/}; pid=${pid%/cmdline}
  mapfile -d '' args <"$f" 2>/dev/null || continue
  for a in "${args[@]}"; do
    if [[ $a == "$STUBS"/* && ${a##*/} == solaar ]]; then echo "$pid"; found=0; break; fi
  done
done
exit $found
EOF
# setsid -f solaar ...: start the fake daemon (FAIL_START=1: start nothing).
cat >"$STUBS/setsid" <<'EOF'
#!/bin/bash
echo start >>"$STATE/log"
[[ ${FAIL_START:-0} == 1 ]] && exit 0
nohup bash "$STUBS/daemon/solaar" --window=hide >/dev/null 2>&1 &
echo $! >>"$STATE/pids"
exit 0
EOF
# solaar <action>: a one-off command. SHOW_SLEEP=N keeps `solaar show` running for N s.
cat >"$STUBS/solaar" <<'EOF'
#!/bin/bash
echo "solaar $*" >>"$STATE/log"
if [[ $1 == show ]]; then
  [[ -n ${SHOW_SLEEP:-} ]] && sleep "$SHOW_SLEEP"
  [[ -n ${FIXTURE:-} ]] && cat "$FIXTURE"
fi
exit 0
EOF
cat >"$STUBS/hyprctl" <<'EOF'
#!/bin/bash
echo "hyprctl $*" >>"$STATE/log"
exit "${HYPR_RC:-0}"
EOF
cat >"$STUBS/omarchy-pkg-add" <<'EOF'
#!/bin/bash
echo "pkg-add $*" >>"$STATE/log"
exit 0
EOF
sed -i "s|\$STUBS|$STUBS|g" "$STUBS/pgrep" "$STUBS/setsid"
chmod +x "$STUBS"/* "$STUBS/daemon/solaar"
# A PATH without any solaar: the stand-ins, plus links to everything else on
# PATH except solaar (the real one may be installed in /usr/bin).
for f in "$STUBS"/*; do [[ -f $f && ${f##*/} != solaar ]] && ln -s "$f" "$NOSOLAAR/"; done
IFS=: read -ra path_dirs <<<"$PATH"
for d in "${path_dirs[@]}"; do
  for f in "$d"/*; do
    n=${f##*/}
    [[ $n == solaar || -e $NOSOLAAR/$n || ! -x $f ]] || ln -s "$f" "$NOSOLAAR/$n"
  done
done
# python3 without the yaml module.
cat >"$NOYAML/python3" <<EOF
#!/bin/bash
[[ "\$*" == *"import sys, yaml"* ]] && exit 1
exec $(command -v python3) "\$@"
EOF
chmod +x "$NOYAML/python3"

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

ORIG_PATH=$PATH

# new_home NAME: a fresh sandbox with the default files and a running fake Solaar.
new_home() {
  export HOME="$WORK/$1" STATE="$WORK/$1/state"
  unset XDG_CONFIG_HOME STUBBORN SLOW FAIL_START SHOW_SLEEP FIXTURE HYPR_RC
  export XDG_RUNTIME_DIR="$HOME/run"
  mkdir -p "$HOME/.config/solaar" "$HOME/.config/hypr" "$STATE" "$XDG_RUNTIME_DIR"
  printf '%s\n' "$CONFIG_YAML" >"$HOME/.config/solaar/config.yaml"
  printf '%s\n' "$RULES_YAML" >"$HOME/.config/solaar/rules.yaml"
  printf '%s\n' "$BINDINGS_LUA" >"$HOME/.config/hypr/bindings.lua"
  printf '%s\n' "$AUTOSTART_LUA" >"$HOME/.config/hypr/autostart.lua"
  export PATH="$STUBS:$ORIG_PATH"
  setsid -f solaar  # Solaar is running when setup starts
  for _ in 1 2 3 4 5 6 7 8; do [[ -n $(daemons) ]] && break; sleep 0.1; done
  : >"$STATE/log"
}
C() { echo "$HOME/.config/$1"; }
# Pids of fake Solaar daemons (not CLI runs), found the way lib.sh finds them.
daemons() { bash -c 'source "$1/lib/solaar-procs.sh"; solaar_daemon_pids' _ "$ROOT"; }
divert_of() { grep -A3 "_NAME: POP Icon Keys" "$(C solaar/config.yaml)" | tr -d '\n' | grep -oE "$1: [0-9]+" | head -1 | cut -d' ' -f2; }
backups() { find "$HOME/.config" -name "*.bak.pop-icon-keys.*" | wc -l; }
sums() { (cd "$HOME/.config" && sha256sum solaar/config.yaml solaar/rules.yaml hypr/bindings.lua hypr/autostart.lua 2>/dev/null); }
config_sum() { sha256sum <"$(C solaar/config.yaml)"; }

echo "setup twice, then uninstall"
new_home t1
cp -r "$HOME/.config" "$WORK/t1.orig"
"$ROOT/setup" --yes >"$WORK/t1.out" 2>&1; rc=$?
check "setup exits 0" "[[ $rc == 0 ]] && grep -q '^Done' \"$WORK/t1.out\""
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
check "Solaar running after setup" "[[ -n \$(daemons) ]]"
check "Hyprland reloaded once" "[[ \$(grep -c 'hyprctl reload' \"$STATE/log\") == 1 ]]"
b1=$(backups)
: >"$STATE/log"
"$ROOT/setup" --yes >"$WORK/t1b.out" 2>&1; rc=$?
check "second setup exits 0" "[[ $rc == 0 ]]"
check "still one rules block" "[[ \$(grep -c '^# BEGIN pop-icon-keys' \"$(C solaar/rules.yaml)\") == 1 ]]"
check "still one lock block" "[[ \$(grep -c '^-- BEGIN pop-icon-keys' \"$(C hypr/bindings.lua)\") == 1 ]]"
check "no new backups when nothing changed ($b1)" "[[ \$(backups) == $b1 ]]"
check "no Hyprland reload when nothing changed" "! grep -q 'hyprctl reload' \"$STATE/log\""
"$ROOT/uninstall" --yes >"$WORK/t1c.out" 2>&1; rc=$?
check "uninstall exits 0" "[[ $rc == 0 ]] && grep -q 'own shortcuts again' \"$WORK/t1c.out\""
check "rules restored exactly" "cmp -s \"$(C solaar/rules.yaml)\" \"$WORK/t1.orig/solaar/rules.yaml\""
check "bindings restored exactly" "cmp -s \"$(C hypr/bindings.lua)\" \"$WORK/t1.orig/hypr/bindings.lua\""
check "autostart restored exactly" "cmp -s \"$(C hypr/autostart.lua)\" \"$WORK/t1.orig/hypr/autostart.lua\""
check "keys back to Regular" "[[ \$(divert_of 259) == 0 && \$(divert_of 110) == 0 ]]"
check "helper removed" "[[ ! -e $HOME/.local/bin/pop-icon-keys-show-desktop ]]"
check "Solaar running after uninstall" "[[ -n \$(daemons) ]]"

echo "broken markers stop setup and uninstall before any change"
for variant in "bindings:-- BEGIN" "bindings:-- END" "autostart:-- BEGIN" "rules:# END" "rules:# BEGIN"; do
  file=${variant%%:*} marker=${variant#*:}
  new_home "t2-$file-${marker##* }"
  case $file in
    rules) target=$(C solaar/rules.yaml) ;;
    *) target=$(C hypr/$file.lua) ;;
  esac
  printf '%s pop-icon-keys\nUSER_LINE_1\n' "$marker" >>"$target"
  before=$(sums)
  "$ROOT/setup" --yes >"$WORK/t2.out" 2>&1; rc=$?
  check "$file, lone '${marker##* }': setup refuses with nothing changed" \
    "[[ $rc != 0 ]] && grep -q 'expected one of each' \"$WORK/t2.out\" && [[ \"\$(sums)\" == \"$before\" ]] && ! grep -q '^start' \"$STATE/log\""
  "$ROOT/uninstall" --yes >"$WORK/t2b.out" 2>&1; rc=$?
  check "$file, lone '${marker##* }': uninstall refuses with nothing changed" \
    "[[ $rc != 0 ]] && [[ \"\$(sums)\" == \"$before\" ]] && ! grep -q '^Done' \"$WORK/t2b.out\""
done

echo "line endings, block position, symlinks and file modes are kept"
new_home t3
printf 'top\r\n-- BEGIN pop-icon-keys\r\nold\r\n-- END pop-icon-keys\r\nbottom\r\n' >"$(C hypr/bindings.lua)"
printf -- '-- a\r\n-- b\r\n-- c\n' >"$(C hypr/autostart.lua)"
mkdir -p "$HOME/dotfiles"
mv "$(C solaar/rules.yaml)" "$HOME/dotfiles/rules.yaml"
ln -s "$HOME/dotfiles/rules.yaml" "$(C solaar/rules.yaml)"
chmod 600 "$(C hypr/bindings.lua)"
"$ROOT/setup" --yes >"$WORK/t3.out" 2>&1; rc=$?
check "setup exits 0" "[[ $rc == 0 ]]"
check "CRLF kept" "! grep -qv \$'\\r\$' \"$(C hypr/bindings.lua)\""
check "block stays above 'bottom'" "[[ \$(tr -d '\\r' <\"$(C hypr/bindings.lua)\" | tail -1) == bottom ]]"
check "old block content replaced" "! grep -q '^old' \"$(C hypr/bindings.lua)\""
check "mixed endings become the more common one (CRLF)" "! grep -qv \$'\\r\$' \"$(C hypr/autostart.lua)\""
check "symlink kept, target edited" "[[ -L \"$(C solaar/rules.yaml)\" ]] && grep -q 'BEGIN pop-icon-keys' \"$HOME/dotfiles/rules.yaml\""
check "file mode kept" "[[ \$(stat -c %a \"$(C hypr/bindings.lua)\") == 600 ]]"
check "no temporary files left" "[[ -z \$(find \"$HOME\" -name '.*.lua.*' -o -name '.rules.yaml.*') ]]"

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
cfg=$(config_sum)
"$ROOT/setup" --yes >"$WORK/t5.out" 2>&1; rc=$?
check "setup fails clearly" "[[ $rc != 0 ]] && grep -q 'not a number' \"$WORK/t5.out\""
check "config.yaml unchanged" "[[ \"\$(config_sum)\" == \"$cfg\" ]]"
check "says how to recover" "grep -q 'Setup stopped partway' \"$WORK/t5.out\""
check "Solaar started again" "[[ -n \$(daemons) ]]"

echo "Hyprland reload fails"
new_home t6
HYPR_RC=1 "$ROOT/setup" --yes >"$WORK/t6.out" 2>&1; rc=$?
check "setup still finishes" "[[ $rc == 0 ]] && grep -q 'Applied, except' \"$WORK/t6.out\""
check "lists the reload as not done" "grep -q 'reload Hyprland' \"$WORK/t6.out\" && grep -q 'could not reload Hyprland' \"$WORK/t6.out\""

echo "keyboard never seen by Solaar"
new_home t7
printf '%s\n' '- 1.1.20' '- _NAME: MX Master 4' '  divert-keys: {82: 0}' >"$(C solaar/config.yaml)"
"$ROOT/setup" --yes >"$WORK/t7.out" 2>&1; rc=$?
check "exit 2 (partly applied)" "[[ $rc == 2 ]] && grep -q 'Partly applied' \"$WORK/t7.out\""
check "Solaar running at the end" "[[ -n \$(daemons) ]]"

echo "Solaar ignores SIGTERM"
new_home t8
"$REAL_PKILL" -KILL -f "$STUBS/daemon/solaar" 2>/dev/null; sleep 0.3
STUBBORN=1 setsid -f solaar; sleep 0.3; old=$(daemons)
: >"$STATE/log"
"$ROOT/setup" --yes >"$WORK/t8.out" 2>&1; rc=$?
check "setup stops it with SIGKILL and finishes" "[[ $rc == 0 ]] && grep -q 'SIGKILL' \"$WORK/t8.out\""
check "keys diverted" "[[ \$(divert_of 259) == 1 ]]"
check "old Solaar gone, a new one running" "! kill -0 $old 2>/dev/null && [[ -n \$(daemons) ]]"

echo "Solaar takes a few seconds to save and exit"
new_home t8b
"$REAL_PKILL" -KILL -f "$STUBS/daemon/solaar" 2>/dev/null; sleep 0.3
SLOW=3 setsid -f solaar; sleep 0.3
"$ROOT/setup" --yes >"$WORK/t8b.out" 2>&1; rc=$?
check "setup waits for it" "[[ $rc == 0 ]] && [[ -s \"$STATE/saved\" ]] && ! grep -q SIGKILL \"$WORK/t8b.out\""
check "Solaar running at the end" "[[ -n \$(daemons) ]]"

echo "setup is stopped (SIGTERM) while it waits for Solaar"
new_home t8c
"$REAL_PKILL" -KILL -f "$STUBS/daemon/solaar" 2>/dev/null; sleep 0.3
SLOW=4 setsid -f solaar; sleep 0.3
cfg=$(config_sum)
"$ROOT/setup" --yes >"$WORK/t8c.out" 2>&1 & spid=$!
sleep 1.5; kill -TERM $spid; wait $spid; rc=$?
check "exits 143" "[[ $rc == 143 ]]"
check "config.yaml unchanged" "[[ \"\$(config_sum)\" == \"$cfg\" ]]"
check "a Solaar is running afterwards (after the old one finished)" "[[ -n \$(daemons) ]] && [[ -s \"$STATE/saved\" ]]"
check "says how to recover" "grep -q 'Setup stopped partway' \"$WORK/t8c.out\""

echo "a 'solaar show' running alongside the daemon"
new_home t8d
SHOW_SLEEP=30 solaar show "POP Icon Keys" >/dev/null 2>&1 & cli=$!
sleep 0.3
"$ROOT/setup" --yes >"$WORK/t8d.out" 2>&1; rc=$?
check "setup exits 0" "[[ $rc == 0 ]]"
check "the show command was not killed" "kill -0 $cli 2>/dev/null"
check "a daemon is running at the end, not just the show command" "[[ -n \$(daemons) ]]"
check "status counts only the daemon" "FIXTURE=/dev/null \"$ROOT/bin/pop-icon-keys-status\" | grep -qx 'running=1'"
"$REAL_PKILL" -KILL -f "$STUBS/daemon/solaar" 2>/dev/null; sleep 0.3
check "status: show command alone is not 'running'" "FIXTURE=/dev/null \"$ROOT/bin/pop-icon-keys-status\" | grep -qx 'running=0'"
kill $cli 2>/dev/null

echo "Solaar fails to start again"
new_home t8e
FAIL_START=1 "$ROOT/setup" --yes >"$WORK/t8e.out" 2>&1; rc=$?
check "setup reports it instead of Done" "! grep -q '^Done' \"$WORK/t8e.out\" && grep -q 'start Solaar' \"$WORK/t8e.out\""

echo "declining, and no terminal"
new_home t9
before=$(sums)
script -qec "$ROOT/setup" /dev/null <<<"n" >"$WORK/t9.out" 2>&1; rc=$?
check "decline exits 0" "[[ $rc == 0 ]] && grep -q 'Nothing changed' \"$WORK/t9.out\""
check "plan is shown before the question" "[[ \$(grep -n 'bind the Lock key' \"$WORK/t9.out\" | cut -d: -f1) -lt \$(grep -n 'Apply these changes' \"$WORK/t9.out\" | cut -d: -f1) ]]"
script -qec "$ROOT/uninstall" /dev/null <<<"n" >"$WORK/t9u.out" 2>&1; rc=$?
check "uninstall decline exits 0" "[[ $rc == 0 ]] && grep -q 'Nothing changed' \"$WORK/t9u.out\""
"$ROOT/setup" </dev/null >"$WORK/t9b.out" 2>&1; rc=$?
check "no terminal and no --yes refuses" "[[ $rc != 0 ]] && grep -q 're-run with --yes' \"$WORK/t9b.out\""
"$ROOT/setup" --dry-run >"$WORK/t9c.out" 2>&1; rc=$?
check "dry run exits 0 with a diff" "[[ $rc == 0 ]] && grep -q 'would change' \"$WORK/t9c.out\""
check "nothing changed by any of them" "[[ \"\$(sums)\" == \"$before\" ]]"
check "Solaar never stopped" "! grep -q '^start' \"$STATE/log\""

echo "--yes never installs Solaar"
new_home t9d
PATH="$NOSOLAAR" "$ROOT/setup" --yes >"$WORK/t9d.out" 2>&1; rc=$?
check "refuses and asks to install Solaar first" "[[ $rc != 0 ]] && grep -q 'install Solaar first' \"$WORK/t9d.out\""
check "package install not run" "! grep -q 'pkg-add' \"$STATE/log\""

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
  - Show Desktop
  - pressed
- Execute:
  - /opt/elsewhere/pop-icon-keys-show-desktop
...
---
- Key:
  - Screen Capture
  - pressed
- Execute:
  - omarchy-capture-screenshot
  - region
  - --extra
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
check "plugin copies removed" "! grep -q 'omarchy-dictation' \"$(C solaar/rules.yaml)\" && ! grep -q '$HOME/.local/bin/pop-icon-keys-show-desktop' \"$(C solaar/rules.yaml)\""
check "user's own Emoji rule kept" "grep -q 'my-own-emoji-tool' \"$(C solaar/rules.yaml)\""
check "Show Desktop rule with another path kept" "grep -q '/opt/elsewhere/pop-icon-keys-show-desktop' \"$(C solaar/rules.yaml)\""
check "near-miss Screen Capture rule kept" "grep -q -- '--extra' \"$(C solaar/rules.yaml)\""
new_home t10b
"$ROOT/setup" --yes >"$WORK/t10b.out" 2>&1
printf '%s\n' '---' '- Key:' '  - Dictation' '  - pressed' '- Execute:' '  - omarchy-dictation' '  - toggle' '...' >>"$(C solaar/rules.yaml)"
"$ROOT/setup" --yes >"$WORK/t10c.out" 2>&1
check "setup drops an earlier copy instead of warning" "[[ \$(grep -c 'omarchy-dictation' \"$(C solaar/rules.yaml)\") == 1 ]] && ! grep -q 'other rules of yours' \"$WORK/t10c.out\""
new_home t10d
"$ROOT/setup" --yes >/dev/null 2>&1
# An unterminated copy (no '...') just before the marked block.
python3 - "$(C solaar/rules.yaml)" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
copy = "---\n- Key:\n  - Dictation\n  - pressed\n- Execute:\n  - omarchy-dictation\n  - toggle\n"
open(p, "w").write(s.replace("# BEGIN pop-icon-keys", copy + "# BEGIN pop-icon-keys", 1))
PY
"$ROOT/setup" --yes >"$WORK/t10e.out" 2>&1; rc=$?
check "unterminated copy before the block: setup exits 0" "[[ $rc == 0 ]]"
check "markers intact (one BEGIN, one END)" "[[ \$(grep -c '^# BEGIN pop-icon-keys' \"$(C solaar/rules.yaml)\") == 1 && \$(grep -c '^# END pop-icon-keys' \"$(C solaar/rules.yaml)\") == 1 ]]"
check "copy removed" "[[ \$(grep -c 'omarchy-dictation' \"$(C solaar/rules.yaml)\") == 1 ]]"
"$ROOT/setup" --yes >"$WORK/t10f.out" 2>&1; rc=$?
check "and the next run still works" "[[ $rc == 0 ]]"

echo "backups: newest 3 kept, by the time in their name"
new_home t11
for i in 1 2 3 4 5; do
  # Change the block by hand, so each run has something to put back (and back up).
  if grep -q '^-- BEGIN pop-icon-keys' "$(C hypr/bindings.lua)"; then
    sed -i "/^-- BEGIN pop-icon-keys/a -- stale $i" "$(C hypr/bindings.lua)"
  fi
  # Old file times, each run older than the last (as after cp -p or a checkout):
  # ordering backups by file time would keep the wrong ones.
  touch -d "$((2010 - i))-01-01" "$(C hypr/bindings.lua)"
  "$ROOT/setup" --yes >/dev/null 2>&1
done
n=$(ls "$(C hypr)" | grep -c 'bindings.lua.bak.pop-icon-keys')
newest=$(ls "$(C hypr)" | grep 'bindings.lua.bak.pop-icon-keys' | sort | tail -1)
check "exactly 3 bindings backups ($n)" "[[ $n == 3 ]]"
check "the newest backup is kept" "grep -q 'stale 5' \"$(C hypr)/$newest\""
POP_KEEP_BACKUPS=0 "$ROOT/setup" --yes >/dev/null 2>&1
sed -i "/^-- BEGIN pop-icon-keys/a -- stale 6" "$(C hypr/bindings.lua)"
POP_KEEP_BACKUPS=0 "$ROOT/setup" --yes >/dev/null 2>&1
check "POP_KEEP_BACKUPS=0 still keeps one" "[[ \$(ls \"$(C hypr)\" | grep -c 'bindings.lua.bak.pop-icon-keys') -ge 1 ]]"

echo "unreadable and unwritable files"
new_home t13
printf '# caf\xe9\n' >>"$(C solaar/rules.yaml)"
before=$(sums)
"$ROOT/setup" --yes >"$WORK/t13.out" 2>&1; rc=$?
check "non-UTF-8 rules.yaml: setup refuses" "[[ $rc != 0 ]] && grep -q 'not UTF-8' \"$WORK/t13.out\""
check "nothing changed, Solaar not stopped" "[[ \"\$(sums)\" == \"$before\" ]] && ! grep -q '^start' \"$STATE/log\""
"$ROOT/uninstall" --yes >"$WORK/t13b.out" 2>&1; rc=$?
check "uninstall refuses too, without 'Done'" "[[ $rc != 0 ]] && ! grep -q '^Done' \"$WORK/t13b.out\" && [[ \"\$(sums)\" == \"$before\" ]]"
new_home t13c
mkdir -p "$HOME/ro"
mv "$(C solaar/rules.yaml)" "$HOME/ro/rules.yaml"
ln -s "$HOME/ro/rules.yaml" "$(C solaar/rules.yaml)"
chmod 555 "$HOME/ro"
cfg=$(config_sum)
"$ROOT/setup" --yes >"$WORK/t13c.out" 2>&1; rc=$?
chmod 755 "$HOME/ro"
check "rules.yaml in a read-only folder: setup fails clearly" "[[ $rc != 0 ]] && grep -q 'cannot write' \"$WORK/t13c.out\" && ! grep -q 'Traceback' \"$WORK/t13c.out\""
check "config.yaml not diverted" "[[ \"\$(config_sum)\" == \"$cfg\" ]]"
check "Solaar not stopped" "! grep -q '^start' \"$STATE/log\" && [[ -n \$(daemons) ]]"

echo "missing Python yaml module"
new_home t14
before=$(sums)
PATH="$NOYAML:$STUBS:$ORIG_PATH" "$ROOT/setup" --yes >"$WORK/t14.out" 2>&1; rc=$?
check "setup refuses and names the package" "[[ $rc != 0 ]] && grep -q 'python-yaml' \"$WORK/t14.out\" && [[ \"\$(sums)\" == \"$before\" ]]"
PATH="$NOYAML:$STUBS:$ORIG_PATH" "$ROOT/uninstall" --yes >"$WORK/t14b.out" 2>&1; rc=$?
check "uninstall refuses too" "[[ $rc != 0 ]] && grep -q 'python-yaml' \"$WORK/t14b.out\""

echo "paths with spaces and commas, and a bad HOME"
new_home "t15 a,b [c]"
"$ROOT/setup" --yes >"$WORK/t15.out" 2>&1; rc=$?
check "setup exits 0" "[[ $rc == 0 ]]"
check "Show Desktop rule runs one program at the full path" "python3 - \"$(C solaar/rules.yaml)\" \"$HOME/.local/bin/pop-icon-keys-show-desktop\" <<'PY'
import sys, yaml
docs = [d for d in yaml.safe_load_all(open(sys.argv[1])) if d]
cmds = [d[1]['Execute'] for d in docs if d[0].get('Key', [None])[0] == 'Show Desktop']
sys.exit(0 if cmds == [[sys.argv[2]]] else 1)
PY"
HOME=$'/tmp/x\ny' "$ROOT/setup" --yes >"$WORK/t15b.out" 2>&1; rc=$?
check "HOME with a newline refused" "[[ $rc != 0 ]] && grep -q 'without newlines' \"$WORK/t15b.out\""

echo "relative XDG_CONFIG_HOME is ignored"
new_home t16
(cd "$HOME" && XDG_CONFIG_HOME=rel "$ROOT/setup" --yes >"$WORK/t16.out" 2>&1); rc=$?
check "edits ~/.config, not ./rel" "[[ $rc == 0 ]] && grep -q 'BEGIN pop-icon-keys' \"$(C solaar/rules.yaml)\" && [[ ! -e $HOME/rel ]]"

echo "one setup at a time"
new_home t17
exec 8>"$XDG_RUNTIME_DIR/pop-icon-keys.lock"; flock 8
before=$(sums)
"$ROOT/setup" --yes >"$WORK/t17.out" 2>&1; rc=$?
exec 8>&-
check "a second setup refuses while one runs" "[[ $rc != 0 ]] && grep -q 'another POP Icon Keys' \"$WORK/t17.out\" && [[ \"\$(sums)\" == \"$before\" ]]"

echo "uninstall when Solaar is not installed"
new_home t18
"$ROOT/setup" --yes >/dev/null 2>&1
PATH="$NOSOLAAR" "$ROOT/uninstall" --yes >"$WORK/t18.out" 2>&1; rc=$?
check "removes the rest and says the diversion was not reset" "[[ $rc == 0 ]] && grep -q 'Solaar is not installed' \"$WORK/t18.out\" && ! grep -q 'own shortcuts again\\.\$' \"$WORK/t18.out\" && ! grep -q 'BEGIN pop-icon-keys' \"$(C solaar/rules.yaml)\""

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
"$REAL_PKILL" -KILL -f "$STUBS/daemon/solaar" 2>/dev/null; sleep 0.3
: >"$STATE/log"
"$ROOT/bin/pop-icon-keys-restore" Dictation >/dev/null 2>&1; rc=$?
check "does nothing while Solaar is not running" "[[ $rc != 0 ]] && ! grep -q 'solaar config' \"$STATE/log\""

echo "one key list everywhere"
names=$(python3 -I "$ROOT/lib/edit.py" keys | cut -f2)
missing_in_panel=""
while IFS= read -r name; do grep -q "solaar: \"$name\"" "$ROOT/Panel.qml" || missing_in_panel+="$name "; done <<<"$names"
check "Panel.qml lists every mapped key" "[[ -z \"$missing_in_panel\" ]]"
check "Panel.qml lists no other Solaar key" "[[ \$(grep -oE 'solaar: \"[^\"]+\"' \"$ROOT/Panel.qml\" | wc -l) == \$(wc -l <<<\"$names\") ]]"

echo
if (( FAILS )); then echo "$FAILS of $CHECKS checks FAILED"; exit 1; fi
echo "ALL OK ($CHECKS checks)"
