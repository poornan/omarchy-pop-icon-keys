# POP Icon Keys for Omarchy

Makes the Mac-style top row of the **Logitech POP Icon Keys** do the matching
thing on [Omarchy](https://omarchy.org), and puts the keyboard's battery in the bar.

Logitech does not support Linux for this keyboard. Most of its special keys send
Windows or macOS shortcuts, or nothing Linux understands. This plugin uses
[Solaar](https://github.com/pwr-Solaar/Solaar) to catch those keys and run Omarchy
commands instead.

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
turns your theme's urgent colour when the battery is low or a key needs setup.

## Requirements

- Omarchy 4.x
- [Solaar](https://github.com/pwr-Solaar/Solaar) 1.1.20 or later (`omarchy pkg add solaar`; setup offers to install it)
- The keyboard on its **Linux** OS mode (the default, and what Solaar's "Set OS" shows), connected by its Logi Bolt receiver or Bluetooth
- `jq` and `python3`, which Omarchy already has

## Install

```bash
omarchy plugin add https://github.com/poornan/omarchy-pop-icon-keys --enable
~/.config/omarchy/plugins/io.github.poornan.pop-icon-keys/setup
```

`setup` lists every file it will change and asks before changing anything.
Add `--dry-run` to see the exact changes without making them, or `--yes` to skip
the question. It is safe to run again; the bar panel's **Re-apply setup** button
runs it in a terminal.

What setup changes (each file is backed up first, as `<file>.bak.pop-icon-keys.<date-time>.<pid>`):

| File | Change |
|---|---|
| `~/.config/solaar/rules.yaml` | Adds the key rules in a block marked `# BEGIN pop-icon-keys` / `# END pop-icon-keys`. Your other rules stay as they are. |
| `~/.local/bin/pop-icon-keys-show-desktop` | Installs the Show Desktop helper |
| `~/.config/solaar/config.yaml` | Sets Show Desktop, Search, Dictation, Emoji and Screen Capture to *Diverted*, so Solaar receives them. Solaar is stopped while this is written, since a running Solaar writes its own settings back over the file. |
| `~/.config/hypr/bindings.lua` | Binds Super+Ctrl+Q (what the Lock key sends) to `omarchy-system-lock`, in a marked block. Skipped if you already bind Super+Ctrl+Q. |
| `~/.config/hypr/autostart.lua` | Starts Solaar hidden at login, in a marked block. Skipped if Solaar already starts there. |

## Remove

```bash
~/.config/omarchy/plugins/io.github.poornan.pop-icon-keys/uninstall
omarchy plugin remove io.github.poornan.pop-icon-keys
```

`uninstall` also asks first, and supports `--dry-run` and `--yes`. It removes the
marked blocks and the helper, and sets the five keys back to *Regular* so they
send the keyboard's own shortcuts again. Lines you wrote yourself, outside the
marked blocks, are left alone. Solaar itself stays installed: remove it with
`omarchy pkg drop solaar` if nothing else needs it.

## Caveats

- The key names (`Show Desktop`, `MultiPlatform Search`, `Dictation`, `Emoji`,
  `Screen Capture`) were checked on Solaar 1.1.20 with one POP Icon Keys. Another
  Solaar version or keyboard revision may name them differently; run
  `solaar show "POP Icon Keys"` to see yours.
- On Wayland, Solaar rules cannot see modifier keys, so the rules match the key
  alone.
- If you already had your own Solaar rules for these keys, setup warns you:
  both would run on each press, so remove the old ones.
- The Lock key is not one Solaar can remap. It sends Super+Ctrl+Q, the macOS
  lock shortcut, which is why it is bound in Hyprland instead.

## Development

```bash
omarchy plugin validate .
python3 tests/qml_logic.py     # widget logic, offscreen; needs quickshell
./setup --dry-run
```

`bin/pop-icon-keys-status` prints what the widget reads: Solaar installed and
running, keyboard connected, battery, and which keys are diverted.

## License

MIT. See [LICENSE](LICENSE).
