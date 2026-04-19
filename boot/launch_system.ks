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
    PRINT "Tests Passed. Starting Launch Sequence...".
    RUN launch.
}
