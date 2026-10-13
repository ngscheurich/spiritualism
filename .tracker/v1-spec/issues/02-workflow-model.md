# Workflow model: brief to pull request

Map: ../map.md
Type: grilling
Status: resolved
Blocked by:

## Question

What is a workflow in Spiritualism? Name its stages from brief to pull request, state which stages are deterministic (owned by the server) and which are agentic, and where the human intervenes or approves. The 'Deterministic' tenet and the 'pre-planned tasks' goal both depend on this concept, which the concept doc never defines.

## Answer

**Decision: a fixed five-stage workflow, Plan → Build → Review → Ship → Done, with a gate on every transition.** One workflow run per workspace carries one brief to a merged pull request. Only the server advances it. A human starts each run with an explicit command; the server never picks up briefs on its own. v1 ships this one sequence; users configure settings per stage and per gate, not the sequence.

Terms defined in `GLOSSARY.md`: Workflow, Stage, Gate, Attention request. ADR: `docs/adrs/0002-fixed-workflow-with-gates.md`.

### Stages

| Stage | Who works | Output |
|-------|-----------|--------|
| Plan | Agent | A plan Artifact, separate from the brief. The brief is never rewritten. |
| Build | Agent | Commits implementing the plan. |
| Review | Agent | Local agentic review, not pull request review. A findings Artifact and a structured verdict: pass or changes needed. |
| Ship | Agent, then the server on a human command | A pull request description Artifact, then the pull request. |
| Done | Nobody | Reached only when the pull request merges. |

- Every stage starts a fresh agent session. Artifacts are the only handoff between stages, so each stage can use a different agent provider.
- An agent reports that its turn ended or returns a verdict. It never chooses the next stage; the server applies a fixed rule.

### Gates

- A gate sits on each of the four transitions. It holds automated checks, a human approval, or both. Checks run first. A gate with neither passes immediately.
- Automated checks are the project's configured commands. The server runs them inside the workspace's sandbox, never on the host, and reads the exit status.
- Human approvals are optional and configured per project. Defaults are not decided here.
- At a human gate the choices are: approve, edit the Artifact under review then approve, or reject with feedback. A reject returns to the stage before the gate with the feedback as input. A reject at Review→Ship names its target: Build or Review.
- Ship→Done is the merge. A human always merges, on the forge. This gate cannot be switched off or forced.

### Backward transitions

- Only two exist: Review→Build and Ship→Build. Once a workflow leaves Plan it never returns. A plan that proves wrong after Build starts means abandoning the workflow; a flaw in the brief's source is outside this system.
- A failing check at Build→Review returns the workflow to Build automatically with the check output as input, up to a configured attempt limit. Then the workflow stops.
- A "changes needed" verdict returns the workflow to Build automatically with the findings as input, up to a configured round limit. Then the workflow stops.
- Ship→Build happens only on a human command. A pull request with changes requested does not trigger it, because the author may disagree with the reviewer. Automatic rebuild is a possible later setting.
- Reworked code passes the Build→Review gate and the Review stage again. No route to Ship skips them.

### Ship

1. A fresh agent session reads the diff, the brief, the plan, and the review findings, and writes the pull request description Artifact: a Markdown file whose top-level heading is the title.
2. The workflow waits, reason "ready to publish".
3. A human reads the Artifact, edits it if wanted, and runs the publish command.
4. The server pushes the branch and opens the pull request, or updates the existing one after a kickback.
5. The workflow waits, reason "merge". The merge moves it to Done.

The server touches the forge only on a human command. **Open to revisit**: the user was unsure about this shape and accepted it for now. Automatic publishing is a possible later setting.

### Status

Stage and status are separate facts.

| Status | Meaning |
|--------|---------|
| Running | An agent or the server is working. |
| Waiting | The workflow needs a human and nothing is wrong. It carries a reason: a gate approval, an attention request, ready to publish, or merge. |
| Stopped | Something went wrong or a human stopped it. |
| Abandoned | Terminal. |

- Any agentic stage (Plan, Build, Review, Ship) can raise an attention request, which puts the workflow in waiting.
- An agent session that dies mid-stage stops the workflow. No automatic retry.
- After an unexpected server death, the server restarts each running stage on startup without counting against the attempt limit. After a forced `spirit server stop`, those workflows stay stopped until a human retries.
- Abandoned is a status, not a stage. The workspace is kept as history and the brief is free for a new workspace. A pull request closed without merging abandons the workflow automatically.

### Human commands

Start, stop a running stage, retry the current stage (resets its attempt count), send back (Review→Build or Ship→Build, with feedback), abandon, publish, and force past. Force past covers a failing automated check on any gate, a Review "changes needed" verdict, and an exhausted limit. Every use is recorded in the workflow's event history.

### Rejected

- User-defined stage graphs in v1.
- A brief that arrives already planned, with no Plan stage.
- Ending the workflow when the pull request opens.
- A separate Check stage and a pull-request Review stage; the check is a gate, and Review is local.
- The Review agent writing the pull request text.
- Any return to Plan after Build starts.
- A human unable to override a failing check.

### Carried to other tickets

- [Forge integration: observing pull requests](15-forge-integration.md): new. How the server learns a pull request merged, closed, or had changes requested, and which forges v1 supports.
- [Agent provider interface](09-agent-provider-interface.md): a fresh session per stage; whether re-entering Build, or restarting after a server crash, resumes an earlier session; how an attention request and a structured verdict reach the server.
- [Sandbox provider interface](08-sandbox-provider-interface.md): the server runs gate checks inside the sandbox; restart after a server crash needs the sandbox to survive or be rebuilt.
- [Workspace and git model](11-workspace-git-model.md): the server pushes and opens or updates the pull request on a human publish command; cleanup on Done and on abandonment.
- [Brief model and provider interface](10-brief-model.md): stages and statuses the kanban can reflect; an abandoned workflow frees its brief.
- Fog: configuration schema (per-gate human approvals and their defaults, check commands, attempt and round limits, per-stage agent provider); Artifacts (plan, review findings, pull request description are the three known so far); public API (the human commands above); direct agent-to-user interaction (how an attention request is answered).
