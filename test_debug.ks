// =========================================================================
// DEBUG TEST - Ultra-defensive version
// =========================================================================

@LAZYGLOBAL OFF.

IF EXISTS("0:/test_results.txt") {
    DELETEPATH("0:/test_results.txt").
}

FUNCTION logprint {
    PARAMETER message.
    PRINT message.
    LOG message TO "0:/test_results.txt".
}

CLEARSCREEN.
logprint("DEBUG TEST - Finding the crash point").
logprint("=========================================").
logprint(" ").

logprint("Step 1: Loading libraries...").
RUNONCEPATH("0:/lib/util.ks").
logprint("  ✓ util.ks loaded").

RUNONCEPATH("0:/lib/guidance.ks").
logprint("  ✓ guidance.ks loaded").

RUNONCEPATH("0:/lib/ascent.ks").
logprint("  ✓ ascent.ks loaded").

RUNONCEPATH("0:/lib/circularize.ks").
logprint("  ✓ circularize.ks loaded").

RUNONCEPATH("0:/lib/boostback.ks").
logprint("  ✓ boostback.ks loaded").

RUNONCEPATH("0:/lib/entry.ks").
logprint("  ✓ entry.ks loaded").

RUNONCEPATH("0:/lib/landing.ks").
logprint("  ✓ landing.ks loaded").

logprint(" ").
logprint("Step 2: Basic ship info...").
logprint("  Ship name: " + SHIP:NAME).
logprint("  Current stage: " + STAGE:NUMBER).
logprint(" ").

logprint("Step 3: Testing LIST ENGINES command...").
logprint("  About to call LIST ENGINES...").

// This is where it might be crashing
LOCAL engine_list IS LIST().
LIST ENGINES IN engine_list.

logprint("  ✓ LIST ENGINES succeeded").
logprint("  Engine count: " + engine_list:LENGTH).

logprint(" ").
logprint("Step 4: Iterating through engines...").

LOCAL engine_count IS 0.
FOR eng IN engine_list {
    SET engine_count TO engine_count + 1.
    logprint("  Engine " + engine_count + ": " + eng:NAME + " (Stage: " + eng:STAGE + ")").
}

logprint(" ").
logprint("Step 5: Testing SHIP:PARTS...").
LOCAL part_count IS 0.
FOR part IN SHIP:PARTS {
    SET part_count TO part_count + 1.
    IF part_count <= 5 {
        logprint("  Part " + part_count + ": " + part:NAME).
    }
}
logprint("  Total parts: " + part_count).

logprint(" ").
logprint("Step 6: Testing resource access...").
LOCAL eng_with_resources IS 0.
FOR eng IN engine_list {
    LOCAL has_fuel_resource IS FALSE.

    FOR res IN eng:RESOURCES {
        IF res:NAME = "LIQUIDFUEL" {
            SET has_fuel_resource TO TRUE.
            SET eng_with_resources TO eng_with_resources + 1.
        }
    }
}
logprint("  Engines with fuel resources: " + eng_with_resources).

logprint(" ").
logprint("=========================================").
logprint("✓ ALL STEPS COMPLETED - No crash!").
logprint("=========================================").
logprint(" ").
logprint("This means the crash is in the test logic, not the LIST command.").
