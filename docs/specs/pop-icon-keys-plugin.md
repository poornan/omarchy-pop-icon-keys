<!-- spec-version: 1 -->
# Spec: POP Icon Keys plugin for Omarchy

**Provenance.** Written on 2026-11-19 *after* v0.2.0 was built. Intent and
acceptance criteria come from the owner's own words in two design sessions
(session A: keyboard diagnosis and the first Solaar setup; session B: testing,
packaging and release), not from the code. Each criterion cites its source.
Where the code and the owner's words disagree, the Ambiguity Log records it
instead of adopting the code's behaviour.

**Correction, 2026-11-19.** Earlier text said the keyboard runs in Linux OS
mode. That was wrong. The owner verified that Solaar reports `Set OS: MacOS`
(and `Set OS (saved): MacOS`, `multiplatform: 1` in `config.yaml`). The keyboard
runs in **MacOS OS mode** and the plugin relies on it (Ambiguity Log row 3).

## Intent Description

The owner uses a **Logitech POP Icon Keys** keyboard (Mac layout, Bolt
receiver) on **Omarchy** (Arch + Hyprland). Logitech does not support Linux for
this keyboard, so most special keys send Windows or macOS shortcuts that
Omarchy does not understand, or nothing.

The owner wants:

1. **The top row to behave as it does on macOS** — "can do the full mapping
   (use macos)", applied to Logitech's published per-OS key table (A 17:32).
2. **Mac modifier positions with Omarchy semantics**: Cmd acts as Super and
   Opt as Alt, as the keyboard sends in its MacOS OS mode. A swap to
   Opt = Super was explicitly rejected: "I want the other way" (A 17:46).
3. **Dictation through the owner's chosen backend** (Superwhisper), the same
   action as Opt+Space, not a personal script (B: "link it to wisper";
   "OS already map opt + space").
4. **A working Lock key** (B: "Fn + last, doesnt lock" was reported as a bug).
5. **To share the mapping with other Omarchy users** through the official
   plugin marketplace (B: "is there any way I can share this solaaar mapping,
   upstream?"; "should we connect to offical plugin channel?").
6. **A visible bar widget**, chosen over a minimal widget or a menu entry (B:
   plugin UI choice "Bar widget").

Out of scope: F9–F12 media keys and brightness (already correct), the four
shape keys (Circle, Triangle, Diamond, Star), keyboards other than the POP Icon
Keys, and changing the keyboard's OS mode.

## Architecture Specification

- **Key capture:** Solaar (the Logitech HID++ manager) diverts the special
  keys to itself and runs Omarchy commands through rules in
  `~/.config/solaar/rules.yaml`. Rules only work while Solaar runs, so Solaar
  starts hidden at login.
- **Persistent diversion:** diversion is written to Solaar's saved config
  (`~/.config/solaar/config.yaml`) while Solaar is stopped. A running Solaar
  overwrites that file on exit, so a runtime `solaar config` change alone is
  lost on restart (observed in session B).
- **Dropped diversion:** the keyboard can drop its live diversion by itself
  (observed in session B; restarting Solaar restored it). The widget compares
  live and saved diversion and re-applies it at runtime without writing files.
- **OS mode:** the keyboard stays in **MacOS OS mode** (Solaar "Set OS" =
  MacOS). That mode sends Cmd as Super, Opt as Alt and the macOS shortcuts; the
  plugin never changes the mode and its key mapping assumes it.
- **Lock key:** the keyboard sends `Super+Ctrl+Q` (the macOS lock shortcut,
  sent only in MacOS mode), which Solaar cannot remap; a Hyprland binding maps
  it to `omarchy-system-lock`.
- **Plugin packaging:** an Omarchy 4.x plugin requires a UI kind, so the
  plugin is a `bar-widget` (`Panel.qml`) with `setup` and `uninstall` scripts
  that make the config changes.
- **Config ownership:** every change lives in a marked block and is reversible
  by `uninstall`. No change happens without the user's consent.
- **Constraints:** Omarchy marketplace submission rules and its static
  security baseline (no `curl | sh`, no unpinned git exec, no sudo, no
  `/tmp`-based process control, no config overwrite without consent).

## Acceptance Criteria

Key mapping (keyboard in MacOS OS mode, Fn-swap on):

- **AC1 — F4 Show Desktop** shows an empty desktop; pressing it again returns
  to the previous workspace. (A: macOS column "Show Desktop"; B: "F4 yes".)
- **AC2 — F5 Search** opens the Omarchy app launcher (Spotlight equivalent).
  (A: macOS column "Search"; B: "F5 yes launcher".)
- **AC3 — F6 Dictation** runs `omarchy-dictation toggle`, the same action as
  Opt+Space, using the dictation backend selected in Omarchy. (B: "link it to
  wisper"; "OS already map opt + space"; "F6 works now".)
- **AC4 — F7 Emoji** opens the Omarchy emoji picker. (A: macOS column
  "Emoji"; B: "F7 yes".)
- **AC5 — F8 Snip & Sketch** takes a screenshot of a selected region. This
  deliberately differs from the macOS column ("Screenshot (full screen)"); see
  Ambiguity Log row 1. (A: "works" after a region mapping; B: "F8 workss";
  B: owner chose "Region (keep current)" on 2026-11-19.)
- **AC6 — Lock (Fn + last key)** locks the screen. This depends on MacOS mode,
  because the Super+Ctrl+Q chord it sends is the macOS lock shortcut. (A: macOS column "Screen
  Lock"; B: "Fn + lock yes".)
- **AC7 —** F9–F12, brightness and all other keys keep their existing
  behaviour. (A: "F9–F12 … unchanged" was accepted.)
- **AC8 —** Cmd sends Super and Opt sends Alt (what MacOS mode sends). (A 17:46.)

Reliability:

- **AC9 —** The mapping survives a Solaar restart and a reboot. (B: the reset
  bug was reported — "F6 not works but opt + space works" — and the owner
  asked whether "this problem come with plugin".)
- **AC10 —** When the keyboard drops diversion, the keys are routed again
  without the user editing anything. (B: pre-release review; owner approved
  fixing.)

Sharing and packaging:

- **AC11 —** Installable from its GitHub repo with
  `omarchy plugin add <repo> --enable`, then `setup`. (B: marketplace.)
- **AC12 —** `setup` lists every file it will change and asks before writing;
  declining changes nothing. (Marketplace checklist: "does not overwrite user
  configuration without explicit consent".)
- **AC13 —** `uninstall` removes everything `setup` added and leaves the
  user's other rules and bindings untouched. (Marketplace: removal
  instructions; B: plugin design.)
- **AC14 —** No personal paths, names or the owner's own scripts in the
  shared code; the owner's dictation script is not referenced. (B: "Sanitise
  before sharing" agreed when packaging was proposed.)
- **AC15 —** The bar widget shows keyboard battery, whether each key is
  routed, Solaar's state, and offers re-applying setup. (B: "Bar widget"
  option as described and chosen.)
- **AC16 —** The README shows the widget screenshot. (B: "include the
  screenshot on readme".)
- **AC17 —** The repo passes `omarchy-plugin-validate`, the marketplace's
  structure rules, and the security baseline patterns.
- **AC18 —** A dev-team code review passes before release. (B: "did we do code
  review. run agentic team orchestrator"; "run the dev-team orchestrator
  again, before release".)

## Glossary

| Term | Definition | Status | Source |
|------|------------|--------|--------|
| POP Icon Keys | Logitech wireless keyboard, Mac layout, used here through a Bolt receiver | `verified` | Solaar output, session A |
| Diverted / Regular | Solaar per-key setting: Diverted sends the press to Solaar rules; Regular lets the keyboard send its built-in shortcut | `unverified` | Solaar UI and behaviour, sessions A–B |
| Live vs saved diversion | Live: what the keyboard currently does. Saved: Solaar's `config.yaml` value it applies on start | `unverified` | `solaar show` output, session B |
| Dropped keys | Saved = Diverted but live = Regular | `unverified` | Observed in session B |
| MacOS OS mode | Keyboard setting (Solaar "Set OS" = MacOS) in which Cmd sends Super, Opt sends Alt and Lock sends Super+Ctrl+Q. It replaces the earlier "Linux OS mode" term, which was wrong | `verified` | Owner, 2026-11-19: `solaar show` "Set OS: MacOS", `config.yaml` `multiplatform: 1`; session A wev captures for the key output |
| macOS column | The macOS behaviour column of Logitech's per-OS key table the owner pasted | `verified` | Session A 17:32 |
| Marked block | Lines between `BEGIN pop-icon-keys` and `END pop-icon-keys` comments that only the plugin edits | `unverified` | Plugin design |

## Ambiguity Log

| # | Decision | Classification | Resolved By | Rationale / Answer |
|---|----------|---------------|-------------|-------------------|
| 1 | **F8: full-screen (macOS column) or region screenshot?** The owner asked for the macOS mapping; Logitech's macOS column says "Screenshot (full screen)". Session A mapped F8 to `Print` (Omarchy's screenshot shortcut), then to region capture, calling region "macOS behaviour" in error. The owner tested region and said it works. | `requires-stakeholder-input` | human (B, 2026-11-19) | "Region (keep current)": the owner's tested preference overrides the macOS column for F8. |
| 2 | Cmd = Super, Opt = Alt (no swap) | `requires-stakeholder-input` | human (A 17:46) | "I want the other way" after a swap to Opt = Super was applied; swap reverted. |
| 3 | OS mode of the keyboard | `requires-stakeholder-input` | human (owner, 2026-11-19, D10) | Corrected. This row said "keep the keyboard in Linux OS mode" (inferred in session A); the owner showed it never was. The keyboard is in **MacOS mode** (`Set OS: MacOS`); the plugin relies on it. Cmd = Super and Opt = Alt are what MacOS mode sends, and the Lock key's `Super+Ctrl+Q` is the macOS lock shortcut and depends on it. The plugin does not change the mode. |
| 4 | F6 target: owner's personal voxtype script vs Omarchy dictation | `requires-stakeholder-input` | human (B) | "link it to wisper"; then "OS already map opt + space" → `omarchy-dictation toggle`, which follows the selected backend. |
| 5 | F4 behaviour: empty workspace vs hiding windows | `requires-stakeholder-input` | human (B) | Explained as the nearest Hyprland equivalent; owner confirmed "F4 yes" (returns on second press). |
| 6 | Lock key binding to `omarchy-system-lock` | `inferable` | inference (B) | Key sends `Super+Ctrl+Q`, unbound in Omarchy; owner confirmed "Fn + lock yes". |
| 7 | Plugin UI: bar widget vs minimal widget vs menu entry | `requires-stakeholder-input` | human (B) | "Bar widget (Recommended)". |
| 8 | Repo owner and plugin id | `requires-stakeholder-input` | human (B) | gh-logged-in account → `poornan`, id `io.github.poornan.pop-icon-keys`. |
| 9 | Distribution channel | `requires-stakeholder-input` | human (B) | Official Omarchy plugin marketplace; Omarchy core PR judged unlikely to be accepted; Solaar Discussions post optional. |
| 10 | Auto-restore dropped keys by default | `inferable` | inference (B) | Restores runtime state only, changes no setting the user chose; a manifest setting turns it off. Owner approved fixing review findings. |
| 11 | Licence | `inferable` | inference (B) | MIT, matching the existing marketplace plugins; owner did not object. |
| 12 | Shape keys (Circle, Triangle, Diamond, Star) | `inferable` | inference (A) | Offered in session A; the owner did not take it up. Out of scope. |

## Consistency Gate

- [x] Intent is unambiguous
- [x] Every behavior/goal maps to an acceptance criterion
- [x] Architecture constrains without over-engineering
- [x] Terminology consistent across artifacts
- [x] No contradictions between artifacts — F8 region capture is the owner's recorded exception to the macOS column (row 1)
- [x] Every gap/ambiguity finding is logged — inferable with rationale or resolved by human

**Verdict: PASS** (2026-11-19, after the owner resolved row 1).
