// =========================================================================
// ASCENT LIBRARY (ascent.ks)
// =========================================================================
// Gravity turn calculations and staging management
// =========================================================================

@LAZYGLOBAL OFF.

RUNONCEPATH("0:/lib/util.ks").

// =========================================================================
// STAGING STATE
// =========================================================================

GLOBAL LAST_STAGE_TIME IS 0.

// Key: booster processor DECOUPLEDIN (= separation stage).
// Value: LEXICON("fuel_parts" -> LIST of live part refs with LF,
//                "dry_kg" -> kg, "lf_cap" -> LF units, "isp" -> s).
// Populated once at setup by build_booster_assemblies().
GLOBAL BOOSTER_ASSEMBLIES IS LEXICON().

// =========================================================================
// GRAVITY TURN PROFILE
// =========================================================================

// Calculate target pitch angle for gravity turn
FUNCTION get_target_pitch {
    PARAMETER current_altitude, turn_start_alt, turn_end_alt, turn_shape.

    IF current_altitude < turn_start_alt {
        RETURN 90.  // Vertical ascent
    }
    ELSE IF current_altitude > turn_end_alt {
        RETURN 0.   // Horizontal (follow prograde)
    }
    ELSE {
        // Smooth polynomial turn
        LOCAL turn_fraction IS (current_altitude - turn_start_alt) /
                                (turn_end_alt - turn_start_alt).
        LOCAL pitch IS 90 * (1 - turn_fraction^turn_shape).
        RETURN pitch.
    }
}

// Calculate launch azimuth for target inclination
FUNCTION get_launch_azimuth {
    PARAMETER target_inclination.

    // Simplified azimuth calculation (works near equator)
    // For more accuracy, use full spherical trigonometry

    IF target_inclination = 0 {
        RETURN 90.  // Due east for equatorial orbit
    }

    LOCAL inertial_azimuth IS ARCSIN(
        MAX(-1, MIN(1, COS(target_inclination) / COS(SHIP:LATITUDE)))
    ).

    // Choose prograde (eastward) launch
    IF target_inclination >= 0 {
        RETURN 90 - inertial_azimuth.
    }
    ELSE {
        RETURN 90 + inertial_azimuth.
    }
}

// =========================================================================
// THROTTLE CONTROL
// =========================================================================

// Calculate throttle to maintain max dynamic pressure limit
FUNCTION get_q_limited_throttle {
    PARAMETER max_q.

    // Dynamic pressure: Q = 0.5 * rho * v^2
    LOCAL speed IS SHIP:VELOCITY:SURFACE:MAG.
    LOCAL rho IS get_atmospheric_density(SHIP:ALTITUDE).
    LOCAL current_q IS 0.5 * rho * speed^2.

    IF current_q > max_q {
        // Reduce throttle proportionally
        LOCAL throttle_reduction IS SQRT(max_q / current_q).
        RETURN MAX(0.5, throttle_reduction).  // Never go below 50%
    }

    RETURN 1.0.  // Full throttle
}

// Calculate throttle to approach target apoapsis smoothly
FUNCTION get_apoapsis_throttle {
    PARAMETER target_ap, current_ap, approach_margin IS 5000.

    // How close are we to target?
    LOCAL error IS target_ap - current_ap.

    // If we're close, reduce throttle
    IF error < approach_margin {
        LOCAL throttle_val IS error / approach_margin.
        RETURN MAX(0.0, MIN(1.0, throttle_val)).
    }

    RETURN 1.0.  // Full throttle when far from target
}

// Calculate throttle to maintain target time-to-apoapsis.
// Prevents apoapsis from "running away" too far ahead of the vessel.
FUNCTION get_eta_throttle {
    PARAMETER target_eta, margin IS 10.

    // No meaningful ETA while below the turn start altitude
    IF SHIP:ALTITUDE < TURN_START_ALTITUDE { RETURN 1.0. }

    LOCAL current_eta IS ETA:APOAPSIS.

    // If ETA is too high, reduce throttle.
    IF current_eta > (target_eta + margin) {
        // Linear reduction: starts at target+margin, reaches 0.5 at target+2*margin
        LOCAL reduction IS 1.0 - (current_eta - (target_eta + margin)) / margin.
        RETURN MAX(0.5, reduction).
    }

    RETURN 1.0.
}

// Combined throttle control (takes minimum of all limits)
FUNCTION get_ascent_throttle {
    PARAMETER target_ap, max_q.

    LOCAL q_throttle IS get_q_limited_throttle(max_q).
    LOCAL ap_throttle IS get_apoapsis_throttle(target_ap, SHIP:APOAPSIS).
    LOCAL eta_throttle IS get_eta_throttle(ASCENT_ETA_APOAPSIS_TARGET, 15).

    RETURN MIN(q_throttle, MIN(ap_throttle, eta_throttle)).
}

// =========================================================================
// STAGING MANAGEMENT
// =========================================================================

// Get total liquid fuel in parts with a specific DECOUPLEDIN value
FUNCTION get_stage_fuel {
    PARAMETER stg.
    LOCAL fuel IS 0.
    FOR part IN SHIP:PARTS {
        IF part:DECOUPLEDIN = stg {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" {
                    SET fuel TO fuel + res:AMOUNT.
                }
            }
        }
    }
    RETURN fuel.
}

// Get liquid fuel capacity in parts with a specific DECOUPLEDIN value
FUNCTION get_stage_fuel_capacity {
    PARAMETER stg.
    LOCAL fuel_max IS 0.
    FOR part IN SHIP:PARTS {
        IF part:DECOUPLEDIN = stg {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" {
                    SET fuel_max TO fuel_max + res:CAPACITY.
                }
            }
        }
    }
    RETURN fuel_max.
}

// Get fuel percentage for a specific DECOUPLEDIN stage group
FUNCTION get_stage_fuel_percent {
    PARAMETER stg.
    LOCAL fuel_max IS get_stage_fuel_capacity(stg).
    IF fuel_max > 0 {
        RETURN (get_stage_fuel(stg) / fuel_max) * 100.
    }
    RETURN 0.
}

// Get the highest DECOUPLEDIN value among all booster-tagged kOS processors.
// The kOS processor often sits on a structural adapter one stage above the fuel tanks,
// so this gives the upper bound when scanning the full booster assembly for fuel.
FUNCTION get_max_booster_decoupledin {
    LOCAL max_dcpl IS 0.
    FOR part IN SHIP:PARTS {
        IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
            IF part:DECOUPLEDIN > max_dcpl { SET max_dcpl TO part:DECOUPLEDIN. }
        }
    }
    RETURN max_dcpl.
}

// Get the DECOUPLEDIN value of the next staging group that will remove liquid fuel.
// Filters out stages that have already been fired (activation stages).
FUNCTION get_next_fuel_stage {
    LOCAL max_dcpl IS -1.
    LOCAL current_stg IS STAGE:NUMBER.
    FOR part IN SHIP:PARTS {
        LOCAL d IS part:DECOUPLEDIN.
        // Only consider stages that haven't been fired yet (d <= current_stg)
        IF d >= 0 AND d <= current_stg {
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" AND res:AMOUNT > 0.1 {
                    IF d > max_dcpl { SET max_dcpl TO d. }
                }
            }
        }
    }
    RETURN max_dcpl.
}

// Get the DECOUPLEDIN values of ALL staging groups that contain parts
// belonging to a booster (tagged "booster_*").
FUNCTION get_booster_decoupledin_values {
    LOCAL result IS LIST().
    FOR part IN SHIP:PARTS {
        IF part:TAG:STARTSWITH("booster") {
            IF part:DECOUPLEDIN >= 0 AND NOT result:CONTAINS(part:DECOUPLEDIN) {
                result:ADD(part:DECOUPLEDIN).
            }
        }
    }
    RETURN result.
}

// Check if a specific staging group contains booster parts.
FUNCTION is_booster_stage {
    PARAMETER stg.
    LOCAL booster_stages IS get_booster_decoupledin_values().
    RETURN booster_stages:CONTAINS(stg).
}

// Alias for telemetry compatibility in launch.ks and test.ks
FUNCTION get_next_booster_stage {
    RETURN get_next_fuel_stage().
}

// Return current LF% for a booster assembly by iterating pre-cached part refs.
// No SHIP:PARTS scan — just reads live resources from the stored part objects.
FUNCTION get_booster_fuel_pct {
    PARAMETER d_proc.
    IF NOT BOOSTER_ASSEMBLIES:HASKEY(d_proc) { RETURN -1. }
    LOCAL fuel IS 0.  LOCAL cap IS 0.
    FOR part IN BOOSTER_ASSEMBLIES[d_proc]["fuel_parts"] {
        FOR res IN part:RESOURCES {
            IF res:NAME = "LiquidFuel" {
                SET fuel TO fuel + res:AMOUNT.
                SET cap  TO cap  + res:CAPACITY.
            }
        }
    }
    IF cap > 0 { RETURN fuel / cap * 100. }
    RETURN 100.
}

// Get the fuel percentage of the booster assembly that is about to decouple.
// Delegates to get_booster_fuel_pct() using the highest active booster stage.
FUNCTION get_booster_assembly_fuel {
    LOCAL d IS get_max_booster_decoupledin().
    IF d <= 0 { RETURN -1. }
    RETURN get_booster_fuel_pct(d).
}

// Log the fuel levels and booster status of all upcoming stages.
FUNCTION log_staging_status {
    tdebug("--- Staging Stack Diagnostic ---").
    LOCAL stg_map IS LEXICON().
    FOR part IN SHIP:PARTS {
        LOCAL d IS part:DECOUPLEDIN.
        IF d >= 0 {
            LOCAL key IS d:TOSTRING.
            IF NOT stg_map:HASKEY(key) {
                stg_map:ADD(key, LIST(0, 0, FALSE)).
            }
            FOR res IN part:RESOURCES {
                IF res:NAME = "LiquidFuel" {
                    SET stg_map[key][0] TO stg_map[key][0] + res:AMOUNT.
                    SET stg_map[key][1] TO stg_map[key][1] + res:CAPACITY.
                }
            }
            IF part:TAG:STARTSWITH("booster") {
                SET stg_map[key][2] TO TRUE.
            }
        }
    }
    
    FOR k IN stg_map:KEYS {
        LOCAL d IS k:TONUMBER().
        IF d <= STAGE:NUMBER {
            LOCAL f IS stg_map[k][0].
            LOCAL c IS stg_map[k][1].
            LOCAL b IS stg_map[k][2].
            IF c > 0 {
                tdebug(" STG " + d + ": " + ROUND(f/c*100,1) + "% fuel, BoosterTag=" + b).
            }
        }
    }
    
    LOCAL b_fuel IS get_booster_assembly_fuel().
    tdebug(" Target Booster Tank Fuel (Decoupler Stage): " + ROUND(b_fuel, 1) + "%").
    tdebug("--------------------------------").
}

// Build BOOSTER_ASSEMBLIES: for each booster group, cache live fuel-part refs,
// dry mass, LF capacity, and engine Isp. Call once from setup_booster_processors()
// before launch.
//
// Engine detection searches DECOUPLEDIN in {d, d-1, d+1}, processing booster
// groups from highest DECOUPLEDIN (earliest-separating) to lowest so that
// earlier-separating groups claim their engine stage before later ones try d+1.
FUNCTION build_booster_assemblies {
    SET BOOSTER_ASSEMBLIES TO LEXICON().

    LOCAL proc_dcpls IS LIST().
    FOR part IN SHIP:PARTS {
        IF part:HASMODULE("kOSProcessor") AND part:TAG:STARTSWITH("booster") {
            IF NOT proc_dcpls:CONTAINS(part:DECOUPLEDIN) {
                proc_dcpls:ADD(part:DECOUPLEDIN).
            }
        }
    }

    LOCAL remaining IS proc_dcpls:COPY.
    LOCAL claimed_eng_dcpls IS LIST().

    UNTIL remaining:EMPTY {
        LOCAL max_d IS remaining[0].  LOCAL max_i IS 0.
        LOCAL i IS 1.
        UNTIL i >= remaining:LENGTH {
            IF remaining[i] > max_d { SET max_d TO remaining[i].  SET max_i TO i. }
            SET i TO i + 1.
        }
        remaining:REMOVE(max_i).
        LOCAL d IS max_d.

        // Find engine DECOUPLEDIN: prefer d, then d-1, then d+1; skip claimed stages.
        LOCAL eng_dcpl IS -1.
        LOCAL cand_list IS LIST(d, d - 1, d + 1).
        FOR cand IN cand_list {
            IF eng_dcpl = -1 AND NOT claimed_eng_dcpls:CONTAINS(cand) AND cand >= 0 {
                FOR eng IN SHIP:ENGINES {
                    IF eng:DECOUPLEDIN = cand { SET eng_dcpl TO cand.  BREAK. }
                }
            }
        }
        IF eng_dcpl >= 0 { claimed_eng_dcpls:ADD(eng_dcpl). }

        // fuel_low / fuel_high define the DECOUPLEDIN range for fuel monitoring.
        // When eng_dcpl < d (kOS adapter is one stage above the tanks/engines):
        //   - fuel_low = fuel_high = eng_dcpl  →  only parts at the engine stage count
        //     toward lf_cap / fuel_parts (those are the tanks the engines actually drain).
        //     Adapter parts at d carry physical mass but their fuel doesn't drain, so
        //     including them would dilute the fuel% and delay staging.
        //   - dry_kg still scans [eng_dcpl, d] to include the adapter's structural mass.
        // When eng_dcpl = d (co-located) or no engines found: scan [d, d].
        LOCAL fuel_low IS d.
        LOCAL fuel_high IS d.
        IF eng_dcpl >= 0 AND eng_dcpl < d {
            SET fuel_low  TO eng_dcpl.
            SET fuel_high TO eng_dcpl.
        }

        LOCAL fuel_parts IS LIST().
        LOCAL lf_cap IS 0.
        LOCAL dry_kg IS 0.
        FOR part IN SHIP:PARTS {
            IF part:DECOUPLEDIN >= fuel_low AND part:DECOUPLEDIN <= d {
                SET dry_kg TO dry_kg + part:DRYMASS * 1000.
            }
            IF part:DECOUPLEDIN >= fuel_low AND part:DECOUPLEDIN <= fuel_high {
                LOCAL has_lf IS FALSE.
                FOR res IN part:RESOURCES {
                    IF res:NAME = "LiquidFuel" {
                        SET lf_cap TO lf_cap + res:CAPACITY.
                        SET has_lf TO TRUE.
                    }
                }
                IF has_lf { fuel_parts:ADD(part). }
            }
        }
        // If engines are above the processor stage (eng_dcpl > d, unusual staging quirk),
        // include their dry mass so the rocket equation sees the full booster mass.
        IF eng_dcpl > d {
            FOR part IN SHIP:PARTS {
                IF part:DECOUPLEDIN = eng_dcpl {
                    SET dry_kg TO dry_kg + part:DRYMASS * 1000.
                }
            }
        }

        // Apply per-stage dry-mass override from config if set.
        IF BOOSTER_DRY_MASS_OVERRIDES:HASKEY(d) AND BOOSTER_DRY_MASS_OVERRIDES[d] > 0 {
            SET dry_kg TO BOOSTER_DRY_MASS_OVERRIDES[d].
        }

        // ISP from engines at eng_dcpl — use ISPAT(0) for vacuum ISP (works when engines are off).
        LOCAL eng_count IS 0.  LOCAL isp_sum IS 0.
        IF eng_dcpl >= 0 {
            FOR eng IN SHIP:ENGINES {
                IF eng:DECOUPLEDIN = eng_dcpl {
                    LOCAL part_isp IS eng:ISPAT(0).
                    IF part_isp <= 0 { SET part_isp TO BOOSTER_VACUUM_ISP. }
                    SET eng_count TO eng_count + 1.
                    SET isp_sum   TO isp_sum + part_isp.
                }
            }
        }
        LOCAL isp IS BOOSTER_VACUUM_ISP.
        IF eng_count > 0 { SET isp TO isp_sum / eng_count. }

        BOOSTER_ASSEMBLIES:ADD(d, LEXICON(
            "fuel_parts", fuel_parts,
            "dry_kg",     dry_kg,
            "lf_cap",     lf_cap,
            "isp",        isp
        )).
        tlog("  Assembly stg " + d + " (eng_dcpl=" + eng_dcpl + "): " +
             "dry=" + ROUND(dry_kg/1000, 2) + "t  " +
             "Isp=" + ROUND(isp, 0) + "s  " +
             "LF_cap=" + ROUND(lf_cap, 0) + "  " +
             "fuel_parts=" + fuel_parts:LENGTH).
    }
}

// Compute the minimum LF% to retain in a booster stage so it has enough delta-v
// for landing. Uses the rocket equation with cached dry mass and engine Isp.
// dv_needed = SHIP:VELOCITY:SURFACE:MAG * BOOSTBACK_DV_FRACTION + LANDING_DV_FIXED
FUNCTION get_booster_dv_threshold_pct {
    PARAMETER booster_dcpl.
    IF NOT BOOSTER_ASSEMBLIES:HASKEY(booster_dcpl) { RETURN 20. }
    LOCAL c IS BOOSTER_ASSEMBLIES[booster_dcpl].
    LOCAL dry_kg IS c["dry_kg"].
    LOCAL isp    IS c["isp"].
    LOCAL lf_cap IS c["lf_cap"].
    IF dry_kg = 0 OR isp = 0 OR lf_cap = 0 { RETURN 20. }
    LOCAL alt_frac IS MIN(1.0, SHIP:ALTITUDE / BODY:ATM:HEIGHT).
    LOCAL bb_frac IS BOOSTBACK_DV_FRACTION + BOOSTBACK_DV_ALT_FACTOR * alt_frac.
    LOCAL dv_needed IS SHIP:VELOCITY:SURFACE:MAG * bb_frac + LANDING_DV_FIXED.
    RETURN calc_dv_threshold_pct(dry_kg, isp, lf_cap, dv_needed).
}

// Same calculation but accepts explicit dv and altitude values.
// Used by test.ks to print thresholds at reference conditions without live data.
FUNCTION get_booster_dv_threshold_pct_at {
    PARAMETER booster_dcpl, vel_ref, alt_ref.
    IF NOT BOOSTER_ASSEMBLIES:HASKEY(booster_dcpl) { RETURN 20. }
    LOCAL c IS BOOSTER_ASSEMBLIES[booster_dcpl].
    LOCAL dry_kg IS c["dry_kg"].
    LOCAL isp    IS c["isp"].
    LOCAL lf_cap IS c["lf_cap"].
    IF dry_kg = 0 OR isp = 0 OR lf_cap = 0 { RETURN 20. }
    LOCAL alt_frac IS MIN(1.0, alt_ref / BODY:ATM:HEIGHT).
    LOCAL bb_frac IS BOOSTBACK_DV_FRACTION + BOOSTBACK_DV_ALT_FACTOR * alt_frac.
    LOCAL dv_needed IS vel_ref * bb_frac + LANDING_DV_FIXED.
    RETURN calc_dv_threshold_pct(dry_kg, isp, lf_cap, dv_needed).
}

// Rocket equation core: given cached booster params and a delta-v budget,
// returns the minimum LF percentage that covers that budget.
// LF+OX mix 0.9:1.1 by volume, equal density (5 kg/unit) -> LF is 45% of prop mass.
FUNCTION calc_dv_threshold_pct {
    PARAMETER dry_kg, isp, lf_cap, dv_needed.
    LOCAL ve IS isp * 9.80665.
    LOCAL m_prop_kg IS dry_kg * (CONSTANT:E ^ (dv_needed / ve) - 1).
    LOCAL lf_units_needed IS m_prop_kg * 0.45 / 5.
    LOCAL pct IS (lf_units_needed / lf_cap) * 100.
    RETURN MIN(90, MAX(5, pct)).
}

// Check if staging is needed.
FUNCTION check_staging_needed {

    LOCAL now IS TIME:SECONDS.
    LOCAL time_since_stg IS now - LAST_STAGE_TIME.

    // 1. Enforce minimum staging interval
    IF time_since_stg < STAGING_MIN_INTERVAL {
        RETURN FALSE.
    }

    // 2. Periodic Diagnostic Logging (every 5s)
    IF MOD(ROUND(now), 5) = 0 {
        log_staging_status().
    }

    // 3. Flameout detection (Primary trigger for all core/upper stages)
    FOR eng IN SHIP:ENGINES {
        IF eng:IGNITION AND eng:FLAMEOUT {
            tlog("Staging: Flameout detected").
            SET LAST_STAGE_TIME TO now.
            RETURN TRUE.
        }
    }

    // 4. Booster Assembly Threshold — dynamic threshold from rocket equation.
    // Threshold = fuel% needed to cover (velocity * BOOSTBACK_DV_FRACTION + LANDING_DV_FIXED).
    // Uses cached dry mass and Isp, so the only live cost is one velocity read + arithmetic.
    LOCAL b_fuel IS get_booster_assembly_fuel().
    IF b_fuel >= 0 {
        LOCAL b_dcpl IS get_max_booster_decoupledin().
        LOCAL dv_threshold IS get_booster_dv_threshold_pct(b_dcpl).
        IF b_fuel < dv_threshold {
            tlog("Staging: Booster assembly at " + ROUND(b_fuel, 1) +
                 "% (threshold " + ROUND(dv_threshold, 1) + "%)").
            SET LAST_STAGE_TIME TO now.
            RETURN TRUE.
        }
    }

    // 5. Dead-Engine Recovery (e.g. activation stage with no engines)
    IF SHIP:MAXTHRUST = 0 AND STAGE:NUMBER > 0 AND time_since_stg > 2.0 {
        tlog("Staging: No thrust detected").
        SET LAST_STAGE_TIME TO now.
        RETURN TRUE.
    }

    RETURN FALSE.
}

// =========================================================================
// VESSEL CHECKS
// =========================================================================

// Check if vessel has probe core
FUNCTION has_probe_core {
    PARAMETER vessel_obj IS SHIP.

    FOR part IN vessel_obj:PARTS {
        IF part:HASMODULE("ModuleCommand") {
            LOCAL cmd_module IS part:GETMODULE("ModuleCommand").
            IF cmd_module:HASEVENT("Control From Here") {
                RETURN TRUE.
            }
        }
    }

    RETURN FALSE.
}

// Check if vessel has kOS processor
FUNCTION has_kos_processor {
    PARAMETER vessel_obj IS SHIP.

    FOR part IN vessel_obj:PARTS {
        IF part:HASMODULE("kOSProcessor") {
            RETURN TRUE.
        }
    }

    RETURN FALSE.
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL ascent_loaded IS TRUE.
