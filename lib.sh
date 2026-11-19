# Shared helpers for setup and uninstall. Sourced, not executed.
# shellcheck shell=bash

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVICE="POP Icon Keys"
MARK="pop-icon-keys"

# shellcheck source=lib/solaar-procs.sh
source "$PLUGIN_DIR/lib/solaar-procs.sh"

# XDG_CONFIG_HOME counts only when it is an absolute path (XDG Base Directory spec).
CONFIG_HOME=${XDG_CONFIG_HOME:-}
[[ $CONFIG_HOME == /* ]] || CONFIG_HOME="$HOME/.config"
SOLAAR_DIR="$CONFIG_HOME/solaar"
RULES_FILE="$SOLAAR_DIR/rules.yaml"
SOLAAR_CONFIG="$SOLAAR_DIR/config.yaml"
HYPR_DIR="$CONFIG_HOME/hypr"
BINDINGS_FILE="$HYPR_DIR/bindings.lua"
AUTOSTART_FILE="$HYPR_DIR/autostart.lua"
BIN_DIR="$HOME/.local/bin"
SHOW_DESKTOP="$BIN_DIR/pop-icon-keys-show-desktop"

# Seconds to wait for Solaar to exit after SIGTERM. Solaar saves its settings up
# to 5 seconds after a change and again on exit, so this must be longer than 5.
SOLAAR_STOP_WAIT=8

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

# Checks shared by setup and uninstall, before anything is read or changed.
preflight() {
  (( EUID != 0 )) || die "run this as your own user, not as root: it edits your config and your Solaar"
  [[ $HOME == /* && $HOME != *$'\n'* ]] || die "HOME must be an absolute path without newlines"
  local cmd
  for cmd in python3 pgrep; do
    command -v "$cmd" >/dev/null 2>&1 || die "$cmd is required but not installed"
  done
  python3 -I -c 'import sys, yaml; sys.exit(sys.version_info < (3, 8))' 2>/dev/null \
    || die "Python 3.8 or later with the yaml module is required (omarchy pkg add python-yaml)"
}

# One setup or uninstall at a time (a double press on Re-apply, two terminals).
take_lock() {
  (( DRY_RUN )) && return 0
  command -v flock >/dev/null 2>&1 || return 0
  local dir=${XDG_RUNTIME_DIR:-}
  [[ $dir == /* && -d $dir && -w $dir ]] || dir="$HOME/.cache"
  mkdir -p "$dir" || return 0
  exec 9>"$dir/pop-icon-keys.lock" || return 0
  flock -n 9 || die "another POP Icon Keys setup or uninstall is running; let it finish first"
}

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
# the newest 3 backups), writes atomically, keeps line endings, refuses broken
# markers, and prints a diff instead of writing under --dry-run.
edit() {
  POP_DRY_RUN=$DRY_RUN python3 -I "$PLUGIN_DIR/lib/edit.py" "$@"
}

# The mapped keys' Solaar control ids, from lib/edit.py (the single list of keys).
DIVERT_IDS=()
load_keys() {
  local out id
  out=$(edit keys) || die "could not read the plugin's key list (lib/edit.py)"
  while IFS=$'\t' read -r id _; do DIVERT_IDS+=("$id"); done <<<"$out"
  (( ${#DIVERT_IDS[@]} )) || die "the plugin's key list is empty"
}

# Replace the marked block in FILE with BODY, or remove it when BODY is empty.
# COMMENT is the file's line-comment prefix ("#" or "--"). Dies on broken markers
# or a file that cannot be read or written. Sets LAST_CHANGED=1 when FILE changed.
LAST_CHANGED=0
write_block() {
  local out rc=0
  out=$(printf '%s' "$3" | edit block "$1" "$2") || rc=$?
  [[ -n $out ]] && printf '%s\n' "$out"
  (( rc == 0 )) || die "$1 was left unchanged"
  LAST_CHANGED=0
  [[ $out == *"  changed: "* || $out == *"would change"* ]] && LAST_CHANGED=1
  return 0
}

# True when FILE has this plugin's marked block. Dies on broken markers, and on a
# file that cannot be read (not UTF-8, no permission), rather than reading it as
# "no block".
has_block() {
  local rc=0
  edit has-block "$1" "$2" || rc=$?
  case $rc in
    0) return 0 ;;
    1) return 1 ;;
    5) die "$1 needs fixing by hand first" ;;
    *) die "could not read $1 (see above); nothing was changed" ;;
  esac
}

# Print the rules on this plugin's keys outside its block, as "<plugin|other>\t<key>".
# Dies (in this shell, not a subshell) when rules.yaml cannot be read.
rules_scan() {
  local out
  out=$(edit rules-scan "$RULES_FILE" "$SHOW_DESKTOP") || die "could not read $RULES_FILE (see above); nothing was changed"
  printf '%s' "$out"
}

solaar_pids() { solaar_daemon_pids; }

# Pids stop_solaar signalled, for restart_solaar to wait on.
SOLAAR_OLD_PIDS=""

# Wait up to $2 seconds for the pids in $1 to exit. True when all are gone.
wait_gone() {
  local pids=$1 tries=$(( $2 * 4 )) pid alive
  while :; do
    alive=0
    for pid in $pids; do kill -0 "$pid" 2>/dev/null && alive=1; done
    (( alive )) || return 0
    (( tries-- > 0 )) || return 1
    sleep 0.25
  done
}

# Stop Solaar and wait for it to exit: SIGTERM, then SIGKILL after
# SOLAAR_STOP_WAIT seconds. Returns 1 if a Solaar is still running after that.
stop_solaar() {
  local pids
  pids=$(solaar_pids)
  [[ -n $pids ]] || return 0
  if (( DRY_RUN )); then
    say "  [dry-run] stop Solaar (pid $(echo $pids))"
    return 0
  fi
  SOLAAR_OLD_PIDS=$pids
  # shellcheck disable=SC2086
  kill $pids 2>/dev/null || true
  wait_gone "$pids" "$SOLAAR_STOP_WAIT" && [[ -z $(solaar_pids) ]] && return 0
  warn "Solaar did not exit within ${SOLAAR_STOP_WAIT}s; stopping it with SIGKILL"
  # shellcheck disable=SC2086
  kill -KILL $pids 2>/dev/null || true
  wait_gone "$pids" 2 && [[ -z $(solaar_pids) ]]
}

# Start Solaar in the background unless one is running, and check that it stays up.
start_solaar() {
  [[ -n $(solaar_pids) ]] && return 0
  if (( DRY_RUN )); then
    say "  [dry-run] start Solaar: setsid -f solaar --window=hide"
    return 0
  fi
  # 9>&-: Solaar must not inherit setup's lock (take_lock), or it would hold it forever.
  if setsid -f solaar --window=hide >/dev/null 2>&1 </dev/null 9>&-; then
    local _
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12; do
      [[ -n $(solaar_pids) ]] && return 0
      sleep 0.25
    done
  fi
  warn "could not start Solaar; start it with: solaar --window=hide"
  return 1
}

# Start Solaar again after stop_solaar: wait for the old one to finish exiting
# (it may still be saving), then start a new one if none is running.
restart_solaar() {
  if [[ -n $SOLAAR_OLD_PIDS ]] && ! wait_gone "$SOLAAR_OLD_PIDS" "$SOLAAR_STOP_WAIT"; then
    # shellcheck disable=SC2086
    kill -KILL $SOLAAR_OLD_PIDS 2>/dev/null || true
    wait_gone "$SOLAAR_OLD_PIDS" 2 || true
  fi
  SOLAAR_OLD_PIDS=""
  start_solaar
}

# Set the diversion of DIVERT_IDS to VALUE (1 diverted, 0 regular) in Solaar's
# saved config, for every saved entry of the keyboard. Solaar must be stopped: a
# running Solaar writes its in-memory state back over the file.
# Returns 3 when Solaar has no saved entry for the keyboard yet, 4 when the file
# could not be read, understood or written (left unchanged).
set_diversion() {
  edit divert "$SOLAAR_CONFIG" "$DEVICE" "$1" "${DIVERT_IDS[@]}"
}

# Reload Hyprland so binding and autostart changes apply. Returns 1 on failure.
reload_hyprland() {
  command -v hyprctl >/dev/null 2>&1 || return 0
  if (( DRY_RUN )); then
    say "  [dry-run] hyprctl reload"
    return 0
  fi
  hyprctl reload >/dev/null 2>&1 && return 0
  warn "could not reload Hyprland; the change applies after your next login"
  return 1
}
