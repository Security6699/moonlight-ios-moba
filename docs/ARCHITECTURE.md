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
│   ├── MobaSkillButtonView
│   ├── MobaSkillCastController
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

Serializes all remote input, tracks pressed keys/buttons, prevents duplicate transitions, commits final cursor+key-up atomically in order, and releases all tracked state.

### Controls

UIKit views own visual state and one active `UITouch`. Controls emit semantic gestures to a UIKit-free controller. They do not contain champion-specific logic.

`MobaSkillButtonView` converts its one owned UIKit touch to StreamView coordinates before forwarding semantic begin, update, release, or cancellation calls. It never imports Dispatcher or a concrete Strategy. `MobaSkillCastController` owns one immutable runtime descriptor, one independent `MobaCastSession`, semantic token identity, the initial StreamView point, the latest StreamView point, and local pressed state. It owns neither `UITouch` nor `UIView`.

The production call chain is fixed.

```text
MobaSkillButtonView
→ MobaSkillCastController
→ MobaCastSession
→ concrete Strategy
→ MobaCursorCoalescer / MobaCancelZoneController
→ MobaInputDispatcher
```

Begin checks the Battle gate, begins Session ownership, begins the shared Cancel Zone only for aimed cancel-enabled skills, then begins the Strategy. Strategy begin preserves its own cursor-before-key ordering. Any partial begin failure silently resets Strategy and Session, ends the owned Cancel Zone presentation, clears local ownership and requests the unified Lifecycle touch-cancellation boundary.

Update computes one current-minus-initial displacement in StreamView coordinates. Directional and Point strategies consume that same displacement, while Point derives both direction and distance from it. The meaningful threshold uses the layout wheel radius and profile touch-response deadzone. Directional profiles without touch response use the named centralized fallback `MobaDirectionalMeaningfulDragDeadzoneRatio`, currently 0.10. After geometry evaluation, Session remains the only cast-state authority. If an accepted Session update is rejected by Strategy or cannot be applied to the Cancel Zone, orchestration requests Lifecycle cancellation rather than leaving split state.

Normal release first validates and consumes the final StreamView endpoint through the same semantic update path used by `touchesMoved`. This recalculates displacement, meaningful drag, Cancel Zone membership, Session active state and the Strategy target before Session produces its sole terminal outcome. A final update mismatch requests Lifecycle cancellation and cannot commit a stale target or invoke intentional cancel input. Committed outcomes call Strategy commit. Only an intentional release whose final accepted state is `CancelArmed` calls Strategy cancel. UIKit `touchesCancelled` and Lifecycle interruptions never call configured cancel actions. They close the Battle gate, enqueue Dispatcher release-all, and silently reset the View, Controller, Session, Strategy, Coalescer and Cancel Zone presentation.

### MobaCastStateMachine

Owns only the transitions between Idle, AimingDefault, AimingDragged, CancelArmed, Committed, and Cancelled. It accepts semantic booleans rather than view or canvas geometry and returns an explicit transition result containing acceptance, previous state, current state, and terminal outcome.

### MobaCastSession

Owns one cast state machine and one active interaction token for a future skill instance. Ownership uses object identity, never transfers during an active session, and is cleared on commit, cancellation, interruption, or silent reset. Lifecycle interruption changes an active session to Cancelled. A later silent reset returns local state to Idle without calling Dispatcher or emitting another input action.

### Cast strategies

Interpret accepted session begin/update/commit/cancel results according to the selected ability profile and own the corresponding remote-input semantics. New future strategies must be addable without changing `SkillButtonView` or the cast state machine. All strategy output must still pass through `MobaInputDispatcher`, which remains the only pressed-input state owner.

`MobaInstantCastStrategy` sends no input on begin or update. It enqueues one configured key tap only when it consumes an accepted committed terminal result. Cancellation and lifecycle interruption never activate the instant skill.

`MobaDirectionalCastStrategy` calculates and retains its configured default target for each cast with `MobaAimGeometry`. Begin starts its optional coalescer, submits that cursor point, then submits the configured skill key-down. An accepted `AimingDragged` update replaces the strategy's latest target and submits it to the coalescer. Returning to `AimingDefault` restores and submits the per-cast default target without requiring a valid drag vector. `CancelArmed` preserves the latest target and submits nothing. After leaving the cancel zone, the Session state decides whether the Strategy restores Default or recalculates Dragged from the current direction. Touch updates never enqueue a Dispatcher cursor event directly. Commit stops and discards coalesced points before calling the Dispatcher's atomic final-cursor-plus-skill-key-up operation so the final cursor strictly precedes key-up without an interleaving input event.

Ground and Unit point casts share `MobaPointCastStrategy` and `MobaPointCastGeometry`. For the normalized drag direction `u`, the geometry computes the ray intersections with independently configured minimum and maximum asymmetric ellipses and applies the following radial interpolation.

```text
minDistance = rayDistance(u, selected minimum radii)
maxDistance = rayDistance(u, selected maximum radii)
ratio = clamp(distanceRatio, 0, 1)
distance = minDistance + (maxDistance - minDistance) * ratio
target = anchor + u * distance
```

A selected zero minimum radius degenerates to zero radial distance. Canvas clamping remains the responsibility of `MobaGameCanvas` at the production input boundary.

Point-cast begin uses a configured default direction and default distance ratio, normally the full-range upward target, then submits that cursor point followed by key-down. The default ratio uses the same 0...1 clamp as all point geometry. Each cast retains that default target locally. Returning to `AimingDefault`, including a dragged interaction falling below the meaningful threshold, restores it and submits that default to the optional coalescer. A zero Point Response ratio follows the same rule so a previous drag target cannot survive a dead-zone update. `CancelArmed` updates preserve the current target without submitting a new point until the Session returns to either default or dragged aiming. Commit uses the same atomic final-cursor-plus-skill-key-up Dispatcher operation as directional casts. Unit mode intentionally performs the same direct point mapping as Ground mode. It has no target detection, snapping, legality query, or fallback input.

### Cursor coalescing

`MobaCursorCoalescer` is a main-thread latest-value buffer between cast strategies and `MobaInputDispatcher`. It depends only on the pure `MobaDisplayLinkDriving` protocol. The production `MobaCADisplayLinkDriver` is the only coalescing component that depends on UIKit and uses `CADisplayLink` in the main run loop common modes.

Coalescer start, submit, stop, and tick entry points stay on the main-thread UIKit boundary. Stop is synchronous and is never delayed through an asynchronous main-queue hop, so commit and cancellation close delivery in their current call stack. The resulting cursor action still enters the Dispatcher's existing asynchronous serial input queue.

The supported update rates are 30, 60, and 120 Hz, with 60 Hz as the default. A touch update stores the Strategy latest target and marks the coalescer point dirty. Several submissions before one display tick collapse to the last point. Each tick sends at most one dirty point through `moveCursorToCanvasPoint:`. A tick with no dirty point sends nothing. Submitting the same coordinates again is treated as new dirty input because it represents a new accepted touch update.

Every start creates a new coalescer generation. Tick callbacks carry the generation they were created for. A stopped or older callback cannot send a later cast's point, clear its dirty state, or change its running state. Driver target ownership uses a weak proxy so the `CADisplayLink` target reference cannot retain the driver or coalescer cycle.

Commit synchronously stops the coalescer and discards pending intermediate points before calling the Dispatcher's atomic final-cursor-plus-skill-key-up API. Cancel and lifecycle interruption also stop and discard without flushing. They never submit a final cursor through the coalescer. The coalescer is a local interaction reset participant. Disabling local interaction synchronously stops its driver before lifecycle enqueues Dispatcher release-all, and recovery only permits a future explicit start.

Strategy initializers continue to support no coalescer for compatibility and tests. Strategies depend on `MobaCursorCoalescing`, not the UIKit driver. A future real `SkillButtonView` owner will create and register the production coalescer. Coordinator intentionally does not create an unused coalescer before that consumer exists.

An intentional cancel-zone release selects a configured keyboard, right-mouse, or release-only action. Keyboard and mouse cancellation use the Dispatcher's ordered cancellation operations. Lifecycle interruption does not send the configured cancel action. It relies on lifecycle `releaseAllInputs`, then silently resets strategy and Session state.

The cancel zone is one shared, fixed `MobaCancelZoneView`. It is a noninteractive presentation view and never owns a skill touch. Each `MobaSkillButtonView` retains its own touch ownership, converts the owned touch location into StreamView coordinates, and routes that point through its Controller to `MobaCancelZoneGeometry`. The geometry performs a pure radial circle test using `visualDiameter / 2 - activationInset` as its activation radius.

The geometric inside value is only an input to `MobaCastSession`. It cannot arm the presentation directly. An accepted Session result in `CancelArmed` arms the zone, while accepted `AimingDefault` and `AimingDragged` results restore the normal casting visual. The Strategy alone maps an intentional cancelled terminal result to its configured keyboard, right-mouse, or release-only input. Neither the View nor the cast state machine hard-codes Escape.

Intentional cancellation and lifecycle interruption remain separate paths. A release while Session is armed calls the Strategy cancel operation. Backgrounding, touch cancellation, disconnection, mode exit, and teardown first use lifecycle `releaseAllInputs`, then silently reset the Strategy, Session, and cancel-zone presentation. Cancel-zone lifecycle reset only hides the view and clears local token and armed state. It sends no remote input and recovery does not restore the previous cast presentation.

Strategies consume only accepted `MobaCastSession` transition results and guard each terminal outcome against repeated consumption. They own no pressed-key collection, tap timer, or release-all state and never mutate the Session. After commit or intentional cancellation, the caller explicitly invokes Session `silentReset` before a new interaction can begin.

### Profiles

`MobaProfileStore` owns only the `Application Support/MOBA` directory structure, bundled-default seeding, path containment, and atomic byte reads and writes. It does not parse JSON or create runtime, input, layout, or champion models. Those models, schema validation, and migration belong to #18. Import/export, user confirmation, and backup workflows belong to #22.

The immutable default-resource manifest maps the bundled `runtime.json`, `input.json`, `ipad-pro-13-layout.json`, `caitlyn.json`, and `debug-instant.json` resources to their storage destinations. The default layout independently seeds both `layouts/ipad-pro-13-layout.json` and `active-layout.json`. Each missing destination is filled separately. An existing regular file is always preserved, including when a newer bundled default exists. Directories, symbolic links, and other conflicting destination types fail safely without deletion or replacement.

All public read and write paths are relative to the standardized `Application Support/MOBA` root. Absolute paths, empty or dot components, parent traversal, the root itself, and resolved paths outside the root are rejected. `replaceExisting = YES` uses Foundation atomic replacement. For `replaceExisting = NO`, complete bytes are first written atomically to a uniquely named file beside the destination, then published with an atomic same-filesystem hard link that fails if the destination already exists. Only the temporary link is removed. The destination is never deleted or exposed partially. Reads and writes accept arbitrary bytes and deliberately perform no schema inspection.

Bootstrap creates the root plus `layouts`, `champions`, and `backups`, then attempts every missing manifest destination. It is idempotent and retryable. A failure returns an error containing the operation and related relative path, but already completed safe copies remain intact. The running stream treats storage failure as nonfatal and logs it.

The production store is created only inside the existing MOBA coordinator boundary, which itself is created only when `mobaControlsEnabled` is enabled. When the feature is disabled, bootstrap is not run and `Application Support/MOBA` is not created or modified. Normal Moonlight launch, settings, streaming, and file behavior remain unchanged.

Profile interpretation is a separate Foundation-only pipeline. `MobaProfileDecoder` accepts bytes from the Store, parses JSON, checks the root dictionary and strict integer `schemaVersion`, asks `MobaProfileMigrator` for a JSON-dictionary migration, validates the migrated schema-v1 dictionary with `MobaProfileValidator`, and only then constructs immutable model objects. Migration never operates on final models. The current v1 migration is identity-only and does not rewrite a successfully loaded user file.

JSON scalar types are strict. Booleans are not accepted as numbers, numeric zero or one is not accepted as a boolean, fractional values are not truncated into integers, and every number must be finite. Missing, type, enum, range, migration, storage, and cross-profile errors use one profile error domain with profile kind, JSON field path, operation, and an underlying error when one exists. Unknown object fields are ignored for forward compatibility and are retained by the identity migration dictionary. Unknown values in known enum fields remain errors at the specific field path.

Runtime, input, layout, champion, and nested profile objects are immutable after initialization. Strings and collection properties are defensively copied, and mutable JSON containers are never exposed. Layout controls and champion skills remain dynamic dictionaries so a future control or skill name can use the common schema without a parser change. Champion classes and Caitlyn calibration values are not embedded in these model types.

`MobaProfileRepository` forms the transactional activation boundary. It reads runtime, input, active layout, and one caller-selected champion relative path through `MobaProfileStore`. All four profiles are migrated, validated, and constructed locally. Cross-profile validation then confirms every champion skill `inputAction` resolves in the input profile. Only a fully valid candidate becomes one immutable `MobaProfileSnapshot`, which replaces `activeSnapshot` in one synchronized assignment. Any storage, parsing, migration, validation, construction, or reference failure preserves the prior snapshot object and contents.

Repository activation includes a candidate-acceptance seam. `MobaCastStrategyFactory` must successfully map the typed candidate snapshot into a `MobaChampionRuntime` before Repository commits it as `activeSnapshot`. Factory failure preserves the old snapshot and its field-specific runtime error. The Factory never parses JSON or reads storage. Directional and Point descriptors require their canonical layout control to provide a finite, positive `wheelRadiusPt` at this assembly boundary. Instant descriptors do not require that field.

The canonical UI slots are Q, W, E, and R. Each slot maps once to the corresponding champion skill and `abilityQ`, `abilityW`, `abilityE`, or `abilityR` layout control. Its display label stays Q, W, E, or R. The host key is resolved separately through the skill `inputAction` and Input Profile actions dictionary. Remapped host letters are not UI labels. A playable runtime requires all four canonical slots. Additional future noncanonical skill fields remain valid profile data but are ignored by this four-slot runtime shell.

Each aimed descriptor owns an independent display-link driver and `MobaCursorCoalescer`, configured with the Runtime Profile update rate and sharing the one Dispatcher. Instant descriptors create neither. `MobaChampionSelectionController` performs manual Caitlyn or Debug Instant replacement inside paired `profileWillReload` and `profileDidReload` calls. It releases and resets the old runtime through Lifecycle, builds and validates the candidate, swaps registered coalescer participants only after Repository commits, and restores the old snapshot, runtime, selection, and participants on failure.

`MobaChampionSelectorView` is a compact UI-mode-only manual selection shell. It delegates champion IDs and owns no Repository, Strategy, Dispatcher, or remote-input behavior. `MobaSkillControlPackage` holds a detached candidate set of all four Q, W, E and R Controllers, Views and Lifecycle reset participants. Champion Selection asks its package builder to complete this set inside the Repository candidate validator after runtime assembly and before snapshot commit. An incomplete package is silently reset and never attached. Its failure preserves the old snapshot, runtime, selection, installed Views and both View and Coalescer participant registrations. On success Champion Selection commits the snapshot, replaces runtime Coalescer participants and active runtime state, then Coordinator atomically installs the already prepared package. Coordinator unregisters only the old Views because Champion Selection owns Coalescer participant replacement.

Each skill layout comes directly from its immutable runtime descriptor. Safe-area normalized centers determine placement. Point sizes determine visible and hit-area bounds. Profile opacity, pressed opacity, disabled opacity, z-index and interaction flag remain independent. Battle shows interactive controls only while Lifecycle allows input. UI hides them. Layout Edit and Skill Tuning show them without gameplay interaction.

Issue #22 owns document picker access, import/export, backup rotation, user confirmation, and migration persistence. This profile layer performs none of those workflows.

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

- Battle: MOBA controls consume their own hit areas and a StreamView routing gate blocks native direct-touch and Pencil gameplay input after real mouse handling. No full-screen overlay view is added.
- UI: overlay controls are reduced/noninteractive and native StreamView interaction is enabled.
- Layout Edit: remote input is disabled; handles edit control properties.
- Skill Tuning: preview or live-cast behavior with explicit controls.

Mode transitions always close Battle input first. Leaving Battle then enqueues dispatcher release-all and resets local interaction before UI mode restores native StreamView routing. Entering Battle disables native routing before Battle controls become interactive. Layout Edit and Skill Tuning keep native routing disabled.

## 7. Lifecycle

Coordinator receives app background/inactive, stream teardown, controller disappearance, and orientation callbacks through the existing `StreamFrameViewController` lifecycle. It also exposes profile reload and feature-toggle interruption entries for their future owners. Every such transition calls `releaseAllInputs`, cancels active touches/casts, and invalidates display links.

All paths converge on `interruptAndReleaseInputsForReason:`. The ordered boundary is suspend input, disable diagnostics and local interaction, enqueue dispatcher release-all, then reset local participants. Release-all expands tracked state into concrete key-up and mouse-up events exactly once and invalidates pending tap tokens.

App-active, orientation-complete, and profile-reloaded callbacks may clear suspension only when the stream remains connected, the coordinator remains running, the mode is Battle, and the resolution remains exactly 2560x1440. Recovery never recreates a pressed input or cancelled timer. Stop, stream teardown, controller disappearance, destruction, and feature disable remain suspended and restore both native StreamView routing and traditional on-screen controls.

## 8. Extension path

Future champion support adds JSON profiles, not new UI classes. Future cast types add a new strategy and schema enum. Future device layouts add layout profiles. The fixed game canvas remains independent from device geometry.
