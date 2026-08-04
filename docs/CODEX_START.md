# Start Codex work

## First task

Start with GitHub Issue #2 after PR #1 has been merged.

Select the `Security6699/moonlight-ios-moba` Codex environment and paste:

```text
Work on GitHub issue #2 only.

Before modifying code, read AGENTS.md and every document linked by the issue.
Create a dedicated branch from master. Implement only the issue scope. Do not
implement resolution guards, input dispatch, joystick, casting strategies,
champion profiles, editors, or JSON import/export unless Issue #2 explicitly
requires them.

Run the validation required by AGENTS.md. Commit the changes and open a draft
pull request against master linked to Issue #2. In the PR, list changed files,
tests and build commands, results, intentionally deferred work, and anything
requiring real-iPad verification.
```

## Execution rules

- One GitHub issue per Codex task.
- Do not ask Codex to implement the entire roadmap in one run.
- Do not start an issue whose dependencies are open.
- Review every diff before merging.
- Keep PRs draft until scope, local validation, and CI results are clear.
- When Xcode is unavailable locally, report that limitation honestly and rely on the repository's `iOS Build` workflow for the required macOS compilation check.
- Static Windows checks must not be described as a successful Xcode build.
- A code PR is not ready to merge until the `iOS Build` GitHub Actions workflow passes.
- Fix CI failures on the existing issue branch and PR rather than opening a replacement PR.
- CI does not replace relevant XCTest or target-iPad testing.
- Calibration Issues #23–#28 require the target iPad and League practice mode; Codex may prepare tooling but cannot claim physical calibration results.

## Validation flow

1. Run `git diff --check` and all environment-available static checks.
2. Run local Xcode discovery and unsigned build when Xcode is available.
3. Push the task branch and open a Draft PR.
4. Wait for the `iOS Build` GitHub Actions result.
5. Fix any real compilation failure on the same branch and PR.
6. Merge only after required CI and tests pass and remaining real-device work is explicitly documented.

## Recommended implementation sequence

1. #2 feature flag and coordinator scaffold.
2. #3 resolution guard and video geometry.
3. #5 serialized input dispatcher.
4. #6 absolute cursor diagnostics.
5. #7 lifecycle release protection.
6. #8 geometry and dispatcher tests.
7. #9–#11 controls and touch routing.
8. #13–#17 casting engine.
9. #18–#22 profiles and editors.
10. #23–#29 real-device calibration and regression.
