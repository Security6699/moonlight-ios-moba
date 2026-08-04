# Implementation plan

Each stage should be implemented through small GitHub issues and draft pull requests. Do not combine unrelated stages.

## Stage 1: scaffold and feature gate

Deliverables:

- `mobaControlsEnabled` setting using existing Moonlight settings patterns.
- `MobaOverlayCoordinator` lifecycle shell.
- Battle/UI mode shell.
- Resolution guard for exactly 2560x1440.
- Traditional on-screen controller disabled only while MOBA mode is active.

Acceptance: project builds; disabling MOBA preserves upstream behavior; no gameplay controls yet.

## Stage 2: geometry and input foundation

Deliverables:

- Fixed `MobaGameCanvas`.
- Aspect Fit video rect exposure for preview rendering.
- `MobaInputSink`, production adapter, fake adapter.
- Serialized dispatcher and pressed-input tracking.
- Nine-point absolute cursor diagnostics.
- Lifecycle `releaseAllInputs` foundation.
- Geometry and dispatcher tests.

Acceptance: nine-point cursor positioning can be tested; input ordering tests pass.

## Stage 3: movement and attack

Deliverables:

- Eight-direction joystick with dead zone and hysteresis.
- State-difference key transitions.
- Single non-repeating attack tap.
- Multi-touch ownership foundation.
- Battle/UI touch routing.

Acceptance: movement and attack work concurrently without stuck keys.

## Stage 4: casting engine

Deliverables:

- Cast session and state machine.
- Fixed cancel zone.
- Instant strategy.
- Directional strategy with asymmetric ellipse ray intersection.
- Point strategy with ground/unit modes and response curve.
- CADisplayLink cursor coalescing at 60 Hz.
- Atomic final-point + key-up commit ordering.

Acceptance: fake sink tests cover normal, cancel, and interruption paths.

## Stage 5: profiles and Caitlyn

Deliverables:

- Runtime, input, layout, and champion models.
- Store, validator, migrator, defaults.
- Bundled Caitlyn and debug-instant profiles.
- Manual champion selection shell.

Acceptance: examples load, invalid files fail safely, strategy factory configures Caitlyn Q/W/E/R.

## Stage 6: editors and tuning

Deliverables:

- Layout editor for position, size, hit area, wheel radius, z-index, enabled state, and opacity.
- Per-control plus global opacity.
- Skill tuning panel.
- Hero-anchor calibration.
- Aim preview overlay.
- Preview Only and Live Cast.

Acceptance: edits apply live, persist, and can be restored.

## Stage 7: import/export and documentation

Deliverables:

- JSON document picker.
- Validation summary, confirmation, backup, atomic import.
- Export active profiles.
- User/developer documentation updates.

Acceptance: round-trip and invalid-import tests pass.

## Stage 8: real-device calibration

Deliverables:

- Confirm nine-point mapping on target iPad/Windows host.
- Calibrate Caitlyn Q/W/E/R.
- Validate cancel action.
- Tune layout, hit areas, opacity, and 60/120 Hz preference.
- Full lifecycle and regression pass.

Acceptance: playable MVP criteria in `PRODUCT_SPEC.md` and `TEST_PLAN.md` are met.

## Required PR discipline

Each task:

1. References one issue.
2. Reads `AGENTS.md` and issue-linked docs.
3. Uses a dedicated branch.
4. States what is intentionally not implemented.
5. Includes validation results.
6. Marks real-device-only verification clearly.
7. Remains draft until reviewed.
