// =========================================================================
// GUIDANCE LIBRARY (guidance.ks)
// =========================================================================
// Trajectory prediction, impact calculation, and steering utilities
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").

// =========================================================================
// TRAJECTORY PREDICTION
// =========================================================================

// Predict impact point using numerical integration
FUNCTION predict_impact {
    PARAMETER vel, pos, time_limit IS 300, dt IS 1.0.

    LOCAL pos_vec IS pos.
    LOCAL vel_vec IS vel.
    LOCAL elapsed_time IS 0.

    UNTIL elapsed_time > time_limit {
        // Calculate altitude above surface
        LOCAL altitude_m IS pos_vec:MAG - BODY:RADIUS.

        // Check if below terrain (landed)
        IF altitude_m <= 0 {
            RETURN LATLNG(
                ARCSIN(pos_vec:Y / pos_vec:MAG) * CONSTANT:RADTODEG,
                ARCTAN2(pos_vec:X, pos_vec:Z) * CONSTANT:RADTODEG
            ).
        }

        // Gravity acceleration
        LOCAL g_vec IS -BODY:MU / pos_vec:MAG^2 * pos_vec:NORMALIZED.

        // Drag acceleration
        LOCAL drag_accel IS get_drag_acceleration_prediction(vel_vec, altitude_m, pos_vec).

        // Update velocity
        SET vel_vec TO vel_vec + (g_vec + drag_accel) * dt.

        // Update position
        SET pos_vec TO pos_vec + vel_vec * dt.

        SET elapsed_time TO elapsed_time + dt.
    }

    // Timeout - return current position projection
    RETURN LATLNG(
        ARCSIN(pos_vec:Y / pos_vec:MAG) * CONSTANT:RADTODEG,
        ARCTAN2(pos_vec:X / pos_vec:Z) * CONSTANT:RADTODEG
    ).
}

// Get drag acceleration for trajectory prediction
FUNCTION get_drag_acceleration_prediction {
    PARAMETER velocity_vec, altitude_m, pos.

    // No atmosphere above this altitude
    IF altitude_m > BODY:ATM:HEIGHT OR altitude_m < 0 {
        RETURN V(0, 0, 0).
    }

    LOCAL v_mag IS velocity_vec:MAG.
    IF v_mag < 0.1 {
        RETURN V(0, 0, 0).
    }

    // Atmospheric density (exponential model for prediction)
    LOCAL scale_height IS 5000.  // Kerbin approximation
    LOCAL rho IS 1.2 * CONSTANT:E^(-altitude_m / scale_height).

    // Drag coefficient * reference area (estimate based on booster)
    LOCAL Cd_A IS 5.0.  // m^2, adjust based on vessel size

    // Drag force: F = 0.5 * rho * v^2 * Cd * A
    LOCAL drag_force IS 0.5 * rho * v_mag^2 * Cd_A.

    // Drag acceleration (opposes velocity)
    LOCAL drag_accel_mag IS drag_force / SHIP:MASS.
    LOCAL drag_accel_vec IS -drag_accel_mag * velocity_vec:NORMALIZED.

    RETURN drag_accel_vec.
}

// =========================================================================
// IMPACT PREDICTION (CURRENT VESSEL)
// =========================================================================

// Predict where current vessel will land
FUNCTION predict_current_impact {
    PARAMETER time_limit IS 300, dt IS 1.0.

    RETURN predict_impact(
        SHIP:VELOCITY:ORBIT,
        SHIP:BODY:POSITION + SHIP:POSITION,
        time_limit,
        dt
    ).
}

// =========================================================================
// STEERING UTILITIES
// =========================================================================

// Steer toward a surface position
FUNCTION steer_to_surface_position {
    PARAMETER target_latlng.

    // Get target position vector
    LOCAL target_pos IS BODY:GEOPOSITIONLATLNG(target_latlng:LAT, target_latlng:LNG):POSITION.

    // Get direction from ship to target
    LOCAL to_target IS (target_pos - SHIP:POSITION):NORMALIZED.

    RETURN to_target.
}

// Blend two steering vectors
FUNCTION blend_steering {
    PARAMETER vec1, vec2, blend_factor.

    LOCAL blend_t IS clamp(blend_factor, 0, 1).
    RETURN ((1 - blend_t) * vec1 + blend_t * vec2):NORMALIZED.
}

// Get steering vector for retrograde with lateral correction
FUNCTION steer_retrograde_with_correction {
    PARAMETER target_latlng, correction_weight IS 0.5.

    // Retrograde component (slow down)
    LOCAL retro_vec IS -SHIP:VELOCITY:SURFACE:NORMALIZED.

    // Correction component (steer toward target)
    LOCAL predicted_impact IS predict_current_impact(120, 1.0).
    LOCAL distance_error IS great_circle_distance(predicted_impact, target_latlng).

    // Only apply correction if error is significant
    IF distance_error < 100 {
        RETURN retro_vec.
    }

    LOCAL bearing IS bearing_to_target(predicted_impact, target_latlng).
    LOCAL correction_vec IS heading_vector(bearing, 0).

    // Blend retrograde with correction
    LOCAL blend_factor IS MIN(1.0, distance_error / 5000) * correction_weight.
    RETURN blend_steering(retro_vec, correction_vec, blend_factor).
}

// =========================================================================
// ALTITUDE UTILITIES
// =========================================================================

// Get true altitude above terrain (uses radar if available)
FUNCTION get_true_altitude {
    IF SHIP:ALTITUDE < 2500 AND ALT:RADAR > 0 {
        RETURN ALT:RADAR.
    }
    RETURN SHIP:ALTITUDE.
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL guidance_loaded IS TRUE.
