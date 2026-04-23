// =========================================================================
// LAUNCH AUTOPILOT (launch.ks)
// =========================================================================
// Automated gravity turn ascent with asparagus staging and circularization
// Triggers booster recovery scripts on separated boosters
// =========================================================================

@LAZYGLOBAL OFF.

// Load config (pulls in util.ks + all user-tunable settings)
RUNONCEPATH("0:/config.ks").
RUNONCEPATH("0:/lib/ascent.ks").
RUNONCEPATH("0:/lib/circularize.ks").

// =========================================================================
// GLOBAL STATE
// =========================================================================

GLOBAL BOOSTER_COUNT IS 0.
GLOBAL BOOSTER_PROCS IS LIST().   // processor references for all active boosters

// =========================================================================
// PRE-LAUNCH INITIALIZATION
// =========================================================================

FUNCTION initialize_mission {
    // Wipe all .log files for a clean slate each flight
    LOCAL old_logs IS LIST().
    LIST FILES IN old_logs.
    FOR f IN old_logs {
        IF f:NAME:ENDSWITH(".log") {
            DELETEPATH("0:/" + f:NAME).
        }
    }

    clear_screen().
    print_header("LAUNCH AUTOPILOT").

    PRINT "Mission Parameters:".
    PRINT "  Target Apoapsis: " + ROUND(TARGET_APOAPSIS/1000, 1) + " km".
    PRINT "  Target Inclination: " + TARGET_INCLINATION + "°".
    PRINT "  Turn Start: " + TURN_START_ALTITUDE + " m".
    PRINT "  Turn End: " + ROUND(TURN_END_ALTITUDE/1000, 1) + " km".
    PRINT "  Booster Recovery: " + ENABLE_BOOSTER_RECOVERY.
    PRINT " ".

    // Validate apoapsis — must be above the atmosphere
    LOCAL atm_height IS BODY:ATM:HEIGHT.
    IF TARGET_APOAPSIS <= atm_height {
        PRINT "ERROR: TARGET_APOAPSIS " + ROUND(TARGET_APOAPSIS/1000,1) +
              "km is inside " + BODY:NAME + "'s atmosphere (" +
              ROUND(atm_height/1000,1) + "km).".
        RETURN FALSE.
    }

    // Load autoland scripts onto booster processors
    IF ENABLE_BOOSTER_RECOVERY {
        IF NOT EXISTS("0:/autoland_staging.ks") {
            PRINT "WARNING: autoland_staging.ks not found — recovery disabled.".
            SET ENABLE_BOOSTER_RECOVERY TO FALSE.
        } ELSE {
            setup_booster_processors().
        }
    }

    RETURN TRUE.
}

// =========================================================================
// BOOSTER SETUP
// =========================================================================

// Finds all kOS processors whose Name Tag starts with "booster".
// Boots autoland_staging.ks from archive on each, waits for READY,
// then populates BOOSTER_PROCS for later DECOUPLE signaling.
FUNCTION setup_booster_processors {
    LOCAL booster_parts IS LIST().

    FOR part IN SHIP:PARTS {
        IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
            booster_parts:ADD(part).
        }
    }

    IF booster_parts:LENGTH = 0 {
        tlog("No booster processors found (set Name Tag to 'booster_N' in VAB)").
        RETURN.
    }

    tlog("Arming " + booster_parts:LENGTH + " booster(s) with autoland_staging.ks...").

    FOR part IN booster_parts {
        LOCAL proc IS PROCESSOR(part:TAG).
        LOCAL vol IS proc:VOLUME.
        COPYPATH("0:/autoland_boot.ks", vol).
        proc:DEACTIVATE().
        WAIT 0.1.
        SET proc:BOOTFILENAME TO "autoland_boot.ks".
        proc:ACTIVATE().
        tlog("  " + part:TAG + " booted via stub").
    }

    // Wait for READY from autoland_staging.ks on each booster
    LOCAL boosters_ready IS 0.
    LOCAL ready_deadline IS TIME:SECONDS + 90.
    UNTIL boosters_ready >= booster_parts:LENGTH OR TIME:SECONDS > ready_deadline {
        UNTIL CORE:MESSAGES:EMPTY {
            LOCAL msg IS CORE:MESSAGES:POP.
            IF msg:CONTENT = "READY" {
                SET boosters_ready TO boosters_ready + 1.
                tlog("  READY (" + boosters_ready + "/" + booster_parts:LENGTH + ")").
            }
        }
        PRINT "Boosters armed: " + boosters_ready + "/" + booster_parts:LENGTH + "     " AT(0, 9).
        WAIT 0.5.
    }
    PRINT "                                          " AT(0, 9).

    IF boosters_ready < booster_parts:LENGTH {
        tlog("WARNING: Only " + boosters_ready + "/" + booster_parts:LENGTH + " boosters ready").
    } ELSE {
        tlog("All " + boosters_ready + " booster(s) armed and in standby").
    }

    FOR part IN booster_parts {
        BOOSTER_PROCS:ADD(part:TAG).
    }

    // Build per-booster assembly cache: live fuel-part refs, dry_kg, lf_cap, Isp.
    // Used by check_staging_needed() every 0.1s via get_booster_fuel_pct().
    build_booster_assemblies().
}

// =========================================================================
// STAGING LOGIC
// =========================================================================

FUNCTION perform_staging {
    LOCAL current_stage IS STAGE:NUMBER.
    LOCAL next_stg IS get_next_booster_stage().
    LOCAL fuel_log IS "unknown".
    IF next_stg >= 0 { SET fuel_log TO ROUND(get_stage_fuel_percent(next_stg), 1) + "%". }
    tlog("Staging initiated - booster fuel at " + fuel_log +
                " (DECOUPLEDIN=" + next_stg + ", STAGE:NUMBER=" + current_stage + ")").

    // Declared at function scope so the intermediate-stage timer reset below can read it
    // even if ENABLE_BOOSTER_RECOVERY is FALSE or BOOSTER_PROCS is empty.
    LOCAL separating IS LIST().

    // Signal only the boosters that are actually separating at this stage event.
    // Boosters at a different DECOUPLEDIN (e.g. booster_3 decoupling later) stay
    // in BOOSTER_PROCS to receive their DECOUPLE message when their stage fires.
    IF ENABLE_BOOSTER_RECOVERY AND BOOSTER_PROCS:LENGTH > 0 {
        LOCAL staying IS LIST().
        FOR tag IN BOOSTER_PROCS {
            LOCAL b_dcpl IS -1.
            FOR part IN SHIP:PARTS {
                IF part:TAG = tag AND part:HASMODULE("kOSProcessor") {
                    IF part:DECOUPLEDIN > b_dcpl { SET b_dcpl TO part:DECOUPLEDIN. }
                }
            }
            IF b_dcpl = current_stage {
                separating:ADD(tag).
            } ELSE {
                staying:ADD(tag).
            }
        }

        IF separating:LENGTH > 0 {
            FOR tag IN separating {
                PROCESSOR(tag):CONNECTION:SENDMESSAGE("DECOUPLE").
            }
            SET BOOSTER_COUNT TO BOOSTER_COUNT + separating:LENGTH.
            tlog("DECOUPLE sent to " + separating:LENGTH + " booster(s) at stage " + current_stage).
            BOOSTER_PROCS:CLEAR().
            FOR tag IN staying {
                BOOSTER_PROCS:ADD(tag).
            }
            WAIT 1.5.  // Wait for booster message poll (0.5s interval) + throttle cut before decoupler fires
        } ELSE {
            tlog("No booster DECOUPLEDIN matched stage " + current_stage + " -- intermediate stage, firing").
        }
    }

    // Fire the decoupler (or intermediate activation stage)
    STAGE.
    WAIT 1.0.

    tlog("Stage fired. Total boosters separated: " + BOOSTER_COUNT).

    // If no booster matched this stage but boosters are still pending, reset the
    // staging timer so check_staging_needed() fires immediately at the new STAGE:NUMBER.
    // Handles any intermediate activation stages between launch and a booster's DECOUPLEDIN.
    IF separating:LENGTH = 0 AND BOOSTER_PROCS:LENGTH > 0 {
        SET LAST_STAGE_TIME TO 0.
        tlog("Intermediate stage consumed -- staging timer reset for next stage").
    }
}

// =========================================================================
// LAUNCH PHASES
// =========================================================================

FUNCTION phase_vertical_ascent {
    tlog("PHASE 1: Vertical Ascent").

    LOCK STEERING TO HEADING(90, 90).  // East, vertical
    LOCK THROTTLE TO 1.0.

    WAIT UNTIL SHIP:ALTITUDE > TURN_START_ALTITUDE.

    tlog("Reached turn start altitude").
}

FUNCTION phase_gravity_turn {
    tlog("PHASE 2: Gravity Turn").

    // Log initial staging state so we can see what parts were found
    LOCAL init_stg IS get_next_booster_stage().
    tlog("Staging group scan: DECOUPLEDIN=" + init_stg +
                "  STAGE:NUMBER=" + STAGE:NUMBER).
    FOR part IN SHIP:PARTS {
        FOR res IN part:RESOURCES {
            IF res:NAME = "LiquidFuel" AND res:CAPACITY > 0 {
                tlog("  Part=" + part:NAME +
                            "  DECOUPLEDIN=" + part:DECOUPLEDIN +
                            "  LF=" + ROUND(res:AMOUNT,0) + "/" + ROUND(res:CAPACITY,0)).
            }
        }
    }

    // Calculate launch azimuth
    LOCAL launch_heading IS get_launch_azimuth(TARGET_INCLINATION).
    LOCAL last_log_time IS TIME:SECONDS.

    UNTIL SHIP:APOAPSIS >= TARGET_APOAPSIS {
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

        // Get current booster fuel state
        LOCAL b_stg IS get_next_booster_stage().
        LOCAL b_fuel IS 0.
        LOCAL b_cap IS 0.
        IF b_stg >= 0 {
            SET b_fuel TO get_stage_fuel(b_stg).
            SET b_cap TO get_stage_fuel_capacity(b_stg).
        }
        LOCAL b_pct IS 0.
        IF b_cap > 0 { SET b_pct TO (b_fuel / b_cap) * 100. }

        // Staging warning: alert when booster fuel is within 3% of the separation threshold
        IF b_stg >= 0 {
            LOCAL stg_threshold IS get_booster_dv_threshold_pct(b_stg).
            IF b_pct < stg_threshold + 3 {
                SET TEL_STAGE_WARN TO ">>> BOOSTER SEPARATION IMMINENT <<<".
            } ELSE {
                SET TEL_STAGE_WARN TO "".
            }
        } ELSE {
            SET TEL_STAGE_WARN TO "".
        }

        // Check staging
        IF check_staging_needed() {
            SET TEL_STAGE_WARN TO "".
            perform_staging().
        }

        // Display telemetry
        show_launch_hud(
            "GRAVITY TURN",
            ROUND(SHIP:ALTITUDE/1000, 1),
            ROUND(SHIP:APOAPSIS/1000, 1),
            ROUND(target_pitch, 1),
            ROUND(throttle_val * 100, 0),
            ROUND(b_pct, 1),
            b_stg,
            STAGE:NUMBER
        ).

        // Log fuel state every 5 seconds
        IF (TIME:SECONDS - last_log_time) >= 5 {
            tlog("Fuel: booster=" + ROUND(b_pct,1) + "% (" +
                        ROUND(b_fuel,0) + "/" + ROUND(b_cap,0) + " LF)" +
                        "  DCPL=" + b_stg + "  STG=" + STAGE:NUMBER +
                        "  AP=" + ROUND(SHIP:APOAPSIS/1000,1) + "km").
            SET last_log_time TO TIME:SECONDS.
        }

        WAIT 0.1.
    }

    tlog("Apoapsis reached: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km").
}

FUNCTION phase_coast_to_apoapsis {
    tlog("PHASE 3: Coast to Apoapsis").

    LOCK THROTTLE TO 0.

    // Follow prograde during coast
    LOCK STEERING TO PROGRADE.

    // Stage any remaining boosters before circularization — even if already above atmosphere
    UNTIL SHIP:ALTITUDE > BODY:ATM:HEIGHT OR get_next_booster_stage() < 0 {
        IF check_staging_needed() {
            perform_staging().
        }

        WAIT 1.0.
    }

    tlog("Exited atmosphere").
}

FUNCTION phase_circularization {
    tlog("PHASE 4: Circularization").

    // Create maneuver node
    LOCAL circ_node IS create_circularization_node(TARGET_PERIAPSIS).

    // Execute the node
    execute_node(circ_node, 30).

    // Verify orbit
    IF is_orbit_circular(5000) {
        tlog("Orbit circularized successfully!").
        tlog("AP: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km, PE: " +
                   ROUND(SHIP:PERIAPSIS/1000, 1) + " km").
    }
    ELSE {
        tlog("WARNING: Orbit not fully circular").
        tlog("AP: " + ROUND(SHIP:APOAPSIS/1000, 1) + " km, PE: " +
                   ROUND(SHIP:PERIAPSIS/1000, 1) + " km").
    }
}

// =========================================================================
// MAIN PROGRAM
// =========================================================================

FUNCTION main {
    SET LOG_FILE TO "0:/flight.log".
    CLEARSCREEN.
    tlog("launch.ks started. Run test.ks separately for pre-flight checks.").

    // Initialize mission (booster setup, parameter validation)
    IF NOT initialize_mission() {
        PRINT "Mission initialization failed!".
        RETURN.
    }

    // Automatic Staging & Countdown
    IF SHIP:MAXTHRUST = 0 {
        tlog("Engines inactive - staging to activate...").
        STAGE.
        WAIT 0.5.
    }

    PRINT "T-10 seconds...".
    FROM {LOCAL t IS 10.} UNTIL t = 0 STEP {SET t TO t - 1.} DO {
        PRINT "T-" + t + " seconds...          " AT(0, 9).
        WAIT 1.
    }

    tlog("LIFTOFF!").
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 1.0.

    // Execute launch sequence
    phase_vertical_ascent().
    phase_gravity_turn().
    phase_coast_to_apoapsis().
    phase_circularization().

    // Mission complete
    SET SHIP:CONTROL:PILOTMAINTHROTTLE TO 0.
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

    tlog("Mission complete.").
}

// =========================================================================
// EXECUTE
// =========================================================================

main().
