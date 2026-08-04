# AGENTS.md

## Required reading

Before modifying code, read:

- `docs/PRODUCT_SPEC.md`
- `docs/ARCHITECTURE.md`
- `docs/INPUT_MODEL.md`
- `docs/CONFIG_SCHEMA.md`
- `docs/TEST_PLAN.md`
- `docs/IMPLEMENTATION_PLAN.md`

For Caitlyn-specific work, also read `docs/CAITLYN_PROFILE.md`.

## Scope rules

- Implement only the assigned GitHub issue.
- Keep all MOBA functionality behind `mobaControlsEnabled`.
- Do not modify Sunshine or the moonlight-common protocol implementation.
- Do not add Android, iPhone, portrait, non-2560x1440, unlocked-camera, or automatic targeting support.
- Do not read League of Legends process memory, inject code, perform image recognition, implement macros, auto-combos, auto-aim, auto-attack repetition, or Vanguard bypasses.
- Preserve upstream Moonlight behavior when MOBA mode is disabled.
- Use Objective-C, UIKit, Foundation, and XCTest unless an issue explicitly authorizes otherwise.
- Do not add third-party dependencies without an explicit issue decision.
- Never commit directly to `master`. Use one branch and one draft PR per issue.

## Validation

Before completing a task:

1. Run `git diff --check`.
2. Run `xcodebuild -list -project Moonlight.xcodeproj`.
3. Use an actual listed scheme for an unsigned generic iOS build:

```bash
xcodebuild \
  -project Moonlight.xcodeproj \
  -scheme <actual-scheme> \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

4. Run relevant XCTest targets when available.
5. Report changed files, commands run, results, limitations, and parameters requiring iPad calibration.

## Input correctness

- All remote input must pass through one serialized dispatcher.
- Final mouse position must be enqueued before skill key-up.
- Track pressed keys and release them exactly once.
- Call `releaseAllInputs` on cancellation, backgrounding, disconnect, mode changes, rotation, profile reload, and controller teardown.
- One touch gesture must map to direct, explainable keyboard or mouse input.

## Configuration

- Game-space aiming values use the fixed 2560x1440 canvas.
- UI layout values use safe-area normalized coordinates plus point sizes.
- Do not hard-code Caitlyn calibration values in implementation classes; load them from champion profiles.
- Preserve `schemaVersion` and use migrations for breaking configuration changes.
