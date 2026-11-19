<!-- spec-version: 1 -->
# Spec: Logitech Keys — keyboard profiles

**Builds on:** [pop-icon-keys-plugin.md](pop-icon-keys-plugin.md) (v0.3.0),
[ADR 0005](../adr/0005-device-profiles-for-other-keyboards.md) and
[ADR 0006](../adr/0006-rename-to-logitech-keys.md).
**Status:** gate passed 2026-11-19, re-run after the architect review
(`.dev-team-reports/architect-review-2026-11-19.md`, must-fix M1–M9 applied;
the owner pre-approved it with "apply architect must-fix changes") and again
after the five plan-review personas (design, acceptance, strategic,
parallelization, UX; all returned needs-revision, all items resolved or decided,
see `plans/logitech-keys-profiles.md`).
The MX Keys for Mac profile ships **untested** (owner's choice). Update
2026-11-19: the owner connected the keyboard and Solaar read it read-only, so its
**device data is now verified from hardware** (a recorded fixture); its **key
presses are still untested** until the owner runs the live test after the build.
Same day, the owner corrected the OS mode (MacOS, not Linux), required accurate
battery (ADR 0007), and chose a swappable Solaar/OpenLogi backend (ADR 0008,
being written by the architect pass; not specified here). Owner decisions D1–D14
are in the Ambiguity Log.

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
   MX Keys for Mac, **untested** (B: "POP + MX Keys for Mac"; then "Ship MX as
   untested"). The MX profile's device data (model id, names, key names and
   control ids) is **verified from hardware**: the owner connected the keyboard
   on 2026-11-19 and a read-only `solaar show` was recorded. Pressing its keys
   has not been tested, so it has no `verified` block and says so in a `note`.
   Its main purpose is to **demonstrate the extension structure**: a second
   keyboard added as data only, the worked example contributors copy (B:
   "adding MX to show extendability (source code strcture)"). Both keyboards run
   in **MacOS OS mode** (D10); the plugin relies on it and never changes it.
3. Adding a keyboard is a **pull request that adds one profile file** plus one
   recorded `solaar show` fixture and a README row. A profile names *actions*
   from a reviewed action table, never commands.
4. **No per-user override file** in this version (B: "Not now").
5. **One bar icon for all connected profiled keyboards**; the popup lists each
   keyboard (B: "One icon, all keyboards").
6. The repo gates contributions: strict profile validation, CI, a PR checklist
   and code owners, so a profile PR cannot run arbitrary commands or break
   another keyboard (architect review M3, M8).
7. **An accurate battery figure.** A fresh Solaar query right after connect
   returned "100% charged" for a keyboard whose own later report said 15%, so
   the widget uses the keyboard's own battery notifications, not the stale
   direct query (D11; ADR 0007).

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
    boolean. `osMode` is the keyboard's Solaar "Set OS" value; both shipped
    keyboards use `"MacOS"` (POP: verified; the MX profile gets its `verified`
    only after the owner's live test).
  - `note` (optional): one line of plain text for contributors and the README
    (the MX profile: "device data recorded from real hardware; key actions
    untested"). It never sets or implies `tested`.
  - `battery` (optional): `{"feature": "UNIFIED BATTERY"}` (POP) or
    `{"feature": "BATTERY STATUS"}` (MX), the HID++ battery feature the
    keyboard reports. Absent means no battery rules are generated for it.
  - Unknown fields fail validation.
- **OS mode:** both keyboards stay in **MacOS OS mode** (Solaar "Set OS" =
  MacOS). Cmd = Super, Opt = Alt and the Lock chord `SUPER + CTRL + Q` are what
  that mode sends, so the profiles' key table and bindings assume it. What
  happens in another OS mode is untested. Setup reads the setting without
  changing it (AC28).
- **Action table** `lib/actions.json` maps an action id to an argument list or
  a plugin helper (`show-desktop`, `app-launcher`, `dictation`, `emoji-picker`,
  `region-screenshot`, `lock`, `calculator`). It is the single place commands
  live. Adding an action is a reviewed edit to this file, owned by the
  maintainer; it is the one allowed non-profile change in a keyboard PR.
- **One reader** `lib/profiles.py` is pure data: it loads and strictly validates
  profiles and the action table (the profile folder is a function argument, not
  an environment variable). Validation: schema field equal to 1, required
  non-empty fields, cid paired with name, unique cids and names, labels, known
  action ids, a chord matching a fixed full-match regex (one to four distinct
  modifiers of SUPER, CTRL, ALT, SHIFT plus one key `A-Z`, `0-9` or `F1-F12`),
  model ids of exactly twelve uppercase hex digits, a `verified` block of the
  right types, `note` a single-line string, `battery` an object whose only field
  `feature` is `UNIFIED BATTERY` or `BATTERY STATUS`, unique slugs equal to the file name, no model id shared by two
  profiles, no profile name that is a substring of another profile's name, the
  same chord never bound to two actions, and name/cid pairs matching Solaar's
  key table. The action table is validated too: unique ids, each entry exactly
  one of an argument list of non-empty control-free strings or a shipped helper
  name. The key table is **injected**: Solaar's `CONTROL` when importable, else
  a snapshot pinned in the repository (so CI stays stdlib-only); with neither,
  the cross-check is skipped with a printed note. A frozen list of shipped
  slugs is checked so a released slug cannot be dropped. `setup`, `uninstall`,
  the status and restore helpers and tests get keyboard data only through the
  reader. Bash never parses profiles (no `jq` on profiles); `Panel.qml` has no
  keyboard knowledge.
- **Modules:** `lib/solaarcfg.py` is the one identity module (config entry
  parsing with line spans; `match_device(profiles, model_id, name)`; the
  ambiguity test); `lib/fileedit.py` reads, backs up and atomically writes files
  and finds marked blocks (the mark is a parameter); `lib/diversion.py` edits
  `config.yaml` diversion; `lib/rules.py` generates and classifies rules and Lua
  and holds **all** escaping (YAML flow, Lua string, shell argument, one function
  each); `lib/applied.py` is the applied record and the one place the plugin
  version is read (from `manifest.json`); `lib/legacy.py` is the single frozen v0.3
  table (marker, helper name, the five argument lists, the v0.3 key set);
  `lib/plan.py` computes the consent plan as data; `lib/edit.py` is the command
  line only.
- **Identity:** a keyboard matches a profile by exact model id, then by exact
  name, in the one identity module. Never by substring: `solaar show/config "MX
  Keys"` would match "MX Keys for Mac", "MX Keys Mini" and "MX Keys S". Solaar
  stores the device name in `_modelId` when the model id is all zero, so a
  saved entry whose `_modelId` is not twelve hex digits is matched on that value
  as a name. Status reads `solaar show all`, splits it per device block and
  checks each block's `Model ID:` line. Restore addresses the keyboard by the
  matched block's exact printed name and skips a keyboard whose selector is
  ambiguous (that name is contained in another device block's name).
- **Status:** `lib/status.py` parses the two diversion lines per key exactly
  (key-name suffix pairs such as "Search" / "MultiPlatform Search" are handled
  by cid, not by substring) and prints JSON: a `schema` field and one section
  per connected profiled keyboard (name, battery, `tested`, keys with label and
  state). Key state is `routed`, `dropped`, `notSetUp` or `absent`, from the
  live line and the saved line: live diverted with saved diverted is `routed`;
  live diverted with saved regular or not listed is `notSetUp`; live regular
  with saved diverted is `dropped`; regular in both or one line only is
  `notSetUp`; not listed in either line is `absent`; with an older Solaar that
  prints no saved line the live line alone decides (diverted `routed`, regular
  `notSetUp`, not listed `absent`). A key whose saved line says diverted and
  whose live line does not list it is `dropped`. `absent` shows dimmed with the
  words "Not found" and does not count toward needing setup; `dropped` alone
  does turn the icon warning. Names are resolved through the injected key table
  by cid where one is available. `keyboards` are sorted by slug, `keys` are in
  profile order, `battery` is null or `{value, source, at}` (see **Battery**). A keyboard that is paired but
  offline is not listed. The bash helper `bin/logitech-keys-status` only runs it
  and always exits 0 with valid JSON.
- **Rules:** one marked block in `rules.yaml` with the rules of every applied
  profile. **Every rule has a `Device` condition** (an `Or` over the profile's
  `names`); no `Model` condition (Solaar 1.1.20 has none). Rules therefore never
  fire for another keyboard, even with the same key name. `classify()`
  recognises the new rule shape and the v0.3 shapes.
- **Battery** (ADR 0007). Solaar's own HID++ query can return a stale value
  (verified 2026-11-19: `solaar show` printed "battery unified 100% charged,
  level 8" right after connect, while the keyboard's own later UNIFIED_BATTERY
  notification said 15%; the GUI showed 15% before a restart and 100% after; the
  batteries are 10 months old). Solaar has no API (no D-Bus or IPC), and its
  `/tmp/Solaar_*` log only receives INFO and WARNING, so battery DEBUG lines
  never reach it: the plugin does **not** parse logs and does not add `-d`.
  Instead (checked in Solaar 1.1.20 source) Solaar passes every feature
  notification, including battery, to the rule engine, so rules can see them.
  For each applied profile that has a `battery` field, the managed rules block
  holds one rule per 10 % bucket (0–9, 10–19, … 90–100): `Device` (an `Or` over
  the profile's names, as every rule) + `Feature` (the profile's battery
  feature) + `Report: 0` + `TestBytes [0, 1, lo, hi]` (byte 0 is the discharge
  percentage in both `UNIFIED BATTERY` and `BATTERY STATUS`; the test is
  inclusive and reads a signed byte, fine for 0–100) → `Execute`
  `[<plugin helper>, <slug>, <lo>]`. The helper `bin/logitech-keys-battery
  <slug> <percent>` accepts only a slug that a profile defines and an integer
  0–100, and writes `$XDG_STATE_HOME/logitech-keys/battery/<slug>` (the value
  and the epoch time) atomically; it writes nothing under `/tmp`. Status reads
  that file: `battery` is `{value, source, at}` with `source` `report` (from the
  file) or `query` (from `solaar show`). It prefers a report newer than the
  keyboard's last connect, else the query value with source `query`. For a
  report `value` is the bucket's midpoint (`lo` + 5, so 10–19 shows "≈15%"); for
  the query it is the exact figure. The widget shows "≈15%" with the report's
  age for reports, and **"Full?"** (never a confident 100 %) when only the query
  says 100. Uninstall removes the plugin's state directory
  (`applied.json` and `battery/`). Whether Solaar reloads the rules without
  a restart is unverified; setup restarts it anyway, and live verification is
  left to the owner. The helper, the state file and the status JSON are
  backend-neutral; only the generated rules are Solaar-specific, and ADR 0008
  (pending) makes them an implementation detail of the Solaar backend.
- **Diversion:** set per matching `config.yaml` device entry from that
  profile's control ids. Solaar keeps separate entries for Bluetooth and Bolt,
  so all entries matching `modelIds` or `names` are written.
- **Applied state:** `$XDG_STATE_HOME/logitech-keys/applied.json` (default
  `~/.local/state`; a relative `XDG_STATE_HOME` is ignored) records
  `{"schema": 1, "version": <plugin version>, "profiles": [{slug, ids, names,
  modelIds}]}` where `names` and `modelIds` are the matched saved entries, so
  `uninstall` works without the profile file and still resets a profile whose
  slug no longer ships. `setup` writes the **union of the old and new ids before
  the diversion** (resetting a never-diverted id is harmless) and rewrites the
  record with the final ids afterwards, so a stop between the writes still lets
  `uninstall` reset everything. `setup` reconciles against it: ids no longer in
  the profile are reset and their rules removed. `uninstall` resets from it and
  deletes it. The record is written atomically with no `.bak` (it is state, not
  user content); a damaged record or one with a newer `schema` stops setup and
  uninstall before any change; a dry run writes nothing. Rule comments are not
  used for state (Solaar's editor drops them). **Slugs are permanent:** never
  renamed or reused for another model.
- **Setup scope:** applies profiles for keyboards present in Solaar's
  `config.yaml`, in **two phases**: (1) resolve the profile set (stop Solaar,
  read the saved entries; if none is profiled, start Solaar once so it records
  the connected keyboards, wait, stop it and read again), (2) write the record,
  the rules, the helper and the Lua for exactly that set, then divert, restart
  Solaar and finalise the record, idempotently, with rules before diversion. The
  consent plan lists the profiles it applies; on a fresh install, when Solaar
  has no entry for any profiled keyboard yet, the plan lists all **supported
  keyboards** (with tested/untested) and says setup applies whichever profiles
  Solaar then records (plan, consent, start Solaar, apply). If Solaar still
  records no supported keyboard, setup exits 2 and writes no record, rules or
  binding. **Consent plan:** computed by `lib/plan.py` as data (bash only prints
  it and runs the steps): a heading; one block per keyboard (tested or
  "Untested - may not match your keys", its keys and actions); file changes;
  the Solaar stop and restart notice; migration items (old blocks, each legacy
  unmarked rule by key, the old helper); "your own rules left unchanged" with a
  note when a listed rule will still fire on a handled keyboard; the exit-2 text
  (supported keyboards and next steps). There is one y/N for all keyboards (no
  per-keyboard option). An uninstall with no record resets the v0.3 key set,
  as v0.3 did, and the plan lists the exact key names.
- **Hyprland bindings:** one marked Lua block, command resolved from the action
  table; chords are validated by regex, no contributor string reaches Lua.
- **Widget:** one bar icon; the popup has a section per connected profiled
  keyboard, ordered by slug, with one header line (name, "Untested - may not
  match your keys" badge, battery or "Battery unknown", one-line status) and one
  row per key stating its state in **words** as well as a glyph: Active, Lost
  (Lost, restoring...), Not set up, Not found; dimming is only extra. The JSON
  carries states; the words live once in the widget, and user text says
  "keyboard", not "profile" (one exception: the all-absent message). A keyboard
  whose keys are all, or more than half, absent shows a plain-text message that
  its profile may not match the model or Solaar version, with the issue address.
  It warns if any keyboard has keys in `dropped` or `notSetUp`, and the tooltip
  lists the affected keyboards. Failures say what to do (restore failed names the
  key; Solaar not running says how to start it; unreadable status; an unknown
  status schema says to reload the shell). "Re-apply setup (all keyboards)" opens
  a terminal running `setup` and shows a pending line until the next status
  read; "Restore (lost keys only)" restores per keyboard. Auto-restore works per
  keyboard. Escape closes the popup, Enter or Space activates a focused button,
  and single-key shortcuts are named in the tooltips. IPC target and QML module
  name are `logitech-keys`.
- **Rename and migration:** new id, display name, repo URL, marker text
  `logitech-keys`, helper names (`logitech-keys-*`). `setup` migrates v0.3
  state: marked `pop-icon-keys` blocks, **and** legacy rules that Solaar's rule
  editor rewrote without markers (a command ending in `pop-icon-keys-show-desktop`
  or the v0.3 argument lists), counting each as ours, not "other". It removes the
  old helper and old `pop-icon-keys` Lua blocks. `uninstall` removes old and new.
  `setup` warns when `io.github.poornan.pop-icon-keys` is still installed (its
  Re-apply would write old blocks; two widgets).
- **Contributor gate:** `.github/workflows/` runs the stdlib tests on push and
  PR (`permissions: contents: read`, every action pinned by full commit SHA);
  `.github/pull_request_template.md` carries the checklist (recorded fixture,
  masked serials, cids checked against `solaar show`, only existing action ids,
  README row, the slug appended to the permanent list, truthful `verified`
  block); `.github/CODEOWNERS` is `* @poornan` plus `profiles/`,
  `lib/actions.json` and `lib/` explicitly. Repository tests check structure
  (files, lists, patterns), not prose. The README order is: what it does,
  supported keyboards, install and uninstall, upgrading from v0.3, rollback (run
  v0.4's own uninstall, which removes both generations; there is no downgrade
  path), troubleshooting, then "Add your keyboard" (masking command, exact local
  test command, an example validator error, a worked diff of the MX profile and
  the "Test my keyboard" path).
- **Tests:** profile schema test (every profile); **one recorded** `solaar show`
  fixture per profile (`tests/fixtures/<slug>/`; the MX fixture is the owner's
  masked 2026-11-19 recording, `tests/fixtures/mx-keys-mac/show.txt`, replacing
  the earlier synthetic MX fixtures), first line carries the Solaar
  version, serials and unit ids masked, enforced by a test); routed, dropped and
  not-set-up variants are derived from the profile in the test (the derived POP
  variants are checked equal to the v0.3 recordings until those are deleted, and
  every variant is read back by the status code as the intended states).
  Masking covers serials, unit ids, MAC addresses and hid paths. A synthetic
  fixture is labelled synthetic and never counts as verification. A sandbox
  setup run covers POP Icon Keys, the two-keyboard case (with a synthetic
  profile that shares a key name, since the shipped profiles share none) and
  migration; the other per-profile checks are fast pure-Python. Solaar-dependent
  checks run against real Solaar on the dev machine with zero skips
  (`LK_REQUIRE_SOLAAR=1`), and generated rules are loaded and evaluated with
  Solaar's own rule code there. No schema-migration machinery (schema change =
  one commit, profiles live in the repo).
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
  profile has no `verified` block (its key presses are untested) but a `note`
  saying the device data was recorded from real hardware; the plan, README and
  widget mark this keyboard **untested**. The owner adds `verified` after the
  live test.
- **AC3a —** (plan id AC23) Profiles use Solaar's own key names and control ids. POP Icon Keys:
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
- **AC9 —** README has an "Add your keyboard" section, after the sections in the
  fixed order (what it does, supported keyboards, install and uninstall,
  upgrading from v0.3, rollback, troubleshooting): how to read key names and ids
  with `solaar show`, the profile format, the action table, a copy-paste masking
  command, the exact local test command, an example validator error, a worked
  diff of the MX profile, the "Test my keyboard" path, and what the PR must
  contain. It also notes: keycap labels depend on Fn-swap, Solaar may name a cid
  differently across versions, releases batch profile PRs (new profile = minor,
  fix = patch), one confirmation covers all keyboards, and rollback is v0.4's own
  uninstall.
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
  field, a chord outside the regex, or any unknown field fail validation, and the
  action table is validated too. Rules and Lua blocks are generated from
  `lib/actions.json`; profile and action text reaches YAML, Lua and shell
  commands only through the rules module's escaping.
- **AC14 —** Every generated rule has a `Device` condition over the profile's
  names and no `Model` condition, and fires only for its own keyboard (checked
  with Solaar's own evaluator). `classify()` treats new and v0.3 rule shapes as
  ours, and any other rule on a profiled key as "other", flagging overlap only
  where it can fire on a keyboard the plugin handles.
- **AC15 —** A key in neither diversion line has state `absent`: dimmed in the
  popup with the words "Not found" and not counted toward the icon's needs-setup
  warning. The state for every live-by-saved combination, including an older
  Solaar with no saved line, follows the table in the Architecture Specification.
- **AC16 —** `setup` writes `applied.json`; when a later profile drops a control
  id, `setup` resets that id and removes its rule (nothing happens, and no error,
  if its keyboard has no saved entry). `uninstall` resets every id in
  `applied.json` and deletes it. Both leave other keys and user rules untouched.
  (Record robustness: AC24.)
- **AC17 —** Legacy migration: v0.3 rules rewritten by Solaar's editor without
  markers (including the `pop-icon-keys-show-desktop` path at any home folder and
  the five v0.3 argument lists) are replaced, not duplicated, and each removed
  rule is listed in the plan; a rule with one argument changed is left alone; the
  old helper and old Lua blocks are removed; `setup` warns if
  `io.github.poornan.pop-icon-keys` is still installed; running `setup` again
  after a migration changes nothing and makes no backup.
- **AC18 —** The profile reader enforces the schema in the Architecture
  Specification, including the Solaar key-table cross-check (the installed
  Solaar's `CONTROL` when importable, else the pinned snapshot, so CI stays
  stdlib-only; skipped with a note only when neither is supplied). Every shipped
  profile passes; a test mutates a valid profile into each failure case (wrong or
  missing schema, duplicate cid or name, empty lists, a shared or malformed model
  id, malformed `verified`, invalid JSON, a non-object file, and the action-table
  cases). On the development machine the Solaar-dependent checks run with zero
  skips (`LK_REQUIRE_SOLAAR=1`).
- **AC19 —** A profile is tested only if `verified` is present with `solaar`,
  `date`, `osMode`, `fnSwap`. Each profile has one recorded fixture whose first
  line holds the Solaar version (equal to `verified.solaar`) and whose serials,
  unit ids, MAC addresses and hid paths are masked (a test enforces it); a
  fixture marked synthetic never sets `verified`. A recorded fixture alone does
  not make a profile tested: `verified` records key presses the owner tested.
- **AC20 —** The repo has a CI workflow running the stdlib tests (actions pinned
  by full commit SHA, `permissions: contents: read`), a PR template with the
  contributor checklist, and CODEOWNERS (`* @poornan` plus `profiles/`,
  `lib/actions.json` and `lib/` explicitly), with structural repository tests.
- **AC21 —** On a fresh install with no Solaar entry for any profiled keyboard,
  the consent plan lists the supported keyboards (tested/untested) and states
  that setup applies whichever Solaar then records; declining still exits 0 with
  no change. Setup is two-phase: the first read knows none, the second (after
  Solaar records the connected keyboards) knows them and the profiles are applied
  idempotently. If Solaar records no supported keyboard (nothing, or only a
  mouse), setup exits 2, names the supported keyboards and the next steps, and
  writes no record.
- **AC22 —** The widget IPC target and QML module name are `logitech-keys`.

The plan numbers AC3a as AC23 (its tooling wants whole numbers); the criteria
below are therefore AC24 onward.

- **AC24 —** The applied record is robust: `setup` writes the union of old and
  new ids before the diversion and the final ids afterwards; the record carries
  the matched saved entry names and model ids, so `uninstall` works without the
  profile file and for a slug that no longer ships; it is written atomically
  with no `.bak`; a missing record reads as empty; a damaged record or one with
  a newer `schema` stops setup and uninstall before any change, naming the file;
  `XDG_STATE_HOME` unset or relative uses `~/.local/state`; a dry run writes
  nothing; a setup stopped between the two writes leaves a record `uninstall`
  can use.
- **AC25 —** Widget states are text first: every key row says Active, Lost, Not
  set up or Not found (with a glyph); an untested keyboard says "Untested - may
  not match your keys"; a keyboard with all (or more than half) of its keys
  absent says its profile may not match the model or Solaar version and where to
  report it, in plain text; warnings, a failed restore (naming the key), Solaar
  not installed or not running, unreadable status and an unknown status schema
  each say what to do; Re-apply setup states that it covers all keyboards and
  shows a pending line; Escape closes the popup, Enter or Space activates a
  focused button and the single-key shortcuts are named in the tooltips.
- **AC26 —** The consent plan is complete and ordered: a block per keyboard
  (tested or "Untested - may not match your keys", keys, actions), the file
  changes, the Solaar stop and restart notice, migration items (old blocks, each
  legacy unmarked rule by key, the old helper), "your own rules left unchanged"
  with a note when one will still fire, and the exit-2 text; an uninstall with no
  record lists the exact v0.3 key names it will reset.

- **AC27 —** (OS mode, README) The README states that the keyboards must be in
  **MacOS OS mode** (Solaar "Set OS" = MacOS), that the plugin does not change
  it, and that behaviour in another OS mode is untested. It contains no claim of
  "Linux mode". The POP profile's `verified.osMode` is `"MacOS"`.
- **AC28 —** (OS mode precondition) Before the consent plan, `setup` reads each
  profiled keyboard's OS mode from Solaar read-only (`solaar show`'s "Set OS"
  line or the saved entry; no write, no restart). If a profile has `verified`
  and the keyboard's mode differs, the plan prints a warning naming the keyboard,
  the expected mode and where to change it (Solaar), and continues. It never
  changes the mode and does not block or change the exit code. If the mode cannot
  be read (older Solaar, no line), no warning is printed. A profile without
  `verified` is not checked.
- **AC29 —** (MX recorded device data) The MX profile's `modelIds`, `names` and
  keys equal the recorded hardware facts (model id `B36140920000`, name "MX Keys
  for Mac", cids 225, 191, 111, 10 with their Solaar names, all
  `persistently_divertable, divertable`), checked against the recorded fixture
  and Solaar's key table. The synthetic MX fixtures are gone; the recorded one is
  masked (a test enforces it). The profile `note` field is optional, validated
  as a single-line string, and shown in the README's supported-keyboards table.
  A test pins that the MX profile has no `verified` block.
- **AC30 —** (battery rules) For each applied profile with a `battery` field,
  setup generates in the managed rules block ten bucket rules (`Device` +
  `Feature` + `Report: 0` + `TestBytes [0,1,lo,hi]` → `Execute`
  `[<helper>, <slug>, <lo>]`), loadable and evaluated by Solaar's own rule code
  on the dev machine: a UNIFIED_BATTERY notification with byte 0 = 15 fires only
  the 10–19 rule, for only that keyboard; 0 and 100 hit the first and last
  buckets; a BATTERY STATUS notification works for the MX profile. A profile with
  no `battery` field gets none. `classify()` counts these rules as ours;
  uninstall removes them; running setup again changes nothing.
- **AC31 —** (battery helper) `bin/logitech-keys-battery <slug> <percent>`
  rejects an unknown slug, a non-integer, a value outside 0–100 and a wrong
  argument count (exit non-zero, no file); otherwise it writes
  `$XDG_STATE_HOME/logitech-keys/battery/<slug>` atomically (value and epoch
  time), using `~/.local/state` when `XDG_STATE_HOME` is unset or relative. It
  never writes under `/tmp`. The slug list comes from the profile reader.
- **AC32 —** (battery status) The status JSON `battery` is null or
  `{value, source, at}` per keyboard. A report newer than the keyboard's last
  connect wins and has `source` `report` and `value` = bucket lower bound + 5;
  otherwise the `solaar show` figure is used with `source` `query`; no data
  gives null. Tests cover the owner's case (report 15, query 100) and a missing
  or damaged battery file.
- **AC33 —** (battery widget) The popup shows "≈15%" with the report's age for a
  report, the exact figure for a query below 100, and "Full?" (not "100%") when
  only the query says 100; "Battery unknown" for null. The widget logic test
  covers each case.
- **AC34 —** (battery cleanup) `uninstall` removes the plugin's state directory,
  including `battery/`, and nothing else; a dry run removes nothing; the plan
  lists it.

## Glossary

| Term | Definition | Status | Source |
|------|------------|--------|--------|
| Profile | A JSON file describing one keyboard model's divertable keys and their action ids | `verified` | ADR 0005, accepted by owner ("make it multi-keyboard") |
| Profiled keyboard | A keyboard with a profile in `profiles/` | `unverified` | This spec |
| Action id | A short name (`lock`, `app-launcher`) that `lib/actions.json` maps to an argument list or plugin helper; the only way a profile triggers a command | `verified` | Architect review M3, applied on owner's "apply architect must-fix changes" |
| Applied state | `$XDG_STATE_HOME/logitech-keys/applied.json`: what setup diverted, per profile | `verified` | Architect review M6 |
| Absent | Key state: the key is in neither diversion line of the keyboard (wrong cid or not on this model) | `verified` | Architect review M5 |
| Tested | A profile with a `verified` block (key presses tested on owner hardware); otherwise untested. A recorded fixture or `note` does not change this | `verified` | Architect review M8 |
| Fixture | Recorded `solaar show` output for a keyboard, serials masked, used by tests | `unverified` | v0.3 tests |
| Known to Solaar | Has an entry in `~/.config/solaar/config.yaml` | `unverified` | Solaar behaviour |
| Key table snapshot | `tests/solaar_control_1.1.20.json`: Solaar 1.1.20's name-to-cid table, committed so CI can run the cross-check without Solaar | `verified` | Plan review (acceptance A3) |
| MacOS OS mode | Keyboard setting (Solaar "Set OS" = MacOS) in which Cmd sends Super, Opt sends Alt and Lock sends `Super+Ctrl+Q`; both shipped keyboards run in it. "Linux OS mode" was an earlier error | `verified` | Owner, 2026-11-19: `solaar show` "Set OS: MacOS", `config.yaml` `multiplatform: 1` (D10) |
| Device data (of a profile) | A profile's model id, names, key names and cids, as read from hardware. The MX profile's are verified from the recorded fixture; its key presses are not | `verified` | Owner-supplied recording, 2026-11-19 |
| Battery report | A battery notification sent by the keyboard itself, seen by a Solaar rule and stored by `bin/logitech-keys-battery`; preferred over the direct query, which can be stale | `verified` | Owner, 2026-11-19 (15% vs 100%); ADR 0007 |
| Identity module | `lib/solaarcfg.py`: the one place that matches a Solaar device or saved entry to a profile | `verified` | Plan review (design D1, parallelization P2) |

## Ambiguity Log

Predictability check (step A2) for each `inferable` row: the plausible
alternative is stated and ruled out by the source named.

| # | Decision | Classification | Resolved By | Rationale / Answer |
|---|----------|---------------|-------------|-------------------|
| 1 | Multi-keyboard before submission vs POP-only plugin (D1) | `requires-stakeholder-input` | human (B) | "make it multi-keyboard before submitting". ADR 0005, accepted. |
| 2 | Plugin id and repo name (D2) | `requires-stakeholder-input` | human (B) | Owner chose "logitech-keys (Recommended)": id `io.github.poornan.logitech-keys`, display "Logitech Keys", repo `poornan/omarchy-logitech-keys` (renamed later; ADR 0006). |
| 3 | Initial profiles and the MX profile's test status (D3, D4) | `requires-stakeholder-input` | human (B) | Owner chose "POP + MX Keys for Mac", then "Ship MX as untested" and "adding MX to show extendability (source code strcture)". The MX profile's role is to demonstrate the extension structure. **Update 2026-11-19 (row 30):** the owner connected the MX Keys for Mac; its device data is now verified from hardware (recorded fixture), its key presses stay untested until the owner's live test, so `verified` stays absent. Tested definition unchanged. |
| 4 | Per-user action overrides (D5) | `requires-stakeholder-input` | human (B) | Owner chose "Not now (Recommended)". |
| 5 | Bar layout with two keyboards (D6) | `requires-stakeholder-input` | human (B) | Owner chose "One icon, all keyboards (Recommended)": one icon; popup lists each keyboard. |
| 6 | MX Keys for Mac key actions | `requires-stakeholder-input` | human (B) | Owner chose "Ship MX as untested" (D4) with actions following macOS. Mapping in AC3; region capture for Print Screen follows the owner's POP choice (D12, row 33). |
| 6a | Mission Control key | `inferable` | inference | Omarchy has no window-overview command; leave the key undiverted rather than invent an action. |
| 6b | Eject key | `inferable` | inference | No Omarchy meaning; leave undiverted. |
| 6c | Rule clashes between profiles | `inferable` | architect (M4) | Replaces the earlier "no device condition needed today". Every rule always has a `Device` condition (`Or` over the profile's names); no `Model` condition exists in Solaar 1.1.20. One tested code path, and a later profile reusing a key name cannot fire on both keyboards. |
| 7 | Which keyboards setup applies | `inferable` | inference | Those in Solaar's `config.yaml`; a keyboard Solaar never saw has no entry to divert. On a fresh install the plan lists supported keyboards and setup applies what Solaar then records (AC21, M9). |
| 8 | Profile format JSON vs YAML | `inferable` | inference + architect (M9) | JSON: the Python stdlib reads it without PyYAML. Corrected: not "readable from bash (jq)"; `lib/profiles.py` is the single reader and `jq` on profiles is forbidden. |
| 9 | Keep the old repo URL working | `inferable` | inference | GitHub redirects renamed repos; README uses the new URL. |
| 10 | Mice (MX Master 4) | `inferable` | inference | Out of scope: the plugin is about keyboard special keys; the name says Keys. |
| 11 | Match keyboards by exact model id, then exact name (M1) | `inferable` | architect | Alternative "name substring" ruled out: Solaar's own selector matches substrings, so "MX Keys" hits three models. AC11. |
| 12 | Status parsing in Python with JSON output (M2) | `inferable` | architect | Alternative "bash substring test" ruled out: Solaar has 28 suffix-pair key names. AC12. |
| 13 | Profiles name action ids, not commands (M3); all architect must-fix items M1–M9 applied (D7) | `requires-stakeholder-input` | human (B): "apply architect must-fix changes when it finishes" | Prevents arbitrary commands in profile PRs and Lua injection; cost is a reviewed edit for a new action. Owner may still override. AC5, AC13. |
| 14 | `absent` key state (M5) | `inferable` | architect | Alternative "treat as not set up" ruled out: a wrong cid in an untested profile would keep the icon red forever. AC15. |
| 15 | Applied-state file, permanent slugs (M6) | `requires-stakeholder-input` | human (B) via the same instruction | Rule comments are not durable (Solaar's editor drops them), so a record is needed to reset removed ids. AC16. |
| 16 | Migration beyond marked blocks (M7) | `inferable` | architect | Alternative "edit only marked blocks" ruled out: Solaar-rewritten v0.3 rules would fire alongside the new ones and cancel the toggle. AC17. |
| 17 | Contributor gate: schema, `verified`, one fixture, CI, template, CODEOWNERS (M8) | `inferable` | architect | `tested` boolean replaced by presence of `verified`; three recorded fixtures cut to one plus derived variants. AC18–AC20. |
| 18 | Deprecation release for the v0.3 id | `inferable` | owner (answer to architect Q1) | v0.3 was never submitted to the marketplace; only the owner installed it from a local path. No deprecation release (ADR 0006). |
| 19 | Modifier conditions, gestures, per-OS-mode variants, release events | `inferable` | architect | Non-goals; reasons in ADR 0005. |
| 20 | Setup-time cid-name warning; keycap labels vs Fn-swap; release batching | `inferable` | architect ("later") | Not built now; README notes only (AC9). |
| 21 | Completeness sweep (entities: profile, applied state, rule block, Lua block, helper, fixture) | `inferable` | inference | Create/update/delete covered by setup reconcile (AC16) and uninstall (AC8, AC16); read by status (AC12); no auth, network or audit surface (local files, consent-gated). Error handling: damaged markers abort with no change (v0.3 constraint, kept). |
| 22 | Restore skips an ambiguous selector rather than working around it; addresses the keyboard by the matched block's exact name | `inferable` | plan review (design) | AC7 kept as written: a wrong device is worse than a skipped restore. Owner may override. |
| 23 | Uninstall with no applied record resets the v0.3 key set and the plan lists the exact key names | `inferable` | plan review (UX) | Matches v0.3; the alternative leaves keys diverted with no rule. Owner may override. AC26. |
| 24 | Legacy unmarked two-line v0.3 rules are deleted, each listed, backups made | `inferable` | plan review (UX) | They cannot be told from v0.3's own; leaving them cancels the toggle. Owner may override. AC17, AC26. |
| 25 | One y/N for all keyboards; untested keyboards marked loudly; no per-keyboard option | `inferable` | plan review (UX) | A per-keyboard flag is more surface than two keyboards need; README says so. Owner may override. AC26. |
| 26 | CI stays stdlib-only via a pinned Solaar key-table snapshot; the dev machine runs real Solaar with zero skips | `inferable` | plan review (acceptance) | CI cannot install Solaar. AC18. |
| 27 | Applied record written as the union before the diversion and finalised after, no `.bak` | `inferable` | plan review (design) | A stop between the writes must still let uninstall reset everything. AC24. |
| 28 | User words for states live in the widget; the JSON carries states only; no collapsing; no scaffold helper; CODEOWNERS `* @poornan` plus paths | `inferable` | plan review (UX, strategic) | Smallest change that satisfies the review. Owner may override. AC25, AC20, AC9. |
| 29 | Branch and PR workflow; release = `/pr`, auto-merge, then tag `main` (D8) | `requires-stakeholder-input` | human (B) | Process row, no AC. Owner: "we can create a branch from what we have"; auto-merge "automatic". Owner-side prerequisites, not done: allow auto-merge in the repo settings; protect `main` with the CI check as required; owner approval at PR time. Recorded in `.claude/CLAUDE.md`. |
| 30 | MX Keys for Mac device data verified from hardware (D4 update) | `requires-stakeholder-input` | human (owner, 2026-11-19) | The owner connected the keyboard and a read-only `solaar show` was recorded: model id `B36140920000`, name "MX Keys for Mac", codename "MX Keys Mac", transport ids btleid `B361` and wpid `4092`, via the Unifying receiver, Set OS MacOS, Swap Fx function True, battery feature `BATTERY STATUS {1000}`. Mapped keys are all `persistently_divertable, divertable`: 225 "Dashboard Launchpad/Action Center", 191 "Screen Capture/Print Screen", 111 "Screen Lock", 10 "Calculator"; 224 Mission Control/Task View and 13 Eject stay undiverted. Names verified against Solaar's `special_keys.CONTROL`. The owner supplied the masked recording; the build copies it to `tests/fixtures/mx-keys-mac/show.txt` (the unmasked `raw.txt` is never copied). Key presses are untested, so `verified` stays absent; the profile carries a `note` field instead. AC3, AC29. |
| 31 | Route all dev work through `dev-team:orchestrator` (D9) | `requires-stakeholder-input` | human (B) | Process row, no AC. Owner: "always invoke through orchestrator". Recorded in `.claude/CLAUDE.md`. |
| 32 | Keyboards run in MacOS OS mode, not Linux (D10) | `requires-stakeholder-input` | human (owner, 2026-11-19) | Owner screenshot; verified `Set OS: MacOS` on both keyboards. Every "Linux OS mode" claim in specs, ADR 0002 and `CLAUDE.md` was wrong and is fixed; POP `verified.osMode` is "MacOS". The README requirement (users set Set OS = MacOS in Solaar; behaviour otherwise untested) is AC27. A read-only setup check that warns and never changes the mode is AC28 (inferable: the plugin never changes a hardware setting the user owns; blocking is ruled out because other modes are untested, not known bad). |
| 33 | F8 / Screen Capture = region screenshot, overriding the macOS column (D12) | `requires-stakeholder-input` | human (B) | Owner chose "Region (keep current)" (POP spec row 1). The MX Screen Capture/Print Screen key follows (AC3). |
| 34 | Accurate battery: use the keyboard's own battery notifications (D11) | `requires-stakeholder-input` | human (B, 2026-11-19) | Owner chose battery from Solaar's own reports ("Read Solaar's own log"). The log gets no DEBUG lines (`solaar/gtk.py` sets INFO/WARNING for the temp log), so it is implemented with Solaar rules on battery notifications. ADR 0007, AC30–AC34. Inferable details (alternative ruled out by the Solaar source in ADR 0007): 10 % buckets, helper writes a state file, "Full?" instead of a confident 100 %. Known limit: a report older than the keyboard's last connect is ignored, so after a reconnect the figure falls back to the query until the next report; the widget shows the report's age so staleness is visible. |
| 35 | Swappable backend now: Solaar or OpenLogi (D13) | `requires-stakeholder-input` | human (B) | Owner: "use swappble dependency either solaar or openlogi"; chose "Swappable backend now" over Solaar-now/backend-later, trial-first or shrink. **To be specified in ADR 0008, to be written by the architect pass; backend ACs are added by a later spec pass.** Until then this spec describes the Solaar behaviour only; the battery helper, state file and status JSON are kept backend-neutral. LogiOps was assessed and deferred (`.dev-team-reports/logiops-feasibility-2026-11-19.md`). |
| 36 | Install OpenLogi (D14) | `requires-stakeholder-input` | human (B) | Owner: "install OpenLogi ... Check OpenLogi for installation details". Install note only: AUR `openlogi`, then `sudo udevadm control --reload && sudo udevadm trigger` and `systemctl --user enable --now openlogi-agent.service`; the owner runs the sudo steps; the plugin never installs it and the `curl | sh` installer is not used (marketplace baseline). |

## Consistency Gate

- [x] Intent is unambiguous
- [x] Every behavior/goal maps to an acceptance criterion
- [x] Architecture constrains without over-engineering
- [x] Terminology consistent across artifacts
- [x] No contradictions between artifacts
- [x] Every gap/ambiguity finding is logged — inferable with rationale or resolved by human

**Verdict: PASS** (re-run 2026-11-19 after architect review M1–M9, after the
plan-review personas: criteria AC24–AC26 added, AC9, AC13–AC21 extended, rows
22–28 logged; and after the owner's corrections of the same day: MacOS OS mode
(D10), MX hardware data (D4 update), battery (D11), criteria AC27–AC34 added,
AC3 and AC19 extended, rows 29–36 logged, owner decisions D1–D14 all recorded).
Open stakeholder questions: none for this spec (rows 13, 15 and 22–28 remain
overridable by the owner). Pending, outside this spec: ADR 0008 and its backend
criteria (row 35).
