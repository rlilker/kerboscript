// =========================================================================
// LAUNCH AUTOPILOT (launch.ks)
// =========================================================================
// Automated gravity turn ascent with asparagus staging and circularization
// Triggers booster recovery scripts on separated boosters
// =========================================================================

@LAZYGLOBAL OFF.

// Load libraries
RUNONCEPATH("0:/lib/util.ks").
RUNONCEPATH("0:/lib/ascent.ks").
RUNONCEPATH("0:/lib/circularize.ks").

// =========================================================================
// MISSION PARAMETERS (USER CONFIGURABLE)
// =========================================================================

// Orbital parameters
SET TARGET_APOAPSIS TO 100000.       // Target apoapsis in meters (100km)
SET TARGET_PERIAPSIS TO 100000.      // Target periapsis for circularization
SET TARGET_INCLINATION TO 0.         // Target orbital inclination (0° = equatorial)

// Ascent profile
SET TURN_START_ALTITUDE TO 100.      // Begin gravity turn at 100m
SET TURN_END_ALTITUDE TO 45000.      // Complete turn by 45km
SET TURN_SHAPE TO 0.5.               // Turn shape factor (0.4-0.6, lower = earlier turn)
SET MAX_Q TO 25000.                  // Max dynamic pressure (Pa), throttle if exceeded

// Staging parameters
SET STAGE_FUEL_THRESHOLD TO 5.       // Stage when fuel drops below 5%
SET ENABLE_BOOSTER_RECOVERY TO TRUE. // Enable landing scripts on boosters

// Landing zone (KSC coordinates)
SET LANDING_ZONE_LAT TO -0.0972.     // KSC latitude
SET LANDING_ZONE_LON TO -74.5577.    // KSC longitude

// =========================================================================
// GLOBAL STATE
// =========================================================================

DECLARE GLOBAL BOOSTER_COUNT.
IF NOT (DEFINED BOOSTER_COUNT) {
    SET BOOSTER_COUNT TO 0.
}

// =========================================================================
// PRE-LAUNCH INITIALIZATION
// =========================================================================

FUNCTION initialize_mission {
    clear_screen().
    print_header("LAUNCH AUTOPILOT").

    PRINT "Mission Parameters:".
    PRINT "  Target Apoapsis: " + ROUND(TARGET_APOAPSIS/1000, 1) + " km".
    PRINT "  Target Inclination: " + TARGET_INCLINATION + "°".
    PRINT "  Turn Start: " + TURN_START_ALTITUDE + " m".
    PRINT "  Turn End: " + ROUND(TURN_END_ALTITUDE/1000, 1) + " km".
    PRINT "  Booster Recovery: " + ENABLE_BOOSTER_RECOVERY.
    PRINT " ".

    // Verify vessel readiness
    IF SHIP:MAXTHRUST = 0 {
        PRINT "ERROR: No active engines!".
        RETURN FALSE.
    }

    // Prepare booster recovery if enabled
    IF ENABLE_BOOSTER_RECOVERY {
        IF NOT EXISTS("0:/autoland_staging.ks") {
            PRINT "WARNING: autoland_staging.ks not found!".
            PRINT "Booster recovery will not be available.".
            SET ENABLE_BOOSTER_RECOVERY TO FALSE.
        }
        ELSE {
            PRINT "Booster recovery script ready.".
        }
    }

    PRINT " ".
    PRINT "Press SPACE to launch...".

    RETURN TRUE.
}

// =========================================================================
// BOOSTER RECOVERY
// =========================================================================

FUNCTION trigger_booster_recovery {
    PARAMETER booster_vessel.

    PRINT "Triggering recovery on: " + booster_vessel:NAME.

    // Copy landing script to booster
    // Note: This requires vessel switching, which may cause brief interruption

    LOCAL original_vessel IS SHIP.

    // Switch to booster
    SET KUNIVERSE:ACTIVEVESSEL TO booster_vessel.
    WAIT 0.5.

    // Copy script
    IF EXISTS("0:/autoland_staging.ks") {
        COPYPATH("0:/autoland_staging.ks", "1:/boot.ks").
        WAIT 0.2.

        // Reboot processor to activate landing script
        LOCAL proc IS CORE:PART:GETMODULE("kOSProcessor").
        proc:DOEVENT("Toggle Power").
        WAIT 0.1.
        proc:DOEVENT("Toggle Power").
    }

    // Switch back to main vessel
    WAIT 0.5.
    SET KUNIVERSE:ACTIVEVESSEL TO original_vessel.
    WAIT 0.5.

    PRINT "Recovery script activated on " + booster_vessel:NAME.
}

FUNCTION check_for_staged_boosters {
    // Check if any new vessels appeared (staged boosters)
    LOCAL staged_boosters IS LIST().

    LIST TARGETS IN all_vessels.
    FOR vessel_obj IN all_vessels {
        // Check if this is a new vessel from our ship
        IF vessel_obj <> SHIP AND vessel_obj:NAME:STARTSWITH(SHIP:NAME:SPLIT(" ")[0]) {
            // Check if it has kOS processor and probe core
            LOCAL has_kos IS FALSE.
            LOCAL has_probe IS FALSE.

            FOR part IN vessel_obj:PARTS {
                IF part:HASMODULE("kOSProcessor") {
                    SET has_kos TO TRUE.
                }
                IF part:HASMODULE("ModuleCommand") {
                    SET has_probe TO TRUE.
                }
            }

            IF has_kos AND has_probe {
                // This is a recoverable booster
                staged_boosters:ADD(vessel_obj).
            }
        }
    }

    RETURN staged_boosters.
}

// =========================================================================
// STAGING LOGIC
// =========================================================================

FUNCTION perform_staging {
    log_message("Staging initiated - fuel at " +
               ROUND(get_stage_fuel_percent(STAGE:NUMBER), 1) + "%").

    // Note boosters before staging
    LOCAL boosters_before IS check_for_staged_boosters().

    // Execute staging
    STAGE.
    WAIT 1.0.  // Allow physics to settle

    // Check for new boosters
    LOCAL boosters_after IS check_for_staged_boosters().

    // Find newly separated boosters
    IF ENABLE_BOOSTER_RECOVERY {
        FOR booster IN boosters_after {
            LOCAL is_new IS TRUE.
            FOR old_booster IN boosters_before {
                IF booster = old_booster {
                    SET is_new TO FALSE.
                    BREAK.
                }
            }

            IF is_new {
                // Increment global booster count
                SET BOOSTER_COUNT TO BOOSTER_COUNT + 1.
                log_message("Booster #" + BOOSTER_COUNT + " separated: " + booster:NAME).

                // Trigger recovery
                trigger_booster_recovery(booster).
            }
        }
    }
}

// =========================================================================
// LAUNCH PHASES
// =========================================================================

FUNCTION phase_vertical_ascent {
    log_message("PHASE 1: Vertical Ascent").

    LOCK STEERING TO HEADING(90, 90).  // East, vertical
    LOCK THROTTLE TO 1.0.

    WAIT UNTIL SHIP:ALTITUDE > TURN_START_ALTITUDE.

    log_message("Reached turn start altitude").
}

FUNCTION phase_gravity_turn {
    log_message("PHASE 2: Gravity Turn").

    // Calculate launch azimuth
    LOCAL launch_heading IS get_launch_azimuth(TARGET_INCLINATION).

    UNTIL SHIP:APOAPSIS >= TARGET_APOAPSIS OR SHIP:ALTITUDE > TURN_END_ALTITUDE {
        // Calculate target pitch
        LOCAL target_pitch IS get_target_pitch(
            SHIP:ALTITUDE,
            TURN_START_ALTITUDE,
            TURN_END_ALTITUDE,
            TURN_SHAPE
        ).

        // Update steering
        LOCK STEERING TO HEADING(launch_heading, target_pitch).

        // Adaptive throttle control
        LOCAL throttle_val IS get_ascent_throttle(TARGET_APOAPSIS, MAX_Q).
        LOCK THROTTLE TO throttle_val.

        // Check staging
        IF check_staging_needed(STAGE_FUEL_THRESHOLD) {
            perform_staging().
        }

        // Display telemetry
        PRINT "Altitude: " + ROUND(SHIP:ALTITUDE/1000, 1) + " km          " AT(0, 10).
        PRINT "Apoapsis: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km          " AT(0, 11).
        PRINT "Pitch: " + ROUND(target_pitch, 1) + "°          " AT(0, 12).
        PRINT "Throttle: " + ROUND(throttle_val * 100, 0) + "%          " AT(0, 13).

        WAIT 0.1.
    }

    log_message("Apoapsis reached: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km").
}

FUNCTION phase_coast_to_apoapsis {
    log_message("PHASE 3: Coast to Apoapsis").

    LOCK THROTTLE TO 0.

    // Follow prograde during coast
    LOCK STEERING TO PROGRADE.

    // Continue staging if needed
    UNTIL SHIP:ALTITUDE > BODY:ATM:HEIGHT {
        IF check_staging_needed(STAGE_FUEL_THRESHOLD) {
            perform_staging().
        }

        WAIT 1.0.
    }

    log_message("Exited atmosphere").
}

FUNCTION phase_circularization {
    log_message("PHASE 4: Circularization").

    // Create maneuver node
    LOCAL circ_node IS create_circularization_node(TARGET_PERIAPSIS).

    // Execute the node
    execute_node(circ_node, 30).

    // Verify orbit
    IF is_orbit_circular(5000) {
        log_message("Orbit circularized successfully!").
        log_message("AP: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km, PE: " +
                   ROUND(SHIP:PERIAPSIS/1000, 1) + " km").
    }
    ELSE {
        log_message("WARNING: Orbit not fully circular").
        log_message("AP: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km, PE: " +
                   ROUND(SHIP:PERIAPSIS/1000, 1) + " km").
    }
}

// =========================================================================
// MAIN PROGRAM
// =========================================================================

FUNCTION main {
    // Initialize mission
    IF NOT initialize_mission() {
        PRINT "Mission initialization failed!".
        RETURN.
    }

    // Wait for launch command (or auto-launch after countdown)
    PRINT "T-10 seconds...".
    FROM {LOCAL t IS 10.} UNTIL t = 0 STEP {SET t TO t - 1.} DO {
        PRINT "T-" + t + "     " AT(0, 20).
        WAIT 1.
    }

    log_message("LIFTOFF!").

    // Execute launch sequence
    phase_vertical_ascent().
    phase_gravity_turn().
    phase_coast_to_apoapsis().
    phase_circularization().

    // Mission complete
    UNLOCK STEERING.
    UNLOCK THROTTLE.

    clear_screen().
    print_header("MISSION COMPLETE").
    PRINT " ".
    PRINT "Final Orbit:".
    PRINT "  Apoapsis: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
    PRINT "  Periapsis: " + ROUND(SHIP:PERIAPSIS/1000, 1) + " km".
    PRINT "  Inclination: " + ROUND(SHIP:ORBIT:INCLINATION, 2) + "°".
    PRINT "  Eccentricity: " + ROUND(get_eccentricity(), 4).
    PRINT " ".

    IF ENABLE_BOOSTER_RECOVERY {
        PRINT "Boosters separated: " + BOOSTER_COUNT.
        PRINT "Check booster telemetry for landing status.".
    }

    log_message("Mission complete.").
}

// =========================================================================
// EXECUTE
// =========================================================================

main().
