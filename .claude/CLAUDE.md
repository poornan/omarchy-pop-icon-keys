# omarchy-pop-icon-keys

Omarchy plugin (`io.github.poornan.pop-icon-keys`) that maps the Logitech POP
Icon Keys top row to Omarchy actions through Solaar rules, binds the Lock key,
and shows a bar widget with battery and routing status. Published at
github.com/poornan/omarchy-pop-icon-keys and submitted to the Omarchy plugin
marketplace (omacom/omarchy-plugin-marketplace).

## Stack

- **Bar widget:** QML on Quickshell (Omarchy 4.x shell). Entry point `Panel.qml`,
  declared in `manifest.json` (`kinds: ["bar-widget"]`).
- **Install scripts:** bash (`setup`, `uninstall`, `lib.sh`) with Python 3
  helpers in `lib/edit.py` (stdlib + PyYAML, run as `python3 -I`).
- **Helpers:** `bin/pop-icon-keys-*` (status, restore, show-desktop).
- **External tools:** solaar, hyprctl, jq, pgrep, setsid, timeout.
- No package manager, no build step.

## Commands

| Task | Command |
|---|---|
| Validate manifest | `omarchy-plugin-validate .` |
| Syntax check | `for f in setup uninstall lib.sh bin/*; do bash -n "$f"; done` |
| Setup/uninstall tests | `bash tests/test_setup.sh` |
| Widget logic tests | `python3 tests/qml_logic.py` |
| QML lint | `/usr/lib/qt6/bin/qmllint Panel.qml` (unresolved `qs.*` import warnings are expected) |
| Dry run against real config | `./setup --dry-run` (read-only) |

shellcheck is not installed on the dev machine. Run every check above before
committing.

## Rules

- **Never run `setup`, `uninstall` or `bin/pop-icon-keys-restore` against the
  real `$HOME` in tests or reviews, and never stop or restart the developer's
  running Solaar.** Use the sandbox HOMEs with stubbed `pgrep`, `solaar`,
  `hyprctl` and `setsid` in `tests/test_setup.sh`. Read-only
  `solaar show "POP Icon Keys"` is allowed.
- **Consent before any config change.** `setup` and `uninstall` print the full
  plan, then ask y/N (default No). `--yes` accepts the plan but never installs
  packages. Declining exits 0. This is a marketplace checklist requirement.
- **Edits go in marked blocks only:** `# BEGIN pop-icon-keys` / `# END
  pop-icon-keys` (YAML), `-- BEGIN/END pop-icon-keys` (Lua). Damaged markers
  abort with no change. Writes are atomic; files are backed up only when their
  content changes.
- **Solaar diversion must be written to `~/.config/solaar/config.yaml` while
  Solaar is stopped.** A running Solaar overwrites that file on exit, and
  `solaar config` alone does not persist across restarts.
- **The keyboard drops live diversion on its own** (after sleep or reconnect).
  The widget compares live and saved state and restores at runtime; that path
  must not write config files.
- **Marketplace security baseline:** no `curl | sh`, no unpinned `git clone` or
  exec, no `sudo` or sudoers, no process control based on `/tmp` state, no
  hard-coded `/home` paths.
- Key names and Solaar control ids (110 Show Desktop, 266 MultiPlatform Search,
  259 Dictation, 264 Emoji, 212 Screen Capture) are verified only on Solaar
  1.1.20 with this keyboard in Linux OS mode.

## dev-team workflow

Specs and plans are files here, not GitHub issues.

- Specs: `docs/specs/<slug>.md` (Intent, Architecture Specification, Acceptance
  Criteria, Glossary, Ambiguity Log, Consistency Gate).
- Plans: `plans/<slug>.md` (vertical slices with Gherkin scenarios).
- ADRs: `docs/adr/`.
- Gherkin feature files: `features/`.
- Reports from `/code-review` go to `.dev-team-reports/` (not committed).

The first version was built before specs existed; its spec, plan and ADRs were
written afterwards from the code and the design conversation, and say so.

## Releases

- Version lives only in `manifest.json` (`version`, semver). Bump it in the
  same commit as the change.
- Tag releases `v<version>` on `main` and create a GitHub release.
- Marketplace updates go through the marketplace's **Plugin verification**
  issue form ("Verify and publish a newer upstream commit") with the full
  40-character SHA of the release commit. Until approved, the listing shows
  "Update unverified".
- `preview.png` at the repo root is the marketplace image; crop screenshots to
  the bar and popup only, with no personal windows or names.

## Commits

Plain imperative subject lines. This is the owner's own repo with no CLA, so
the `Co-Authored-By: Claude ...` trailer is fine.
