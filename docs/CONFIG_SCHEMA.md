# Configuration schema

All files use UTF-8 JSON and include `schemaVersion`. Active files are stored under `Application Support/MOBA/`; user import/export uses the system document picker.

## 1. Storage layout

```text
Application Support/MOBA/
├── runtime.json
├── input.json
├── active-layout.json
├── layouts/
├── champions/
└── backups/
```

Writes must be atomic. Import validates first, backs up active state, then replaces. Failed import leaves existing configuration unchanged.

## 2. Runtime profile

```json
{
  "schemaVersion": 1,
  "canvas": { "width": 2560, "height": 1440 },
  "requiredStreamResolution": { "width": 2560, "height": 1440 },
  "videoMode": "aspectFit",
  "camera": {
    "mode": "locked",
    "heroAnchorPx": { "x": 1280, "y": 720 }
  },
  "mouseUpdateRateHz": 60,
  "globalOpacityMultiplier": 1.0
}
```

Validation:

- Canvas and required stream must be 2560x1440 in schema v1.
- Video mode must be `aspectFit`.
- Anchor must be inside the canvas.
- Update rate must be one of 30, 60, 120.
- Opacity multiplier must be 0...1.

## 3. Input profile

```json
{
  "schemaVersion": 1,
  "profileId": "lol-wasd-default",
  "movement": {
    "up": 87,
    "left": 65,
    "down": 83,
    "right": 68
  },
  "actions": {
    "ability1": 81,
    "ability2": 69,
    "ability3": 82,
    "ability4": 84,
    "attack": 67
  },
  "attackTapDurationMs": 30,
  "cancelCastAction": {
    "type": "keyboard",
    "keyCode": 27,
    "cancelBeforeSkillKeyUp": true
  }
}
```

Cancel types: `keyboard`, `rightMouse`, `releaseOnly`.

## 4. Layout profile

Layout positions are relative to `safeAreaLayoutFrame`; sizes are UIKit points.

```json
{
  "schemaVersion": 1,
  "layoutId": "ipad-pro-13-default",
  "deviceClass": "ipad-pro-13-landscape",
  "controls": {
    "move": {
      "centerX": 0.14,
      "centerY": 0.82,
      "visualWidthPt": 190,
      "visualHeightPt": 190,
      "hitAreaScale": 1.20,
      "wheelRadiusPt": 95,
      "opacity": 0.66,
      "pressedOpacity": 0.82,
      "disabledOpacity": 0.30,
      "zIndex": 10,
      "interactionEnabled": true
    }
  },
  "cancelZone": {
    "centerX": 0.83,
    "centerY": 0.48,
    "diameterPt": 112,
    "activationInsetPt": 8,
    "opacity": 0.58,
    "visibleOnlyWhileCasting": true
  }
}
```

Per-control validation:

- `centerX/Y`: 0...1.
- Point dimensions: 24...600.
- `hitAreaScale`: 0.5...3.0.
- `wheelRadiusPt`: 40...400 when applicable.
- Opacity fields: 0...1.
- Zero opacity does not disable interaction.

## 5. Champion profile

```json
{
  "schemaVersion": 1,
  "championId": "caitlyn",
  "displayName": "Caitlyn",
  "displayNameZhCN": "皮城女警 凯特琳",
  "skills": {
    "Q": {
      "inputAction": "ability1",
      "castType": "directional",
      "defaultAim": { "angleDeg": 270, "distanceRatio": 1.0 },
      "range": {
        "model": "asymmetricEllipse",
        "leftPx": 720,
        "rightPx": 720,
        "upPx": 480,
        "downPx": 480
      },
      "touchResponse": { "deadzoneRatio": 0.10 },
      "allowCancel": true
    }
  }
}
```

Supported cast types in v1:

- `instant`.
- `directional`.
- `point` with `targetMode` = `ground` or `unit`.

`calibrationStatus` is optional non-empty metadata. Its absence is valid in schema v1.

All example skill ranges are calibration placeholders.

## 6. Point range

```json
{
  "model": "asymmetricEllipse",
  "minLeftPx": 0,
  "minRightPx": 0,
  "minUpPx": 0,
  "minDownPx": 0,
  "maxLeftPx": 680,
  "maxRightPx": 680,
  "maxUpPx": 450,
  "maxDownPx": 450
}
```

Response:

```json
{
  "deadzoneRatio": 0.10,
  "fullRangeRatio": 0.90,
  "curveExponent": 1.25
}
```

Validation:

- Ratios: dead zone 0...0.5, full range 0.5...1.5.
- Exponent: 0.25...4.0.
- Range values: 0...2560; actual target is clamped to canvas.
- Minimum values may not exceed corresponding maximum values.

## 7. Layout editor persistence

Schema v1 layout editing changes only the existing control and cancel-zone fields documented above. Control centers remain safe-area normalized values and may place controls over Aspect Fit black bars. `zIndex` remains a strict platform integer. Editor forward/back controls use overflow-safe increments and do not introduce a narrower schema range.

For Cancel Zone, `activationInsetPt` is non-negative and strictly smaller than half of `diameterPt`. Opacity values and Runtime `globalOpacityMultiplier` remain in 0...1. Effective gameplay opacity is the current per-state opacity multiplied by the Runtime global multiplier. A value of zero does not imply `interactionEnabled = false`.

Saving starts from deep copies of the current raw JSON dictionaries and patches only managed paths. `schemaVersion`, `layoutId`, `deviceClass`, unknown root or nested fields, and future controls are retained. Restore Defaults reads the bundled runtime and layout resources but does not persist until Save.

## 8. Skill tuning persistence

Skill Tuning does not change schema v1. It patches only `camera.heroAnchorPx.x`, `camera.heroAnchorPx.y`, `mouseUpdateRateHz` and the existing managed fields of the selected champion skill. Runtime anchor values remain fixed 2560×1440 game-space pixels. The update rate remains the strict enum 30, 60 or 120.

Directional and Point ranges remain game-space pixels. Default aim, response and `allowCancel` retain their existing types and validation ranges. Instant skills do not gain range, response or default-aim fields. Saving begins from private deep mutable copies and preserves schema metadata, calibration metadata, unknown root and nested fields, future skill fields and every unedited skill. Input and Layout bytes are outside this transaction.

Restore Defaults pairs the bundled Runtime with the bundled resource for the currently selected champion. Missing champion defaults are an error and never substitute another champion's values.

## 9. Migration

`MobaProfileMigrator` upgrades older schema versions before model creation. Unknown fields are ignored for forward tolerance. Unknown enum values are rejected with a field-specific error. Breaking changes increment `schemaVersion` and require tests.

## 10. Import result

Import UI must show:

- File type detected.
- Schema version.
- Profile ID/champion/layout name.
- Validation errors with JSON path.
- Summary of values that will replace active state.

The user explicitly confirms before applying.
