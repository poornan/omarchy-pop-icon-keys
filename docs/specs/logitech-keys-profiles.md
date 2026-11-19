<!-- spec-version: 1 -->
# Spec: Logitech Keys — keyboard presets (slim v0.4.0)

**Builds on:** [pop-icon-keys-plugin.md](pop-icon-keys-plugin.md) (v0.3.0),
[ADR 0005](../adr/0005-device-profiles-for-other-keyboards.md),
[ADR 0006](../adr/0006-rename-to-logitech-keys.md),
[ADR 0007](../adr/0007-battery-from-keyboard-notifications.md) and
[ADR 0009](../adr/0009-slim-v0-4-0-scope.md).
[ADR 0008](../adr/0008-swappable-input-backend.md) (swappable backend) is
**Deferred by D19**.
**Status:** gate passed 2026-11-19 and **re-scoped the same day by owner decision
D19** (row 67): "Slim, keep battery". This text is the slim spec. History in one
paragraph: the spec was first written for multi-keyboard profiles, amended after
the architect review (`.dev-team-reports/architect-review-2026-11-19.md`, M1 to
M9), the owner's MacOS-mode, MX-hardware and battery corrections (D10, D4
update, D11, D18), a swappable Solaar/OpenLogi backend (D13 to D17) and the
Solaar `show` crash finding, and went through six plan-review rounds. D19 kept
what makes the plugin useful on top of Solaar and deferred the rest; **acceptance
criteria that D19 deferred stay in place with their numbers and read "Deferred
(D19)"** so numbering is stable and nothing is silently lost. Owner decisions
D1 to D19 are in the Ambiguity Log. The MX Keys for Mac preset ships
**untested** (owner's choice): its device data is verified from a recording of
real hardware (2026-11-19), its key presses are not.

## Intent Description

The owner wants the plugin to support Logitech keyboards other than the POP Icon
Keys before it is submitted to the Omarchy marketplace, so that other people can
add their keyboard by pull request ("is this project extensible moduler strcture
for others to send PR for other keyboard than pop-icon"; "make it
multi-keyboard before submitting"). Solaar's own GUI already offers key diversion
dropdowns and a rule editor with Execute actions (D19), so this plugin's value is
the part Solaar does not do for you:

1. **Ready-made presets per keyboard.** The plugin is renamed **Logitech Keys**
   (`io.github.poornan.logitech-keys`; the repo becomes
   `poornan/omarchy-logitech-keys` later; ADR 0006). The owner's word *preset* is
   the profile file (`profiles/<slug>.json`, Glossary): key name, control id,
   label and an Omarchy command per key. It ships **two**: POP Icon Keys (key
   mapping tested on real hardware, MacOS OS mode) and MX Keys for Mac (device
   data from real hardware, key presses **untested**; it demonstrates the
   extension structure). Both keyboards run in **MacOS OS mode** (the user sets
   Solaar "Set OS" = MacOS; the plugin never changes it).
2. **One consent-gated setup and uninstall** that put the rules, the diversion,
   the POP Lock binding and Solaar's autostart in place and take them away again,
   with backups, marked blocks and Solaar stopped while its config is written.
3. **Restore of dropped keys.** A keyboard drops its live diversion after sleep or
   reconnect; the widget notices and restores it without writing any file.
4. **Start Solaar.** Closing Solaar's window quits Solaar on Omarchy (no tray),
   which silently kills all key routing, so the widget says so and offers a Start
   Solaar action (and an Open Solaar action).
5. **An accurate battery** (D11, D18, kept by D19; ADR 0007): the keyboard's own
   battery reports, kept with their age, not the stale direct query.
6. **A small widget:** one bar icon (battery plus OK or attention); the popup lists
   each keyboard with its battery and **one** state and a few buttons.
7. **A status that survives a crashing `solaar show`:** each preset's keyboard is
   queried on its own; unread keyboards are "unknown", never "disconnected".
8. **Adding a keyboard is a pull request** that adds one preset file, one recorded
   fixture and a README row; the README says how, and that a preset can run any
   command on a key press, so presets are reviewed (the accepted risk of D19).

Everything the POP Icon Keys spec requires (AC1 to AC18 there) keeps holding for
the POP Icon Keys preset. v0.3 safety tests (119 checks) are an explicit
requirement (AC10).

Out of scope: mice and other non-keyboard devices, per-user overrides,
non-Logitech keyboards, keyboards Solaar cannot divert keys on, modifier-key
conditions (Solaar's `Modifiers` returns False without a keymap on Wayland),
gestures and thumb buttons, per-OS-mode variants, key-release events. **Deferred
by D19** (not deleted ideas; reasons in the Ambiguity Log): a swappable Solaar or
OpenLogi backend and switching (ADR 0008), a strict preset schema beyond basic
validation, an action table, `applied.json` and reconciliation, legacy-rule
migration machinery, CODEOWNERS and a PR template, a Solaar key-table
cross-check in CI, a per-key widget UI, `unsupportedByBackend`, `otherRunning`,
`liveKeyState`, LogiOps.

## Architecture Specification

- **Presets** live in `profiles/<slug>.json`, one per keyboard model (`"schema":
  1`):
  - `slug`, `displayName`;
  - `modelIds`: required non-empty list of Solaar model ids (twelve uppercase hex
    digits), the primary identity. `names`: required non-empty list of **exact**
    Solaar names the keyboard can have, used as fallback identity and as the
    values of the rule `Device` condition. It lists both the name `solaar show`
    prints while the keyboard is online and the codename Solaar saves as `_NAME`
    in `config.yaml` while it is offline (MX: "MX Keys for Mac" and "MX Keys
    Mac"). Never substrings.
  - `osMode` (required): the keyboard's Solaar "Set OS" value, one of `Linux`,
    `MacOS`, `Windows`, `iOS`, `Android`, `WebOS`, `Chrome`, `WinEmb`, `Tizen`.
    Both shipped presets are `"MacOS"`.
  - `keys`: non-empty list of `{name, cid, label, command}`. `name` is Solaar's
    key name and `cid` its control id, always together. `label` is the human text
    for the plan and README. `command` is a non-empty **argument list** of strings
    without control characters (the one non-literal argument is the placeholder
    `@show-desktop`, replaced by the installed Show Desktop helper path).
  - `bindings` (optional): list of `{chord, label, command}` Hyprland bindings for
    keys Solaar cannot divert (POP Lock: `SUPER + CTRL + Q`, `omarchy-system-lock`).
    `chord` must fully match a fixed regex (one to four distinct modifiers of
    SUPER, CTRL, ALT, SHIFT, then one key `A-Z`, `0-9` or `F1-F12`).
  - `battery` (optional): `{"feature": "UNIFIED BATTERY"}` (POP) or `{"feature":
    "BATTERY STATUS"}` (MX), the HID++ battery feature. Absent: no battery rules,
    the battery source is the query.
  - `verified` (optional): `{solaar, date, fnSwap}`. A preset is **tested** if
    and only if `verified` is present (no boolean). POP has it; MX gets it only
    after the owner's live test. `note` (optional): one line of plain text (MX:
    "device data recorded from real hardware 2026-11-19; key actions untested").
  - Unknown top-level fields fail validation.
- **One reader** `lib/profiles.py` (stdlib, pure data; the folder is a function
  argument): required fields and types as above, slug equals the file name, cid
  paired with name, no duplicate cids or key names within a preset, no model id or
  name shared by two presets, chord regex, closed lists for `osMode` and battery
  feature, `verified` types, `note` single line. Errors name the file and field
  (`error: profile: <file>: <field>: <reason>`). `setup`, `uninstall`, the status
  and restore helpers and tests get keyboard data only through the reader. Bash
  never parses presets (no `jq`); `Panel.qml` has no keyboard knowledge. Deferred
  by D19: strict nested-field validation, the substring-of-another-name check,
  the chord-conflict check, a permanent-slug list, the key-table snapshot. An
  optional local check against the installed Solaar's key table runs when Solaar
  is importable and is never required.
- **Accepted risk (D19).** A preset holds the command Solaar runs on a key press, so
  a preset PR can put a command on a key. Mitigation is maintainer review only; the
  README says so (AC9) and ADR 0005 records it. Cheap safety stays: the command is
  validated as an argument list, the chord regex, and **one module `lib/rules.py`
  holds all escaping** (YAML flow, Lua string, shell argument; one function each);
  nothing else writes YAML, Lua or shell text from preset data.
- **Modules** (kept close to v0.3): `lib/profiles.py` (reader); `lib/solaarcfg.py`
  (the one identity module: `config.yaml` entry parsing with line spans,
  `match_device(profiles, model_id, name)`, the ambiguity test); `lib/status.py`
  (parse `solaar show` blocks, the state table, `choose_battery`, the status JSON,
  restore; `collect(run, ...)` is the only function that does I/O and `run` is
  injected); `lib/rules.py` (rule and Lua generation, classification, all
  escaping); `lib/plan.py` (the consent plan as text from data); `lib/edit.py` (the
  v0.3 command line and file primitives: read, back up, atomic write, marked
  blocks, `config.yaml` diversion), made preset-driven (its `RULES` table is
  deleted). Every `lib/` module imports on its own under `python3 -I`; entry
  scripts put their own folder first on `sys.path`.
- **Identity.** A keyboard matches a preset by exact model id, then exact name; Solaar
  stores the name in `_modelId` when the model id is all zero, so a saved entry
  whose `_modelId` is not twelve hex digits is matched on that value as a name.
  Never by substring: `solaar show "MX Keys"` would match "MX Keys for Mac", "MX
  Keys Mini" and "MX Keys S". Status queries each preset's keyboard by exact
  selector, `solaar show "<selector>"`, **never `solaar show all`** (Solaar 1.1.20
  crashes with `UnicodeDecodeError` in `get_host_names` partway on the owner's
  machine while printing the MX Master 4). Selectors are the preset `names` and the
  names of saved `config.yaml` entries matched to it by model id; a saved name that
  starts with `-` or contains a double quote or a newline is skipped. Each returned
  block is parsed on its own and its `Model ID:` (or exact name when the model id is
  all zero) is verified: a block that is not the preset's keyboard is not this
  device and makes the selector ambiguous. Restore addresses the keyboard by the
  matched block's exact printed name and skips an ambiguous selector.
- **Daemon detection.** `pgrep -u $UID -x solaar` finds Solaar's daemon; a process
  with only options is the daemon, whatever the options (`solaar -dd
  --window=hide`, the owner's command line, counts), and a process given a
  subcommand (`show`, `config`, `probe`, `profiles`, `pair`, `unpair`) is a one-off
  and does not. Options that take a value are skipped with it.
- **Status** (`bin/logitech-keys-status`, always exit 0, valid JSON): `{schema: 1,
  solaar: {installed, running, canStart}, keyboards: [...]}`. Per keyboard, sorted
  by slug: `slug`, `name`, `tested`, `connected`, `state`, `readProblem`
  (`solaarCrashed`, `timeout`, `noOutput` or null), `battery` (null or `{value,
  level, source, at}`), `keys` (`cid`, `label`, `state`) and `counts`. **Key state**
  is `routed`, `dropped`, `notSetUp`, `absent` or `unknown`: live diverted with
  saved diverted is `routed`; live diverted with saved regular or unlisted is
  `notSetUp`; live regular with saved diverted is `dropped`; regular in both or one
  line only is `notSetUp`; listed in neither line is `absent` (the keyboard does not
  report the cid; dimmed, never counted toward a warning); with an older Solaar
  that prints no saved line the live line alone decides. Diversion lines are parsed
  in Python by exact key name and cid (suffix pairs such as "Search / MultiPlatform
  Search" and "Screen Capture/Print Screen" are handled by cid, not by substring).
  **Truncated output:** a non-zero exit, a timeout or empty output means the devices
  not yet printed were not read; a block is complete when the next header follows it
  or the call exited 0. Complete blocks parse normally. A preset keyboard known to
  Solaar (a saved entry matches) that was not read completely has every key
  `unknown` and a `readProblem`; `unknown` never counts toward a warning and is never
  restored; it is never reported as disconnected or not set up. `no device found
  matching` is a clean "not present" (no section). **Keyboard state** (one word per
  keyboard, the widget's only per-keyboard fact): `unknown` if any key is unknown;
  `needsSetup` if any key is `notSetUp`; `stopped` if Solaar is not running (keys
  that would read dropped are not blamed on the keyboard); `dropped` if any key is
  `dropped`; `mismatch` if every key is `absent`; else `ok`. While Solaar is stopped
  the per-device `solaar show` still works (it reads the receiver itself), so the
  keyboards are still listed. `battery.source` is `report` (the state file) or
  `query`; the one function `choose_battery(report, query)` holds the rule.
- **Rules:** one marked block in `rules.yaml` with the rules of every applied
  preset. **Every rule has a `Device` condition** (an `Or` over the preset's `names`;
  a plain `Device` for one name); no `Model` condition (Solaar 1.1.20 has none).
  Rules never fire for another keyboard, even with the same key name.
  `classify()` reports plugin-owned rules and, for any rule outside the block that
  names a handled key and can fire on a handled keyboard, "your own rule" (setup
  warns that both would run; it also catches v0.3 rules Solaar's editor rewrote
  without markers, which is all the migration D19 keeps for them).
- **Battery** (ADR 0007, unchanged by D19 except that it is Solaar rules only).
  Solaar's direct query can be stale (verified: "100% charged" while the keyboard's
  own report said 15%); Solaar has no API and its log gets no DEBUG lines, so the
  plugin parses no logs and adds no `-d`. Solaar passes every feature notification to
  the rule engine, so for each applied preset with a `battery` field the rules block
  holds one rule per 10 % bucket (0-9, 10-19, ... 90-100): `Device` + `Feature` (the
  preset's battery feature) + `Report: 0` + `TestBytes [0, 1, lo, hi]` (inclusive,
  signed byte, fine for 0-100) -> `Execute [<helper>, <slug>, <lo>]`. The helper
  `bin/logitech-keys-battery <slug> <percent>` is **self-contained** (no import of
  plugin modules, so the copy in `~/.local/bin` works): it accepts a slug of
  lowercase letters, digits and single hyphens and an integer 0-100, snaps the
  percent to its bucket's lower bound, and writes
  `$XDG_STATE_HOME/logitech-keys/battery/<slug>` atomically as `<lo>\n<epoch>\n`
  (`~/.local/state` when `XDG_STATE_HOME` is unset or relative; never under
  `/tmp`). It is the **only** writer of that directory; a query value is never
  persisted. Selection (D18, "Keep last report"): the latest report is kept at any
  age until a newer report or a **lower** direct query arrives; an equal or higher
  query never replaces it; with no report the query is shown (source `query`).
  A report's `value` is the bucket midpoint (`lo` + 5). The widget shows "≈15%, 3 h
  ago" for a report, the exact figure for a lower query, and "Full?" (never a
  confident 100 %) when only the query says full or 100. Accepted risk: after new
  batteries the old low value shows until the keyboard reports again. Whether
  Solaar reloads rules without a restart is unverified (setup restarts it) and the
  end-to-end battery result is **unverified until the owner's live check**; the
  README says so.
- **Diversion:** set per matching `config.yaml` entry from the preset's control ids
  (separate entries for Bluetooth and Bolt: all entries matching `modelIds` or
  `names` are written), only while Solaar is stopped.
- **Setup scope:** applies presets for keyboards recorded in Solaar's `config.yaml`.
  Two phases: (1) resolve the set (stop Solaar, read the saved entries; if none
  matches, start Solaar once so it records the connected keyboards, wait, stop it,
  read again); (2) rules block, helpers, Lua blocks, then divert, then restart Solaar,
  with rules before diversion so a failure leaves the keyboard working as before.
  On a fresh install, when Solaar has no entry for any supported keyboard, the consent
  plan lists the **supported keyboards** (tested or "Untested - may not match your
  keys") and says setup applies whichever Solaar then records. If Solaar still records
  none, setup exits 2 and writes no rules block or binding. Solaar is stopped while
  `config.yaml` is written and **restarted on every exit path** (v0.3 guarantee, M5).
  The OS mode is read-only: if a keyboard's "Set OS" differs from the preset's
  `osMode` the plan warns and continues; an unreadable mode gives no warning.
- **Consent plan** (`lib/plan.py`; bash only prints it and runs steps): a heading; one
  block per keyboard (tested or untested, each key with its command); file changes;
  the Solaar stop and restart notice; the v0.3 cleanup items; the control ids that
  uninstall would reset (on uninstall); a **Warnings** group directly above the prompt
  (OS mode mismatch, your own rules on handled keys, old plugin installed, no keyboard
  recorded yet); one y/N for all keyboards, default No; `--dry-run` prints diffs and
  writes nothing; `--yes` accepts but never installs packages; declining exits 0.
- **Uninstall** removes both generations' marked blocks (`logitech-keys` and v0.3
  `pop-icon-keys`) from `rules.yaml`, Hyprland's bindings and autostart, the helpers,
  and the plugin's state directory (the battery files); it resets the diversion to
  Regular for the control ids of the presets of the known keyboards, on the
  `config.yaml` entries that match them (as v0.3 did), while Solaar is stopped, and
  restarts Solaar only if it stopped it. **Limit, stated in the plan:** a key the
  user diverted for themselves on the same control id is reset too, and the plan
  lists the ids. It never uninstalls packages.
- **v0.3 cleanup (setup):** with consent and listed in the plan, setup removes
  `pop-icon-keys` marked blocks (YAML and Lua) and the old helper
  `~/.local/bin/pop-icon-keys-show-desktop`, and warns if
  `io.github.poornan.pop-icon-keys` is still installed (its Re-apply would write old
  blocks; two widgets). Deferred by D19: replacing v0.3 rules Solaar rewrote without
  markers (the "your own rules" warning shows them; README upgrade note says to
  delete them by hand).
- **Hyprland bindings:** one marked Lua block with the preset `bindings`, the command
  shell-joined by `lib/rules.py`, chords validated; an existing unmarked binding of
  the same chord is left alone and listed (v0.3 behaviour). Solaar autostart:
  `o.launch_on_start("solaar --window=hide")` in its own marked block unless a line
  already starts Solaar.
- **Restore and Start Solaar.** `bin/logitech-keys-restore [slug...]` re-applies the
  saved diversion of `dropped` keys with `solaar config "<exact name>" divert-keys
  "<key>" Diverted` for keyboards whose selector is unambiguous; it writes no file
  and does nothing for `unknown`, `absent` or `notSetUp` keys or while Solaar is
  stopped. The widget's auto-restore is rate-limited (v0.3: at most one run per
  minute, held back after a manual restore). `bin/logitech-keys-start` runs `setsid
  -f solaar --window=hide` (verified from `solaar --help`), changes and writes no file,
  exits 0 when it started Solaar and non-zero with a one-line sentence when Solaar is
  already running or not installed. **Open Solaar** runs `solaar --window=show`
  (a second `solaar` activates the running instance's window; unverified until the
  owner's live check); its tooltip says closing that window quits Solaar.
- **Widget:** `Panel.qml` renders the status JSON only; it has no keyboard or key
  names and no per-key list. One bar icon (battery glyph plus OK or an attention
  badge; the icon warns for `needsSetup`, `dropped`, `stopped` and `mismatch`, not for
  `unknown`). The popup, when Solaar is stopped, **opens with a banner** ("Solaar is
  not running, so these keys do nothing", with a **Start Solaar** button when
  `solaar.canStart`). Then one row per keyboard: name, an "Untested - may not match
  your keys" label when not tested, the battery text or "Battery unknown", and ONE
  state in words, never colour alone: "OK", "N keys dropped", "Needs setup", "Not active
  (Solaar stopped)", "Status unknown", "Preset may not match this keyboard". Buttons:
  **Restore** (hidden while Solaar is stopped or when nothing is dropped), **Start
  Solaar**, **Re-apply setup** (opens a terminal running `setup`; says it covers all
  keyboards; shows a pending line), **Open Solaar**. Escape closes the popup, Enter or
  Space activates a focused button, single-key shortcuts (`r` refresh, `s` setup, `k`
  restore, `t` Start Solaar) are named in the tooltips; failures say what to do (a
  failed restore, unreadable status, an unknown status schema says to reload the
  shell). User vocabulary: "keyboard", never "profile"/"preset" in the popup. IPC
  target and QML module name are `logitech-keys`; manifest id, name and version
  `0.4.0`.
- **Rename and cleanup:** new id, display name, repo URL, marker text `logitech-keys`,
  helpers `logitech-keys-*`, state directory `logitech-keys` (ADR 0006).
- **Contributor gate (slim):** `.github/workflows/test.yml` runs the stdlib and
  sandbox tests on push and PR (`permissions: contents: read`, every action pinned by
  full commit SHA) and validates the presets (the reader). The README's "Add your
  keyboard" says what a PR must contain. Deferred by D19: PR template, CODEOWNERS.
- **README order:** what it does, supported keyboards (with tested/untested and the
  MacOS-mode requirement), install and uninstall, upgrading from v0.3, troubleshooting
  and known issues, then "Add your keyboard".
- **Tests:** preset reader and mutation tests; **one recorded** `solaar show` fixture
  per preset (`tests/fixtures/<slug>/show.txt`, first line carries the Solaar version,
  serials, unit ids, MAC addresses and hid paths masked, enforced by a test; the MX
  fixture is the owner's masked 2026-11-19 recording copied from the orchestrator's
  scratch recording, never the unmasked `raw.txt`); routed, dropped and not-set-up
  variants derived in the test (POP variants checked equal to the v0.3 recordings until
  those are deleted); a synthetic truncation fixture built in the test from the masked
  POP fixture plus the traceback text and labelled synthetic; the sandbox
  `tests/test_setup.sh` (stubs for `pgrep`, `solaar`, `hyprctl`, `setsid`; v0.3 safety
  checks kept, count not below 119) covers POP, the two-keyboard case (with a synthetic
  preset that shares a key name) and v0.3 cleanup; other presets get fast pure-Python
  checks. On the dev machine generated rules are loaded and evaluated with Solaar's own
  rule code (`LK_REQUIRE_SOLAAR=1` turns a skip into a failure there; CI has no Solaar).
- **Constraints:** unchanged from v0.3: consent, marked blocks, atomic writes, Solaar
  stopped while writing `config.yaml`, marketplace baseline (no `curl | sh`, no
  `sudo`, no `/tmp` process control, no `/home` paths in shipped files).

## Acceptance Criteria

Numbering is stable. "Deferred (D19)" criteria are kept in place and are not built in
v0.4.0; the plan lists them under Deferred.

- **AC1 —** The plugin id is `io.github.poornan.logitech-keys`, display name "Logitech
  Keys", manifest version `0.4.0`; the README and every install command in it use
  `github.com/poornan/omarchy-logitech-keys`; the old repository name appears in the
  README only in the upgrading-from-v0.3 section (a test checks both).
- **AC2 —** With only the POP Icon Keys known to Solaar, behaviour matches the POP Icon
  Keys spec AC1 to AC18, including a fresh install where Solaar has no keyboard entry yet
  (AC21).
- **AC3 —** With only the MX Keys for Mac known to Solaar, setup diverts and maps
  (control id -> command): 225 Launchpad -> the app launcher; 191 Screen Capture/Print
  Screen -> region screenshot; 111 Screen Lock -> `omarchy-system-lock`; 10 Calculator ->
  `omacalc`. Mission Control (224), Eject (13), brightness, backlight, media and volume
  keys are not diverted. The preset has no `verified` block but a `note`; the plan, README
  and widget mark it **untested**.
- **AC3a —** (plan id AC23) Presets use Solaar's own key names and control ids. POP Icon
  Keys: 110 Show Desktop, 212 MultiPlatform Search, 259 Dictation, 264 Emoji, 266 Screen
  Capture. v0.3 had 212 and 266 swapped in the `RULES` data of `lib/edit.py`, which status
  and restore read; diversion was unaffected only because both ids were listed. The preset
  is the single source and a test pins these pairs.
- **AC4 —** With both keyboards known, setup applies both presets in one consent-gated
  run, and each keyboard's keys run its own preset's commands, including a key name the
  two share (each rule carries its `Device` condition).
- **AC5 —** Adding a keyboard needs only a new `profiles/<slug>.json`, its one recorded
  fixture and a README row; no script or QML change and no other table. A test fails if a
  preset is malformed or lacks its fixture.
- **AC6 —** The bar shows one icon. The popup lists every connected preset keyboard with
  its battery and ONE state; the icon warns for needs setup, dropped keys, Solaar stopped
  or a mismatching preset, not for unknown. Untested presets are labelled.
- **AC7 —** A keyboard that drops diversion is restored without affecting the other
  keyboard. Restore does nothing for a keyboard whose selector matches more than one
  device, writes no file, and does nothing while Solaar is stopped.
- **AC8 —** Running the new `setup` over a v0.3 install removes the `pop-icon-keys` marked
  blocks and the old helper (with consent, listed in the plan), puts the `logitech-keys`
  blocks in their place with one copy of each rule, and leaves user rules intact; a second
  run changes nothing and makes no backup. `uninstall` removes both old and new blocks.
  Setup warns if `io.github.poornan.pop-icon-keys` is still installed. (Unmarked v0.3 rules:
  AC17.)
- **AC9 —** The README has an "Add your keyboard" section, after what it does, supported
  keyboards, install and uninstall, upgrading from v0.3, and troubleshooting and known
  issues: how to read key names and ids with `solaar show "<name>"`, the preset format, a
  copy-paste masking command for the fixture, how to record it, and what the PR must
  contain (preset, fixture, README row, honest `verified`). It states the **accepted risk**:
  a preset can run any command when its key is pressed, so presets are reviewed by the
  maintainer before they are merged. It also notes: keycap labels depend on Fn-swap, Solaar
  may name a cid differently across versions, and rollback is v0.4's own uninstall.
- **AC10 —** All v0.3 safety tests still pass, adapted to presets (the sandbox suite's
  check count is not below the v0.3 baseline of 119), plus the preset, status, two-keyboard,
  cleanup and battery tests; dev-team review passes before release.
- **AC11 —** Identity is by exact model id, then exact name. A device named "MX Keys Mini"
  or "MX Keys S" does not match the MX Keys for Mac preset. Status checks each device
  block's `Model ID:` line.
- **AC12 —** Diversion lines are parsed in Python with exact key-name and cid matching; a
  fixture with Solaar's suffixed names (Search / MultiPlatform Search, Print Screen / Screen
  Capture/Print Screen) gives the right states. `Panel.qml` renders the JSON and contains no
  keyboard or key names.
- **AC13 —** Preset commands are argument lists of non-empty control-free strings; a
  string `command`, an empty list, a control character, a chord outside the regex or an
  unknown top-level field fails validation. Rules and Lua blocks are generated from the
  presets; preset text reaches YAML, Lua and shell commands only through the escaping
  functions of `lib/rules.py` (a test feeds quotes, brackets, `#`, backslashes and `]]`).
- **AC14 —** Every generated rule has a `Device` condition over the preset's names and no
  `Model` condition, and fires only for its own keyboard (checked with Solaar's own
  evaluator on the dev machine). `classify()` treats the plugin's rules as ours and flags any
  other rule on a handled key that can fire on a handled keyboard.
- **AC15 —** A key in neither diversion line has state `absent`: not counted toward any
  warning. The key state for every live-by-saved combination, including an older Solaar with
  no saved line, follows the table in the Architecture Specification.
- **AC16 —** Deferred (D19): `applied.json`, reconcile on setup and reset-from-record on
  uninstall (M6). Replaced by AC65.
- **AC17 —** Deferred (D19): detecting and replacing v0.3 rules that Solaar's editor
  rewrote without markers, the five v0.3 argument lists and the near-miss rule. Kept
  instead: the cleanup in AC8 and the "your own rules" warning (AC14, AC26).
- **AC18 —** The preset reader enforces the basic schema in the Architecture
  Specification. Every shipped preset passes; a test mutates a valid preset into each failure
  case (missing or wrong `schema`, duplicate cid or key name, empty `keys`, `names` or
  `modelIds`, a malformed model id, a shared model id or name, a bad chord, a bad battery
  feature, a bad `osMode`, a string command, malformed `verified`, invalid JSON, a
  non-object file). Deferred (D19): the Solaar key-table cross-check in CI and the strict
  nested schema; an optional local check against the installed Solaar's key table runs
  when it is importable.
- **AC19 —** A preset is tested only if `verified` is present with `solaar`, `date` and
  `fnSwap` (`osMode` is a top-level field, AC45). Each preset has one recorded fixture whose
  first line holds the Solaar version (equal to `verified.solaar` when present) and whose
  serials, unit ids, MAC addresses and hid paths are masked (a test enforces it); a fixture
  marked synthetic never sets `verified`. A recorded fixture alone does not make a preset
  tested.
- **AC20 —** The repo has a CI workflow running the stdlib and sandbox tests and validating
  the presets (actions pinned by full commit SHA, `permissions: contents: read`), with a
  structural repository test. Deferred (D19): PR template and CODEOWNERS.
- **AC21 —** On a fresh install with no Solaar entry for any supported keyboard, the consent
  plan lists the supported keyboards (tested/untested) and states that setup applies whichever
  Solaar then records; declining still exits 0 with no change. Setup is two-phase. If Solaar
  records no supported keyboard, setup exits 2, names the supported keyboards and the next
  steps, and writes no rules block or binding.
- **AC22 —** The widget IPC target and QML module name are `logitech-keys`.

The plan numbers AC3a as AC23 (its tooling wants whole numbers); the criteria below are AC24
onward.

- **AC24 —** Deferred (D19): a robust `applied.json` (union before divert, atomic, damaged
  or newer record stops setup).
- **AC25 —** Widget states are text first: every keyboard row states its ONE state in words
  (OK, N keys dropped, Needs setup, Not active (Solaar stopped), Status unknown, Preset may
  not match this keyboard); an untested keyboard says "Untested - may not match your keys";
  a stopped Solaar leads the popup with a banner; failures say what to do; Re-apply setup
  states that it covers all keyboards and shows a pending line; Escape closes the popup, Enter
  or Space activates a focused button, and the single-key shortcuts are named in the tooltips.
- **AC26 —** The consent plan is complete and ordered: a block per keyboard (tested or
  "Untested - may not match your keys", keys, commands), the file changes, the Solaar stop and
  restart notice, the v0.3 cleanup items, and a Warnings group directly above the prompt (OS
  mode mismatch, your own rules on handled keys, old plugin still installed). The uninstall
  plan lists the control ids it will reset and says a key the user diverted themselves on the
  same id is reset too.
- **AC27 —** (OS mode, README) The README states that the keyboards must be in **MacOS OS
  mode** (the user sets Solaar "Set OS" = MacOS), that the plugin does not change it, and that
  behaviour in another OS mode is untested. The shipped README and fixtures contain neither
  "Linux OS mode" nor "Linux mode" (case-insensitive; the plan, the ADRs and the project rules
  may quote it, an explicit allowlist in the test). Every preset's `osMode` is `"MacOS"`.
- **AC28 —** (OS mode precondition) Before the consent plan, `setup` reads each preset
  keyboard's OS mode from Solaar read-only (`solaar show`'s "Set OS" line or the saved entry;
  no write, no restart). If it differs from the preset's `osMode` the plan warns, naming the
  keyboard, the expected mode and where to change it (Solaar), and continues. It never changes
  the mode and does not block or change the exit code. If the mode cannot be read, no warning.
- **AC29 —** (MX recorded device data) The MX preset's `modelIds`, `names`, `osMode`
  (`MacOS`), `battery` feature (`BATTERY STATUS`) and keys equal the recorded hardware facts
  (model id `B36140920000`, name "MX Keys for Mac", codename "MX Keys Mac", Unifying receiver,
  cids 225 "Dashboard Launchpad/Action Center", 191 "Screen Capture/Print Screen", 111 "Screen
  Lock", 10 "Calculator", all `persistently_divertable, divertable`), checked against the
  recorded fixture `tests/fixtures/mx-keys-mac/show.txt`. The recorded fixture is masked (a
  test enforces it) and the earlier synthetic MX variants are gone. A test pins that the MX
  preset has no `verified` block and has a `note`.
- **AC30 —** (battery rules) For each applied preset with a `battery` field, setup generates in
  the managed rules block ten bucket rules (`Device` + `Feature` + `Report: 0` + `TestBytes [0,
  1, lo, hi]` -> `Execute [<helper>, <slug>, <lo>]`), loadable and evaluated by Solaar's own rule
  code on the dev machine: a UNIFIED_BATTERY notification with byte 0 = 15 fires only the 10-19
  rule, for only that keyboard; 0 and 100 hit the first and last buckets; a BATTERY STATUS
  notification works for the MX preset. A preset with no `battery` gets none. `classify()` counts
  these rules as ours; uninstall removes them; running setup again changes nothing.
- **AC31 —** (battery helper) `bin/logitech-keys-battery <slug> <percent>` is self-contained,
  rejects a slug that is not lowercase letters, digits and single hyphens, a non-integer, a value
  outside 0-100 and a wrong argument count (exit non-zero, no file); otherwise it writes
  `$XDG_STATE_HOME/logitech-keys/battery/<slug>` atomically as `<lo>\n<epoch>\n`, using
  `~/.local/state` when `XDG_STATE_HOME` is unset or relative, never under `/tmp`. It snaps a
  percent to its bucket's lower bound (0 to 9 gives 0, 15 gives 10, 95 and 100 give 90); a test
  pins 0, 10, 15, 90, 95, 100 and the round trip: the helper writes bucket 10, status reads value
  15, source `report`. A path-traversal slug (`../x`) writes nothing.
- **AC32 —** (battery status) The status `battery` is null or `{value, level, source, at}` per
  keyboard (`level` may be null; `source` is `report` or `query`). The one function
  `choose_battery(report, query)` (D18) keeps the latest report (`value` = bucket lower bound + 5,
  `at` its time) whatever its age, unless the query value is **lower**, in which case the query
  figure is used with source `query`. An equal or higher query never replaces the report (report
  15, query 100 shows the report); a newer report replaces an older one; with no report the
  `solaar show` figure is used (source `query`); no data gives null. A missing or damaged battery
  file reads as no report. A query figure is never persisted (AC52).
- **AC33 —** (battery widget) The popup shows "≈15%, 3 h ago" for a report (the age is one pure
  function of the report time and an injected `now`: under a minute and any future time "just
  now", then "N min ago", "N h ago", "N d ago"), the exact figure for a query below 100 (no age),
  "Full?" (not "100%") when only the query says full or 100, and "Battery unknown" for null. The
  tooltips are "The keyboard has not reported its charge yet." for "Full?" and "Waiting for the
  keyboard's next battery report." for "Battery unknown"; the accessible name of a report is
  "about 15 percent, 3 hours ago". The README states the accepted limitation (D18: after new
  batteries the old value shows until the keyboard reports; Restore or Refresh does not force a
  report). The widget logic test covers each case.
- **AC34 —** (battery cleanup) `uninstall` removes the plugin's state directory (`battery/`) and
  nothing else; a dry run removes nothing; the plan lists it.
- **AC35 —** Deferred (D19): backend seam and registry (ADR 0008).
- **AC36 —** Deferred (D19): backend selection and the both-running refusal.
- **AC37 —** Deferred (D19): the OpenLogi read side.
- **AC38 —** Deferred (D19): OpenLogi unusable states.
- **AC39 —** Deferred (D19): `unsupportedByBackend`.
- **AC40 —** Deferred (D19): `otherRunning`.
- **AC41 —** Deferred (D19): switching backends (D15 `disable --now` path not built).
- **AC42 —** Deferred (D19): uninstall across backends.
- **AC43 —** Deferred (D19): backend lines of the consent plan.
- **AC44 —** Deferred (D19): backend fields of the applied record.
- **AC45 —** (schema: `osMode`) Every preset has a top-level `osMode` from the closed list
  (Linux, MacOS, Windows, iOS, Android, WebOS, Chrome, WinEmb, Tizen); a missing or unknown value,
  or an `osMode` inside `verified`, fails validation. POP and MX are `MacOS`.
- **AC46 —** Deferred (D19): the optional `backends` section.
- **AC47 —** Deferred (D19): backend contract tests and the OpenLogi/`systemctl` stubs.
- **AC48 —** Deferred (D19): OpenLogi never written (there is no OpenLogi code).
- **AC49 —** (Solaar not running, widget and status) When Solaar is installed but not running,
  `solaar.running` is false and the widget shows it prominently: a banner leading the popup in
  words ("Solaar is not running, so these keys do nothing"), the icon in its warning state, and no
  automatic restore. `solaar.canStart` is true exactly when Solaar is installed and not running;
  the banner then has a **Start Solaar** button, and without `canStart` it says how to install
  Solaar. While Solaar is stopped the status still lists the preset keyboards read per device:
  keys that look lost read "Not active (Solaar stopped)", the manual Restore button is hidden,
  and nothing is restored until Solaar runs; the icon and the banner show even when
  hide-when-disconnected is on. Falsifiers: Solaar running (no banner, icon unchanged), Solaar
  not installed (the install copy, no button).
- **AC50 —** (Start Solaar action) `bin/logitech-keys-start` starts Solaar hidden (`setsid -f
  solaar --window=hide`), changes no configuration file, writes nothing, asks nothing beyond the
  widget click, exits 0 when it started it, and exits non-zero with a one-line sentence when Solaar
  is already running or not installed (no second instance). The widget shows a pending line until
  the next status read and the failure line if it exits non-zero. Tested in the sandbox with the
  `solaar` and `setsid` stubs; the files' checksums are unchanged.
- **AC51 —** (README: start Solaar hidden) The README says that closing Solaar's window quits
  Solaar on Omarchy (no tray) and stops all key routing, tells the user to start it hidden
  (`solaar --window=hide`, which `setup` also puts in autostart) and to leave it running, and
  mentions the widget's Start Solaar and Open Solaar buttons. A structural test pins the flag text
  against `solaar --help` on the dev machine and the autostart line.
- **AC52 —** (battery persistence, D17) Only keyboard battery reports are persisted:
  `bin/logitech-keys-battery` is the only writer of `$XDG_STATE_HOME/logitech-keys/battery/`; the
  status code and the restore helper never write there. A `solaar show` figure (source `query`) is
  shown with its source and never stored, so a stale query cannot be read back later as a report.
  Tested by running status with a query figure and asserting the state directory is byte-identical,
  and by a source check that only the helper opens that path for writing.
- **AC53 —** (per-device queries, never `solaar show all`) Status and restore run `solaar show
  "<selector>"` once per preset keyboard, with an exact selector taken from the preset's `names`
  and from saved `config.yaml` entries matched to it by model id, and run no other `solaar` command
  except restore's `solaar config`; `solaar show all` is never run. Each returned device block is
  parsed on its own and its `Model ID:` line (or exact name when the model id is all zero) is
  checked against the preset: a block that does not match is not this device, and a selector that
  returns such a block is ambiguous (restore skips it, AC7). A saved-entry name that starts with
  `-` or contains a double quote or a newline is skipped, never used as a selector (AC63). Tested
  through `collect` with an injected `run` (exact call count and exact argv list), with a selector
  that returns the POP Icon Keys and a look-alike block. Falsifiers: one `solaar show all` call, a
  keyboard found by substring, an ambiguous selector restored.
- **AC54 —** (truncated or failed output is unknown) A non-zero exit, a timeout or empty output
  from a `solaar show` call never produces `disconnected`, `notSetUp` or a missing keyboard for a
  keyboard Solaar knows: every device block that parsed completely keeps its normal states; a preset
  keyboard known to Solaar that was not read completely has every key `unknown` and a
  `readProblem`; `no device found matching` is "not present" (no section). `unknown` never counts
  toward the warning and is never restored. Falsifiers: a truncated output after a complete POP
  block (POP keeps its states, the unread keyboard is `unknown`), a timeout with a saved entry
  (`unknown`), a timeout with no saved entry (no section), a clean `no device found` (no section).
- **AC55 —** (widget: unknown) The widget shows an `unknown` keyboard's state as "Status unknown"
  and the line "Could not read this keyboard's status. Choose Refresh." (copy once, in `Panel.qml`);
  `unknown` does not turn the icon warning and has no restore action, while a `dropped` keyboard
  still does. Falsifier: an unknown keyboard beside an OK one leaves the icon unchanged.
- **AC56 —** (synthetic truncation fixture) A test builds, in memory, a truncated `solaar show`
  output from the masked recorded POP fixture followed by a second device header (a device whose
  name contains the selector, as a per-device call can return) and the `UnicodeDecodeError`
  traceback text (labelled `synthetic: built from the recorded POP fixture and the owner's
  2026-11-19 traceback`, never counted as verification), and checks AC53 and AC54 on it: the POP
  block is complete and `routed`, the remainder is unknown; it also covers a selector returning two
  blocks (ambiguity).
- **AC57 —** (README known issue) The README has a known-issues note that Solaar 1.1.20's host-name
  decoding bug can make plain `solaar show` (all devices) crash, that the plugin works around it by
  querying each keyboard on its own, and that the user sees "Status unknown" for a keyboard that
  could not be read. A structural test checks the keywords, each within its own section.
- **AC58 —** (module isolation) Every module under `lib/` imports on its own under `python3 -I` in
  a fresh interpreter (a test imports each), and each command-line entry script (`lib/edit.py`,
  `lib/profiles.py`, `lib/status.py`) runs under `-I` from another working directory. Only
  `status.collect` and the process boundary in `lib/status.py` do I/O for status.
- **AC59 —** Deferred (D19): one writer of the applied record.
- **AC60 —** Deferred (D19): typed plan steps and pure switch steps. Kept as AC66: setup's order
  and the Solaar restart guarantee.
- **AC61 —** (widget honesty) The icon tooltip and each keyboard row say "OK" only when every key is
  routed or absent and at least one is routed; "Status unknown" for an unread keyboard (with a short
  phrase per `readProblem` in the tooltip, ending "If this keeps happening, see Troubleshooting in
  the README."); while Solaar is stopped the state reads "Not active (Solaar stopped)" and manual
  Restore is hidden; the popup stays open after Start Solaar and shows a pending line in place of the
  button; the start helper's failure lines are full sentences (a structural test); the battery tooltips
  are as AC33 states.
- **AC62 —** (consent plan warnings) The consent plan has a "Warnings" group directly above the
  prompt: the OS mode, your own rules on handled keys, the old plugin still installed, and no keyboard
  recorded yet. The plan never prints an internal code.
- **AC63 —** (hostile saved-entry names) A saved `config.yaml` entry name that starts with `-` or
  contains a double quote or a newline is skipped as a selector (exact argv assertions: no `solaar
  show` call carries it).
- **AC64 —** (release readiness) Live check 1 (the battery rules write the state file on a real
  notification) is a precondition for tagging v0.4.0; until it is done the README labels the battery
  "unverified until live-checked" (a structural test; the owner removes label and expectation in the
  commit that records the check). The other owner live checks (POP smoke test, MX key presses, Start
  Solaar with Solaar quit, Open Solaar) are owner items before the tag. The plan records no switching
  descope (there is no switching).

Criteria added by D19 and the simplifications:

- **AC65 —** (uninstall resets the known presets' ids) `uninstall` resets the diversion to Regular for
  the control ids of the presets of the known keyboards, on every `config.yaml` entry matching them,
  while Solaar is stopped; keys and entries of other keyboards, and the user's rules, are untouched;
  a profile entry with no matching saved entry is a no-op, not an error; the plan lists the ids and
  states the limit (a user's own diverted key on the same id is reset too). Replaces AC16's record.
- **AC66 —** (setup order and restart guarantee, M5) Setup writes the rules and helpers before the
  diversion, stops Solaar before `config.yaml` is written and restarts it on every exit path (an
  error, Ctrl-C, a closed terminal) when it stopped it; a failure after the first change names the
  backups. A damaged marker aborts with no change. A sandbox test kills setup between steps and checks
  Solaar is running again.
- **AC67 —** (daemon detection with debug flags) `pgrep -x solaar` daemon detection treats `solaar -dd
  --window=hide` (debug flags plus a value-less window option) as the daemon, also `solaar --window
  hide`, and does not treat `solaar show "POP Icon Keys"`, `solaar config ...` or `solaar -dd show
  all` as the daemon. A test in the sandbox pins each.
- **AC68 —** (MX names include the codename) The MX preset's `names` contain both "MX Keys for Mac"
  (as `solaar show` names it online) and "MX Keys Mac" (the codename Solaar saves in `config.yaml`
  `_NAME` while the keyboard is offline), and a saved entry named "MX Keys Mac" with an all-zero model
  id matches the MX preset while "MX Keys Mini" and "MX Keys S" do not (a test).
- **AC69 —** (Open Solaar button) The popup has an **Open Solaar** button that runs `solaar
  --window=show` through the widget's process runner; it is disabled with the reason "Start Solaar
  first" while Solaar is stopped, and its tooltip says closing the Solaar window quits Solaar. Whether
  a second `solaar` activates the hidden window is unverified until the owner's live check.
## Glossary

| Term | Definition | Status | Source |
|------|------------|--------|--------|
| Preset (profile) | The owner's word *preset* = the file `profiles/<slug>.json` describing one keyboard model: names, model ids, key names, control ids, labels and commands. Code and the directory say "profile"; user-facing text says "preset" or "keyboard" | `verified` | Owner (D19), row 68 |
| Preset keyboard | A keyboard with a preset in `profiles/` | `unverified` | This spec |
| Command | The argument list in a preset key or binding that Solaar (or Hyprland) runs; `@show-desktop` is the one placeholder | `verified` | ADR 0005 (D19) |
| Absent | Key state: the key is in neither diversion line (wrong cid or not on this model); never counts toward a warning | `verified` | Architect review M5 |
| Unknown | Key (and keyboard) state: the keyboard's `solaar show` output was truncated, crashed or timed out; never disconnected, never warned, never restored | `verified` | Owner finding 2026-11-19 (`solaar show` crash) |
| Keyboard state | The one word per keyboard: `ok`, `dropped`, `needsSetup`, `stopped`, `unknown` or `mismatch` | `unverified` | This spec |
| Tested | A preset with a `verified` block (key presses tested on owner hardware); otherwise untested. A recorded fixture or `note` does not change this | `verified` | Architect review M8 |
| Fixture | Recorded `solaar show` output for a keyboard, masked, used by tests | `unverified` | v0.3 tests |
| Known to Solaar | Has an entry in `~/.config/solaar/config.yaml` | `unverified` | Solaar behaviour |
| Codename name | The name Solaar saves as `_NAME` in `config.yaml` while a keyboard is offline ("MX Keys Mac"), unlike the name `solaar show` prints online ("MX Keys for Mac") | `verified` | Owner hardware recording, 2026-11-19 |
| MacOS OS mode | Keyboard setting (Solaar "Set OS" = MacOS) in which Cmd sends Super, Opt sends Alt and Lock sends `Super+Ctrl+Q`; both shipped keyboards run in it. The user sets it; the plugin never changes it | `verified` | Owner, 2026-11-19 (D10) |
| Device data (of a preset) | A preset's model id, names, key names and cids as read from hardware. The MX preset's are verified from the recorded fixture; its key presses are not | `verified` | Owner recording, 2026-11-19 |
| Battery report | A battery notification sent by the keyboard itself, seen by a Solaar rule and stored by `bin/logitech-keys-battery`; kept over a direct query that is equal or higher, replaced only by a lower query (D18) | `verified` | Owner, 2026-11-19 (15% vs 100%); ADR 0007 |
| Selector | The argument of `solaar show "<selector>"`: an exact preset name or saved-entry name. Solaar matches it by name substring, so the returned blocks are checked by model id | `verified` | Solaar 1.1.20 behaviour (ADR 0005) |
| Start Solaar action | `bin/logitech-keys-start`: `setsid -f solaar --window=hide`, no config change, refuses when Solaar already runs | `verified` | `solaar --help`; AC50 |
| Not active | The widget's words for a key that looks lost while Solaar is stopped ("Not active (Solaar stopped)"); the JSON state is still `dropped` | `verified` | Plan review round 6 (UX U-3) |
| Identity module | `lib/solaarcfg.py`: the one place that matches a Solaar device or saved entry to a preset | `verified` | Plan review (design D1) |
| Deferred by D19 | Designed or specified earlier, not built in v0.4.0, kept as reference with the reason | `verified` | Owner, D19 |

## Ambiguity Log

Predictability check (step A2) for each `inferable` row: the plausible alternative is stated and ruled out by the source named.

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
| 13 | Profiles name action ids, not commands (M3); architect must-fix items M1-M9 applied (D7) | `requires-stakeholder-input` | human (B) via "apply architect must-fix changes"; narrowed by D19 | **Deferred by D19 for M3, M6, M7 (most) and M8 (most).** Applied: M1 (exact identity), M2 (Python parsing), M4 (always `Device`), M5 (absent), M9. M3 (action ids) is replaced by commands in the preset: **accepted risk**, a preset PR can put a command that Solaar runs on a key press, mitigated only by maintainer review; the README says so; cheap injection safety (argv-list validation, chord regex, one escaping module) stays. ADR 0005, 0009. AC5, AC13. |
| 14 | `absent` key state (M5) | `inferable` | architect | Alternative "treat as not set up" ruled out: a wrong cid in an untested profile would keep the icon red forever. AC15. |
| 15 | Applied-state file, permanent slugs (M6) | `requires-stakeholder-input` | human (B); deferred by D19 | **Deferred by D19** (applied.json, reconcile; AC16, AC24 deferred). Reason: a record writer, a union-before-divert order and damaged-record handling are more than two keyboards need; uninstall resets the known presets' ids as v0.3 did and states the limit (row 73, AC65). Slugs stay permanent (a release rule, not a file). |
| 16 | Migration beyond marked blocks (M7) | `inferable` | architect; reduced by D19 | **Reduced by D19.** Kept: remove `pop-icon-keys` marked blocks and the old helper with consent, warn about the old plugin (AC8). Deferred: detecting v0.3 rules Solaar rewrote without markers (AC17); the "your own rules" warning (AC14, AC26) still shows them and the README upgrade note says to delete them by hand. Alternative "full legacy table" ruled out as a large frozen table for a plugin only the owner installed (row 18). |
| 17 | Contributor gate: schema, `verified`, one fixture, CI (M8) | `inferable` | architect; reduced by D19 | `tested` is derived from `verified`; one recorded fixture plus derived variants; CI runs the tests (AC18 to AC20). **Deferred by D19:** strict nested schema, the permanent-slug list, the key-table snapshot cross-check, PR template and CODEOWNERS (single maintainer; the README says what a PR must contain). |
| 18 | Deprecation release for the v0.3 id | `inferable` | owner (answer to architect Q1) | v0.3 was never submitted to the marketplace; only the owner installed it from a local path. No deprecation release (ADR 0006). |
| 19 | Modifier conditions, gestures, per-OS-mode variants, release events | `inferable` | architect | Non-goals; reasons in ADR 0005. |
| 20 | Setup-time cid-name warning; keycap labels vs Fn-swap; release batching | `inferable` | architect ("later") | Not built now; README notes only (AC9). |
| 21 | Completeness sweep (entities: preset, rule block, Lua block, helper, fixture, battery file) | `inferable` | inference | Create/update/delete covered by setup (AC8, AC21, AC66), uninstall (AC8, AC34, AC65) and status (AC12); no auth, network or audit surface (local files, consent-gated). Error handling: damaged markers abort with no change (v0.3 constraint, kept). |
| 22 | Restore skips an ambiguous selector rather than working around it; addresses the keyboard by the matched block's exact name | `inferable` | plan review (design) | AC7 kept as written: a wrong device is worse than a skipped restore. Owner may override. |
| 23 | Uninstall resets the control ids of the known presets and the plan lists them | `inferable` | plan review (UX); simplified by D19 | Matches v0.3; the alternative (leave keys diverted with no rule) is worse. There is no record to read (row 15), so the ids come from the presets of the known keyboards; limit stated in the plan. AC26, AC65. |
| 24 | Unmarked v0.3 rules | `inferable` | plan review (UX); deferred by D19 | **Deferred by D19** (AC17): no deletion machinery; the "your own rules" warning lists them. |
| 25 | One y/N for all keyboards; untested keyboards marked loudly; no per-keyboard option | `inferable` | plan review (UX) | A per-keyboard flag is more surface than two keyboards need; README says so. Owner may override. AC26. |
| 26 | CI stays stdlib-only | `inferable` | plan review (acceptance); simplified by D19 | CI cannot install Solaar, so Solaar-dependent checks (rules evaluated by Solaar's own code, the optional key-table check) run on the dev machine with `LK_REQUIRE_SOLAAR=1` and are skipped in CI. The pinned key-table snapshot is **deferred by D19**. AC18. |
| 27 | Applied record written as the union before the diversion | `inferable` | plan review (design); deferred by D19 | **Deferred by D19** with the record (AC24). |
| 28 | User words for states live in the widget; the JSON carries states only | `inferable` | plan review (UX, strategic) | Smallest change that satisfies the review. CODEOWNERS and the scaffold helper are not built (D19). AC25, AC20, AC9. |
| 29 | Branch and PR workflow; release = `/pr`, auto-merge, then tag `main` (D8) | `requires-stakeholder-input` | human (B) | Process row, no AC. Owner: "we can create a branch from what we have"; auto-merge "automatic". Owner-side prerequisites, not done: allow auto-merge in the repo settings; protect `main` with the CI check as required; owner approval at PR time. Recorded in `.claude/CLAUDE.md`. |
| 30 | MX Keys for Mac device data verified from hardware (D4 update) | `requires-stakeholder-input` | human (owner, 2026-11-19) | The owner connected the keyboard and a read-only `solaar show` was recorded: model id `B36140920000`, name "MX Keys for Mac", codename "MX Keys Mac", transport ids btleid `B361` and wpid `4092`, via the Unifying receiver, Set OS MacOS, Swap Fx function True, battery feature `BATTERY STATUS {1000}`. Mapped keys are all `persistently_divertable, divertable`: 225 "Dashboard Launchpad/Action Center", 191 "Screen Capture/Print Screen", 111 "Screen Lock", 10 "Calculator"; 224 Mission Control/Task View and 13 Eject stay undiverted. Names verified against Solaar's `special_keys.CONTROL`. The owner supplied the masked recording; the build copies it to `tests/fixtures/mx-keys-mac/show.txt` (the unmasked `raw.txt` is never copied). Key presses are untested, so `verified` stays absent; the profile carries a `note` field instead. AC3, AC29. |
| 31 | Route all dev work through `dev-team:orchestrator` (D9) | `requires-stakeholder-input` | human (B) | Process row, no AC. Owner: "always invoke through orchestrator". Recorded in `.claude/CLAUDE.md`. |
| 32 | Keyboards run in MacOS OS mode, not Linux (D10) | `requires-stakeholder-input` | human (owner, 2026-11-19) | Owner screenshot; verified `Set OS: MacOS` on both keyboards. Every "Linux OS mode" claim in specs, ADR 0002 and `CLAUDE.md` was wrong and is fixed; POP `verified.osMode` is "MacOS". The README requirement (users set Set OS = MacOS in Solaar; behaviour otherwise untested) is AC27. A read-only setup check that warns and never changes the mode is AC28 (inferable: the plugin never changes a hardware setting the user owns; blocking is ruled out because other modes are untested, not known bad). |
| 33 | F8 / Screen Capture = region screenshot, overriding the macOS column (D12) | `requires-stakeholder-input` | human (B) | Owner chose "Region (keep current)" (POP spec row 1). The MX Screen Capture/Print Screen key follows (AC3). |
| 34 | Accurate battery: use the keyboard's own battery notifications (D11) | `requires-stakeholder-input` | human (B, 2026-11-19) | Owner chose battery from Solaar's own reports ("Read Solaar's own log"). The log gets no DEBUG lines (`solaar/gtk.py` sets INFO/WARNING for the temp log), so it is implemented with Solaar rules on battery notifications. ADR 0007, AC30–AC34. Inferable details (alternative ruled out by the Solaar source in ADR 0007): 10 % buckets, helper writes a state file, "Full?" instead of a confident 100 %. Known limit (superseded by row 56): the first design ignored a report older than the keyboard's last connect; D18 replaced that rule. |
| 35 | Swappable backend now: Solaar or OpenLogi (D13) | `requires-stakeholder-input` | human (B); **Deferred by D19** | Owner chose "Swappable backend now" earlier the same day (D13: "use swappble dependency either solaar or openlogi"); superseded by D19 (row 67). ADR 0008 -> Deferred. AC35 to AC44, AC46 to AC48 deferred. |
| 36 | Install OpenLogi (D14) | `requires-stakeholder-input` | human (B); moot after D19 | Install note only (AUR `openlogi`, owner runs the sudo steps); no longer needed by the plugin. |
| 37 | D15 (was Q1): `systemctl --user disable --now openlogi-agent.service` on a switch to Solaar, with consent | `requires-stakeholder-input` | human (owner, 2026-11-19); moot after D19 | Owner answered yes, with consent. **Deferred by D19:** no switching, so the path is not built. |
| 38 | D17 (was Q2): ship OpenLogi read-only; how to read battery? | `requires-stakeholder-input` | human (owner, 2026-11-19); partly kept | Owner: "or we can refer how they read battery and reproduce on ours"; confirmed "yes, that is what I meant". Kept: the battery design of ADR 0007 (capture the broadcast, query only as fallback, never persist a query). **Deferred by D19:** the read-only OpenLogi backend. |
| 39 | D16 (was Q3): never change OpenLogi `keep_os_layout` | `requires-stakeholder-input` | human (owner, 2026-11-19); moot after D19 | Owner: not in v0.4.0, warn and document only. No OpenLogi code now. |
| 40 | LogiOps (`logid`) as a third backend | `requires-stakeholder-input` | orchestrator on the feasibility report; owner may override | Considered and **deferred**, not built: no battery feature, `Keypress`-only actions (it would need a keysym plus a Hyprland bind indirection), a root-owned `/etc/logid.cfg` and a system service that need `sudo` (conflicts with the consent and no-sudo baseline), last release 2024-09. The backend interface stays open to a future keypress-indirection backend. `.dev-team-reports/logiops-feasibility-2026-11-19.md`; ADR 0008, Considered options. |
| 41 | OpenLogi experimental and read-only in v0.4.0; the writer (chord bridge) designed not built | `inferable` | architect; **Deferred by D19** | Whole OpenLogi backend deferred: OpenLogi cannot remap keyboard keys on Linux (ADR 0008). |
| 42 | One active backend per machine; both running is refused | `inferable` | `INSTALL-linux.md`; **Deferred by D19** | Moot without a backend seam. |
| 43 | The profile field stays named `battery {feature}` | `inferable` | orchestrator | One name in the spec, ADR 0005, 0007 and the plan. Kept. |
| 44 | `osMode` is a required top-level field and AC28 checks every preset | `inferable` | architect (defect fix) | The POP file said `Linux` (wrong, D10) and the field sat inside `verified`. Kept. AC28, AC45. |
| 45 | OpenLogi identity by exact device name only | `inferable` | architect / live check; **Deferred by D19** | Deferred with the OpenLogi backend; reasoning kept in ADR 0008. |
| 46 | `liveKeyState` false means no `dropped`, no restore | `inferable` | architect / live check; **Deferred by D19** | Deferred with the OpenLogi backend; reasoning kept in ADR 0008. |
| 47 | OpenLogi read side uses `openlogi api` only | `inferable` | architect / live check; **Deferred by D19** | Deferred with the OpenLogi backend; reasoning kept in ADR 0008. |
| 48 | OpenLogi writer gated on a recorded proof | `inferable` | architect / live check; **Deferred by D19** | Deferred with the OpenLogi backend; reasoning kept in ADR 0008. |
| 49 | Widget shows a stopped Solaar prominently and offers Start Solaar (AC49 to AC51) | `requires-stakeholder-input` | human (owner finding, 2026-11-19); kept by D19 | The owner found that closing Solaar's window quits Solaar on Omarchy (no tray), which kills all key routing, and asked the widget to detect `running=false` prominently and offer a Start Solaar action that starts it hidden, with no config change and no consent beyond the click, and the README to say to start it hidden. Inferable details: the flag is `solaar --window=hide` (verified from `solaar --help`, already used by setup's autostart); a status field `solaar.canStart` keeps the button decision out of the widget; auto-restore does not run while Solaar is stopped. |
| 50 | Real OpenLogi fixtures | `inferable` | live check; **Deferred by D19** | No OpenLogi fixtures. |
| 51 | Solaar's plain `solaar show` crashes on the owner's machine, so status and restore must not rely on it (AC53) | `requires-stakeholder-input` | human (owner finding, 2026-11-19) | The owner ran plain `solaar show` and it raised `UnicodeDecodeError: 'utf-8' codec can't decode byte 0xe2 in position 13` in `logitech_receiver/hidpp20.py:2078` `get_host_names` (called from `solaar/cli/show.py:326`) while printing the MX Master 4, after the POP Icon Keys and before the Unifying receiver; exit non-zero. `solaar show "POP Icon Keys"` and `solaar show "MX Keys for Mac"` work. Alternatives: keep one `solaar show all` and tolerate partial output (rejected: the MX Keys for Mac, the very device we need, is printed after the crash); patch or wrap Solaar (rejected: not ours, and not on other machines). Decision: one `solaar show "<selector>"` per preset keyboard. ADR 0005. |
| 52 | Per-device selectors still match by substring, so each block's identity is verified and a mismatching block is not-this-device and makes the selector ambiguous (AC53) | `inferable` | ADR 0005 identity rule, Solaar behaviour | The plausible alternative "trust the exact selector" is ruled out by the recorded Solaar fact (a selector matches any device whose name contains it). The selector list is the profile `names` plus saved entries matched by model id, so a keyboard whose printed name differs is still queried. |
| 53 | Truncated, crashed or timed-out output is `unknown`, a fifth key state with a `readProblem`; not disconnected, not set up, not counted toward the warning, never restored (AC54, AC55) | `requires-stakeholder-input` | human (owner finding, same instruction, 2026-11-19) | Decided in the instruction that recorded the owner's finding (summarised, the quote is not stored verbatim): devices not yet printed are "unknown", never disconnected or not set up, and the widget shows it. Inferable details: only a keyboard known to Solaar (a saved entry) is shown as unknown (the plugin cannot claim a keyboard exists on a failed call); a device block is complete when the next header follows it or the call exited 0; `no device found matching` is a clean "not present". The alternative of reusing `absent` is ruled out: it means "the keyboard does not report this cid", a profile fact. |
| 54 | Synthetic truncation fixture built in the test from the recorded POP fixture and the traceback text (AC56) | `inferable` | test-fixtures rule: one recorded fixture per profile | Recording the crash is not possible per profile (it depends on another device on the machine); the synthetic fixture is labelled and never counts as verification (AC19). |
| 55 | README known-issues note on the Solaar host-name bug (AC57) | `inferable` | owner instruction | Documentation of a known upstream bug and the workaround; no behaviour choice. |
| 56 | D18: which battery figure wins when the keyboard's last report is older than its last connect or a query disagrees? | `requires-stakeholder-input` | human (owner, 2026-11-19) | Owner chose "Keep last report (Recommended)" over ignoring reports older than the last connect. Rule: the latest report is shown with its age across reconnects and Solaar restarts until a newer report arrives or a direct query returns a **lower** value (then the query value, source `query`); a query equal to or higher never replaces it. **Stated risk the owner accepted:** after new batteries the widget shows the old low value until the keyboard reports again; the README says a new report arrives soon after fitting batteries and Restore/Refresh does not force one. Replaces the "ignore reports older than last connect" rule, so `connected_at` is no longer an input. One function `choose_battery(report, query)` holds the rule. ADR 0007, AC32, AC33. Kept by D19. |
| 57 | Module layout after plan review round 6 (contract, registry, split status module) | `inferable` | plan review round 6; **Deferred by D19** | Belonged to the backend seam and the applied record; the slim layout is in the Architecture Specification (AC58 kept in reduced form). |
| 58 | One writer of `applied.json` | `inferable` | plan review round 6; **Deferred by D19** | Belonged to the backend seam and the applied record; the slim layout is in the Architecture Specification (AC58 kept in reduced form). |
| 59 | Typed plan steps, pure `switch_steps`, `<b>_resolve` | `inferable` | plan review round 6; **Deferred by D19** | Belonged to the backend seam and the applied record; the slim layout is in the Architecture Specification (AC58 kept in reduced form). |
| 60 | Stopped Solaar: the status still lists preset keyboards read per device; keys that look lost read "Not active (Solaar stopped)"; manual Restore hidden (AC49, AC61) | `inferable` | plan review (acceptance, UX U-3); Solaar behaviour (per-device `show` works without the daemon) | Making AC49 reachable and not telling the user keys are "Lost" when the cause is that Solaar is stopped. Kept by D19. |
| 61 | `--backend` does not override the both-running refusal | `inferable` | plan review (acceptance); **Deferred by D19** | No backends. |
| 62 | A v0.3 leftover under an OpenLogi record is only warned about | `inferable` | plan review (design); **Deferred by D19** | No OpenLogi. |
| 63 | Hostile saved-entry names (leading `-`, a double quote, a newline) are skipped as selectors (AC63) | `inferable` | plan review (acceptance) | Skipping is smaller and safer than passing `--` or quoting; the keyboard is then still found by its profile names. |
| 64 | Widget and plan copy changes of the UX review (AC61, AC62) | `inferable` | plan review (UX U-1 to U-7); kept by D19 | Honesty about what was checked (never "OK" for an unread keyboard), a way out of the unknown dead end, plain words instead of internal codes. |
| 65 | Release preconditions (AC64) | `inferable` | plan review (strategic); reduced by D19 | Live check 1 (battery) gates the tag, not the merge. The switching descope order is gone with switching. The owner may override. |
| 66 | OpenLogi "routed = configured and the agent running" meaning deferred | `inferable` | plan review (acceptance); **Deferred by D19** | No OpenLogi. |
| 67 | **D19: slim v0.4.0 scope.** Slim and keep the battery, or slim and drop it, or the full plan? | `requires-stakeholder-input` | human (owner, 2026-11-19), after seeing that Solaar's own GUI covers diversion dropdowns and a rule editor with Execute actions | The owner chose **"Slim, keep battery"** over "Slim, drop battery" and "Full plan". Kept: rename, presets for POP (tested) and MX (untested key presses), exact identity with the MX codename, always `Device`, setup and uninstall with consent, the POP Lock binding, Solaar autostart, a simple v0.3 cleanup, restore of dropped keys, Start Solaar and Open Solaar, accurate battery (ADR 0007, D18), per-device queries and `unknown`, a small widget, a short README with "Add your keyboard", CI. **Deferred by D19 (not deleted ideas):** swappable backend, OpenLogi backend and switching (ADR 0008 -> Deferred; OpenLogi cannot remap keyboard keys on Linux; revisit; the D15/Q1 `disable --now` path is not built; the architect design file is kept as reference); strict preset schema beyond basic validation; the action table (M3; accepted risk in row 13); `applied.json` and reconcile (M6); legacy-rule migration machinery (M7); CODEOWNERS and PR template; a Solaar key-table cross-check in CI (optional local check only); the per-key widget UI; `unsupportedByBackend`, `otherRunning`, `liveKeyState`; LogiOps (row 40). ADR 0009. Deferred acceptance criteria are marked "Deferred (D19)" in place. |
| 68 | Terminology: the owner's word "presets" = the profile files; the directory stays `profiles/<slug>.json` | `requires-stakeholder-input` | human (owner, with D19) | The owner says "presets"; partly built work lives in `profiles/`, so the directory and the reader module keep the name `profiles`. User-facing text says "preset" or "keyboard". Glossary. |
| 69 | Commands live in the preset (no action table): the accepted risk | `requires-stakeholder-input` | human (owner, D19) | See row 13. Alternative "keep the action table" was the architect's M3; the owner chose the slim plan. The README and ADR 0005 state that a preset PR can put a command Solaar runs on a key press, mitigated only by maintainer review. |
| 70 | The MX preset lists both "MX Keys for Mac" and "MX Keys Mac" in `names` | `inferable` | recorded hardware facts (rows 30, 51); owner instruction | `solaar show` prints "MX Keys for Mac" online but Solaar saves the codename "MX Keys Mac" as `_NAME` in `config.yaml` while the keyboard is offline; a list with only the long name would miss the offline entry and a substring match would hit "MX Keys Mini". AC68. |
| 71 | Daemon detection must accept `solaar -dd --window=hide` | `inferable` | owner instruction (the owner runs Solaar with debug flags) | The filter excludes only CLI subcommands, never options; the v0.3 code already skips unknown options, so the change is a pinned test. AC67. |
| 72 | Open Solaar button | `requires-stakeholder-input` | human (owner, with D19) | Buttons: Restore, Start Solaar, Re-apply setup, Open Solaar. Command `solaar --window=show`; activation of a hidden instance is unverified (live check). AC69. |
| 73 | Uninstall resets the control ids of the known presets; limit stated | `inferable` | D19 (row 15) | As in v0.3: the ids come from the presets of the known keyboards; a user's own diverted key on the same id is reset too and the plan lists the ids. Alternative "do not reset" leaves keys diverted with no rule. AC65. |
| 74 | Battery helper is self-contained; slug is a safe-name regex, not a preset lookup | `inferable` | ADR 0007; marketplace baseline (no /home paths, no plugin-path coupling) | The copy installed in `~/.local/bin` must run without the plugin folder; a slug of lowercase letters, digits and single hyphens cannot traverse paths. Alternative "look the slug up in the presets" ruled out: the installed copy cannot import the reader. AC31. |
| 75 | One state per keyboard in the widget, including `mismatch` when every key is absent | `inferable` | plan UX lessons kept from the round-6 review | "OK" with nothing routed would be false; the alternative of dropping `mismatch` was ruled out for honesty (AC61). Precedence: unknown, needsSetup, stopped, dropped, mismatch, ok. |
| 76 | Per-key widget details, an `otherRunning` warning and per-key states in the popup | `inferable` | D19 | Deferred with the full widget; the JSON still carries per-key states for tests and the command line. |

## Consistency Gate

- [x] Intent is unambiguous
- [x] Every behavior/goal maps to an acceptance criterion
- [x] Architecture constrains without over-engineering
- [x] Terminology consistent across artifacts
- [x] No contradictions between artifacts
- [x] Every gap/ambiguity finding is logged: inferable with rationale or resolved by human

**Verdict: PASS** (re-run 2026-11-19 after owner decision D19, the slim re-scope).
What changed in this pass: Intent rewritten for the slim scope (eight items); the
Architecture Specification slimmed (presets with `command` argument lists, no action
table, no applied record, no backend seam, one `lib/status.py`, `lib/edit.py` kept);
AC1 to AC15, AC18 to AC22, AC25 to AC34, AC45, AC49 to AC58, AC61 to AC64 amended;
AC16, AC17 (largely), AC24, AC35 to AC44, AC46 to AC48, AC59 and AC60 marked
"Deferred (D19)" in place, numbering unchanged; AC65 to AC69 added (uninstall reset,
setup order and restart guarantee, `-dd` daemon detection, MX codename, Open Solaar);
glossary trimmed (Preset/profile mapping added); rows 67 to 76 added (D19 and its
inferable details) and rows 13, 15 to 17, 21, 23 to 28, 35 to 50, 57 to 62, 65 and 66
annotated or collapsed. Mechanical checks of this pass: every AC id AC1 to AC69 (AC3a
stands where the plan says AC23) appears once as a criterion entry; the deferred criteria are exactly AC16, AC24,
AC35 to AC44, AC46 to AC48, AC59, AC60 (AC17 is partly kept); every ADR and every row
cited exists (ADR 0005 to 0009; rows 1 to 76); no live text outside a "Deferred (D19)"
context describes `lib/actions.json`, `applied.json`, a backend seam or OpenLogi.
**Open stakeholder questions: none.** D1 to D19 are recorded; rows 13, 22 to 28 and
65 remain overridable by the owner. Owner-only live checks are listed in the plan.
