# GEMINI.md - KSP Launch & Booster Recovery System (Ike I)

## Project Overview
This project is a sophisticated **KerboScript (kOS)** autopilot system for Kerbal Space Program (KSP). It automates the entire flight lifecycle of the **Ike I** rocket, from a vertical gravity-turn launch to SpaceX-style **Return-To-Launch-Site (RTLS)** booster recovery.

### Key Technologies
- **KerboScript (kOS):** The primary scripting language.
- **PowerShell/Batch:** Used for project deployment, CPU monitoring, and terminal connectivity.
- **KSP Mods Support:** Integrated with **FMRS** (Flight Manager for Reusable Stages) and **Physics Range Extender (PRE)** for multi-vessel physics.

### Core Architecture
The system is modular, separating mission configuration from reusable flight logic.
- **Root Scripts:** Entry points for launch (`launch.ks`), booster landing (`autoland_staging.ks`), and testing (`test.ks`).
- **Library (`lib/`):** Specialized modules for guidance, ascent, circularization, landing, and telemetry.
- **Configuration:** All tunable parameters are centralized in `config.ks`.

---

## Development Conventions

### KerboScript Standards
- **Strict Mode:** Always use `@LAZYGLOBAL OFF.` at the top of every file.
- **Variable Declaration:** Every variable must be explicitly declared (e.g., `LOCAL x IS 0.` or `GLOBAL y IS 1.`).
- **Dependency Management:** Use `RUNONCEPATH("0:/lib/filename.ks").` to load libraries.
- **ASCII Only:** String literals must be plain ASCII to avoid kOS parse errors.

### Project Structure & Workflow
- **Naming Tags:** Use `booster_1`, `booster_2`, etc., for booster CPUs and `launch_vessel` for the main CPU (set in VAB).
- **Staging Logic:** Avoid `STAGE:NUMBER` for fuel detection; use `get_next_fuel_stage()` and `get_booster_assembly_fuel()` from `lib/ascent.ks`.
- **Testing:** Always run `RUN 0:/test.` before a launch. Keep `test.ks` in sync with any library changes.

### Telemetry & Logging
- **tlog(msg):** Logs events to `0:/flight.log` and updates the HUD status row.
- **tdebug(msg):** Logs detailed info only if `DEBUG_MODE IS TRUE`.
- **plog(msg):** Scrolling print + log for initialization and testing.
- **HUDs:** Specialized HUD functions in `lib/telemetry.ks` provide refreshing terminal displays for launch and landing phases.

---

## Building and Running

### Pre-Flight Testing
Ensure all systems are ready by running the test suite on the launchpad:
```kerboscript
SWITCH TO 0.
RUN test.
```

### Launching
To perform a full mission from the host machine (PowerShell):
```powershell
.\launch.ps1
```
Or directly from the kOS terminal:
```kerboscript
RUN launch.
```

### Booster Recovery
Boosters are automatically handled by `autoland_staging.ks`. If using **FMRS**, the script detects an "Airborne boot" and resumes the landing sequence from the separation point.

---

## Key Files
- `config.ks`: Central mission parameters (target orbit, turn shape, fuel thresholds).
- `launch.ks`: Main launch loop (ascent -> staging -> orbit).
- `autoland_staging.ks`: Booster landing logic (boostback -> entry -> suicide burn).
- `lib/util.ks`: Math, LATLNG math, and physics utilities.
- `lib/ascent.ks`: Gravity turn profiles and staging management.
- `lib/guidance.ks`: Trajectory prediction and impact calculation.
- `lib/telemetry.ks`: Unified logging and HUD interface.
- `test.ks`: Comprehensive pre-flight validation suite.
- `launch.ps1`: Automated deployment and launch orchestration script.

---

## Troubleshooting & Tuning
- **Boosters land short:** Increase `BOOSTBACK_MAX_BURN_TIME` in `config.ks`.
- **Hard landings:** Increase `SUICIDE_MARGIN` in `config.ks`.
- **Staging fails:** Check `test.ks` (Test 4) for `DECOUPLEDIN` values and fuel detection.
- **Connectivity:** Use `connect.bat` to open a telnet session to the kOS server (127.0.0.1:5410).
