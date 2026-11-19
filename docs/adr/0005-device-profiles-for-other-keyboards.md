# 5. Device profiles for keyboards other than the POP Icon Keys

Date: 2026-11-19

## Status

Accepted. Amended after the architect review of 2026-11-19 (identity, actions,
`Device` rule, applied state, `absent`, schema field, non-goals). Rename:
[ADR 0006](0006-rename-to-logitech-keys.md).

## Context

Other Logitech keyboards (MX Keys, MX Keys Mini, POP Keys, K-series) have
similar divertable special keys under Solaar. Until v0.3 the device name, Solaar
key names, control ids, actions and the Lock shortcut were repeated in several
files (`lib.sh`, `lib/edit.py`, the status and restore helpers, `Panel.qml`,
tests). A contributor adding a keyboard would have to edit all of them. Two
v0.3 facts show the cost: the `RULES` data in `lib/edit.py` had control ids 212
and 266 swapped, and status and restore read that data.

Solaar's own behaviour constrains the design (checked on Solaar 1.1.20):

- `solaar show/config <name>` matches any device whose name *contains* the
  argument; `config` acts on the first online match.
- The diversion lines in `solaar show` use key names with suffix variants.
- Rule conditions are `Device`, `Active` and `Host` (and key, modifier and
  similar); there is no `Model` condition.
- Solaar's rule editor drops comments.
- `Modifiers` returns False without a keymap on Wayland.

## Decision

- **Profiles.** One file per keyboard in `profiles/<slug>.json` with
  `"schema": 1`. Fields: `slug`, `displayName`, `modelIds`, `names`, `keys`
  (`name`, `cid`, `label`, `action`), optional `bindings` (`chord`, `action`,
  `label`) and optional `verified` (`solaar`, `date`, `osMode`, `fnSwap`). One
  reader, `lib/profiles.py`, validates strictly: unknown fields fail; name and
  cid are paired and, where Solaar is importable, cross-checked against its
  `CONTROL` table; model ids and chords match fixed formats. Nothing else reads
  profile files; bash never uses `jq` on them; `Panel.qml` knows no keyboard.
- **Identity.** A keyboard matches a profile by exact model id first, then by
  exact name. Never by substring. Validation refuses a profile name that is a
  substring of another's. Status checks each device block's `Model ID:` line;
  restore skips an ambiguous selector.
- **Action vocabulary.** Profiles name an action id; `lib/actions.json` maps it
  to an argument list or plugin helper. A contributor PR therefore cannot put an
  arbitrary command in a Solaar rule or Lua string. A new action is a reviewed
  edit to the table, the one allowed non-profile change in a keyboard PR.
- **Always `Device`.** Every generated rule carries a `Device` condition (an
  `Or` over the profile's names). No `Model` condition. Rules never fire for
  another keyboard, and a hand-diverted key on an unprofiled keyboard does not
  trigger the plugin's rule. `classify()` recognises the new and v0.3 shapes.
- **Applied state.** `$XDG_STATE_HOME/logitech-keys/applied.json` records slug,
  control ids and plugin version per applied profile. Setup reconciles against
  it (a removed id is reset and its rule deleted); uninstall resets from it and
  deletes it. Comments in rules are not state.
- **Permanent slugs.** A released slug is never renamed or reused for another
  model.
- **`absent` state.** A key in neither diversion line is `absent`: dimmed, and
  not counted toward needing setup. A wrong cid in an untested profile must not
  keep the bar icon red.
- **Status and widget.** `lib/status.py` parses the diversion lines exactly and
  emits JSON with a `schema` field and one section per connected profiled
  keyboard. One bar icon, one popup section per keyboard.
- **Tested versus untested.** A profile is tested only if it has a `verified`
  block. One recorded `solaar show` fixture per profile; routed, dropped and
  not-set-up variants are derived. Synthetic fixtures never count as
  verification. The plan, README and widget mark untested profiles.
- **Setup scope.** Setup applies profiles for keyboards in Solaar's
  `config.yaml`; on a fresh install the consent plan lists the supported
  keyboards and setup applies whichever Solaar then records.
- **Contributor gate.** CI runs the stdlib tests; a PR template carries the
  checklist; CODEOWNERS gives the maintainer `profiles/`, `lib/actions.json` and
  `lib/`.
- **Rename** to a device-neutral id before the first marketplace submission
  (ADR 0006).

### Non-goals

- Modifier conditions (Solaar's `Modifiers` returns False with no keymap on
  Wayland).
- Gestures and thumb buttons.
- Per-OS-mode variants: `verified.osMode` records the mode and a profile assumes
  that one mode.
- Per-user overrides.
- Key-release events.

## Consequences

- Adding a keyboard is a one-file PR plus a fixture and a README row; a new
  action also edits the action table.
- A profile cannot run an arbitrary command; the price is a maintainer-reviewed
  action table.
- Two persistent stores of ours: marked blocks in config files and
  `applied.json`.
- No schema-migration machinery: profiles live in the repo, so a schema change
  is one commit.
- More moving parts in setup and the widget; the spec and plan cover them.
