# 8. Swappable input backend: Solaar or OpenLogi

Date: 2026-11-19

## Status

Accepted. The owner chose "Swappable backend now" (decision D13: "use swappble
dependency either solaar or openlogi"); the design is the architect's
(`.dev-team-reports/architect-backend-design-2026-11-19.md`, not committed).
Depends on [ADR 0005](0005-device-profiles-for-other-keyboards.md) (profiles)
and [ADR 0007](0007-battery-from-keyboard-notifications.md) (battery). In
**v0.4.0 the OpenLogi backend is experimental and read-only**: it detects the
agent, matches keyboards by exact name and shows battery and backend status, and
reports every key as `unsupportedByBackend`. Its configuration is never written.
The OpenLogi key-mapping writer is designed here but built later (see "Deferred
slice S10").

The owner answered the three open questions on 2026-11-19 (decisions D15 to D17,
below); there are no open questions. Amended the same day with the facts read
from the owner's live OpenLogi 0.9.0 install (agent installed, disabled, not
running, never started by this work) and from the OpenLogi source. Amended again the same day for the owner's finding
that plain `solaar show` crashes on this machine ("The Solaar backend queries one
device at a time", below).

## Context

Until now the plugin was Solaar-only. Owner decision D13 asks for a choice of
backend, Solaar or OpenLogi (AprilNEA/OpenLogi, Rust, a systemd user agent
`openlogi-agent.service`). Facts, from the OpenLogi documentation snapshot in
`.dev-team-reports/openlogi-docs/` (GitHub master `9ca7ef0cbd1f4577ffdc338f8288f8c3a410f013`, latest release v0.9.0,
2026-11-03; SHA in `SOURCE.txt`):

- **One program owns a receiver.** `INSTALL-linux.md`: "Quit Solaar ... the two
  applications fight over HID++ access". Backends are exclusive per machine, not
  mixable per keyboard on one receiver.
- OpenLogi describes itself as not yet stable ("features and config may still
  change", `README.md`). Its platform table marks "Keyboard F-key remapping" as
  not available on Linux (`README.md`, line 164).
- It has a documented JSON interface (`openlogi api devices`, `api status`,
  `USAGE.md`) with a schema-versioned envelope, and a strict TOML config
  (`CONFIGURATION.md`, `schema_version` 11, a bad field stops the whole file from
  loading).
- It installs from the AUR (builds from source) or a `curl | sh` installer, with
  `sudo` for udev rules (`INSTALL-linux.md`). The marketplace baseline forbids
  the plugin doing either.

Live facts, read-only, 2026-11-19, OpenLogi 0.9.0 on the owner's machine (agent
`openlogi-agent.service` installed but disabled and not running; recordings in
`.dev-team-reports/openlogi-live/`):

- `openlogi list` without the agent reads the hardware directly, works while
  Solaar runs (read-only), and prints both receivers, slots, kind, wpid,
  `model_ids` (POP `[b38f,0000,0000]`, MX Keys for Mac `[b361,4092,0000]`),
  transports and battery. It has **no JSON form** (`openlogi list --help` shows
  only `-h`); its output is a text table. It also shows the **stale 100 %** for
  the POP, so it is no better than Solaar's query (ADR 0007).
- `openlogi api` needs the agent (it has no hardware fallback). Its subcommands
  are `status`, `devices`, `dpi`, `smartshift`, `fn-lock`, `os-layout`,
  `report-rate` and `easy-switch`. There is **no key-binding or button-remap
  subcommand**: bindings live only in the TOML config.
- `openlogi fixture record|verify|contribute` records and validates
  privacy-safe device fixtures (`record case` is a strict HID cassette of one
  named read, `record profile` captures semantic state through the running
  agent, `verify` checks a fixture directory).
- OpenLogi reads the battery the way Solaar does (source, master:
  `crates/openlogi-hidpp/src/feature/unified_battery.rs`): HID++ UnifiedBattery
  `0x1004`, `getStatus` (function 1) and status event 0, with the same byte layout
  as Solaar. Its agent re-reads the battery on every inventory poll
  (`crates/openlogi-device/src/inventory/cache.rs`), never restores a saved
  reading (`persist.rs`: it "would resurrect a stale value") and handles the
  battery broadcast (`inventory/replay_tests.rs`, `battery_broadcast_refresh`).
  There is no special battery command. This is the prior art for ADR 0007.

Solaar fact found by the owner, 2026-11-19 (Solaar 1.1.20): plain `solaar show`
(all devices) **crashes** on the owner's machine partway through. After printing
the POP Icon Keys block it raises `UnicodeDecodeError: 'utf-8' codec can't decode
byte 0xe2 in position 13` in `logitech_receiver/hidpp20.py:2078`, `get_host_names`
(called from `solaar/cli/show.py:326`) while printing the MX Master 4: Solaar
decodes the host-name chunks of 14 bytes separately, so a multibyte character
split across two chunks fails. The output stops before the Unifying receiver, so
the MX Keys for Mac never appears, and the exit status is non-zero.
`solaar show "POP Icon Keys"` and `solaar show "MX Keys for Mac"` each work. A
selector that matches no device exits 1 with `no device found matching '<name>'`.
Any device on the machine, profiled or not, can therefore break a whole-machine
`solaar show`, so the plugin must not depend on it.

The Solaar behaviour of ADR 0005 and 0007 (rules, `config.yaml` diversion, the
`Device` condition, the battery notification rules) is correct but is one
backend's implementation, and must stop leaking into profiles, status, the
widget and setup's flow.

## Decision

v0.4.0 puts a **backend seam** between profiles and the daemon that owns the
receiver. **One active backend per machine**, recorded in
`applied.json`. Each backend is a pair: `lib/backends/<name>.py` (all data
work) and `lib/backends/<name>.sh` (process lifecycle only).
**Solaar is the reference backend**: tested, the default, and it keeps every
behaviour of ADR 0005 and 0007. **OpenLogi is read-only and experimental**
in v0.4.0.

### Split rule and interface

- **Bash** owns process lifecycle (installed, running, stop, start,
  restart-on-exit) and the consent prompt. Bash never learns a file format.
- **Python** owns reading, parsing, identity, planning and file edits.
  `lib/edit.py` stays the only command line, with new verbs
  `plan|apply|remove|status|restore --backend <name>`. A shared executor in
  `lib/fileedit.py` writes every `FileEdit` (atomic, backup on change, dry-run
  diffs, marker checks, once for all backends).
- **Layout:** `lib/backends/__init__.py` (the contract: key states, battery
  shape, `Plan` and `FileEdit`, and `REGISTRY = {"solaar": ..., "openlogi":
  ...}`); `lib/backends/solaar.py` (a thin adapter over the existing identity,
  status, rules, diversion and battery modules; no logic moves);
  `lib/backends/solaar.sh` (sources `lib/solaar-procs.sh`; stop, start and restart
  move here from `lib.sh`); `lib/backends/openlogi.py` (read side);
  `lib/backends/openlogi.sh` (`systemctl --user` lifecycle).
- **Python contract**, per backend module: constants `NAME`, `LABEL`,
  `EXPERIMENTAL`, `LIVE_KEY_STATE` (Solaar: `EXPERIMENTAL` false,
  `LIVE_KEY_STATE` true; OpenLogi: `EXPERIMENTAL` true, `LIVE_KEY_STATE` false;
  `LIVE_KEY_STATE` says whether the backend can read which keys are diverted
  right now); `collect(run, paths, profiles)` (the only I/O; `run(argv, timeout)` is
  injected; the read-only argv allow-list is `solaar show "<selector>"`, one call
  per profiled device with an exact selector (see "The Solaar backend queries one
  device at a time"), never `solaar show all`, plus reading `config.yaml` and the
  battery state files for Solaar, and `openlogi api status`
  and `openlogi api devices` for OpenLogi); `probe(raw)` returning
  `{version, usable, problem}` with `problem` one of `agentUnavailable`,
  `versionMismatch`, `inventoryNotReady`, `unknownSchema` or null;
  `known(raw, profiles)` (Solaar: saved entries; OpenLogi: inventory devices
  whose name **exactly** equals a profile name; duplicates are marked
  ambiguous); `keyboards(raw, profiles, applied, now)` (status sections);
  `restore(sections)` (an argv list; never writes config; Solaar
  `solaar config <exact matched name> divert-keys <key> Diverted`, skipped when
  ambiguous; OpenLogi returns `[]`); `plan_apply(...)` and `plan_remove(...)`
  returning a `Plan` (`edits`, per-key outcomes `mapped` or `unsupported` with a
  reason, `daemonMustBeStopped`, `artifacts`).
- **Bash contract**, namespaced `<b>_installed`, `<b>_running`, `<b>_stop`,
  `<b>_start`, `<b>_restart_if_stopped`. Solaar: `command -v solaar`, the
  existing `solaar_daemon_pids`, the existing stop, start and restart. OpenLogi:
  installed is `command -v openlogi` and `systemctl --user cat
  openlogi-agent.service`; running is `systemctl --user is-active --quiet
  openlogi-agent.service`, else `pgrep -u $UID -x openlogi-agent`; stop and start
  are `systemctl --user stop|start`; it restarts only what it stopped. Both honour
  `--dry-run` and are called only after consent.

### Status contract

(Owned by slice S2; v0.4.0 is unreleased, so this goes into schema 1.)

```
{"schema": 1,
 "backend": {"name", "experimental", "installed", "running", "usable",
             "problem", "liveKeyState", "otherRunning", "canStart"},
 "keyboards": [{"slug", "name", "tested", "connected", "identity",
                "battery": {"value", "level", "source", "at"},
                "keys": [{"cid", "label", "state", "reason"?}], "bindings"}]}
```

- Key states (camelCase): `routed`, `dropped`, `notSetUp`, `absent`,
  `unsupportedByBackend`, `unknown`. **`absent`** is a profile fact (the keyboard
  does not report the cid). **`unsupportedByBackend`** is a backend fact (the
  active backend cannot route the cid; `reason` is `notImplemented` or
  `unverified`). **`unknown`** is a read fact: the backend could not read this
  keyboard completely (see "The Solaar backend queries one device at a time");
  the keyboard section then carries `readProblem` (`solaarCrashed`, `timeout` or
  `noOutput`, otherwise null). All three are dimmed and none counts toward the
  warning; `unknown` is never restored.
- When `liveKeyState` is false, `dropped` is never emitted, `routed` means
  "configured and the agent is running", and the widget offers no restore.
- Battery `source` is `report`, `query` or `backend` (the daemon's cached value
  read at `at`); `level` may be null.
- `otherRunning` names the other backend when its daemon also runs; the widget
  warns that both own the receiver.
- `canStart` is true only when the backend is installed, not running and has a
  start that needs no consent: Solaar, started hidden (see "Widget: the backend
  is not running" below). It is always false for OpenLogi: the plugin never
  starts or stops OpenLogi's agent outside a consented switch.
- Kept from ADR 0005 and 0007: Solaar identity by model id then exact name;
  OpenLogi by exact name only (its API exposes no documented model id; see
  "OpenLogi: the read side" for `openlogi list`); exact parsing in
  Python; action ids only (no profile string reaches YAML, TOML or Lua); every
  Solaar rule, battery rules included, has the `Device` `Or`; the `absent`
  meaning; legacy v0.3 migration stays inside the Solaar adapter.

### The Solaar backend queries one device at a time

Decision (owner finding, 2026-11-19, see the Solaar fact in Context): the Solaar
backend **never runs `solaar show all`** and never relies on one whole-machine
call.

- **Selectors.** `collect` runs `solaar show "<selector>"` once per selector, with
  the 20 second timeout, where the selectors are each profile's exact `names`
  and the names of the saved `config.yaml` entries that `known` matches to a
  profile by model id (so a keyboard whose printed name differs from the profile
  still has a selector). No other argv is allowed. The selector list is the
  allow-list; it comes from data, not from bash.
- **Each returned block is parsed on its own.** A selector still matches by name
  **substring**, so one call can return more than one device block. The status
  code verifies each block's `Model ID:` line (or, when that is all zero, its
  exact name) with the one identity module and treats a block whose identity does
  not match the profile as **not this device**. That block still counts for
  ambiguity: if a selector returns a block that is not the profiled device, the
  selector is ambiguous and restore skips it (ADR 0005, unchanged).
- **A failed or truncated call is `unknown`, never "disconnected" or "not set
  up".** A non-zero exit (a traceback), a timeout or empty output means the
  devices not yet printed were not read. A device block counts as complete when
  the next device header follows it, or the call exited 0; the block being
  printed when the call failed is incomplete. Complete blocks are kept and parsed
  normally. A profiled keyboard that is known to Solaar (a saved entry matches it)
  and was not read completely is shown with `unknown` keys and a `readProblem`; it
  is not counted toward the warning and is not restored. `no device found
  matching` (a clean "not present") lists nothing, as before. A keyboard Solaar
  has no saved entry for and whose call failed is not listed (the plugin cannot
  claim it exists).
- **Cost.** One call per selector (two keyboards, two or three calls) instead of
  one; each has its own timeout, so one hung device cannot hide the others.

### OpenLogi: what the documents settle

From `CONFIGURATION.md`, `USAGE.md` and `INSTALL-linux.md`:

- Bindings live under `[devices."<physical-key>"].bindings`; a keyboard key can
  be written `control:0x<cid>` for any control `openlogi diag controls` reports
  divertable; a bound key is diverted while the agent runs.
- `CustomShortcut` chords accept Super (KEY_LEFTMETA), Ctrl, Alt, Shift and F1 to
  F20.
- The TOML is strict: `schema_version` 11, a newer one is rejected, a bad field
  stops the whole file loading.
- `openlogi api devices` returns one JSON envelope (`schema_version` 1, `ok`,
  `inventory` of `scanning`, `ready` or `unavailable`; per device `name`,
  `online`, `battery {percentage, level, status}`), with stable error codes.
  Device `id` values are opaque routes and are never parsed.
- On Linux only `LaunchpadShow` (runs `omarchy-menu toggle`, not this plugin's
  launcher), `LockScreen`, `PreviousDesktop` and `NextDesktop` have documented
  behaviour.

### OpenLogi: the read side (decision)

`openlogi list` gives `model_ids` and works without the agent, but it prints a
text table only, and the plugin never parses a text table. **Decision: the
v0.4.0 read side uses `openlogi api status` and `openlogi api devices` only.**
Consequences: it needs the agent, and on the owner's machine (agent disabled and
not running, never started by this work) the backend reports `usable: false`,
`problem: agentUnavailable`, which is the correct, honest answer; identity stays
the exact device name. If OpenLogi adds a JSON form of `list`, or documents a
model id in `api devices`, identity by model id becomes possible, and the read
side may then use it (flagged in the unsettled list below). The device names
printed by `openlogi list` are exactly `POP Icon Keys` and `MX Keys for Mac`
(text-table evidence only; the `api devices` `name` is still unrecorded).

### OpenLogi: what the documents leave open and what the live outputs settled

Settled by the live outputs and the source:

- **Item 1 (keyboard diversion on Linux): settled as "no, per the README".** The
  platform table lists "Keyboard F-key remapping" as not available on Linux, and
  `openlogi api` has no binding subcommand, so bindings could only be written into
  the TOML. Keys therefore stay `unsupportedByBackend` and S10 is **gated on a
  recorded proof** that a `control:0x<cid>` binding diverts a dedicated key on
  the Linux build; without it S10 is not built.
- **Item 8 (battery: notification or query): settled.** The agent re-reads on
  every poll and handles the broadcast (see the live facts); a figure from
  `api devices` is a fresh read at `at`, but it can still be the stale device
  value, so it keeps source `backend` and is treated like a query (never "100 %",
  "Full?").
- **Item 10 (the text format of `openlogi list`): settled.** There is no JSON
  form; the table is never parsed.
- **Item 4 (the exact names): partly settled.** `list` prints `POP Icon Keys` and
  `MX Keys for Mac`; the `api devices` `name` is recorded only once the owner
  runs it with the agent up.

Still open (not built until recorded):

1. Whether keyboard-control diversion works on Linux at all (the platform table
   says no for "Keyboard F-key remapping").
2. The `control:0x<cid>` spelling (hex width and case) and the catalog-name to
   cid mapping (binding one control under both spellings is a load error).
3. Which `[devices."<key>"]` entry is a given keyboard (keys such as `unit:`,
   `serial:` or a route; identity and links are app-managed with no documented
   shape; no model id in the API).
4. The `api devices` `name` strings of the POP and MX keyboards (`name` may be
   null; the `list` table's names are known, see above).
5. Whether the agent reloads a hand edit without the GUI or a restart.
6. The `config.toml.lock` protocol for external editors.
7. Whether any API shows key or diversion state (none documented, hence
   `LIVE_KEY_STATE` false).
8. Whether the API battery is a notification or a query, and the full `level`
   vocabulary.
9. What `keep_os_layout` (default on) does on a Linux host: it may move
   keyboards out of MacOS OS mode on connect, which would break the profiles'
   `osMode` and the Lock chord `SUPER + CTRL + Q`; the current layout is not
   readable through the API. Decision D16: the plugin warns and documents this
   and never changes `keep_os_layout`.
10. ~~The text format of `openlogi list`~~ (settled, see above; new item: whether
    OpenLogi will ever offer a JSON `list` or a model id in `api devices`, which
    would allow identity by model id).
11. Whether `diag controls` runs while the agent runs.
12. Linux behaviour of `ShowDesktop`, `CaptureRegion` and `OpenApplication`.
13. Flatpak (no user service; detected as not installed).

### v0.4.0 degradation

For OpenLogi, `plan_apply` returns no OpenLogi edits; every key is
`unsupportedByBackend` with reason `notImplemented`; the widget shows battery,
connection and backend status only; the Hyprland bindings block (POP Lock) still
applies; restore does nothing; an envelope with `ok: false`, an unknown
`schema_version` or a CLI exit 2 gives `usable: false` with a `problem`, never a
crash. After S10, reason `unverified` applies to a cid until
`backends.openlogi.verified` lists it.

### Selection, switching, storage, uninstall

- **Storage:** the backend in effect lives in `applied.json` (no new file):
  `{"schema": 1, "version", "backend": "solaar", "switching": null, "profiles":
  [{slug, cids}], "artifacts": {"solaar": {"entries": {slug: [names]},
  "rulesBlock", "batteryRules", "autostartBlock"}, "hypr": {"bindingsBlock"},
  "openlogi": {"entries": {}, "enabledService": false, "disabledService": false}}}`
  (`disabledService` is true when setup ran `disable --now` on the OpenLogi
  service during a switch to Solaar, so the plan and uninstall can print the
  re-enable command). This changes the
  unreleased schema 1 directly (no migration). With no `applied.json`, status
  shows what it detects, for display only.
- **Selection by setup:** `--backend solaar|openlogi` given: that one (a
  difference from the recorded backend is a switch). No flag and an
  `applied.json`: the recorded one (the widget's Re-apply never switches). Only
  one installed: that one (OpenLogi is shown as "experimental, keys not
  mapped"). Both installed and exactly one running: the running one. Both
  installed and both running: **refuse**, exit 1, "two programs own the
  receiver; quit one", nothing changes. Both installed and neither running:
  Solaar, the plan saying why. Neither installed: Solaar through `omarchy pkg add
  solaar`, as today. Setup **never installs OpenLogi** (AUR build, `sudo` udev
  rules); the D14 install note stays in the README, with no `curl | sh`.
- **Consent plan additions:** the backend, the reason and an experimental
  badge; per keyboard each key as mapped, unsupported by `<backend>` (with the
  reason) or absent; every daemon action (stop, start, enable, disable; a switch
  to Solaar lists `systemctl --user disable --now openlogi-agent.service` when
  that service is enabled, because the user's OpenLogi install enabled it and it
  would retake the receiver at next login); for OpenLogi a line that its configuration is not changed (v0.4.0); a warning
  about OpenLogi's OS-layout default; the OS mode precondition warning (spec
  AC28).
- **Switching** is one consent and one plan, with a write-ahead
  `switching: {from, to}`: (1) write `applied.json` with `switching` set; (2) stop
  the old daemon; (3) the old backend's `plan_remove` (Solaar: reset the recorded
  cids in `config.yaml` while stopped, remove the rules block with its key and
  battery rules, and the Solaar autostart block); (4) the old backend's autostart that
  conflicts (decision D15): on a switch **to Solaar**, if the OpenLogi service is
  enabled, run `systemctl --user disable --now openlogi-agent.service` (the plan
  lists it; it runs only on `y`; a disabled service is not touched and not
  listed; record `disabledService: true`); (5) start the new daemon (OpenLogi: enable the service if
  not enabled and record `enabledService: true`); (6) the new backend's
  `plan_apply`; (7) write `applied.json` with the new backend and `switching:
  null`. A failure before step 5 restarts the old daemon through the `on_exit`
  trap (for OpenLogi after step 4, `systemctl --user start`; the service stays
  disabled); a re-run sees `switching` and finishes. Declining runs no
  `systemctl` call at all.
- **Uninstall** removes the artifacts of every backend recorded (a
  half-finished switch included), the Hyprland blocks, the battery state
  directory, the helpers and `applied.json`. It restarts only a daemon it
  stopped and disables only a service it enabled. It never uninstalls packages
  and never re-enables the other backend, including a service a switch disabled
  (it prints the command `systemctl --user enable --now openlogi-agent.service`).

### Schema changes (ADR 0005 amended)

- `osMode` moves to the profile's **top level**, required, out of `verified`; one
  of Solaar's multiplatform OS base names (Linux, MacOS, Windows, iOS, Android,
  WebOS, Chrome, WinEmb, Tizen; checked against Solaar 1.1.20
  `settings_templates.py`). POP and MX are `MacOS`. The shipped POP profile said
  `Linux`; that was wrong (D10) and is fixed.
- `battery` stays `{"feature": "UNIFIED BATTERY" | "BATTERY STATUS"}` (the name
  ADR 0007 and the spec already use); absent means no report rules and battery
  source `query`.
- `verified` becomes `{solaar, date, fnSwap}` (the Solaar reference; it means
  "tested").
- New optional `backends`, whose only allowed key is `openlogi`: `{names?: [exact
  OpenLogi names], verified?: {openlogi, date, keys: [cid, ...]}}`; `keys` is a
  subset of the profile's cids; a `verified` block requires a recorded,
  non-synthetic `tests/fixtures/<slug>/openlogi-devices.json`. v0.4.0 ships no
  `backends` sections.
- The contributor minimum is unchanged: one profile, one recorded `solaar show`
  fixture, a README row. Adding a backend is maintainer code (registry plus
  schema enum).

### Deferred slice S10: the OpenLogi writer (designed, not built)

**Decision Q2 (D17): v0.4.0 ships with OpenLogi read-only; S10 is v0.5.0** and
is built only if two conditions hold: the owner records fixtures from a real
install, and a recorded check shows that OpenLogi's Linux build honours
keyboard dedicated-key bindings (its README says it does not, and `openlogi api`
has no binding subcommand, so the writer would edit the TOML only). If the
check fails, the keys stay `unsupportedByBackend` and S10 is dropped. The design is a **chord
bridge**: each action in `lib/actions.json` gains a fixed `bridge` key (F13 to
F19, validated unique). For each mapped key, setup writes the OpenLogi binding
`"control:0x<cid>" = { CustomShortcut = "Super+Ctrl+Alt+F13" }` and, in this
plugin's Lua block, `o.bind("SUPER + CTRL + ALT + F13", ..., <argv from
actions.json>)`. One generic path; commands only from `actions.json`, run by
Hyprland; OpenLogi's built-in actions are avoided. The edit goes in a marked
block inside the device's bindings table; the exact key=value pairs are recorded
in `applied.json` so removal works if the GUI rewrites comments; `tomllib`
re-parses before the write; the agent is stopped and the GUI closed while
`config.toml` is written, then the agent starts and setup checks `api status` and
`api devices` for ok and ready; on failure the backup is restored (stated in the
consent plan). Fixtures: OpenLogi has its own privacy-safe fixture tool,
`openlogi fixture record case|profile`, `verify` and `contribute`; the real
OpenLogi fixtures use its directory format where it fits (checked with
`openlogi fixture verify <dir>`), and the `api` JSON envelopes the contract tests
read are stored beside them as `tests/fixtures/openlogi/*.json`. Until the owner
records them the synthetic fixtures stay, labelled `synthetic: doc-derived
USAGE.md @9ca7ef0`, and real ones replace them. Before S10 the owner records,
masked: `openlogi --version`,
`api status`, `api devices`, `~/.config/openlogi/config.toml` after the agent has
seen both keyboards, `diag controls` for POP and MX, and `systemctl --user show
openlogi-agent.service -p UnitFileState,ActiveState`.

### Widget: the backend is not running

Verified on the owner's machine: closing Solaar's window **quits** Solaar on
Omarchy (no tray), and with it every diverted key. `backend.running` (already in
the status contract) is therefore a prominent state, not a footnote: the popup
leads with a banner in words ("Solaar is not running, so these keys do nothing")
and the icon warns. When `backend.canStart` is true the banner carries a **Start
Solaar** button. It runs `bin/logitech-keys-start`, which starts Solaar hidden
(`setsid -f solaar --window=hide`; `-w, --window {show,hide,only}` read from
`solaar --help`), changes no configuration, writes nothing and needs no consent
beyond the click, and refuses when Solaar is already running or not installed.
Auto-restore never runs while the backend is not running. The README tells the
user to start Solaar hidden and not to close its window. OpenLogi never gets this
button (`canStart` false); its agent problem copy stays as before.

## Considered options

- **Solaar only (keep v0.3 scope).** Simplest and fully tested; rejected by the
  owner (D13), who wants the choice. It remains the default and the reference.
- **OpenLogi only.** Rejected: its Linux keyboard remapping is not available per its README
  (item 1), it is "not yet stable", and the POP and MX key behaviour is verified
  only under Solaar.
- **LogiOps (`logid`), considered and deferred.** From
  `.dev-team-reports/logiops-feasibility-2026-11-19.md` (snapshot
  `e15799553f97c1b8bab5d9b22b58453513b56217`, v0.3.5, 2024-09-28): no battery
  feature; actions are `Keypress` only (no run-command), so it needs a keysym plus
  a Hyprland bind indirection; its config `/etc/logid.cfg` is root-owned and
  `logid` is a system service, so it needs `sudo`, which conflicts with the
  consent and no-sudo baseline; the last release is old; the POP and MX
  keyboards are not in its tested list. The backend interface does not preclude a
  future keypress-indirection backend. It is **not built**.
- **Mixed backends per keyboard.** Rejected: one program owns the receiver, so two
  daemons for two keyboards on one receiver is not possible (and on two
  receivers adds state for little).
- **A directory plugin contract (backends as drop-in files).** Rejected for now:
  adding a backend is maintainer code (registry plus schema enum).

## Consequences

- Solaar behaviour is unchanged, but its code sits behind an adapter; the
  battery helper, state file and status JSON are backend-neutral, and the
  generated rules are a Solaar implementation detail (ADR 0007 amended).
- OpenLogi users get detection, battery and status in v0.4.0 and no key mapping;
  the widget says so ("experimental, keys not mapped"). Contract tests over a
  docs-only backend could give false confidence; the OpenLogi fixtures are
  labelled `synthetic: doc-derived USAGE.md @9ca7ef0` and the backend carries an
  experimental badge.
- Three new slices (S7 seam and OpenLogi read side, S8 battery, S9 selection and
  switching) add work before submission.
- A switch touches two daemons; the write-ahead record and the `on_exit` restart
  keep an interrupted switch from leaving neither daemon running. Setup refuses
  to act when both run.
- Risks: OpenLogi's OS-layout default may change the keyboards when the owner
  installs it; a TOML writer built on guessed rules could break the whole
  OpenLogi config (hence deferred, with rollback designed in).
- Closing Solaar's window quits Solaar on Omarchy (there is no tray), which
  kills all key routing; the widget shows this prominently and offers a start
  action (next section).
- Live checks only the owner can run: the battery rules writing the state file
  on a real notification (POP, MX over Unifying); MX key presses under Solaar;
  with Solaar quit by hand, `openlogi api devices` names and battery (with the
  agent up) and whether the keyboards leave MacOS mode when the agent connects;
  the Start Solaar action on a real quit Solaar; in a scratch config one
  `control:0x<cid>` binding (does it divert on Linux, and does Hyprland receive
  the uinput F13 chord); hand-edit reload without a restart; a real switch round
  trip with checksums.

## Non-goals

Mixing backends per keyboard; installing OpenLogi from setup; an OpenLogi
native-action table; changing `keep_os_layout` automatically; Flatpak; a backend
picker in the widget settings; a third backend (LogiOps) or a directory plugin
contract.

## Owner decisions (2026-11-19)

All three former open questions are answered; none remain.

- **D15 (Q1), yes, with consent.** Owner answer: yes, with consent. During an
  explicit switch to Solaar, setup lists `systemctl --user disable --now
  openlogi-agent.service` in the consent plan and runs it **only on y**, because
  the user's OpenLogi install enabled the service and it would retake the
  receiver at next login. The path is built and sandbox-tested with a `systemctl`
  stub that logs calls; it never runs on the real machine. Uninstall still never
  re-enables the service (it prints the command). It is the one place the plugin
  disables a service it did not enable.
- **D16 (Q3), not in v0.4.0.** Under OpenLogi, setup does not write
  `keep_os_layout=off` (`openlogi api os-layout --set off --save`): it warns and
  the README documents it. `keep_os_layout` is never changed by the plugin.
- **D17 (Q2), read-only now, writer later.** The owner's words: "or we can refer
  how they read battery and reproduce on ours"; asked whether that meant
  reproducing OpenLogi's battery method through ADR 0007 with the OpenLogi backend
  read-only and experimental in v0.4.0 and fully supported in v0.5.0, the owner
  confirmed: "yes, that's what I meant". Checked in OpenLogi's source
  (master): it uses the same HID++ UnifiedBattery `0x1004` `getStatus` and status
  event 0 with the same byte layout as Solaar, re-reads on every poll, never
  restores a saved reading and handles the battery broadcast; there is no special
  command, and `openlogi list` shows the same stale 100 % for the POP. So
  "reproduce on ours" is [ADR 0007](0007-battery-from-keyboard-notifications.md)
  as designed (Solaar-rule capture of the broadcast, the query as fallback, a
  query value never persisted as truth). v0.4.0 ships the OpenLogi backend
  read-only and experimental; the release decision (ship read-only or wait for
  S10) is answered: **ship read-only**, S10 in v0.5.0.

## Unsettled, for the next architect pass

- Whether OpenLogi's Linux build diverts dedicated keyboard keys at all (S10
  gate); the `control:0x<cid>` spelling; which `[devices."<key>"]` entry is which
  keyboard; reload and `config.toml.lock` protocol; `diag controls` while the
  agent runs; `ShowDesktop`, `CaptureRegion` and `OpenApplication` on Linux.
- Identity by model id for OpenLogi: possible only if `openlogi list` gains a
  JSON form or `api devices` exposes a model id (neither is the case in 0.9.0);
  exact name only until then.
- The `api devices` `name` strings and battery `level` vocabulary (recorded once
  the owner runs the command with the agent up).
- The real fixture format: whether `openlogi fixture record profile` output can
  feed the contract tests directly or only through an adapter.
