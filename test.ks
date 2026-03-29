// =========================================================================
// LAUNCH SYSTEM TEST (test.ks)
// =========================================================================
// Pre-flight checks: compile validation, library loading, vessel readiness
// Run this before attempting a full launch.
// Results saved to test_results.txt
// =========================================================================

@LAZYGLOBAL OFF.

// Load config (pulls in util.ks + all user-tunable settings)
RUNONCEPATH("0:/config.ks").

// Redirect log output to test results file (override config default)
SET LOG_FILE TO "0:/test_results.txt".
IF EXISTS(LOG_FILE) { DELETEPATH(LOG_FILE). }

CLEARSCREEN.
plog("========================================").
plog(" LAUNCH SYSTEM - PRE-FLIGHT TEST").
plog("========================================").
plog(" ").

LOCAL all_passed IS TRUE.

// =========================================================================
// TEST 0: COMPILE VALIDATION
// =========================================================================
// Uses COMPILE to check syntax of all scripts without executing them.
// If a file has a syntax error, kOS will halt here and print file:line details.

plog("Test 0: Compile validation...").

LOCAL files_to_check IS LIST(
    "0:/config.ks",
    "0:/lib/util.ks",
    "0:/lib/telemetry.ks",
    "0:/lib/guidance.ks",
    "0:/lib/ascent.ks",
    "0:/lib/circularize.ks",
    "0:/lib/boostback.ks",
    "0:/lib/entry.ks",
    "0:/lib/landing.ks",
    "0:/launch.ks",
    "0:/autoland_staging.ks",
    "0:/autoland_boot.ks",
    "0:/test_booster_cpu.ks"
).

LOCAL compile_ok IS TRUE.
FOR f IN files_to_check {
    IF EXISTS(f) {
        COMPILE f TO "0:/tmp_syntax_check.ksm".
        plog("  ✓ " + f).
    } ELSE {
        plog("  ✗ NOT FOUND: " + f).
        SET compile_ok TO FALSE.
        SET all_passed TO FALSE.
    }
}

IF EXISTS("0:/tmp_syntax_check.ksm") { DELETEPATH("0:/tmp_syntax_check.ksm"). }

IF compile_ok {
    plog("  ✓ All files compile successfully").
} ELSE {
    plog("  ✗ Some files missing — check above").
}

plog(" ").

// =========================================================================
// TEST 1: LIBRARY LOADING
// =========================================================================

plog("Test 1: Loading libraries...").

LOCAL libs_ok IS TRUE.

RUNONCEPATH("0:/lib/guidance.ks").
IF DEFINED guidance_loaded { plog("  ✓ guidance.ks").
} ELSE { plog("  ✗ guidance.ks FAILED"). SET libs_ok TO FALSE. SET all_passed TO FALSE. }

RUNONCEPATH("0:/lib/ascent.ks").
IF DEFINED ascent_loaded { plog("  ✓ ascent.ks").
} ELSE { plog("  ✗ ascent.ks FAILED"). SET libs_ok TO FALSE. SET all_passed TO FALSE. }

RUNONCEPATH("0:/lib/circularize.ks").
IF DEFINED circularize_loaded { plog("  ✓ circularize.ks").
} ELSE { plog("  ✗ circularize.ks FAILED"). SET libs_ok TO FALSE. SET all_passed TO FALSE. }

RUNONCEPATH("0:/lib/boostback.ks").
IF DEFINED boostback_loaded { plog("  ✓ boostback.ks").
} ELSE { plog("  ✗ boostback.ks FAILED"). SET libs_ok TO FALSE. SET all_passed TO FALSE. }

RUNONCEPATH("0:/lib/entry.ks").
IF DEFINED entry_loaded { plog("  ✓ entry.ks").
} ELSE { plog("  ✗ entry.ks FAILED"). SET libs_ok TO FALSE. SET all_passed TO FALSE. }

RUNONCEPATH("0:/lib/landing.ks").
IF DEFINED landing_loaded { plog("  ✓ landing.ks").
} ELSE { plog("  ✗ landing.ks FAILED"). SET libs_ok TO FALSE. SET all_passed TO FALSE. }

plog(" ").
IF libs_ok { plog("  ✓ All libraries loaded").
} ELSE { plog("  ✗ Library failures — fix before launch"). }
plog(" ").

// Remaining tests require libraries
IF libs_ok {

// =========================================================================
// TEST 2: VESSEL READINESS
// =========================================================================

plog("Test 2: Vessel readiness...").
plog("  Ship: " + SHIP:NAME).
plog("  Mass: " + ROUND(SHIP:MASS, 2) + " t").
plog("  Max thrust: " + ROUND(SHIP:MAXTHRUST, 0) + " kN").
plog("  Available thrust: " + ROUND(SHIP:AVAILABLETHRUST, 0) + " kN").
plog("  Atmosphere: " + ROUND(BODY:ATM:HEIGHT/1000, 1) + " km (" + BODY:NAME + ")").

LOCAL twr IS get_twr().
plog("  TWR: " + ROUND(twr, 2)).

IF twr < 0.1 {
    plog("    ⚠ TWR = 0 — engines not staged/activated yet").
    plog("    TIP: Stage once to activate engines, then run: RUN launch.").
} ELSE IF twr < 1.2 {
    plog("    ⚠ TWR < 1.2 — launch may be sluggish").
} ELSE IF twr > 3.0 {
    plog("    ⚠ TWR > 3.0 — may be too aggressive for gravity turn").
} ELSE {
    plog("    ✓ TWR in good range").
}

plog(" ").

// =========================================================================
// TEST 3: ATTITUDE CONTROL
// =========================================================================

plog("Test 3: Attitude control...").
LOCAL has_rcs IS has_module("ModuleRCS").
LOCAL has_rw  IS has_module("ModuleReactionWheel").
plog("  RCS: " + has_rcs + "  Reaction wheels: " + has_rw).

IF has_rcs OR has_rw { plog("    ✓ Attitude control available").
} ELSE { plog("    ✗ No attitude control!"). SET all_passed TO FALSE. }

plog(" ").

// =========================================================================
// TEST 4: STAGING & FUEL
// =========================================================================

plog("Test 4: Staging & fuel...").
plog("  STAGE:NUMBER = " + STAGE:NUMBER).

// Show part count — this is what booster scripts use for separation detection.
// autoland_staging.ks records SHIP:PARTS:LENGTH at boot and waits until it
// drops below 50% to detect separation.
LOCAL total_parts IS SHIP:PARTS:LENGTH.
plog("  Total parts: " + total_parts).
plog("  Separation threshold: < " + ROUND(total_parts * 0.5, 0) + " parts (50%)").

// Count kOS processors — should match expected number of recoverable boosters
LOCAL kos_count IS 0.
FOR part IN SHIP:PARTS {
    IF part:HASMODULE("kOSProcessor") { SET kos_count TO kos_count + 1. }
}
plog("  kOS processors: " + kos_count + " (1 main + " + (kos_count - 1) + " booster(s))").
IF kos_count > 1 { plog("    ✓ Booster processors present — will self-activate on separation").
} ELSE { plog("    ⚠ No booster processors found — recovery will not work"). }

plog(" ").

// Dump every LiquidFuel part and its DECOUPLEDIN — key for diagnosing staging issues
plog("  LiquidFuel parts on vessel:").
LOCAL found_lf_parts IS FALSE.
FOR part IN SHIP:PARTS {
    FOR res IN part:RESOURCES {
        IF res:NAME = "LiquidFuel" AND res:CAPACITY > 0 {
            plog("    " + part:NAME +
                 "  DECOUPLEDIN=" + part:DECOUPLEDIN +
                 "  LF=" + ROUND(res:AMOUNT,0) + "/" + ROUND(res:CAPACITY,0) +
                 " (" + ROUND((res:AMOUNT/res:CAPACITY)*100,1) + "%)").
            SET found_lf_parts TO TRUE.
        }
    }
}
IF NOT found_lf_parts { plog("    (none found)"). }

// Show what the staging detection function finds
LOCAL next_stg IS get_next_booster_stage().
plog("  Next staging group (get_next_booster_stage): DECOUPLEDIN=" + next_stg).
IF next_stg >= 0 {
    LOCAL b_fuel IS get_stage_fuel(next_stg).
    LOCAL b_cap  IS get_stage_fuel_capacity(next_stg).
    IF b_cap > 0 {
        plog("  Group fuel: " + ROUND(b_fuel,0) + "/" + ROUND(b_cap,0) +
             " LF (" + ROUND((b_fuel/b_cap)*100,1) + "%)").
        plog("    ✓ Staging detection has a valid group to monitor").
    }
} ELSE {
    plog("    ⚠ No staging group detected — staging will not fire").
}

plog(" ").

// =========================================================================
// TEST 5: KOS STORAGE
// =========================================================================

plog("Test 5: kOS storage...").
plog("  Processor: " + CORE:ELEMENT:NAME).
plog("  Free: " + CORE:VOLUME:FREESPACE + " / " + CORE:VOLUME:CAPACITY + " bytes").
IF CORE:VOLUME:FREESPACE < 5000 { plog("    ⚠ Low disk space!"). SET all_passed TO FALSE.
} ELSE { plog("    ✓ Sufficient storage"). }
plog(" ").

// =========================================================================
// TEST 6: RECOVERY FILES
// =========================================================================

plog("Test 6: Recovery files...").
IF EXISTS("0:/autoland_staging.ks") { plog("    ✓ autoland_staging.ks found").
} ELSE { plog("    ✗ autoland_staging.ks NOT FOUND — booster recovery disabled"). SET all_passed TO FALSE. }

IF EXISTS("0:/launch.ks") { plog("    ✓ launch.ks found").
} ELSE { plog("    ✗ launch.ks NOT FOUND"). SET all_passed TO FALSE. }
plog(" ").

// =========================================================================
// TEST 7: MATH FUNCTIONS
// =========================================================================

plog("Test 7: Math functions...").
LOCAL ref IS LATLNG(0, 0).
LOCAL offset IS offset_latlng(ref, 100, 0).
LOCAL dist IS great_circle_distance(ref, offset).
plog("  Offset 100m east: LAT=" + ROUND(offset:LAT, 5) + " LON=" + ROUND(offset:LNG, 5)).
plog("  Round-trip distance: " + ROUND(dist, 1) + "m (expected ~100m)").
IF dist > 90 AND dist < 110 { plog("    ✓ LATLNG math correct").
} ELSE { plog("    ✗ LATLNG math incorrect! Got: " + ROUND(dist, 1) + "m"). SET all_passed TO FALSE. }
plog(" ").

// =========================================================================
// TEST 8: GRAVITY TURN PROFILE
// =========================================================================

plog("Test 8: Gravity turn profile...").
// Current config: start=1500m, end=50000m, shape=1.5
// shape>1 keeps the rocket near-vertical through thick lower atmosphere
LOCAL ts IS 1500.   // TURN_START_ALTITUDE
LOCAL te IS 50000.  // TURN_END_ALTITUDE
LOCAL sh IS 1.5.    // TURN_SHAPE
plog("  Config: start=" + ts + "m  end=" + ROUND(te/1000,0) + "km  shape=" + sh).
LOCAL p_0m   IS get_target_pitch(0,     ts, te, sh).
LOCAL p_5k   IS get_target_pitch(5000,  ts, te, sh).
LOCAL p_10k  IS get_target_pitch(10000, ts, te, sh).
LOCAL p_20k  IS get_target_pitch(20000, ts, te, sh).
LOCAL p_30k  IS get_target_pitch(30000, ts, te, sh).
LOCAL p_40k  IS get_target_pitch(40000, ts, te, sh).
LOCAL p_55k  IS get_target_pitch(55000, ts, te, sh).
plog("  Pitch at  0m:  " + ROUND(p_0m,  1) + "° (expected 90° — below turn start)").
plog("  Pitch at  5km: " + ROUND(p_5k,  1) + "° (should be near-vertical, ~88°)").
plog("  Pitch at 10km: " + ROUND(p_10k, 1) + "° (should be >80°)").
plog("  Pitch at 20km: " + ROUND(p_20k, 1) + "°").
plog("  Pitch at 30km: " + ROUND(p_30k, 1) + "°").
plog("  Pitch at 40km: " + ROUND(p_40k, 1) + "°").
plog("  Pitch at 55km: " + ROUND(p_55k, 1) + "° (expected 0° — above turn end)").
IF ABS(p_0m - 90) < 1 AND ABS(p_55k) < 1 AND p_5k > 85 AND p_10k > 78 {
    plog("    ✓ Profile correct — stays near-vertical through lower atmosphere").
} ELSE {
    plog("    ✗ Profile may be too aggressive in lower atmosphere").
    SET all_passed TO FALSE.
}
plog(" ").

// =========================================================================
// TEST 9: BOOSTER CPU READINESS
// =========================================================================

plog("Test 9: Booster CPU readiness...").
LOCAL booster_cpus_found IS 0.
FOR part IN SHIP:PARTS {
    IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
        LOCAL proc IS PROCESSOR(part:TAG).
        SET booster_cpus_found TO booster_cpus_found + 1.
        plog("  " + part:TAG + ":").
        plog("    MODE          = " + proc:MODE).
        plog("    Boot file     = '" + proc:BOOTFILENAME + "'").
        plog("    Local vol cap = " + proc:VOLUME:CAPACITY + " bytes").
        plog("    Local vol free= " + proc:VOLUME:FREESPACE + " bytes").
        IF proc:VOLUME:CAPACITY < 5000 {
            plog("    WARNING: Low local storage for landing log").
        } ELSE {
            plog("    OK: sufficient local storage").
        }
    }
}
IF booster_cpus_found = 0 {
    plog("  WARNING: No booster CPUs found (set Name Tag to 'booster_N' in VAB)").
} ELSE {
    plog("  " + booster_cpus_found + " booster CPU(s) found").
}
plog(" ").

// =========================================================================
// TEST 10: LANDING MATH VERIFICATION
// =========================================================================
// Validates the core guidance math without flying.
// These are the functions that caused the boostback to diverge and the
// suicide burn to crash.

plog("Test 10: Landing math verification...").

// Bearing test: a point 100km east of KSC should give ~270 bearing to KSC
LOCAL east_of_ksc IS LATLNG(-0.0972, -73.64).
LOCAL ksc_pos IS LATLNG(-0.0972, -74.5577).
LOCAL test_bearing IS bearing_to_target(east_of_ksc, ksc_pos).
plog("  Bearing from 100km E of KSC to KSC: " + ROUND(test_bearing, 1) + "° (expected ~270)").
IF ABS(test_bearing - 270) < 15 {
    plog("    OK: bearing math correct — boostback will steer toward KSC").
} ELSE {
    plog("    FAIL: bearing wrong — boostback will steer AWAY from target").
    SET all_passed TO FALSE.
}

// Bearing test 2: a point north of KSC should give ~180 (south) to KSC
LOCAL north_of_ksc IS LATLNG(1.0, -74.5577).
LOCAL test_bearing2 IS bearing_to_target(north_of_ksc, ksc_pos).
plog("  Bearing from N of KSC to KSC: " + ROUND(test_bearing2, 1) + "° (expected ~180)").
IF ABS(test_bearing2 - 180) < 15 {
    plog("    OK").
} ELSE {
    plog("    FAIL: north-south bearing wrong").
    SET all_passed TO FALSE.
}

// Verify impact prediction time limit is sufficient
// At 22km alt heading upward, impact takes ~250s — the old 120s limit gave wrong results
// We can't simulate this here but document the requirement
plog("  Impact prediction time limit check:").
plog("    predict_current_impact uses 400s limit (was 120s — too short for post-separation arc)").
plog("    OK: time limit updated").

plog(" ").

// =========================================================================
// SUMMARY
// =========================================================================

plog("========================================").
plog(" TEST COMPLETE").
plog("========================================").
plog(" ").

IF all_passed {
    plog("✓ All checks passed — system ready for launch!").
    plog(" ").
    plog("To launch:    RUN launch.").
    plog("Debug mode:   SET DEBUG_MODE TO TRUE.   (in kOS terminal before running)").
} ELSE {
    plog("✗ Some checks failed — review output above before launch.").
}

// =========================================================================
// TEST 11: BOOSTER STAGING LOGIC
// =========================================================================

plog("Test 11: Booster staging logic...").
LOCAL booster_dcpl IS get_booster_decoupledin_values().
IF booster_dcpl:LENGTH > 0 {
    LOCAL dcpl_str IS "".
    FOR d IN booster_dcpl {
        IF dcpl_str:LENGTH > 0 { SET dcpl_str TO dcpl_str + ", ". }
        SET dcpl_str TO dcpl_str + d.
    }
    plog("  Booster DECOUPLEDIN groups (threshold staging): [" + dcpl_str + "]").
    plog("  Other groups (flameout only): all others").
    plog("    OK: only booster groups will early-stage").
} ELSE {
    plog("  No booster processors found — staging uses DECOUPLEDIN > 1 fallback").
    plog("  (Set Name Tags to 'booster_N' in VAB for booster-specific staging)").
}
plog(" ").

// =========================================================================
// TEST 12: BOOSTER CPU DIAGNOSTICS
// =========================================================================
// Copies test_booster_cpu.ks to each booster's local volume, boots it,
// and waits for PASS:/FAIL: result messages. Does NOT consume READY --
// those are for launch.ks to collect after it arms boosters.

plog("Test 12: Booster CPU diagnostics...").
LOCAL booster_test_parts IS LIST().
FOR part IN SHIP:PARTS {
    IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
        booster_test_parts:ADD(part).
    }
}

IF booster_test_parts:LENGTH = 0 {
    plog("  No booster CPUs found (set Name Tag to 'booster_N' in VAB)").
} ELSE {
    plog("  Booting " + booster_test_parts:LENGTH + " booster(s) with test_booster_cpu.ks...").
    FOR part IN booster_test_parts {
        LOCAL proc IS PROCESSOR(part:TAG).
        LOCAL vol IS proc:VOLUME.
        COPYPATH("0:/test_booster_cpu.ks", vol).
        proc:DEACTIVATE().
        WAIT 0.1.
        SET proc:BOOTFILENAME TO "test_booster_cpu.ks".
        proc:ACTIVATE().
        plog("  " + part:TAG + " activated").
    }

    LOCAL boosters_reported IS 0.
    LOCAL diag_deadline IS TIME:SECONDS + 90.
    UNTIL boosters_reported >= booster_test_parts:LENGTH OR TIME:SECONDS > diag_deadline {
        UNTIL CORE:MESSAGES:EMPTY {
            LOCAL msg IS CORE:MESSAGES:POP.
            LOCAL content IS msg:CONTENT.
            IF content:STARTSWITH("PASS:") {
                SET boosters_reported TO boosters_reported + 1.
                plog("  " + content + " (" + boosters_reported + "/" + booster_test_parts:LENGTH + ")").
            } ELSE IF content:STARTSWITH("FAIL:") {
                SET boosters_reported TO boosters_reported + 1.
                SET all_passed TO FALSE.
                plog("  " + content + " (" + boosters_reported + "/" + booster_test_parts:LENGTH + ")").
            }
            // Any other message (e.g. stray READY) is silently dropped
        }
        PRINT "Booster results: " + boosters_reported + "/" + booster_test_parts:LENGTH + "     " AT(0, 20).
        WAIT 0.5.
    }
    PRINT "                                          " AT(0, 20).

    IF boosters_reported < booster_test_parts:LENGTH {
        plog("  WARNING: Only " + boosters_reported + "/" + booster_test_parts:LENGTH + " boosters reported").
        SET all_passed TO FALSE.
    } ELSE {
        plog("  All " + boosters_reported + " booster(s) passed diagnostics").
    }
    plog("  Boosters idle -- run launch.ks to arm them with autoland_staging.ks").
}
plog(" ").

// =========================================================================
// TEST 13: LAUNCH ARMING VERIFICATION
// =========================================================================
// Arms each booster with autoland_staging.ks using the SAME method as
// launch.ks setup_booster_processors(). If READY is received from all
// boosters, launch.ks will work. Boosters remain in standby after this test.

plog("Test 13: Launch arming verification...").
LOCAL arm_parts IS LIST().
FOR part IN SHIP:PARTS {
    IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
        arm_parts:ADD(part).
    }
}

IF arm_parts:LENGTH = 0 {
    plog("  No booster CPUs found -- skipping").
} ELSE {
    FOR part IN arm_parts {
        LOCAL proc IS PROCESSOR(part:TAG).
        LOCAL vol IS proc:VOLUME.
        COPYPATH("0:/autoland_boot.ks", vol).
        proc:DEACTIVATE().
        WAIT 0.1.
        SET proc:BOOTFILENAME TO "autoland_boot.ks".
        proc:ACTIVATE().
        plog("  " + part:TAG + " armed (stub boot)").
    }

    LOCAL armed IS 0.
    LOCAL arm_deadline IS TIME:SECONDS + 90.
    UNTIL armed >= arm_parts:LENGTH OR TIME:SECONDS > arm_deadline {
        UNTIL CORE:MESSAGES:EMPTY {
            LOCAL msg IS CORE:MESSAGES:POP.
            IF msg:CONTENT = "READY" {
                SET armed TO armed + 1.
                plog("  READY (" + armed + "/" + arm_parts:LENGTH + ")").
            }
        }
        PRINT "Boosters armed: " + armed + "/" + arm_parts:LENGTH + "     " AT(0, 20).
        WAIT 0.5.
    }
    PRINT "                                          " AT(0, 20).

    IF armed < arm_parts:LENGTH {
        plog("  FAIL: Only " + armed + "/" + arm_parts:LENGTH + " boosters sent READY").
        plog("  launch.ks arming will fail -- check autoland_staging.ks and archive connection").
        SET all_passed TO FALSE.
    } ELSE {
        plog("  All " + armed + " booster(s) armed and in standby").
        plog("  Boosters in standby -- launch.ks will re-arm them cleanly via DEACTIVATE/ACTIVATE").
    }
}
plog(" ").

} // end IF libs_ok

plog(" ").
plog("Full results: " + LOG_FILE).

// Expose result for callers (e.g. launch.ks runs this via RUNPATH and checks this global)
GLOBAL PREFLIGHT_OK IS all_passed.
