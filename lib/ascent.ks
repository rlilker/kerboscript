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

// Get total liquid fuel in current stage
FUNCTION get_stage_fuel {
    PARAMETER stg.

    LOCAL fuel IS 0.
    LOCAL engines_collection IS LIST().

    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:STAGE = stg {
            // Get fuel from this engine's fuel tanks
            // Check if engine has RESOURCES suffix
            IF eng:HASRESOURCES {
                FOR res IN eng:RESOURCES {
                    IF res:NAME = "LIQUIDFUEL" {
                        SET fuel TO fuel + res:AMOUNT.
                    }
                }
            }
        }
    }

    RETURN fuel.
}

// Get maximum liquid fuel capacity in current stage
FUNCTION get_stage_fuel_capacity {
    PARAMETER stg.

    LOCAL fuel_max IS 0.
    LOCAL engines_collection IS LIST().

    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:STAGE = stg {
            // Check if engine has RESOURCES suffix
            IF eng:HASRESOURCES {
                FOR res IN eng:RESOURCES {
                    IF res:NAME = "LIQUIDFUEL" {
                        SET fuel_max TO fuel_max + res:CAPACITY.
                    }
                }
            }
        }
    }

    RETURN fuel_max.
}

// Get fuel percentage in current stage
FUNCTION get_stage_fuel_percent {
    PARAMETER stg.

    LOCAL fuel IS get_stage_fuel(stg).
    LOCAL fuel_max IS get_stage_fuel_capacity(stg).

    IF fuel_max > 0 {
        RETURN (fuel / fuel_max) * 100.
    }

    RETURN 0.
}

// Check if current stage has active engines
FUNCTION stage_has_engines {
    PARAMETER stg.

    LOCAL engines_collection IS LIST().
    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:STAGE = stg AND NOT eng:FLAMEOUT {
            RETURN TRUE.
        }
    }

    RETURN FALSE.
}

// Check if staging is needed
FUNCTION check_staging_needed {
    PARAMETER fuel_threshold.

    // Get current stage fuel percentage
    LOCAL fuel_pct IS get_stage_fuel_percent(STAGE:NUMBER).

    // Stage if fuel is depleted
    IF fuel_pct < fuel_threshold AND stage_has_engines(STAGE:NUMBER) {
        RETURN TRUE.
    }

    // Also check for flameout
    LOCAL all_flameout IS TRUE.
    LOCAL engines_collection IS LIST().
    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:IGNITION AND NOT eng:FLAMEOUT {
            SET all_flameout TO FALSE.
            BREAK.
        }
    }

    RETURN all_flameout.
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
