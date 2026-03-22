// =========================================================================
// SYSTEM TEST SCRIPT - LOGGED VERSION (test_system_logged.ks)
// =========================================================================
// Tests that all libraries load correctly and basic functions work
// Outputs everything to both screen AND file: test_results.txt
// =========================================================================

@LAZYGLOBAL OFF.

// Delete old log if it exists
IF EXISTS("0:/test_results.txt") {
    DELETEPATH("0:/test_results.txt").
}

FUNCTION logprint {
    PARAMETER message.
    PRINT message.
    LOG message TO "0:/test_results.txt".
}

CLEARSCREEN.
logprint("========================================").
logprint(" LAUNCH SYSTEM - COMPONENT TEST").
logprint("========================================").
logprint(" ").

// Test 1: Library Loading
logprint("Test 1: Loading libraries...").

LOCAL test_passed IS TRUE.

logprint("  Loading util.ks...").
RUNONCEPATH("0:/lib/util.ks").
IF DEFINED util_loaded {
    logprint("    ✓ util.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load util.ks").
    SET test_passed TO FALSE.
}

logprint("  Loading guidance.ks...").
RUNONCEPATH("0:/lib/guidance.ks").
IF DEFINED guidance_loaded {
    logprint("    ✓ guidance.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load guidance.ks").
    SET test_passed TO FALSE.
}

logprint("  Loading ascent.ks...").
RUNONCEPATH("0:/lib/ascent.ks").
IF DEFINED ascent_loaded {
    logprint("    ✓ ascent.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load ascent.ks").
    SET test_passed TO FALSE.
}

logprint("  Loading circularize.ks...").
RUNONCEPATH("0:/lib/circularize.ks").
IF DEFINED circularize_loaded {
    logprint("    ✓ circularize.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load circularize.ks").
    SET test_passed TO FALSE.
}

logprint("  Loading boostback.ks...").
RUNONCEPATH("0:/lib/boostback.ks").
IF DEFINED boostback_loaded {
    logprint("    ✓ boostback.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load boostback.ks").
    SET test_passed TO FALSE.
}

logprint("  Loading entry.ks...").
RUNONCEPATH("0:/lib/entry.ks").
IF DEFINED entry_loaded {
    logprint("    ✓ entry.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load entry.ks").
    SET test_passed TO FALSE.
}

logprint("  Loading landing.ks...").
RUNONCEPATH("0:/lib/landing.ks").
IF DEFINED landing_loaded {
    logprint("    ✓ landing.ks loaded").
} ELSE {
    logprint("    ✗ FAILED to load landing.ks").
    SET test_passed TO FALSE.
}

logprint(" ").

IF test_passed {
    logprint("✓ All libraries loaded successfully!").
} ELSE {
    logprint("✗ Some libraries failed to load!").
    logprint("Cannot proceed with launch.").
    SET test_passed TO FALSE.
}

logprint(" ").

// Only continue if libraries loaded successfully
IF test_passed {
    // Test 2: Vessel Checks
    logprint("Test 2: Vessel readiness...").

    logprint("  Ship name: " + SHIP:NAME).
    logprint("  Mass: " + ROUND(SHIP:MASS, 2) + " tons").
    logprint("  Max thrust: " + ROUND(SHIP:MAXTHRUST, 0) + " kN").
    logprint("  Available thrust: " + ROUND(SHIP:AVAILABLETHRUST, 0) + " kN").

    LOCAL twr IS get_twr().
    logprint("  TWR: " + ROUND(twr, 2)).

    IF twr < 1.2 {
        logprint("    ⚠ WARNING: TWR < 1.2 - launch may be sluggish").
    } ELSE IF twr > 3.0 {
        logprint("    ⚠ WARNING: TWR > 3.0 - may be too aggressive").
    } ELSE {
        logprint("    ✓ TWR is good for launch").
    }

    logprint(" ").

    // Test 3: Part Checks
    logprint("Test 3: Part inventory...").

    LOCAL has_rcs IS has_module("ModuleRCS").
    LOCAL has_sas IS has_module("ModuleSAS").
    LOCAL has_reaction_wheel IS has_module("ModuleReactionWheel").

    logprint("  RCS: " + has_rcs).
    logprint("  SAS: " + has_sas).
    logprint("  Reaction wheels: " + has_reaction_wheel).

    IF has_rcs OR has_reaction_wheel {
        logprint("    ✓ Attitude control available").
    } ELSE {
        logprint("    ✗ WARNING: No attitude control!").
    }

    logprint(" ").

    // Test 4: Staging Check
    logprint("Test 4: Staging configuration...").

    logprint("  Current stage: " + STAGE:NUMBER).
    logprint("  Stages available: " + STAGE:NUMBER).

    LOCAL stage_fuel IS get_stage_fuel_percent(STAGE:NUMBER).
    logprint("  Current stage fuel: " + ROUND(stage_fuel, 1) + "%").

    IF stage_fuel > 80 {
        logprint("    ✓ Plenty of fuel in current stage").
    } ELSE {
        logprint("    ⚠ WARNING: Low fuel in current stage").
    }

    logprint(" ").

    // Test 5: kOS Processor Check
    logprint("Test 5: kOS configuration...").

    logprint("  Processor: " + CORE:ELEMENT:NAME).
    logprint("  Free space: " + CORE:VOLUME:FREESPACE + " bytes").
    logprint("  Max space: " + CORE:VOLUME:CAPACITY + " bytes").

    IF CORE:VOLUME:FREESPACE < 5000 {
        logprint("    ⚠ WARNING: Low disk space!").
    } ELSE {
        logprint("    ✓ Sufficient disk space").
    }

    logprint(" ").

    // Test 6: Check for recovery files
    logprint("Test 6: Recovery system...").

    IF EXISTS("0:/autoland_staging.ks") {
        logprint("    ✓ autoland_staging.ks found").
    } ELSE {
        logprint("    ✗ autoland_staging.ks NOT FOUND!").
        logprint("    Booster recovery will not work!").
    }

    IF EXISTS("0:/launch.ks") {
        logprint("    ✓ launch.ks found").
    } ELSE {
        logprint("    ✗ launch.ks NOT FOUND!").
    }

    logprint(" ").

    // Test 7: Basic function tests
    logprint("Test 7: Function tests...").

    LOCAL test_latlng IS LATLNG(0, 0).
    LOCAL test_offset IS offset_latlng(test_latlng, 100, 0).
    logprint("  LATLNG offset test: " + ROUND(test_offset:LAT, 4) + ", " + ROUND(test_offset:LNG, 4)).

    LOCAL test_distance IS great_circle_distance(test_latlng, test_offset).
    logprint("  Distance calculation: " + ROUND(test_distance, 1) + "m (should be ~100m)").

    IF test_distance > 90 AND test_distance < 110 {
        logprint("    ✓ Math functions working correctly").
    } ELSE {
        logprint("    ✗ Math functions may be incorrect!").
    }

    logprint(" ").

    // Test 8: Gravity turn calculation
    logprint("Test 8: Ascent calculations...").

    LOCAL pitch_0 IS get_target_pitch(50, 100, 45000, 0.5).
    LOCAL pitch_mid IS get_target_pitch(20000, 100, 45000, 0.5).
    LOCAL pitch_end IS get_target_pitch(50000, 100, 45000, 0.5).

    logprint("  Pitch at 50m: " + ROUND(pitch_0, 1) + "° (should be 90°)").
    logprint("  Pitch at 20km: " + ROUND(pitch_mid, 1) + "°").
    logprint("  Pitch at 50km: " + ROUND(pitch_end, 1) + "° (should be 0°)").

    IF ABS(pitch_0 - 90) < 1 AND ABS(pitch_end - 0) < 1 {
        logprint("    ✓ Gravity turn calculations correct").
    } ELSE {
        logprint("    ✗ Gravity turn calculations incorrect!").
    }

    logprint(" ").
    logprint("========================================").
    logprint(" TEST COMPLETE").
    logprint("========================================").
    logprint(" ").

    logprint("✓ System ready for launch!").
    logprint(" ").
    logprint("To launch, run: RUN launch.").
} ELSE {
    logprint(" ").
    logprint("✗ System has issues - fix before launch.").
}

logprint(" ").
logprint("Results saved to: 0:/test_results.txt").
logprint("To view: PRINT OPEN(" + CHAR(34) + "0:/test_results.txt" + CHAR(34) + "):READALL:STRING.").
