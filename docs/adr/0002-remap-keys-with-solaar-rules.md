# 2. Remap the special keys with Solaar rules

Date: 2026-11-19

## Status

Accepted

## Context

The POP Icon Keys top row sends Windows or macOS shortcuts (for example
Super+Ctrl+<key>), or HID++ events Linux does not map, depending on the
keyboard's OS mode. Binding the shortcuts it emits in Hyprland would collide
with Omarchy's own bindings (undiverted, F7 opened the wallpaper picker). Switching the keyboard to macOS mode swaps Cmd and Opt,
which the owner rejected.

Alternatives: keyd or input-remapper (would have to rewrite the emitted
shortcut combinations, which also fire when typed by hand, and need a
system-level daemon), Hyprland bindings on the emitted shortcuts (collide with
Omarchy), changing the keyboard OS mode (wrong modifiers).

## Decision

Divert the special keys to Solaar and run Omarchy commands from Solaar rules in
`~/.config/solaar/rules.yaml`. Keep the keyboard in Linux OS mode. The Lock key
is not divertable; bind the shortcut it sends (Super+Ctrl+Q) in Hyprland.

## Consequences

- Solaar must run in the user session (started hidden at login).
- Rules cannot read modifiers on Wayland, so a key has one action.
- Key names and control ids depend on Solaar's device tables; verified on 1.1.20.
