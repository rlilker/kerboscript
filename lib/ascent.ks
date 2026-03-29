// =========================================================================
// ASCENT LIBRARY (ascent.ks)
// =========================================================================
// Gravity turn calculations and staging management
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").

// =========================================================================
// GRAVITY TURN PROFILE
// =========================================================================

// Calculate target pitch angle for gravity turn
FUNCTION get_target_pitch {
    PARAMETER current_altitude, turn_start_alt, turn_end_alt, turn_shape.

    IF current_altitude < turn_start_alt {
        RETURN 90.  // Vertical ascent
    }
    ELSE IF current_altitude > turn_end_alt {
        RETURN 0.   // Horizontal (follow prograde)
    }
    ELSE {
        // Smooth polynomial turn
        LOCAL turn_fraction IS (current_altitude - turn_start_alt) /
                                (turn_end_alt - turn_start_alt).
        LOCAL pitch IS 90 * (1 - turn_fraction^turn_shape).
        RETURN pitch.
    }
}

// Calculate launch azimuth for target inclination
FUNCTION get_launch_azimuth {
    PARAMETER target_inclination.

    // Simplified azimuth calculation (works near equator)
    // For more accuracy, use full spherical trigonometry

    IF target_inclination = 0 {
        RETURN 90.  // Due east for equatorial orbit
    }

    LOCAL inertial_azimuth IS ARCSIN(
        MAX(-1, MIN(1, COS(target_inclination) / COS(SHIP:LATITUDE)))
    ).

    // Choose prograde (eastward) launch
    IF target_inclination >= 0 {
        RETURN 90 - inertial_azimuth.
    }
    ELSE {
        RETURN 90 + inertial_azimuth.
    }
}

// =========================================================================
// THROTTLE CONTROL
// =========================================================================

// Calculate throttle to maintain max dynamic pressure limit
FUNCTION get_q_limited_throttle {
    PARAMETER max_q.

    // Dynamic pressure: Q = 0.5 * rho * v^2
    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL rho IS get_atmospheric_density(SHIP:ALTITUDE).
    LOCAL current_q IS 0.5 * rho * speed^2.

    IF current_q > max_q {
        // Reduce throttle proportionally
        LOCAL throttle_reduction IS SQRT(max_q / current_q).
        RETURN MAX(0.5, throttle_reduction).  // Never go below 50%
    }

    RETURN 1.0.  // Full throttle
}

// Calculate throttle to approach target apoapsis smoothly
FUNCTION get_apoapsis_throttle {
    PARAMETER target_ap, current_ap, approach_margin IS 5000.

    // How close are we to target?
    LOCAL error IS target_ap - current_ap.

    // If we're close, reduce throttle
    IF error < approach_margin {
        LOCAL throttle_val IS error / approach_margin.
        RETURN MAX(0.0, MIN(1.0, throttle_val)).
    }

    RETURN 1.0.  // Full throttle when far from target
}

// Combined throttle control (takes minimum of all limits)
FUNCTION get_ascent_throttle {
    PARAMETER target_ap, max_q.

    LOCAL q_throttle IS get_q_limited_throttle(max_q).
    LOCAL ap_throttle IS get_apoapsis_throttle(target_ap, SHIP:APOAPSIS).

    RETURN MIN(q_throttle, ap_throttle).
}

// =========================================================================
// STAGING MANAGEMENT
// =========================================================================

// Get total liquid fuel in parts with a specific DECOUPLEDIN value
FUNCTION get_stage_fuel {
    PARAMETER stg.
    LOCAL fuel IS 0.
    FOR part IN SHIP:PARTS {
        IF part:DECOUPLEDIN = stg {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" {
                    SET fuel TO fuel + res:AMOUNT.
                }
            }
        }
    }
    RETURN fuel.
}

// Get liquid fuel capacity in parts with a specific DECOUPLEDIN value
FUNCTION get_stage_fuel_capacity {
    PARAMETER stg.
    LOCAL fuel_max IS 0.
    FOR part IN SHIP:PARTS {
        IF part:DECOUPLEDIN = stg {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" {
                    SET fuel_max TO fuel_max + res:CAPACITY.
                }
            }
        }
    }
    RETURN fuel_max.
}

// Get fuel percentage for a specific DECOUPLEDIN stage group
FUNCTION get_stage_fuel_percent {
    PARAMETER stg.
    LOCAL fuel_max IS get_stage_fuel_capacity(stg).
    IF fuel_max > 0 {
        RETURN (get_stage_fuel(stg) / fuel_max) * 100.
    }
    RETURN 0.
}

// Get the DECOUPLEDIN values of staging groups that contain a booster kOS processor.
// Only these groups get threshold-based early staging; others use flameout-only.
FUNCTION get_booster_decoupledin_values {
    LOCAL result IS LIST().
    FOR part IN SHIP:PARTS {
        IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
            IF part:DECOUPLEDIN > 0 AND NOT result:CONTAINS(part:DECOUPLEDIN) {
                result:ADD(part:DECOUPLEDIN).
            }
        }
    }
    RETURN result.
}

// Find the DECOUPLEDIN value of the staging group closest to empty.
// Only considers groups that contain a booster kOS processor (tagged "booster_*").
// Falls back to DECOUPLEDIN > 1 approach if no booster processors are found.
FUNCTION get_next_booster_stage {
    LOCAL booster_dcpl IS get_booster_decoupledin_values().

    // Build a map of DECOUPLEDIN -> [fuel, capacity]
    LOCAL groups IS LEXICON().

    FOR part IN SHIP:PARTS {
        LOCAL dcpl IS part:DECOUPLEDIN.
        // Only track groups that are booster groups (or any >1 if no boosters defined)
        LOCAL include IS FALSE.
        IF booster_dcpl:LENGTH > 0 {
            SET include TO booster_dcpl:CONTAINS(dcpl).
        } ELSE {
            SET include TO dcpl > 1.
        }

        IF include {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" AND res:CAPACITY > 0 {
                    LOCAL key IS dcpl:TOSTRING.
                    IF NOT groups:HASKEY(key) {
                        groups:ADD(key, LIST(0, 0)).
                    }
                    SET groups[key][0] TO groups[key][0] + res:AMOUNT.
                    SET groups[key][1] TO groups[key][1] + res:CAPACITY.
                }
            }
        }
    }

    LOCAL best_stg IS -1.
    LOCAL best_pct IS 101.
    LOCAL fallback_stg IS -1.

    FOR key IN groups:KEYS {
        LOCAL stg IS key:TONUMBER(0).
        LOCAL fuel IS groups[key][0].
        LOCAL cap  IS groups[key][1].
        LOCAL pct  IS (fuel / cap) * 100.

        IF pct < 100 {
            IF pct < best_pct {
                SET best_pct TO pct.
                SET best_stg TO stg.
            }
        } ELSE {
            IF stg > fallback_stg { SET fallback_stg TO stg. }
        }
    }

    IF best_stg >= 0 { RETURN best_stg. }
    RETURN fallback_stg.
}

// Print staging diagnostic info (call with DEBUG_MODE = TRUE to see output)
FUNCTION debug_staging {
    debug("--- Staging Diagnostic ---").
    debug("STAGE:NUMBER = " + STAGE:NUMBER).
    FOR part IN SHIP:PARTS {
        FOR res IN part:RESOURCES {
            IF res:NAME = "LiquidFuel" AND res:CAPACITY > 0 {
                debug("  " + part:NAME + "  DECOUPLEDIN=" + part:DECOUPLEDIN +
                      "  LF=" + ROUND(res:AMOUNT,0) + "/" + ROUND(res:CAPACITY,0)).
            }
        }
    }
    LOCAL next_stg IS get_next_booster_stage().
    debug("Next booster stage group: DECOUPLEDIN=" + next_stg).
    IF next_stg >= 0 {
        debug("  Fuel in that group: " + ROUND(get_stage_fuel_percent(next_stg), 1) + "%").
    }
    debug("--------------------------").
}

// Check if staging is needed.
// STAGE_FUEL_THRESHOLD applies only to booster groups (tagged "booster_*" kOS processors).
// Non-booster groups use flameout detection only.
FUNCTION check_staging_needed {
    PARAMETER fuel_threshold.

    LOCAL next_stg IS get_next_booster_stage().
    LOCAL booster_dcpl IS get_booster_decoupledin_values().

    IF next_stg >= 0 {
        LOCAL fuel_max IS get_stage_fuel_capacity(next_stg).
        IF fuel_max > 0 {
            LOCAL fuel_pct IS (get_stage_fuel(next_stg) / fuel_max) * 100.
            // Only apply threshold staging if this is a booster group
            LOCAL is_booster_group IS booster_dcpl:LENGTH = 0 OR booster_dcpl:CONTAINS(next_stg).
            IF is_booster_group {
                debug("Booster fuel (DECOUPLEDIN=" + next_stg + "): " +
                      ROUND(fuel_pct, 1) + "% / threshold " + fuel_threshold + "%").
                RETURN fuel_pct < fuel_threshold.
            }
        }
    }

    // Fall back to flameout detection for non-booster stages and when no liquid fuel found
    LOCAL engines_collection IS LIST().
    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:IGNITION AND eng:FLAMEOUT AND eng:POSSIBLETHRUST > 10 {
            debug("Flameout trigger: " + eng:NAME +
                  " (" + ROUND(eng:POSSIBLETHRUST, 0) + " kN)").
            RETURN TRUE.
        }
    }

    RETURN FALSE.
}

// =========================================================================
// VESSEL CHECKS
// =========================================================================

// Check if vessel has probe core
FUNCTION has_probe_core {
    PARAMETER vessel_obj IS SHIP.

    FOR part IN vessel_obj:PARTS {
        IF part:HASMODULE("ModuleCommand") {
            LOCAL cmd_module IS part:GETMODULE("ModuleCommand").
            IF cmd_module:HASEVENT("Control From Here") {
                RETURN TRUE.
            }
        }
    }

    RETURN FALSE.
}

// Check if vessel has kOS processor
FUNCTION has_kos_processor {
    PARAMETER vessel_obj IS SHIP.

    FOR part IN vessel_obj:PARTS {
        IF part:HASMODULE("kOSProcessor") {
            RETURN TRUE.
        }
    }

    RETURN FALSE.
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL ascent_loaded IS TRUE.
