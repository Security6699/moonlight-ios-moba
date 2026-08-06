# Input model

## 1. Global invariants

1. Remote input is serialized through one dispatcher queue.
2. UI views never call Moonlight input APIs directly.
3. Pressed-key state is tracked; duplicate down/up transitions are suppressed.
4. The final cursor position is sent before the ability key-up.
5. Any interruption releases every tracked key and mouse button exactly once.
6. Touch input remains direct mapping only; no game-state inference or automation.

## 2. Joystick

The joystick produces an active set selected from W/A/S/D.

| Direction | Active keys |
|---|---|
| Center | none |
| Up | W |
| Up-right | W+D |
| Right | D |
| Down-right | S+D |
| Down | S |
| Down-left | S+A |
| Left | A |
| Up-left | W+A |

Default parameters:

- Dead zone ratio: 0.16.
- Direction hysteresis: 8 degrees.

On state change:

1. Send key-up for `old - new`.
2. Send key-down for `new - old`.

Example W+D -> D emits only W key-up.

## 3. Attack

Attack activates on touch-down and emits one key tap. Default host key C, tap duration 30 ms. No repeat while held. Timing must use dispatch scheduling, not blocking sleep.

## 4. Cast state machine

```text
Idle
  -> AimingDefault       touch begins
  -> AimingDragged       drag exceeds dead zone
  -> CancelArmed         touch enters cancel zone
  -> AimingDragged       touch exits cancel zone
  -> Committed           normal release
  -> Cancelled           release while CancelArmed
  -> Idle
```

States:

```objc
typedef NS_ENUM(NSInteger, MobaCastState) {
    MobaCastStateIdle,
    MobaCastStateAimingDefault,
    MobaCastStateAimingDragged,
    MobaCastStateCancelArmed,
    MobaCastStateCommitted,
    MobaCastStateCancelled
};
```

Each skill control tracks exactly one `UITouch`. One touch belongs to one control.

`MobaSkillButtonView` first converts UIKit locations to StreamView coordinates. Its UIKit-free `MobaSkillCastController` then owns the corresponding semantic token and one independent `MobaCastSession`. View code never calls Dispatcher or a concrete Strategy.

For an aimed skill update, orchestration computes exactly one displacement.

```text
displacement = currentStreamViewPoint - initialStreamViewPoint
```

Directional and Point updates receive this same displacement. The Cancel Zone evaluates the same current StreamView point before Session update. An accepted Session result is then consumed by the concrete Strategy and applied to Cancel Zone presentation. A Session/Strategy/Cancel Zone acceptance mismatch triggers unified Lifecycle cancellation.

Normal release produces one Session terminal outcome. Committed releases call Strategy commit. Only an intentional release from `CancelArmed` calls Strategy cancel. `touchesCancelled`, background, disconnect, orientation, profile reload and teardown never synthesize a configured cancel action. They use Lifecycle release-all followed by silent local reset.

## 5. Default aim

When an aimed skill is pressed without a meaningful drag:

- Angle is 270 degrees (screen-up).
- Directional skill uses its configured fixed range.
- Point skill uses `distanceRatio = 1.0` unless overridden in the champion profile.

Angle convention:

- 0 right.
- 90 down.
- 180 left.
- 270 up.

## 6. Asymmetric ellipse aiming

Range can differ left/right/up/down.

Given normalized drag direction `u = (ux, uy)`:

```text
rx = ux >= 0 ? rightPx : leftPx
ry = uy >= 0 ? downPx : upPx
```

The distance to the ray/ellipse intersection is:

```text
maxDistance = 1 / sqrt(ux^2/rx^2 + uy^2/ry^2)
```

Target:

```text
target = heroAnchor + u * maxDistance * distanceRatio
```

This preserves the finger's direction even when X and Y ranges differ. Clamp final target to X 0...2559 and Y 0...1439.

## 7. Drag distance response

For point casts:

```text
raw = dragDistance / wheelRadius
normalized = clamp((raw - deadzoneRatio) /
                   (fullRangeRatio - deadzoneRatio), 0, 1)
distanceRatio = pow(normalized, curveExponent)
```

Defaults:

- `deadzoneRatio`: 0.10.
- `fullRangeRatio`: 0.90.
- `curveExponent`: 1.25.

## 8. Strategy event ordering

### Instant

- Begin: capture touch.
- Commit: enqueue one configured key tap.
- Cancel/interruption: clear touch without activation.

### Directional

Begin:

1. Calculate default target.
2. Enqueue cursor move.
3. Enqueue ability key-down.

Update:

1. In `AimingDragged`, calculate the direction target and store it for display-link delivery.
2. In `AimingDefault`, restore the per-cast default target for display-link delivery without requiring a drag vector.
3. In `CancelArmed`, preserve the latest target and submit no cursor update.
4. After leaving the cancel zone, restore Default or recalculate Dragged according to the Session state.

Commit:

1. Stop coalescing and discard pending intermediate points.
2. Enqueue the final cursor point and ability key-up in the same serialized operation.

### Point/Ground

Same ordering as directional; target distance comes from the response curve.

### Point/Unit

Moves the cursor according to the configured mapping. It does not identify, snap to, or validate targets. League performs target validation.

## 9. Cursor scheduling

`touchesMoved` updates only `latestTargetPoint`. A `CADisplayLink` sends the latest unsent point at the selected 30/60/120 Hz rate. MVP default is 60 Hz.

Commit bypasses coalescing and enqueues final point + key-up atomically in order.

## 10. Cancellation

While aiming, entering the fixed cancel zone sets `CancelArmed` and changes visual state. Exiting returns to aiming.

On release inside the zone:

1. Enqueue configured cancel action.
2. Enqueue ability key-up.
3. End session.

Supported configuration values:

- Escape key tap (default).
- Right mouse click.
- No separate cancel input; only release ability key, for testing.

The state machine must not hard-code Escape.

## 11. Release-all conditions

Release all input on:

- `touchesCancelled`.
- App resign active/background.
- Stream disconnect/teardown.
- View controller disappearance.
- Battle -> UI/Edit/Tuning transitions.
- Orientation change.
- Champion/profile reload.
- MOBA feature disabled.

Release behavior:

- Stop display links.
- Release tracked W/A/S/D.
- Release tracked ability keys.
- Release tracked mouse buttons.
- Clear attack timers.
- Clear active touches and cast sessions.
- Reset all controls to Idle.

## 12. Multi-touch acceptance

At minimum, simultaneously support:

1. Movement joystick.
2. One aimed skill.
3. Attack or a separate action.

MOBA battle mode must prevent the third touch from activating Moonlight's native keyboard gesture.
