# Executable issue backlog

This file is the source for creating GitHub Issues after repository Issues are enabled. Each implementation item is intended for one Codex branch and draft PR.

## Common Codex footer

Append this to every implementation issue:

> Read `AGENTS.md` and all linked documents. Use a dedicated branch, implement only this issue, run required validation, and open a draft PR. Report changed files, commands/results, intentionally deferred work, and real-device-only verification. Do not add memory reading, injection, image recognition, automatic targeting, macros, repeated attack, or anti-cheat bypasses.

---

## F1 — [M0.1][P0][Codex] Add MOBA feature flag and coordinator scaffold

**Dependencies:** Bootstrap documentation PR #1 merged.

**Scope:** Add persistent `mobaControlsEnabled` using existing settings patterns; add `MobaOverlayCoordinator` lifecycle shell and overlay mode enum; create/destroy from stream lifecycle; preserve upstream behavior when disabled.

**Out of scope:** Resolution guard, input, controls, casting, profiles, editors.

**Acceptance:** Defaults off; persists; enabled coordinator starts/stops safely; traditional controls change only in enabled mode; unsigned generic iOS build succeeds.

## F2 — [M0.1][P0][Codex] Add 2560x1440 stream guard and Aspect Fit video geometry

**Dependencies:** F1.

**Scope:** Expose runtime stream resolution and Aspect Fit `videoRect`; block Battle mode unless exactly 2560x1440; retain UI mode and exit; add geometry tests where practical.

**Acceptance:** Correct video rect in both landscape orientations; nonmatching resolution cannot send MOBA input; no hard-coded iPad screen dimensions.

## F3 — [M0.1][P1][Codex] Add profile storage and bundled default resources scaffold

**Dependencies:** F1.

**Scope:** Create Application Support/MOBA directory structure; copy bundled example defaults on first run; no full models/validation yet; define atomic read/write helper boundary.

**Acceptance:** First launch creates defaults without overwriting user files; errors are nonfatal and logged; no editor/import UI.

---

## I1 — [M0.2][P0][Codex] Implement serialized MOBA input dispatcher

**Dependencies:** F1.

**Scope:** Add `MobaInputSink`, fake sink, `MobaInputDispatcher`, serial queue, pressed-key/button tracking, duplicate suppression, scheduled key taps, atomic final-cursor+key-up operation.

**Acceptance:** Unit tests prove ordering, suppression, nonblocking tap timing, and exact release behavior.

## I2 — [M0.2][P0][Codex] Implement 2560x1440 absolute cursor adapter and nine-point diagnostics

**Dependencies:** F2, I1.

**Scope:** Production Moonlight adapter; clamp canvas points; send absolute cursor with 2560x1440 reference; developer nine-point panel.

**Acceptance:** Fake-sink tests pass; panel exposes all nine reference points; no conversion through iPad layout coordinates.

## I3 — [M0.2][P0][Codex] Implement lifecycle release-all protection

**Dependencies:** I1.

**Scope:** Release tracked input on touch cancel, resign active, background, disconnect, controller disappearance, mode transition, orientation, profile reload, and feature disable.

**Acceptance:** Tests or controlled fake-sink scenarios show every tracked input receives exactly one release; timers/display links stop.

## I4 — [M0.2][P1][Codex] Add game-canvas, aim-geometry, and dispatcher XCTest coverage

**Dependencies:** I1, I2.

**Scope:** Canvas clamp, asymmetric ellipse ray intersection, response curve, dispatcher ordering and release tests.

**Acceptance:** Required cases in `docs/TEST_PLAN.md` are covered and deterministic.

---

## C1 — [M0.3][P0][Codex] Implement eight-direction WASD joystick

**Dependencies:** I1, I3.

**Scope:** UIKit joystick, one-touch ownership, dead zone, eight directions, 8-degree hysteresis, state-difference transitions, configurable geometry/opacity hooks.

**Acceptance:** All eight states; W+D to D only releases W; interruption releases all movement keys.

## C2 — [M0.3][P0][Codex] Implement non-repeating attack button

**Dependencies:** I1, I3.

**Scope:** One touch-down emits one configured C tap, default 30 ms; hold does not repeat; visual pressed/disabled opacity.

**Acceptance:** One gesture -> one tap; no main-thread sleep; cancellation does not duplicate input.

## C3 — [M0.3][P0][Codex] Implement Battle and UI touch-routing modes

**Dependencies:** F1, I3.

**Scope:** Battle shields native StreamView gameplay touches; UI restores native Moonlight interaction; transitions release input; toolbar switch.

**Acceptance:** MOBA disabled matches upstream; Battle prevents native three-finger keyboard gesture; UI supports desktop/shop interaction.

## C4 — [M0.3][P1][iPad] Validate three-touch concurrent input

**Dependencies:** C1, C2, C3 and at least one aimed skill.

**Scope:** Real-device validation for joystick + aimed skill + attack/action.

**Acceptance:** No touch ownership transfer, dropped movement, native gesture, or stuck input. Record device/iPadOS/network.

---

## S1 — [M0.4][P0][Codex] Implement cast state machine and sessions

**Dependencies:** I1, I3.

**Scope:** Idle/default/dragged/cancel-armed/committed/cancelled states; one active touch per skill; semantic begin/update/commit/cancel interface.

**Acceptance:** State-transition tests cover normal, cancel, interruption, reentry, and invalid duplicate begin.

## S2 — [M0.4][P0][Codex] Implement instant and directional cast strategies

**Dependencies:** S1, I2, I4.

**Scope:** Instant on-release key tap; directional default-up aim; asymmetric ellipse ray intersection; cursor/key ordering; cancellation hook.

**Acceptance:** Debug instant profile and fake directional profile pass tests; direction preserved for unequal radii.

## S3 — [M0.4][P0][Codex] Implement ground and unit point-cast strategies

**Dependencies:** S1, I2, I4.

**Scope:** Ground and unit target modes; direction+distance curve; default-up maximum distance; no target recognition or snapping.

**Acceptance:** Dead zone/full range/exponent behavior tested; unit mode only moves cursor and sends key input.

## S4 — [M0.4][P0][Codex] Implement fixed cast-cancel zone

**Dependencies:** S1, S2 or S3.

**Scope:** Configurable fixed cancel-zone view, visible while casting; arm/disarm state; configurable Escape/right-mouse/release-only action.

**Acceptance:** Enter/exit visual state works; release in zone sends configured cancel then skill key-up; no hard-coded Escape in state machine.

## S5 — [M0.4][P1][Codex] Implement cursor coalescing and final-event ordering tests

**Dependencies:** S2, S3.

**Scope:** `CADisplayLink` latest-point delivery at 30/60/120 options; default 60; final point bypasses coalescing and precedes key-up atomically.

**Acceptance:** Tests demonstrate ordering and coalescing; display link stops on interruption.

---

## P1 — [M0.5][P0][Codex] Implement versioned profile models, validator, and migrator

**Dependencies:** F3, core geometry.

**Scope:** Runtime, input, layout, champion models; schema v1 validator with JSON paths; migrator boundary; unknown-field tolerance; atomic store.

**Acceptance:** Bundled examples load; invalid enum/range/opacity/canvas fails safely; active state remains unchanged.

## P2 — [M0.5][P0][Codex] Add Caitlyn and debug instant profiles

**Dependencies:** P1, S2, S3.

**Scope:** Bundle and load Caitlyn Q directional, W ground, E directional, R unit plus debug instant; strategy factory configuration; manual champion selection shell.

**Acceptance:** No calibration placeholder is hard-coded in strategy classes; labels remain Q/W/E/R while host keys are Q/E/R/T.

## E1 — [M0.5][P1][Codex] Implement layout editor and per-control opacity

**Dependencies:** P1, C1, C2, skill controls.

**Scope:** Edit position, visual size, hit-area scale, wheel radius, z-order, interaction state, base/pressed/disabled opacity, global multiplier; restore/save.

**Acceptance:** Edit mode sends no remote input; changes apply live and persist; opacity zero remains interactive unless disabled.

## E2 — [M0.5][P1][Codex] Implement skill tuning and hero-anchor calibration

**Dependencies:** P1, S2, S3.

**Scope:** Per-skill range/default/response/cancel controls; anchor X/Y micro-adjust; Preview Only and Live Cast; game-space aim overlay.

**Acceptance:** Values apply live and persist; preview maps through runtime video rect; no range stored in UIKit points.

## E3 — [M0.5][P1][Codex] Implement JSON import and export

**Dependencies:** P1.

**Scope:** Document picker; detect profile type; validate; show summary; confirm; backup; atomic import; export active profiles.

**Acceptance:** Round trip succeeds; malformed/invalid file leaves active state unchanged and reports field path.

---

## R1 — [M1.0][P0][iPad] Validate nine-point cursor mapping on target setup

**Dependencies:** I2.

**Scope:** Target iPad, Windows host, 2560x1440 Aspect Fit, locked camera. Test all nine points and Windows DPI/multi-monitor configuration.

**Acceptance:** No offset or stretch; center is correct; evidence and environment recorded before skill calibration.

## R2 — [M1.0][P0][iPad] Calibrate Caitlyn Q and E directional mapping

**Dependencies:** R1, P2, E2.

**Scope:** Measure four-direction extents and diagonals for Q/E; validate default-up and cancellation.

**Acceptance:** Repeatable profile values committed through PR; residual bias documented.

## R3 — [M1.0][P0][iPad] Calibrate Caitlyn W ground point-cast mapping

**Dependencies:** R1, P2, E2.

**Scope:** Tune min/max four-direction ranges, dead zone, full range, exponent; test near/mid/max and diagonals.

**Acceptance:** Repeatable placement and accepted JSON values committed; method documented.

## R4 — [M1.0][P0][iPad] Validate Caitlyn R unit-target cursor mapping

**Dependencies:** R1, P2, E2.

**Scope:** Tune cursor envelope for visible units; test legal and invalid targets; verify no snapping/fallback.

**Acceptance:** Profile mapping documented; game remains responsible for target legality.

## R5 — [M1.0][P0][iPad] Validate cancellation input and lifecycle safety

**Dependencies:** S4, I3.

**Scope:** Compare Escape/right-mouse/release-only in practice mode; run all lifecycle stuck-key tests.

**Acceptance:** Select default cancel input; no key/button remains active after every interruption path.

## R6 — [M1.0][P1][iPad] Calibrate iPad Pro layout, opacity, and update rate

**Dependencies:** E1, E2.

**Scope:** Tune control positions, sizes, hit areas, wheel radii, per-control opacity, and 60/120 Hz feel.

**Acceptance:** Final layout JSON committed; three-touch usability documented; power/latency observations noted.

## R7 — [M1.0][P0][Codex+iPad] Complete full MVP regression

**Dependencies:** All implementation and calibration items.

**Scope:** Run `docs/TEST_PLAN.md`, build/tests, import/export, lifecycle, all Caitlyn actions, disabled-mode upstream regression.

**Acceptance:** All `docs/PRODUCT_SPEC.md` MVP criteria pass; remaining limitations are documented calibration/product limitations, not untriaged defects.
