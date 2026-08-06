# Test plan

## 1. Test layers

- Windows or other non-Xcode static checks: formatting, JSON, XML, PBX references, and source-level assertions. These checks do not prove that the iOS project compiles.
- GitHub Actions macOS validation: real Xcode project discovery and unsigned generic iOS compilation on every pull request targeting `master`.
- Unit tests for geometry, state machines, profile validation, joystick transitions, and input ordering.
- Integration tests with a fake `MobaInputSink`.
- Manual Windows cursor diagnostics.
- Real-device gameplay validation on the target iPad.

## 2. Required unit test groups

### MobaGameCanvasTests

- Clamp (-1,-1) -> (0,0).
- Clamp (3000,2000) -> (2559,1439).
- Preserve valid center (1280,720).

### MobaAimGeometryTests

- 270-degree default target is above anchor.
- Cardinal and diagonal ray/ellipse intersections.
- Asymmetric left/right and up/down ranges.
- Output ray direction matches drag direction.
- Zero or invalid radii are rejected by validation.

### MobaPointResponseTests

- Dead-zone input returns zero distance.
- Full-range input returns one.
- Exponent 1 is linear.
- Exponents above/below one produce expected monotonic behavior.

### MobaJoystickTests

- All eight directions.
- Dead zone.
- Hysteresis near boundaries.
- W+D -> D emits only W up.
- Release/cancel emits all necessary key-up events once.

### MobaCastStateMachineTests

- Idle -> default -> dragged -> committed.
- Enter/exit cancel zone.
- Cancelled release.
- Touch cancellation.
- Repeated begin while active is rejected.

### MobaSkillCastOrchestrationTests

- Independent Session and semantic token ownership for Q, W, E and R.
- Battle gate, Session, Cancel Zone and Strategy begin ordering.
- Transactional rollback when Cancel Zone or Strategy begin fails.
- One current-minus-initial StreamView displacement for Directional and Point updates.
- The final release endpoint is consumed as a semantic update before terminal release, including dead-zone and Cancel Zone transitions.
- Final endpoint failure requests Lifecycle cancellation and cannot commit an earlier target.
- Accepted Session update mismatch escalates to Lifecycle cancellation.
- Intentional `CancelArmed` release is the only configured Strategy cancel path.
- Final cursor remains ordered before skill key-up through Strategy and Dispatcher.
- UIKit cancellation and Lifecycle reset release tracked input once, silently clear local state and emit no Escape or mouse action.
- UI hides skill controls. Layout Edit and Skill Tuning show disabled controls without gameplay input.
- Profile-driven size, hit area, opacity, z-index, label and interaction behavior.
- Candidate Q/W/E/R package failure preserves snapshot, runtime, selection, installed Views and participant registrations.
- Successful Champion replacement installs one prebuilt package and swaps View participants once.
- Factory assembly rejects missing, nonfinite or nonpositive aimed-skill wheel radius while Instant skills may omit it.
- Semantic View tests use object tokens and pre-converted points instead of private `UITouch` construction.

### MobaInputDispatcherTests

- Duplicate key-down/up suppression.
- Final mouse position precedes skill key-up.
- Cancel action precedes skill key-up.
- Key tap uses scheduled up without blocking.
- `releaseAllInputs` releases all tracked state exactly once.

### MobaProfileValidatorTests

- Valid bundled examples load.
- Invalid canvas, opacity, coordinates, ranges, and enums report JSON paths.
- Minimum range greater than maximum is rejected.
- Unknown fields are tolerated.
- Unsupported schema versions use migrator or fail safely.

## 3. Nine-point cursor diagnostics

Provide a developer panel that sends these game-canvas points:

```text
(0,0)       (1280,0)       (2559,0)
(0,720)     (1280,720)     (2559,720)
(0,1439)    (1280,1439)    (2559,1439)
```

Verify on the Windows host:

- No offset from Aspect Fit black bars.
- No X/Y stretch.
- Correct center.
- No Windows DPI or multi-monitor offset.

Do not continue to ability calibration until this passes.

## 4. Lifecycle tests

For each condition, hold movement and/or an ability, trigger the condition, and verify no host key remains pressed:

- App resign active.
- Open Control Center.
- Background app.
- Stream disconnect.
- Leave stream controller.
- Rotate between landscape orientations.
- Switch Battle -> UI/Edit/Tuning.
- Reload champion or input profile.
- Disable MOBA setting.

## 5. Multi-touch tests

Simultaneously:

1. Hold movement.
2. Drag an aimed skill.
3. Tap attack or another control.

Verify no touch ownership transfer, no native keyboard gesture, no dropped movement, and correct cast ordering.

## 6. Caitlyn manual tests

### Q

- Eight directions.
- No-drag upward cast.
- Movement while casting.
- Cancel-zone release.
- Final cursor remains at target.

### W

- Near, mid, and maximum placement.
- Four cardinal and four diagonal directions.
- Live range/curve changes apply without restart.
- No-drag upward maximum placement.

### E

- Eight directions.
- Client does not invert direction for recoil.
- Movement and cancel behavior.

### R

- Drag cursor onto a visible enemy champion.
- Legal target succeeds through League behavior.
- Invalid target does not trigger automatic fallback.
- No target detection or snapping is visible.

### Attack

- One press -> one C tap.
- Hold does not repeat.
- Works while moving.
- Does not steal active skill touch.

## 7. Layout and opacity

- Move and resize each control.
- Adjust per-control and global opacity.
- Confirm opacity zero does not disable hit testing.
- Disable interaction explicitly and verify no hit.
- Persist, restart, and reload.
- Switch landscape directions and verify safe-area placement.
- Restore defaults.

## 8. JSON import/export

- Export each profile type.
- Re-import exported files.
- Reject malformed and invalid files without changing active configuration.
- Confirm backup creation before successful replacement.
- Confirm field-specific error messages.

## 9. Build and CI validation

Before every PR completion, run locally where the environment supports it:

```bash
git diff --check
xcodebuild -list -project Moonlight.xcodeproj
xcodebuild \
  -project Moonlight.xcodeproj \
  -scheme <actual-scheme> \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

When Xcode is not installed, run the available static checks, report the limitation, and do not claim compilation success. Push the branch so the `iOS Build` GitHub Actions workflow can perform the required macOS/Xcode build.

Every code PR targeting `master` must pass `iOS Build` before merge. CI failures must be fixed on the same task branch and PR unless the failure is confirmed to be unrelated infrastructure breakage.

Run relevant XCTest targets when introduced. A successful compile does not replace XCTest, and neither CI nor XCTest replaces target-iPad touch, lifecycle, latency, layout, or game-calibration testing.

## 10. MVP exit criteria

All automated tests pass; nine-point diagnostics pass; no lifecycle stuck keys; Caitlyn strategies behave as configured; layout/opacity and import/export persist; unresolved items are limited to documented calibration values rather than architecture defects.
