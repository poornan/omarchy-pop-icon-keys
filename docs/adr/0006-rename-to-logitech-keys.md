# 6. Rename the plugin to logitech-keys

Date: 2026-11-19

## Status

Accepted. Stands unchanged under owner decision D19 ([ADR 0009](0009-slim-v0-4-0-scope.md)).

## Context

Omarchy marketplace plugin ids are permanent. The v0.3 id,
`io.github.poornan.pop-icon-keys`, names one keyboard, while ADR 0005 makes the
plugin multi-keyboard. v0.3 was never submitted to the marketplace and only the
owner installed it, from a local path. "Keys" also covers other Logitech
devices' special buttons, and the id must not tie the plugin to Solaar.

## Decision

- Plugin id `io.github.poornan.logitech-keys`; display name "Logitech Keys".
- Repository `poornan/omarchy-logitech-keys`. The GitHub rename happens later,
  by the owner; docs already use the new URL.
- Marker text `logitech-keys` in config blocks (`# BEGIN logitech-keys`,
  `-- BEGIN logitech-keys`); helpers `bin/logitech-keys-*`; state directory
  `logitech-keys`; `ipcTarget` and `moduleName` `logitech-keys`.
- No deprecation release of the old id. `setup` removes the v0.3
  `pop-icon-keys` marked blocks and the old helper (with consent) and warns if
  the old plugin is still installed (spec AC8; detecting v0.3 rules that
  Solaar's editor rewrote without markers is deferred by D19, ADR 0009).

## Consequences

- The owner's install needs a remove and re-add under the new id, then `setup`.
- GitHub redirects the old repo URL after the rename; README links use the new
  one.
- The slug rule of ADR 0005 applies from here: profile slugs and the plugin id
  do not change again.
