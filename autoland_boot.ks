// =========================================================================
// AUTOLAND BOOT STUB (autoland_boot.ks)
// =========================================================================
// Minimal boot file — kept small so it fits on the kOS processor's local
// volume (which cannot hold the full autoland_staging.ks).
// Copies itself to 0:/ (archive) then runs autoland_staging.ks from there.
// =========================================================================

@LAZYGLOBAL OFF.
SWITCH TO 0.
RUNPATH("0:/autoland_staging.ks").
