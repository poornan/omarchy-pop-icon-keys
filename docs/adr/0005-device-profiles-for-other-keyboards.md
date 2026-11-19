# 5. Device profiles for keyboards other than the POP Icon Keys

Date: 2026-11-19

## Status

Proposed

## Context

Other Logitech keyboards (MX Keys, MX Keys Mini, POP Keys, K-series) have
similar divertable special keys under Solaar. Today the device name, Solaar key
names, control ids, actions and the Lock shortcut are repeated in several files
(`lib.sh`, `lib/edit.py`, the status and restore helpers, `Panel.qml`, tests).
A contributor adding a keyboard would have to edit all of them. Marketplace
plugin ids are permanent, and the current id names one keyboard.

## Decision (proposed)

- One profile file per keyboard in `profiles/<slug>.json`: Solaar device name,
  model id, keys (Solaar name, control id, label, command), optional Hyprland
  bindings (for example the Lock shortcut), and the Solaar version it was
  verified on.
- Every script and the widget read profiles; nothing hard-codes a keyboard.
- Setup applies profiles for keyboards Solaar knows; the widget shows one row
  per connected profiled keyboard.
- A test validates every profile's schema; a contributor PR adds one JSON file,
  its fixture (`solaar show` output) and a README row.
- Rename the plugin to a device-neutral id before the first marketplace
  submission.

## Consequences

- Adding a keyboard becomes a one-file PR plus a fixture.
- The rename changes the repo name and install commands; existing installs
  (the owner's) need a remove and re-add.
- More moving parts in setup and the widget; needs its own spec and plan.
