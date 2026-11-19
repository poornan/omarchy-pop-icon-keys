# 9. Slim v0.4.0 scope

Date: 2026-11-19

## Status

Accepted. Owner decision **D19** (requires-stakeholder-input, resolved by the
human): the owner chose "Slim, keep battery" over "Slim, drop battery" and "Full
plan", after seeing that Solaar's own GUI covers key diversion dropdowns and a
rule editor with Execute actions. This record narrows
[ADR 0005](0005-device-profiles-for-other-keyboards.md) and defers
[ADR 0008](0008-swappable-input-backend.md); it leaves
[ADR 0006](0006-rename-to-logitech-keys.md) and
[ADR 0007](0007-battery-from-keyboard-notifications.md) standing.

## Context

By the sixth plan-review round the design had nine slices, about 3,000 plan lines,
an action table, an applied-state file, a backend seam with an OpenLogi
read-only backend and a resumable backend switch. Solaar already lets a user
divert a key and attach an Execute action by hand. What the plugin adds that
Solaar does not: ready-made presets per keyboard, a one-command setup with
consent, the restore of keys the keyboard drops after sleep, a way to start
Solaar after closing its window quits it, and a battery figure that is not stale.

## Decision

**Keep (v0.4.0):** the rename to Logitech Keys; presets for POP Icon Keys
(tested) and MX Keys for Mac (untested key presses); match by model id then exact
names (the MX preset lists both "MX Keys for Mac" and "MX Keys Mac"); every rule
has a `Device` condition; setup and uninstall with consent, dry run, backups,
marked blocks, Solaar stopped while `config.yaml` is written, the Lock binding
and Solaar autostart; a simple v0.3 cleanup; restore of dropped keys and the
Start Solaar action; accurate battery (ADR 0007); per-device `solaar show`
queries with the `unknown` state; a small widget; a short README with "Add your
keyboard"; CI running the existing tests.

**Defer (not deleted ideas; reasons in the spec as "Deferred by D19"):**

| Deferred | Reason |
|---|---|
| Swappable backend, OpenLogi backend, switching (ADR 0008 -> Deferred) | OpenLogi cannot remap keyboard keys on Linux; revisit if it can. The `disable --now` path (D15) is not built. The architect's design file stays as reference |
| Strict preset schema beyond basic validation | Review plus basic checks suffice for two keyboards |
| Action table (M3) | A second file per new command. **Accepted risk:** a preset pull request can put a command that Solaar runs on a key press; mitigated only by maintainer review; the README says so (ADR 0005) |
| `applied.json` and reconcile (M6) | Uninstall resets the known presets' ids as v0.3 did; the limit is stated in the plan |
| Legacy-rule migration machinery (M7) | A simple cleanup of marked v0.3 blocks and the old helper remains |
| CODEOWNERS and PR template | Single maintainer; the README states what a PR must contain |
| Solaar key-table cross-check in CI | Optional local check only |
| Per-key widget UI, `unsupportedByBackend`, `otherRunning`, `liveKeyState` | Belong to the deferred backend seam or the full widget |
| LogiOps | Already deferred (spec row 40) |

## Consequences

- The plan shrinks to six slices with an installable checkpoint after setup,
  restore and the widget work for the POP preset.
- The code base stays close to v0.3: `lib/edit.py` is kept and made
  preset-driven rather than split into many modules.
- The deferred designs remain documented, so a later version can pick them up
  without redoing the research.
