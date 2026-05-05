// =========================================================================
// MISSION BOOT SCRIPT (boot/launch_system.ks)
// =========================================================================
// Automatically runs pre-flight tests and initiates launch.
// Select this as the boot file for the main vessel in the VAB.
//
// Detects mission stage on boot so resuming focus (e.g. after FMRS booster
// recovery) does not restart the launch sequence from scratch:
//
//   AP > atm AND PE > 0  →  stable orbit — show status, stay idle
//   velocity > 50 m/s   →  mid-flight restart — skip tests, resume launch.ks
//   otherwise           →  pre-launch — normal test + countdown + launch
// =========================================================================

WAIT UNTIL SHIP:UNPACKED.
CLEARSCREEN.
FOR p IN SHIP:PARTS {
    IF p:HASMODULE("kOSProcessor") {
        p:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
    }
}
WAIT 2.

SWITCH TO 0.

LOCAL atm_top IS BODY:ATM:HEIGHT.

IF SHIP:APOAPSIS > atm_top AND SHIP:PERIAPSIS > 0 {
    // -----------------------------------------------------------------------
    // STABLE ORBIT — vessel already circularised.
    // Fires on FMRS resume after booster recovery, or any post-mission reboot.
    // -----------------------------------------------------------------------
    PRINT "=== " + SHIP:NAME + " ===".
    PRINT "Vessel in stable orbit.".
    PRINT "  AP:  " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
    PRINT "  PE:  " + ROUND(SHIP:PERIAPSIS/1000, 1) + " km".
    PRINT "  Inc: " + ROUND(SHIP:ORBIT:INCLINATION, 2) + " deg".
    PRINT " ".
    PRINT "kOS idle. Ready for terminal commands.".

} ELSE IF SHIP:VELOCITY:SURFACE:MAG > 50 OR SHIP:ALTITUDE > 500 {
    // -----------------------------------------------------------------------
    // MID-FLIGHT — kOS processor restarted during ascent or coast.
    // Skip tests and countdown; launch.ks will resume from the current state.
    // -----------------------------------------------------------------------
    PRINT "Mid-flight boot detected.".
    PRINT "  Alt: " + ROUND(SHIP:ALTITUDE/1000, 1) + " km".
    PRINT "  AP:  " + ROUND(SHIP:APOAPSIS/1000, 1) + " km".
    PRINT " ".
    PRINT "Skipping pre-flight checks. Resuming ascent...".
    IF EXISTS("launch.ks") { RUN launch. }

} ELSE {
    // -----------------------------------------------------------------------
    // PRE-LAUNCH — normal boot from the pad.
    // -----------------------------------------------------------------------
    PRINT "Booting Launch System...".

    IF EXISTS("test.ks") {
        PRINT "Initiating Pre-Flight Tests...".
        RUN test.

        IF DEFINED PREFLIGHT_OK AND NOT PREFLIGHT_OK {
            PRINT " ".
            PRINT "!!! PRE-FLIGHT TESTS FAILED !!!".
            PRINT "Launch aborted. Check test_results.txt".
            SHUTDOWN.
        }
    }

    IF EXISTS("launch.ks") {
        PRINT " ".
        PRINT "Tests passed. Launching in 10 seconds - press Ctrl+C to abort.".
        FROM {LOCAL t IS 10.} UNTIL t = 0 STEP {SET t TO t - 1.} DO {
            PRINT "  " + t + "..." AT(0, TERMINAL:HEIGHT - 2).
            WAIT 1.
        }
        RUN launch.
    }
}
