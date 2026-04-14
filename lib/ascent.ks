// =========================================================================
// ASCENT LIBRARY (ascent.ks)
// =========================================================================
// Gravity turn calculations and staging management
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").

// =========================================================================
// STAGING STATE
// =========================================================================

GLOBAL LAST_STAGE_TIME IS 0.

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

// Calculate throttle to maintain target time-to-apoapsis.
// Prevents apoapsis from "running away" too far ahead of the vessel.
FUNCTION get_eta_throttle {
    PARAMETER target_eta, margin IS 10.

    // No meaningful ETA while below the turn start altitude
    IF SHIP:ALTITUDE < TURN_START_ALTITUDE { RETURN 1.0. }

    LOCAL current_eta IS ETA:APOAPSIS.

    // If ETA is too high, reduce throttle.
    IF current_eta > (target_eta + margin) {
        // Linear reduction: starts at target+margin, reaches 0.5 at target+2*margin
        LOCAL reduction IS 1.0 - (current_eta - (target_eta + margin)) / margin.
        RETURN MAX(0.5, reduction).
    }

    RETURN 1.0.
}

// Combined throttle control (takes minimum of all limits)
FUNCTION get_ascent_throttle {
    PARAMETER target_ap, max_q.

    LOCAL q_throttle IS get_q_limited_throttle(max_q).
    LOCAL ap_throttle IS get_apoapsis_throttle(target_ap, SHIP:APOAPSIS).
    LOCAL eta_throttle IS get_eta_throttle(ASCENT_ETA_APOAPSIS_TARGET, 15).

    RETURN MIN(q_throttle, MIN(ap_throttle, eta_throttle)).
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

// Get the highest DECOUPLEDIN value among all booster-tagged kOS processors.
// The kOS processor often sits on a structural adapter one stage above the fuel tanks,
// so this gives the upper bound when scanning the full booster assembly for fuel.
FUNCTION get_max_booster_decoupledin {
    LOCAL max_dcpl IS 0.
    FOR part IN SHIP:PARTS {
        IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
            IF part:DECOUPLEDIN > max_dcpl { SET max_dcpl TO part:DECOUPLEDIN. }
        }
    }
    RETURN max_dcpl.
}

// Get the DECOUPLEDIN value of the next staging group that will remove liquid fuel.
// Filters out stages that have already been fired (activation stages).
FUNCTION get_next_fuel_stage {
    LOCAL max_dcpl IS -1.
    LOCAL current_stg IS STAGE:NUMBER.
    FOR part IN SHIP:PARTS {
        LOCAL d IS part:DECOUPLEDIN.
        // Only consider stages that haven't been fired yet (d <= current_stg)
        IF d >= 0 AND d <= current_stg {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" AND res:AMOUNT > 0.1 {
                    IF d > max_dcpl { SET max_dcpl TO d. }
                }
            }
        }
    }
    RETURN max_dcpl.
}

// Get the DECOUPLEDIN values of ALL staging groups that contain parts
// belonging to a booster (tagged "booster_*").
FUNCTION get_booster_decoupledin_values {
    LOCAL result IS LIST().
    FOR part IN SHIP:PARTS {
        IF part:TAG:STARTSWITH("booster") {
            IF part:DECOUPLEDIN >= 0 AND NOT result:CONTAINS(part:DECOUPLEDIN) {
                result:ADD(part:DECOUPLEDIN).
            }
        }
    }
    RETURN result.
}

// Check if a specific staging group contains booster parts.
FUNCTION is_booster_stage {
    PARAMETER stg.
    LOCAL booster_stages IS get_booster_decoupledin_values().
    RETURN booster_stages:CONTAINS(stg).
}

// Alias for telemetry compatibility in launch.ks and test.ks
FUNCTION get_next_booster_stage {
    RETURN get_next_fuel_stage().
}

// Get the total fuel percentage of the booster tanks that are due to be decoupled.
// Identifies the highest DECOUPLEDIN stage S among booster-tagged parts, then checks
// fuel capacity at both S and S-1, monitoring whichever holds more fuel. This handles
// two booster configurations automatically:
//   - kOS co-located with tanks (same DECOUPLEDIN, e.g. booster_3): primary fuel is at S
//   - kOS adapter one stage above tanks (e.g. boosters 1+2): primary fuel is at S-1
FUNCTION get_booster_assembly_fuel {
    LOCAL max_b_stg IS -1.
    FOR part IN SHIP:PARTS {
        IF part:TAG:STARTSWITH("booster") {
            IF part:DECOUPLEDIN > max_b_stg AND part:DECOUPLEDIN <= STAGE:NUMBER {
                SET max_b_stg TO part:DECOUPLEDIN.
            }
        }
    }

    IF max_b_stg = -1 { RETURN -1. }

    // Measure LiquidFuel at S and S-1, pick the stage with greater capacity.
    LOCAL fuel_s IS 0.   LOCAL cap_s IS 0.
    LOCAL fuel_sm IS 0.  LOCAL cap_sm IS 0.
    FOR part IN SHIP:PARTS {
        FOR res IN part:RESOURCES {
            IF res:NAME = "LiquidFuel" {
                IF part:DECOUPLEDIN = max_b_stg {
                    SET fuel_s TO fuel_s + res:AMOUNT.
                    SET cap_s  TO cap_s  + res:CAPACITY.
                }
                IF part:DECOUPLEDIN = max_b_stg - 1 {
                    SET fuel_sm TO fuel_sm + res:AMOUNT.
                    SET cap_sm  TO cap_sm  + res:CAPACITY.
                }
            }
        }
    }

    IF cap_s >= cap_sm {
        IF cap_s > 0 { RETURN (fuel_s / cap_s) * 100. }
    } ELSE {
        IF cap_sm > 0 { RETURN (fuel_sm / cap_sm) * 100. }
    }
    RETURN 100.
}

// Log the fuel levels and booster status of all upcoming stages.
FUNCTION log_staging_status {
    tdebug("--- Staging Stack Diagnostic ---").
    LOCAL stg_map IS LEXICON().
    FOR part IN SHIP:PARTS {
        LOCAL d IS part:DECOUPLEDIN.
        IF d >= 0 {
            LOCAL key IS d:TOSTRING.
            IF NOT stg_map:HASKEY(key) {
                stg_map:ADD(key, LIST(0, 0, FALSE)).
            }
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" {
                    SET stg_map[key][0] TO stg_map[key][0] + res:AMOUNT.
                    SET stg_map[key][1] TO stg_map[key][1] + res:CAPACITY.
                }
            }
            IF part:TAG:STARTSWITH("booster") {
                SET stg_map[key][2] TO TRUE.
            }
        }
    }
    
    FOR k IN stg_map:KEYS {
        LOCAL d IS k:TONUMBER().
        IF d <= STAGE:NUMBER {
            LOCAL f IS stg_map[k][0].
            LOCAL c IS stg_map[k][1].
            LOCAL b IS stg_map[k][2].
            IF c > 0 {
                tdebug(" STG " + d + ": " + ROUND(f/c*100,1) + "% fuel, BoosterTag=" + b).
            }
        }
    }
    
    LOCAL b_fuel IS get_booster_assembly_fuel().
    tdebug(" Target Booster Tank Fuel (Decoupler Stage): " + ROUND(b_fuel, 1) + "%").
    tdebug("--------------------------------").
}

// Check if staging is needed.
FUNCTION check_staging_needed {
    PARAMETER fuel_threshold.

    LOCAL now IS TIME:SECONDS.
    LOCAL time_since_stg IS now - LAST_STAGE_TIME.

    // 1. Enforce minimum staging interval
    IF time_since_stg < STAGING_MIN_INTERVAL {
        RETURN FALSE.
    }

    // 2. Periodic Diagnostic Logging (every 5s)
    IF MOD(ROUND(now), 5) = 0 {
        log_staging_status().
    }

    // 3. Flameout detection (Primary trigger for all core/upper stages)
    FOR eng IN SHIP:ENGINES {
        IF eng:IGNITION AND eng:FLAMEOUT {
            tlog("Staging: Flameout detected").
            SET LAST_STAGE_TIME TO now.
            RETURN TRUE.
        }
    }

    // 4. Booster Assembly Threshold
    // If the next boosters-to-decouple drop below threshold, stage.
    LOCAL b_fuel IS get_booster_assembly_fuel().
    IF b_fuel >= 0 AND b_fuel < fuel_threshold {
        tlog("Staging: Booster assembly at " + ROUND(b_fuel, 1) + "%").
        SET LAST_STAGE_TIME TO now.
        RETURN TRUE.
    }

    // 5. Dead-Engine Recovery (e.g. activation stage with no engines)
    IF SHIP:MAXTHRUST = 0 AND STAGE:NUMBER > 0 AND time_since_stg > 2.0 {
        tlog("Staging: No thrust detected").
        SET LAST_STAGE_TIME TO now.
        RETURN TRUE.
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
