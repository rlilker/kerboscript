---
name: Telemetry system refactor
description: lib/telemetry.ks is the canonical home for all HUD and logging functions; tlog/tdebug/plog replace the old log_message/debug calls
type: project
---

`lib/telemetry.ks` was added as the single source of truth for logging and HUD.
It is loaded by `config.ks` after `lib/util.ks`.

Key functions defined there:
- `tlog(msg)` — replaces `log_message()`: file-only write with timestamp, sets TEL_LAST_MSG, NO terminal print
- `tdebug(msg)` — replaces `debug()`: debug-only log to file + HUD debug row
- `plog(msg)` — scrolling print + log (moved here from util.ks)
- `show_launch_hud(phase, alt_km, ap_km, pitch_deg, throttle_pct, b_fuel_pct, b_stg, stg_num)` — AT-based launch HUD
- `show_booster_hud(phase_name, extra_line)` — AT-based booster HUD (references BOOSTER_TARGET global)
- `show_standby_hud()` — AT-based standby HUD
- `GLOBAL BOOSTER_TARGET IS LATLNG(0, 0)` — declared here, NOT in autoland_staging.ks

**Why:** Centralises all display/logging so individual scripts don't duplicate HUD code.

**How to apply:** Any new script that logs or displays telemetry should use tlog/tdebug/plog/show_*_hud.
Never redeclare BOOSTER_TARGET or redefine show_booster_hud/show_standby_hud/show_launch_hud in other files.
Old names log_message() and debug() no longer exist in util.ks — do not use them.
