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

# Ask a yes/no question. --yes and --dry-run answer yes; no terminal is an error.
confirm() {
  (( ASSUME_YES )) && return 0
  (( DRY_RUN )) && return 0
  [[ -t 0 ]] || die "no terminal to confirm on; re-run with --yes to accept the changes listed above"
  local reply
  read -r -p "$1 [y/N] " reply
  [[ $reply == [yY] || $reply == [yY][eE][sS] ]]
}

# File edits live in lib/edit.py: it backs a file up only when it changes (keeping
# the newest 3 backups), writes atomically, keeps CRLF, refuses broken markers,
# and prints a diff instead of writing under --dry-run.
edit() {
  POP_DRY_RUN=$DRY_RUN python3 -I "$PLUGIN_DIR/lib/edit.py" "$@"
}

# Replace the marked block in FILE with BODY, or remove it when BODY is empty.
# COMMENT is the file's line-comment prefix ("#" or "--"). Dies on broken markers.
write_block() {
  printf '%s' "$3" | edit block "$1" "$2" || die "$1 was left unchanged"
}

# True when FILE has this plugin's marked block. Dies on broken markers.
has_block() {
  local rc=0
  edit has-block "$1" "$2" || rc=$?
  (( rc == 5 )) && die "$1 needs fixing by hand first"
  (( rc == 0 ))
}

# Solaar's process name is "solaar" (it runs as a Python script), so match the
# process name exactly; a pattern match on the command line would also hit the
# shell running this script.
solaar_pids() { pgrep -x solaar 2>/dev/null || true; }

# Stop Solaar and wait for it to exit. Solaar saves its settings up to 5 seconds
# after a change and again on exit, so wait long enough for that save to land
# before config.yaml is edited. Returns 1 if Solaar is still running.
stop_solaar() {
  local pids
  pids=$(solaar_pids)
  [[ -n $pids ]] || return 0
  if (( DRY_RUN )); then
    say "  [dry-run] stop Solaar (pid $(echo $pids))"
    return 0
  fi
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
  local _
  for _ in $(seq 1 16); do
    [[ -z $(solaar_pids) ]] && return 0
    sleep 0.5
  done
  return 1
}

start_solaar() {
  [[ -n $(solaar_pids) ]] && return 0
  if (( DRY_RUN )); then
    say "  [dry-run] start Solaar: setsid -f solaar --window=hide"
    return 0
  fi
  setsid -f solaar --window=hide >/dev/null 2>&1 </dev/null || warn "could not start Solaar; start it with: solaar --window=hide"
}

# Set the diversion of DIVERT_IDS to VALUE (1 diverted, 0 regular) in Solaar's
# saved config, for every saved entry of the keyboard. Solaar must be stopped: a
# running Solaar writes its in-memory state back over the file.
# Returns 3 when Solaar has no saved entry for the keyboard yet, 4 when the file
# could not be read or understood (left unchanged).
set_diversion() {
  edit divert "$SOLAAR_CONFIG" "$DEVICE" "$1" "${DIVERT_IDS[@]}"
}

reload_hyprland() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  if (( DRY_RUN )); then
    say "  [dry-run] hyprctl reload"
    return 0
  fi
  hyprctl reload >/dev/null 2>&1 || warn "could not reload Hyprland; the Lock key works after your next login"
}
