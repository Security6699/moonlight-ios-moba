# Caitlyn profile

## 1. Purpose

Caitlyn is the first real champion used to validate the configurable casting engine. Her profile covers directional, ground point-cast, and unit point-cast behavior.

Caitlyn does not provide an instant active ability. Instant-cast support is validated with `debug-instant.json`.

## 2. Ability mapping

| On-screen ability | Host key | Strategy | Target mode |
|---|---:|---|---|
| Q | Q / 81 | Directional | fixed-range direction |
| W | E / 69 | Point | ground |
| E | R / 82 | Directional | fixed-range direction |
| R | T / 84 | Point | unit |

The host key mapping is required because W is reserved for movement.

## 3. Default aim

All aimed Caitlyn skills initially use:

- Default direction: screen-up, 270 degrees.
- Default point-cast distance: 1.0, configured maximum.
- Cursor remains at the target after cast.

These defaults are per-skill profile fields and may be tuned later without code changes.

## 4. Q: directional

Q reads direction only and places the cursor at the configured asymmetric-ellipse boundary.

Placeholder calibration:

```json
{
  "leftPx": 720,
  "rightPx": 720,
  "upPx": 480,
  "downPx": 480
}
```

Test eight primary directions, no-drag default aim, movement+cast, cancellation, and final-cursor ordering.

## 5. W: ground point-cast

W reads direction and drag magnitude. The maximum and minimum range components are live-tunable.

Placeholder maximum:

```json
{
  "maxLeftPx": 680,
  "maxRightPx": 680,
  "maxUpPx": 450,
  "maxDownPx": 450
}
```

Initial response:

```json
{
  "deadzoneRatio": 0.10,
  "fullRangeRatio": 0.90,
  "curveExponent": 1.25
}
```

Calibration must test near, middle, maximum, cardinal, and diagonal placements. The values above are not claimed to match real League range.

## 6. E: directional

E uses the direction in which the net is fired. The client must not invert input to compensate for Caitlyn's in-game recoil; recoil is game behavior.

Placeholder calibration:

```json
{
  "leftPx": 620,
  "rightPx": 620,
  "upPx": 420,
  "downPx": 420
}
```

## 7. R: unit point-cast

R moves the cursor to a visible enemy model and releases the configured key. It does not identify, prioritize, snap to, or validate targets.

Placeholder mapping extent:

```json
{
  "maxLeftPx": 1120,
  "maxRightPx": 1120,
  "maxUpPx": 620,
  "maxDownPx": 620
}
```

This mapping is a touch-to-screen cursor envelope, not Caitlyn's world-space ultimate range. League remains responsible for whether the cursor is over a legal target.

## 8. Parameters requiring real-device calibration

- Locked-camera hero anchor X/Y.
- Q left/right/up/down cursor extent.
- W minimum and maximum ranges.
- W dead zone, full-range point, and response exponent.
- E left/right/up/down cursor extent.
- R unit-selection cursor mapping.
- Cancel action type.
- Button position, size, hit area, wheel radius, and opacity.
- 60 vs 120 Hz input update feel.

## 9. Calibration rules

- Use League practice mode.
- Keep host and stream at 2560x1440.
- Keep camera locked.
- Calibrate on the target 13-inch iPad Pro.
- Change one parameter group at a time.
- Export the profile after each accepted calibration pass.
- Record measured values in the related calibration issue and PR.
