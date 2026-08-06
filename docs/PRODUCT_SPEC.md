# Product specification

## 1. Objective

Add an optional MOBA touch-control mode to Moonlight iOS so League of Legends running on a Windows Sunshine host can be played on an iPad with controls resembling League of Legends: Wild Rift.

The MVP is an input-remapping and streaming client feature. It must not inspect or automate game state.

## 2. Frozen platform scope

- Client: iPadOS only.
- First target: 13-inch iPad Pro (2025), landscape.
- Supported orientations: Landscape Left and Landscape Right.
- Required host and stream resolution: exactly 2560x1440.
- Video scaling: Aspect Fit only.
- Camera assumption: League locked camera.
- Controls may occupy the upper and lower black bars.
- MVP input update rate: 60 Hz; architecture must allow 30/60/120 Hz.

MOBA battle input must be blocked when the negotiated stream is not 2560x1440. UI mode and exiting the stream must remain available.

## 3. Host bindings

- Move up/left/down/right: W/A/S/D.
- On-screen Q ability -> host Q.
- On-screen W ability -> host E.
- On-screen E ability -> host R.
- On-screen R ability -> host T.
- Attack -> host C.
- Default cancel input -> Escape, configurable.

The on-screen labels remain Q/W/E/R and must not expose the remapped host letters.

## 4. Interaction modes

### Battle

MOBA controls capture game gestures. Native StreamView touch gestures are suppressed. Multi-touch must support movement, aiming, and attack/another action concurrently.

### UI

MOBA controls become non-interactive or visually reduced. Native Moonlight touch behavior is restored for shops, launcher UI, settings, and desktop interaction.

### Layout edit

No host input is sent. The user can modify position, visual size, hit-area scale, wheel radius, z-order, enabled state, and opacity.

### Skill tuning

The user can inspect and adjust hero anchor, skill ranges, dead zones, response curves, default aim, cancel behavior, and mouse update rate. It supports Preview Only and Live Cast.

## 5. Controls

### Movement

A left virtual joystick maps to eight-direction W/A/S/D states. It uses a configurable dead zone and direction hysteresis. Only state differences are transmitted.

### Attack

One attack button sends a single C key tap on touch-down. Holding must not repeat.

### Abilities

Four labeled ability controls support these top-level types:

1. Instant: no cursor target; one key tap on release.
2. Directional: drag selects direction; configured fixed game-space range.
3. Point/Ground: drag direction and distance select a ground point.
4. Point/Unit: drag moves the cursor to a visible unit; League validates the unit. No target detection or snapping.

For directional and point abilities, a touch with no meaningful drag uses a fixed default aim:

- Angle: 270 degrees, screen-up.
- Point-cast distance ratio: 1.0, maximum configured distance.

### Cancellation

The architecture includes `cancelState`. The MVP displays a fixed cancel zone while an aimed ability is active. Releasing inside it sends the configured cancel action and then releases the ability key. Escape is the initial default but remains configurable.

### Cursor after cast

The cursor remains at the final target point.

## 6. Layout and opacity

Each control has independently configurable:

- Safe-area normalized center X/Y.
- Visual width and height in UIKit points.
- Hit-area scale.
- Wheel radius in points where applicable.
- Base opacity.
- Pressed and disabled opacity.
- Z-index.
- Interaction enabled state.

A global opacity multiplier applies after per-control opacity. Zero opacity does not disable interaction; `interactionEnabled` controls hit testing.

Layout Edit works on a typed draft separated from immutable committed profiles. Move, Attack, Q/W/E/R, Cancel Zone, and the global multiplier preview immediately without sending gameplay input. Control centers are normalized to the StreamView safe area and may be placed in Aspect Fit black bars. Normal, Pressed, and Disabled opacity preview states are visual only.

Save validates a complete candidate before replacing the active layout and Runtime opacity. The two files are atomically replaced with rollback to their prior bytes on failure, then the current champion runtime and all four skill controls are rebuilt from the committed snapshot. Revert restores the editor baseline without disk access. Restore Defaults reads bundled resources and requires a later Save. Leaving Layout Edit discards unsaved changes.

## 7. Coordinate requirements

- All aiming and range values use a fixed 2560x1440 game canvas.
- All layout positions use safe-area normalized coordinates.
- Preview graphics transform game-canvas coordinates into the runtime Aspect Fit video rect.
- Skill range and control layout must never share one coordinate space.

## 8. Profiles

The MVP has four independently persisted configuration layers:

- Runtime profile: canvas, resolution, camera anchor, update rate.
- Input profile: host key codes and cancel input.
- Layout profile: control geometry, opacity, and UI behavior.
- Champion profile: cast type and calibrated range per ability.

The first champion is Caitlyn. Switching champions must replace champion behavior without replacing the user's layout.

## 9. Import/export

Use JSON with `schemaVersion`. The app supports document-picker import/export, validation, import preview, atomic replacement, and backup before import. Invalid input must not modify active configuration.

## 10. First champion

Caitlyn mapping:

- Q: directional.
- W: point/ground.
- E: directional.
- R: point/unit.

Caitlyn has no instant active skill. Instant behavior is tested with a debug champion profile.

## 11. Non-goals

- Android or iPhone support.
- Portrait or unlocked camera.
- Other stream resolutions.
- Target detection, target snapping, or target prioritization.
- Memory reading, process injection, image recognition, or Vanguard bypass.
- Auto-combos, repeated attack, auto-kiting, auto-last-hit, or macros.
- Automatic champion detection.

## 12. MVP acceptance

The MVP is accepted when:

1. MOBA mode is feature-gated and upstream behavior is preserved when disabled.
2. 2560x1440 absolute cursor diagnostics pass at nine reference points.
3. Eight-direction movement has no stuck keys.
4. Attack sends exactly one non-repeating action.
5. Caitlyn Q/W/E/R use their configured strategies.
6. Default no-drag casts aim upward; point casts use maximum distance.
7. Cancel-zone behavior is configurable and does not leave pressed keys.
8. Movement, aiming, and a third action can coexist.
9. Skill parameters and control opacity update live and persist.
10. Layout editing and JSON import/export function safely.
11. Backgrounding, disconnecting, mode changes, rotation, and profile reload release all inputs.
12. Unit and integration tests pass; real-device calibration items remain explicitly identified.
