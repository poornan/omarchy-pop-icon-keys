# omarchy-logitech-keys

Omarchy plugin (`io.github.poornan.logitech-keys`, display name "Logitech
Keys", renamed from `pop-icon-keys` in v0.4.0) that maps the special keys of
Logitech keyboards to Omarchy actions through Solaar rules, binds keys Solaar
cannot divert (POP Icon Keys Lock), and shows one bar widget with battery and
routing status per keyboard. Keyboards are described by profile files
(`profiles/<slug>.json`); shipped: POP Icon Keys (tested) and MX Keys for Mac
(untested). Repo `github.com/poornan/omarchy-logitech-keys` (renamed on GitHub
later by the owner; the old name is `omarchy-pop-icon-keys`); prepared for
submission to the Omarchy plugin marketplace (omacom/omarchy-plugin-marketplace),
not yet submitted (v0.3 was only installed from a local path by the owner).

## Stack

- **Bar widget:** QML on Quickshell (Omarchy 4.x shell). Entry point `Panel.qml`,
  declared in `manifest.json` (`kinds: ["bar-widget"]`).
- **Install scripts:** bash (`setup`, `uninstall`, `lib.sh`) with Python 3
  helpers (stdlib + PyYAML, run as `python3 -I`): `lib/edit.py` is the command
  line only; `lib/solaarcfg.py` (the one device matcher), `lib/fileedit.py`,
  `lib/diversion.py`, `lib/rules.py` (all escaping), `lib/applied.py`,
  `lib/legacy.py` (frozen v0.3 table), `lib/plan.py` (consent plan as data).
- **Profiles and actions:** `profiles/*.json`, `lib/actions.json`, read only by
  `lib/profiles.py` (stdlib). `lib/status.py` builds the widget's JSON.
- **Helpers:** `bin/logitech-keys-*` (status, restore, show-desktop, battery).
- **External tools:** solaar, hyprctl, jq (never on profiles), pgrep, setsid, timeout.
- No package manager, no build step.

## Commands

| Task | Command |
|---|---|
| Validate manifest | `omarchy-plugin-validate .` |
| Syntax check | `for f in setup uninstall lib.sh bin/*; do bash -n "$f"; done` |
| Profile schema and fixtures | `python3 -I tests/test_profiles.py` |
| Status parsing | `python3 -I tests/test_status.py` |
| Rules, classify, escaping, Solaar loader | `python3 -I tests/test_rules.py` |
| Diversion, applied record | `python3 -I tests/test_state.py` |
| Consent plan | `python3 -I tests/test_plan.py` |
| edit.py command line | `python3 -I tests/test_edit.py` |
| Repository structure (CI files, allowlists) | `python3 -I tests/test_repo.py` |
| Setup/uninstall sandbox tests | `bash tests/test_setup.sh` |
| Widget logic tests | `python3 tests/qml_logic.py` (`--pure` runs the stdlib part only) |
| QML lint | `/usr/lib/qt6/bin/qmllint Panel.qml` (unresolved `qs.*` import warnings are expected) |
| Dry run against real config | `./setup --dry-run` (read-only) |
| Plan waves | `python3 ~/.claude/plugins/cache/agentic-dev-team/dev-team/14.3.0/scripts/plan_waves.py plans/<slug>.md` |

shellcheck is not installed on the dev machine. Run every check above before
committing, with `LK_REQUIRE_SOLAAR=1` on the Python tests: a skipped Solaar
check is a failure on the dev machine (CI uses a pinned key-table snapshot).
Every slice and every commit leaves the tree and `bash tests/test_setup.sh`
green. CI (`.github/workflows/`) runs the stdlib and sandbox tests, not
the QML ones (they need quickshell).

## Rules

- **Never run `setup`, `uninstall` or `bin/logitech-keys-restore` against the
  real `$HOME` in tests or reviews, and never stop or restart the developer's
  running Solaar.** Use the sandbox HOMEs with stubbed `pgrep`, `solaar`,
  `hyprctl` and `setsid` in `tests/test_setup.sh`. Read-only `solaar show` is
  allowed. Checksum `~/.config/solaar/{rules,config}.yaml` and
  `~/.config/hypr/{bindings,autostart}.lua` before and after a build.
- **Consent before any config change.** `setup` and `uninstall` print the full
  plan, then ask y/N (default No). `--yes` accepts the plan but never installs
  packages. Declining exits 0. This is a marketplace checklist requirement.
- **Edits go in marked blocks only:** `# BEGIN logitech-keys` / `# END
  logitech-keys` (YAML), `-- BEGIN/END logitech-keys` (Lua). Damaged markers
  abort with no change. Writes are atomic; files are backed up only when their
  content changes. Setup also migrates v0.3 `pop-icon-keys` blocks, the old
  helper, and v0.3 rules Solaar's editor rewrote without markers.
- **Profiles are data, actions are code.** A profile names action ids from
  `lib/actions.json`, never commands; `lib/profiles.py` is the only reader and
  validates strictly (unknown fields fail). Slugs are permanent. A profile is
  tested only if it has a `verified` block (no boolean). Identify keyboards by
  exact model id, then exact name, never by substring; never use `jq` on
  profiles; `Panel.qml` has no keyboard or key names and renders
  `bin/logitech-keys-status` JSON only.
- **Every generated Solaar rule has a `Device` condition** (`Or` over the
  profile's names). Solaar 1.1.20 has no `Model` condition.
- **`$XDG_STATE_HOME/logitech-keys/applied.json`** records what setup diverted
  (slug, control ids, version). Setup reconciles against it, uninstall resets
  from it and deletes it. Rule comments are not state (Solaar drops them).
  **`.../battery/<slug>`** holds the last battery report (value, epoch time),
  written only by `bin/logitech-keys-battery`, which Solaar rules call
  (ADR 0007); uninstall removes the whole state directory. Never parse Solaar
  logs or add `-d` for battery, and never use `/tmp`.
- **Key state `absent`** (in neither diversion line) is dimmed and never counts
  toward the needs-setup warning.
- **One recorded fixture per profile** (`tests/fixtures/<slug>/`, first line has
  the Solaar version, serials and unit ids masked); routed/dropped/not-set-up
  variants are derived in tests. Synthetic fixtures are labelled and never count
  as verification. Full sandbox setup runs only for POP Icon Keys, the
  two-keyboard case and migration; other profiles get fast pure-Python checks.
- **Solaar diversion must be written to `~/.config/solaar/config.yaml` while
  Solaar is stopped.** A running Solaar overwrites that file on exit, and
  `solaar config` alone does not persist across restarts.
- **The keyboard drops live diversion on its own** (after sleep or reconnect).
  The widget compares live and saved state and restores at runtime; that path
  must not write config files.
- **Marketplace security baseline:** no `curl | sh`, no unpinned `git clone` or
  exec, no `sudo` or sudoers, no process control based on `/tmp` state, no
  hard-coded `/home` paths.
- **Both keyboards run in MacOS OS mode** (Solaar "Set OS" = MacOS), not Linux.
  Cmd = Super, Opt = Alt and the Lock chord `SUPER + CTRL + Q` (the macOS lock
  shortcut) are what that mode sends. The plugin never changes the OS mode;
  setup only warns on a mismatch. Never write "Linux OS mode".
- Key names and Solaar control ids (POP: 110 Show Desktop, 212 MultiPlatform
  Search, 259 Dictation, 264 Emoji, 266 Screen Capture) are verified only on
  Solaar 1.1.20 with the POP Icon Keys in MacOS OS mode. The MX Keys for Mac
  profile's device data was recorded from real hardware (2026-11-19) but its
  key presses are untested, so it has no `verified` block (a `note` says so).
- **Backend:** the owner decided on a swappable backend, Solaar or OpenLogi
  (D13). ADR 0008 is pending (architect pass); until it is accepted, code and
  specs describe Solaar only, and new code should keep keyboard and battery
  logic out of Solaar-specific files.

## dev-team workflow

Specs and plans are files here, not GitHub issues.

- **Route all dev work through `dev-team:orchestrator`** (owner decision D9:
  "always invoke through orchestrator").
- Specs: `docs/specs/<slug>.md` (Intent, Architecture Specification, Acceptance
  Criteria, Glossary, Ambiguity Log, Consistency Gate).
- Plans: `plans/<slug>.md` (vertical slices with Gherkin scenarios).
- ADRs: `docs/adr/`.
- Gherkin feature files: `features/`.
- Reports from `/code-review` go to `.dev-team-reports/` (not committed).

The first version was built before specs existed; its spec, plan and ADRs were
written afterwards from the code and the design conversation, and say so.

## Branches, releases and commits

- Work happens on feature branches, never directly on `main`. Open a pull
  request to `main` with dev-team `/pr` (pre-PR gate, then the PR). Commit
  locally; push and open the PR only when the owner asks.
- Release workflow (owner decision D8): branch, `/pr`, auto-merge, then tag
  `main`. Owner-side prerequisites, **not yet done**: allow auto-merge in the
  repo settings, protect `main` with the CI check as a required check, and the
  owner approves at PR time.
- Version lives only in `manifest.json` (`version`, semver). Bump it in the
  same commit as the change. A new profile is a minor bump, a fix a patch;
  profile PRs may batch into one release.
- Releases are tagged `v<version>` on `main` after the PR is merged, with a
  GitHub release.
- Future process, once the plugin has been submitted and listed: updates go
  through the marketplace's **Plugin verification** issue form ("Verify and
  publish a newer upstream commit") with the full 40-character SHA of the
  release commit; until approved, the listing would show "Update unverified".
  Nothing has been submitted yet.
- `preview.png` at the repo root is the marketplace image; crop screenshots to
  the bar and popup only, with no personal windows or names.
- Plain imperative commit subjects. This is the owner's own repo with no CLA,
  so the `Co-Authored-By: Claude ...` trailer is fine.
