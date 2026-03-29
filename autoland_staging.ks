// =========================================================================
// BOOSTER LANDING AUTOPILOT (autoland_staging.ks)
// =========================================================================
// Loaded onto booster processors by launch.ks before launch.
// Receives a processor reference from the main vessel on startup,
// signals READY, waits for DECOUPLE command, then lands autonomously.
// =========================================================================

@LAZYGLOBAL OFF.

SWITCH TO 0.

// =========================================================================
// PHASE 0: STANDBY
// =========================================================================
// Main vessel sends its CORE processor reference as the first message,
// then signals "START". We respond "READY" and wait for "DECOUPLE".

RUNONCEPATH("0:/config.ks").

LOCAL init_parts IS SHIP:PARTS:LENGTH.

// Unique log file per booster using its Name Tag
LOCAL booster_log IS "0:/booster_" + CORE:TAG + ".log".
IF EXISTS(booster_log) { DELETEPATH(booster_log). }
SET LOG_FILE TO booster_log.
tlog("Booster standby started on " + SHIP:NAME).

RUNONCEPATH("0:/lib/guidance.ks").
RUNONCEPATH("0:/lib/boostback.ks").
RUNONCEPATH("0:/lib/entry.ks").
RUNONCEPATH("0:/lib/landing.ks").

// =========================================================================
// PHASE 0: STANDBY (skipped on FMRS rewind / airborne boot)
// =========================================================================
// If already airborne at boot, skip standby. This happens when:
//   1. FMRS rewinds to separation and the kOS processor boots fresh
//   2. kOS processor power-cycled and reboots during flight
// In both cases, proceed directly into the landing sequence.
LOCAL already_separated IS SHIP:VELOCITY:SURFACE:MAG > 50 OR SHIP:ALTITUDE > 500.

IF already_separated {
    tlog("Airborne boot detected -- skipping standby (FMRS or power cycle recovery)").
} ELSE {
    // Signal the main vessel processor that we're loaded and in standby.
    // Main vessel kOS processor must have Name Tag set to "launch_vessel" in the VAB.
    PROCESSOR("launch_vessel"):CONNECTION:SENDMESSAGE("READY").
    tlog("Sent READY to launch_vessel").

    // Standby display — wait for DECOUPLE from main vessel
    UNTIL NOT CORE:MESSAGES:EMPTY {
        show_standby_hud().
        // Fallback: if physically separated without receiving DECOUPLE message
        IF SHIP:PARTS:LENGTH < init_parts * 0.5 {
            tlog("Separation detected via parts count (no message received)").
            BREAK.
        }
        WAIT 0.5.
    }
    // Pop the DECOUPLE message if one arrived; if we broke out via parts-count fallback the queue is empty
    IF NOT CORE:MESSAGES:EMPTY {
        LOCAL decouple_msg IS CORE:MESSAGES:POP.
        tlog("Received: " + decouple_msg:CONTENT).
    } ELSE {
        tlog("Proceeding via separation fallback (no DECOUPLE message)").
    }
}

// =========================================================================
// SEPARATION — cut engines and begin landing
// =========================================================================

LOCK THROTTLE TO 0.
LOCK STEERING TO RETROGRADE.
RCS ON.
deploy_airbrakes().  // Top-mounted airbrakes: stabilise retrograde orientation + slow descent

// After physical separation, archive (0:/) requires an antenna connection to KSC.
// The separation event briefly drops the link even with antennae fitted.
// Wait up to 10s for connection to re-establish; fall back to local volume if needed.
LOCAL conn_deadline IS TIME:SECONDS + 10.
UNTIL HOMECONNECTION:ISCONNECTED OR TIME:SECONDS > conn_deadline { WAIT 0.2. }
IF NOT HOMECONNECTION:ISCONNECTED {
    tlog("No archive connection").
} ELSE {
    tlog("Archive connection OK").
}
// Keep LOG_FILE as archive path — log_message handles connection drops gracefully
tlog("Landing log: " + LOG_FILE).

tlog("Throttle cut. Beginning landing sequence.").

// Wait for vessel to be in full physics simulation before acting
WAIT UNTIL SHIP:UNPACKED.
tlog("Vessel in physics simulation").

// =========================================================================
// BOOSTER IDENTIFICATION
// =========================================================================

FUNCTION assign_booster_id {
    // Derive ID from CORE:TAG — tag is "booster_1", "booster_2" etc.
    LOCAL id IS CORE:TAG:REPLACE("booster_", ""):TONUMBER(1).
    RETURN id.
}

FUNCTION calculate_landing_offset {
    PARAMETER booster_id.
    LOCAL offset_pattern IS LIST(-1, 0, 1, -2, 2, -3, 3, -4, 4).
    LOCAL offset_index IS MIN(booster_id - 1, offset_pattern:LENGTH - 1).
    IF offset_index >= offset_pattern:LENGTH {
        RETURN (offset_index - offset_pattern:LENGTH + 1) * LANDING_OFFSET_SPACING.
    }
    RETURN offset_pattern[offset_index] * LANDING_OFFSET_SPACING.
}

// =========================================================================
// INITIALIZATION
// =========================================================================

FUNCTION initialize_landing_system {
    CLEARSCREEN.
    print_header("BOOSTER LANDING AUTOPILOT").

    LOCAL my_booster_id IS assign_booster_id().
    LOCAL my_offset IS calculate_landing_offset(my_booster_id).

    tlog("Booster ID: " + my_booster_id + "  Offset: " + my_offset + "m east").

    LOCAL target_zone IS LATLNG(KSC_LAT, KSC_LON).
    LOCAL my_target IS offset_latlng(target_zone, my_offset, 0).
    SET BOOSTER_TARGET TO my_target.

    tlog("Target: LAT=" + ROUND(my_target:LAT, 4) + " LON=" + ROUND(my_target:LNG, 4)).

    LOCAL twr IS get_twr().
    tlog("TWR: " + ROUND(twr, 2)).
    IF twr < 1.5 { tlog("WARNING: Low TWR - landing may be difficult"). }

    RETURN my_target.
}

// =========================================================================
// LANDING PHASES
// =========================================================================

FUNCTION phase_separation_coast {
    PARAMETER target_latlng.
    tlog("PHASE 1: Post-Separation Coast").
    WAIT 3.
    LOCAL predicted_impact IS predict_current_impact(400, 1.0).
    LOCAL distance IS great_circle_distance(predicted_impact, target_latlng).
    tlog("Trajectory: " + ROUND(distance/1000, 1) + " km from target").
    RETURN distance.
}

FUNCTION phase_flip {
    tlog("PHASE 2: Flip Maneuver").
    LOCAL flip_success IS execute_flip(MAX_FLIP_TIME).
    IF NOT flip_success { tlog("WARNING: Flip incomplete - continuing"). }
    RETURN flip_success.
}

FUNCTION phase_boostback {
    PARAMETER target_latlng.
    tlog("PHASE 3: Boostback Burn").
    IF assess_boostback_needed(target_latlng, 2000) {
        RETURN execute_boostback(target_latlng, BOOSTBACK_MAX_BURN_TIME, BOOSTBACK_TARGET_ERROR).
    }
    tlog("Skipping boostback - already on trajectory").
    RETURN TRUE.
}

FUNCTION phase_coast_entry {
    PARAMETER target_latlng.
    tlog("PHASE 4: Coast to Entry").
    LOCK STEERING TO RETROGRADE.
    LOCAL entry_burn_done IS FALSE.
    UNTIL SHIP:ALTITUDE < 20000 {
        IF SHIP:ALTITUDE < AIRBRAKE_DEPLOY_ALT AND NOT BRAKES {
            deploy_airbrakes().
            tlog("Airbrakes deployed at " + ROUND(SHIP:ALTITUDE/1000, 1) + " km").
        }
        IF NOT entry_burn_done {
            IF check_and_execute_entry_burn(ENTRY_BURN_SPEED, ENTRY_BURN_ALTITUDE) {
                SET entry_burn_done TO TRUE.
            }
        }
        LOCAL airbrake_status IS "".
        IF BRAKES { SET airbrake_status TO "Airbrakes: DEPLOYED". }
        ELSE { SET airbrake_status TO "Airbrakes: retracted". }
        show_booster_hud("COAST TO ENTRY", airbrake_status).
        WAIT 0.5.
    }
    tlog("Entered lower atmosphere").
}

FUNCTION phase_descent {
    PARAMETER target_latlng.
    tlog("PHASE 5: Descent").
    coast_to_landing_altitude(5000, target_latlng).
}

FUNCTION phase_landing {
    PARAMETER target_latlng.
    tlog("PHASE 6: Landing Burn").
    execute_landing(target_latlng, SUICIDE_MARGIN).
}

FUNCTION phase_post_landing {
    PARAMETER target_latlng.
    tlog("PHASE 7: Post-Landing").
    LOCK THROTTLE TO 0.
    LOCK STEERING TO SHIP:UP.
    RCS OFF.
    SAS ON.
    LOCAL landing_error IS great_circle_distance(SHIP:GEOPOSITION, target_latlng).
    LOCAL touchdown_speed IS SHIP:VELOCITY:SURFACE:MAG.
    WAIT 2.
    CLEARSCREEN.
    print_header("LANDING COMPLETE").
    tlog("Landing error: " + ROUND(landing_error, 1) + " m").
    tlog("Touchdown speed: " + ROUND(touchdown_speed, 2) + " m/s").
    IF landing_error < 10  { tlog("EXCELLENT LANDING! (< 10m)"). }
    ELSE IF landing_error < 50  { tlog("Good landing (< 50m)"). }
    ELSE IF landing_error < 200 { tlog("Acceptable landing (< 200m)"). }
    ELSE { tlog("Rough landing (" + ROUND(landing_error, 0) + "m)"). }
}

// =========================================================================
// MAIN
// =========================================================================

ON ABORT {
    PRINT "ABORT - Emergency descent.".
    LOCK THROTTLE TO 0.
    LOCK STEERING TO SHIP:UP.
    PRESERVE.
}

LOCAL target_latlng IS initialize_landing_system().
phase_separation_coast(target_latlng).
phase_flip().
phase_boostback(target_latlng).
phase_coast_entry(target_latlng).
phase_descent(target_latlng).
phase_landing(target_latlng).
phase_post_landing(target_latlng).
UNLOCK ALL.
