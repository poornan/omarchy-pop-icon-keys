# 4. Restore diversion the keyboard drops, at runtime

Date: 2026-11-19

## Status

Accepted

## Context

The keyboard can drop its live diversion by itself (observed: saved settings
said Diverted, the keyboard reported Regular; restarting Solaar restored it).
The likely trigger is sleep or reconnect. Solaar does not always re-apply it.
Polling `solaar show` does not cause it.

## Decision

The status helper reports live and saved diversion separately. When a key is
saved as Diverted but live Regular, the widget re-applies it with
`solaar config` (no file edit, no restart), at most once a minute, controlled
by the `autoRestore` setting (default on), with a manual Restore button.

## Consequences

- Keys can be dead for up to the poll interval (2 minutes) after a drop.
- Restore needs a running Solaar daemon.
- A re-check runs 8 s after a restore, after Solaar's deferred save.
