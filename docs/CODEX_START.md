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
- Keep PRs draft until build/test results and scope are clear.
- Calibration Issues #23–#28 require the target iPad and League practice mode; Codex may prepare tooling but cannot claim physical calibration results.

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
