# KSP Launch & Booster Recovery System

A comprehensive kOS autopilot system for Kerbal Space Program featuring automated gravity turn launches and SpaceX-style booster recovery.

## Features

- 🚀 **Automated Gravity Turn** - Smooth, efficient ascent to orbit
- 🎯 **Asparagus Staging** - Automatic fuel monitoring and staging
- 🛬 **RTLS Booster Recovery** - SpaceX-style return-to-launch-site landing
- 🎮 **Full Autonomy** - Set it and forget it
- 📊 **Multi-Booster Support** - Handles multiple boosters with automatic spacing

## Quick Start

1. Load your rocket on the launchpad
2. Open kOS terminal
3. Stage once to activate engines
4. Run: `RUN 0:/launch.`

## System Architecture

### Main Scripts
- `launch.ks` - Main launch autopilot (runs on main vessel)
- `autoland_staging.ks` - Booster landing autopilot (runs on each booster)

### Libraries
- `lib/util.ks` - Utilities, math, LATLNG functions
- `lib/guidance.ks` - Trajectory prediction & impact calculation
- `lib/ascent.ks` - Gravity turn & staging logic
- `lib/circularize.ks` - Orbital circularization
- `lib/boostback.ks` - RTLS boostback guidance
- `lib/entry.ks` - Entry burn & descent control
- `lib/landing.ks` - Suicide burn & touchdown

### Testing
- `test_system_logged.ks` - Comprehensive system test with file logging
- `test_debug.ks` - Debug script for troubleshooting

## Requirements

### Main Vessel
- kOS processor (10000+ bytes recommended)
- Proper staging configuration

### Recoverable Boosters
Each booster must have:
- ✅ Probe core or command pod
- ✅ kOS processor (5000+ bytes)
- ✅ At least one throttleable engine
- ✅ Landing legs
- ✅ Power source (battery/RTG)
- ✅ Reaction wheel or RCS

### Optional (Recommended)
- Airbrakes for descent control
- RCS thrusters for precise steering
- Grid fins

## Configuration

Edit parameters at the top of `launch.ks`:

```kerboscript
SET TARGET_APOAPSIS TO 100000.       // Target orbit (meters)
SET TURN_START_ALTITUDE TO 100.      // Start gravity turn
SET TURN_END_ALTITUDE TO 45000.      // Complete turn
SET TURN_SHAPE TO 0.5.               // Turn profile (0.4-0.6)
SET STAGE_FUEL_THRESHOLD TO 5.       // Stage at 5% fuel
```

Edit booster landing parameters in `autoland_staging.ks`:

```kerboscript
SET SUICIDE_MARGIN TO 1.20.          // 20% safety margin
SET BOOSTBACK_MAX_BURN_TIME TO 60.   // Max RTLS burn time
SET LANDING_OFFSET_SPACING TO 10.    // Booster separation (meters)
```

## How It Works

### Launch Sequence
1. **Vertical Ascent** (0-100m) - Full throttle climb
2. **Gravity Turn** (100m-45km) - Gradual pitch over
3. **Asparagus Staging** - Automatic when fuel <5%
4. **Coast to Apoapsis** - Engines cut at target altitude
5. **Circularization** - Burn at apoapsis for circular orbit

### Booster Recovery Sequence
Each booster independently executes:
1. **Post-Separation Coast** (2-3s) - Clear main rocket
2. **Flip Maneuver** (5-10s) - Rotate to retrograde
3. **Boostback Burn** (0-60s) - Return to KSC trajectory
4. **Coast to Entry** - Ballistic arc with airbrakes
5. **Entry Burn** (optional) - If speed >800 m/s at 15km
6. **Descent** - Retrograde orientation, calculate suicide burn
7. **Suicide Burn** - Adaptive throttle for soft touchdown
8. **Touchdown** - Land at <2 m/s vertical speed

### Booster Spacing
Boosters automatically space themselves:
- **Booster 1**: -10m west of target
- **Booster 2**: Center (0m)
- **Booster 3**: +10m east of target
- **Booster 4+**: Pattern continues

## Testing

Run the system test before first launch:

```kerboscript
RUN 0:/test_system_logged.
```

Check `test_results.txt` for detailed output.

## Troubleshooting

### Boosters land short of target
- Increase `BOOSTBACK_MAX_BURN_TIME` (try 90)
- Decrease `BOOSTBACK_TARGET_ERROR` (try 300)

### Boosters land long (overshoot)
- Decrease `BOOSTBACK_MAX_BURN_TIME` (try 45)
- Increase `BOOSTBACK_TARGET_ERROR` (try 700)

### Landing too hard
- Increase `SUICIDE_MARGIN` (try 1.25-1.30)
- Check TWR >1.5 required for safe landing

### Landing too soft (wasting fuel)
- Decrease `SUICIDE_MARGIN` (try 1.15)

### Gravity turn too aggressive
- Increase `TURN_END_ALTITUDE` (try 50000-55000)
- Increase `TURN_SHAPE` (try 0.6)

## Reference Documentation

- `KERBOSCRIPT_REFERENCE.md` - Complete kOS language reference
- `README_LAUNCH_SYSTEM.md` - Detailed system documentation

## Credits

Based on research from:
- [chippydip's suicide burn algorithm](https://gist.github.com/chippydip/75d67e902a3a88b9534fa809c3fe78b4)
- [Patrykz94's kOS-RTLS-Landing](https://github.com/Patrykz94/kOS-RTLS-Landing)
- kOS community documentation

## Version

**KSP Version:** 1.12.5
**kOS Version:** 1.4.0+
**Last Updated:** 2025-03-22

## License

Free to use and modify. Attribution appreciated.

Happy launching! 🚀
