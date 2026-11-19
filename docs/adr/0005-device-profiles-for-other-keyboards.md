# 5. Device profiles for keyboards other than the POP Icon Keys

Date: 2026-11-19

## Status

Accepted. Amended after the architect review of 2026-11-19 (identity, actions,
`Device` rule, applied state, `absent`, schema field, non-goals) and again after
the plan review of the same day (module layout, applied-record order and
content, injected key table, escaping, restore, two-phase setup), and a third
time for the swappable backend ([ADR 0008](0008-swappable-input-backend.md)); a
fourth time for the Solaar `show` crash (per-device queries, `unknown` state).
Rename: [ADR 0006](0006-rename-to-logitech-keys.md).

Owner decisions behind it: D1 ("make it multi-keyboard before submitting"),
D3 (POP Icon Keys and MX Keys for Mac), D4 (MX ships untested to demonstrate
the extension structure; its device data was later verified from hardware, key
presses still untested), D5 (no per-user overrides), D6 (one bar icon for all
keyboards) and **D7** ("apply architect must-fix changes when it finishes":
architect items M1–M9, including action ids and the applied-state record). Full
quotes are in the Ambiguity Log of
[the spec](../specs/logitech-keys-profiles.md). **ADR 0008** (a swappable Solaar or
OpenLogi backend, decision D13) extends this ADR: profiles stay
backend-neutral, and the Solaar-specific parts below (rules, `config.yaml`
diversion, the `Device` condition, the applied record's entries) are the Solaar
backend's implementation, behind a backend seam. Additions after the 2026-11-19
verification: an optional profile `note` (one line of plain text), an optional
`battery` field naming the HID++ battery feature
([ADR 0007](0007-battery-from-keyboard-notifications.md)), a required top-level
`osMode` (moved out of `verified`, and corrected: the keyboards run in MacOS
mode, not Linux), an optional `backends` section, and a `verified` block without
`osMode`.

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
- Plain `solaar show` (all devices) can crash partway: on the owner's machine
  (Solaar 1.1.20) it raises `UnicodeDecodeError` in `get_host_names` while
  printing the MX Master 4 (host-name chunks of 14 bytes are decoded separately),
  after the POP Icon Keys block and before the Unifying receiver, with a
  non-zero exit. `solaar show "<name>"` for one device works.

## Decision

- **Profiles.** One file per keyboard in `profiles/<slug>.json` with
  `"schema": 1`. Fields: `slug`, `displayName`, `modelIds`, `names`, `keys`
  (`name`, `cid`, `label`, `action`), required top-level `osMode` (a Solaar
  multiplatform OS base name: Linux, MacOS, Windows, iOS, Android, WebOS, Chrome,
  WinEmb or Tizen; both shipped keyboards are `MacOS`), optional `bindings`
  (`chord`, `action`, `label`), optional `battery` (`{"feature": "UNIFIED
  BATTERY" | "BATTERY STATUS"}`, ADR 0007), optional `note`, optional
  `backends` (only the key `openlogi`: `{names?, verified?}`; keys a subset of the
  profile's cids; a verified block needs a recorded, non-synthetic OpenLogi
  fixture; ADR 0008) and optional `verified` (`solaar`, `date`, `fnSwap`, the
  Solaar reference; it means "tested"). One
  reader, `lib/profiles.py`, validates strictly: unknown fields fail; name and
  cid are paired and, where Solaar is importable, cross-checked against its
  `CONTROL` table; model ids and chords match fixed formats. Nothing else reads
  profile files; bash never uses `jq` on them; `Panel.qml` knows no keyboard.
- **Identity.** A keyboard matches a profile by exact model id first, then by
  exact name. Never by substring. Validation refuses a profile name that is a
  substring of another's. Status checks each device block's `Model ID:` line;
  restore skips an ambiguous selector. **Status and restore do not rely on one
  `solaar show all` call** (it can crash, see Context; this replaces the earlier
  plan to split one `solaar show all` per device): they query each profiled
  device by exact selector, and because `solaar show "<name>"` still matches by
  name substring they parse every returned block on its own and treat a block
  whose `Model ID:` (or exact name) is not the profile's as not this device, which
  also makes that selector ambiguous. Details: ADR 0008, "The Solaar backend
  queries one device at a time".
- **Action vocabulary.** Profiles name an action id; `lib/actions.json` maps it
  to an argument list or plugin helper. A contributor PR therefore cannot put an
  arbitrary command in a Solaar rule or Lua string. A new action is a reviewed
  edit to the table, the one allowed non-profile change in a keyboard PR.
- **Always `Device`.** Every generated rule carries a `Device` condition (an
  `Or` over the profile's names). No `Model` condition. Rules never fire for
  another keyboard, and a hand-diverted key on an unprofiled keyboard does not
  trigger the plugin's rule. `classify()` recognises the new and v0.3 shapes.
- **Applied state.** `$XDG_STATE_HOME/logitech-keys/applied.json` records slug,
  control ids, the matched saved entry names and model ids, and the plugin
  version per applied profile. Setup writes the union of the old and new ids
  before the diversion and the final ids afterwards, so a stop in between still
  lets uninstall reset everything (resetting a never-diverted id is harmless);
  it reconciles against the record (a removed id is reset and its rule deleted).
  Uninstall resets from it, even for a profile that no longer ships, and deletes
  it. The record is written atomically with no `.bak`; a damaged or newer record
  stops setup and uninstall before any change. Comments in rules are not state.
- **Backend seam.** The modules below are the Solaar backend, reached through
  `lib/backends/solaar.py` (ADR 0008); profiles, status JSON and the widget are
  backend-neutral. The applied record gains a `backend` field and per-backend
  `artifacts`.
- **Module layout.** `lib/edit.py` is the command line only. One module owns each
  concern: `lib/solaarcfg.py` (the one device-to-profile matcher and
  `config.yaml` entry parsing), `lib/fileedit.py` (read, back up, atomic write,
  marked blocks with the mark as a parameter), `lib/diversion.py`,
  `lib/rules.py` (rule and Lua generation, classification and **all escaping**:
  YAML flow, Lua string and shell argument, one function each),
  `lib/applied.py`, `lib/legacy.py` (the single frozen v0.3 table) and
  `lib/plan.py` (the consent plan as data). `lib/profiles.py` stays pure data
  with the profile folder as an argument. Bash knows no keyboard.
- **Key table.** The cross-check against Solaar's key table takes the table as an
  injected parameter: the installed Solaar's `CONTROL`, else a snapshot committed
  with the tests so CI stays stdlib-only. On the development machine the
  Solaar-dependent checks run with zero skips.
- **Restore.** Restore addresses the keyboard by the matched device block's exact
  printed name and skips a keyboard whose name is contained in another device's
  name; it never writes a config file.
- **Setup is two-phase.** Resolve the profile set first (one start-record-stop
  when Solaar knows no profiled keyboard), then apply that set idempotently with
  the rules in place before the diversion.
- **Permanent slugs.** A released slug is never renamed or reused for another
  model.
- **`absent` state.** A key in neither diversion line is `absent`: dimmed, and
  not counted toward needing setup. A wrong cid in an untested profile must not
  keep the bar icon red.
- **`unknown` state.** A keyboard Solaar knows but whose `solaar show` output was
  truncated, crashed or timed out is `unknown`: never disconnected and never not
  set up; dimmed, not counted toward the warning, not restored. A block that
  parsed completely is kept.
- **Status and widget.** `lib/solaarshow.py` parses the diversion lines exactly
  and `lib/statuscontract.py` builds the JSON with a `schema` field and one section
  per connected profiled keyboard (ADR 0008, module layout after round 6). One bar icon, one popup section per keyboard.
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
- Per-OS-mode variants: the top-level `osMode` records the mode and a profile
  assumes that one mode.
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
