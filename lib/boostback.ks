// =========================================================================
// BOOSTBACK LIBRARY (boostback.ks)
// =========================================================================
// RTLS boostback guidance and control
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").
RUNONCEPATH("0:/lib/guidance.ks").

// =========================================================================
// FLIP MANEUVER
// =========================================================================

// Execute flip to retrograde orientation
FUNCTION execute_flip {
    PARAMETER max_flip_time IS 10.

    tlog("Executing flip maneuver...").

    // Enable RCS for flip
    RCS ON.

    LOCAL flip_start IS TIME:SECONDS.
    LOCK STEERING TO RETROGRADE.

    UNTIL VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR) < 5 OR
          (TIME:SECONDS - flip_start) > max_flip_time {
        LOCAL angle_err IS ROUND(VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR), 1).
        show_booster_hud("FLIP TO RETROGRADE", "Angle error: " + angle_err + " deg").
        WAIT 0.5.
    }

    LOCAL flip_time IS TIME:SECONDS - flip_start.

    IF VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR) < 5 {
        tlog("Flip complete in " + ROUND(flip_time, 1) + " seconds").
        RETURN TRUE.
    }
    ELSE {
        tlog("WARNING: Flip timeout. Angle error: " +
                   ROUND(VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR), 1) + " degrees").
        RETURN FALSE.
    }
}

// =========================================================================
// BOOSTBACK BURN
// =========================================================================

// Execute boostback burn to return to target landing zone.
// Burns primarily retrograde (to stop the ballistic arc) with a small lean toward target.
// Full throttle throughout; stops early if fuel reserve for landing is reached.
FUNCTION execute_boostback {
    PARAMETER target_latlng, max_burn_time IS 60, target_error IS 500, landing_reserve IS 0.

    tlog("Starting boostback burn...").
    tlog("Target: LAT=" + ROUND(target_latlng:LAT, 4) + " LON=" + ROUND(target_latlng:LNG, 4)).

    LOCAL start_time IS TIME:SECONDS.

    LOCAL initial_fuel IS 0.
    FOR res IN SHIP:RESOURCES {
        IF res:NAME = "LiquidFuel" { SET initial_fuel TO initial_fuel + res:AMOUNT. }
    }
    tlog("Fuel: " + ROUND(initial_fuel, 0) + " LF  landing reserve: " + ROUND(landing_reserve, 0) + " LF").

    LOCK STEERING TO RETROGRADE.

    // Cache impact prediction — predict_current_impact(400,1.0) runs 400 integration
    // steps per call. Calling it every 0.1s = 4000 steps/sec which crashes kOS.
    // Update every 2 seconds; accuracy is sufficient since trajectory changes slowly.
    LOCAL last_predict_time IS TIME:SECONDS - 10.
    LOCAL last_tlog_time IS TIME:SECONDS - 10.
    LOCAL predicted_impact IS LATLNG(0, 0).
    LOCAL error_distance IS 999999.

    UNTIL (TIME:SECONDS - start_time) > max_burn_time {
        // Check fuel reserve — stop if not enough left to land
        LOCAL current_fuel IS 0.
        FOR res IN SHIP:RESOURCES {
            IF res:NAME = "LiquidFuel" { SET current_fuel TO current_fuel + res:AMOUNT. }
        }
        IF current_fuel <= landing_reserve {
            LOCK THROTTLE TO 0.
            tlog("Boostback stopped - fuel reserve reached (" + ROUND(current_fuel, 0) + " LF remaining). Trajectory err: " + ROUND(error_distance/1000, 1) + "km").
            RETURN FALSE.
        }

        // Stop when velocity is mostly cancelled — further burning is counterproductive
        IF SHIP:VELOCITY:SURFACE:MAG < 300 {
            LOCK THROTTLE TO 0.
            tlog("Boostback stopped - velocity cancelled (" + ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " m/s remaining). Trajectory err: " + ROUND(error_distance/1000, 1) + "km").
            RETURN FALSE.
        }

        // Predict landing point and check error (rate-limited to every 2s)
        IF (TIME:SECONDS - last_predict_time) >= 2.0 {
            SET predicted_impact TO predict_current_impact(400, 1.0).
            SET error_distance TO great_circle_distance(predicted_impact, target_latlng).
            SET last_predict_time TO TIME:SECONDS.
        }

        LOCAL bb_info IS "Burn: " + ROUND(TIME:SECONDS - start_time, 0) + "s  Err: " + ROUND(error_distance/1000, 1) + "km".
        show_booster_hud("BOOSTBACK BURN", bb_info).

        // Periodic file log — HUD is screen-only; without this, crashes leave no trace
        IF TIME:SECONDS - last_tlog_time >= 5 {
            LOCAL cur_lean IS ROUND(MIN(0.20, error_distance / 200000), 3).
            LOCAL tilt IS ROUND(VANG(SHIP:FACING:VECTOR, RETROGRADE:VECTOR), 1).
            LOCAL cur_lf IS 0.
            FOR res IN SHIP:RESOURCES { IF res:NAME = "LiquidFuel" { SET cur_lf TO cur_lf + res:AMOUNT. } }
            tlog("BB t=" + ROUND(TIME:SECONDS - start_time, 0) + "s vel=" + ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " lean=" + cur_lean + " tilt=" + tilt + "deg err=" + ROUND(error_distance/1000, 1) + "km fuel=" + ROUND(cur_lf, 0)).
            SET last_tlog_time TO TIME:SECONDS.
        }

        IF error_distance < target_error {
            LOCK THROTTLE TO 0.
            tlog("Boostback complete. Error: " + ROUND(error_distance, 0) + "m").
            RETURN TRUE.
        }

        // Steering: retrograde with small lean toward KSC.
        // Lean is fixed at 20% max — ensures 80% retrograde (velocity cancellation)
        // and 20% correction (trajectory bend toward KSC).
        // Use current position bearing (not predicted impact) for stability.
        LOCAL target_bearing IS bearing_to_target(SHIP:GEOPOSITION, target_latlng).
        LOCAL correction_vec IS heading_vector(target_bearing, 0).
        LOCAL lean_factor IS MIN(0.20, error_distance / 200000).
        LOCAL steer_vec IS ((1 - lean_factor) * RETROGRADE:VECTOR +
                            lean_factor * correction_vec):NORMALIZED.
        LOCK STEERING TO steer_vec.

        // Full throttle — maximum delta-V from limited fuel
        LOCK THROTTLE TO 1.0.

        WAIT 0.1.
    }

    LOCK THROTTLE TO 0.
    tlog("Boostback timeout.").

    LOCAL final_error IS great_circle_distance(predicted_impact, target_latlng).
    tlog("Final error: " + ROUND(final_error/1000, 1) + "km").

    RETURN FALSE.
}

// =========================================================================
// BOOSTBACK ASSESSMENT
// =========================================================================

// Check if boostback burn is needed
FUNCTION assess_boostback_needed {
    PARAMETER target_latlng, threshold_distance IS 2000.

    // Predict impact with no boostback
    LOCAL predicted_impact IS predict_current_impact(400, 1.0).
    LOCAL distance IS great_circle_distance(predicted_impact, target_latlng).

    tlog("Predicted impact distance: " + ROUND(distance, 0) + "m").

    IF distance > threshold_distance {
        tlog("Boostback required.").
        RETURN TRUE.
    }
    ELSE {
        tlog("On target - boostback not needed.").
        RETURN FALSE.
    }
}

// Estimate required boostback delta-V
FUNCTION estimate_boostback_dv {
    PARAMETER target_latlng.

    // Simple estimate: distance to target / burn efficiency
    // This is a rough approximation

    LOCAL predicted_impact IS predict_current_impact(400, 1.0).
    LOCAL distance IS great_circle_distance(predicted_impact, target_latlng).

    // Estimate efficiency factor (how much horizontal distance per m/s dV)
    LOCAL efficiency IS 10.  // Very rough estimate: 10m per m/s

    LOCAL estimated_dv IS distance / efficiency.

    RETURN estimated_dv.
}

// Check if vessel has enough fuel for boostback
FUNCTION check_boostback_fuel {
    PARAMETER required_dv.

    // Get current delta-V capacity
    LOCAL current_dv IS get_vessel_deltav().

    IF current_dv > required_dv * 1.5 {
        // 1.5x safety margin
        RETURN TRUE.
    }

    tlog("WARNING: Low fuel for boostback. Have " + ROUND(current_dv, 0) +
               " m/s, need ~" + ROUND(required_dv, 0) + " m/s").

    RETURN FALSE.
}

// Estimate vessel delta-V (simplified)
FUNCTION get_vessel_deltav {
    // Very simplified delta-V calculation
    // dV = Isp * g0 * ln(m_wet / m_dry)

    LOCAL total_fuel_mass IS 0.
    FOR res IN SHIP:RESOURCES {
        IF res:NAME = "LIQUIDFUEL" OR res:NAME = "OXIDIZER" {
            SET total_fuel_mass TO total_fuel_mass + res:AMOUNT * res:DENSITY.
        }
    }

    LOCAL wet_mass IS SHIP:MASS.
    LOCAL dry_mass IS wet_mass - total_fuel_mass.

    IF dry_mass <= 0 {
        RETURN 0.
    }

    // Get average ISP
    LOCAL avg_isp IS 0.
    LOCAL engine_count IS 0.

    LOCAL engines_collection IS LIST().
    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        SET avg_isp TO avg_isp + eng:ISP.
        SET engine_count TO engine_count + 1.
    }

    IF engine_count > 0 {
        SET avg_isp TO avg_isp / engine_count.
    }
    ELSE {
        RETURN 0.
    }

    LOCAL g0 IS 9.80665.
    LOCAL dv IS avg_isp * g0 * LN(wet_mass / dry_mass).

    RETURN dv.
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL boostback_loaded IS TRUE.
