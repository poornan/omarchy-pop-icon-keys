# 5. Presets for keyboards other than the POP Icon Keys

Date: 2026-11-19

## Status

Accepted, **simplified by owner decision D19** (2026-11-19; see
[ADR 0009](0009-slim-v0-4-0-scope.md)). The first version of this record (after
the architect review of 2026-11-19, items M1 to M9) described an action table,
an applied-state file, strict contributor validation and a backend seam. D19
deferred those; this text is what v0.4.0 builds. Rename:
[ADR 0006](0006-rename-to-logitech-keys.md). Battery:
[ADR 0007](0007-battery-from-keyboard-notifications.md). The backend seam
([ADR 0008](0008-swappable-input-backend.md)) is deferred.

**Terminology.** The owner calls these files *presets*. The files live in
`profiles/<slug>.json` (the directory name is kept so no partly built work moves)
and the code says "profile"; user-facing text says "preset" or just "keyboard".
The spec's Glossary records the mapping.

Owner decisions behind it: D1 ("make it multi-keyboard before submitting"),
D3 (POP Icon Keys and MX Keys for Mac), D4 (MX ships untested to demonstrate the
extension structure; its device data was later verified from hardware, key
presses still untested), D5 (no per-user overrides), D6 (one bar icon for all
keyboards), D7 (architect items M1 to M9, now partly deferred, below) and **D19**
(slim v0.4.0). Full quotes are in the Ambiguity Log of
[the spec](../specs/logitech-keys-profiles.md).

## Context

Other Logitech keyboards (MX Keys, MX Keys Mini, POP Keys, K-series) have
similar divertable special keys under Solaar. Until v0.3 the device name, Solaar
key names, control ids, commands and the Lock shortcut were repeated in several
files (`lib.sh`, `lib/edit.py`, the status and restore helpers, `Panel.qml`,
tests); two v0.3 facts show the cost: control ids 212 and 266 were swapped in the
`RULES` data of `lib/edit.py`, which status and restore read.

Solaar's own behaviour constrains the design (checked on Solaar 1.1.20):

- `solaar show/config <name>` matches any device whose name *contains* the
  argument; `config` acts on the first online match.
- The diversion lines in `solaar show` use key names with suffix variants
  (`Search / MultiPlatform Search`, `Screen Capture/Print Screen`).
- Rule conditions are `Device`, `Active` and `Host` (and key, modifier and
  similar); there is no `Model` condition. `Device` matches by name.
- Solaar's rule editor drops comments.
- `Modifiers` returns False without a keymap on Wayland.
- A keyboard's name differs by state: `solaar show` prints "MX Keys for Mac" while
  it is online, but Solaar saves the **codename** "MX Keys Mac" as `_NAME` in
  `config.yaml` while it is offline.
- Plain `solaar show` (all devices) can crash partway: on the owner's machine it
  raises `UnicodeDecodeError` in `get_host_names` while printing the MX Master 4,
  after the POP Icon Keys block, with a non-zero exit. `solaar show "<name>"`
  for one device works.
- The owner runs the Solaar daemon as `solaar -dd --window=hide` (debug flags), so
  process detection must not depend on the exact command line.
- Solaar's own GUI already offers diversion dropdowns and a rule editor with
  Execute actions (the reason for D19).

## Decision

- **Presets.** One file per keyboard in `profiles/<slug>.json`, `"schema": 1`:
  `slug`, `displayName`, `modelIds`, `names`, `osMode`, `keys` (`name`, `cid`,
  `label`, `command`: an argument list for an Omarchy command), optional
  `bindings` (`chord`, `label`, `command`) for keys Solaar cannot divert (POP
  Lock), optional `battery` (`{"feature": ...}`, ADR 0007), optional `note`,
  optional `verified` (`solaar`, `date`, `fnSwap`; it means "tested"). One
  reader, `lib/profiles.py`, validates **basically**: required fields and types,
  slug equals the file name, model ids of twelve uppercase hex digits, cid paired
  with name, no duplicate cids or key names, a command that is a non-empty list of
  control-free strings, a chord matching a fixed regex, a closed list of battery
  features and OS modes, no model id or name shared by two presets, unknown
  top-level fields refused. Nothing else reads preset files; bash never parses
  them (no `jq`); `Panel.qml` knows no keyboard.
- **Identity.** A keyboard matches a preset by exact model id first, then by exact
  name. Never by substring. A preset's `names` lists **every name Solaar can use
  for the keyboard**, so the MX preset lists both "MX Keys for Mac" (as `solaar
  show` names it online) and "MX Keys Mac" (the codename Solaar saves while it is
  offline); a test pins both. Status and restore query each preset's keyboard by
  exact selector (`solaar show "<name>"`), **never `solaar show all`**, parse
  every returned block on its own and verify its `Model ID:` (or exact name); a
  block that is not the preset's keyboard is not this device and makes that
  selector ambiguous (restore skips it). Output that is truncated, crashed or
  timed out leaves the keyboards not fully printed in the **unknown** state:
  never disconnected, never not set up, never warned about, never restored; a
  block that parsed completely is kept.
- **Always `Device`.** Every generated rule carries a `Device` condition (an `Or`
  over the preset's `names`). Rules never fire for another keyboard, and a
  hand-diverted key on an unprofiled keyboard does not trigger the plugin's
  rule.
- **Commands in presets (accepted risk, D19).** The architect's action table
  (M3: a preset names an action id, `lib/actions.json` maps it to a command) is
  **deferred**. A preset therefore holds the command Solaar runs on a key press,
  so a preset pull request can put a command on a key. This is mitigated **only by
  maintainer review** of preset pull requests; the README says so. Cheap
  injection safety stays: the command is validated as an argument list, chords
  must match the regex, and one module (`lib/rules.py`) holds all escaping for
  YAML, Lua and shell text. The helper placeholder `@show-desktop` is the only
  non-literal argument.
- **No applied record (M6 deferred).** Setup keeps no state file about what it
  diverted. Uninstall resets the diversion for the control ids of the presets of
  the known keyboards, as v0.3 did. **Limit, stated in the plan:** a key that the
  user diverted for themselves on the same control id is reset too, and the plan
  lists the ids. A preset change that removes a control id leaves that id
  diverted with no rule until the user resets it in Solaar.
- **Simple v0.3 cleanup (M7 reduced).** Setup removes `pop-icon-keys` marked
  blocks and the old helper `pop-icon-keys-show-desktop`, with consent, listed in
  the plan, and warns when `io.github.poornan.pop-icon-keys` is still installed.
  Detecting v0.3 rules that Solaar's editor rewrote without markers is deferred;
  setup's existing warning about "other" rules on a handled key covers them.
- **Setup scope.** Setup applies presets for keyboards recorded in Solaar's
  `config.yaml`; on a fresh install the consent plan lists the supported
  keyboards and setup applies whichever Solaar then records (two phases: resolve
  the set, then apply it with the rules in place before the diversion; Solaar is
  stopped while `config.yaml` is written and restarted after). Setup warns, never
  blocks or changes, when a keyboard's OS mode differs from the preset's `osMode`.
- **Tested versus untested.** A preset is tested only if it has a `verified`
  block (no boolean). One recorded `solaar show` fixture per preset; the routed,
  dropped and not-set-up variants are derived in tests. Synthetic fixtures are
  labelled and never count as verification. The consent plan, README and widget
  mark untested presets.
- **States.** A key in neither diversion line is `absent` (a wrong cid must not
  keep the icon red); `unknown` as above. The widget shows one state per keyboard.
- **Permanent slugs.** A released slug is never renamed or reused for another
  model.
- **Rename** to a device-neutral id before the first marketplace submission
  (ADR 0006).

### Deferred by D19 (not deleted ideas)

| Architect item | What it was | Why deferred |
|---|---|---|
| M3 | Action table `lib/actions.json`, presets name an action id | Costs a reviewed edit per new command and a second file for contributors; accepted risk above |
| M6 | `applied.json`, reconcile on setup, uninstall from the record | Needs a record writer, a union-before-divert order and damaged-record handling; the v0.3 reset-the-known-ids behaviour is enough for two keyboards |
| M7 (most) | Detect v0.3 rules Solaar rewrote without markers | Rare; the "other rules" warning covers it |
| M8 (most) | Strict schema (permanent-slug list, substring and chord-conflict checks), key-table snapshot cross-check in CI, PR template, CODEOWNERS | Basic validation and review are enough for the first submission; an optional local key-table check may exist |
| ADR 0008 | Swappable Solaar/OpenLogi backend | OpenLogi cannot remap keyboard keys on Linux |

### Non-goals

- Modifier conditions (Solaar's `Modifiers` returns False with no keymap on
  Wayland).
- Gestures and thumb buttons.
- Per-OS-mode variants: the top-level `osMode` records the mode and a preset
  assumes that one mode; the plugin never changes it.
- Per-user overrides.
- Key-release events.

## Consequences

- Adding a keyboard is a one-file pull request plus a recorded fixture and a
  README row; a new command is just a different `command` in that file, which a
  maintainer reviews.
- A preset can run any command as the user when its key is pressed; the price of
  dropping the action table is review discipline and the README's statement of
  the risk.
- Setup writes marked blocks only and keeps no other state of its own except the
  battery files of ADR 0007.
- No schema-migration machinery: presets live in the repo, so a schema change is
  one commit.
