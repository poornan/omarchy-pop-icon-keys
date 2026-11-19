# Shared helpers for setup and uninstall. Sourced, not executed.
# shellcheck shell=bash

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="POP Icon Keys"
MARK="pop-icon-keys"

SOLAAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/solaar"
RULES_FILE="$SOLAAR_DIR/rules.yaml"
SOLAAR_CONFIG="$SOLAAR_DIR/config.yaml"
HYPR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/hypr"
BINDINGS_FILE="$HYPR_DIR/bindings.lua"
AUTOSTART_FILE="$HYPR_DIR/autostart.lua"
BIN_DIR="$HOME/.local/bin"
SHOW_DESKTOP="$BIN_DIR/pop-icon-keys-show-desktop"

# Solaar control ids of the mapped keys (REPROG CONTROLS V4 on the POP Icon Keys):
# 110 Show Desktop, 266 MultiPlatform Search, 259 Dictation, 264 Emoji, 212 Screen Capture.
DIVERT_IDS=(110 266 259 264 212)

DRY_RUN=0
ASSUME_YES=0

parse_args() {
  local arg
  for arg in "$@"; do
    case $arg in
      --dry-run|-n) DRY_RUN=1 ;;
      --yes|-y) ASSUME_YES=1 ;;
      -h|--help) usage; exit 0 ;;
      *) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    esac
  done
}

say() { printf '%s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Run a command, or only print it under --dry-run.
run() {
  if (( DRY_RUN )); then
    printf '  [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

confirm() {
  (( ASSUME_YES )) && return 0
  (( DRY_RUN )) && return 0
  [[ -t 0 ]] || die "no terminal to confirm on; re-run with --yes to accept the changes listed above"
  local reply
  read -r -p "$1 [y/N] " reply
  [[ $reply == [yY] || $reply == [yY][eE][sS] ]]
}

backup() {
  local file=$1
  [[ -f $file ]] || return 0
  run cp -p -- "$file" "$file.bak.$MARK.$(date +%Y%m%d-%H%M%S).$$"
}

# Replace the marked block in FILE with BODY (or remove it when BODY is empty).
# COMMENT is the file's line-comment prefix ("#" or "--").
write_block() {
  local file=$1 comment=$2 body=$3
  if (( DRY_RUN )); then
    if [[ -n $body ]]; then
      printf '  [dry-run] write %s block in %s:\n' "$MARK" "$file"
      printf '%s\n' "$body" | sed 's/^/      | /'
    else
      printf '  [dry-run] remove %s block from %s\n' "$MARK" "$file"
    fi
    return 0
  fi
  python3 -I - "$file" "$comment" "$MARK" "$body" <<'PY'
import os, re, sys
path, comment, mark, body = sys.argv[1:5]
begin, end = f"{comment} BEGIN {mark}", f"{comment} END {mark}"
text = open(path).read() if os.path.exists(path) else ""
pattern = re.compile(r"\n?" + re.escape(begin) + r"\n.*?" + re.escape(end) + r"\n?", re.S)
text = pattern.sub("\n", text).rstrip("\n")
if body:
    block = f"{begin}\n{body.rstrip(chr(10))}\n{end}"
    text = f"{text}\n\n{block}" if text else block
open(path, "w").write(text + "\n" if text else "")
PY
}

has_block() {
  [[ -f $1 ]] && grep -qF -- "$2 BEGIN $MARK" "$1"
}

# Solaar's process name is "solaar" (it runs as a Python script), so match the
# process name exactly; a pattern match on the command line would also hit the
# shell running this script.
solaar_pids() { pgrep -x solaar 2>/dev/null || true; }

stop_solaar() {
  local pids
  pids=$(solaar_pids)
  [[ -n $pids ]] || return 0
  # shellcheck disable=SC2086
  run kill $pids
  (( DRY_RUN )) && return 0
  local _
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    [[ -z $(solaar_pids) ]] && return 0
    sleep 0.5
  done
  warn "Solaar did not stop; its config may be rewritten when it exits"
}

start_solaar() {
  [[ -n $(solaar_pids) ]] && return 0
  if (( DRY_RUN )); then
    say "  [dry-run] setsid -f solaar --window=hide"
    return 0
  fi
  setsid -f solaar --window=hide >/dev/null 2>&1 </dev/null
}

# Set the diversion of DIVERT_IDS to VALUE (1 diverted, 0 regular) in Solaar's
# saved config, under the POP Icon Keys device. Solaar must be stopped: a
# running Solaar writes its in-memory state back over the file.
# Exit 3 when the device has no entry yet (Solaar never saw the keyboard).
set_diversion() {
  local value=$1
  if (( DRY_RUN )); then
    printf '  [dry-run] set divert-keys %s to %s for "%s" in %s\n' "${DIVERT_IDS[*]}" "$value" "$DEVICE" "$SOLAAR_CONFIG"
    return 0
  fi
  [[ -f $SOLAAR_CONFIG ]] || return 3
  python3 -I - "$SOLAAR_CONFIG" "$DEVICE" "$value" "${DIVERT_IDS[@]}" <<'PY'
import re, sys
path, device, value, *ids = sys.argv[1:]
text = open(path).read()
# Each device is a top-level list item starting "- _NAME: <name>".
m = re.search(r"^- _NAME: " + re.escape(device) + r"\n(?:(?!^- ).*\n?)*", text, re.M)
if not m:
    sys.exit(3)
block = m.group(0)
d = re.search(r"^(  divert-keys: )\{(.*?)\}", block, re.M | re.S)
pairs = {}
if d:
    for item in d.group(2).replace("\n", " ").split(","):
        if ":" in item:
            k, v = item.split(":", 1)
            pairs[int(k.strip())] = v.strip()
for i in ids:
    pairs[int(i)] = value
flow = "  divert-keys: {" + ", ".join(f"{k}: {v}" for k, v in sorted(pairs.items())) + "}"
if d:
    new_block = block[:d.start()] + flow + block[d.end():]
else:
    new_block = block.rstrip("\n") + "\n" + flow + "\n"
text = text[:m.start()] + new_block + text[m.end():]
open(path, "w").write(text)
PY
}

reload_hyprland() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  run hyprctl reload >/dev/null
}
