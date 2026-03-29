# kOS Launch & Booster Recovery System

## Overview

kOS autopilot for the **Ike I** rocket: gravity turn ascent, asparagus staging, orbital circularization, and SpaceX-style RTLS booster recovery. All scripts live in `Ships/Script/`.

## File Structure

```
Ships/Script/
├── launch.ks              # Main launch autopilot (run this to launch)
├── autoland_staging.ks    # Booster RTLS landing — runs independently on each separated booster
├── test.ks                # Pre-flight test suite
└── lib/
    ├── util.ks            # Shared foundation: logging, LATLNG math, DEBUG_MODE
    ├── ascent.ks          # Gravity turn profile, staging detection
    ├── guidance.ks        # Trajectory prediction, impact calculation
    ├── circularize.ks     # Circularization burn
    ├── boostback.ks       # Boostback burn guidance (RTLS)
    ├── entry.ks           # Entry burn and descent control
    └── landing.ks         # Suicide burn and touchdown
```

## Connecting to kOS

kOS exposes a telnet terminal server on **127.0.0.1:5410** (default).

**Interactive (user):** run `connect.bat` — opens a plink terminal session.

**Programmatic (Claude):** use plink via Bash to send commands and capture output:
```bash
# Send a command and read response
echo "PRINT SHIP:NAME." | plink -telnet 127.0.0.1 -P 5410

# Run a script
echo 'RUN test.' | timeout 30 plink -telnet 127.0.0.1 -P 5410

# Read a log file
echo 'PRINT OPEN("0:/flight.log"):READALL:STRING.' | plink -telnet 127.0.0.1 -P 5410
```

Host and port are configured at the top of `connect.bat`.

## One-Time VAB Setup (per rocket build)

On each recoverable booster, right-click the kOS processor part and set the **Name Tag** to `booster_1`, `booster_2` etc. This is the only tag needed — `part:TAG` and the kOS Name Tag are the same field.

- `launch.ks` filters by `part:TAG:STARTSWITH("booster")` to find recoverable boosters
- `PROCESSOR("booster_1")` works because it matches this same tag

The main vessel kOS processor must have Name Tag `launch_vessel` (set this in the VAB).

## Launching

**From PowerShell** (handles everything — booster setup + launch):
```powershell
# Normal launch (runs test.ks first automatically)
.\launch.ps1

# Test only — runs test.ks without launching
.\launch.ps1 -TestOnly

# With live flight.log output
.\launch.ps1 -MonitorLog

# Override CPU indices if vessel lineup changes
.\launch.ps1 -MainCPU 1 -BoosterCPUs 2,3
```

`launch.ps1` does three things in order:
1. Copies `autoland_staging.ks` to each booster processor as the boot file
2. Runs `launch.ks` on the main vessel CPU
3. Optionally streams `flight.log` to the console

**From kOS terminal directly:**
```
// Pre-flight check:
SWITCH TO 0.
RUN test.

// Launch (after manually staging engines):
SWITCH TO 0.
RUN launch.
```

## FMRS + Physics Range Extender (Hybrid Workflow)

Two mods enable the recommended hybrid approach for booster recovery:

### Physics Range Extender (PRE)
Extends the physics bubble so both vessels run kOS simultaneously during
early flight. Recommended setting: **100 km** (covers boostback phase for
most ascent profiles). Configure in `GameData/PhysicsRangeExtender/`.

During early flight within range, kOS runs on both vessels simultaneously.
Once the booster exceeds the extended range (typically mid-boostback), its
kOS pauses until it becomes the focused vessel again — this is unavoidable.

### FMRS Workflow
FMRS saves booster state at staging and lets you rewind after orbit is achieved:

1. `RUN test.` — pre-flight checks, arms boosters (Test 13)
2. `RUN launch.` — gravity turn, staging, circularization
3. After circularization, FMRS prompts to recover the booster
4. Rewind — FMRS loads the booster at the separation moment
5. kOS auto-activates `autoland_staging.ks` via the persisted BOOTFILENAME;
   it detects airborne state and goes directly into the landing sequence
6. Watch the booster land, then FMRS merges the timeline

### Airborne Boot Detection
`autoland_staging.ks` checks `SHIP:VELOCITY:SURFACE:MAG > 50 OR SHIP:ALTITUDE > 500`
at startup. If true, it skips the READY/DECOUPLE handshake and goes straight to
landing. This handles both the FMRS rewind case and any unexpected processor restart
mid-flight. Normal pad launches are unaffected (both conditions are false on the ground).

Check `booster_N.log` for `"Airborne boot detected"` (FMRS path) vs
`"Sent READY to launch_vessel"` (normal pad path).

## Keeping test.ks in Sync

`test.ks` is the primary debugging tool and **must be kept up to date**. After any change to the scripts:

- **New library function** → add a test case that calls it and prints its output
- **Config default changed** → update the matching hardcoded values in the relevant test (e.g. `TURN_SHAPE`, `TURN_START_ALTITUDE` in Test 8)
- **New launch validation added** → add the same check to the appropriate test section
- **Staging logic changed** → Test 4 must reflect the current detection approach

Test 4 must **always** print every `LiquidFuel` part's `DECOUPLEDIN` value and the result of `get_next_booster_stage()`. This is the first thing to check when staging isn't firing.

The test suite runs on the launchpad without launching — there is no cost to making it thorough.

## kOS Language Gotchas

**`@LAZYGLOBAL OFF.` is used everywhere.** This means:
- Every variable must be declared before use: `GLOBAL x IS 0.` or `LOCAL x IS 0.`
- `SET x TO value.` is assignment only — it will error if `x` hasn't been declared
- `DECLARE GLOBAL x.` without `IS value` is a **syntax error**

**Resources live on parts, not engines:**
- `eng:RESOURCES` does not exist on `EngineValue` — this will crash
- Use `SHIP:PARTS` and `part:RESOURCES` to read fuel levels

**Staging:**
- `part:DECOUPLEDIN` = the stage number at which that part separates from the vessel
- Stages count **down** (7→6→5…), so the **highest** `DECOUPLEDIN` among current parts = the next group to separate
- Do not rely on `STAGE:NUMBER` matching `DECOUPLEDIN` — use `get_next_booster_stage()` from `ascent.ks` instead
- `get_booster_decoupledin_values()` finds DECOUPLEDIN values of staging groups containing a "booster_*" tagged kOS processor — only those groups get threshold-based early staging; all others use flameout detection
- Boosters must stage with fuel remaining (default threshold: 20%) so they have delta-v for boostback and landing

**Atmosphere:**
- Use `BODY:ATM:HEIGHT` instead of hardcoding `70000` — works correctly for any body
- **No non-ASCII in string literals** — em dashes, smart quotes, etc. cause `Unexpected token` parse errors. Comments are fine; strings must be plain ASCII.
- Kerbin's atmosphere ends at exactly 70 km

**Gravity turn shape:**
- `pitch = 90 * (1 - t^TURN_SHAPE)` where `t` is the fraction through the turn altitude range
- `TURN_SHAPE < 1`: turns aggressively early (dangerous in thick lower atmosphere)
- `TURN_SHAPE > 1`: stays near-vertical longer, turns later — correct for Kerbin
- Current default: `1.5` (starts at 1500m, completes by 50km)

## Logging

- `LOG_FILE` (declared in `util.ks`) controls where all output goes — default `0:/flight.log`
- `log_message(msg)` — always prints to screen + file, prepends mission timestamp
- `plog(msg)` — always prints to screen + file, no timestamp (used in test.ks)
- `debug(msg)` — only prints/logs when `DEBUG_MODE IS TRUE`
- `test.ks` redirects `LOG_FILE` to `0:/test_results.txt` and clears it on each run
- `launch.ks` clears `flight.log` at the start of each mission
