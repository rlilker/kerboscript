// =========================================================================
// TELEMETRY (lib/telemetry.ks)
// =========================================================================
// Unified logging and refreshing terminal HUD interface.
//
// LOGGING
//   tlog(msg)    -- event log to file with timestamp; updates HUD status row.
//                   Does NOT print to terminal -- the HUD shows it instead.
//   tdebug(msg)  -- debug log to file + HUD debug row (DEBUG_MODE = TRUE only)
//   plog(msg)    -- scrolling print + log; used in test.ks and init phases
//
// HUD (refreshing AT-based terminal display)
//   show_launch_hud(phase, alt, ap, pitch, throttle, b_pct, b_stg, stg_num)
//   show_booster_hud(phase, extra_line)  -- references BOOSTER_TARGET global
//   show_standby_hud()                  -- booster waiting for DECOUPLE
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").

// =========================================================================
// TELEMETRY STATE
// =========================================================================

// Most recent tlog/tdebug messages — shown in HUD status rows.
GLOBAL TEL_LAST_MSG IS "".
GLOBAL TEL_DEBUG_MSG IS "".
GLOBAL TEL_STAGE_WARN IS "".

// Booster landing target — set by autoland_staging.ks; referenced by show_booster_hud.
GLOBAL BOOSTER_TARGET IS LATLNG(0, 0).

// =========================================================================
// LOGGING
// =========================================================================

// Event log: timestamp + write to file; sets TEL_LAST_MSG for HUD status row.
// Terminal display is handled by the HUD functions, not here.
FUNCTION tlog {
    PARAMETER message.
    LOCAL entry IS "[" + format_time(MISSIONTIME) + "] " + message.
    IF LOG_FILE:STARTSWITH("0:/") {
        IF HOMECONNECTION:ISCONNECTED { LOG entry TO LOG_FILE. }
    } ELSE {
        LOG entry TO LOG_FILE.
    }
    SET TEL_LAST_MSG TO message.
}

// Debug log: only active when DEBUG_MODE = TRUE.
// Writes timestamped [DBG] entry to file and updates HUD debug row.
FUNCTION tdebug {
    PARAMETER message.
    IF NOT DEBUG_MODE { RETURN. }
    LOCAL entry IS "[DBG " + format_time(MISSIONTIME) + "] " + message.
    IF LOG_FILE:STARTSWITH("0:/") {
        IF HOMECONNECTION:ISCONNECTED { LOG entry TO LOG_FILE. }
    } ELSE {
        LOG entry TO LOG_FILE.
    }
    SET TEL_DEBUG_MSG TO message.
}

// Scrolling print + log: for test.ks output and initialization messages.
// Use this before the HUD is active (pre-flight, test suite, error messages).
FUNCTION plog {
    PARAMETER message.
    PRINT message.
    LOG message TO LOG_FILE.
}

// =========================================================================
// LAUNCH HUD  (rows 0-7, optional row 8 in debug mode)
// =========================================================================

FUNCTION show_launch_hud {
    PARAMETER phase_name, alt_km, ap_km, pitch_deg, throttle_pct,
              b_fuel_pct, b_stg, stg_num.

    PRINT "=== LAUNCH AUTOPILOT ==============================  " AT(0, 0).
    PRINT "Phase:    " + phase_name + "                          " AT(0, 1).
    PRINT "Altitude: " + alt_km + " km                          " AT(0, 2).
    PRINT "Apoapsis: " + ap_km + " km                           " AT(0, 3).
    PRINT "Pitch:    " + pitch_deg + "deg    Throttle: " + throttle_pct + "%     " AT(0, 4).
    PRINT "Booster:  " + b_fuel_pct + "% fuel  (DCPL=" + b_stg + " STG=" + stg_num + ")    " AT(0, 5).
    PRINT "Warning:  " + TEL_STAGE_WARN + "                              " AT(0, 6).
    PRINT "Status:   " + TEL_LAST_MSG + "                        " AT(0, 7).
    IF DEBUG_MODE {
        PRINT "Debug:    " + TEL_DEBUG_MSG + "                    " AT(0, 8).
    }
}

// =========================================================================
// BOOSTER STANDBY HUD  (rows 0-4)
// =========================================================================
// Shown while the booster processor is armed and waiting for DECOUPLE.

FUNCTION show_standby_hud {
    PRINT "=== BOOSTER STANDBY - Armed, waiting for decouple =  " AT(0, 0).
    PRINT "Alt:      " + ROUND(SHIP:ALTITUDE/1000, 1) + " km                    " AT(0, 1).
    PRINT "Speed:    " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " m/s               " AT(0, 2).
    PRINT "Apoapsis: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km                " AT(0, 3).
    PRINT "Status:   " + TEL_LAST_MSG + "                          " AT(0, 4).
}

// =========================================================================
// BOOSTER LANDING HUD  (rows 0-6, optional row 7 in debug mode)
// =========================================================================
// Used by all booster landing phases (flip, boostback, entry, descent, landing).
// References BOOSTER_TARGET global (set during initialize_landing_system).

FUNCTION show_booster_hud {
    PARAMETER phase_name, extra_line IS "".

    LOCAL alt_km IS ROUND(SHIP:ALTITUDE/1000, 1).
    LOCAL spd IS ROUND(SHIP:VELOCITY:SURFACE:MAG, 0).

    LOCAL fuel IS 0.
    LOCAL fuel_cap IS 0.
    FOR res IN SHIP:RESOURCES {
        IF res:NAME = "LiquidFuel" {
            SET fuel TO fuel + res:AMOUNT.
            SET fuel_cap TO fuel_cap + res:CAPACITY.
        }
    }
    LOCAL fuel_pct IS 0.
    IF fuel_cap > 0 { SET fuel_pct TO ROUND((fuel / fuel_cap) * 100, 1). }

    LOCAL twr IS get_twr().
    LOCAL dist_km IS ROUND(great_circle_distance(SHIP:GEOPOSITION, BOOSTER_TARGET)/1000, 1).

    PRINT "=== BOOSTER LANDING AUTOPILOT ===========  " AT(0, 0).
    PRINT "Phase:  " + phase_name + "                          " AT(0, 1).
    PRINT "Alt:    " + alt_km + " km     Spd: " + spd + " m/s          " AT(0, 2).
    PRINT "Fuel:   " + ROUND(fuel, 0) + " LF (" + fuel_pct + "%)  TWR: " + ROUND(twr, 2) + "          " AT(0, 3).
    PRINT "Target: " + dist_km + " km from KSC                          " AT(0, 4).
    IF extra_line:LENGTH > 0 {
        PRINT extra_line + "                          " AT(0, 5).
    } ELSE {
        PRINT "                                          " AT(0, 5).
    }
    PRINT "Status: " + TEL_LAST_MSG + "                          " AT(0, 6).
    IF DEBUG_MODE {
        PRINT "Debug:  " + TEL_DEBUG_MSG + "                      " AT(0, 7).
    }
}

// =========================================================================

GLOBAL telemetry_loaded IS TRUE.
