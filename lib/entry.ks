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

        tlog("Entry burn triggered - speed: " +
                   ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " m/s").

        execute_entry_burn().
        RETURN TRUE.
    }

    RETURN FALSE.
}

// Execute short entry burn to reduce speed
FUNCTION execute_entry_burn {
    PARAMETER burn_duration IS 5, throttle_level IS 0.3.

    tlog("Executing entry burn...").

    LOCAL start_speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL start_time IS TIME:SECONDS.

    LOCK STEERING TO RETROGRADE.
    LOCK THROTTLE TO throttle_level.

    WAIT burn_duration.

    LOCK THROTTLE TO 0.

    LOCAL end_speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL speed_reduction IS start_speed - end_speed.

    tlog("Entry burn complete. Speed reduced by " +
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
            tlog("Airbrakes deployed at " + ROUND(SHIP:ALTITUDE/1000, 1) + " km").
        }
    }

}

// =========================================================================
// DESCENT PHASE CONTROL
// =========================================================================

// Coast through atmosphere maintaining retrograde with active corrections.
// Prediction is scheduled (not every tick) to avoid kOS CPU overload.
// min_fuel: if > 0, skip engine nudges when LF at or below this (landing reserve guard).
FUNCTION coast_to_landing_altitude {
    PARAMETER landing_start_altitude IS 5000, target_latlng IS LATLNG(0, 0), min_fuel IS 0.

    tlog("Coasting to landing altitude...").
    IF min_fuel > 0 { tlog("Landing fuel reserve: " + ROUND(min_fuel, 0) + " LF (coast nudge guarded)"). }

    RCS ON.

    LOCAL last_display    IS TIME:SECONDS.
    LOCAL last_predict    IS TIME:SECONDS - 100.  // force immediate first prediction
    LOCAL last_fuel_check IS TIME:SECONDS - 100.  // force immediate first check
    LOCAL cached_impact   IS LATLNG(0, 0).
    LOCAL distance_error  IS 9999.
    LOCAL can_nudge       IS TRUE.

    UNTIL get_true_altitude() < landing_start_altitude {
        LOCAL ship_alt IS SHIP:ALTITUDE.

        // Prediction on a schedule: 30s above 30 km, 5s below
        LOCAL predict_interval IS 30.
        IF ship_alt < 30000 { SET predict_interval TO 5. }

        IF TIME:SECONDS - last_predict > predict_interval {
            SET cached_impact  TO predict_current_impact(400, 1.0).
            SET distance_error TO great_circle_distance(cached_impact, target_latlng).
            SET last_predict   TO TIME:SECONDS.
        }

        // Fuel guard: re-read resources every 30 s (fuel changes slowly during coast)
        IF min_fuel > 0 AND TIME:SECONDS - last_fuel_check > 30 {
            LOCAL cur_lf IS 0.
            FOR res IN SHIP:RESOURCES {
                IF res:NAME = "LiquidFuel" { SET cur_lf TO cur_lf + res:AMOUNT. }
            }
            SET can_nudge       TO cur_lf > min_fuel.
            SET last_fuel_check TO TIME:SECONDS.
        }

        // Throttle: engine nudge only when off-course, high enough, and fuel allows
        IF distance_error > 500 AND ship_alt > 5000 AND can_nudge {
            LOCK THROTTLE TO 0.05.
        } ELSE {
            LOCK THROTTLE TO 0.
        }

        // Steering: uses cached prediction — no redundant predict_current_impact call
        LOCK STEERING TO steer_retrograde_corrected(cached_impact, distance_error, target_latlng, 0.4).

        // Airbrakes
        IF ship_alt < 40000 AND ship_alt > 1000 {
            IF NOT BRAKES { deploy_airbrakes(). }
        }

        // Telemetry once per second
        IF TIME:SECONDS - last_display > 1.0 {
            LOCAL airbrake_status IS "Airbrakes: retracted".
            IF BRAKES { SET airbrake_status TO "Airbrakes: DEPLOYED". }
            LOCAL nudge_status IS "Glide".
            IF THROTTLE > 0 { SET nudge_status TO "Nudge". }
            show_booster_hud(nudge_status + " (Err: " + ROUND(distance_error, 0) + "m)", airbrake_status).
            SET last_display TO TIME:SECONDS.
        }

        // Tick rate: slower at high altitude where nothing changes fast
        IF ship_alt > 30000 { WAIT 0.5. }
        ELSE { WAIT 0.1. }
    }

    LOCK THROTTLE TO 0.
    tlog("Reached landing altitude: " + ROUND(get_true_altitude(), 0) + " m").
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL entry_loaded IS TRUE.
