# Architecture

## 1. Integration strategy

Keep Sunshine, streaming, codecs, audio, pairing, and moonlight-common protocol code unchanged. Add an optional UIKit overlay and input interpretation layer to Moonlight iOS.

Primary upstream integration points:

- `Limelight/ViewControllers/StreamFrameViewController.m`: create and destroy the MOBA coordinator with the stream lifecycle.
- `Limelight/Input/StreamView.h/.m`: expose Aspect Fit video geometry and allow native touch routing to be enabled or disabled.
- Existing settings storage/controller files: add `mobaControlsEnabled` using established project patterns.

When disabled, the fork must behave like upstream Moonlight.

## 2. Proposed module tree

```text
Limelight/Input/MOBA/
├── Core/
│   ├── MobaOverlayCoordinator
│   ├── MobaInputSink
│   ├── MoonlightMobaInputAdapter
│   ├── MobaInputDispatcher
│   ├── MobaInputState
│   └── MobaDisplayGeometry
├── Controls/
│   ├── MobaOverlayView
│   ├── MoveJoystickView
│   ├── SkillButtonView
│   ├── AttackButtonView
│   ├── CancelZoneView
│   └── MobaToolbarView
├── Casting/
│   ├── MobaCastStrategy
│   ├── MobaCastStrategyFactory
│   ├── MobaCastSession
│   ├── MobaCastStateMachine
│   ├── InstantCastStrategy
│   ├── DirectionalCastStrategy
│   └── PointCastStrategy
├── Geometry/
│   ├── MobaGameCanvas
│   ├── MobaAimGeometry
│   └── MobaVideoGeometry
├── Profiles/
│   ├── MobaRuntimeProfile
│   ├── MobaInputProfile
│   ├── MobaLayoutProfile
│   ├── MobaChampionProfile
│   ├── MobaProfileStore
│   ├── MobaProfileValidator
│   └── MobaProfileMigrator
├── Editor/
│   ├── MobaLayoutEditorViewController
│   ├── MobaSkillTuningViewController
│   ├── MobaAnchorCalibrationViewController
│   └── MobaJSONDocumentController
└── Debug/
    ├── MobaAimPreviewView
    └── MobaInputDebugView
```

Objective-C, UIKit, Foundation, and XCTest are the default technologies. Do not add a second networking layer or Windows helper application.

## 3. Responsibilities

### MobaOverlayCoordinator

Owns overlay lifecycle, active mode, profile loading, child controls, notifications, and release-all behavior. It is the only object attached directly by the stream view controller.

The coordinator owns one `MobaOverlayLifecycle` state machine. Battle input is allowed only while the coordinator is running, the mode is Battle, the stream resolution is valid, and input is not suspended. An interruption synchronously suspends Battle input and disables local interaction before it enqueues dispatcher release-all. It then resets every registered local interaction participant. Repeated interruption calls while already suspended do not release or reset again.

Local interaction reset participants must cancel owned touches, invalidate timers and display links, clear cast or session state, and remove visual pressed state. The DEBUG cursor diagnostic panel uses the same participant boundary. The dispatcher remains the only pressed-key and pressed-button owner. Sink and production adapter implementations remain stateless.

### MobaOverlayView

Hosts controls and manages hit testing by mode. It does not send remote input directly.

### MobaInputSink

Abstract interface for keyboard, cursor, and mouse-button actions. This permits a debug/test sink.

### MoonlightMobaInputAdapter

Translates abstract actions into existing Moonlight calls. Game-canvas points are clamped and sent with 2560x1440 reference dimensions.

### MobaInputDispatcher

Serializes all remote input, tracks pressed keys/buttons, prevents duplicate transitions, coalesces cursor movement, commits final cursor+key-up atomically in order, and releases all tracked state.

### Controls

UIKit views own visual state and one active `UITouch`. Controls emit semantic gestures to the coordinator or cast strategy; they do not contain champion-specific logic.

### Cast strategies

Interpret begin/update/commit/cancel according to the selected ability profile. New future strategies must be addable without changing `SkillButtonView`.

### Profiles

Load validated, versioned configuration. Layout, runtime, input, and champion behavior remain separate.

## 4. Coordinate spaces

### Game canvas

Fixed 2560x1440 integer-like coordinates, origin top-left. Used for hero anchor, skill range, cursor targets, diagnostics, and champion calibration.

`MobaGameCanvas` accepts only finite game-space coordinates. It clamps X to 0...2559 and Y to 0...1439 before conversion to the integer values required by moonlight-common. Fractional parts are discarded toward zero after clamping. Non-finite coordinates are rejected and no input event is sent. This conversion never uses StreamView bounds, safe areas, videoRect, or device screen dimensions.

### View space

UIKit points in the stream view/controller hierarchy. Used only for rendering and local touch locations.

### Layout space

Safe-area normalized center coordinates plus point dimensions. Used for persistent control layout.

### Video rect

Runtime Aspect Fit rectangle derived from StreamView bounds and stream aspect ratio. Used to render game-space previews, not to store skill ranges.

## 5. Input adapter contract

```objc
@protocol MobaInputSink <NSObject>
- (void)setKeyCode:(uint16_t)keyCode down:(BOOL)down;
- (void)moveCursorToCanvasPoint:(CGPoint)point;
- (void)sendMouseButton:(int)button down:(BOOL)down;
@end
```

The production adapter should call the existing Moonlight input APIs. A sink sends only individual stateless input actions and must not maintain another pressed-key or pressed-button collection.

`MoonlightMobaInputAdapter` uses the existing `KeyboardSupport` Win32 VK convention of `0x8000 | keyCode`, with `KEY_ACTION_DOWN` or `KEY_ACTION_UP` and zero modifiers. Mouse buttons use `LiSendMouseButtonEvent` with `BUTTON_ACTION_PRESS` or `BUTTON_ACTION_RELEASE`. Absolute cursor events use `LiSendMousePositionEvent` after `MobaGameCanvas` validation, always with reference width 2560 and reference height 1440. A thin stateless sender is the only layer that calls these moonlight-common functions.

The dispatcher is the only input state owner. It owns pressed-key and pressed-button tracking, duplicate transition suppression, tap timing, event ordering, and release-all behavior. Release-all invalidates pending tap timers, clears dispatcher state, and expands every tracked input into one concrete key-up or mouse-up. Each tracked state is released at most once. UI code must not call the Moonlight input APIs directly.

The debug nine-point panel submits only the fixed canvas points documented in the test plan. It calls `MobaCursorDiagnostics`, which checks the coordinator's `battleInputAllowed` gate and then submits the point to `MobaInputDispatcher`. The panel is compiled into the DEBUG diagnostic path and is attached only by a running MOBA coordinator. It never calls the adapter or moonlight-common directly.

## 6. Modes and hit testing

- Battle: controls and a transparent game-area shield consume gameplay touches; native StreamView gestures are disabled.
- UI: overlay controls are reduced/noninteractive and native StreamView interaction is enabled.
- Layout Edit: remote input is disabled; handles edit control properties.
- Skill Tuning: preview or live-cast behavior with explicit controls.

Mode transitions always release remote input before changing hit testing.

## 7. Lifecycle

Coordinator receives app background/inactive, stream teardown, controller disappearance, and orientation callbacks through the existing `StreamFrameViewController` lifecycle. It also exposes profile reload and feature-toggle interruption entries for their future owners. Every such transition calls `releaseAllInputs`, cancels active touches/casts, and invalidates display links.

All paths converge on `interruptAndReleaseInputsForReason:`. The ordered boundary is suspend input, disable diagnostics and local interaction, enqueue dispatcher release-all, then reset local participants. Release-all expands tracked state into concrete key-up and mouse-up events exactly once and invalidates pending tap tokens.

App-active, orientation-complete, and profile-reloaded callbacks may clear suspension only when the stream remains connected, the coordinator remains running, the mode is Battle, and the resolution remains exactly 2560x1440. Recovery never recreates a pressed input or cancelled timer. Stop, stream teardown, controller disappearance, destruction, and feature disable remain suspended and restore traditional on-screen controls.

## 8. Extension path

Future champion support adds JSON profiles, not new UI classes. Future cast types add a new strategy and schema enum. Future device layouts add layout profiles. The fixed game canvas remains independent from device geometry.
