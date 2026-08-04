# Start Codex work

## First task

After the bootstrap documentation PR is reviewed and merged, start with the first Foundation issue.

Paste this into Codex after selecting the `Security6699/moonlight-ios-moba` environment:

```text
Work on GitHub issue #<first-foundation-issue-number> only.

Before modifying code, read AGENTS.md and every document linked by the issue.
Create a dedicated branch from master. Implement only the issue scope. Do not
implement joystick, casting strategies, champion profiles, editors, or JSON
import/export unless the issue explicitly includes them.

Run the validation required by AGENTS.md. Commit the changes and open a draft
pull request linked to the issue. In the PR, list changed files, tests and build
commands, results, intentionally deferred work, and anything requiring real-iPad
verification.
```

## Execution rules

- One GitHub issue per Codex task.
- Do not ask Codex to implement the whole roadmap in one run.
- Do not start an issue whose dependencies are open.
- Review every diff before merging.
- Keep PRs draft until build/test results and scope are clear.
- Calibration issues require the target iPad and League practice mode; Codex can prepare tooling but cannot claim physical calibration results.

## Recommended first sequence

1. Feature flag and coordinator scaffold.
2. Resolution guard and video geometry.
3. Input dispatcher.
4. Absolute cursor diagnostics.
5. Lifecycle release protection.
6. Joystick and attack.
7. Casting engine.
8. Profiles, editors, and calibration.
