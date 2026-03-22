# KerboScript Language Reference
## Complete specification for kOS programming in Kerbal Space Program

**Version:** kOS 1.4.0+
**Last Updated:** 2025-03-22

---

## Table of Contents
1. [Reserved Keywords](#reserved-keywords)
2. [Built-in Read-Only Variables](#built-in-read-only-variables)
3. [Data Types](#data-types)
4. [Syntax Rules](#syntax-rules)
5. [Functions](#functions)
6. [Control Structures](#control-structures)
7. [Operators](#operators)
8. [Common Suffixes](#common-suffixes)
9. [Common Pitfalls](#common-pitfalls)

---

## Reserved Keywords

**NEVER use these as variable, parameter, or function names:**

### Control Flow Keywords
```
IF, ELSE, UNTIL, FROM, TO, STEP, DO, WHILE, FOR, IN, BREAK, PRESERVE, RETURN, WAIT
```

### Declaration Keywords
```
SET, LOCK, UNLOCK, LOCAL, GLOBAL, PARAMETER, DECLARE, FUNCTION
```

### Boolean Keywords
```
TRUE, FALSE, AND, OR, NOT
```

### Action Keywords
```
ON, WHEN, THEN, TOGGLE, STAGE, PRINT, AT, CLEARSCREEN, LOG
RUN, RUNPATH, RUNONCEPATH, COMPILE, SWITCH, COPY, DELETE, RENAME, EXISTS
ADD, REMOVE, REVERT
```

### Special Keywords
```
OFF (used for locks like LOCK STEERING TO OFF)
CHOOSE (ternary operator: CHOOSE x IF condition ELSE y)
```

---

## Built-in Read-Only Variables

**NEVER use these as variable or parameter names - they will cause "clobber" errors:**

### Named Vessels and Bodies
```
SHIP, TARGET, HASTARGET, BODY, HOMECONNECTION, CONTROLCONNECTION
```

### Ship Field Aliases (Most Common)
```
HEADING, PROGRADE, RETROGRADE, FACING
MAXTHRUST, VELOCITY, GEOPOSITION
LATITUDE, LONGITUDE, UP, NORTH
ANGULARMOMENTUM, ANGULARVEL, ANGULARVELOCITY
MASS, VERTICALSPEED, GROUNDSPEED, AIRSPEED
ALTITUDE, APOAPSIS, PERIAPSIS
SENSORS, SRFPROGRADE, SRFRETROGRADE
OBT, STATUS, SHIPNAME
```

### Critical: ALT and ETA Structures
```
ALT (structure with :APOAPSIS, :PERIAPSIS, :RADAR suffixes)
ETA (structure with :APOAPSIS, :PERIAPSIS, :NEXTNODE, :TRANSITION suffixes)
```

### System Structures
```
CONSTANT, TERMINAL, CORE, ARCHIVE
STAGE, NEXTNODE, HASNODE, ALLNODES
ENCOUNTER, VERSION, KUNIVERSE, CONFIG
WARP, WARPMODE, MAPVIEW, LOADDISTANCE
SOLARPRIMEVECTOR, OPCODESLEFT
```

### Resources (Global Variables)
```
LIQUIDFUEL, OXIDIZER, ELECTRICCHARGE
MONOPROPELLANT, INTAKEAIR, SOLIDFUEL
```

### Boolean Action Flags
```
SAS, RCS, GEAR, LIGHTS, BRAKES, ABORT
LEGS, CHUTES, CHUTESSAFE, PANELS
RADIATORS, LADDERS, BAYS, INTAKES
DEPLOYDRILLS, DRILLS, FUELCELLS, ISRU
AG1, AG2, AG3, AG4, AG5, AG6, AG7, AG8, AG9, AG10
```

### Flight Control (Can be SET or LOCKed)
```
THROTTLE, STEERING, WHEELTHROTTLE, WHEELSTEERING
```

### Raw Control Suffixes (SHIP:CONTROL:*)
```
MAINTHROTTLE, YAW, PITCH, ROLL, ROTATION
YAWTRIM, PITCHTRIM, ROLLTRIM
FORE, STARBOARD, TOP, TRANSLATION
WHEELSTEER, WHEELTHROTTLE, WHEELSTEERTRIM, WHEELTHROTTLETRIM
NEUTRAL, NEUTRALIZE
```

### Time Variables
```
MISSIONTIME, TIME, SESSIONTIME, TIMESTAMP, TIMESPAN
```

### Celestial Bodies
```
KERBIN, MUN, MINMUS
DUNA, IKE
EVE, GILLY
JOOL, LAYTHE, VALL, TYLO, BOP, POL
MOHO, DRES, EELOO
SUN (Kerbol)
```

### Color Constants
```
WHITE, BLACK, RED, GREEN, BLUE, YELLOW, CYAN, MAGENTA
```

---

## Safe Naming Conventions

To avoid conflicts, use these suffixes for variables:

```kerboscript
// WRONG - These are ALL reserved!
LOCAL altitude IS SHIP:ALTITUDE.    // ✗ "altitude" is reserved
LOCAL velocity IS SHIP:VELOCITY.    // ✗ "velocity" is reserved
LOCAL position IS SHIP:POSITION.    // ✗ "position" is reserved
LOCAL north IS SHIP:NORTH:VECTOR.   // ✗ "north" is reserved
LOCAL up IS SHIP:UP:VECTOR.         // ✗ "up" is reserved
LOCAL target IS TARGET.             // ✗ "target" is reserved
LOCAL body IS SHIP:BODY.            // ✗ "body" is reserved
LOCAL alt IS SHIP:ALTITUDE.         // ✗ "alt" is reserved (it's a structure!)

// CORRECT - Add suffixes or use different names
LOCAL altitude_m IS SHIP:ALTITUDE.       // ✓ Added suffix
LOCAL vel IS SHIP:VELOCITY.              // ✓ Shortened form
LOCAL pos IS SHIP:POSITION.              // ✓ Shortened form
LOCAL north_vec IS SHIP:NORTH:VECTOR.    // ✓ Added suffix
LOCAL up_vec IS SHIP:UP:VECTOR.          // ✓ Added suffix
LOCAL tgt IS TARGET.                     // ✓ Abbreviated
LOCAL my_body IS SHIP:BODY.              // ✓ Added prefix
LOCAL h IS SHIP:ALTITUDE.                // ✓ Physics notation (height)

// BEST - Use fully descriptive names
LOCAL current_altitude_m IS SHIP:ALTITUDE.
LOCAL surface_velocity_vec IS SHIP:VELOCITY:SURFACE.
LOCAL target_apoapsis_m IS 100000.
LOCAL burn_duration_s IS 30.
```

---

## Data Types

### Scalars (Numbers)
```kerboscript
LOCAL x IS 42.
LOCAL pi IS 3.14159.
LOCAL big_number IS 1.5e6.  // Scientific notation: 1,500,000
```

### Booleans
```kerboscript
LOCAL flag IS TRUE.
LOCAL done IS FALSE.
LOCAL result IS (x > 5).  // Boolean expression
```

### Strings
```kerboscript
LOCAL name IS "Jeb".
LOCAL message IS "Hello " + name.  // Concatenation
```

### Vectors
```kerboscript
LOCAL v IS V(1, 2, 3).              // 3D vector
LOCAL direction IS SHIP:FACING:VECTOR.
LOCAL magnitude IS v:MAG.
LOCAL normalized IS v:NORMALIZED.
```

### Lists
```kerboscript
LOCAL my_list IS LIST().
my_list:ADD(10).
my_list:ADD(20).
LOCAL first IS my_list[0].          // Zero-indexed
LOCAL count IS my_list:LENGTH.
```

### Lexicons (Dictionaries)
```kerboscript
LOCAL my_lex IS LEXICON().
SET my_lex["key1"] TO "value1".
SET my_lex["count"] TO 42.
LOCAL val IS my_lex["key1"].
```

### Structures (Complex Types)
```kerboscript
// Many built-in types: Vessel, Body, Orbit, Part, Engine, etc.
LOCAL current_orbit IS SHIP:ORBIT.
LOCAL home_planet IS SHIP:BODY.
LOCAL first_engine IS SHIP:PARTS[0].
```

---

## Syntax Rules

### Case Insensitivity
```kerboscript
// These are all equivalent:
SET x TO 10.
set x to 10.
Set X To 10.
```

### Statement Terminators
```kerboscript
// Statements end with a period (.)
SET x TO 5.
PRINT "Hello".

// Exception: Blocks don't need periods after braces
IF x > 0 {
    PRINT "Positive".
}  // No period here

// But you CAN add them:
IF x > 0 {
    PRINT "Positive".
}.  // This is also valid
```

### Comments
```kerboscript
// Single-line comment

/* Multi-line
   comment */
```

### Variable Declaration
```kerboscript
// Implicit global (avoid in modern code):
SET x TO 10.

// Explicit local (preferred):
LOCAL x IS 10.
LOCAL y IS 20.
SET x TO 15.  // Modify existing variable

// Global declaration:
GLOBAL my_global IS 100.

// Parameter declaration (in functions):
FUNCTION my_func {
    PARAMETER x, y IS 0.  // y has default value
    RETURN x + y.
}
```

### SET vs IS
```kerboscript
// First assignment - use IS:
LOCAL x IS 10.

// Reassignment - use SET TO:
SET x TO 20.

// IS can also be used for SET in first assignment:
LOCAL y IS 5.        // Preferred for locals
SET z TO 5.          // Creates global if doesn't exist (avoid)
```

---

## Functions

### Function Declaration
```kerboscript
// Basic function
FUNCTION my_function {
    PRINT "Hello".
}

// Function with parameters
FUNCTION add {
    PARAMETER x, y.
    RETURN x + y.
}

// Function with default parameters
FUNCTION greet {
    PARAMETER name IS "World".
    RETURN "Hello " + name.
}

// Function with multiple statements
FUNCTION calculate_orbit {
    PARAMETER target_alt.

    LOCAL r IS BODY:RADIUS + target_alt.
    LOCAL v IS SQRT(BODY:MU / r).

    RETURN v.
}
```

### Function Calls
```kerboscript
my_function().           // No parameters
LOCAL result IS add(5, 3).
LOCAL msg IS greet().         // Uses default
LOCAL msg2 IS greet("Jeb").   // Override default
```

### Anonymous Functions (Delegates)
```kerboscript
LOCAL my_func IS { PARAMETER x. RETURN x * 2. }.
PRINT my_func(5).  // Prints 10
```

---

## Control Structures

### IF / ELSE
```kerboscript
IF condition {
    // Code
}

IF condition {
    // Code
} ELSE {
    // Code
}

IF condition1 {
    // Code
} ELSE IF condition2 {
    // Code
} ELSE {
    // Code
}
```

### UNTIL Loop
```kerboscript
UNTIL condition {
    // Code
    // Repeats while condition is FALSE
}
```

### FROM Loop
```kerboscript
FROM {LOCAL x IS 0.} UNTIL x >= 10 STEP {SET x TO x + 1.} DO {
    PRINT x.
}
```

### FOR Loop
```kerboscript
FOR item IN my_list {
    PRINT item.
}
```

### WHEN / THEN (Triggers)
```kerboscript
WHEN condition THEN {
    // Executes once when condition becomes true
}

WHEN condition THEN {
    // Code
    PRESERVE.  // Re-arm the trigger
}
```

### ON (Event Handlers)
```kerboscript
ON STAGE {
    PRINT "Staged!".
    PRESERVE.  // Keep handler active
}

ON ABORT {
    PRINT "Abort!".
    // No PRESERVE - one-time handler
}
```

---

## Operators

### Arithmetic
```kerboscript
+   // Addition
-   // Subtraction
*   // Multiplication
/   // Division
^   // Exponentiation
```

### Comparison
```kerboscript
=   // Equal
<>  // Not equal
<   // Less than
>   // Greater than
<=  // Less than or equal
>=  // Greater than or equal
```

### Logical
```kerboscript
AND  // Logical AND
OR   // Logical OR
NOT  // Logical NOT
```

### Assignment
```kerboscript
IS       // Initial assignment (LOCAL x IS 5)
TO       // Reassignment (SET x TO 10)
```

### Ternary
```kerboscript
CHOOSE x IF condition ELSE y
// Example:
LOCAL result IS CHOOSE "High" IF altitude > 10000 ELSE "Low".
```

---

## Common Suffixes

### Vector Suffixes
```kerboscript
:MAG          // Magnitude
:NORMALIZED   // Unit vector
:SQRMAGNITUDE // Squared magnitude (faster)
:X, :Y, :Z    // Components
```

### Vessel Suffixes
```kerboscript
SHIP:ALTITUDE
SHIP:VELOCITY:SURFACE
SHIP:VELOCITY:ORBIT
SHIP:MASS
SHIP:MAXTHRUST
SHIP:AVAILABLETHRUST
SHIP:FACING:VECTOR
SHIP:UP:VECTOR
SHIP:NORTH:VECTOR
SHIP:PROGRADE
SHIP:RETROGRADE
SHIP:PARTS
SHIP:RESOURCES
SHIP:ENGINES
```

### Orbit Suffixes
```kerboscript
SHIP:ORBIT:APOAPSIS
SHIP:ORBIT:PERIAPSIS
SHIP:ORBIT:ECCENTRICITY
SHIP:ORBIT:INCLINATION
SHIP:ORBIT:PERIOD
SHIP:ORBIT:SEMIMAJORAXIS
```

### Body Suffixes
```kerboscript
BODY:RADIUS
BODY:MU            // Gravitational parameter
BODY:ATM:HEIGHT    // Atmosphere height
BODY:POSITION
```

### Time Suffixes
```kerboscript
TIME:SECONDS
TIME:YEAR
TIME:DAY
TIME:HOUR
TIME:MINUTE
```

### List Suffixes
```kerboscript
:LENGTH
:ADD(item)
:REMOVE(index)
:CLEAR
:CONTAINS(item)
```

---

## Common Pitfalls

### 1. Reserved Keyword as Variable
```kerboscript
// WRONG - "altitude" is reserved
PARAMETER altitude.

// CORRECT
PARAMETER alt.
```

### 2. RETURN Outside Function
```kerboscript
// WRONG - RETURN only works in functions
IF x > 10 {
    RETURN.  // ERROR!
}

// CORRECT - use control flow
IF x > 10 {
    SET should_continue TO FALSE.
}
```

### 3. Missing Period
```kerboscript
// WRONG
SET x TO 10
PRINT x

// CORRECT
SET x TO 10.
PRINT x.
```

### 4. Using SET for First Assignment
```kerboscript
// WRONG - Creates implicit global
SET my_var TO 10.

// CORRECT - Explicit local
LOCAL my_var IS 10.
```

### 5. Lock vs Set
```kerboscript
// LOCK creates a binding that updates automatically
LOCK STEERING TO PROGRADE.  // Always points prograde

// SET is one-time assignment
SET STEERING TO PROGRADE.   // Sets once, doesn't update

// To remove a LOCK:
UNLOCK STEERING.
```

### 6. Case Sensitivity for Strings
```kerboscript
// kOS keywords are case-insensitive
SET x TO 10.  // Same as: set x to 10.

// But strings ARE case-sensitive
LOCAL name IS "Jeb".
IF name = "jeb" {  // FALSE - case mismatch
    PRINT "Found".
}
```

### 7. Division by Zero
```kerboscript
// WRONG - Can crash
LOCAL result IS x / y.

// CORRECT - Check first
IF y <> 0 {
    LOCAL result IS x / y.
}
```

### 8. Accessing Non-Existent List Elements
```kerboscript
// WRONG - Index out of bounds
LOCAL item IS my_list[10].  // If list has <11 items

// CORRECT - Check length
IF my_list:LENGTH > 10 {
    LOCAL item IS my_list[10].
}
```

### 9. Modifying List During Iteration
```kerboscript
// WRONG - Can cause issues
FOR item IN my_list {
    my_list:REMOVE(0).  // Modifying during iteration
}

// CORRECT - Use index-based loop or copy
LOCAL i IS my_list:LENGTH - 1.
UNTIL i < 0 {
    my_list:REMOVE(i).
    SET i TO i - 1.
}
```

### 10. Floating Point Comparison
```kerboscript
// WRONG - Floating point precision issues
IF x = 0.1 + 0.2 {  // Might not be exactly 0.3
    PRINT "Equal".
}

// CORRECT - Use tolerance
LOCAL epsilon IS 0.001.
IF ABS(x - 0.3) < epsilon {
    PRINT "Equal".
}
```

---

## Best Practices

### 1. Always Use @LAZYGLOBAL OFF
```kerboscript
// Put this at the top of every script
@LAZYGLOBAL OFF.

// This forces you to declare variables explicitly
LOCAL x IS 10.  // Required
```

### 2. Use Descriptive Names
```kerboscript
// BAD
LOCAL x IS 100000.
LOCAL t IS 60.

// GOOD
LOCAL target_altitude IS 100000.
LOCAL burn_time IS 60.
```

### 3. Document Complex Functions
```kerboscript
// Calculate delta-V for circularization at apoapsis
// Parameters:
//   target_pe - desired periapsis altitude (meters)
// Returns: delta-V in m/s
FUNCTION calculate_circularization_dv {
    PARAMETER target_pe.
    // Implementation...
}
```

### 4. Use Constants for Magic Numbers
```kerboscript
// BAD
IF altitude > 70000 {
    // Code
}

// GOOD
LOCAL ATMOSPHERE_HEIGHT IS 70000.
IF altitude > ATMOSPHERE_HEIGHT {
    // Code
}
```

### 5. Error Handling
```kerboscript
// Check preconditions
IF SHIP:MAXTHRUST = 0 {
    PRINT "ERROR: No engines!".
    RETURN.
}

// Validate parameters
FUNCTION my_function {
    PARAMETER x.

    IF x <= 0 {
        PRINT "ERROR: x must be positive".
        RETURN -1.
    }

    // Normal code
}
```

---

## kOS Specific Features

### File System
```kerboscript
// Volume 0 is always the Archive (Ships/Script/)
SWITCH TO 0.

// Vessel volumes are 1, 2, 3, etc.
COPYPATH("0:/myfile.ks", "1:/myfile.ks").

// File operations
EXISTS("0:/myfile.ks")
DELETE "1:/oldfile.ks".
RENAME "1:/old.ks" TO "new.ks".
```

### Running Scripts
```kerboscript
RUN myfile.              // Runs once
RUNPATH("0:/myfile.ks"). // Explicit path
RUNONCEPATH("0:/lib.ks").// Only runs if not already run
```

### Compiling
```kerboscript
COMPILE myfile TO "compiled".
RUN compiled.  // Faster execution
```

### Wait Statements
```kerboscript
WAIT 5.               // Wait 5 seconds
WAIT UNTIL x > 10.    // Wait for condition
```

---

## Performance Tips

### 1. Cache Frequently Used Values
```kerboscript
// SLOW - Recalculates every iteration
UNTIL altitude > target {
    SET altitude TO SHIP:ALTITUDE.
    WAIT 0.01.
}

// FAST - Cache the value
UNTIL alt > target {
    LOCAL alt IS SHIP:ALTITUDE.
    WAIT 0.01.
}
```

### 2. Use SQRMAGNITUDE When Possible
```kerboscript
// SLOWER
IF v:MAG > 100 {
}

// FASTER (avoid SQRT)
IF v:SQRMAGNITUDE > 10000 {
}
```

### 3. Avoid Nested Function Calls
```kerboscript
// SLOWER
PRINT ROUND(SQRT(x^2 + y^2), 2).

// FASTER - Break into steps
LOCAL dist IS SQRT(x^2 + y^2).
PRINT ROUND(dist, 2).
```

---

## Quick Reference: Common Patterns

### Suicide Burn
```kerboscript
LOCAL v IS SHIP:VELOCITY:SURFACE:MAG.
LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
LOCAL a_max IS SHIP:MAXTHRUST / SHIP:MASS.
LOCAL stop_dist IS v^2 / (2 * (a_max - g)).
```

### Time to Impact (Simple)
```kerboscript
LOCAL alt IS SHIP:ALTITUDE.
LOCAL v_down IS -SHIP:VELOCITY:SURFACE:MAG.
LOCAL tti IS alt / v_down.
```

### Orbital Velocity
```kerboscript
LOCAL r IS BODY:RADIUS + SHIP:ALTITUDE.
LOCAL v_orbital IS SQRT(BODY:MU / r).
```

### Great Circle Distance
```kerboscript
FUNCTION great_circle_distance {
    PARAMETER lat1, lon1, lat2, lon2.

    LOCAL dlat IS (lat2 - lat1) * CONSTANT:DEGTORAD.
    LOCAL dlon IS (lon2 - lon1) * CONSTANT:DEGTORAD.

    LOCAL a IS SIN(dlat/2)^2 + COS(lat1*CONSTANT:DEGTORAD) *
               COS(lat2*CONSTANT:DEGTORAD) * SIN(dlon/2)^2.
    LOCAL c IS 2 * ARCTAN2(SQRT(a), SQRT(1-a)).

    RETURN BODY:RADIUS * c.
}
```

---

## Version History

- **v1.0** (2025-03-22): Initial reference created based on kOS 1.4.0+

---

## Additional Resources

- Official kOS Documentation: https://ksp-kos.github.io/KOS/
- kOS GitHub: https://github.com/KSP-KOS/KOS
- Community Forums: https://forum.kerbalspaceprogram.com/

---

**Remember:** When in doubt about a variable name, add a suffix (`_vec`, `_val`, `alt`, `vel`, etc.) to avoid conflicts with built-in keywords!
