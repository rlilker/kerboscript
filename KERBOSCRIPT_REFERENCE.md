# KerboScript Language Reference
## Complete specification for kOS programming in Kerbal Space Program

**Version:** kOS 1.4.0+
**Last Updated:** 2026-03-25

---

## Table of Contents
1. [Reserved Keywords](#reserved-keywords)
2. [Built-in Read-Only Variables](#built-in-read-only-variables)
3. [Data Types](#data-types)
4. [Syntax Rules](#syntax-rules)
5. [Variable Declaration & Scope](#variable-declaration--scope)
6. [Functions](#functions)
7. [Control Structures](#control-structures)
8. [Operators](#operators)
9. [Math Functions](#math-functions)
10. [String Functions](#string-functions)
11. [Vector Functions](#vector-functions)
12. [Direction Functions](#direction-functions)
13. [Collection Structures](#collection-structures)
14. [Common Suffixes](#common-suffixes)
15. [Flight Control](#flight-control)
16. [Prediction Functions](#prediction-functions)
17. [File System & Script Execution](#file-system--script-execution)
18. [Common Pitfalls](#common-pitfalls)
19. [Best Practices](#best-practices)
20. [Performance Tips](#performance-tips)
21. [Quick Reference: Common Patterns](#quick-reference-common-patterns)

---

## Reserved Keywords

**NEVER use these as variable, parameter, or function names.**

### Control Flow
```
IF, ELSE, UNTIL, FROM, TO, STEP, DO, WHILE, FOR, IN, BREAK, PRESERVE, RETURN, WAIT
```

### Declaration
```
SET, LOCK, UNLOCK, LOCAL, GLOBAL, PARAMETER, DECLARE, FUNCTION
```

### Boolean
```
TRUE, FALSE, AND, OR, NOT
```

### Action
```
ON, WHEN, THEN, TOGGLE, STAGE, PRINT, AT, CLEARSCREEN, LOG
RUN, RUNPATH, RUNONCEPATH, COMPILE, SWITCH, COPY, DELETE, RENAME, EXISTS
ADD, REMOVE, REVERT, REBOOT, SHUTDOWN, EDIT, ONCE
```

### Inspection / Misc
```
LIST, DEFINED, FILE, VOLUME, UNSET
```

### Special
```
OFF          // Used in:  LOCK STEERING TO OFF
CHOOSE       // Ternary:  CHOOSE x IF condition ELSE y
```

---

## Built-in Read-Only Variables

**NEVER use these as variable or parameter names — they will cause "clobber" errors.**

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
ALT   // Structure with :APOAPSIS, :PERIAPSIS, :RADAR suffixes
ETA   // Structure with :APOAPSIS, :PERIAPSIS, :NEXTNODE, :TRANSITION suffixes
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
SUN  // Kerbol
```

### Color Constants
```
WHITE, BLACK, RED, GREEN, BLUE, YELLOW, CYAN, MAGENTA
```

---

## Safe Naming Conventions

To avoid conflicts, use descriptive suffixes or prefixes:

```kerboscript
// WRONG - These are ALL reserved!
LOCAL altitude IS SHIP:ALTITUDE.    // "altitude" is reserved
LOCAL velocity IS SHIP:VELOCITY.    // "velocity" is reserved
LOCAL north IS SHIP:NORTH:VECTOR.   // "north" is reserved
LOCAL up IS SHIP:UP:VECTOR.         // "up" is reserved
LOCAL target IS TARGET.             // "target" is reserved
LOCAL body IS SHIP:BODY.            // "body" is reserved
LOCAL alt IS SHIP:ALTITUDE.         // "alt" is reserved (it's a structure!)
LOCAL list IS LIST().               // "list" is reserved

// CORRECT
LOCAL altitude_m IS SHIP:ALTITUDE.
LOCAL vel IS SHIP:VELOCITY.
LOCAL north_vec IS SHIP:NORTH:VECTOR.
LOCAL up_vec IS SHIP:UP:VECTOR.
LOCAL tgt IS TARGET.
LOCAL my_body IS SHIP:BODY.
LOCAL h IS SHIP:ALTITUDE.           // Physics notation (height)
```

---

## Data Types

### Scalars (Numbers)
```kerboscript
LOCAL x IS 42.
LOCAL pi IS 3.14159.
LOCAL big_number IS 1.5e6.    // Scientific notation: 1,500,000
LOCAL tiny IS 1.23e-4.        // Also works: 0.000123
```

### Booleans
```kerboscript
LOCAL flag IS TRUE.
LOCAL done IS FALSE.
LOCAL result IS (x > 5).      // Boolean expression
```

### Strings
```kerboscript
LOCAL name IS "Jeb".
LOCAL message IS "Hello " + name.    // Concatenation
// IMPORTANT: No non-ASCII characters in string literals!
// Em dashes, smart quotes, etc. cause "Unexpected token" parse errors.
// Comments are fine; only string literals must be plain ASCII.
```

### Vectors
```kerboscript
LOCAL v IS V(1, 2, 3).               // 3D vector
LOCAL direction IS SHIP:FACING:VECTOR.
LOCAL magnitude IS v:MAG.
LOCAL normalized IS v:NORMALIZED.
LOCAL sq_mag IS v:SQRMAGNITUDE.      // Faster than MAG when comparing distances
```

### Directions
```kerboscript
LOCAL d IS R(pitch, yaw, roll).      // Euler rotation (degrees)
LOCAL h IS HEADING(90, 10).          // Compass heading 90 deg, 10 deg pitch up
LOCAL combined IS SHIP:PROGRADE + R(0, 0, 45). // Prograde + 45 deg roll
```

### Lists
```kerboscript
LOCAL my_list IS LIST().
LOCAL pre_filled IS LIST(10, 20, 30).    // Pre-populated
my_list:ADD(10).
my_list:ADD(20).
LOCAL first IS my_list[0].               // Zero-indexed
LOCAL count IS my_list:LENGTH.
```

### Lexicons (Dictionaries)
```kerboscript
LOCAL my_lex IS LEXICON().
SET my_lex["key1"] TO "value1".
SET my_lex["count"] TO 42.
LOCAL val IS my_lex["key1"].
IF my_lex:HASKEY("count") { PRINT my_lex["count"]. }
```

### Structures (Complex Types)
```kerboscript
LOCAL current_orbit IS SHIP:ORBIT.
LOCAL home_planet IS SHIP:BODY.
LOCAL first_part IS SHIP:PARTS[0].
```

---

## Syntax Rules

### Case Insensitivity
```kerboscript
// These are all equivalent (keywords and identifiers are case-insensitive):
SET x TO 10.
set x to 10.
Set X To 10.
// Strings ARE case-sensitive:
IF "Jeb" = "jeb" { }    // FALSE
```

### Statement Terminators
```kerboscript
// Statements end with a period (.)
SET x TO 5.
PRINT "Hello".

// Blocks don't need periods after braces
IF x > 0 {
    PRINT "Positive".
}  // No period needed

// But you CAN add them:
IF x > 0 {
    PRINT "Positive".
}.  // Also valid
```

### Comments
```kerboscript
// Single-line comment

/* Multi-line
   comment */
```

### Special Symbols
```
()    Expression grouping and function parameters
{}    Statement blocks
[]    List/Lexicon indexing
#     Legacy list indexing — DEPRECATED, use [] instead
,     Argument separator
:     Suffix operator (member access): SHIP:ALTITUDE
@     Delegate operator — suppresses function call, returns a reference
      Example:  LOCAL func_ref IS my_func@.
                LOCAL result IS func_ref(5).
```

### Compiler Directives
```kerboscript
@LAZYGLOBAL OFF.      // REQUIRED: forces explicit declaration of all variables.
                      // Put at top of EVERY script.
                      // Without it, SET on undeclared variables silently
                      // creates globals — leads to hard-to-find bugs.

@CLOBBERBUILTINS ON.  // Allows variable names that shadow built-ins.
                      // AVOID: exists only for legacy scripts.
```

---

## Variable Declaration & Scope

### Declaration Syntax

```kerboscript
// These are all equivalent ways to declare a local variable:
LOCAL x IS 10.
DECLARE LOCAL x TO 10.
DECLARE x TO 10.         // assumes LOCAL by default

// Global declaration:
GLOBAL my_global IS 100.

// Multiple variables in one statement:
LOCAL a IS 5, b TO 1, c TO "hello".

// An initial value IS always required — this is a syntax error:
// DECLARE GLOBAL x.     // ERROR - no value provided
```

### SET vs IS vs DECLARE

| Statement | Behavior |
|-----------|----------|
| `LOCAL x IS 10.` | Creates a new local variable in current scope (preferred) |
| `GLOBAL x IS 10.` | Creates/updates a global variable |
| `SET x TO 20.` | Modifies existing `x`; if not found, creates global (AVOID without @LAZYGLOBAL OFF) |
| `LOCK x TO expr.` | Creates a live expression re-evaluated on each read |

### Scope Rules

- Each function body has its own local scope
- Loop and conditional blocks (`{}`) have their own local scope
- A variable declared `LOCAL` at file top-level is local to that file
- `GLOBAL` bypasses all scopes and writes to global scope
- With `@LAZYGLOBAL OFF`, using `SET` on an undeclared name is a runtime error

### LOCK Statements

```kerboscript
// LOCK creates a binding re-evaluated every time the variable is read
LOCK STEERING TO PROGRADE.     // Always points prograde, updates each physics tick
LOCK THROTTLE TO pid_output.   // Follows pid_output continuously

// Locks are ALWAYS GLOBAL for backward compatibility with cooked controls
// (STEERING, THROTTLE, WHEELTHROTTLE, WHEELSTEERING must be global)

// To remove a LOCK:
UNLOCK STEERING.
UNLOCK THROTTLE.
// All locks are automatically released when the script ends.
```

### DEFINED — Test if a Variable Exists

```kerboscript
IF DEFINED my_var {
    PRINT "my_var exists".
}
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

// Function with default parameters (optional must follow mandatory)
FUNCTION greet {
    PARAMETER name IS "World".
    RETURN "Hello " + name.
}

// Function with multiple statements
FUNCTION calc_orbital_velocity {
    PARAMETER target_alt_m.
    LOCAL r IS BODY:RADIUS + target_alt_m.
    LOCAL v IS SQRT(BODY:MU / r).
    RETURN v.
}
```

### Function Calls
```kerboscript
my_function().
LOCAL result IS add(5, 3).
LOCAL msg IS greet().          // Uses default
LOCAL msg2 IS greet("Jeb").    // Override default
```

### Delegate (Function Reference) Operator
```kerboscript
// Use @ to get a reference to a function without calling it:
LOCAL func_ref IS add@.        // NOT add() — that would call it
LOCAL result IS func_ref(5, 3).  // Call through the reference

// Anonymous function (lambda):
LOCAL double IS { PARAMETER x. RETURN x * 2. }.
PRINT double(5).  // Prints 10
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
// NOTE: Do NOT put a period before ELSE — it ends the statement.
```

### UNTIL Loop
```kerboscript
UNTIL condition {
    // Repeats while condition is FALSE (opposite of WHILE)
    WAIT 0.1.    // Always include a WAIT when monitoring physical values
}
```

### FROM Loop (C-style for loop)
```kerboscript
FROM { LOCAL i IS 0. } UNTIL i >= 10 STEP { SET i TO i + 1. } DO {
    PRINT i.
}
// The init block's variables are scoped to the loop
```

### FOR Loop (foreach)
```kerboscript
FOR item IN my_list {
    PRINT item.
}
```

### BREAK
```kerboscript
UNTIL TRUE {
    IF some_condition { BREAK. }
}
```

### WAIT
```kerboscript
WAIT 5.                    // Wait 5 real-time seconds
WAIT UNTIL x > 10.         // Wait for condition to become true
WAIT 0.                    // Yield to physics engine for exactly one tick
// WAIT 0. is often needed after operations that require a physics update
// (e.g. after VESSEL:BOUNDS, after staging, etc.)
```

### WHEN / THEN (Background Trigger)
```kerboscript
// Fires ONCE when condition first becomes true, then stops:
WHEN condition THEN {
    PRINT "Triggered!".
}

// To keep the trigger active after firing:
WHEN condition THEN {
    PRINT "Triggered again!".
    PRESERVE.           // Legacy syntax — re-arms the trigger
}

// Modern equivalent using RETURN:
WHEN condition THEN {
    PRINT "Triggered!".
    RETURN TRUE.        // TRUE = keep active; FALSE = disable (same as PRESERVE)
}

// IMPORTANT: Keep trigger bodies SHORT.
// Triggers run between physics ticks; long execution blocks everything.
// Never use WAIT inside a trigger body.
```

### ON (Event Trigger — fires on change)
```kerboscript
// Fires whenever the monitored expression CHANGES value:
ON STAGE {
    PRINT "Staged!".
    PRESERVE.
}

ON ABORT {
    PRINT "Abort!".
    // No PRESERVE — fires once only
}
```

---

## Operators

### Arithmetic
```
+    Addition
-    Subtraction
*    Multiplication
/    Division
^    Exponentiation (right-associative: 2^3^2 = 2^(3^2) = 512)
```

### Comparison
```
=    Equal
<>   Not equal
<    Less than
>    Greater than
<=   Less than or equal
>=   Greater than or equal
```

### Logical
```
AND    Logical AND
OR     Logical OR
NOT    Logical NOT
```

### Assignment
```
IS    Initial assignment  (LOCAL x IS 5.)
TO    Reassignment        (SET x TO 10.)
```

### Ternary
```kerboscript
CHOOSE expression_if_true IF condition ELSE expression_if_false

// Example:
LOCAL label IS CHOOSE "High" IF altitude > 10000 ELSE "Low".
LOCAL safe_dv IS CHOOSE dv IF dv > 0 ELSE 0.
```

### Operator Precedence (highest to lowest)
```
()                       Grouping
e                        Scientific notation (1.5e6)
^                        Exponentiation
*, /                     Multiplication, Division
+, -                     Addition, Subtraction
=, <>, <, >, <=, >=      Comparison
NOT                      Logical negation
AND                      Logical AND
OR                       Logical OR
```

---

## Math Functions

```kerboscript
// Rounding
ABS(x)             // Absolute value
CEILING(x)         // Round up to nearest integer
CEILING(x, places) // Round up to N decimal places
FLOOR(x)           // Round down to nearest integer
FLOOR(x, places)   // Round down to N decimal places
ROUND(x)           // Round to nearest integer
ROUND(x, places)   // Round to N decimal places

// Arithmetic
SQRT(x)            // Square root
MOD(a, b)          // Remainder (a mod b)
MIN(a, b)          // Smaller of two values
MAX(a, b)          // Larger of two values
LN(x)              // Natural logarithm
LOG10(x)           // Base-10 logarithm

// Trigonometry (all angles in DEGREES)
SIN(deg)           // Sine
COS(deg)           // Cosine
TAN(deg)           // Tangent
ARCSIN(x)          // Inverse sine   → degrees, range [-90..90]
ARCCOS(x)          // Inverse cosine → degrees, range [0..180]
ARCTAN(x)          // Inverse tangent → degrees
ARCTAN2(y, x)      // Two-argument arctangent → degrees; handles all quadrants

// Constants (via CONSTANT structure)
CONSTANT:PI        // 3.14159265358979...
CONSTANT:E         // 2.71828182845905...
CONSTANT:G         // 6.67408e-11 (gravitational constant)
CONSTANT:DEGTORAD  // PI / 180 (multiply degrees to get radians)
CONSTANT:RADTODEG  // 180 / PI (multiply radians to get degrees)

// Character conversion
CHAR(n)            // Unicode code point → single-character string
UNCHAR(s)          // Single character → unicode code point

// Random numbers
RANDOM()           // Uniform float in [0..1)
RANDOM(key)        // Next value from named random sequence
RANDOMSEED(key, n) // Initialize named sequence with seed n (deterministic)
```

---

## String Functions

```kerboscript
LOCAL s IS "Hello World".

// Properties
s:LENGTH                       // Character count
s:TOLOWER                      // "hello world"
s:TOUPPER                      // "HELLO WORLD"
s:TRIM                         // Remove leading/trailing whitespace
s:TRIMSTART                    // Remove leading whitespace only
s:TRIMEND                      // Remove trailing whitespace only

// Search
s:CONTAINS("World")            // TRUE
s:STARTSWITH("Hello")          // TRUE
s:ENDSWITH("World")            // TRUE
s:FIND("o")                    // 4 (first index of "o")
s:FINDAT("o", 5)               // 7 (search starting at index 5)
s:FINDLAST("o")                // 7 (last index of "o")
s:FINDLASTAT("o", 6)           // 4 (search backwards from index 6)
s:INDEXOF("World")             // 6 (alias for FIND)
s:MATCHESPATTERN("H.*d")       // TRUE (regex match)

// Manipulation
s:SUBSTRING(6, 5)              // "World" (start, length)
s:REPLACE("World", "Kerbin")   // "Hello Kerbin"
s:SPLIT(" ")                   // LIST("Hello","World")
s:INSERT(5, ",")               // "Hello, World"
s:REMOVE(5, 1)                 // "Hello World" → "HelloWorld" (start, count)
s:PADLEFT(15)                  // "   Hello World" (right-align in 15 chars)
s:PADRIGHT(15)                 // "Hello World   " (left-align in 15 chars)

// Conversion
s:TONUMBER(0)                  // Parse as number; return 0 if fails
"3.14":TOSCALAR(0)             // Same as TONUMBER
```

---

## Vector Functions

```kerboscript
// Construction
LOCAL v IS V(1, 2, 3).

// Properties (Get/Set unless noted)
v:X                     // X component (get/set)
v:Y                     // Y component (get/set)
v:Z                     // Z component (get/set)
v:MAG                   // Magnitude (get/set — setting rescales the vector)
v:NORMALIZED            // Unit vector, same direction (get only)
v:SQRMAGNITUDE          // Squared magnitude — faster than MAG for comparisons
v:DIRECTION             // Convert to Direction (get/set)
v:VEC                   // Independent copy of this vector

// Vector math functions
VDOT(v1, v2)            // Dot product → scalar
VECTORDOTPRODUCT(v1, v2)  // Alias for VDOT
VCRS(v1, v2)            // Cross product → perpendicular vector
VECTORCROSSPRODUCT(v1, v2)  // Alias for VCRS
VANG(v1, v2)            // Angle between vectors → degrees
VECTORANGLE(v1, v2)     // Alias for VANG
VXCL(v1, v2)            // Exclude: project v2 onto plane perpendicular to v1
VECTOREXCLUDE(v1, v2)   // Alias for VXCL

// Arithmetic operators
v1 + v2                 // Vector addition
v1 - v2                 // Vector subtraction
v1 * scalar             // Scale vector
scalar * v1             // Scale vector (commutative)
```

---

## Direction Functions

```kerboscript
// R(pitch, yaw, roll) — Euler rotation in degrees
LOCAL d IS R(0, 90, 0).          // Rotate 90 degrees around yaw axis
LOCAL d2 IS R(20, 0, 0).         // Pitch up 20 degrees

// HEADING(compass, pitch) — from horizon
// compass: degrees clockwise from north (0=N, 90=E, 180=S, 270=W)
// pitch: degrees above horizon (positive = up)
LOCAL east IS HEADING(90, 0).
LOCAL northeast_climb IS HEADING(45, 15).

// LOOKDIRUP(forwardVec, upVec) — point in direction with specific "up"
LOCAL d IS LOOKDIRUP(vel_vec, up_vec).

// ANGLEAXIS(degrees, axisVector) — rotate around an axis
LOCAL rot IS ANGLEAXIS(90, V(0,1,0)).   // 90 deg around Y axis

// ROTATEFROMTO(fromVec, toVec) — rotation that maps fromVec onto toVec
LOCAL d IS ROTATEFROMTO(SHIP:FACING:VECTOR, target_vec).

// Q(x, y, z, w) — quaternion constructor (advanced use)
LOCAL q IS Q(0, 0.707, 0, 0.707).

// Direction arithmetic
SHIP:PROGRADE + R(0, 20, 0)      // Prograde pitched up 20 degrees
HEADING(90, 0) * R(0, 0, 45)     // East heading with 45 deg roll

// Direction suffixes
d:VECTOR                  // Forward-pointing unit vector
d:UPVECTOR                // Up-pointing unit vector
d:RIGHTVECTOR             // Right-pointing unit vector
d:PITCH                   // Pitch angle (degrees)
d:YAW                     // Yaw angle (degrees)
d:ROLL                    // Roll angle (degrees)
d:INVERSE                 // Opposite rotation
```

---

## Collection Structures

### LIST

```kerboscript
// Construction
LOCAL empty IS LIST().
LOCAL filled IS LIST(10, 20, 30).
LOCAL nested IS LIST(LIST(1,2), LIST(3,4)).    // 2D array

// Core suffixes
my_list:LENGTH             // Number of elements
my_list:ADD(item)          // Append to end
my_list:INSERT(idx, item)  // Insert before index idx
my_list:REMOVE(idx)        // Remove element at index idx
my_list:CLEAR()            // Remove all elements
my_list:COPY               // Shallow copy of the list
my_list:SUBLIST(idx, len)  // New list: len elements starting at idx
my_list:JOIN(separator)    // Concatenate all elements with separator string
my_list:FIND(item)         // First index of item (-1 if not found)
my_list:FINDLAST(item)     // Last index of item (-1 if not found)
my_list:CONTAINS(item)     // TRUE if item exists in list
my_list:ITERATOR           // Iterator object for manual iteration
my_list:DUMP               // Verbose string representation

// Indexing
my_list[0]                 // First element (zero-indexed)
my_list[my_list:LENGTH-1]  // Last element

// Iteration
FOR item IN my_list {
    PRINT item.
}

// IMPORTANT: Lists compare by identity, not content.
// list1 = list2 is TRUE only if they are the SAME list object.
// To compare contents, iterate element by element.
```

### LEXICON (Dictionary)

```kerboscript
// Construction
LOCAL empty IS LEXICON().
LOCAL filled IS LEXICON("key1", "val1", "key2", 42).  // key-value pairs

// Core suffixes
lex:LENGTH             // Number of key-value pairs
lex:KEYS               // List of all keys
lex:VALUES             // List of all values
lex:HASKEY("key")      // TRUE if key exists
lex:HASVALUE(val)      // TRUE if value exists
lex:ADD("key", val)    // Add new pair (error if key exists)
lex:REMOVE("key")      // Delete pair by key
lex:CLEAR()            // Remove all pairs
lex:COPY()             // Shallow copy
lex:CASESENSITIVE      // Boolean; default FALSE. Setting to TRUE clears the lexicon!
lex:DUMP               // Verbose string representation

// Access
lex["key"]             // Get or set by string key
SET lex["key"] TO val. // Create or update (unlike ADD, no error if exists)
lex:key                // Shorthand suffix syntax (only works for simple key names)

// Case insensitivity (default)
SET lex["ABC"] TO 1.
PRINT lex["abc"].      // Works — keys are case-insensitive by default
```

---

## Common Suffixes

### Vessel Suffixes

```kerboscript
// Motion
SHIP:ALTITUDE              // Meters above sea level
SHIP:VELOCITY:SURFACE      // Velocity vector relative to surface
SHIP:VELOCITY:ORBIT        // Velocity vector in orbital frame
SHIP:VERTICALSPEED         // Vertical component of surface velocity (m/s)
SHIP:GROUNDSPEED           // Horizontal surface speed (m/s)
SHIP:AIRSPEED              // Speed relative to air mass (m/s)
SHIP:DYNAMICPRESSURE       // Dynamic pressure (atm); alias: SHIP:Q
SHIP:BEARING               // Relative heading to target vessel (degrees)

// Mass
SHIP:MASS                  // Current mass (metric tons)
SHIP:WETMASS               // Mass fully fueled (metric tons)
SHIP:DRYMASS               // Mass with no resources (metric tons)

// Thrust
SHIP:MAXTHRUST             // Max thrust of all active engines (kN)
SHIP:AVAILABLETHRUST       // Thrust at current throttle setting (kN)
SHIP:THRUST                // Current actual thrust (kN)

// Delta-V
SHIP:DELTAV                // DeltaV structure for whole vessel
SHIP:STAGEDELTAV(n)        // DeltaV structure for stage n
SHIP:DELTAVASL             // Delta-V at sea level (m/s)
SHIP:DELTAVVACUUM          // Delta-V in vacuum (m/s)
SHIP:BURNTIME              // Total burn time (seconds)

// Attitude
SHIP:FACING                // Direction the ship is pointed (Direction)
SHIP:FACING:VECTOR         // Forward unit vector
SHIP:UP:VECTOR             // "Up" unit vector (away from body center)
SHIP:NORTH:VECTOR          // North unit vector
SHIP:PROGRADE              // Prograde direction
SHIP:RETROGRADE            // Retrograde direction
SHIP:SRFPROGRADE           // Surface-relative prograde
SHIP:SRFRETROGRADE         // Surface-relative retrograde
SHIP:ANGULARMOMENTUM       // Angular momentum vector
SHIP:ANGULARVEL            // Angular velocity vector

// Identity
SHIP:NAME / SHIP:SHIPNAME  // Vessel name (get/set)
SHIP:TYPE                  // Vessel type string (get/set)
SHIP:STATUS                // "LANDED", "ORBITING", "FLYING", etc.
SHIP:STAGENUM              // Current stage number
SHIP:CREW()                // List of CrewMember structures
SHIP:CREWCAPACITY          // Maximum crew capacity

// Parts
SHIP:PARTS                 // List of all Part structures
SHIP:ENGINES               // List of all Engine structures
SHIP:RCS                   // List of all RCS thruster structures
SHIP:DOCKINGPORTS          // List of all DockingPort structures
SHIP:RESOURCES             // List of AggregateResource structures
SHIP:ROOTPART              // The root Part
SHIP:CONTROLPART           // Part used as control reference

// Part query methods
SHIP:PARTSNAMED("name")          // List[Part] matched by Part:NAME
SHIP:PARTSNAMEDPATTERN("regex")  // List[Part] matched by regex on NAME
SHIP:PARTSTITLED("title")        // List[Part] matched by Part:TITLE
SHIP:PARTSTAGGED("tag")          // List[Part] matched by Part:TAG
SHIP:PARTSDUBBED("name")         // List[Part] matching NAME, TITLE, or TAG
SHIP:MODULESNAMED("ModName")     // List[PartModule] by module class name
SHIP:ALLTAGGEDPARTS()            // List[Part] with any non-blank tag

// Connection & Communication
SHIP:CONNECTION                  // Connection structure to this vessel
SHIP:MESSAGES                    // MessageQueue (for inter-vessel messaging)
SHIP:LOADED                      // TRUE if within physics range
SHIP:ISDEAD                      // TRUE if vessel no longer exists
```

### Orbit Suffixes

```kerboscript
SHIP:ORBIT:APOAPSIS              // Apoapsis altitude (m above sea level)
SHIP:ORBIT:PERIAPSIS             // Periapsis altitude (m above sea level)
SHIP:ORBIT:BODY                  // Body being orbited
SHIP:ORBIT:PERIOD                // Orbital period (seconds)
SHIP:ORBIT:INCLINATION           // Inclination (degrees, relative to equator)
SHIP:ORBIT:ECCENTRICITY          // Eccentricity (<1 = ellipse, >=1 = open)
SHIP:ORBIT:SEMIMAJORAXIS         // Semi-major axis (meters)
SHIP:ORBIT:SEMIMINORAXIS         // Semi-minor axis (meters)
SHIP:ORBIT:LAN                   // Longitude of ascending node (degrees)
                                  // Alias: SHIP:ORBIT:LONGITUDEOFASCENDINGNODE
SHIP:ORBIT:ARGUMENTOFPERIAPSIS   // Argument of periapsis (degrees)
SHIP:ORBIT:TRUEANOMALY           // True anomaly: current position in orbit (degrees)
                                  // Range [0..360) for closed; (-180..180) for open
SHIP:ORBIT:MEANANOMALYATEPOCH    // Mean anomaly at epoch (degrees)
SHIP:ORBIT:EPOCH                 // Reference timestamp — CHANGES during time warp
SHIP:ORBIT:TRANSITION            // "INITIAL", "FINAL", "ENCOUNTER", "ESCAPE", "MANEUVER"
SHIP:ORBIT:HASNEXTPATCH          // TRUE if orbit transitions (requires tracking upgrade)
SHIP:ORBIT:NEXTPATCH             // Next orbit patch (requires tracking upgrade)
SHIP:ORBIT:NEXTPATCHETA          // Seconds until next patch transition
SHIP:ORBIT:POSITION              // Current position vector
SHIP:ORBIT:VELOCITY              // Current OrbitableVelocity structure
```

### Body Suffixes

```kerboscript
BODY:RADIUS                // Body radius (meters)
BODY:MU                    // Gravitational parameter (m^3/s^2)
BODY:MASS                  // Body mass (kg)
BODY:ATM:EXISTS            // TRUE if body has atmosphere
BODY:ATM:HEIGHT            // Atmosphere top altitude (meters)
                            // USE THIS instead of hardcoding 70000!
BODY:ATM:PRESSURE          // Pressure at sea level (atm)
BODY:POSITION              // Position vector of body center
BODY:ROTATIONPERIOD        // Sidereal rotation period (seconds)
BODY:ORBITINGCHILDREN      // List of orbiting bodies/vessels
```

### Time Suffixes

```kerboscript
TIME:SECONDS               // Universal time in seconds since epoch
TIME:YEAR                  // Current in-game year
TIME:DAY                   // Day of current year
TIME:HOUR                  // Hour of current day
TIME:MINUTE                // Minute of current hour
TIME:SECOND                // Second of current minute
MISSIONTIME                // Seconds elapsed since vessel launch
```

### Vector Suffixes
```kerboscript
:MAG                       // Magnitude
:NORMALIZED                // Unit vector (same direction, length 1)
:SQRMAGNITUDE              // Squared magnitude (faster than MAG^2)
:X, :Y, :Z                 // Components
:DIRECTION                 // Convert to Direction
```

### List Suffixes
```kerboscript
:LENGTH                    // Element count
:ADD(item)                 // Append
:INSERT(idx, item)         // Insert at position
:REMOVE(idx)               // Remove at position
:CLEAR()                   // Remove all
:CONTAINS(item)            // TRUE if item present
:FIND(item)                // First index (-1 if missing)
:FINDLAST(item)            // Last index (-1 if missing)
:SUBLIST(start, len)       // Sub-list
:JOIN(sep)                 // Join to string
:COPY                      // Shallow copy
```

---

## Flight Control

### Cooked Control (Recommended)

```kerboscript
// LOCK creates a continuously-updating binding
LOCK THROTTLE TO 1.0.               // Range: 0.0 to 1.0
LOCK THROTTLE TO throttle_pid.      // Dynamic expression

LOCK STEERING TO PROGRADE.          // Point prograde
LOCK STEERING TO HEADING(90, 0).    // Fly east, level
LOCK STEERING TO UP + R(20, 0, 0).  // Vertical + 20 deg pitch
LOCK STEERING TO target_direction.  // Any Direction or Vector
LOCK STEERING TO "kill".            // Kill rotation (damp angular velocity)

LOCK WHEELTHROTTLE TO 0.5.          // Rover drive: -1.0 to 1.0
LOCK WHEELSTEERING TO HEADING(90,0). // Rover steering: GeoCoord, Vessel, or scalar

// Release control
UNLOCK STEERING.
UNLOCK THROTTLE.
// Controls also auto-release when script ends.
```

**Critical caveats:**
- **Do NOT use both SAS and `LOCK STEERING` at the same time** — they fight each other
- If multiple processor parts both lock STEERING, whichever updates last wins
- Never use `WAIT` inside a `LOCK` expression — it starves the physics engine
- WHEELSTEERING is confused by vertically-mounted probe cores; orient forward

### Raw Control (Direct input)

```kerboscript
// Raw control uses SET, not LOCK, and requires manual management each tick
SET SHIP:CONTROL:MAINTHROTTLE TO 0.5.    // Engine throttle: 0 to 1
SET SHIP:CONTROL:PITCH TO 0.2.           // Pitch: -1 to 1 (up positive)
SET SHIP:CONTROL:YAW TO -0.1.            // Yaw: -1 to 1 (right positive)
SET SHIP:CONTROL:ROLL TO 0.              // Roll: -1 to 1
SET SHIP:CONTROL:ROTATION TO V(0.2, -0.1, 0).  // Combined: V(pitch, yaw, roll)

// RCS translation (only works with RCS enabled):
SET SHIP:CONTROL:FORE TO 0.5.            // Forward: -1 to 1
SET SHIP:CONTROL:STARBOARD TO 0.1.       // Right: -1 to 1
SET SHIP:CONTROL:TOP TO -0.3.            // Up: -1 to 1
SET SHIP:CONTROL:TRANSLATION TO V(0.1, -0.3, 0.5).  // V(starboard, top, fore)

// Rover:
SET SHIP:CONTROL:WHEELSTEER TO 0.3.      // Steering: -1 to 1
SET SHIP:CONTROL:WHEELTHROTTLE TO 0.5.   // Drive speed: -1 to 1

// Release all raw controls:
SET SHIP:CONTROL:NEUTRALIZE TO TRUE.
```

**Raw control limitations:**
- RCS translation has a built-in **5% null zone** — inputs below 5% range do nothing
- `YAWTRIM`, `PITCHTRIM`, `ROLLTRIM` have no real effect in practice
- Raw controls do NOT work with Breaking Ground DLC robotic parts

---

## Prediction Functions

```kerboscript
// Predict future state of a vessel or body at a given time.
// 'time' can be a TimeStamp or universal seconds (scalar).

// Position at time (ship-raw coordinate frame):
LOCAL future_pos IS POSITIONAT(SHIP, TIME:SECONDS + 300).
LOCAL body_pos IS POSITIONAT(BODY, TIME:SECONDS + 3600).

// Velocity at time (returns OrbitalVelocity structure):
LOCAL future_vel IS VELOCITYAT(SHIP, TIME:SECONDS + 300).
PRINT future_vel:ORBIT:MAG.    // Orbital speed
PRINT future_vel:SURFACE:MAG.  // Surface speed

// Orbit patch at time (returns Orbit structure):
LOCAL future_orbit IS ORBITAT(SHIP, TIME:SECONDS + 300).
PRINT future_orbit:PERIAPSIS.

// These functions account for planned maneuver nodes when applicable.
```

---

## File System & Script Execution

```kerboscript
// Volume 0 is always the Archive (Ships/Script/)
// Vessel volumes start at 1 (stored on kOS processor parts)

SWITCH TO 0.                           // Switch active volume to Archive
SWITCH TO 1.                           // Switch to vessel volume 1

// Running scripts
RUN myfile.                            // Run script on active volume
RUNPATH("0:/myfile.ks").               // Run by explicit path
RUNPATH("0:/lib/ascent.ks").           // Run from subdirectory
RUNONCEPATH("0:/lib/util.ks").         // Run only if not already run this session

// File path operations (preferred over legacy COPY/DELETE)
COPYPATH("0:/myfile.ks", "1:/myfile.ks").   // Copy between volumes
MOVEPATH("0:/old.ks", "0:/new.ks").         // Move/rename

// Legacy operations (still work)
COPY myfile FROM 0 TO 1.
DELETE myfile FROM 1.
RENAME myfile TO newname.

// File existence check
IF EXISTS("0:/myfile.ks") { PRINT "File found". }

// Compiling (creates .ksm — faster execution)
COMPILE "0:/myfile.ks" TO "0:/myfile.ksm".
RUN myfile.ksm.
```

---

## Common Pitfalls

### 1. Reserved Keyword as Variable Name
```kerboscript
// WRONG
PARAMETER altitude.    // "altitude" is reserved
LOCAL list IS LIST().  // "list" is reserved

// CORRECT
PARAMETER alt_m.
LOCAL my_list IS LIST().
```

### 2. RETURN Outside a Function
```kerboscript
// WRONG — RETURN only works inside a FUNCTION body
IF x > 10 { RETURN. }    // ERROR at runtime

// CORRECT — use a flag variable
IF x > 10 { SET should_continue TO FALSE. }
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

### 4. Implicit Global (without @LAZYGLOBAL OFF)
```kerboscript
// WRONG — Creates implicit global (dangerous)
SET my_var TO 10.

// CORRECT
LOCAL my_var IS 10.
// And put @LAZYGLOBAL OFF. at the top of every file!
```

### 5. LOCK vs SET Semantics
```kerboscript
// LOCK = live expression, re-evaluated every read
LOCK STEERING TO PROGRADE.    // Always tracks prograde

// SET = one-time snapshot
SET STEERING TO PROGRADE.     // Sets once, does NOT track changes
```

### 6. WAIT in LOCK Expressions
```kerboscript
// WRONG — Starves the physics engine, causes lag/freeze
LOCK THROTTLE TO { WAIT 0.1. RETURN pid(). }.   // Never do this

// CORRECT — LOCKed expressions must be instantaneous
LOCK THROTTLE TO pid_output.    // pid_output updated in main loop
```

### 7. SAS + LOCK STEERING Conflict
```kerboscript
// WRONG — They fight each other
SET SAS TO TRUE.
LOCK STEERING TO PROGRADE.

// CORRECT — Use one or the other
SET SAS TO FALSE.
LOCK STEERING TO PROGRADE.
```

### 8. Hardcoded Atmosphere Height
```kerboscript
// WRONG — Breaks on other bodies
IF SHIP:ALTITUDE > 70000 { ... }

// CORRECT — Works anywhere
IF SHIP:ALTITUDE > BODY:ATM:HEIGHT { ... }
```

### 9. Non-ASCII in String Literals
```kerboscript
// WRONG — Causes "Unexpected token" parse error
LOCAL msg IS "Mission — success".   // em dash is non-ASCII

// CORRECT
LOCAL msg IS "Mission - success".   // plain ASCII hyphen
// Note: Comments CAN contain non-ASCII. Only string literals must be ASCII.
```

### 10. Accessing eng:RESOURCES (doesn't exist)
```kerboscript
// WRONG — EngineValue has no :RESOURCES suffix
FOR eng IN SHIP:ENGINES {
    PRINT eng:RESOURCES.    // ERROR
}

// CORRECT — Resources are on parts, not engines
FOR pt IN SHIP:PARTS {
    FOR res IN pt:RESOURCES {
        PRINT res:NAME + ": " + res:AMOUNT.
    }
}
```

### 11. Floating Point Comparison
```kerboscript
// WRONG — Precision issues
IF x = 0.1 + 0.2 { PRINT "Equal". }   // Might not be exactly 0.3

// CORRECT — Use tolerance
LOCAL epsilon IS 0.001.
IF ABS(x - 0.3) < epsilon { PRINT "Equal". }
```

### 12. Modifying List During Iteration
```kerboscript
// WRONG
FOR item IN my_list { my_list:REMOVE(0). }

// CORRECT — Iterate backwards by index
LOCAL i IS my_list:LENGTH - 1.
UNTIL i < 0 {
    my_list:REMOVE(i).
    SET i TO i - 1.
}
```

### 13. DECOUPLEDIN and Stage Numbering
```kerboscript
// Stages count DOWN (7, 6, 5, ...).
// part:DECOUPLEDIN = stage number at which the part separates.
// The NEXT stage to fire = highest DECOUPLEDIN among currently-attached parts.
// Do NOT assume STAGE:NUMBER matches DECOUPLEDIN.
FOR pt IN SHIP:PARTS {
    PRINT pt:NAME + " decouples in stage " + pt:DECOUPLEDIN.
}
```

### 14. DECLARE without Initial Value
```kerboscript
// WRONG — Syntax error; initializer is always required
DECLARE GLOBAL x.      // ERROR

// CORRECT
DECLARE GLOBAL x TO 0.
// or
GLOBAL x IS 0.
```

---

## Best Practices

### 1. Always Use @LAZYGLOBAL OFF
```kerboscript
// Put at the top of EVERY script
@LAZYGLOBAL OFF.

// Now all variables must be explicitly declared:
LOCAL x IS 10.    // Required; SET x TO 10 errors if x not declared
```

### 2. Use Descriptive Names with Units
```kerboscript
// BAD
LOCAL x IS 100000.
LOCAL t IS 60.

// GOOD
LOCAL target_altitude_m IS 100000.
LOCAL burn_duration_s IS 30.
```

### 3. Document Complex Functions
```kerboscript
// Calculate delta-V for circularization at apoapsis
// Parameters:
//   target_pe_m - desired periapsis altitude in meters
// Returns: delta-V in m/s
FUNCTION calc_circularize_dv {
    PARAMETER target_pe_m.
    // ...implementation...
}
```

### 4. Use BODY:ATM:HEIGHT for Atmosphere
```kerboscript
// BAD — Breaks on non-Kerbin bodies
LOCAL ATMOSPHERE_HEIGHT IS 70000.

// GOOD — Works universally
LOCAL atm_height_m IS BODY:ATM:HEIGHT.
```

### 5. Error Handling
```kerboscript
// Check preconditions before acting
IF SHIP:MAXTHRUST = 0 {
    PRINT "ERROR: No active engines.".
    RETURN.
}

// Validate parameters
FUNCTION calc_dv {
    PARAMETER isp_s, m0_kg, m1_kg.
    IF m1_kg <= 0 OR m0_kg <= m1_kg {
        PRINT "ERROR: Invalid mass parameters.".
        RETURN -1.
    }
    RETURN isp_s * 9.80665 * LN(m0_kg / m1_kg).
}
```

### 6. Use WAIT in Monitoring Loops
```kerboscript
// WRONG — Spins CPU, no time passes
UNTIL SHIP:ALTITUDE > 100000 { }

// CORRECT — Yields to physics engine
UNTIL SHIP:ALTITUDE > 100000 {
    WAIT 0.1.    // Or WAIT 0. for minimum yield
}
```

---

## Performance Tips

### 1. Cache Frequently Used Values
```kerboscript
// SLOW — Re-accesses SHIP:ALTITUDE every iteration
UNTIL SHIP:ALTITUDE > target_m {
    IF SHIP:ALTITUDE > 50000 { ... }
    WAIT 0.1.
}

// FAST — Cache locally
UNTIL SHIP:ALTITUDE > target_m {
    LOCAL h IS SHIP:ALTITUDE.
    IF h > 50000 { ... }
    WAIT 0.1.
}
```

### 2. Use SQRMAGNITUDE for Distance Comparisons
```kerboscript
// SLOWER — Takes square root
IF v:MAG > 100 { }

// FASTER — No square root needed
IF v:SQRMAGNITUDE > 10000 { }   // 100^2 = 10000
```

### 3. Avoid Nested Function Calls
```kerboscript
// SLOWER
PRINT ROUND(SQRT(x^2 + y^2), 2).

// FASTER
LOCAL dist IS SQRT(x^2 + y^2).
PRINT ROUND(dist, 2).
```

### 4. Keep Trigger Bodies Short
```kerboscript
// Triggers (WHEN/THEN, ON) run between physics ticks.
// Long trigger bodies block everything else.
// Keep them to < a few lines; set flags for main loop to handle.

WHEN SHIP:ALTITUDE > 50000 THEN {
    SET entered_upper_atm TO TRUE.
    // Don't do complex calculations here — just set a flag
}
```

---

## Quick Reference: Common Patterns

### Suicide Burn Stop Distance
```kerboscript
LOCAL spd IS SHIP:VELOCITY:SURFACE:MAG.
LOCAL g IS BODY:MU / (BODY:RADIUS + SHIP:ALTITUDE)^2.
LOCAL a_max IS SHIP:MAXTHRUST / SHIP:MASS.
LOCAL stop_dist_m IS spd^2 / (2 * (a_max - g)).
```

### Time to Impact (Simple)
```kerboscript
LOCAL h IS SHIP:ALTITUDE.
LOCAL v_down IS -SHIP:VELOCITY:SURFACE:MAG.
LOCAL tti_s IS h / v_down.
```

### Orbital Velocity at Altitude
```kerboscript
LOCAL r IS BODY:RADIUS + SHIP:ALTITUDE.
LOCAL v_orbital IS SQRT(BODY:MU / r).
```

### Hohmann Transfer Delta-V
```kerboscript
// Delta-V to raise apoapsis from current altitude to target altitude
FUNCTION dv_hohmann_raise {
    PARAMETER target_alt_m.
    LOCAL mu IS BODY:MU.
    LOCAL r1 IS BODY:RADIUS + SHIP:ALTITUDE.
    LOCAL r2 IS BODY:RADIUS + target_alt_m.
    LOCAL v1 IS SQRT(mu / r1).
    LOCAL v_transfer IS SQRT(mu * (2/r1 - 1/((r1+r2)/2))).
    RETURN v_transfer - v1.
}
```

### Tsiolkovsky Rocket Equation
```kerboscript
// Delta-V from specific impulse and mass ratio
FUNCTION tsiolkovsky_dv {
    PARAMETER isp_s, m_initial_kg, m_final_kg.
    RETURN isp_s * 9.80665 * LN(m_initial_kg / m_final_kg).
}
```

### Circularization Burn Delta-V (at apoapsis)
```kerboscript
FUNCTION dv_circularize {
    LOCAL mu IS BODY:MU.
    LOCAL r_ap IS BODY:RADIUS + SHIP:APOAPSIS.
    LOCAL r_pe IS BODY:RADIUS + SHIP:PERIAPSIS.
    LOCAL v_now IS SQRT(mu * (2/r_ap - 2/(r_ap + r_pe))).
    LOCAL v_circ IS SQRT(mu / r_ap).
    RETURN v_circ - v_now.
}
```

### Great Circle Distance
```kerboscript
FUNCTION great_circle_dist {
    PARAMETER lat1, lon1, lat2, lon2.
    LOCAL dlat IS (lat2 - lat1) * CONSTANT:DEGTORAD.
    LOCAL dlon IS (lon2 - lon1) * CONSTANT:DEGTORAD.
    LOCAL a IS SIN(dlat/2)^2 +
               COS(lat1*CONSTANT:DEGTORAD) * COS(lat2*CONSTANT:DEGTORAD) * SIN(dlon/2)^2.
    LOCAL c IS 2 * ARCTAN2(SQRT(a), SQRT(1-a)).
    RETURN BODY:RADIUS * c.
}
```

### PID Controller Skeleton
```kerboscript
LOCAL pid_kp IS 1.0.
LOCAL pid_ki IS 0.1.
LOCAL pid_kd IS 0.5.
LOCAL pid_integral IS 0.
LOCAL pid_last_error IS 0.
LOCAL pid_last_time IS TIME:SECONDS.

FUNCTION pid_update {
    PARAMETER setpoint, measured.
    LOCAL now IS TIME:SECONDS.
    LOCAL dt IS now - pid_last_time.
    IF dt <= 0 { RETURN 0. }
    LOCAL err IS setpoint - measured.
    SET pid_integral TO pid_integral + err * dt.
    LOCAL derivative IS (err - pid_last_error) / dt.
    SET pid_last_error TO err.
    SET pid_last_time TO now.
    RETURN pid_kp * err + pid_ki * pid_integral + pid_kd * derivative.
}
```

---

## Version History

- **v2.0** (2026-03-25): Major expansion — added math/string/vector/direction functions, full vessel/orbit suffix reference, raw control table, prediction functions, lexicon detail, operator precedence, directives, delegate operator, numerous pitfalls and patterns
- **v1.0** (2025-03-22): Initial reference created based on kOS 1.4.0+

---

## Additional Resources

- Official kOS Documentation: https://ksp-kos.github.io/KOS/
- kOS GitHub: https://github.com/KSP-KOS/KOS
- Community Forums: https://forum.kerbalspaceprogram.com/

---

**Remember:** When in doubt about a variable name, add a suffix (`_m`, `_s`, `_vec`, `_val`, etc.) to avoid conflicts with built-in keywords. Always use `@LAZYGLOBAL OFF.` at the top of every script.
