# Moonlight iPad MOBA Controls

This fork adds an experimental iPadOS touch-control layer for playing the Windows version of League of Legends through Moonlight and Sunshine.

## MVP scope

- Target device: 13-inch iPad Pro (2025), landscape.
- Required stream: 2560x1440, 16:9, Aspect Fit.
- Camera: locked.
- Movement: eight-direction virtual joystick mapped to W/A/S/D.
- Host ability keys: Q/E/R/T, displayed on-screen as Q/W/E/R.
- Attack: one non-repeating button mapped to C.
- Cast types: instant, directional, ground point-cast, and unit point-cast.
- Default no-drag cast: upward at maximum configured distance.
- Fixed cancel zone with configurable cancel input.
- Per-control position, size, hit area, wheel radius, z-order, and opacity.
- In-app live calibration and JSON import/export.
- First champion profile: Caitlyn.

## Documentation

Start with [`docs/INDEX.md`](docs/INDEX.md). Repository rules for Codex are in [`AGENTS.md`](AGENTS.md).

## Development model

- `master` remains the stable integration branch.
- Every implementation issue uses a dedicated branch and draft pull request.
- Full specifications live in the repository; Codex prompts should reference one GitHub issue at a time.
- Calibration values in example profiles are placeholders until verified on the target iPad and in League practice mode.

## Non-goals

This project does not implement automatic targeting, image recognition, memory reading, process injection, macros, repeated attack input, auto-combos, or anti-cheat bypasses.
