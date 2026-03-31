// =========================================================================
// LANDING LIBRARY (landing.ks)
// =========================================================================
// Suicide burn calculation and touchdown control
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/config.ks").
RUNONCEPATH("0:/lib/util.ks").
RUNONCEPATH("0:/lib/guidance.ks").

// =========================================================================
// SUICIDE BURN CALCULATION
// =========================================================================

// Get max thrust of ONLY currently ignited engines.
// SHIP:MAXTHRUST can be misleading if some engines are deactivated or shutdown.
FUNCTION get_active_max_thrust {
    LOCAL total_thrust IS 0.
    FOR eng IN SHIP:ENGINES {
        IF eng:IGNITION AND NOT eng:FLAMEOUT {
            SET total_thrust TO total_thrust + eng:POSSIBLETHRUST.
        }
    }
    // Fallback to SHIP:MAXTHRUST if no engines reported ignition (e.g. at/before trigger)
    IF total_thrust = 0 { RETURN SHIP:MAXTHRUST. }
    RETURN total_thrust.
}

// Calculate altitude at which to start suicide burn
FUNCTION calculate_suicide_burn_altitude {
    PARAMETER safety_margin IS 1.20.

    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL v_up IS ABS(SHIP:VERTICALSPEED). // Use absolute vertical speed
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.

    // Maximum deceleration available
    // Subtract some thrust for steering/instability
    // Use a more conservative 0.90 multiplier to handle steering losses
    LOCAL thrust_mult IS 0.90.
    LOCAL active_max_thrust IS get_active_max_thrust().
    LOCAL a_max IS (active_max_thrust * thrust_mult) / SHIP:MASS.

    // Account for vertical component of thrust (assuming retrograde steering)
    // If speed is much larger than v_up, we are tilted.
    LOCAL cos_theta IS v_up / MAX(0.01, speed).

    // Cap cos_theta to 0.95 even if perfectly vertical, to account for
    // unavoidable steering corrections during the burn.
    SET cos_theta TO MIN(0.95, cos_theta).

    LOCAL a_net IS a_max * cos_theta - g.

    IF a_net <= 0 {
        RETURN 99999.  // Can't stop - TWR too low or tilted too far
    }

    // Vertical distance needed to stop: d = v_up^2 / (2 * a_net)
    LOCAL stop_dist IS v_up^2 / (2 * a_net).

    // Apply safety margin and target altitude
    LOCAL burn_alt IS stop_dist * safety_margin + SUICIDE_ALT_TARGET.

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
    LOCAL v_up IS SHIP:VERTICALSPEED.
    LOCAL altitude_m IS get_true_altitude().
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.

    LOCAL active_max_thrust IS get_active_max_thrust().

    // Avoid division by zero — no thrust available or at/below ground
    IF active_max_thrust <= 0 { RETURN 0. }

    // Target stopping at SUICIDE_ALT_TARGET
    LOCAL available_dist IS altitude_m - SUICIDE_ALT_TARGET.

    // Vertical component of current facing (how much thrust goes UP)
    // Use actual facing because steering takes time to align
    LOCAL ship_up_dot IS VDOT(SHIP:FACING:VECTOR, SHIP:UP:VECTOR).
    LOCAL cos_theta IS MAX(0.01, ship_up_dot).

    IF available_dist < 2 {
        // Below or very near target altitude - MUST stop descent
        IF v_up < -0.5 {
            // Still falling - use MAX thrust corrected for tilt
            RETURN clamp(1.0 / cos_theta, 0, 1).
        }
        // Hovering or going up - maintain hover
        LOCAL hover_throttle IS g * SHIP:MASS / (active_max_thrust * cos_theta).
        RETURN clamp(hover_throttle, 0, 1).
    }

    // Required vertical deceleration to stop at target altitude
    // Use absolute v_up to handle both descent and accidental ascent
    LOCAL required_accel IS v_up^2 / (2 * available_dist).

    // If already moving away from ground (v_up > 0), we don't need suicide thrust
    IF v_up > 0 {
        RETURN 0.
    }

    // Throttle needed (accounting for gravity and tilt)
    // Add a 10% safety margin to required_accel to ensure we stay ahead of the curve
    LOCAL throttle_val IS (required_accel * 1.10 + g) * SHIP:MASS / (active_max_thrust * cos_theta).

    // Clamp to valid range
    RETURN clamp(throttle_val, 0, 1).
}
// =========================================================================
// LANDING STEERING
// =========================================================================

FUNCTION clear_landing_translation {
    SET SHIP:CONTROL:STARBOARD TO 0.
    SET SHIP:CONTROL:TOP TO 0.
    SET SHIP:CONTROL:FORE TO 0.
}

FUNCTION get_horizontal_component {
    PARAMETER vec.
    RETURN vec - VDOT(vec, SHIP:UP:VECTOR) * SHIP:UP:VECTOR.
}

FUNCTION apply_terminal_rcs_guidance {
    PARAMETER target_latlng, altitude_m.

    LOCAL target_pos IS BODY:GEOPOSITIONLATLNG(target_latlng:LAT, target_latlng:LNG):POSITION.
    LOCAL horizontal_error IS get_horizontal_component(target_pos - SHIP:POSITION).
    LOCAL horizontal_vel IS get_horizontal_component(SHIP:VELOCITY:SURFACE).

    // Project onto actual ship axes for better control when tilted
    LOCAL error_starboard IS VDOT(horizontal_error, SHIP:FACING:RIGHTVECTOR).
    LOCAL error_top IS VDOT(horizontal_error, SHIP:FACING:UPVECTOR).
    
    LOCAL vel_starboard IS VDOT(horizontal_vel, SHIP:FACING:RIGHTVECTOR).
    LOCAL vel_top IS VDOT(horizontal_vel, SHIP:FACING:UPVECTOR).

    LOCAL pos_gain IS TERMINAL_RCS_POSITION_GAIN.
    IF altitude_m < HORIZONTAL_KILL_ALT OR horizontal_error:MAG < LANDING_TARGET_TOLERANCE {
        SET pos_gain TO 0.
    }

    LOCAL starboard_cmd IS clamp(error_starboard * pos_gain - vel_starboard * TERMINAL_RCS_VELOCITY_GAIN, -1, 1).
    LOCAL top_cmd IS clamp(error_top * pos_gain - vel_top * TERMINAL_RCS_VELOCITY_GAIN, -1, 1).

    // Reduced deadzone for more precise terminal control
    IF ABS(starboard_cmd) < 0.02 { SET starboard_cmd TO 0. }
    IF ABS(top_cmd) < 0.02 { SET top_cmd TO 0. }

    SET SHIP:CONTROL:STARBOARD TO starboard_cmd.
    SET SHIP:CONTROL:TOP TO top_cmd.
    SET SHIP:CONTROL:FORE TO 0.
}

// Get steering for landing approach
FUNCTION get_landing_steering {
    PARAMETER target_latlng, final_approach_alt IS 50, kill_horizontal_only IS FALSE.

    LOCAL altitude_m IS get_true_altitude().
    LOCAL horizontal_vel IS get_horizontal_component(SHIP:VELOCITY:SURFACE).

    // Below 15m or very low horizontal speed: go fully vertical
    IF altitude_m < 15 OR horizontal_vel:MAG < 0.1 {
        RETURN SHIP:UP:VECTOR.
    }

    // Commit to a vertical landing below the correction cutoff OR if specifically requested.
    IF altitude_m < FINAL_CORRECTION_CUTOFF_ALT OR kill_horizontal_only {
        RETURN SHIP:UP:VECTOR.
    }

    // Below final approach altitude: go fully vertical
    IF altitude_m < final_approach_alt {
        RETURN SHIP:UP:VECTOR.
    }

    // Above final approach: blend retrograde with vertical based on altitude
    LOCAL blend_factor IS clamp(1 - (altitude_m - final_approach_alt) / 1000, 0, 1).

    // Lateral correction
    LOCAL distance_to_target IS great_circle_distance(SHIP:GEOPOSITION, target_latlng).

    // During suicide burn (or very low), prioritize vertical thrust over lateral correction.
    // Limit correction weight to avoid excessive tilting when we need thrust.
    LOCAL corr_weight IS 0.5.
    IF altitude_m < 500 { SET corr_weight TO 0.2. }
    IF altitude_m < 200 { SET corr_weight TO 0.05. }

    IF distance_to_target > LANDING_TARGET_TOLERANCE AND altitude_m > FINAL_CORRECTION_CUTOFF_ALT {
        // Still have time to correct
        LOCAL retro_corrected IS steer_retrograde_with_correction(target_latlng, corr_weight).
        RETURN blend_steering(retro_corrected, SHIP:UP:VECTOR, blend_factor).
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

    tlog("Starting suicide burn...").

    LOCAL gear_deployed IS FALSE.
    LOCAL final_approach IS FALSE.

    RCS ON.

    UNTIL SHIP:STATUS = "LANDED" OR SHIP:STATUS = "SPLASHED" {
        LOCAL altitude_m IS get_true_altitude().
        LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
        LOCAL v_up IS SHIP:VERTICALSPEED.
        LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.

        // Deploy landing gear at appropriate altitude
        IF altitude_m < 100 AND NOT gear_deployed {
            deploy_gear().
            SET gear_deployed TO TRUE.
            tlog("Landing gear deployed").
        }

        // Retract airbrakes during landing burn
        IF altitude_m < 2000 {
            retract_airbrakes().
        }

        // Switch to final approach mode below 50m
        IF altitude_m < FINAL_CORRECTION_CUTOFF_ALT AND NOT final_approach {
            SET final_approach TO TRUE.
            tlog("Final approach - cancelling target correction and going vertical").
        }

        // Calculate steering - Focus on "straight and soft" (velocity kill only) during suicide burn
        LOCAL steer_vec IS get_landing_steering(target_latlng, FINAL_APPROACH_ALT, TRUE).
        LOCK STEERING TO steer_vec.

        // Calculate throttle
        LOCAL throttle_val IS calculate_suicide_throttle().

        // Fine control near ground / touchdown
        IF altitude_m < (SUICIDE_ALT_TARGET + 5) {
            // Below target altitude or very close: transition to soft touchdown
            IF speed < 15 {
                // Aim for TOUCHDOWN_SPEED vertical descent
                LOCAL target_v IS -TOUCHDOWN_SPEED.
                LOCAL v_error IS target_v - v_up. // e.g. -1.5 - (-10) = +8.5 (falling too fast, need more thrust)
                LOCAL active_max_thrust IS get_active_max_thrust().
                LOCAL ship_up_dot IS VDOT(SHIP:FACING:VECTOR, SHIP:UP:VECTOR).
                LOCAL cos_theta IS MAX(0.01, ship_up_dot).

                // Simple proportional control for hover/touchdown (Kp=1.5)
                LOCAL hover_throttle IS (g + v_error * 1.5) * SHIP:MASS / MAX(0.1, active_max_thrust * cos_theta).
                SET throttle_val TO clamp(hover_throttle, 0.05, 1.0).
            }
        }

        // Terminal RCS guidance: use velocity damping only during the suicide burn
        // Passing HORIZONTAL_KILL_ALT as altitude_m forces pos_gain to 0 in apply_terminal_rcs_guidance
        apply_terminal_rcs_guidance(target_latlng, MIN(altitude_m, HORIZONTAL_KILL_ALT - 1)).

        // Kill throttle at very low altitude if nearly stopped
        IF altitude_m < 0.2 OR (altitude_m < 2 AND speed < 0.3) {
            SET throttle_val TO 0.
            SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
        }

        LOCK THROTTLE TO throttle_val.

        // Periodically log status
        IF MOD(ROUND(TIME:SECONDS * 10), 10) = 0 {
            tlog("Burn: h=" + ROUND(altitude_m,0) + " v=" + ROUND(v_up,1) + " thr=" + ROUND(throttle_val*100,0) + "%").
        }

        // Display telemetry
        LOCAL burn_info IS "Alt: " + ROUND(altitude_m, 0) + "m  Thr: " + ROUND(throttle_val*100, 0) + "%".
        show_booster_hud("SUICIDE BURN", burn_info).

        WAIT 0.05.  // High update rate for precision
    }

    LOCK THROTTLE TO 0.
    tlog("TOUCHDOWN!").

    // Post-landing status
    LOCAL touchdown_speed IS SHIP:VELOCITY:SURFACE:MAG.
    tlog("Touchdown speed: " + ROUND(touchdown_speed, 2) + " m/s").

    LOCAL landing_error IS great_circle_distance(SHIP:GEOPOSITION, target_latlng).
    tlog("Landing error: " + ROUND(landing_error, 1) + " m").
}

// =========================================================================
// COMPLETE LANDING SEQUENCE
// =========================================================================

// Execute complete landing from current altitude
FUNCTION execute_landing {
    PARAMETER target_latlng, safety_margin IS 1.20.

    tlog("Initiating landing sequence...").
    tlog("Target: LAT=" + ROUND(target_latlng:LAT, 4) +
               " LON=" + ROUND(target_latlng:LNG, 4)).

    // Wait for suicide burn altitude
    tlog("Waiting for suicide burn altitude...").

    UNTIL should_start_suicide_burn(safety_margin) {
        LOCAL altitude_m IS get_true_altitude().
        LOCAL burn_alt IS calculate_suicide_burn_altitude(safety_margin).

        IF altitude_m < FINAL_CORRECTION_CUTOFF_ALT {
            LOCK STEERING TO SHIP:UP:VECTOR.
            clear_landing_translation().
        } ELSE {
            LOCK STEERING TO steer_retrograde_with_correction(target_latlng, 0.5).
        }

        // Update display
        LOCAL wait_info IS "Waiting: alt=" + ROUND(altitude_m,0) + "m  burn@" + ROUND(burn_alt,0) + "m".
        show_booster_hud("WAITING FOR BURN ALT", wait_info).

        WAIT 0.01. // Increased polling frequency for precision
    }

    // Execute suicide burn
    LOCAL burn_alt IS calculate_suicide_burn_altitude(safety_margin).
    LOCAL vel IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL v_up IS SHIP:VERTICALSPEED.
    LOCAL ship_mass IS SHIP:MASS.
    LOCAL ship_max_thrust IS SHIP:MAXTHRUST.
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
    LOCAL a_max IS ship_max_thrust / ship_mass.
    LOCAL cos_theta IS ABS(v_up) / MAX(0.01, vel).
    LOCAL a_net IS a_max * cos_theta - g.
    
    tlog("--- SUICIDE BURN TRIGGER ---").
    tlog("Alt: " + ROUND(get_true_altitude(), 1) + "m (BurnAlt: " + ROUND(burn_alt, 1) + "m)").
    tlog("Vel: " + ROUND(vel, 1) + "m/s (Vup: " + ROUND(v_up, 1) + "m/s)").
    tlog("TWR_net: " + ROUND(a_max/g, 2) + " (A_net: " + ROUND(a_net, 2) + "m/s2)").
    tlog("Theta: " + ROUND(ARCCOS(clamp(cos_theta, -1, 1)), 1) + "deg").
    tlog("Mass: " + ROUND(ship_mass, 1) + "t Thrust: " + ROUND(ship_max_thrust, 1) + "kN").
    tlog("----------------------------").

    execute_suicide_burn(target_latlng, safety_margin).
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL landing_loaded IS TRUE.
