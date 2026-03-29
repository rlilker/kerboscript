// =========================================================================
// BOOSTER STARTUP TEST (test_booster_start.ks)
// =========================================================================
// Tests the correct approach: copy script to booster's LOCAL volume,
// set BOOTFILENAME to local path, then DEACTIVATE/ACTIVATE.
// Per kOS docs: boot file must be on local drive, not archive (0:/).
// =========================================================================

@LAZYGLOBAL OFF.

SWITCH TO 0.

LOCAL log IS "0:/booster_start_test.log".
IF EXISTS(log) { DELETEPATH(log). }

FUNCTION tlog {
    PARAMETER msg.
    PRINT msg.
    LOG msg TO log.
}

tlog("=== Booster Startup Test ===").

LOCAL booster_part IS 0.
FOR part IN SHIP:PARTS {
    IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
        SET booster_part TO part.
        BREAK.
    }
}

IF booster_part = 0 {
    tlog("ERROR: No booster processor found").
} ELSE {
    LOCAL tag IS booster_part:TAG.
    LOCAL proc IS PROCESSOR(tag).
    LOCAL vol IS proc:VOLUME.
    LOCAL vol_name IS vol:NAME.

    tlog("Booster: " + tag + "  MODE=" + proc:MODE).
    tlog("Booster volume name: '" + vol_name + "'").

    // Step 1: Copy script to booster's local volume
    LOCAL local_path IS vol_name + ":/autoland_staging.ks".
    tlog("Copying to: " + local_path).
    COPYPATH("0:/autoland_staging.ks", local_path).
    tlog("  Copy done. File exists: " + EXISTS(local_path)).

    // Step 2: Deactivate, set BOOTFILENAME to LOCAL path, activate
    tlog("DEACTIVATE...").
    proc:DEACTIVATE().
    WAIT 0.5.
    tlog("  MODE after deactivate: " + proc:MODE).

    SET proc:BOOTFILENAME TO "autoland_staging.ks".  // local path only, no volume prefix
    tlog("  BOOTFILENAME set to: '" + proc:BOOTFILENAME + "'").

    tlog("ACTIVATE...").
    proc:ACTIVATE().
    WAIT 3.
    tlog("  MODE after activate: " + proc:MODE + "  BOOT=" + proc:BOOTFILENAME).

    tlog(" ").
    tlog("If autoland_staging.ks ran, a booster_*.log file will appear.").
    tlog("=== Done ===").
}

PRINT "Done. Check booster_start_test.log".
