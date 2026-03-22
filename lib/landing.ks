// =========================================================================
// LANDING LIBRARY (landing.ks)
// =========================================================================
// Suicide burn calculation and touchdown control
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").
RUNONCEPATH("0:/lib/guidance.ks").

// =========================================================================
// SUICIDE BURN CALCULATION
// =========================================================================

// Calculate altitude at which to start suicide burn
FUNCTION calculate_suicide_burn_altitude {
    PARAMETER safety_margin IS 1.20.

    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.

    // Maximum deceleration available
    LOCAL a_max IS SHIP:MAXTHRUST / SHIP:MASS.
    LOCAL a_net IS a_max - g.

    IF a_net <= 0 {
        RETURN 99999.  // Can't stop - TWR too low
    }

    // Stopping distance: d = v^2 / (2 * a_net)
    LOCAL stop_dist IS speed^2 / (2 * a_net).

    // Apply safety margin
    LOCAL burn_alt IS stop_dist * safety_margin.

    RETURN burn_alt.
}

// Check if it's time to start suicide burn
FUNCTION should_start_suicide_burn {
    PARAMETER safety_margin IS 1.20.

    LOCAL burn_alt IS calculate_suicide_burn_altitude(safety_margin).
    LOCAL current_altitude_m IS get_true_altitude().

    RETURN current_altitude_m <= burn_alt.
}

// =========================================================================
// ADAPTIVE THROTTLE CONTROL
// =========================================================================

// Calculate throttle needed to maintain suicide burn profile
FUNCTION calculate_suicide_throttle {
    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL altitude_m IS get_true_altitude().
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.

    // Avoid division by zero
    IF altitude_m < 1 {
        RETURN 0.
    }

    // Required deceleration to stop at current altitude
    // a = v^2 / (2 * h)
    LOCAL required_accel IS speed^2 / (2 * altitude_m).

    // Throttle needed to achieve this (accounting for gravity)
    LOCAL throttle_val IS (required_accel + g) * SHIP:MASS / SHIP:MAXTHRUST.

    // Clamp to valid range
    RETURN clamp(throttle_val, 0, 1).
}

// =========================================================================
// LANDING STEERING
// =========================================================================

// Get steering for landing approach
FUNCTION get_landing_steering {
    PARAMETER target_latlng, final_approach_alt IS 50.

    LOCAL altitude_m IS get_true_altitude().
    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.

    // Below final approach altitude: go fully vertical
    IF altitude_m < final_approach_alt {
        RETURN SHIP:UP.
    }

    // Above final approach: blend retrograde with vertical based on altitude
    LOCAL blend_factor IS clamp(1 - (altitude_m - final_approach_alt) / 1000, 0, 1).

    // Also add lateral correction toward target
    LOCAL distance_to_target IS great_circle_distance(SHIP:GEOPOSITION, target_latlng).

    IF distance_to_target > 50 AND altitude_m > 100 {
        // Still have time to correct
        LOCAL retro_corrected IS steer_retrograde_with_correction(target_latlng, 0.5).
        RETURN blend_steering(retro_corrected, SHIP:UP, blend_factor).
    }
    ELSE {
        // Close to target or very low - just blend retrograde and vertical
        RETURN blend_steering(RETROGRADE:VECTOR, SHIP:UP:VECTOR, blend_factor).
    }
}

// =========================================================================
// SUICIDE BURN EXECUTION
// =========================================================================

// Execute suicide burn to touchdown
FUNCTION execute_suicide_burn {
    PARAMETER target_latlng, safety_margin IS 1.20.

    log_message("Starting suicide burn...").

    LOCAL gear_deployed IS FALSE.
    LOCAL final_approach IS FALSE.

    RCS ON.

    UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
        LOCAL altitude_m IS get_true_altitude().
        LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.

        // Deploy landing gear at appropriate altitude
        IF altitude_m < 100 AND NOT gear_deployed {
            deploy_gear().
            SET gear_deployed TO TRUE.
            log_message("Landing gear deployed").
        }

        // Retract airbrakes during landing burn
        IF altitude_m < 2000 {
            retract_airbrakes().
        }

        // Switch to final approach mode below 50m
        IF altitude_m < 50 AND NOT final_approach {
            SET final_approach TO TRUE.
            log_message("Final approach - transitioning to vertical").
        }

        // Calculate steering
        LOCAL steer_vec IS get_landing_steering(target_latlng, 50).
        LOCK STEERING TO steer_vec.

        // Calculate throttle
        LOCAL throttle_val IS calculate_suicide_throttle().

        // Fine control near ground
        IF altitude_m < 20 {
            // Very gentle throttle near ground
            IF speed < 5 {
                SET throttle_val TO clamp(speed / 10, 0.05, 0.3).
            }
        }

        // Kill throttle at very low altitude if nearly stopped
        IF altitude_m < 0.5 OR (altitude_m < 3 AND speed < 0.5) {
            SET throttle_val TO 0.
        }

        LOCK THROTTLE TO throttle_val.

        // Display telemetry
        PRINT "Altitude: " + ROUND(altitude_m, 1) + " m          " AT(0, 18).
        PRINT "Speed: " + ROUND(speed, 1) + " m/s          " AT(0, 19).
        PRINT "Throttle: " + ROUND(throttle_val * 100, 0) + "%          " AT(0, 20).

        WAIT 0.05.  // High update rate for precision
    }

    LOCK THROTTLE TO 0.
    log_message("TOUCHDOWN!").

    // Post-landing status
    LOCAL touchdown_speed IS SHIP:VELOCITY:SURFACE:MAG.
    log_message("Touchdown speed: " + ROUND(touchdown_speed, 2) + " m/s").

    LOCAL landing_error IS great_circle_distance(SHIP:GEOPOSITION, target_latlng).
    log_message("Landing error: " + ROUND(landing_error, 1) + " m").
}

// =========================================================================
// COMPLETE LANDING SEQUENCE
// =========================================================================

// Execute complete landing from current altitude
FUNCTION execute_landing {
    PARAMETER target_latlng, safety_margin IS 1.20.

    log_message("Initiating landing sequence...").
    log_message("Target: LAT=" + ROUND(target_latlng:LAT, 4) +
               " LON=" + ROUND(target_latlng:LNG, 4)).

    // Wait for suicide burn altitude
    log_message("Waiting for suicide burn altitude...").

    UNTIL should_start_suicide_burn(safety_margin) {
        LOCAL altitude_m IS get_true_altitude().
        LOCAL burn_alt IS calculate_suicide_burn_altitude(safety_margin).

        // Steer retrograde with correction
        LOCK STEERING TO steer_retrograde_with_correction(target_latlng, 0.5).

        // Update display
        PRINT "Altitude: " + ROUND(altitude_m, 0) + " m          " AT(0, 16).
        PRINT "Burn alt: " + ROUND(burn_alt, 0) + " m          " AT(0, 17).

        WAIT 0.1.
    }

    // Execute suicide burn
    execute_suicide_burn(target_latlng, safety_margin).
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL landing_loaded IS TRUE.
