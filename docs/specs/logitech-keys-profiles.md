<!-- spec-version: 1 -->
# Spec: Logitech Keys — keyboard profiles

**Builds on:** [pop-icon-keys-plugin.md](pop-icon-keys-plugin.md) (v0.3.0),
[ADR 0005](../adr/0005-device-profiles-for-other-keyboards.md),
[ADR 0006](../adr/0006-rename-to-logitech-keys.md),
[ADR 0007](../adr/0007-battery-from-keyboard-notifications.md) and
[ADR 0008](../adr/0008-swappable-input-backend.md).
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
battery (ADR 0007), and chose a swappable Solaar/OpenLogi backend (D13).
**Backend pass, 2026-11-19:** the architect designed it
(`.dev-team-reports/architect-backend-design-2026-11-19.md`), ADR 0008 records
it, and this spec gained the **Backend seam** section and AC35–AC48 (the gate was
re-run). In v0.4.0 the Solaar backend is the tested reference and the OpenLogi
backend is **experimental and read-only**; the OpenLogi key-mapping writer is
deferred (ADR 0008, "Deferred slice S10"). Owner decisions D1–D14 are in the
Ambiguity Log. **Owner decisions pass, 2026-11-19:** the three open questions are
answered (D15 to D17, rows 37–39, `requires-stakeholder-input`, resolved by
human): a switch to Solaar disables the OpenLogi service on consent (built and
sandbox-tested); `keep_os_layout` is never changed; v0.4.0 ships OpenLogi
read-only and its battery reading is cited as prior art. The live OpenLogi 0.9.0
outputs and the finding that closing Solaar's window quits Solaar added AC49–AC52
and rows 47–50; the gate was re-run. **Solaar crash pass, 2026-11-19:** the owner
ran plain `solaar show` and it crashes on this machine partway (a `UnicodeDecodeError`
in `get_host_names` while printing the MX Master 4), so the Solaar backend queries
one device at a time, treats truncated output as `unknown`, and AC53–AC57 and rows
51–55 were added (ADR 0005, 0008); the gate was re-run.

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

8. **A swappable backend** (D13, ADR 0008): the program that owns the receiver is
   either Solaar or OpenLogi, one per machine, chosen by setup and recorded.
   Solaar is the tested reference. OpenLogi is **experimental and read-only** in
   this version: it detects keyboards, shows battery and backend status, and
   reports every key as unsupported by the backend; the plugin never writes
   OpenLogi's configuration. Switching backend is one consent-gated run that
   can be interrupted and resumed; a switch to Solaar also disables the OpenLogi
   service on consent (D15), so it does not retake the receiver at login.
9. **A visible, one-click answer when the backend is not running.** Closing
   Solaar's window quits Solaar on Omarchy (no tray), which silently kills all key
   routing, so the widget says so prominently and offers a Start Solaar action
   (AC49 to AC51).

10. **A status that survives a crashing `solaar show`.** On the owner's machine
    plain `solaar show` (all devices) crashes before it reaches the MX Keys for
    Mac, so status and restore query each profiled device by exact selector,
    verify every returned block's identity, and show a keyboard they could not
    read completely as **unknown**, never as disconnected or not set up (AC53 to
    AC57).

Everything the POP Icon Keys spec requires (AC1–AC18 there) keeps holding for
the POP Icon Keys profile under the Solaar backend.

Out of scope: mice and other non-keyboard devices, per-user action overrides,
non-Logitech keyboards, keyboards Solaar cannot divert keys on, modifier-key
conditions (Solaar's `Modifiers` condition returns False without a keymap on
Wayland), gestures and thumb buttons, per-OS-mode variants (a profile assumes
the one OS mode in its top-level `osMode`), key-release events. Also out of scope
(ADR 0008 non-goals): OpenLogi key mapping in this version, mixing backends per
keyboard, installing OpenLogi from setup, changing OpenLogi's `keep_os_layout`,
Flatpak OpenLogi, a backend picker in the widget settings, and a third backend
(LogiOps is considered and deferred).

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
  - `osMode` (**required**, top level): the keyboard's Solaar "Set OS" value, one
    of Solaar's multiplatform base names `Linux`, `MacOS`, `Windows`, `iOS`,
    `Android`, `WebOS`, `Chrome`, `WinEmb`, `Tizen` (checked against Solaar
    1.1.20 `settings_templates.py`). Both shipped keyboards use `"MacOS"`. It
    moved out of `verified` because the setup precondition (AC28) and the
    OpenLogi OS-layout warning apply to every profile, tested or not.
  - `verified` (optional): `{solaar, date, fnSwap}`, the Solaar reference
    verification. A profile is **tested** if and only if `verified` is present.
    There is no `tested` boolean. POP has it; the MX profile gets its `verified`
    only after the owner's live test.
  - `backends` (optional): only the key `openlogi` is allowed, with
    `{names?: [exact OpenLogi device names], verified?: {openlogi, date, keys:
    [cid, ...]}}`. `keys` must be a subset of the profile's cids; a `verified`
    block requires a recorded, non-synthetic
    `tests/fixtures/<slug>/openlogi-devices.json`. v0.4.0 ships no `backends`
    section. Adding a backend is maintainer code (registry plus schema enum),
    not a profile change.
  - `note` (optional): one line of plain text for contributors and the README
    (the MX profile: "device data recorded from real hardware; key actions
    untested"). It never sets or implies `tested`.
  - `battery` (optional): `{"feature": "UNIFIED BATTERY"}` (POP) or
    `{"feature": "BATTERY STATUS"}` (MX), the HID++ battery feature the
    keyboard reports. A closed set. Absent means no battery rules are generated
    for it and the battery source is `query`. This is the one name for the field
    in the spec, ADR 0007, ADR 0008 and the plan.
  - Unknown fields fail validation.
- **OS mode:** both keyboards stay in **MacOS OS mode** (Solaar "Set OS" =
  MacOS). Cmd = Super, Opt = Alt and the Lock chord `SUPER + CTRL + Q` are what
  that mode sends, so the profiles' key table and bindings assume it, and each
  profile records it as its top-level `osMode`. What happens in another OS mode
  is untested. Setup reads the setting without changing it (AC28). OpenLogi's
  `keep_os_layout` (default on) may move a keyboard out of MacOS mode when its
  agent connects; the plugin cannot read the layout through OpenLogi's API, so
  the consent plan warns and the README documents it (D16: never changed by the
  plugin, not in v0.4.0).
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
  model ids of exactly twelve uppercase hex digits, a required `osMode` from the
  closed list, a `verified` block of the right types (no `osMode` inside it), a
  `backends` section of the right shape (only `openlogi`, cids a subset, a
  `verified` block only with a non-synthetic fixture), `note` a single-line
  string, `battery` an object whose only field
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
- **Backend seam** (ADR 0008). One **active backend** per machine, recorded in
  `applied.json`. A backend is a pair: `lib/backends/<name>.py` (all data work:
  reading, parsing, identity, planning, file edits) and `lib/backends/<name>.sh`
  (process lifecycle only: installed, running, stop, start, restart-on-exit; bash
  never learns a file format). `lib/backends/__init__.py` holds the contract (key
  states, battery shape, `Plan` and `FileEdit`) and `REGISTRY = {"solaar",
  "openlogi"}`. `lib/backends/solaar.py` is a thin adapter over the existing
  identity, status, rules, diversion and battery modules (no logic moves);
  `lib/backends/solaar.sh` sources `lib/solaar-procs.sh`. `lib/edit.py` stays the
  only command line, with the verbs `plan|apply|remove|status|restore --backend
  <name>`; one executor in `lib/fileedit.py` writes every `FileEdit` (atomic,
  backup on change, dry-run diffs, marker checks, once for all backends). Python
  contract per backend: constants `NAME`, `LABEL`, `EXPERIMENTAL`,
  `LIVE_KEY_STATE`; `collect(run, paths, profiles)` (the **only** function that does I/O;
  `run(argv, timeout)` is injected and a fixed read-only argv allow-list applies:
  `solaar show "<selector>"` with one exact selector per profiled device (never
  `solaar show all`, which can crash on this machine), reading `config.yaml` and
  the battery state files; or
  `openlogi api status` and `openlogi api devices`); `probe(raw)`;
  `known(raw, profiles)`; `keyboards(raw, profiles, applied, now)`;
  `restore(sections)` (an argv list, never a file write); `plan_apply(...)` and
  `plan_remove(...)` returning a `Plan`. Bash contract per backend, namespaced:
  `<b>_installed`, `<b>_running`, `<b>_stop`, `<b>_start`,
  `<b>_restart_if_stopped`; all honour `--dry-run` and are called only after
  consent. Solaar: `LIVE_KEY_STATE` true, not experimental, the reference.
  OpenLogi: `EXPERIMENTAL` true, `LIVE_KEY_STATE` false; installed means
  `command -v openlogi` and `systemctl --user cat openlogi-agent.service`;
  running means `systemctl --user is-active --quiet openlogi-agent.service`, else
  `pgrep -u $UID -x openlogi-agent`; a Flatpak install counts as not installed.
- **OpenLogi backend in v0.4.0 (read-only).** `collect` runs `openlogi api
  status` and `openlogi api devices`. `probe` returns `{version, usable,
  problem}` with `problem` one of `agentUnavailable` (envelope `ok: false`,
  `agent_unavailable`), `versionMismatch` (`version_mismatch`, exit 1),
  `inventoryNotReady` (`inventory` `scanning` or `unavailable`), `unknownSchema`
  (`schema_version` other than 1, output that is not JSON, or CLI exit 2) or null;
  an unusable backend never crashes the helper. `known` matches an inventory
  device whose `name` **exactly** equals one of the profile's `names` or its
  `backends.openlogi.names` (the API exposes no model id; device `id` values are
  opaque and never parsed); two devices with the same matched name are marked
  ambiguous. `plan_apply` returns **no OpenLogi edits** (the OpenLogi config is
  never written, and the agent is never started or stopped by anything except a
  consented switch); every key's outcome is `unsupported` with reason
  `notImplemented` (after the deferred writer, `unverified` until
  `backends.openlogi.verified` lists the cid). `restore` returns `[]`.
  The Hyprland bindings block (POP Lock) still applies under either backend.
  **Read-side source (decision):** `openlogi list` works without the agent and
  prints `model_ids`, but it has no JSON form (live check, OpenLogi 0.9.0), so it
  is never parsed and `collect` uses `openlogi api` only; with the agent disabled
  and not running (the owner's state) the backend is `usable: false`,
  `agentUnavailable`. Identity by model id for OpenLogi becomes possible only if a
  JSON `list` or a model id in `api devices` appears (ADR 0008, unsettled list).
- **Identity:** a keyboard matches a profile by exact model id, then by exact
  name, in the one identity module (the Solaar backend; OpenLogi matches by exact
  name only). Never by substring: `solaar show/config "MX
  Keys"` would match "MX Keys for Mac", "MX Keys Mini" and "MX Keys S". Solaar
  stores the device name in `_modelId` when the model id is all zero, so a
  saved entry whose `_modelId` is not twelve hex digits is matched on that value
  as a name. Status queries each profiled device by exact selector
  (`solaar show "<name>"`; never `solaar show all`, AC53), parses every returned
  device block on its own and checks its `Model ID:` line (or its exact name when
  the model id is all zero); because Solaar still matches the selector by name
  substring, a block whose identity is not the profile's is treated as not this
  device. The selectors are the profile `names` and the names of saved
  `config.yaml` entries matched to the profile by model id. Restore addresses the keyboard by the
  matched block's exact printed name and skips a keyboard whose selector is
  ambiguous (that name is contained in another device block's name).
- **Status:** `lib/status.py` parses the two diversion lines per key exactly
  (key-name suffix pairs such as "Search" / "MultiPlatform Search" are handled
  by cid, not by substring) and prints JSON: a `schema` field (1), a `backend`
  block `{name, experimental, installed, running, usable, problem, liveKeyState,
  otherRunning, canStart}` and one section per connected profiled keyboard (`slug`, `name`,
  `tested`, `connected`, `identity`, `battery`, `keys` with `cid`, label, state
  and an optional `reason`, and `bindings`). `otherRunning` names the other
  backend when its daemon also runs; `canStart` is true only when the backend is
  installed, not running and can be started without consent: Solaar (hidden, AC50),
  never OpenLogi. Key state is `routed`, `dropped`, `notSetUp`,
  `absent`, `unsupportedByBackend` or `unknown`. **Truncated output** (AC54): a
  non-zero exit, a timeout or empty output from a `solaar show` call means the
  devices not yet printed were not read. A device block is complete when the next
  device header follows it or the call exited 0; the block being printed at the
  failure is incomplete. Complete blocks parse normally. A profiled keyboard known
  to Solaar (a saved `config.yaml` entry matches it) that was not read completely
  has every key `unknown` and its section a `readProblem` (`solaarCrashed`,
  `timeout` or `noOutput`; null otherwise); `unknown` is dimmed, does not count
  toward the warning, and is never restored. It is never reported as disconnected
  or not set up. A `no device found matching` reply is a clean "not present" (no
  section). For the Solaar backend it comes from the
  live line and the saved line: live diverted with saved diverted is `routed`;
  live diverted with saved regular or not listed is `notSetUp`; live regular
  with saved diverted is `dropped`; regular in both or one line only is
  `notSetUp`; not listed in either line is `absent`; with an older Solaar that
  prints no saved line the live line alone decides (diverted `routed`, regular
  `notSetUp`, not listed `absent`). A key whose saved line says diverted and
  whose live line does not list it is `dropped`. `absent` (a profile fact: the keyboard does not report the cid) shows dimmed with
  the words "Not found" and does not count toward needing setup;
  `unsupportedByBackend` (a backend fact: the active backend cannot route the cid;
  `reason` `notImplemented` or `unverified`) is dimmed too, reads "Not supported
  by <backend>" and does not count either; `dropped` alone does turn the icon
  warning. When `liveKeyState` is false (OpenLogi) `dropped` is never emitted,
  `routed` means "configured and the agent is running", and the widget offers no
  restore. Names are resolved through the injected key table
  by cid where one is available. `keyboards` are sorted by slug, `keys` are in
  profile order, `battery` is null or `{value, level, source, at}`
  (see **Battery**; `level` may be null; the report's freshness rule is one function,
  `report_is_fresh(report_at, connected_at)`, so that its pending owner decision,
  ADR 0007, is a one-line change). A keyboard that is paired but
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
  that file: `battery` is `{value, level, source, at}` with `source` `report`
  (from the file) or `query` (from `solaar show`); the OpenLogi backend adds
  `backend` (the daemon's cached figure from `openlogi api devices`, read at
  `at`; it is a fresh read, not necessarily a fresh device value, so the widget
  treats it like a query figure). **Persistence rule (D17):** only keyboard
  reports are persisted, and only `bin/logitech-keys-battery` writes the battery
  state directory; a query or backend figure is shown with its source and is
  never written there, so it cannot later be read back as a report. **Prior
  art:** OpenLogi (source, master) reads the same HID++ UnifiedBattery `0x1004`
  `getStatus` and status event 0 with Solaar's byte layout, re-reads on every poll,
  never restores a saved reading and handles the battery broadcast (ADR 0007);
  `openlogi list` showed the same stale 100 % for the POP, and there is no
  special battery command, so this design is the "reproduce it on ours" the owner
  asked for. It prefers a report newer than the
  keyboard's last connect, else the query value with source `query`. For a
  report `value` is the bucket's midpoint (`lo` + 5, so 10–19 shows "≈15%"); for
  the query it is the exact figure. The widget shows "≈15%" with the report's
  age for reports, and **"Full?"** (never a confident 100 %) when only the query
  says 100. Uninstall removes the plugin's state directory
  (`applied.json` and `battery/`). Whether Solaar reloads the rules without
  a restart is unverified; setup restarts it anyway, and live verification is
  left to the owner. The helper, the state file and the status JSON are
  backend-neutral; only the generated rules are Solaar-specific, and ADR 0008
  makes them an implementation detail of the Solaar backend (its adapter plans
  their writing and removal).
- **Diversion:** set per matching `config.yaml` device entry from that
  profile's control ids. Solaar keeps separate entries for Bluetooth and Bolt,
  so all entries matching `modelIds` or `names` are written.
- **Applied state:** `$XDG_STATE_HOME/logitech-keys/applied.json` (default
  `~/.local/state`; a relative `XDG_STATE_HOME` is ignored) records
  `{"schema": 1, "version": <plugin version>, "backend": "solaar"|"openlogi",
  "switching": null|{"from","to"}, "profiles": [{slug, ids, names, modelIds}],
  "artifacts": {"solaar": {"entries", "rulesBlock", "batteryRules",
  "autostartBlock"}, "hypr": {"bindingsBlock"}, "openlogi": {"entries",
  "enabledService", "disabledService"}}}` (v0.4.0 is unreleased, so this is schema 1 itself, with no
  migration; `entries` maps each slug to the matched names) where `names` and
  `modelIds` are the matched saved entries, so
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
  renamed or reused for another model. With no record, status shows what it
  detects (display only) and no backend is "in effect".
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
- **Backend selection and switching** (ADR 0008). Setup chooses the backend
  in this order: `--backend solaar|openlogi` given: that one (a difference from
  the recorded backend is a **switch**); no flag and a record: the recorded one
  (the widget's Re-apply never switches); only one installed: that one (OpenLogi
  is shown as "experimental, keys not mapped"); both installed and exactly one
  running: the running one; both installed and **both running: refuse**, exit 1,
  "two programs own the receiver; quit one", nothing changes; both installed and
  neither running: Solaar, the plan saying why; neither installed: Solaar,
  installed through `omarchy pkg add solaar` as today. Setup **never installs
  OpenLogi** (an AUR build and `sudo` udev rules; the README carries the install
  note, with no `curl | sh`). A switch is one consent and one plan, with a
  write-ahead record `switching: {from, to}`: (1) write the record with
  `switching` set; (2) stop the old daemon; (3) the old backend's `plan_remove`
  (Solaar: reset the recorded cids in `config.yaml` while stopped, remove the
  rules block with its key and battery rules and the Solaar autostart block);
  (4) the old backend's autostart that conflicts (D15, row 37): on a switch **to
  Solaar**, when the OpenLogi service is enabled, setup runs `systemctl --user
  disable --now openlogi-agent.service`; the plan lists it with the reason
  (OpenLogi would retake the receiver at next login) and it runs **only on y**
  (a disabled service is neither touched nor listed; `disabledService` is
  recorded as true); (5) start the new daemon (OpenLogi: `systemctl --user enable` the service
  first if it is not enabled and record `enabledService: true`, so uninstall
  disables only what the plugin enabled); (6) the new backend's
  `plan_apply`; (7) write the record with the new backend and `switching: null`.
  A failure before step 5 restarts the old daemon (the exit trap; an OpenLogi agent
  is restarted with `systemctl --user start` and stays disabled); a re-run sees
  `switching` and finishes the switch. Declining runs no `systemctl` call. **Uninstall** removes the artifacts of
  every backend recorded (a half-finished switch included), the Hyprland blocks,
  the state directory (battery files included), the helpers and the record; it
  restarts only a daemon it stopped, disables only a service it enabled, never
  uninstalls packages and never re-enables the other backend, including a service
  a switch disabled (it prints `systemctl --user enable --now
  openlogi-agent.service`). The consent plan adds: the backend, the reason it was chosen and an
  experimental badge; per keyboard each key as mapped, "unsupported by
  <backend>" with the reason, or absent; every daemon action (stop, start,
  enable, and `disable --now` on a switch to Solaar); for OpenLogi a line that its
  configuration is not changed; a warning about OpenLogi's OS-layout default; and
  the OS mode precondition warning (AC28).
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
  key; unreadable status; an unknown
  status schema says to reload the shell). "Re-apply setup (all keyboards)" opens
  a terminal running `setup` and shows a pending line until the next status
  read; "Restore (lost keys only)" restores per keyboard. Auto-restore works per
  keyboard and only when the backend's `liveKeyState` is true. An
  `unsupportedByBackend` key row reads "Not supported by <backend>" (dimmed, not
  a warning); an experimental backend carries a badge ("experimental, keys not
  mapped" for OpenLogi); when `otherRunning` is set the popup warns that both
  programs own the receiver. **A backend that is installed but not running is
  shown prominently** (closing Solaar's window quits Solaar on Omarchy, which
  kills all key routing): a banner leads the popup ("Solaar is not running, so
  these keys do nothing"), the icon warns, auto-restore does not run, and when
  `backend.canStart` is true the banner has a **Start Solaar** button that runs
  `bin/logitech-keys-start` (hidden start, no config change, no consent beyond the
  click; AC49 to AC51). A keyboard whose status could not be read completely
  (`unknown` keys) shows its rows as "Unknown" and one section line saying so,
  does not turn the icon warning, offers no restore for those rows and is never
  auto-restored (AC55). A backend that is not `usable` says why in words
  from its `problem`. Escape closes the popup, Enter or Space activates a focused button,
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
  block, and a line that `backends` is optional and needs a recorded OpenLogi
  fixture); `.github/CODEOWNERS` is `* @poornan` plus `profiles/`,
  `lib/actions.json` and `lib/` explicitly. Repository tests check structure
  (files, lists, patterns), not prose. The README order is: what it does,
  supported keyboards, install and uninstall, upgrading from v0.3, rollback (run
  v0.4's own uninstall, which removes both generations; there is no downgrade
  path), troubleshooting, then "Add your keyboard" (masking command, exact local
  test command, an example validator error, a worked diff of the MX profile and
  the "Test my keyboard" path). The README also has an **OpenLogi (experimental)**
  section (read-only in this version; the install note without `curl | sh`; the
  OS-layout warning) and states the MacOS OS mode requirement.
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
  Solaar's own rule code there. **Backend tests:** one suite,
  `tests/test_backend_contract.py`, runs over both backends (key states within
  the enum; `unsupportedByBackend` and `absent` never count toward the warning;
  exact identity, look-alike names do not match, ambiguous names are skipped;
  `restore` returns only allow-listed argv and writes nothing; `plan_apply`
  touches only declared paths and is idempotent; remove after apply gives
  byte-identical files; unusable envelopes become `problem` codes; nothing
  outside `collect` does I/O). OpenLogi inputs are
  `tests/fixtures/openlogi/*.json`, **synthetic and labelled** `synthetic:
  doc-derived USAGE.md @9ca7ef0` (devices ready, scanning, empty-ready, null name
  and battery; status `agent_unavailable` and `version_mismatch` with exit 1;
  `schema_version` 2; CLI exit 2); they never count as verification. The sandbox
  adds stubs on `PATH` for `openlogi` (a fixture per test) and `systemctl` (it
  refuses anything except `--user` `is-active`, `is-enabled`, `cat`, `start`,
  `stop`, `enable` and `disable` (with or without `--now`) on the one unit, keeps
  the unit's enabled state in a sandbox file and logs every call) beside
  the `pgrep`, `solaar`, `hyprctl` and `setsid` stubs; a guard fails the run if a
  stub is missing, so OpenLogi is never started or stopped for real. Sandbox
  cases: the selection matrix; a switch round trip Solaar to OpenLogi to Solaar
  with Solaar's files byte-identical apart from backups and the stub log showing
  the stop and start order; a switch to Solaar with the service enabled, where the
  log shows `disable --now` only after `y`, only on a switch to Solaar and never
  on decline; a switch interrupted at the agent start; uninstall mid-switch; the
  start helper (Solaar stub and `setsid` stub, nothing written). No schema-migration machinery (schema change =
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
  `date`, `fnSwap` (**superseded wording:** `osMode` is no longer in `verified`;
  it is a required top-level field, AC45). Each profile has one recorded fixture whose first
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
  "Linux mode". Every profile's top-level `osMode` is `"MacOS"` (AC45).
- **AC28 —** (OS mode precondition) Before the consent plan, `setup` reads each
  profiled keyboard's OS mode from Solaar read-only (`solaar show`'s "Set OS"
  line or the saved entry; no write, no restart). If the keyboard's mode differs
  from its profile's top-level `osMode`, the plan prints a warning naming the
  keyboard, the expected mode and where to change it (Solaar), and continues. It
  never changes the mode and does not block or change the exit code. If the mode
  cannot be read (older Solaar, no line, or the OpenLogi backend, whose API does
  not expose it), no warning is printed. (Since `osMode` is now required on every
  profile, the check covers untested profiles too; v0.3 wording limited it to a
  profile with `verified`.)
- **AC29 —** (MX recorded device data) The MX profile's `modelIds`, `names`,
  `osMode` (`MacOS`), `battery` feature (`BATTERY STATUS`) and keys equal the
  recorded hardware facts (model id `B36140920000`, name "MX Keys for Mac",
  codename "MX Keys Mac", Unifying receiver, cids 225 "Dashboard
  Launchpad/Action Center", 191 "Screen Capture/Print Screen", 111 "Screen Lock"
  and 10 "Calculator", all `persistently_divertable, divertable`), checked against the recorded fixture
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
  `{value, level, source, at}` per keyboard (`level` may be null; for the Solaar
  backend `source` is `report` or `query`, for OpenLogi `backend`, AC37). A report newer than the keyboard's last
  connect wins and has `source` `report` and `value` = bucket lower bound + 5;
  otherwise the `solaar show` figure is used with `source` `query`; no data
  gives null. Tests cover the owner's case (report 15, query 100) and a missing
  or damaged battery file. A query or backend figure is never persisted (AC52).
- **AC33 —** (battery widget) The popup shows "≈15%" with the report's age for a
  report, the exact figure for a query or backend figure below 100, and "Full?"
  (not "100%") when only the query or the backend says 100; "Battery unknown" for
  null. The widget logic test
  covers each case.
- **AC34 —** (battery cleanup) `uninstall` removes the plugin's state directory,
  including `battery/`, and nothing else; a dry run removes nothing; the plan
  lists it.

- **AC35 —** (backend seam and registry) Each backend is a pair
  `lib/backends/<name>.py` and `lib/backends/<name>.sh`; the registry holds
  exactly `solaar` and `openlogi`; every backend module provides the Python
  contract (`NAME`, `LABEL`, `EXPERIMENTAL`, `LIVE_KEY_STATE`, `collect`,
  `probe`, `known`, `keyboards`, `restore`, `plan_apply`, `plan_remove`) and every
  shell file the five lifecycle functions; only `collect` does I/O; `lib/edit.py`
  is the only command line and takes `--backend <name>`; one executor writes every
  `FileEdit`. A test fails when a backend lacks a member or the registry names an
  unknown backend. The Solaar adapter changes no Solaar behaviour: the POP spec
  AC1–AC18 (AC2) tests pass through it.
- **AC36 —** (selection and refusal) Setup selects the backend as the Architecture
  Specification states: `--backend` given wins (a change
  from the record is a switch); with no flag and a record, the recorded backend;
  only one installed, that one; both installed, exactly one running, the running
  one; both installed and neither running, Solaar with the reason in the plan;
  neither installed, Solaar through `omarchy pkg add solaar`; both installed and
  both running: exit 1 with "two programs own the receiver; quit one" and no
  file, process or record changed. The widget's Re-apply never switches. Setup
  never installs OpenLogi, and `--yes` installs nothing.
- **AC37 —** (OpenLogi read side) With OpenLogi installed and its agent running,
  status lists every connected inventory device whose `name` exactly equals a
  profile `names` entry or `backends.openlogi.names` entry (a look-alike name, a
  substring and a null name match nothing; two devices with one matched name are
  marked ambiguous); the section carries the profile's tested flag, the backend
  block (`experimental` true, `installed`, `running`, `usable`, `liveKeyState`
  false) and the daemon's battery as `{value, level, source: "backend", at}`
  (`level` null when absent). A Flatpak-only OpenLogi counts as not installed.
- **AC38 —** (OpenLogi unusable) An envelope with `ok: false`
  (`agent_unavailable`, `version_mismatch` with exit 1), inventory `scanning` or
  `unavailable`, an unknown `schema_version`, output that is not JSON and CLI exit
  2 each give `usable: false` with `problem` `agentUnavailable`,
  `versionMismatch`, `inventoryNotReady` or `unknownSchema`; the status helper
  still exits 0 with valid JSON and the widget says what to do. Nothing raises.
- **AC39 —** (`unsupportedByBackend`) Under OpenLogi every profile key has state
  `unsupportedByBackend` with `reason` `notImplemented`; the widget shows each as
  "Not supported by OpenLogi", dimmed, and neither it nor `absent` turns the icon
  warning. With `liveKeyState` false no key is `dropped`, `routed` means
  "configured and the agent is running", no restore button is offered, no
  auto-restore runs, and `restore` returns no argv. The widget still shows
  battery, connection and the experimental badge. The Hyprland bindings block
  (POP Lock) still applies.
- **AC40 —** (`otherRunning`) When the daemon of the backend that is not active
  also runs, `backend.otherRunning` names it and the popup warns "both own the
  receiver"; it does not change the icon's warning state by itself and does not
  stop anything.
- **AC41 —** (switching) A switch is one consent and one plan and runs the
  write-ahead steps (record with `switching`, stop the old daemon, old backend
  `plan_remove`, start the new daemon, new `plan_apply`, final record with
  `switching` null). Solaar to OpenLogi to Solaar leaves Solaar's files
  byte-identical to before apart from backups, and the `systemctl` stub log shows
  the stop and start order. A failure before the new daemon starts restarts the
  old one and leaves `switching` set; re-running setup finishes the switch.
  **D15 (owner: yes, with consent):** on a switch to Solaar, when the OpenLogi
  service is enabled, the plan lists `systemctl --user disable --now
  openlogi-agent.service` with the reason and setup runs it only on `y` (declining
  runs no `systemctl` call; a service already disabled is not touched or listed),
  after the old daemon is stopped and before Solaar starts; the sandbox `systemctl`
  stub log proves the order and the `y` gate; `disabledService` is recorded. A
  service the plugin enabled on a switch to OpenLogi is recorded
  (`enabledService`); uninstall disables only that and never re-enables.
- **AC42 —** (uninstall across backends) Uninstall removes the artifacts of every
  backend recorded, including a half-finished switch (`switching` set), the
  Hyprland blocks, the state directory and the record; it restarts only a daemon
  it stopped, never uninstalls a package, never re-enables the other backend or a
  service a switch disabled (it prints `systemctl --user enable --now
  openlogi-agent.service`), and leaves user content byte-identical.
- **AC43 —** (consent plan, backend) The plan names the backend, the reason, the
  experimental badge, per keyboard each key as mapped, unsupported by the backend
  (with the reason) or absent, every daemon action (stop, start, enable, and the
  `disable --now` of the OpenLogi service on a switch to Solaar, listed only when
  it will run), for OpenLogi the line that its configuration is not changed, and
  the OS-layout warning (D16: warned and documented, never changed); nothing is shown that setup will not
  do. Declining still exits 0 with no change.
- **AC44 —** (applied record, backend) The record has `backend`, `switching` and
  per-backend `artifacts` as the Architecture Specification states; setup, switch
  and uninstall write and read it with the same robustness rules as AC24; with no
  record, status shows what it detects and setup treats the machine as new; the
  record's `entries`, `rulesBlock`, `batteryRules` and `autostartBlock` let
  uninstall remove a Solaar install without the profile files.
- **AC45 —** (schema: `osMode`) Every profile has a top-level `osMode` from the
  closed list (Linux, MacOS, Windows, iOS, Android, WebOS, Chrome, WinEmb,
  Tizen), checked against Solaar's own table where importable; a missing or
  unknown value, or an `osMode` inside `verified`, fails validation. POP and MX are
  `MacOS`. This supersedes AC19's and AC27's earlier wording.
- **AC46 —** (schema: `backends`) `backends` is optional and strict: only the key
  `openlogi`; `names` a list of non-empty single-line strings; `verified` with
  `openlogi` (version), `date` and `keys` (a subset of the profile's cids); a
  `verified` block fails validation without a recorded, non-synthetic
  `tests/fixtures/<slug>/openlogi-devices.json`. The shipped profiles have no
  `backends` section, so no key is ever reported as verified for OpenLogi.
- **AC47 —** (backend contract tests) `tests/test_backend_contract.py` runs one
  suite over both backends with the properties listed under **Tests**; OpenLogi
  inputs are the labelled synthetic fixtures; the sandbox stubs `openlogi` and
  `systemctl` and fails the run if a stub is missing; the selection matrix, the
  switch round trip, a switch interrupted at the agent start and an uninstall
  mid-switch each run in the sandbox.
- **AC48 —** (OpenLogi never written) In v0.4.0 no code path writes
  `~/.config/openlogi/config.toml` or anything under `~/.config/systemd/user/`
  except the consented `enable` of the OpenLogi service during a switch to
  OpenLogi and the consented `disable --now` during a switch to Solaar (AC41); a
  test checksums the sandbox OpenLogi config and unit folder before and after
  setup, status, restore, switch and uninstall and fails on a difference other
  than those two (the unit's enabled state in the stub); the real
  `systemctl` is never called by any test (a missing stub fails the run). `CLAUDE.md` forbids stopping, starting,
  enabling or disabling the developer's OpenLogi agent in tests and reviews and allows only the
  read-only `openlogi api status` and `openlogi api devices`.
- **AC49 —** (backend not running, widget and status) When the active backend is
  installed but not running, `backend.running` is false and the widget shows it
  prominently: a banner leading the popup in words ("Solaar is not running, so
  these keys do nothing"), the icon in its warning state, and no automatic
  restore. `backend.canStart` is true exactly when the backend is installed, not
  running and Solaar (never OpenLogi); the banner then has a **Start Solaar**
  button, and without `canStart` it says how to start the program. A keyboard
  state that looks like `dropped` because Solaar is not running is not restored
  until it runs. Falsifiers: Solaar running (no banner, icon unchanged), Solaar
  not installed (the install copy, no button), OpenLogi not running (no button).
- **AC50 —** (Start Solaar action) `bin/logitech-keys-start` starts Solaar hidden
  (`setsid -f solaar --window=hide`; `-w, --window {show,hide,only}` verified
  from `solaar --help` on 1.1.20), changes no configuration file, writes nothing,
  asks nothing beyond the widget click, exits 0 when it started it, and exits
  non-zero with a one-line reason when Solaar is already running or not installed
  (no second instance). The widget shows a pending line until the next status
  read and the failure line if it exits non-zero. Tested in the sandbox with the
  `solaar` and `setsid` stubs; the files' checksums are unchanged.
- **AC51 —** (README: start Solaar hidden) The README says that closing Solaar's
  window quits Solaar on Omarchy (no tray) and stops all key routing, tells the
  user to start it hidden (`solaar --window=hide`, which `setup` also puts in
  autostart) and to leave it running, and mentions the widget's Start Solaar
  button. A structural test pins the flag text against `solaar --help` on the dev
  machine and the autostart line.
- **AC52 —** (battery persistence, D17) Only keyboard battery reports are
  persisted: `bin/logitech-keys-battery` is the only writer of
  `$XDG_STATE_HOME/logitech-keys/battery/`, and the status code, the restore
  helper and the OpenLogi backend never write there. A `solaar show` figure
  (source `query`) and an `openlogi api devices` figure (source `backend`) are
  shown with their source and never stored as the persisted truth, so a stale
  query cannot be read back later as a report. Tested by running status with query
  and backend figures and asserting the state directory is byte-identical, and by
  a source check that only the helper opens that path for writing. The ADR 0007
  note on OpenLogi's battery code is the stated prior art.
- **AC53 —** (per-device queries, never `solaar show all`) Status and restore for
  the Solaar backend run `solaar show "<selector>"` once per profiled device, with
  an exact selector taken from the profile's `names` and from saved `config.yaml`
  entries matched to it by model id, and run no other `solaar` command except
  restore's `solaar config`; `solaar show all` is never run. Each returned device
  block is parsed on its own and its `Model ID:` line (or exact name when the
  model id is all zero) is checked against the profile: a block that does not match
  is treated as not this device, and a selector that returns such a block is
  ambiguous (restore skips it, AC7). Tested through the Solaar adapter's `collect`
  allow-list (per-device selectors only), with a selector that returns the POP
  Icon Keys and a look-alike block. Falsifiers: one `solaar show all` call, a
  keyboard found by substring, an ambiguous selector restored.
- **AC54 —** (truncated or failed output is unknown) A non-zero exit, a timeout or
  empty output from a `solaar show` call never produces `disconnected`,
  `notSetUp` or a missing keyboard for a keyboard Solaar knows: every device block
  that parsed completely keeps its normal states; a profiled keyboard known to
  Solaar that was not read completely has every key `unknown` and a `readProblem`;
  `no device found matching` is "not present" (no section). `unknown` never counts
  toward the warning and is never restored. Falsifiers: a truncated output after a
  complete POP block (POP keeps its states, the unread keyboard is `unknown`), a
  timeout with a saved entry (`unknown`), a timeout with no saved entry (no
  section), a clean `no device found` (no section).
- **AC55 —** (widget: unknown) The widget shows the `unknown` rows as "Unknown" and
  the section line "Could not read this keyboard's status. Choose Refresh." (copy
  table, once, in `Panel.qml`); `unknown` does not turn the icon warning and has no
  restore action, while a `dropped` key of another keyboard still does.
  Falsifier: an `unknown` keyboard beside a routed one leaves the icon unchanged.
- **AC56 —** (synthetic truncation fixture) A test builds, in memory, a truncated
  `solaar show` output from the masked recorded POP fixture followed by a second
  device header and the `UnicodeDecodeError` traceback text (labelled
  `synthetic: built from the recorded POP fixture and the owner's 2026-11-19
  traceback`, never counted as verification), and checks AC53 and AC54 on it: the
  POP block is complete and `routed`, the remainder is unknown. It also covers the
  per-device selectors of the Solaar adapter's `collect` allow-list and a selector
  returning two blocks (ambiguity).
- **AC57 —** (README known issue) The README has a known-issues note that Solaar
  1.1.20's host-name decoding bug can make plain `solaar show` (all devices) crash,
  that the plugin works around it by querying each keyboard on its own, and that
  the user sees "Unknown" for a keyboard that could not be read. A structural test
  checks the keywords.

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
| Backend | The program that owns the receiver and routes keys: Solaar (tested reference) or OpenLogi (experimental, read-only in v0.4.0). One active per machine, recorded in `applied.json`; each is a `lib/backends/<name>.py` and `.sh` pair | `verified` | Owner D13; ADR 0008 |
| unsupportedByBackend | Key state: the active backend cannot route this cid (reason `notImplemented` or `unverified`). A backend fact, unlike `absent` (a profile fact: the keyboard does not report the cid); both are dimmed and neither counts toward the warning | `verified` | ADR 0008 (architect design) |
| liveKeyState | Backend flag: whether it can read which keys are diverted right now. Solaar true; OpenLogi false, so `dropped` is never emitted and no restore is offered | `unverified` | ADR 0008; OpenLogi open item 7 (no documented API shows key state) |
| otherRunning | Status field: the other backend's daemon also runs, so both own the receiver; the widget warns | `verified` | ADR 0008; `INSTALL-linux.md` (only one application owns a receiver) |
| Switching record | `switching: {from, to}` in `applied.json`, written before a backend switch begins and cleared at the end, so an interrupted switch can be finished or uninstalled | `verified` | ADR 0008 |
| osMode | Required top-level profile field: the keyboard's Solaar "Set OS" value the profile assumes (both shipped: `MacOS`); no longer inside `verified` | `verified` | ADR 0008, ADR 0005 amended; owner D10 |
| canStart | Status field `backend.canStart`: the backend is installed, not running and can be started with no consent (Solaar, hidden; never OpenLogi). It enables the widget's Start Solaar button | `verified` | Owner finding 2026-11-19 (closing Solaar's window quits it); ADR 0008 |
| Start Solaar action | `bin/logitech-keys-start`: starts Solaar hidden (`setsid -f solaar --window=hide`), no config change, refuses when it already runs | `verified` | `solaar --help` (`-w, --window {show,hide,only}`); AC50 |
| unknown | Key state: the backend could not read this keyboard completely (truncated, crashed or timed-out `solaar show`), so its keys are neither routed nor lost. A read fact, unlike `absent` (profile fact) and `unsupportedByBackend` (backend fact); dimmed, never warns, never restored. The section carries `readProblem` | `verified` | Owner finding 2026-11-19 (`solaar show` crash); ADR 0008 |
| Selector | The argument of `solaar show "<selector>"`: an exact profile name or saved-entry name. Solaar matches it by name substring, so the returned blocks are checked by model id | `verified` | Solaar 1.1.20 behaviour (ADR 0005 Context); ADR 0008 |
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
| 35 | Swappable backend now: Solaar or OpenLogi (D13) | `requires-stakeholder-input` | human (B) | Owner: "use swappble dependency either solaar or openlogi"; chose "Swappable backend now" over Solaar-now/backend-later, trial-first or shrink. **Resolved by the owner; specified in [ADR 0008](../adr/0008-swappable-input-backend.md) (accepted) and AC35–AC48.** Solaar is the tested reference and OpenLogi ships read-only and experimental in v0.4.0 (rows 40–41). |
| 36 | Install OpenLogi (D14) | `requires-stakeholder-input` | human (B) | Owner: "install OpenLogi ... Check OpenLogi for installation details". Install note only: AUR `openlogi`, then `sudo udevadm control --reload && sudo udevadm trigger` and `systemctl --user enable --now openlogi-agent.service`; the owner runs the sudo steps; the plugin never installs it and the `curl | sh` installer is not used (marketplace baseline). |
| 37 | D15 (was Q1): during an explicit switch to Solaar, may setup run `systemctl --user disable openlogi-agent.service` (a service the owner's OpenLogi install enabled, not this plugin)? | `requires-stakeholder-input` | human (owner, 2026-11-19) | Owner answered **yes, with consent** (summarised in the instruction that recorded it; the quote is not stored verbatim). Built: on a switch to Solaar, when the service is enabled, the plan lists `systemctl --user disable --now openlogi-agent.service` with the reason and setup runs it only on `y`; sandbox-tested with a logging `systemctl` stub, never on the real machine. Uninstall still never re-enables it (it prints the command); `disabledService` is recorded. Replaces the earlier default of "print the command only". AC41, AC42, AC43, AC48; ADR 0008. |
| 38 | D17 (was Q2): ship v0.4.0 with OpenLogi read-only, or wait for the writer (S10)? How should battery be read? | `requires-stakeholder-input` | human (owner, 2026-11-19) | Owner: "or we can refer how they read battery and reproduce on ours"; asked whether that meant reproducing OpenLogi's battery method through ADR 0007, OpenLogi read-only and experimental in v0.4.0 and fully supported in v0.5.0, the owner confirmed: "yes, that's what I meant". Verified in OpenLogi's source (master): it uses the same HID++ UnifiedBattery `0x1004` `getStatus` and status event 0 with Solaar's byte layout (`crates/openlogi-hidpp/src/feature/unified_battery.rs`), re-reads on every inventory poll (`.../inventory/cache.rs`), never restores a saved reading (`persist.rs`) and handles the battery broadcast (`replay_tests.rs`, `battery_broadcast_refresh`); there is no special command and `openlogi list` showed the same stale 100 % for the POP. So "reproduce on ours" is ADR 0007 as designed (capture the broadcast with Solaar rules, the query as fallback, never persist a query as truth: AC52). The release decision is thereby answered: **ship v0.4.0 with OpenLogi read-only and experimental; the writer (S10) is v0.5.0.** AC32, AC37 to AC39, AC48, AC52; ADR 0007, ADR 0008. |
| 39 | D16 (was Q3): under OpenLogi, should setup write `keep_os_layout=off` through `openlogi api os-layout --set off --save`? | `requires-stakeholder-input` | human (owner, 2026-11-19) | Owner answered **not in v0.4.0: warn and document only**; the plugin never changes `keep_os_layout`. The plan warns and the README documents that it may move a keyboard out of MacOS mode on connect and break `SUPER + CTRL + Q`. AC43, AC27. |
| 40 | LogiOps (`logid`) as a third backend | `requires-stakeholder-input` | orchestrator on the feasibility report; owner may override | Considered and **deferred**, not built: no battery feature, `Keypress`-only actions (it would need a keysym plus a Hyprland bind indirection), a root-owned `/etc/logid.cfg` and a system service that need `sudo` (conflicts with the consent and no-sudo baseline), last release 2024-09. The backend interface stays open to a future keypress-indirection backend. `.dev-team-reports/logiops-feasibility-2026-11-19.md`; ADR 0008, Considered options. |
| 41 | OpenLogi is experimental and read-only in v0.4.0; the writer (chord bridge) is designed but not built | `inferable` | architect, on the OpenLogi docs | Alternative "write OpenLogi's TOML now" ruled out by the 13 open items in ADR 0008 (Linux keyboard diversion unconfirmed; `control:0x<cid>` spelling; which device entry is which keyboard; reload and lock behaviour), and by strict TOML where one bad field stops the whole file loading. AC37–AC39, AC48. |
| 42 | One active backend per machine; both running is refused | `inferable` | `INSTALL-linux.md` | "Only one application can own a receiver"; the alternative of a backend per keyboard is ruled out because both keyboards here share one receiver type and two daemons would fight over HID++ access. AC36. |
| 43 | The profile field stays named `battery {feature}` (the architect's note offered `batteryFeature`) | `inferable` | orchestrator | One name already in the spec, ADR 0007 and the plan; renaming adds churn for nothing. Reconciled across spec, ADR 0005, 0007, 0008 and the plan. |
| 44 | `osMode` is a required top-level field and AC28 now checks every profile | `inferable` | architect (defect fix) | The POP profile said `Linux` (wrong, D10) and the field sat inside `verified`, so an untested profile had none. Alternative "keep it in `verified`" ruled out: the precondition warning and the OpenLogi OS-layout warning apply to untested profiles too. AC28, AC45. |
| 45 | OpenLogi identity is the exact device name only (profile `names` or `backends.openlogi.names`); a CLI exit 2 or non-JSON output is `unknownSchema` | `inferable` | OpenLogi `USAGE.md` | The API exposes no model id and its device ids are opaque, so exact name is the only identity; the problem set is closed (`agentUnavailable`, `versionMismatch`, `inventoryNotReady`, `unknownSchema`) and output the plugin cannot read is the closest. AC37, AC38. |
| 46 | `liveKeyState` false means no `dropped`, no restore, `routed` = configured and the agent running | `inferable` | OpenLogi docs | No documented OpenLogi API shows key or diversion state (open item 7); claiming "Active" from a live read would be false. AC39. |
| 47 | OpenLogi's read side uses `openlogi api` only, not `openlogi list` | `inferable` | live check, OpenLogi 0.9.0 | `openlogi list` works without the agent and prints `model_ids`, but has no JSON form (`openlogi list --help` shows only `-h`); parsing its text table is ruled out (fragile, no schema). Consequence: it needs the agent, so on the owner's machine (agent disabled, not running, never started by this work) the backend is `usable: false`, `agentUnavailable`. Identity by model id is possible only if a JSON `list` or a model id in `api devices` appears; flagged in ADR 0008. |
| 48 | OpenLogi's key writer (S10) is gated on a recorded proof that its Linux build honours keyboard dedicated-key bindings | `inferable` | OpenLogi README, `openlogi api --help` | The README says "Keyboard F-key remapping" is not available on Linux and `openlogi api` has no binding subcommand (bindings live only in the TOML). Alternative "build the TOML writer now" ruled out (row 41). If the check fails, keys stay `unsupportedByBackend` and S10 is dropped. |
| 49 | Widget shows a stopped backend prominently and offers Start Solaar (new AC49 to AC51) | `requires-stakeholder-input` | human (owner finding, 2026-11-19) | The owner found that closing Solaar's window quits Solaar on Omarchy (no tray), which kills all key routing, and asked the widget to detect `running=false` prominently and offer a Start Solaar action that starts it hidden, with no config change and no consent beyond the click, and the README to say to start it hidden. Inferable details: the flag is `solaar --window=hide` (verified from `solaar --help`, already used by setup's autostart); a status field `backend.canStart` (true for Solaar only) keeps the button decision out of the widget; OpenLogi never gets a start button (the plugin starts or stops its agent only in a consented switch); auto-restore does not run while the backend is stopped. |
| 50 | Real OpenLogi fixtures use `openlogi fixture` where it fits; the synthetic ones stay labelled until then | `inferable` | live check, `openlogi fixture --help` | OpenLogi ships privacy-safe fixture tooling (`record case|profile`, `verify`, `contribute`). Whether its format can feed the contract tests directly is unsettled (ADR 0008); until the owner records real ones the synthetic fixtures stay labelled `synthetic: doc-derived USAGE.md @9ca7ef0` and never count as verification. |
| 51 | Solaar's plain `solaar show` crashes on the owner's machine, so status and restore must not rely on it (AC53) | `requires-stakeholder-input` | human (owner finding, 2026-11-19) | The owner ran plain `solaar show` and it raised `UnicodeDecodeError: 'utf-8' codec can't decode byte 0xe2 in position 13` in `logitech_receiver/hidpp20.py:2078` `get_host_names` (called from `solaar/cli/show.py:326`) while printing the MX Master 4, after the POP Icon Keys and before the Unifying receiver; exit non-zero. `solaar show "POP Icon Keys"` and `solaar show "MX Keys for Mac"` work. Alternatives: keep one `solaar show all` and tolerate partial output (rejected: the MX Keys for Mac, the very device we need, is printed after the crash); patch or wrap Solaar (rejected: not ours, and not on other machines). Decision: one `solaar show "<selector>"` per profiled device. ADR 0005, 0008. |
| 52 | Per-device selectors still match by substring, so each block's identity is verified and a mismatching block is not-this-device and makes the selector ambiguous (AC53) | `inferable` | ADR 0005 identity rule, Solaar behaviour | The plausible alternative "trust the exact selector" is ruled out by the recorded Solaar fact (a selector matches any device whose name contains it). The selector list is the profile `names` plus saved entries matched by model id, so a keyboard whose printed name differs is still queried. |
| 53 | Truncated, crashed or timed-out output is `unknown`, a sixth key state with a `readProblem`; not disconnected, not set up, not counted toward the warning, never restored (AC54, AC55) | `requires-stakeholder-input` | human (owner finding, same instruction, 2026-11-19) | Decided in the instruction that recorded the owner's finding (summarised, the quote is not stored verbatim): devices not yet printed are "unknown", never disconnected or not set up, and the widget shows it. Inferable details: only a keyboard known to Solaar (a saved entry) is shown as unknown (the plugin cannot claim a keyboard exists on a failed call); a device block is complete when the next header follows it or the call exited 0; `no device found matching` is a clean "not present". The alternative of reusing `absent` is ruled out: it means "the keyboard does not report this cid", a profile fact. |
| 54 | Synthetic truncation fixture built in the test from the recorded POP fixture and the traceback text (AC56) | `inferable` | test-fixtures rule: one recorded fixture per profile | Recording the crash is not possible per profile (it depends on another device on the machine); the synthetic fixture is labelled and never counts as verification (AC19). |
| 55 | README known-issues note on the Solaar host-name bug (AC57) | `inferable` | owner instruction | Documentation of a known upstream bug and the workaround; no behaviour choice. |

## Consistency Gate

- [x] Intent is unambiguous
- [x] Every behavior/goal maps to an acceptance criterion
- [x] Architecture constrains without over-engineering
- [x] Terminology consistent across artifacts
- [x] No contradictions between artifacts
- [x] Every gap/ambiguity finding is logged — inferable with rationale or resolved by human

**Verdict: PASS** (re-run 2026-11-19 after architect review M1–M9, after the
plan-review personas: criteria AC24–AC26 added, AC9, AC13–AC21 extended, rows
22–28 logged; after the owner's corrections of the same day: MacOS OS mode
(D10), MX hardware data (D4 update), battery (D11), criteria AC27–AC34 added,
AC3 and AC19 extended, rows 29–36 logged, owner decisions D1–D14 all recorded;
and after the backend pass: ADR 0008 accepted, the Backend seam section, the
status contract, selection and switching, criteria AC35–AC48 added, AC19, AC27,
AC28, AC29, AC32 and AC33 amended, glossary and rows 35–46 updated, the profile
field name `battery` reconciled across spec, ADR 0005, 0007, 0008 and the plan;
and after the owner-decisions pass of 2026-11-19: D15 to D17 resolved in rows
37–39 (the former "defaults in force" replaced), the live OpenLogi 0.9.0 outputs,
the Solaar-quits-with-its-window finding, criteria AC49–AC52 added, AC32, AC41,
AC42, AC43 and AC48 amended, `canStart` and `disabledService` added, rows 47–50;
and after the Solaar crash pass of 2026-11-19: criteria AC53–AC57 added, Intent
item 10, the Architecture text for `collect`, identity, status and the widget
amended, glossary terms `unknown` and Selector, rows 51–55, and the D17
confirmation quote added to row 38).
Mechanical checks of this pass: every AC id AC1–AC57 appears once as a heading
entry; each of AC35–AC57 is referenced by a plan criterion; every ADR and row
cited exists. **Open stakeholder questions: none.** Q1 to Q3 are D15 to D17
(rows 37–39); rows 13, 15, 22–28 and 40–50 remain overridable by the owner. Live
checks only the owner can run are listed in ADR 0008.
