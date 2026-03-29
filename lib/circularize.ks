// =========================================================================
// CIRCULARIZATION LIBRARY (circularize.ks)
// =========================================================================
// Orbital circularization burn planning and execution
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").

// =========================================================================
// ORBITAL MECHANICS
// =========================================================================

// Calculate orbital velocity at given altitude
FUNCTION orbital_velocity_at_altitude {
    PARAMETER altitude_m.

    LOCAL radius IS BODY:RADIUS + altitude_m.
    LOCAL orbital_vel IS SQRT(BODY:MU / radius).

    RETURN orbital_vel.
}

// Calculate delta-V needed for circularization at apoapsis
FUNCTION calculate_circularization_dv {
    PARAMETER target_periapsis.

    // Current orbital parameters
    LOCAL ap IS SHIP:APOAPSIS.
    LOCAL pe IS SHIP:PERIAPSIS.

    // Semi-major axes
    LOCAL a_current IS (ap + pe) / 2 + BODY:RADIUS.
    LOCAL a_target IS ap + BODY:RADIUS.

    // Current velocity at apoapsis (vis-viva equation)
    LOCAL r_ap IS ap + BODY:RADIUS.
    LOCAL v_current IS SQRT(BODY:MU * (2/r_ap - 1/a_current)).

    // Target velocity at apoapsis (circular orbit)
    LOCAL v_target IS SQRT(BODY:MU / r_ap).

    // Delta-V required
    LOCAL dv IS v_target - v_current.

    RETURN dv.
}

// Calculate time to apoapsis
FUNCTION time_to_apoapsis {
    IF SHIP:ORBIT:TRANSITION = "ENCOUNTER" OR SHIP:ORBIT:TRANSITION = "ESCAPE" {
        RETURN -1.  // Invalid in encounter/escape trajectory
    }

    RETURN ETA:APOAPSIS.
}

// =========================================================================
// BURN NODE CREATION
// =========================================================================

// Create maneuver node for circularization
FUNCTION create_circularization_node {
    PARAMETER target_periapsis.

    LOCAL dv IS calculate_circularization_dv(target_periapsis).
    LOCAL t_ap IS TIME:SECONDS + time_to_apoapsis().

    // Create node at apoapsis with prograde delta-V
    LOCAL circ_node IS NODE(t_ap, 0, 0, dv).
    ADD circ_node.

    RETURN circ_node.
}

// =========================================================================
// BURN EXECUTION
// =========================================================================

// Execute a maneuver node
FUNCTION execute_node {
    PARAMETER node_to_execute, lead_time IS 30.

    LOCAL dv_vec IS node_to_execute:DELTAV.
    LOCAL dv_mag IS dv_vec:MAG.

    tlog("Circularization burn dV: " + ROUND(dv_mag, 1) + " m/s").

    // Calculate burn time
    LOCAL burn_time IS calculate_burn_time(dv_mag).
    tlog("Burn time: " + ROUND(burn_time, 1) + " seconds").

    // Warp to burn start
    LOCAL burn_start_time IS TIME:SECONDS + node_to_execute:ETA - burn_time/2.
    IF burn_start_time > TIME:SECONDS + lead_time {
        tlog("Warping to burn point...").
        WARPTO(burn_start_time - lead_time).
        WAIT UNTIL TIME:SECONDS >= burn_start_time - lead_time.
        WAIT 1.  // Let physics settle
    }

    // Orient to node direction
    tlog("Orienting to burn direction...").
    tlog("Burn window: T+" + ROUND(burn_start_time - TIME:SECONDS, 1) + "s").
    LOCK STEERING TO node_to_execute:DELTAV.

    // Wait for alignment — guard against near-zero deltav vector (causes VANG crash)
    LOCAL max_wait IS 60.
    LOCAL wait_start IS TIME:SECONDS.
    WAIT UNTIL node_to_execute:DELTAV:MAG < 0.1 OR
               VANG(SHIP:FACING:VECTOR, node_to_execute:DELTAV) < 2 OR
               (TIME:SECONDS - wait_start) > max_wait.

    LOCAL align_err IS VANG(SHIP:FACING:VECTOR, node_to_execute:DELTAV).
    tlog("Aligned (" + ROUND(align_err, 1) + " deg). Waiting for burn window...").

    // Wait for burn time (with vertical speed fail-safe for shallow ascents)
    UNTIL TIME:SECONDS >= burn_start_time OR (SHIP:ALTITUDE > BODY:ATM:HEIGHT AND SHIP:VERTICALSPEED < 5) {
        LOCAL wait_info IS "Wait: " + ROUND(burn_start_time - TIME:SECONDS, 0) + "s  Vspd: " + ROUND(SHIP:VERTICALSPEED, 1) + "m/s".
        show_launch_hud("WAITING FOR BURN", ROUND(SHIP:ALTITUDE/1000, 1), ROUND(SHIP:APOAPSIS/1000, 1), 0, 0, 0, 0, STAGE:NUMBER).
        WAIT 0.1.
    }

    // Execute burn
    tlog("Executing burn...").
    LOCAL remaining_dv IS node_to_execute:DELTAV:MAG.

    LOCK STEERING TO node_to_execute:DELTAV.

    UNTIL remaining_dv < 0.5 {
        // Stage if engines flamed out (e.g. booster separation mid-burn)
        IF SHIP:MAXTHRUST = 0 {
            tlog("Engines out mid-burn — staging...").
            STAGE.
            WAIT 1.
            // Re-lock steering after staging clears the decoupler
            LOCK STEERING TO node_to_execute:DELTAV.
        }

        LOCAL max_accel IS 0.
        IF SHIP:MASS > 0 { SET max_accel TO SHIP:MAXTHRUST / SHIP:MASS. }

        LOCAL throttle_val IS 1.0.
        IF max_accel > 0 {
            LOCAL burn_time_remaining IS remaining_dv / max_accel.
            IF burn_time_remaining < 3 {
                SET throttle_val TO MAX(0.05, burn_time_remaining / 3).
            }
        }

        LOCK THROTTLE TO throttle_val.

        SET remaining_dv TO node_to_execute:DELTAV:MAG.
        WAIT 0.1.
    }

    // Cut throttle
    LOCK THROTTLE TO 0.
    UNLOCK STEERING.
    UNLOCK THROTTLE.
    WAIT 0.5.

    // Remove node
    REMOVE node_to_execute.

    tlog("Circularization complete.").
    tlog("Final orbit: AP=" + ROUND(SHIP:APOAPSIS/1000, 1) + "km, PE=" +
               ROUND(SHIP:PERIAPSIS/1000, 1) + "km").
}

// Calculate burn time for given delta-V
FUNCTION calculate_burn_time {
    PARAMETER dv.

    // Use Tsiolkovsky rocket equation
    // dV = Isp * g0 * ln(m0/m1)
    // Rearrange: m1 = m0 * e^(-dV/(Isp*g0))

    LOCAL isp IS get_average_isp().
    LOCAL g0 IS 9.80665.  // Standard gravity

    IF isp = 0 {
        RETURN 0.
    }

    LOCAL m0 IS SHIP:MASS.
    LOCAL m1 IS m0 * CONSTANT:E^(-dv / (isp * g0)).
    LOCAL fuel_mass IS m0 - m1.

    // Get fuel flow rate
    LOCAL fuel_flow IS get_fuel_flow_rate().

    IF fuel_flow > 0 {
        RETURN fuel_mass / fuel_flow.
    }

    // Fallback: simple approximation
    LOCAL avg_accel IS SHIP:AVAILABLETHRUST / m0.
    IF avg_accel > 0 {
        RETURN dv / avg_accel.
    }

    RETURN 0.
}

// Get average ISP of active engines
FUNCTION get_average_isp {
    LOCAL total_thrust IS 0.
    LOCAL weighted_isp IS 0.

    LOCAL engines_collection IS LIST().
    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:IGNITION AND NOT eng:FLAMEOUT {
            LOCAL eng_thrust IS eng:AVAILABLETHRUST.
            SET total_thrust TO total_thrust + eng_thrust.
            SET weighted_isp TO weighted_isp + eng:ISP * eng_thrust.
        }
    }

    IF total_thrust > 0 {
        RETURN weighted_isp / total_thrust.
    }

    RETURN 0.
}

// Get total fuel flow rate (tons/second)
FUNCTION get_fuel_flow_rate {
    LOCAL total_flow IS 0.

    LOCAL engines_collection IS LIST().
    LIST ENGINES IN engines_collection.
    FOR eng IN engines_collection {
        IF eng:IGNITION AND NOT eng:FLAMEOUT {
            // Get fuel flow from engine (kg/s)
            SET total_flow TO total_flow + eng:FUELFLOW.
        }
    }

    RETURN total_flow.
}

// =========================================================================
// ORBIT VERIFICATION
// =========================================================================

// Check if orbit is approximately circular
FUNCTION is_orbit_circular {
    PARAMETER tolerance IS 5000.  // meters

    LOCAL ap IS SHIP:APOAPSIS.
    LOCAL pe IS SHIP:PERIAPSIS.

    IF pe < 0 {
        RETURN FALSE.  // Not in orbit
    }

    LOCAL difference IS ABS(ap - pe).
    RETURN difference < tolerance.
}

// Get orbital eccentricity
FUNCTION get_eccentricity {
    RETURN SHIP:ORBIT:ECCENTRICITY.
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL circularize_loaded IS TRUE.
