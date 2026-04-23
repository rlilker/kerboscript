// =========================================================================
// MISSION BOOT SCRIPT (boot/launch_system.ks)
// =========================================================================
// Automatically runs pre-flight tests and initiates launch.
// Select this as the boot file for the main vessel in the VAB.
// =========================================================================

WAIT UNTIL SHIP:UNPACKED.
CLEARSCREEN.
FOR p IN SHIP:PARTS {
    IF p:HASMODULE("kOSProcessor") {
        p:GETMODULE("kOSProcessor"):DOEVENT("Open Terminal").
    }
}
WAIT 2.
PRINT "Booting Launch System...".

SWITCH TO 0.

IF EXISTS("test.ks") {
    PRINT "Initiating Pre-Flight Tests...".
    RUN test.
    
    // Check if tests passed (test.ks sets PREFLIGHT_OK)
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
