# 3. Persist key diversion by editing Solaar's config while it is stopped

Date: 2026-11-19

## Status

Accepted

## Context

`solaar config <device> divert-keys <key> Diverted` changes the keyboard
immediately, but a running Solaar writes its in-memory settings back over
`~/.config/solaar/config.yaml` when it exits. On the owner's machine, F6 and F7
went back to Regular after a Solaar restart. Solaar also defers saves by about
5 seconds.

## Decision

`setup` stops the user's Solaar daemon (waiting for it to exit), sets the
mapped control ids to 1 in `config.yaml` for every matching device entry, and
starts Solaar again on every exit path.

## Consequences

- Setup always restarts Solaar, and must never leave it stopped.
- Daemon detection must match only the current user's daemon, not `solaar`
  CLI runs.
- Hand edits to `divert-keys` in unusual YAML shapes must be handled or refused.
