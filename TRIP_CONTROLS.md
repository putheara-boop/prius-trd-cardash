# Trip controls

The trip screen has separate **START**, **RESET**, and **PAUSE** buttons, plus HOME.

- Automatic GPS tracking remains the default for existing trips.
- START resumes automatic tracking without clearing distance, moving time, or maximum speed. Repeated START presses do not break a moving segment.
- PAUSE holds tracking even if the vehicle keeps moving. The paused setting survives app restart until START is pressed.
- RESET asks for confirmation, clears totals, and preserves whether tracking was manually paused.
- START does not invent distance while stopped or without reliable GPS; the existing motion thresholds and GPS quality checks still apply.

`TRDTrip.h` and `TRDTripView.h` are included because the entry points already import them, but they were missing from the repository. Their automatic-GPS baseline comes from the previously deployed source, with the manual controls added here.

## Validation

On a Mac with Xcode Command Line Tools, run from the repository root:

```sh
xcrun clang -fobjc-arc -fblocks -O1 -framework Foundation -framework CoreLocation tests/TripControlsTests.m -o /tmp/trd-trip-controls-tests
/tmp/trd-trip-controls-tests
```

The tests use isolated synthetic CLLocation samples and do not access or overwrite the user's trip preferences. They cover motion/stop/resume, quality gaps, duplicate fixes, legacy summaries, manual pause persistence, and cumulative START resume.

Before deployment, copy the updated trip headers and chosen main entry point to the existing iPad build directory, then build with the project's ARMv7 toolchain. Other supporting headers and the SDK are still supplied by that existing environment. This change has not yet been built or installed on the iPad.
