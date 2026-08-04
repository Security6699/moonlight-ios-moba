# Accepted design decisions

## D-001 Client platform

Only iPadOS is in scope for the MVP. The first target is the 13-inch iPad Pro (2025) in landscape.

## D-002 Stream geometry

The MOBA input model requires an exact 2560x1440 stream. Video uses Aspect Fit. Other resolutions are blocked rather than automatically scaled.

## D-003 Camera model

The MVP assumes League locked camera. Hero anchor defaults to (1280,720) but remains calibratable in game-canvas pixels.

## D-004 Coordinate separation

Skill aiming uses 2560x1440 game coordinates. Control layout uses normalized iPad safe-area coordinates and point sizes. These spaces are never combined in persisted data.

## D-005 Movement and host bindings

Movement is W/A/S/D. Ability labels Q/W/E/R map to host Q/E/R/T. Attack maps to C.

## D-006 Cast mode

Aimed abilities use League's quick cast with indicator. Final cursor movement must precede key-up.

## D-007 Default no-drag cast

Default direction is screen-up (270 degrees). Point casts default to maximum configured distance (`distanceRatio = 1.0`).

## D-008 Cancellation

The architecture includes cancel state from the first version. The MVP uses a fixed visible-while-casting cancel zone. Escape is the initial cancel action but is configurable.

## D-009 Cursor persistence

After casting, the cursor remains at the final target.

## D-010 First champion

Caitlyn is the first champion profile: Q directional, W ground point, E directional, R unit point. Instant cast is tested with a debug profile.

## D-011 Layout editor

The MVP includes editing for position, size, hit area, wheel radius, z-order, interaction state, and opacity.

## D-012 Opacity

Each control has independent base/pressed/disabled opacity and a global multiplier. Zero opacity does not imply disabled interaction.

## D-013 Configuration workflow

Skill ranges and layout are live-tunable. JSON import/export, validation, backup, and migration are required.

## D-014 Input safety

No repeated attack, macros, auto-targeting, game-memory access, injection, image recognition, or anti-cheat bypass is permitted.

## D-015 Implementation ownership

Full requirements live in GitHub. Codex receives one scoped issue at a time and works through dedicated branches and draft PRs.
