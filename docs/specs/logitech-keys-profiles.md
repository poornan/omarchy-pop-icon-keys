<!-- spec-version: 1 -->
# Spec: Logitech Keys — keyboard profiles

**Builds on:** [pop-icon-keys-plugin.md](pop-icon-keys-plugin.md) (v0.3.0),
[ADR 0005](../adr/0005-device-profiles-for-other-keyboards.md) and
[ADR 0006](../adr/0006-rename-to-logitech-keys.md).
**Status:** gate passed 2026-11-19, re-run after the architect review
(`.dev-team-reports/architect-review-2026-11-19.md`, must-fix M1–M9 applied;
the owner pre-approved it with "apply architect must-fix changes").
The MX Keys for Mac profile ships **untested** (owner's choice; hardware not
available).

## Intent Description

The owner wants the plugin to support Logitech keyboards other than the POP
Icon Keys before it is submitted to the Omarchy marketplace, so that other
people can add their keyboard by pull request (B: "is this project extensible
moduler strcture for others to send PR for other keyboard than pop-icon";
"make it multi-keyboard before submitting").

Concretely:

1. The plugin is renamed to **Logitech Keys** with the permanent id
   `io.github.poornan.logitech-keys`; the repo becomes
   `poornan/omarchy-logitech-keys` later (B: owner chose "logitech-keys").
   The repo rename is not part of this change; docs use the new URL.
2. It ships with **two profiles**: POP Icon Keys (tested on owner hardware) and
   MX Keys for Mac, **untested**, drafted from Solaar's saved settings for the
   owner's keyboard and Solaar's key table (B: "POP + MX Keys for Mac"; then,
   with the keyboard unavailable, "Ship MX as untested"). Its main purpose is
   to **demonstrate the extension structure**: a second keyboard added as data
   only, the worked example contributors copy (B: "adding MX to show
   extendability (source code strcture)").
3. Adding a keyboard is a **pull request that adds one profile file** plus one
   recorded `solaar show` fixture and a README row. A profile names *actions*
   from a reviewed action table, never commands.
4. **No per-user override file** in this version (B: "Not now").
5. **One bar icon for all connected profiled keyboards**; the popup lists each
   keyboard (B: "One icon, all keyboards").
6. The repo gates contributions: strict profile validation, CI, a PR checklist
   and code owners, so a profile PR cannot run arbitrary commands or break
   another keyboard (architect review M3, M8).

Everything the POP Icon Keys spec requires (AC1–AC18 there) keeps holding for
the POP Icon Keys profile.

Out of scope: mice and other non-keyboard devices, per-user action overrides,
non-Logitech keyboards, keyboards Solaar cannot divert keys on, modifier-key
conditions (Solaar's `Modifiers` condition returns False without a keymap on
Wayland), gestures and thumb buttons, per-OS-mode variants (a profile assumes
the one OS mode in its `verified.osMode`), key-release events.

## Architecture Specification

- **Profiles** live in `profiles/<slug>.json`, one per keyboard model. Format
  (`"schema": 1`):
  - `slug`, `displayName`;
  - `modelIds`: required list of Solaar model ids (12 hex digits). Primary
    identity. `names`: required list of exact Solaar device names; fallback
    where Solaar records the name instead of an all-zero model id, and the
    values of the rule `Device` condition. Never substrings.
  - `keys`: list of `{name, cid, label, action}`. `name` is Solaar's key name,
    `cid` its control id, always given together. `label` is the human text for
    the popup and plan. `action` is an action id.
  - `bindings` (optional): list of `{chord, action, label}` Hyprland bindings
    for keys Solaar cannot divert (POP Icon Keys Lock: `SUPER + CTRL + Q` →
    `lock`). `chord` must match a fixed regex (modifiers plus one key).
  - `verified` (optional): `{solaar, date, osMode, fnSwap}`. A profile is
    **tested** if and only if `verified` is present. There is no `tested`
    boolean.
  - Unknown fields fail validation.
- **Action table** `lib/actions.json` maps an action id to an argument list or
  a plugin helper (`show-desktop`, `app-launcher`, `dictation`, `emoji-picker`,
  `region-screenshot`, `lock`, `calculator`). It is the single place commands
  live. Adding an action is a reviewed edit to this file, owned by the
  maintainer; it is the one allowed non-profile change in a keyboard PR.
- **One reader** `lib/profiles.py` loads and strictly validates profiles and the
  action table. Validation: schema field, required fields, cid paired with
  name, labels, known action ids, chord regex, model-id format, unique slugs,
  no profile name that is a substring of another profile's name, and, when
  `logitech_receiver.special_keys.CONTROL` is importable, name/cid pairs match
  Solaar's table (skipped when Solaar is missing). `setup`, `uninstall`, the
  status and restore helpers and tests get keyboard data only through it. Bash
  never parses profiles (no `jq` on profiles); `Panel.qml` has no keyboard
  knowledge.
- **Identity:** a keyboard matches a profile by exact model id, then by exact
  name. Never by substring: `solaar show/config "MX Keys"` would match "MX Keys
  for Mac", "MX Keys Mini" and "MX Keys S". Status reads `solaar show all`,
  splits it per device block and checks each block's `Model ID:` line. Restore
  skips a keyboard whose selector is ambiguous.
- **Status:** `lib/status.py` parses the two diversion lines per key exactly
  (key-name suffix pairs such as "Search" / "MultiPlatform Search" are handled
  by cid, not by substring) and prints JSON: a `schema` field and one section
  per connected profiled keyboard (name, battery, `tested`, keys with label and
  state). Key state is `routed`, `dropped`, `notSetUp` or `absent`. `absent` = the
  key is in neither diversion line; it shows dimmed and does not count toward
  needing setup. The bash helper `bin/logitech-keys-status` only runs it.
- **Rules:** one marked block in `rules.yaml` with the rules of every applied
  profile. **Every rule has a `Device` condition** (an `Or` over the profile's
  `names`); no `Model` condition (Solaar 1.1.20 has none). Rules therefore never
  fire for another keyboard, even with the same key name. `classify()`
  recognises the new rule shape and the v0.3 shapes.
- **Diversion:** set per matching `config.yaml` device entry from that
  profile's control ids. Solaar keeps separate entries for Bluetooth and Bolt,
  so all entries matching `modelIds` or `names` are written.
- **Applied state:** `$XDG_STATE_HOME/logitech-keys/applied.json` (default
  `~/.local/state`) records, per applied profile, slug, control ids and plugin
  version. `setup` reconciles against it: ids no longer in the profile are reset
  and their rules removed. `uninstall` resets from it and deletes it. Rule
  comments are not used for state (Solaar's editor drops them). **Slugs are
  permanent:** never renamed or reused for another model.
- **Setup scope:** applies profiles for keyboards present in Solaar's
  `config.yaml`. The consent plan lists the profiles it applies; on a fresh
  install, when Solaar has no entry for any profiled keyboard yet, the plan
  lists all **supported keyboards** (with tested/untested) and says setup
  applies whichever profiles Solaar then records (this keeps the v0.3 order:
  plan, consent, start Solaar, apply).
- **Hyprland bindings:** one marked Lua block, command resolved from the action
  table; chords are validated by regex, no contributor string reaches Lua.
- **Widget:** one bar icon; the popup has a section per connected profiled
  keyboard (battery, per-key routing, dropped-key state, "untested" badge). It
  warns if any keyboard has keys in `dropped` or `notSetUp`. Auto-restore works per
  keyboard. IPC target and QML module name are `logitech-keys`.
- **Rename and migration:** new id, display name, repo URL, marker text
  `logitech-keys`, helper names (`logitech-keys-*`). `setup` migrates v0.3
  state: marked `pop-icon-keys` blocks, **and** legacy rules that Solaar's rule
  editor rewrote without markers (a command ending in `pop-icon-keys-show-desktop`
  or the v0.3 argument lists), counting each as ours, not "other". It removes the
  old helper and old `pop-icon-keys` Lua blocks. `uninstall` removes old and new.
  `setup` warns when `io.github.poornan.pop-icon-keys` is still installed (its
  Re-apply would write old blocks; two widgets).
- **Contributor gate:** `.github/workflows/` runs the stdlib tests on push and
  PR; `.github/pull_request_template.md` carries the checklist (recorded
  fixture, masked serials, cids checked against `solaar show`, only existing
  action ids, README row, truthful `verified` block); `.github/CODEOWNERS`
  gives `poornan` `profiles/`, `lib/actions.json` and `lib/`.
- **Tests:** profile schema test (every profile); **one recorded** `solaar show`
  fixture per profile (`tests/fixtures/<slug>/`, first line carries the Solaar
  version, serials and unit ids masked, enforced by a test); routed, dropped and
  not-set-up variants are derived from the profile in the test. A synthetic
  fixture is labelled synthetic and never counts as verification. A sandbox
  setup run covers POP Icon Keys and the two-keyboard case; the other
  per-profile checks are fast pure-Python. No schema-migration machinery
  (schema change = one commit, profiles live in the repo).
- **Constraints:** unchanged from v0.3 (consent, marked blocks, atomic writes,
  Solaar stopped while writing `config.yaml`, marketplace baseline: no
  `curl | sh`, no sudo, no `/tmp` process control, no `/home` paths).

## Acceptance Criteria

- **AC1 —** The plugin id is `io.github.poornan.logitech-keys`, display name
  "Logitech Keys", and the README and install commands use
  `github.com/poornan/omarchy-logitech-keys`.
- **AC2 —** With only the POP Icon Keys known to Solaar, behaviour matches the
  POP Icon Keys spec AC1–AC18. This includes a fresh install where Solaar has
  no keyboard entry yet (see AC21).
- **AC3 —** With only the MX Keys for Mac known to Solaar, setup diverts and
  maps (Solaar control id → action): 225 Launchpad → `app-launcher`;
  191 Screen Capture/Print Screen → `region-screenshot`; 111 Screen Lock →
  `lock`; 10 Calculator → `calculator` (`omacalc`). Mission Control (224), Eject
  (13), brightness, backlight, media and volume keys are not diverted. The
  profile has no `verified` block; the plan, README and widget mark this keyboard
  **untested**.
- **AC3a —** Profiles use Solaar's own key names and control ids. POP Icon Keys:
  110 Show Desktop, 212 MultiPlatform Search, 259 Dictation, 264 Emoji,
  266 Screen Capture. v0.3 had 212 and 266 swapped in the `RULES` data of
  `lib/edit.py`, which status and restore read; diversion was unaffected only
  because both ids were listed. The new profile is the single source and a test
  pins these pairs.
- **AC4 —** With both keyboards known, setup applies both profiles in one
  consent-gated run, and each keyboard's keys run its own profile's actions,
  including a key name the two share (each rule carries its `Device` condition).
- **AC5 —** Adding a keyboard needs only a new `profiles/<slug>.json`, its one
  recorded fixture and a README row; no script or QML change. Needing an action
  that is not in `lib/actions.json` is the one allowed non-profile change, and is
  a reviewed edit to that table. A test fails if a profile is malformed or
  lacks its fixture.
- **AC6 —** The bar shows one icon. The popup lists every connected profiled
  keyboard with battery and per-key routing; the icon warns if any keyboard has
  keys that need setup or were dropped. Untested profiles are labelled.
- **AC7 —** A keyboard that drops diversion is restored without affecting the
  other keyboard. Restore does nothing for a keyboard whose selector matches
  more than one device.
- **AC8 —** Running the new `setup` over a v0.3 install replaces the old
  `pop-icon-keys` blocks with `logitech-keys` blocks, keeps one copy of each
  rule, and leaves user rules intact. `uninstall` removes both old and new
  blocks. (Legacy forms: AC17.)
- **AC9 —** README has an "Add your keyboard" section: how to read key names and
  ids with `solaar show`, the profile format, the action table, how to record the
  fixture, and what the PR must contain. It also notes: keycap labels depend on
  Fn-swap, Solaar may name a cid differently across versions, and releases batch
  profile PRs (new profile = minor, fix = patch).
- **AC10 —** All v0.3 safety tests still pass (adapted to profiles), plus
  profile schema, two-keyboard, status, applied-state and migration tests;
  dev-team review passes before release.
- **AC11 —** Identity is by exact model id, then exact name. A device named "MX
  Keys Mini" or "MX Keys S" does not match the MX Keys for Mac profile, and a
  profile named "MX Keys" would be refused by validation as a substring of
  another profile's name. Status checks each device block's `Model ID:` line.
- **AC12 —** Diversion lines are parsed in Python with exact key-name and cid
  matching; a fixture with Solaar's suffixed names (Search / MultiPlatform
  Search, Print Screen / Screen Capture/Print Screen) gives the right states.
  `Panel.qml` renders the JSON and contains no keyboard or key names.
- **AC13 —** Profile keys and bindings name an action id. Unknown ids, a command
  field, a chord outside the regex, or any unknown field fail validation. Rules
  and Lua blocks are generated from `lib/actions.json`.
- **AC14 —** Every generated rule has a `Device` condition over the profile's
  names and no `Model` condition. `classify()` treats new and v0.3 rule shapes
  as ours, and a hand-written rule on another keyboard as "other".
- **AC15 —** A key in neither diversion line has state `absent`: dimmed in the
  popup and not counted toward the icon's needs-setup warning.
- **AC16 —** `setup` writes `applied.json`; when a later profile drops a control
  id, `setup` resets that id and removes its rule. `uninstall` resets every id in
  `applied.json` and deletes it. Both leave other keys and user rules untouched.
- **AC17 —** Legacy migration: v0.3 rules rewritten by Solaar's editor without
  markers (including the `pop-icon-keys-show-desktop` path and the v0.3 argument
  lists) are replaced, not duplicated; the old helper and old Lua blocks are
  removed; `setup` warns if `io.github.poornan.pop-icon-keys` is still installed.
- **AC18 —** The profile reader enforces the schema in the Architecture
  Specification, including the Solaar `CONTROL` cross-check when Solaar is
  importable. Every shipped profile passes; a test mutates a valid profile into
  each failure case.
- **AC19 —** A profile is tested only if `verified` is present with `solaar`,
  `date`, `osMode`, `fnSwap`. Each profile has one recorded fixture whose first
  line holds the Solaar version and whose serials and unit ids are masked (a test
  enforces it); a fixture marked synthetic never sets `verified`.
- **AC20 —** The repo has a CI workflow running the stdlib tests, a PR template
  with the contributor checklist, and CODEOWNERS covering `profiles/`,
  `lib/actions.json` and `lib/`.
- **AC21 —** On a fresh install with no Solaar entry for any profiled keyboard,
  the consent plan lists the supported keyboards (tested/untested) and states
  that setup applies whichever Solaar then records; declining still exits 0 with
  no change.
- **AC22 —** The widget IPC target and QML module name are `logitech-keys`.

## Glossary

| Term | Definition | Status | Source |
|------|------------|--------|--------|
| Profile | A JSON file describing one keyboard model's divertable keys and their action ids | `verified` | ADR 0005, accepted by owner ("make it multi-keyboard") |
| Profiled keyboard | A keyboard with a profile in `profiles/` | `unverified` | This spec |
| Action id | A short name (`lock`, `app-launcher`) that `lib/actions.json` maps to an argument list or plugin helper; the only way a profile triggers a command | `verified` | Architect review M3, applied on owner's "apply architect must-fix changes" |
| Applied state | `$XDG_STATE_HOME/logitech-keys/applied.json`: what setup diverted, per profile | `verified` | Architect review M6 |
| Absent | Key state: the key is in neither diversion line of the keyboard (wrong cid or not on this model) | `verified` | Architect review M5 |
| Tested | A profile with a `verified` block; otherwise untested | `verified` | Architect review M8 |
| Fixture | Recorded `solaar show` output for a keyboard, serials masked, used by tests | `unverified` | v0.3 tests |
| Known to Solaar | Has an entry in `~/.config/solaar/config.yaml` | `unverified` | Solaar behaviour |

## Ambiguity Log

Predictability check (step A2) for each `inferable` row: the plausible
alternative is stated and ruled out by the source named.

| # | Decision | Classification | Resolved By | Rationale / Answer |
|---|----------|---------------|-------------|-------------------|
| 1 | Multi-keyboard before submission vs POP-only plugin | `requires-stakeholder-input` | human (B) | "make it multi-keyboard before submitting". |
| 2 | Plugin id and repo name | `requires-stakeholder-input` | human (B) | `io.github.poornan.logitech-keys`, repo `omarchy-logitech-keys` (renamed later; ADR 0006). |
| 3 | Initial profiles | `requires-stakeholder-input` | human (B) | POP Icon Keys (tested on owner hardware) + MX Keys for Mac (**untested**, per #6). Corrected: the earlier "both tested" contradicted the Intent. |
| 4 | Per-user action overrides | `requires-stakeholder-input` | human (B) | "Not now". |
| 5 | Bar layout with two keyboards | `requires-stakeholder-input` | human (B) | One icon; popup lists each keyboard. |
| 6 | MX Keys for Mac key actions | `requires-stakeholder-input` | human (B) | Owner chose "Ship MX as untested" with actions following macOS. Mapping in AC3; region capture for Print Screen follows the owner's POP choice. |
| 6a | Mission Control key | `inferable` | inference | Omarchy has no window-overview command; leave the key undiverted rather than invent an action. |
| 6b | Eject key | `inferable` | inference | No Omarchy meaning; leave undiverted. |
| 6c | Rule clashes between profiles | `inferable` | architect (M4) | Replaces the earlier "no device condition needed today". Every rule always has a `Device` condition (`Or` over the profile's names); no `Model` condition exists in Solaar 1.1.20. One tested code path, and a later profile reusing a key name cannot fire on both keyboards. |
| 7 | Which keyboards setup applies | `inferable` | inference | Those in Solaar's `config.yaml`; a keyboard Solaar never saw has no entry to divert. On a fresh install the plan lists supported keyboards and setup applies what Solaar then records (AC21, M9). |
| 8 | Profile format JSON vs YAML | `inferable` | inference + architect (M9) | JSON: the Python stdlib reads it without PyYAML. Corrected: not "readable from bash (jq)"; `lib/profiles.py` is the single reader and `jq` on profiles is forbidden. |
| 9 | Keep the old repo URL working | `inferable` | inference | GitHub redirects renamed repos; README uses the new URL. |
| 10 | Mice (MX Master 4) | `inferable` | inference | Out of scope: the plugin is about keyboard special keys; the name says Keys. |
| 11 | Match keyboards by exact model id, then exact name (M1) | `inferable` | architect | Alternative "name substring" ruled out: Solaar's own selector matches substrings, so "MX Keys" hits three models. AC11. |
| 12 | Status parsing in Python with JSON output (M2) | `inferable` | architect | Alternative "bash substring test" ruled out: Solaar has 28 suffix-pair key names. AC12. |
| 13 | Profiles name action ids, not commands (M3) | `requires-stakeholder-input` | human (B) via "apply architect must-fix changes" | Prevents arbitrary commands in profile PRs and Lua injection; cost is a reviewed edit for a new action. Owner may still override. AC5, AC13. |
| 14 | `absent` key state (M5) | `inferable` | architect | Alternative "treat as not set up" ruled out: a wrong cid in an untested profile would keep the icon red forever. AC15. |
| 15 | Applied-state file, permanent slugs (M6) | `requires-stakeholder-input` | human (B) via the same instruction | Rule comments are not durable (Solaar's editor drops them), so a record is needed to reset removed ids. AC16. |
| 16 | Migration beyond marked blocks (M7) | `inferable` | architect | Alternative "edit only marked blocks" ruled out: Solaar-rewritten v0.3 rules would fire alongside the new ones and cancel the toggle. AC17. |
| 17 | Contributor gate: schema, `verified`, one fixture, CI, template, CODEOWNERS (M8) | `inferable` | architect | `tested` boolean replaced by presence of `verified`; three recorded fixtures cut to one plus derived variants. AC18–AC20. |
| 18 | Deprecation release for the v0.3 id | `inferable` | owner (answer to architect Q1) | v0.3 was never submitted to the marketplace; only the owner installed it from a local path. No deprecation release (ADR 0006). |
| 19 | Modifier conditions, gestures, per-OS-mode variants, release events | `inferable` | architect | Non-goals; reasons in ADR 0005. |
| 20 | Setup-time cid-name warning; keycap labels vs Fn-swap; release batching | `inferable` | architect ("later") | Not built now; README notes only (AC9). |
| 21 | Completeness sweep (entities: profile, applied state, rule block, Lua block, helper, fixture) | `inferable` | inference | Create/update/delete covered by setup reconcile (AC16) and uninstall (AC8, AC16); read by status (AC12); no auth, network or audit surface (local files, consent-gated). Error handling: damaged markers abort with no change (v0.3 constraint, kept). |

## Consistency Gate

- [x] Intent is unambiguous
- [x] Every behavior/goal maps to an acceptance criterion
- [x] Architecture constrains without over-engineering
- [x] Terminology consistent across artifacts
- [x] No contradictions between artifacts
- [x] Every gap/ambiguity finding is logged — inferable with rationale or resolved by human

**Verdict: PASS** (re-run 2026-11-19 after architect review M1–M9). Open
stakeholder questions: none (rows 13 and 15 were decided by the owner's
pre-approval and remain overridable).
