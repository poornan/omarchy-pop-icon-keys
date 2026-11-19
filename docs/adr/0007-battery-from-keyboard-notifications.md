# 7. Battery from the keyboard's own notifications

Date: 2026-11-19

## Status

Accepted. Amended for [ADR 0008](0008-swappable-input-backend.md): the battery
rules are the **Solaar backend's** implementation detail, and the status battery
`source` gains `backend`. Amended 2026-11-19 by owner decision D18 (see
Decision): the report is kept across reconnects and a lower query replaces it;
the earlier rule that ignored a report older than the last connect is withdrawn.

## Context

The widget shows the keyboard battery. Owner requirement (decision D11): the
figure must be accurate, so it comes from the keyboard's own battery reports,
not from a direct query.

Verified on 2026-11-19 on the owner's POP Icon Keys with Solaar 1.1.20:

- `solaar show` (a fresh HID++ query) printed "battery unified 100% charged,
  level 8" right after connect (`logitech_receiver/hidpp20.py`,
  `decipher_battery_unified`), while the keyboard's own later UNIFIED_BATTERY
  notification reported 15%. The Solaar GUI showed 15% before a restart and 100%
  after it. The batteries are 10 months old, so the direct query is stale.
- Solaar has no API: no D-Bus service, no IPC. Its temporary log
  (`/tmp/Solaar_*`) only receives INFO and WARNING (`solaar/gtk.py`, lines
  129-130), so the battery DEBUG lines never reach it. Parsing logs or starting
  Solaar with `-d` is therefore not an option, and `/tmp` state is also against
  the marketplace baseline.
- Solaar passes every feature notification, battery included, to the rule engine
  (`logitech_receiver/notifications.py`: `_process_feature_notification` handles
  UNIFIED_BATTERY at lines 273-277 without returning, then calls
  `diversion.process_notification` at line 480). The rule conditions available
  are `Feature` (`diversion.py` line 680), `Report` (701, compares
  `notification.address >> 4`), `TestBytes [start, end, min, max]` (941;
  `range_test`, line 891, reads `data[start:end]` as a big-endian signed integer
  and is inclusive) and `Device` (1045).
- In the unified battery data, byte 0 is the discharge percentage and byte 1 the
  level. For BATTERY STATUS (the MX Keys for Mac), `decipher_battery_status`
  reads `data[:3]` as discharge percentage, next level, status, so a
  `TestBytes [0, 1, lo, hi]` on byte 0 works for both features.

Prior art (D17, read in OpenLogi's source on master, 2026-11-19): the owner
suggested "or we can refer how they read battery and reproduce on ours".
OpenLogi uses the same HID++ UnifiedBattery `0x1004` `getStatus` (function 1)
and status event 0 with the same byte layout as Solaar
(`crates/openlogi-hidpp/src/feature/unified_battery.rs`). Its agent re-reads the
battery on every inventory poll (`crates/openlogi-device/src/inventory/cache.rs`),
never restores a saved reading (`persist.rs`: it "would resurrect a stale
value") and handles the battery broadcast
(`inventory/replay_tests.rs`, `battery_broadcast_refresh`). It has no special
battery command, and `openlogi list` showed the same stale 100 % for the POP.
So reproducing it here is this ADR as designed: capture the broadcast (Solaar
rules), query only as a fallback, and never persist a query as the truth.

Alternatives: parse Solaar's log (no DEBUG lines, `/tmp`), run Solaar with `-d`
(noisy, changes the user's setup), query only (stale, the problem above), poll
`solaar show` more often (still the stale query).

## Decision

Use Solaar rules to observe the keyboard's battery notifications.

- A profile may have a `battery` field: `{"feature": "UNIFIED BATTERY"}` (POP
  Icon Keys) or `{"feature": "BATTERY STATUS"}` (MX Keys for Mac). Without it, no
  battery rules are generated.
- For each applied profile with that field, the managed rules block gets one rule
  per 10 % bucket (0-9, 10-19, ... 90-100): `Device` (an `Or` over the profile's
  names, per ADR 0005) + `Feature` + `Report: 0` + `TestBytes [0, 1, lo, hi]`,
  with the action `Execute [<plugin helper>, <slug>, <lo>]`.
- New helper `bin/logitech-keys-battery <slug> <percent>`: accepts only a slug
  that a profile defines and an integer 0-100, and writes
  `$XDG_STATE_HOME/logitech-keys/battery/<slug>` (the value and the epoch time)
  atomically. It writes nothing under `/tmp`.
- The status JSON carries `battery` as null or `{value, level, source, at}`
  (`level` may be null), with `source` `report` or `query` (Solaar backend) or
  `backend` (the figure another backend's daemon cached, read at `at`, for
  example OpenLogi's `openlogi api devices` battery). **Selection rule (D18,
  owner-decided):** the latest keyboard report is kept and shown with its age,
  across reconnects and Solaar restarts, until either a newer report arrives or a
  direct query (or backend figure) returns a **lower** value, in which case the
  query value is shown with source `query` (or `backend`). A query value equal to
  or higher than the report never replaces it. With no report, the query figure
  is shown. The owner chose this ("Keep last report (Recommended)") over ignoring
  a report older than the last connect, knowing the stated risk below. The rule
  is held in **one function**,
  `choose_battery(report, query)`, with a test pinning each case; the status
  builder no longer takes the keyboard's last connect as an input. A report's
  `value` is its bucket midpoint.
- The widget shows "≈15%" and the report's age (for example "≈15%, 3 h ago") for
  a report, and "Full?", not a confident 100 %, when only the query says full or
  100. When the query wins because it is lower, the exact figure is shown with
  source `query` and no report age.
- **Only reports are persisted.** `bin/logitech-keys-battery` (called by the
  rules, so only from a keyboard report) is the only writer of
  `$XDG_STATE_HOME/logitech-keys/battery/`. A query result (Solaar's
  `solaar show`, or an OpenLogi `api devices` figure) is shown with source
  `query` or `backend`, is never written to that directory and so can never be
  read back later as if it were a report.
- `uninstall` removes the plugin's state directory, battery files included.

## Consequences

- The figure is accurate to a 10 % bucket and only as fresh as the keyboard's
  last report; the widget shows the age.
- **Limitation (D18, accepted by the owner).** The last report is kept whatever
  its age. After the owner fits new batteries the widget keeps showing the old
  low value (for example "≈15%, 3 h ago") until the keyboard reports again, which
  it does soon after power-up; Restore and Refresh do not force a report. A query
  that returns a higher value (a stale 100 % included) never replaces the report,
  which is the stale-query problem this ADR exists to avoid. A query that returns
  a lower value does replace it, so a battery that has dropped is not hidden.
- Setup writes more rules (ten per battery-capable keyboard), all in the managed
  block, covered by the same classify, reconcile and uninstall paths.
- Live verification needs Solaar to reload the rules; setup restarts it, but the
  end-to-end result on the owner's keyboards is unverified and left to the owner.
  The rule evaluation itself is tested with Solaar's own rule code.
- The helper, the state file and the status JSON do not depend on Solaar. Only
  the generated rules do, and ADR 0008 makes them an implementation detail of the
  Solaar backend (`lib/backends/solaar.py`); the rules, their classification and
  their removal belong to that backend's plan. The OpenLogi backend does not
  write rules or the state file: it reads the battery from its agent
  (`source` `backend`).
