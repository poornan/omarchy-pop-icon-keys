# POP Icon Keys for Omarchy

Makes the Mac-style top row of the **Logitech POP Icon Keys** do the matching
thing on [Omarchy](https://omarchy.org), and puts the keyboard's battery in the bar.

Logitech does not support Linux for this keyboard. Most of its special keys send
Windows or macOS shortcuts, or nothing Linux understands. This plugin uses
[Solaar](https://github.com/pwr-Solaar/Solaar) to catch those keys and run Omarchy
commands instead.

![The POP Icon Keys bar widget open: battery, key map with each key routed, Solaar status, and the Re-apply setup and Refresh buttons](preview.png)

| Key | Does |
|---|---|
| F4 Show Desktop | Switches to an empty workspace; press again to go back |
| F5 Search | Omarchy app launcher |
| F6 Dictation | `omarchy-dictation toggle`, the same as Alt+Space, using whichever dictation backend you chose in Omarchy |
| F7 Emoji | Omarchy emoji picker |
| F8 Screen Capture | Region screenshot |
| Lock (Fn + last key) | Lock screen (`omarchy-system-lock`) |
| F9–F12, brightness, volume | Unchanged: the keyboard's own media keys already work |

The bar icon shows the keyboard's battery. Click it for the key map, whether
Solaar is running, and whether each key is routed. Right-click to refresh. It
turns your theme's urgent colour when the battery is low, a key needs setup, or
the keyboard has dropped keys (below). In the open panel, `r` refreshes, `k`
restores dropped keys and `s` runs setup.

### When the keyboard drops keys

The keyboard forgets which keys go to Solaar when it sleeps or reconnects, and
Solaar does not always send them again. The keys then fall back to the
keyboard's own shortcuts until Solaar is restarted. This is a keyboard and
Solaar limitation, not something setup can fix in a file.

The widget compares what Solaar has saved with what the keyboard reports. A key
that is saved but not active is shown as **dropped**, and the widget sends it
back to Solaar (`bin/pop-icon-keys-restore`). That re-applies Solaar's saved
setting and changes no setting (the running Solaar may write `config.yaml` again
with the same values). It only runs while Solaar is running. It happens
automatically, at most once a minute, unless you turn off **autoRestore**; the
**Restore** button does it by hand (and also holds the automatic one back for a
minute).
The widget checks every 2 minutes, so a dropped key can take that long to come
back. Restarting Solaar also fixes it.

### Settings

| Setting | Default | |
|---|---|---|
| `hideWhenDisconnected` | on | Hide the icon while the keyboard is away and nothing needs fixing |
| `showPercentage` | off | Show the battery percentage next to the icon |
| `autoRestore` | on | Send dropped keys back to Solaar automatically |

## Requirements

- Omarchy 4.x (its Quickshell bar, `hyprctl` and the `omarchy-*` commands)
- [Solaar](https://github.com/pwr-Solaar/Solaar) (`omarchy pkg add solaar`). Tested
  on Solaar 1.1.20 only; there is no version check. When run in a terminal, setup
  offers to install it; with `--yes` it stops and asks you to install it first.
- The keyboard on its **Linux** OS mode (the default, and what Solaar's "Set OS" shows), connected by its Logi Bolt receiver or Bluetooth
- Python 3.8 or later with PyYAML (`python-yaml`, which Solaar depends on), and
  `jq`, `pgrep` (procps), `setsid` and `flock` (util-linux), `timeout` and
  `install` (coreutils). Omarchy has all of these.
- Run setup and uninstall as your own user. They refuse to run as root.

## Install

```bash
omarchy plugin add https://github.com/poornan/omarchy-pop-icon-keys --enable
~/.config/omarchy/plugins/io.github.poornan.pop-icon-keys/setup
```

`setup` lists every file it will change and asks before changing anything.
Add `--dry-run` to see each change as a diff without making it, or `--yes` to
skip the question. It is safe to run again: a file whose content would not
change is not touched. The bar panel's **Re-apply setup** button runs it in a
terminal, so you still get asked. Only one setup or uninstall runs at a time.

Setup writes the rules first, which on their own do nothing, and diverts the
keys last. To divert them it stops Solaar (SIGTERM, then SIGKILL after 8
seconds), edits Solaar's settings, and starts Solaar, also when Solaar was not
running before (it is what routes the keys). However setup ends, including an
error, Ctrl-C or a closed terminal, a Solaar it stopped is started again. If
setup fails after changing a file, it says so and how to recover: fix the
problem and run setup again, or run uninstall. At the end it lists any step it
could not do (no `bindings.lua`, Solaar not starting, Hyprland not reloading)
instead of saying "Done". Exit status: 0 done or declined, 1 error, 2 partly
applied (Solaar has never seen the keyboard, so the keys could not be diverted
yet: turn the keyboard on and run setup again).

What setup changes. A file edited in place is backed up only when its content
changes, as `<file>.bak.pop-icon-keys.<date-time>`, and the newest 3 backups of
each file are kept. Those edits are written to a temporary file and moved into
place (a symlinked file is written through to its target, with its mode kept),
the file's line endings are kept (a file mixing CRLF and LF gets the more common
one), and a marked block stays where it is in the file. The Show Desktop helper
is copied with `install`, and a missing or empty `rules.yaml` is started as
`%YAML 1.3`; neither needs a backup.

| File | Change |
|---|---|
| `~/.config/solaar/rules.yaml` | Adds the key rules in a block marked `# BEGIN pop-icon-keys` / `# END pop-icon-keys`, and removes earlier exact copies of these rules left outside the block. Your other rules stay as they are. |
| `~/.local/bin/pop-icon-keys-show-desktop` | Installs the Show Desktop helper |
| `~/.config/solaar/config.yaml` | Sets Show Desktop, Search, Dictation, Emoji and Screen Capture to *Diverted* for every saved entry of the keyboard, so Solaar receives them. Other keys and devices are kept. Solaar is stopped while this is written, since a running Solaar writes its own settings back over the file. |
| `~/.config/hypr/bindings.lua` | Binds Super+Ctrl+Q (what the Lock key sends) to `omarchy-system-lock`, in a marked block. Skipped if the file already has a line starting `o.bind("SUPER + CTRL + Q"`; a binding spelled another way is not noticed. |
| `~/.config/hypr/autostart.lua` | Starts Solaar hidden at login, in a marked block. Skipped if any uncommented line mentions `solaar`. |
| Hyprland | Reloaded (`hyprctl reload`) if either Hyprland file changed. |

`XDG_CONFIG_HOME` is used instead of `~/.config` when it is set to an absolute path.

## Remove

```bash
~/.config/omarchy/plugins/io.github.poornan.pop-icon-keys/uninstall
omarchy plugin remove io.github.poornan.pop-icon-keys
```

Run `uninstall` **before** removing Solaar: it needs Solaar to reset the keys.

`uninstall` also asks first, and supports `--dry-run` and `--yes`. It sets the
five keys back to *Regular* first, so they send the keyboard's own shortcuts
again (even keys that were already *Diverted* before you ran setup), then
removes the marked blocks and the helper. It also removes exact copies of this
plugin's rules that are no longer inside the marked block (see Caveats); a rule
only counts as a copy when its key and command match exactly, including the
helper's full path. Lines and rules you wrote yourself are left alone. If Solaar
is not installed any more, uninstall removes the rest and says that the key
diversion was not reset; the keyboard then sends its own shortcuts again after
it is turned off and on.

Left behind on purpose: the backups (`<file>.bak.pop-icon-keys.*`, up to 3 per
file), a `rules.yaml` that setup created (it then holds only `%YAML 1.3`), and
the lock file `pop-icon-keys.lock` in `$XDG_RUNTIME_DIR`. Delete them if you
like. Solaar itself stays installed: remove it with `omarchy pkg drop solaar`
if nothing else needs it.

## Caveats

- The key names (`Show Desktop`, `MultiPlatform Search`, `Dictation`, `Emoji`,
  `Screen Capture`) were checked on Solaar 1.1.20 with one POP Icon Keys. Another
  Solaar version or keyboard revision may name them differently; run
  `solaar show "POP Icon Keys"` to see yours.
- On Wayland, Solaar rules cannot see modifier keys, so the rules match the key
  alone.
- If you already had your own Solaar rules for these keys, setup warns you and
  leaves them: both would run on each press, so remove the old ones.
- Saving rules in Solaar's own rule editor rewrites `rules.yaml` and drops all
  comments, including the `BEGIN`/`END` markers. Setup and uninstall still
  recognise this plugin's rules by their exact key and command and replace or
  remove them. If you changed one of them in Solaar's editor, it no longer
  matches: remove it there by hand.
- If a `BEGIN` or `END` marker line was edited or deleted by hand, setup and
  uninstall stop without changing anything and say which file to fix.
- The Lock key is not one Solaar can remap. It sends Super+Ctrl+Q, the macOS
  lock shortcut, which is why it is bound in Hyprland instead.
- Known limitations: in the open panel, `s`, `r` and `k` also react with Ctrl or
  Alt held. The widget polls every 2 minutes even while it is hidden, and each
  read takes a few seconds. The Show Desktop helper's "press again to go back"
  uses Hyprland's previous-workspace focus and has only been tried on one setup.
  Uninstall removes only its own marked Lock binding and autostart lines, not
  ones you wrote yourself.

## Development

```bash
omarchy plugin validate .
python3 tests/qml_logic.py     # widget logic, offscreen; needs quickshell
tests/test_setup.sh            # setup, uninstall and the helpers in throwaway HOMEs (about a minute)
./setup --dry-run
```

`bin/pop-icon-keys-status` prints what the widget reads: Solaar installed and
running, keyboard connected, battery, which keys the keyboard is routing now,
which Solaar has saved, and which are missing (need setup) or dropped (need a
restore). File edits live in `lib/edit.py`, which also holds the one list of
mapped keys and their Solaar ids (`python3 -I lib/edit.py keys`); the test
suite checks that `Panel.qml` shows the same keys.

## License

MIT. See [LICENSE](LICENSE).
