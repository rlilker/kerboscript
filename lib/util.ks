// =========================================================================
// UTILITY LIBRARY (util.ks)
// =========================================================================
// Shared utility functions for launch and landing scripts
// Provides: math utilities, LATLNG operations, telemetry, logging
// =========================================================================

@LAZYGLOBAL OFF.

// =========================================================================
// DEBUG / LOGGING GLOBALS
// =========================================================================

// Set DEBUG_MODE to TRUE for verbose console output during development
GLOBAL DEBUG_MODE IS FALSE.

// All log_message / plog / debug output goes to this file
GLOBAL LOG_FILE IS "0:/flight.log".

// =========================================================================
// LATLNG MANIPULATION
// =========================================================================

// Offset a LATLNG position by meters (east/north)
FUNCTION offset_latlng {
    PARAMETER base_latlng, offset_east, offset_north.

    // Convert meters to degrees
    // Meters per degree = (2*pi*R)/360 = (pi*R)/180
    LOCAL meters_per_degree IS (CONSTANT:PI * BODY:RADIUS) / 180.

    LOCAL lat_offset IS offset_north / meters_per_degree.

    // Longitude: meters per degree varies by latitude (narrower near poles)
    LOCAL lat_rad IS base_latlng:LAT * CONSTANT:DEGTORAD.
    LOCAL cos_lat IS COS(lat_rad).

    // Avoid division by zero at poles
    IF ABS(cos_lat) < 0.0001 {
        SET cos_lat TO 0.0001.
    }

    LOCAL lon_offset IS offset_east / (meters_per_degree * cos_lat).

    RETURN LATLNG(base_latlng:LAT + lat_offset, base_latlng:LNG + lon_offset).
}

// Calculate great circle distance between two LATLNG points (meters)
FUNCTION great_circle_distance {
    PARAMETER latlng1, latlng2.

    LOCAL lat1 IS latlng1:LAT * CONSTANT:DEGTORAD.
    LOCAL lat2 IS latlng2:LAT * CONSTANT:DEGTORAD.
    LOCAL dLon IS (latlng2:LNG - latlng1:LNG) * CONSTANT:DEGTORAD.

    LOCAL a IS SIN(lat1) * SIN(lat2) + COS(lat1) * COS(lat2) * COS(dLon).
    // Clamp to [-1, 1] to avoid numerical errors
    SET a TO MAX(-1, MIN(1, a)).

    // In kOS, ARCCOS returns radians (unlike most trig functions)
    // Arc length = radius * angle_in_radians
    RETURN BODY:RADIUS * ARCCOS(a).
}

// Calculate compass bearing from one LATLNG to another (0-360 degrees)
// Note: kOS SIN/COS take DEGREES. Do NOT convert to radians first.
// kOS ARCTAN2 returns DEGREES directly — no RADTODEG multiplication needed.
FUNCTION bearing_to_target {
    PARAMETER from_latlng, to_latlng.

    LOCAL lat1 IS from_latlng:LAT.
    LOCAL lat2 IS to_latlng:LAT.
    LOCAL dLon IS to_latlng:LNG - from_latlng:LNG.

    LOCAL y IS SIN(dLon) * COS(lat2).
    LOCAL x IS COS(lat1) * SIN(lat2) - SIN(lat1) * COS(lat2) * COS(dLon).
    LOCAL bearing IS ARCTAN2(y, x).

    RETURN MOD(bearing + 360, 360).
}

// =========================================================================
// VECTOR OPERATIONS
// =========================================================================

// Convert heading and pitch to direction vector
// kOS SIN/COS take DEGREES — use heading_deg/pitch_deg directly.
FUNCTION heading_vector {
    PARAMETER heading_deg, pitch_deg IS 0.

    LOCAL north_vec IS SHIP:NORTH:VECTOR.
    LOCAL east_vec IS VCRS(SHIP:UP:VECTOR, north_vec):NORMALIZED.
    LOCAL up_vec IS SHIP:UP:VECTOR.

    RETURN (COS(pitch_deg) * (SIN(heading_deg) * east_vec + COS(heading_deg) * north_vec) +
            SIN(pitch_deg) * up_vec):NORMALIZED.
}

// =========================================================================
// ATMOSPHERIC MODEL
// =========================================================================

// Get atmospheric density at altitude (kg/m^3)
FUNCTION get_atmospheric_density {
    PARAMETER altitude_m.

    IF altitude_m > BODY:ATM:HEIGHT {
        RETURN 0.
    }

    // Use actual atmospheric pressure if available
    IF SHIP:ALTITUDE < BODY:ATM:HEIGHT {
        RETURN SHIP:BODY:ATM:ALTITUDEPRESSURE(altitude_m) / (SHIP:BODY:ATM:ALTITUDETEMPERATURE(altitude_m) * 287).
    }

    // Fallback: exponential model for predictions
    LOCAL scale_height IS 5000.  // Approximate for Kerbin
    RETURN 1.2 * CONSTANT:E^(-altitude_m / scale_height).
}

// =========================================================================
// SHIP INFORMATION
// =========================================================================

// Get current thrust-to-weight ratio
FUNCTION get_twr {
    IF SHIP:MASS = 0 { RETURN 0. }
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
    RETURN SHIP:AVAILABLETHRUST / (SHIP:MASS * g).
}

// Get maximum deceleration (m/s^2) accounting for gravity
FUNCTION get_max_decel {
    IF SHIP:MASS = 0 { RETURN 0. }
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
    LOCAL max_accel IS SHIP:MAXTHRUST / SHIP:MASS.
    RETURN max_accel - g.
}

// Get current deceleration (m/s^2) accounting for gravity
FUNCTION get_current_decel {
    IF SHIP:MASS = 0 { RETURN 0. }
    LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
    LOCAL current_accel IS SHIP:AVAILABLETHRUST / SHIP:MASS.
    RETURN current_accel - g.
}

// Check if vessel has a specific part module
FUNCTION has_module {
    PARAMETER module_name.

    FOR part IN SHIP:PARTS {
        IF part:HASMODULE(module_name) {
            RETURN TRUE.
        }
    }
    RETURN FALSE.
}

// =========================================================================
// CONTROL UTILITIES
// =========================================================================

// Deploy airbrakes if available
FUNCTION deploy_airbrakes {
    IF has_module("ModuleAeroSurface") {
        BRAKES ON.
        RETURN TRUE.
    }
    RETURN FALSE.
}

// Retract airbrakes if available
FUNCTION retract_airbrakes {
    BRAKES OFF.
}

// Deploy landing gear
FUNCTION deploy_gear {
    GEAR ON.
}

// =========================================================================
// TELEMETRY DISPLAY
// =========================================================================

// Clear terminal
FUNCTION clear_screen {
    CLEARSCREEN.
}

// Print header with mission name
FUNCTION print_header {
    PARAMETER mission_name.

    PRINT "========================================".
    PRINT " " + mission_name.
    PRINT "========================================".
    PRINT " ".
}

// Print status line with label and value
FUNCTION print_status {
    PARAMETER label, value, decimals IS 1.

    LOCAL formatted_value IS "".

    IF value:ISTYPE("Scalar") {
        SET formatted_value TO ROUND(value, decimals):TOSTRING.
    }
    ELSE {
        SET formatted_value TO value:TOSTRING.
    }

    PRINT label + ": " + formatted_value.
}

// Format time as MM:SS
FUNCTION format_time {
    PARAMETER seconds.

    LOCAL mins IS FLOOR(seconds / 60).
    LOCAL secs IS FLOOR(MOD(seconds, 60)).

    RETURN mins:TOSTRING:PADLEFT(2):REPLACE(" ", "0") + ":" +
           secs:TOSTRING:PADLEFT(2):REPLACE(" ", "0").
}

// =========================================================================
// LOGGING
// =========================================================================

// Print to screen AND write to LOG_FILE — use in test scripts and status output
FUNCTION plog {
    PARAMETER message.
    PRINT message.
    LOG message TO LOG_FILE.
}

// Mission phase log: always prints to screen with timestamp, always writes to file
FUNCTION log_message {
    PARAMETER message.
    LOCAL log_entry IS "[" + format_time(MISSIONTIME) + "] " + message.
    PRINT log_entry.
    // Only write to archive if connected; local volume writes always attempted
    IF LOG_FILE:STARTSWITH("0:/") {
        IF HOMECONNECTION:ISCONNECTED {
            LOG log_entry TO LOG_FILE.
        }
    } ELSE {
        LOG log_entry TO LOG_FILE.
    }
}

// Debug log: only prints/logs when DEBUG_MODE is TRUE
FUNCTION debug {
    PARAMETER message.
    IF DEBUG_MODE {
        LOCAL entry IS "[DBG " + format_time(MISSIONTIME) + "] " + message.
        PRINT entry.
        LOG entry TO LOG_FILE.
    }
}

// Enable or disable debug mode at runtime
FUNCTION set_debug {
    PARAMETER enabled.
    SET DEBUG_MODE TO enabled.
    IF enabled { plog("[DEBUG MODE ON]"). }
    ELSE { plog("[DEBUG MODE OFF]"). }
}

// =========================================================================
// MATH UTILITIES
// =========================================================================

// Clamp value between min and max
FUNCTION clamp {
    PARAMETER value, min_val, max_val.
    RETURN MAX(min_val, MIN(max_val, value)).
}

// Linear interpolation
FUNCTION lerp {
    PARAMETER a, b, t.
    RETURN a + (b - a) * clamp(t, 0, 1).
}

// =========================================================================
// EXPORTS
// =========================================================================

GLOBAL util_loaded IS TRUE.
