# Roadmap

GitHub issue titles carry phase, priority, executor suitability, and device requirements until a Project board is configured.

## M0.1 Foundation

1. `[M0.1][P0][Codex] Add MOBA feature flag and coordinator scaffold`
2. `[M0.1][P0][Codex] Add 2560x1440 stream guard and Aspect Fit video geometry`
3. `[M0.1][P1][Codex] Add profile storage and bundled default resources scaffold`

## M0.2 Input foundation

4. `[M0.2][P0][Codex] Implement serialized MOBA input dispatcher`
5. `[M0.2][P0][Codex] Implement 2560x1440 absolute cursor adapter and diagnostics`
6. `[M0.2][P0][Codex] Implement lifecycle release-all protection`
7. `[M0.2][P1][Codex] Add geometry and dispatcher XCTest coverage`

## M0.3 Core controls

8. `[M0.3][P0][Codex] Implement eight-direction WASD joystick`
9. `[M0.3][P0][Codex] Implement non-repeating attack button`
10. `[M0.3][P0][Codex] Implement Battle and UI touch-routing modes`
11. `[M0.3][P1][iPad] Validate three-touch concurrent input`

## M0.4 Casting engine

12. `[M0.4][P0][Codex] Implement cast state machine and sessions`
13. `[M0.4][P0][Codex] Implement instant and directional strategies`
14. `[M0.4][P0][Codex] Implement ground and unit point-cast strategies`
15. `[M0.4][P0][Codex] Implement fixed cancel zone`
16. `[M0.4][P1][Codex] Implement cursor coalescing and final-event ordering tests`

## M0.5 Profiles and editor

17. `[M0.5][P0][Codex] Implement versioned profile models, validator, and migrator`
18. `[M0.5][P0][Codex] Add Caitlyn and debug instant profiles`
19. `[M0.5][P1][Codex] Implement layout editor and per-control opacity`
20. `[M0.5][P1][Codex] Implement skill tuning and hero-anchor calibration`
21. `[M0.5][P1][Codex] Implement JSON import and export`

## M1.0 Playable MVP

22. `[M1.0][P0][iPad] Validate nine-point cursor mapping on target setup`
23. `[M1.0][P0][iPad] Calibrate Caitlyn Q and E directional mapping`
24. `[M1.0][P0][iPad] Calibrate Caitlyn W ground point-cast mapping`
25. `[M1.0][P0][iPad] Validate Caitlyn R unit-target cursor mapping`
26. `[M1.0][P0][iPad] Validate cancellation input and lifecycle safety`
27. `[M1.0][P1][iPad] Calibrate iPad Pro layout, opacity, and update rate`
28. `[M1.0][P0][Codex+iPad] Complete full MVP regression`

## Dependency principles

- Input foundation precedes controls and casting.
- Casting strategies depend on dispatcher and geometry.
- Caitlyn profile depends on strategy and profile infrastructure.
- Editors depend on profile models.
- Real-device calibration does not begin until nine-point cursor diagnostics pass.

## Suggested GitHub Project fields

- Status: Backlog, Ready, In Progress, In Review, Blocked, Done.
- Phase: Foundation, Input, Controls, Casting, Profiles, Editor, Testing.
- Priority: P0, P1, P2, P3.
- Effort: XS, S, M, L, XL.
- Release: M0.1, M0.2, M0.3, M0.4, M0.5, M1.0.
- Needs iPad: Yes/No.
- Codex Ready: Yes/Partial/No.
