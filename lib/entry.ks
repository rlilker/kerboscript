// =========================================================================
// ENTRY LIBRARY (entry.ks)
// =========================================================================
// Entry burn and descent management
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").
RUNONCEPATH("0:/lib/guidance.ks").

// =========================================================================
// ENTRY BURN
// =========================================================================

// Execute entry burn if speed is too high
FUNCTION check_and_execute_entry_burn {
    PARAMETER speed_threshold IS 800, altitude_threshold IS 15000.

    // Check if we're approaching entry burn conditions
    IF SHIP:ALTITUDE < altitude_threshold AND
       SHIP:VELOCITY:SURFACE:MAG > speed_threshold {

        log_message("Entry burn triggered - speed: " +
                   ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " m/s").

        execute_entry_burn().
        RETURN TRUE.
    }

    RETURN FALSE.
}

// Execute short entry burn to reduce speed
FUNCTION execute_entry_burn {
    PARAMETER burn_duration IS 5, throttle_level IS 0.3.

    log_message("Executing entry burn...").

    LOCAL start_speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL start_time IS TIME:SECONDS.

    LOCK STEERING TO RETROGRADE.
    LOCK THROTTLE TO throttle_level.

    WAIT burn_duration.

    LOCK THROTTLE TO 0.

    LOCAL end_speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL speed_reduction IS start_speed - end_speed.

    log_message("Entry burn complete. Speed reduced by " +
               ROUND(speed_reduction, 0) + " m/s").
}

// =========================================================================
// DESCENT MONITORING
// =========================================================================

// Monitor descent and deploy airbrakes at appropriate altitude
FUNCTION manage_descent {
    PARAMETER airbrake_altitude IS 40000.

    // Maintain retrograde orientation
    LOCK STEERING TO RETROGRADE.

    // Monitor for airbrake deployment
    IF SHIP:ALTITUDE < airbrake_altitude AND SHIP:ALTITUDE > 1000 {
        IF NOT BRAKES {
            deploy_airbrakes().
            log_message("Airbrakes deployed at " + ROUND(SHIP:ALTITUDE/1000, 1) + " km").
        }
    }

    // Continuous telemetry display
    PRINT "Altitude: " + ROUND(SHIP:ALTITUDE/1000, 1) + " km          " AT(0, 10).
    PRINT "Speed: " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " m/s          " AT(0, 11).
}

// =========================================================================
// DESCENT PHASE CONTROL
// =========================================================================

// Coast through atmosphere maintaining retrograde
FUNCTION coast_to_landing_altitude {
    PARAMETER landing_start_altitude IS 5000, target_latlng IS LATLNG(0, 0).

    log_message("Coasting to landing altitude...").

    // Enable RCS for stability
    RCS ON.

    LOCAL last_update IS TIME:SECONDS.

    UNTIL get_true_altitude() < landing_start_altitude {
        // Maintain retrograde with slight correction toward target
        IF great_circle_distance(SHIP:GEOPOSITION, target_latlng) > 500 {
            LOCK STEERING TO steer_retrograde_with_correction(target_latlng, 0.3).
        }
        ELSE {
            LOCK STEERING TO RETROGRADE.
        }

        // Deploy airbrakes if in atmosphere
        IF SHIP:ALTITUDE < 40000 AND SHIP:ALTITUDE > 1000 {
            IF NOT BRAKES {
                deploy_airbrakes().
            }
        }

        // Update telemetry every second
        IF TIME:SECONDS - last_update > 1.0 {
            manage_descent(40000).
            LOCAL airbrake_status IS "".
            IF BRAKES { SET airbrake_status TO "Airbrakes: DEPLOYED". }
            ELSE { SET airbrake_status TO "Airbrakes: retracted". }
            show_booster_hud("DESCENT", airbrake_status).
            SET last_update TO TIME:SECONDS.
        }

        WAIT 0.1.
    }

    log_message("Reached landing altitude: " + ROUND(get_true_altitude(), 0) + " m").
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL entry_loaded IS TRUE.
