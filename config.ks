// =========================================================================
// MISSION CONFIGURATION (config.ks)
// =========================================================================
// Edit this file to configure the launch and landing system.
// All user-tunable values live here — do not edit the library files.
// =========================================================================

@LAZYGLOBAL OFF.

// Load the utility foundation (math, physics, ship utilities)
RUNONCEPATH("0:/lib/util.ks").
// Load the telemetry interface (tlog, tdebug, plog, HUD functions)
RUNONCEPATH("0:/lib/telemetry.ks").

// =========================================================================
// DEBUG / LOGGING
// =========================================================================

SET DEBUG_MODE TO TRUE.               // TRUE for verbose output to log file
SET LOG_FILE TO "0:/flight.log".      // Log destination for launch and landing

// =========================================================================
// ORBITAL TARGET
// =========================================================================

GLOBAL TARGET_APOAPSIS IS 100000.     // Target apoapsis (m) — must be above atmosphere
GLOBAL TARGET_PERIAPSIS IS 100000.    // Target periapsis for circularization (m)
GLOBAL TARGET_INCLINATION IS 0.       // Orbital inclination (degrees, 0 = equatorial)

// =========================================================================
// ASCENT PROFILE
// =========================================================================
// pitch = 90 * (1 - t^TURN_SHAPE)  where t = fraction through altitude range
// TURN_SHAPE < 1 : turns fast early (aggressive, risky in thick atmosphere)
// TURN_SHAPE = 1 : linear
// TURN_SHAPE > 1 : stays near-vertical through thick air, turns later (correct for Kerbin)

GLOBAL TURN_START_ALTITUDE IS 1500.   // Begin gravity turn (m)
GLOBAL TURN_END_ALTITUDE IS 65000.    // Complete turn (m)
GLOBAL TURN_SHAPE IS 2.5.             // Turn profile shape (Kerbin: 1.5–2.5)
                                      // 2.5 is steeper, better for Ike I high-TWR core.
GLOBAL MAX_Q IS 25000.                // Max dynamic pressure (Pa) — throttle back if exceeded

GLOBAL ASCENT_ETA_APOAPSIS_TARGET IS 50. // Target time-to-apoapsis during ascent (s)

// =========================================================================
// STAGING
// =========================================================================

GLOBAL STAGE_FUEL_THRESHOLD IS 20.   // Stage when booster liquid fuel drops below this % —
                                      // must be high enough to leave fuel for landing burns
GLOBAL STAGING_MIN_INTERVAL IS 1.5.  // Minimum time between stage activations (s)
                                      // Prevents runaway staging chain reactions.

GLOBAL ENABLE_BOOSTER_RECOVERY IS TRUE.

// =========================================================================
// LANDING ZONE
// =========================================================================

GLOBAL KSC_LAT IS -0.0972.           // Target landing latitude  (KSC launchpad)
GLOBAL KSC_LON IS -74.5577.          // Target landing longitude (KSC launchpad)
GLOBAL LANDING_OFFSET_SPACING IS 10. // East-west spacing between booster landing zones (m)

// =========================================================================
// BOOSTER LANDING — FLIGHT PARAMETERS
// =========================================================================

GLOBAL SUICIDE_MARGIN IS 1.25.        // Safety factor on suicide burn altitude (1.0 = no margin)
GLOBAL SUICIDE_ALT_TARGET IS 12.      // Target altitude to reach zero velocity (m)
                                      // Higher = safer soft-touchdown phase.
GLOBAL LANDING_HEIGHT_OFFSET IS 15.   // Distance from root part to bottom of landing legs (m)
                                      // Crucial: Set this if the booster is tall!
                                      // If root is at top, use ~20-30m.
GLOBAL GEAR_DEPLOY_ALT IS 100.        // Deploy landing gear below this altitude (m)
GLOBAL FINAL_APPROACH_ALT IS 50.      // Switch to vertical attitude below this altitude (m)
GLOBAL FINAL_CORRECTION_CUTOFF_ALT IS 120. // Stop target-chasing below this altitude (m)
GLOBAL HORIZONTAL_KILL_ALT IS 35.     // Below this altitude, stop moving toward target and only kill lateral speed (m)
GLOBAL LANDING_TARGET_TOLERANCE IS 10. // Desired landing error at touchdown (m)
GLOBAL TERMINAL_RCS_POSITION_GAIN IS 0.08. // Increased for more aggressive target chasing
GLOBAL TERMINAL_RCS_VELOCITY_GAIN IS 5.0. // Increased from 3.5 to combat engine gimbal drift
GLOBAL TOUCHDOWN_SPEED IS 1.5.        // Target touchdown vertical speed (m/s)
GLOBAL AIRBRAKE_DEPLOY_ALT IS 70000.  // Deploy airbrakes below this altitude (m)
GLOBAL DECOUPLE_PUSH_DURATION IS 0.6. // Reduced from 1.2s
GLOBAL DECOUPLE_PUSH_STRENGTH IS 0.45. // Reduced from 0.85

// =========================================================================
// BOOSTER LANDING — ENTRY BURN
// =========================================================================

GLOBAL ENTRY_BURN_SPEED IS 800.       // Trigger entry burn if speed exceeds this at entry alt (m/s)
GLOBAL ENTRY_BURN_ALTITUDE IS 15000.  // Altitude at which to check for entry burn (m)

// =========================================================================
// BOOSTER LANDING — BOOSTBACK GUIDANCE
// =========================================================================

GLOBAL BOOSTBACK_MAX_BURN_TIME IS 60. // Max boostback burn duration (s)
GLOBAL BOOSTBACK_TARGET_ERROR IS 250. // Stop boostback when predicted impact within this range (m)
GLOBAL BOOSTBACK_KP IS 0.5.           // Proportional gain for boostback throttle PI controller
GLOBAL BOOSTBACK_KI IS 0.1.           // Integral gain for boostback throttle PI controller

// =========================================================================
// FLIP MANEUVER
// =========================================================================

GLOBAL MAX_FLIP_TIME IS 60.           // Max time allowed to flip to retrograde (s)

// =========================================================================

GLOBAL config_loaded IS TRUE.
