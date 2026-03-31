// =========================================================================
// BOOSTER CPU DIAGNOSTIC (test_booster_cpu.ks)
// =========================================================================
// Runs on each booster CPU during pre-flight test (loaded by setup_booster_processors).
// Shows a test report on the booster terminal and reports PASS/FAIL to main vessel.
// =========================================================================

@LAZYGLOBAL OFF.

SWITCH TO 0.

CLEARSCREEN.
PRINT "=== BOOSTER CPU DIAGNOSTIC ===".
PRINT "Tag: " + CORE:TAG.
PRINT "------------------------------".

LOCAL tag IS CORE:TAG.
LOCAL pass IS TRUE.
LOCAL fail_reason IS "".

FUNCTION check {
    PARAMETER label, result, expected IS TRUE.
    IF result = expected {
        PRINT "  OK  " + label.
    } ELSE {
        PRINT " FAIL " + label.
        SET pass TO FALSE.
        IF fail_reason:LENGTH = 0 { SET fail_reason TO label. }
    }
}

// Test 1: Archive connection
PRINT " ".
PRINT "1. Connectivity:".
check("Archive connected", HOMECONNECTION:ISCONNECTED).
check("Local vol accessible", CORE:VOLUME:CAPACITY > 0).
LOCAL vol_ok IS CORE:VOLUME:FREESPACE > 5000.
check("Local vol space (>5000 bytes)", vol_ok).
PRINT "   Free: " + CORE:VOLUME:FREESPACE + " bytes".

// Test 2: Archive write (if connected)
PRINT " ".
PRINT "2. Archive I/O:".
IF HOMECONNECTION:ISCONNECTED {
    LOCAL test_flag IS "0:/" + tag + "_diag.flag".
    LOG "test" TO test_flag.
    LOCAL write_ok IS EXISTS(test_flag).
    IF write_ok { DELETEPATH(test_flag). }
    check("Archive write", write_ok).
} ELSE {
    PRINT "  SKIP Archive write (no connection)".
}

// Test 3: Load landing libraries
PRINT " ".
PRINT "3. Libraries:".
RUNONCEPATH("0:/config.ks").
check("config.ks", DEFINED config_loaded).
RUNONCEPATH("0:/lib/util.ks").
check("util.ks", DEFINED util_loaded).
RUNONCEPATH("0:/lib/guidance.ks").
check("guidance.ks", DEFINED guidance_loaded).
RUNONCEPATH("0:/lib/boostback.ks").
check("boostback.ks", DEFINED boostback_loaded).
RUNONCEPATH("0:/lib/entry.ks").
check("entry.ks", DEFINED entry_loaded).
RUNONCEPATH("0:/lib/landing.ks").
check("landing.ks", DEFINED landing_loaded).

// Test 4: Key config values
PRINT " ".
PRINT "4. Config values:".
check("KSC_LAT defined", DEFINED KSC_LAT).
check("KSC_LON defined", DEFINED KSC_LON).
check("SUICIDE_MARGIN defined", DEFINED SUICIDE_MARGIN).
check("MAX_FLIP_TIME defined", DEFINED MAX_FLIP_TIME).
check("BOOSTBACK_MAX_BURN_TIME defined", DEFINED BOOSTBACK_MAX_BURN_TIME).
check("FINAL_CORRECTION_CUTOFF_ALT defined", DEFINED FINAL_CORRECTION_CUTOFF_ALT).
check("DECOUPLE_PUSH_STRENGTH defined", DEFINED DECOUPLE_PUSH_STRENGTH).
check("LANDING_TARGET_TOLERANCE defined", DEFINED LANDING_TARGET_TOLERANCE).
check("TERMINAL_RCS_POSITION_GAIN defined", DEFINED TERMINAL_RCS_POSITION_GAIN).

// Test 5: Bearing math (core to boostback guidance)
PRINT " ".
PRINT "5. Bearing math:".
LOCAL east_pt IS LATLNG(-0.0972, -73.64).
LOCAL ksc_pt IS LATLNG(-0.0972, -74.5577).
LOCAL b IS bearing_to_target(east_pt, ksc_pt).
check("E of KSC -> KSC ~270 deg", ABS(b - 270) < 15).
PRINT "   Got: " + ROUND(b, 1) + " deg (expect ~270)".

// Test 6: TWR info (engines not staged on launchpad, so just show the value)
PRINT " ".
PRINT "6. Landing readiness:".
LOCAL twr IS get_twr().
PRINT "   TWR: " + ROUND(twr, 2) + " (0 = engines not yet staged, OK on launchpad)".

// Summary
PRINT " ".
PRINT "------------------------------".
IF pass {
    PRINT "RESULT: PASS".
} ELSE {
    PRINT "RESULT: FAIL - " + fail_reason.
}
PRINT "==============================".

// Clear the boot file so the processor won't auto-restart on vessel switch/battery.
PRINT " ".
SET CORE:BOOTFILENAME TO "".

// Report back to main vessel (launch_vessel processor)
LOCAL result IS "PASS:" + tag.
IF NOT pass { SET result TO "FAIL:" + tag + ":" + fail_reason. }

IF HOMECONNECTION:ISCONNECTED {
    PROCESSOR("launch_vessel"):CONNECTION:SENDMESSAGE(result).
} ELSE {
    // No connection -- write result to archive when available, or just continue
    LOG result TO ("0:/" + tag + "_diag_result.log").
}
