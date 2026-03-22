// =========================================================================
// SYSTEM TEST SCRIPT (test_system.ks)
// =========================================================================
// Tests that all libraries load correctly and basic functions work
// Run this before attempting a full launch
// =========================================================================

@LAZYGLOBAL OFF.

CLEARSCREEN.
PRINT "========================================".
PRINT " LAUNCH SYSTEM - COMPONENT TEST".
PRINT "========================================".
PRINT " ".

// Test 1: Library Loading
PRINT "Test 1: Loading libraries...".

LOCAL test_passed IS TRUE.

PRINT "  Loading util.ks...".
RUNONCEPATH("0:/lib/util.ks").
IF DEFINED util_loaded {
    PRINT "    ✓ util.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load util.ks".
    SET test_passed TO FALSE.
}

PRINT "  Loading guidance.ks...".
RUNONCEPATH("0:/lib/guidance.ks").
IF DEFINED guidance_loaded {
    PRINT "    ✓ guidance.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load guidance.ks".
    SET test_passed TO FALSE.
}

PRINT "  Loading ascent.ks...".
RUNONCEPATH("0:/lib/ascent.ks").
IF DEFINED ascent_loaded {
    PRINT "    ✓ ascent.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load ascent.ks".
    SET test_passed TO FALSE.
}

PRINT "  Loading circularize.ks...".
RUNONCEPATH("0:/lib/circularize.ks").
IF DEFINED circularize_loaded {
    PRINT "    ✓ circularize.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load circularize.ks".
    SET test_passed TO FALSE.
}

PRINT "  Loading boostback.ks...".
RUNONCEPATH("0:/lib/boostback.ks").
IF DEFINED boostback_loaded {
    PRINT "    ✓ boostback.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load boostback.ks".
    SET test_passed TO FALSE.
}

PRINT "  Loading entry.ks...".
RUNONCEPATH("0:/lib/entry.ks").
IF DEFINED entry_loaded {
    PRINT "    ✓ entry.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load entry.ks".
    SET test_passed TO FALSE.
}

PRINT "  Loading landing.ks...".
RUNONCEPATH("0:/lib/landing.ks").
IF DEFINED landing_loaded {
    PRINT "    ✓ landing.ks loaded".
} ELSE {
    PRINT "    ✗ FAILED to load landing.ks".
    SET test_passed TO FALSE.
}

PRINT " ".

IF test_passed {
    PRINT "✓ All libraries loaded successfully!".
} ELSE {
    PRINT "✗ Some libraries failed to load!".
    PRINT "Cannot proceed with launch.".
    SET test_passed TO FALSE.
}

PRINT " ".

// Only continue if libraries loaded successfully
IF test_passed {
    // Test 2: Vessel Checks
    PRINT "Test 2: Vessel readiness...".

PRINT "  Ship name: " + SHIP:NAME.
PRINT "  Mass: " + ROUND(SHIP:MASS, 2) + " tons".
PRINT "  Max thrust: " + ROUND(SHIP:MAXTHRUST, 0) + " kN".
PRINT "  Available thrust: " + ROUND(SHIP:AVAILABLETHRUST, 0) + " kN".

LOCAL twr IS get_twr().
PRINT "  TWR: " + ROUND(twr, 2).

IF twr < 1.2 {
    PRINT "    ⚠ WARNING: TWR < 1.2 - launch may be sluggish".
} ELSE IF twr > 3.0 {
    PRINT "    ⚠ WARNING: TWR > 3.0 - may be too aggressive".
} ELSE {
    PRINT "    ✓ TWR is good for launch".
}

PRINT " ".

// Test 3: Part Checks
PRINT "Test 3: Part inventory...".

LOCAL has_rcs IS has_module("ModuleRCS").
LOCAL has_sas IS has_module("ModuleSAS").
LOCAL has_reaction_wheel IS has_module("ModuleReactionWheel").

PRINT "  RCS: " + has_rcs.
PRINT "  SAS: " + has_sas.
PRINT "  Reaction wheels: " + has_reaction_wheel.

IF has_rcs OR has_reaction_wheel {
    PRINT "    ✓ Attitude control available".
} ELSE {
    PRINT "    ✗ WARNING: No attitude control!".
}

PRINT " ".

// Test 4: Staging Check
PRINT "Test 4: Staging configuration...".

PRINT "  Current stage: " + STAGE:NUMBER.
PRINT "  Stages available: " + STAGE:NUMBER.

LOCAL stage_fuel IS get_stage_fuel_percent(STAGE:NUMBER).
PRINT "  Current stage fuel: " + ROUND(stage_fuel, 1) + "%".

IF stage_fuel > 80 {
    PRINT "    ✓ Plenty of fuel in current stage".
} ELSE {
    PRINT "    ⚠ WARNING: Low fuel in current stage".
}

PRINT " ".

// Test 5: kOS Processor Check
PRINT "Test 5: kOS configuration...".

PRINT "  Processor: " + CORE:ELEMENT:NAME.
PRINT "  Free space: " + CORE:VOLUME:FREESPACE + " bytes".
PRINT "  Max space: " + CORE:VOLUME:CAPACITY + " bytes".

IF CORE:VOLUME:FREESPACE < 5000 {
    PRINT "    ⚠ WARNING: Low disk space!".
} ELSE {
    PRINT "    ✓ Sufficient disk space".
}

PRINT " ".

// Test 6: Check for recovery files
PRINT "Test 6: Recovery system...".

IF EXISTS("0:/autoland_staging.ks") {
    PRINT "    ✓ autoland_staging.ks found".
} ELSE {
    PRINT "    ✗ autoland_staging.ks NOT FOUND!".
    PRINT "    Booster recovery will not work!".
}

IF EXISTS("0:/launch.ks") {
    PRINT "    ✓ launch.ks found".
} ELSE {
    PRINT "    ✗ launch.ks NOT FOUND!".
}

PRINT " ".

// Test 7: Basic function tests
PRINT "Test 7: Function tests...".

LOCAL test_latlng IS LATLNG(0, 0).
LOCAL test_offset IS offset_latlng(test_latlng, 100, 0).
PRINT "  LATLNG offset test: " + ROUND(test_offset:LAT, 4) + ", " + ROUND(test_offset:LNG, 4).

LOCAL test_distance IS great_circle_distance(test_latlng, test_offset).
PRINT "  Distance calculation: " + ROUND(test_distance, 1) + "m (should be ~100m)".

IF test_distance > 90 AND test_distance < 110 {
    PRINT "    ✓ Math functions working correctly".
} ELSE {
    PRINT "    ✗ Math functions may be incorrect!".
}

PRINT " ".

// Test 8: Gravity turn calculation
PRINT "Test 8: Ascent calculations...".

LOCAL pitch_0 IS get_target_pitch(50, 100, 45000, 0.5).
LOCAL pitch_mid IS get_target_pitch(20000, 100, 45000, 0.5).
LOCAL pitch_end IS get_target_pitch(50000, 100, 45000, 0.5).

PRINT "  Pitch at 50m: " + ROUND(pitch_0, 1) + "° (should be 90°)".
PRINT "  Pitch at 20km: " + ROUND(pitch_mid, 1) + "°".
PRINT "  Pitch at 50km: " + ROUND(pitch_end, 1) + "° (should be 0°)".

IF ABS(pitch_0 - 90) < 1 AND ABS(pitch_end - 0) < 1 {
    PRINT "    ✓ Gravity turn calculations correct".
} ELSE {
    PRINT "    ✗ Gravity turn calculations incorrect!".
}

    PRINT " ".
    PRINT "========================================".
    PRINT " TEST COMPLETE".
    PRINT "========================================".
    PRINT " ".

    PRINT "✓ System ready for launch!".
    PRINT " ".
    PRINT "To launch, run: RUN launch.".
} ELSE {
    PRINT " ".
    PRINT "✗ System has issues - fix before launch.".
}
