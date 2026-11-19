# 2. Remap the special keys with Solaar rules

Date: 2026-11-19

## Status

Accepted

## Context

The POP Icon Keys top row sends Windows or macOS shortcuts (for example
Super+Ctrl+<key>), or HID++ events Linux does not map, depending on the
keyboard's OS mode. The keyboard runs in **MacOS OS mode** (Solaar "Set OS" =
MacOS; verified by the owner on 2026-11-19, which corrects the earlier text of
this record that said Linux mode). In that mode Cmd sends Super and Opt sends
Alt, which suits Omarchy, and the special keys send the macOS shortcuts or HID++
events. Binding those shortcuts in Hyprland would collide with Omarchy's own
bindings (undiverted, F7 opened the wallpaper picker). A modifier swap that
made Opt send Super was rejected by the owner.

Alternatives: keyd or input-remapper (would have to rewrite the emitted
shortcut combinations, which also fire when typed by hand, and need a
system-level daemon), Hyprland bindings on the emitted shortcuts (collide with
Omarchy), changing the keyboard OS mode (it is already MacOS mode, which gives the
modifiers the owner wants; other modes send other shortcuts and are untested).

## Decision

Divert the special keys to Solaar and run Omarchy commands from Solaar rules in
`~/.config/solaar/rules.yaml`. The keyboard stays in MacOS OS mode; macOS
behaviour is copied through the rules, not through a different OS mode. The Lock
key is not divertable; bind the shortcut it sends (Super+Ctrl+Q, the macOS lock
shortcut, which exists only in MacOS mode) in Hyprland.

## Consequences

- Solaar must run in the user session (started hidden at login).
- Rules cannot read modifiers on Wayland, so a key has one action.
- Key names and control ids depend on Solaar's device tables; verified on 1.1.20.
- The mapping assumes MacOS OS mode; behaviour in another mode is untested, and
  the Lock binding depends on it (spec AC27, AC28).
