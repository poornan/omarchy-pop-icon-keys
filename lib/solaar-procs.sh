# Find the current user's Solaar background program (the daemon), not one-off
# `solaar show` / `solaar config` runs. Sourced by lib.sh and bin/pop-icon-keys-status.
# shellcheck shell=bash

# Solaar's command-line actions. A Solaar process given one of these is a
# one-off command that exits on its own, not the background program.
SOLAAR_ACTIONS=" show probe profiles config pair unpair "

# True when /proc/PID/cmdline is a Solaar daemon: "solaar" (run directly or
# through python) with options only, no action.
solaar_is_daemon() {
  local pid=$1 args=() i n found=0
  [[ -r /proc/$pid/cmdline ]] || return 1
  mapfile -d '' args <"/proc/$pid/cmdline" 2>/dev/null || return 1
  n=${#args[@]}
  for (( i = 0; i < n; i++ )); do
    if [[ ${args[i]##*/} == solaar ]]; then found=1; break; fi
  done
  (( found )) || return 1
  for (( i = i + 1; i < n; i++ )); do
    case ${args[i]} in
      # Options that take their value as the next argument (`-w show` is not the show action).
      -w|--window|-D|--hidraw|-b|--battery-icons|--tray-icon-size) i=$((i + 1)) ;;
      -*) ;;
      *) [[ $SOLAAR_ACTIONS == *" ${args[i]} "* ]] && return 1 ;;
    esac
  done
  return 0
}

# Pids of this user's Solaar daemon(s), one per line. Solaar's process name is
# "solaar" (it is a Python script), so the name is matched exactly; a pattern
# match on the command line would also hit the shell running this script.
solaar_daemon_pids() {
  local pid
  for pid in $(pgrep -u "$(id -u)" -x solaar 2>/dev/null); do
    solaar_is_daemon "$pid" && echo "$pid"
  done
  return 0
}
