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

The owner's answers to the three open questions below (Q1 to Q3) are pending;
the defaults stated there are what the plan builds.

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
  right now); `collect(run, paths)` (the only I/O; `run(argv, timeout)` is
  injected; the read-only argv allow-list is `solaar show all`, reading
  `config.yaml` and the battery state files for Solaar, and `openlogi api status`
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
             "problem", "liveKeyState", "otherRunning"},
 "keyboards": [{"slug", "name", "tested", "connected", "identity",
                "battery": {"value", "level", "source", "at"},
                "keys": [{"cid", "label", "state", "reason"?}], "bindings"}]}
```

- Key states (camelCase): `routed`, `dropped`, `notSetUp`, `absent`,
  `unsupportedByBackend`. **`absent`** is a profile fact (the keyboard does not
  report the cid). **`unsupportedByBackend`** is a backend fact (the active
  backend cannot route the cid; `reason` is `notImplemented` or `unverified`).
  Both are dimmed and neither counts toward the warning.
- When `liveKeyState` is false, `dropped` is never emitted, `routed` means
  "configured and the agent is running", and the widget offers no restore.
- Battery `source` is `report`, `query` or `backend` (the daemon's cached value
  read at `at`); `level` may be null.
- `otherRunning` names the other backend when its daemon also runs; the widget
  warns that both own the receiver.
- Kept from ADR 0005 and 0007: Solaar identity by model id then exact name;
  OpenLogi by exact name only (its API exposes no model id); exact parsing in
  Python; action ids only (no profile string reaches YAML, TOML or Lua); every
  Solaar rule, battery rules included, has the `Device` `Or`; the `absent`
  meaning; legacy v0.3 migration stays inside the Solaar adapter.

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

### OpenLogi: what the documents leave open (so it is not built)

1. Whether keyboard-control diversion works on Linux at all (the platform table
   says no for "Keyboard F-key remapping").
2. The `control:0x<cid>` spelling (hex width and case) and the catalog-name to
   cid mapping (binding one control under both spellings is a load error).
3. Which `[devices."<key>"]` entry is a given keyboard (keys such as `unit:`,
   `serial:` or a route; identity and links are app-managed with no documented
   shape; no model id in the API).
4. The exact `name` strings of the POP and MX keyboards (`name` may be null).
5. Whether the agent reloads a hand edit without the GUI or a restart.
6. The `config.toml.lock` protocol for external editors.
7. Whether any API shows key or diversion state (none documented, hence
   `LIVE_KEY_STATE` false).
8. Whether the API battery is a notification or a query, and the full `level`
   vocabulary.
9. What `keep_os_layout` (default on) does on a Linux host: it may move
   keyboards out of MacOS OS mode on connect, which would break the profiles'
   `osMode` and the Lock chord `SUPER + CTRL + Q`; the current layout is not
   readable through the API.
10. The text format of `openlogi list` (never parsed; the API is used).
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
  "openlogi": {"entries": {}, "enabledService": false}}}`. This changes the
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
  reason) or absent; every daemon action (stop, start, enable, disable); for
  OpenLogi a line that its configuration is not changed (v0.4.0); a warning
  about OpenLogi's OS-layout default; the OS mode precondition warning (spec
  AC28).
- **Switching** is one consent and one plan, with a write-ahead
  `switching: {from, to}`: (1) write `applied.json` with `switching` set; (2) stop
  the old daemon; (3) the old backend's `plan_remove` (Solaar: reset the recorded
  cids in `config.yaml` while stopped, remove the rules block with its key and
  battery rules, and the Solaar autostart block); (4) handle the old autostart
  that conflicts (Q1); (5) start the new daemon (OpenLogi: enable the service if
  not enabled and record `enabledService: true`); (6) the new backend's
  `plan_apply`; (7) write `applied.json` with the new backend and `switching:
  null`. A failure before step 5 restarts the old daemon through the `on_exit`
  trap; a re-run sees `switching` and finishes.
- **Uninstall** removes the artifacts of every backend recorded (a
  half-finished switch included), the Hyprland blocks, the battery state
  directory, the helpers and `applied.json`. It restarts only a daemon it
  stopped and disables only a service it enabled. It never uninstalls packages
  and never re-enables the other backend (it prints the command).

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

Built only after the owner records fixtures from a real install, and not in
v0.4.0 unless the recordings arrive before release. The design is a **chord
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
consent plan). Before S10 the owner re-records, masked: `openlogi --version`,
`api status`, `api devices`, `~/.config/openlogi/config.toml` after the agent has
seen both keyboards, `diag controls` for POP and MX, and `systemctl --user show
openlogi-agent.service -p UnitFileState,ActiveState`.

## Considered options

- **Solaar only (keep v0.3 scope).** Simplest and fully tested; rejected by the
  owner (D13), who wants the choice. It remains the default and the reference.
- **OpenLogi only.** Rejected: its Linux keyboard remapping is unconfirmed (open
  item 1), it is "not yet stable", and the POP and MX key behaviour is verified
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
- Live checks only the owner can run: the battery rules writing the state file
  on a real notification (POP, MX over Unifying); MX key presses under Solaar;
  with Solaar quit by hand, OpenLogi's device names, battery and whether the
  keyboards leave MacOS mode when the agent connects; in a scratch config one
  `control:0x<cid>` binding (does it divert on Linux, and does Hyprland receive
  the uinput F13 chord); hand-edit reload without a restart; a real switch round
  trip with checksums.

## Non-goals

Mixing backends per keyboard; installing OpenLogi from setup; an OpenLogi
native-action table; changing `keep_os_layout` automatically; Flatpak; a backend
picker in the widget settings; a third backend (LogiOps) or a directory plugin
contract.

## Open questions for the owner (defaults in force)

- **Q1.** During an explicit switch to Solaar, may setup run `systemctl --user
  disable openlogi-agent.service` (a service the owner's OpenLogi install
  enabled, not this plugin)? The architect recommends yes. **Default until the
  owner answers: no.** The switch does not run `disable` on a service this plugin
  did not enable; the consent plan **prints the command** for the user to run and
  warns that OpenLogi may retake the receiver at next login. The code path that
  runs `disable` is not built.
- **Q2.** If the OpenLogi recordings are not ready, ship v0.4.0 with OpenLogi
  read-only, or wait for S10? The architect recommends shipping read-only and
  S10 in v0.5.0. **Not decided here;** the v0.4.0 plan assumes read-only and the
  release decision stays with the owner.
- **Q3.** Under OpenLogi, should setup later write `keep_os_layout=off` through
  `openlogi api os-layout --set off --save`? **Default: not in v0.4.0**; warn and
  document, decide after the live check of the OS layout.
