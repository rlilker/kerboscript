# Integrated Launch & Booster Recovery System

A comprehensive kOS autopilot system for Kerbal Space Program that provides:
- **Automated gravity turn launch** with asparagus staging
- **Orbital circularization** to target apoapsis
- **SpaceX-style booster recovery** with RTLS (Return To Launch Site) precision landing

## Features

### Launch Autopilot (`launch.ks`)
- Smooth gravity turn ascent profile
- Automatic asparagus staging detection
- Dynamic throttle control (Q-limit and apoapsis management)
- Automatic circularization at apoapsis
- Triggers landing scripts on separated boosters

### Booster Landing (`autoland_staging.ks`)
- Autonomous landing for all boosters with kOS processors
- Flip maneuver to retrograde orientation
- Boostback burn for RTLS trajectory
- Entry burn (if speed is excessive)
- Suicide burn with adaptive throttle control
- Precision landing within 10m of target
- Multiple boosters land with 10m spacing for safety

## Installation

1. **Copy scripts to KSP:**
   ```
   Ships/Script/
   ├── launch.ks
   ├── autoland_staging.ks
   └── lib/
       ├── util.ks
       ├── guidance.ks
       ├── ascent.ks
       ├── circularize.ks
       ├── boostback.ks
       ├── entry.ks
       └── landing.ks
   ```

2. **Verify files are in place:**
   - All 9 files should be present
   - Library files must be in the `lib/` subdirectory

## Vehicle Requirements

### Main Vessel (Payload/Upper Stage)
- At least one engine
- kOS processor (10000+ bytes storage recommended)
- Properly configured staging

### Recoverable Boosters (REQUIRED for recovery)
Each booster that you want to recover MUST have:
- ✅ **Probe core** (or command pod) - for control
- ✅ **kOS processor** (5000+ bytes storage)
- ✅ **At least one engine** (must be throttleable)
- ✅ **Landing legs**
- ✅ **Power source** (battery, RTG, or solar panels)
- ✅ **Reaction wheel or RCS** (for attitude control)

### Optional but Recommended
- **Airbrakes** - for descent control
- **RCS thrusters** - for precise steering
- **Grid fins** - for aerodynamic control
- **Multiple batteries** - for redundancy

## Usage

### Quick Start

1. **Build your rocket** with asparagus staging
2. **Add kOS processors** to each recoverable booster
3. **Load the launch script** on the main vessel:
   ```
   SWITCH TO 0.
   RUN launch.
   ```

That's it! The script handles everything automatically.

### Configuration

Edit the parameters at the top of `launch.ks`:

```kerboscript
// Orbital parameters
SET TARGET_APOAPSIS TO 100000.       // Target orbit altitude (meters)
SET TARGET_PERIAPSIS TO 100000.      // For circularization
SET TARGET_INCLINATION TO 0.         // 0° = equatorial, 90° = polar

// Ascent profile
SET TURN_START_ALTITUDE TO 100.      // When to begin gravity turn
SET TURN_END_ALTITUDE TO 45000.      // When to complete turn
SET TURN_SHAPE TO 0.5.               // Turn shape (0.4-0.6 typical)

// Staging
SET STAGE_FUEL_THRESHOLD TO 5.       // Stage at 5% fuel remaining
SET ENABLE_BOOSTER_RECOVERY TO TRUE. // Enable/disable recovery

// Landing zone (change for different launch sites)
SET LANDING_ZONE_LAT TO -0.0972.     // KSC latitude
SET LANDING_ZONE_LON TO -74.5577.    // KSC longitude
```

### Advanced Configuration

Edit `autoland_staging.ks` for booster landing parameters:

```kerboscript
SET SUICIDE_MARGIN TO 1.20.          // 20% safety margin (1.15-1.30)
SET BOOSTBACK_MAX_BURN_TIME TO 60.   // Max time for RTLS burn
SET LANDING_OFFSET_SPACING TO 10.    // Meters between boosters
```

## How It Works

### Launch Sequence

1. **Vertical Ascent** (0-100m): Full throttle vertical climb
2. **Gravity Turn** (100m-45km): Gradual pitch over following smooth curve
3. **Asparagus Staging**: Automatic staging when fuel <5%, triggers recovery on boosters
4. **Coast to Apoapsis**: Engines cut when target apoapsis reached
5. **Circularization**: Burn at apoapsis to achieve circular orbit

### Booster Recovery Sequence

Each booster independently executes:

1. **Post-Separation Coast** (2-3 sec): Clear from main rocket
2. **Flip Maneuver** (5-10 sec): Rotate to retrograde orientation
3. **Boostback Burn** (0-60 sec): Return to launch site trajectory
4. **Coast to Entry** (ballistic arc): Maintain retrograde, deploy airbrakes
5. **Entry Burn** (optional): If speed >800 m/s at 15km altitude
6. **Descent Phase**: Coast with airbrakes, continuously calculate suicide burn
7. **Suicide Burn**: Adaptive throttle to achieve soft touchdown
8. **Touchdown**: Land vertically at <2 m/s

### Booster Spacing

Boosters automatically space themselves:
- **Booster 1**: Lands 10m west of target
- **Booster 2**: Lands at target center (0m)
- **Booster 3**: Lands 10m east of target
- **Booster 4+**: Continue pattern with increasing spacing

## Tuning Guide

### If boosters land SHORT of target:
- Increase `BOOSTBACK_MAX_BURN_TIME` (try 90 seconds)
- Decrease `BOOSTBACK_TARGET_ERROR` (try 300m)

### If boosters land LONG (overshoot):
- Decrease `BOOSTBACK_MAX_BURN_TIME` (try 45 seconds)
- Increase `BOOSTBACK_TARGET_ERROR` (try 700m)

### If landing too HARD:
- Increase `SUICIDE_MARGIN` (try 1.25 or 1.30)
- Check TWR - needs to be >1.5 for safe landing

### If landing too SOFT (wasting fuel):
- Decrease `SUICIDE_MARGIN` (try 1.15)

### If gravity turn too AGGRESSIVE:
- Increase `TURN_END_ALTITUDE` (try 50000 or 55000)
- Increase `TURN_SHAPE` (try 0.6)

### If gravity turn too CONSERVATIVE:
- Decrease `TURN_END_ALTITUDE` (try 40000)
- Decrease `TURN_SHAPE` (try 0.4)

## Troubleshooting

### "No active engines!" error
- Verify engines are not disabled
- Check staging sequence
- Make sure throttle limiter is not at 0%

### Boosters don't attempt landing
- Check that `ENABLE_BOOSTER_RECOVERY` is TRUE
- Verify `autoland_staging.ks` exists in `Ships/Script/`
- Ensure boosters have probe cores AND kOS processors

### Flip maneuver fails
- Add more reaction wheels or RCS to boosters
- Increase `MAX_FLIP_TIME` in `autoland_staging.ks`
- Check that RCS has fuel

### Boostback burn doesn't reach KSC
- Increase `BOOSTBACK_MAX_BURN_TIME`
- Check booster fuel capacity
- Verify engines have sufficient thrust

### Suicide burn starts too late (crash)
- Increase `SUICIDE_MARGIN` (emergency: set to 1.50)
- Check TWR - may be too low
- Verify engines ignite properly

### Landing precision is poor (>50m error)
- Tune boostback parameters (see Tuning Guide above)
- Add RCS for lateral corrections
- Check for excessive crosswinds (rare on Kerbin)

### Vessel switching causes issues
- This is a known limitation of the current implementation
- The script requires brief vessel switching to activate booster scripts
- Future versions may use pre-loaded boot files to avoid this

## Performance Tips

- **TWR Recommendations:**
  - Main vessel during launch: 1.2-1.8 (initial)
  - Boosters for landing: >1.5 (required for suicide burn)

- **Fuel Planning:**
  - Reserve 20-30% of booster fuel for landing
  - Use asparagus staging to ensure outer boosters have landing fuel

- **Part Count:**
  - Keep booster part count reasonable (<100 parts each)
  - High part count may cause kOS lag during rapid updates

## Known Limitations

- **Simplified drag model**: May be inaccurate for complex shapes
- **No terrain avoidance**: Assumes flat KSC terrain
- **RTLS only**: No downrange (ASDS) landing mode yet
- **No collision avoidance**: Boosters don't communicate with each other
- **Vessel switching**: Brief interruption during staging

## Future Enhancements

- Downrange landing (drone ship/ASDS mode)
- Terrain radar and obstacle avoidance
- GUI telemetry displays
- Multi-engine landing burns (1-engine vs 3-engine mode)
- Pre-loaded boot files (no vessel switching)
- Inter-booster communication

## Example Missions

### Mission 1: Simple Two-Booster Launch
```
Rocket: "Ike I" (asparagus-staged)
Target: 100km equatorial orbit
Result: Main vessel in orbit, 2 boosters land at KSC
```

### Mission 2: High Orbit
```
Configuration:
  SET TARGET_APOAPSIS TO 250000.
  SET TURN_END_ALTITUDE TO 60000.
Result: Higher, more efficient ascent profile
```

### Mission 3: Polar Orbit
```
Configuration:
  SET TARGET_INCLINATION TO 90.
Result: Launches north/south for polar orbit
```

## Credits

Based on research from:
- [chippydip's suicide burn algorithm](https://gist.github.com/chippydip/75d67e902a3a88b9534fa809c3fe78b4)
- [Patrykz94's kOS-RTLS-Landing](https://github.com/Patrykz94/kOS-RTLS-Landing)
- kOS community documentation and examples

## License

Free to use and modify. Attribution appreciated.

## Support

For issues, questions, or improvements:
1. Check the Troubleshooting section above
2. Review your rocket design (especially TWR and fuel)
3. Enable kOS logging: Check `KSP.log` for errors
4. Experiment with tuning parameters

Happy launching! 🚀
