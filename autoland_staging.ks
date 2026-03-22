// =========================================================================
// BOOSTER LANDING AUTOPILOT (autoland_staging.ks)
// =========================================================================
// Autonomous booster recovery - Return To Launch Site (RTLS)
// Runs independently on each separated booster
// Executes: flip, boostback, entry, descent, suicide burn, touchdown
// =========================================================================

@LAZYGLOBAL OFF.

// Load libraries
RUNONCEPATH("0:/lib/util.ks").
RUNONCEPATH("0:/lib/guidance.ks").
RUNONCEPATH("0:/lib/boostback.ks").
RUNONCEPATH("0:/lib/entry.ks").
RUNONCEPATH("0:/lib/landing.ks").

// =========================================================================
// LANDING CONFIGURATION (USER CONFIGURABLE)
// =========================================================================

// Target landing zone (KSC coordinates)
SET KSC_LAT TO -0.0972.              // KSC latitude
SET KSC_LON TO -74.5577.             // KSC longitude
SET LANDING_OFFSET_SPACING TO 10.    // Meters between booster landing zones

// Flight parameters
SET SUICIDE_MARGIN TO 1.20.          // 20% safety margin on suicide burn altitude
SET MAX_FLIP_TIME TO 10.             // Max seconds for flip maneuver
SET ENTRY_BURN_SPEED TO 800.         // Trigger entry burn if speed > 800 m/s at 15km
SET ENTRY_BURN_ALTITUDE TO 15000.    // Altitude to check for entry burn
SET FINAL_APPROACH_ALT TO 50.        // Switch to vertical orientation below this
SET GEAR_DEPLOY_ALT TO 100.          // Deploy landing gear at this altitude
SET TOUCHDOWN_SPEED TO 1.5.          // Target touchdown velocity (m/s)

// Guidance tuning
SET BOOSTBACK_MAX_BURN_TIME TO 60.   // Max seconds for boostback burn
SET BOOSTBACK_TARGET_ERROR TO 500.   // Stop boostback when within 500m of target
SET AIRBRAKE_DEPLOY_ALT TO 40000.    // Deploy airbrakes at this altitude (meters)

// =========================================================================
// BOOSTER IDENTIFICATION
// =========================================================================

FUNCTION assign_booster_id {
    // Assign unique ID based on global counter
    DECLARE GLOBAL BOOSTER_COUNT.

    IF NOT (DEFINED BOOSTER_COUNT) {
        SET BOOSTER_COUNT TO 0.
    }

    SET BOOSTER_COUNT TO BOOSTER_COUNT + 1.
    LOCAL my_id IS BOOSTER_COUNT.

    RETURN my_id.
}

FUNCTION calculate_landing_offset {
    PARAMETER booster_id.

    // Offset pattern: -10, 0, +10, -20, +20, -30, +30, ...
    // This spreads boosters east-west of target
    LOCAL offset_pattern IS LIST(-1, 0, 1, -2, 2, -3, 3, -4, 4).

    LOCAL offset_index IS MIN(booster_id - 1, offset_pattern:LENGTH - 1).

    IF offset_index >= offset_pattern:LENGTH {
        // For more boosters, continue pattern
        LOCAL extra IS offset_index - offset_pattern:LENGTH + 1.
        RETURN extra * LANDING_OFFSET_SPACING.
    }

    RETURN offset_pattern[offset_index] * LANDING_OFFSET_SPACING.
}

// =========================================================================
// INITIALIZATION
// =========================================================================

FUNCTION initialize_landing_system {
    // Wait for separation clearance
    WAIT 2.

    clear_screen().
    print_header("BOOSTER LANDING AUTOPILOT").

    // Assign booster ID
    LOCAL my_booster_id IS assign_booster_id().
    LOCAL my_offset IS calculate_landing_offset(my_booster_id).

    PRINT "Booster ID: " + my_booster_id.
    PRINT "Landing offset: " + my_offset + "m east".
    PRINT " ".

    // Calculate target landing zone
    LOCAL target_zone IS LATLNG(KSC_LAT, KSC_LON).
    LOCAL my_target IS offset_latlng(target_zone, my_offset, 0).

    PRINT "Target: LAT=" + ROUND(my_target:LAT, 4) + " LON=" + ROUND(my_target:LNG, 4).
    PRINT " ".

    // Verify vessel capabilities
    LOCAL current_twr IS get_twr().
    PRINT "Current TWR: " + ROUND(current_twr, 2).

    IF current_twr < 1.5 {
        PRINT "WARNING: Low TWR - landing may be difficult!".
    }

    PRINT " ".

    RETURN my_target.
}

// =========================================================================
// LANDING PHASES
// =========================================================================

FUNCTION phase_separation_coast {
    PARAMETER target_latlng.

    log_message("PHASE 1: Post-Separation Coast").

    // Enable RCS for stability
    RCS ON.

    // Coast briefly to gain clearance
    WAIT 3.

    // Assess trajectory
    LOCAL predicted_impact IS predict_current_impact(120, 1.0).
    LOCAL distance IS great_circle_distance(predicted_impact, target_latlng).

    log_message("Current trajectory: " + ROUND(distance/1000, 1) + " km from target").

    RETURN distance.
}

FUNCTION phase_flip {
    log_message("PHASE 2: Flip Maneuver").

    LOCAL flip_success IS execute_flip(MAX_FLIP_TIME).

    IF NOT flip_success {
        log_message("WARNING: Flip incomplete - continuing anyway").
    }

    RETURN flip_success.
}

FUNCTION phase_boostback {
    PARAMETER target_latlng.

    log_message("PHASE 3: Boostback Burn").

    // Assess if boostback is needed
    LOCAL needs_boostback IS assess_boostback_needed(target_latlng, 2000).

    IF needs_boostback {
        // Execute boostback burn
        LOCAL bb_success IS execute_boostback(
            target_latlng,
            BOOSTBACK_MAX_BURN_TIME,
            BOOSTBACK_TARGET_ERROR
        ).

        RETURN bb_success.
    }
    ELSE {
        log_message("Skipping boostback - already on trajectory").
        RETURN TRUE.
    }
}

FUNCTION phase_coast_entry {
    PARAMETER target_latlng.

    log_message("PHASE 4: Coast to Entry").

    // Maintain retrograde orientation
    LOCK STEERING TO RETROGRADE.

    LOCAL entry_burn_done IS FALSE.

    UNTIL SHIP:ALTITUDE < 20000 {
        // Deploy airbrakes at appropriate altitude
        IF SHIP:ALTITUDE < AIRBRAKE_DEPLOY_ALT AND SHIP:ALTITUDE > 1000 {
            IF NOT BRAKES {
                deploy_airbrakes().
                log_message("Airbrakes deployed").
            }
        }

        // Check for entry burn
        IF NOT entry_burn_done {
            IF check_and_execute_entry_burn(ENTRY_BURN_SPEED, ENTRY_BURN_ALTITUDE) {
                SET entry_burn_done TO TRUE.
            }
        }

        // Update display
        PRINT "Altitude: " + ROUND(SHIP:ALTITUDE/1000, 1) + " km          " AT(0, 10).
        PRINT "Speed: " + ROUND(SHIP:VELOCITY:SURFACE:MAG, 0) + " m/s          " AT(0, 11).

        WAIT 0.5.
    }

    log_message("Entered lower atmosphere").
}

FUNCTION phase_descent {
    PARAMETER target_latlng.

    log_message("PHASE 5: Descent").

    // Coast to landing altitude while maintaining retrograde + correction
    coast_to_landing_altitude(5000, target_latlng).
}

FUNCTION phase_landing {
    PARAMETER target_latlng.

    log_message("PHASE 6: Landing Burn").

    // Execute suicide burn and touchdown
    execute_landing(target_latlng, SUICIDE_MARGIN).
}

FUNCTION phase_post_landing {
    PARAMETER target_latlng.

    log_message("PHASE 7: Post-Landing").

    // Shutdown systems
    LOCK THROTTLE TO 0.
    LOCK STEERING TO SHIP:UP.
    RCS OFF.
    SAS ON.

    // Calculate final statistics
    LOCAL landing_error IS great_circle_distance(SHIP:GEOPOSITION, target_latlng).
    LOCAL touchdown_speed IS SHIP:VELOCITY:SURFACE:MAG.

    WAIT 2.

    // Display final report
    clear_screen().
    print_header("LANDING COMPLETE").
    PRINT " ".
    PRINT "Landing Statistics:".
    PRINT "  Landing Error: " + ROUND(landing_error, 1) + " m".
    PRINT "  Touchdown Speed: " + ROUND(touchdown_speed, 2) + " m/s".
    PRINT "  Final Position: LAT=" + ROUND(SHIP:GEOPOSITION:LAT, 4) +
          " LON=" + ROUND(SHIP:GEOPOSITION:LNG, 4).
    PRINT " ".

    // Landing quality assessment
    IF landing_error < 10 {
        PRINT "  EXCELLENT LANDING! (< 10m error)".
    }
    ELSE IF landing_error < 50 {
        PRINT "  Good landing (< 50m error)".
    }
    ELSE IF landing_error < 200 {
        PRINT "  Acceptable landing (< 200m error)".
    }
    ELSE {
        PRINT "  Rough landing (" + ROUND(landing_error, 0) + "m error)".
    }

    IF touchdown_speed < 2 {
        PRINT "  Soft touchdown (< 2 m/s)".
    }
    ELSE IF touchdown_speed < 5 {
        PRINT "  Moderate touchdown (< 5 m/s)".
    }
    ELSE {
        PRINT "  Hard touchdown (" + ROUND(touchdown_speed, 1) + " m/s)".
    }

    PRINT " ".
    log_message("Booster recovery complete.").
}

// =========================================================================
// MAIN PROGRAM
// =========================================================================

FUNCTION main {
    // Initialize landing system
    LOCAL target_latlng IS initialize_landing_system().

    // Execute landing sequence
    LOCAL separation_distance IS phase_separation_coast(target_latlng).
    phase_flip().
    phase_boostback(target_latlng).
    phase_coast_entry(target_latlng).
    phase_descent(target_latlng).
    phase_landing(target_latlng).
    phase_post_landing(target_latlng).

    // Script complete
    UNLOCK ALL.
}

// =========================================================================
// ERROR HANDLING
// =========================================================================

// Wrap main in error handler
LOCAL error_occurred IS FALSE.

ON ABORT {
    PRINT "ABORT DETECTED - Emergency landing!".
    LOCK THROTTLE TO 0.
    LOCK STEERING TO SHIP:UP.
    PRESERVE.
}

// Check for critical errors
IF SHIP:MAXTHRUST = 0 {
    PRINT "CRITICAL ERROR: No engines available!".
    PRINT "Emergency ballistic descent...".
    LOCK STEERING TO RETROGRADE.
    deploy_airbrakes().
    deploy_gear().
    SET error_occurred TO TRUE.
}

IF NOT error_occurred {
    main().
}
ELSE {
    PRINT "Landing script terminated due to errors.".
}
