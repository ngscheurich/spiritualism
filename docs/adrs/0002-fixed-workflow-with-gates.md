---
status: accepted
---

# A fixed five-stage workflow with gates

Spiritualism wraps unpredictable agents in a workflow the server controls. We chose one fixed sequence, Plan → Build → Review → Ship → Done, with a gate on every transition that holds automated checks, an optional human approval, or both. Determinism and human intervention live in the gates; agents work inside stages and never choose the next one.

Two choices in it are deliberate and easy to mistake for omissions.

**Nothing returns to Plan.** The only backward transitions are Review→Build and Ship→Build. A plan that proves wrong after Build starts means abandoning the workflow and starting another. A wrong approach is treated as a flaw in the brief's source, which is outside the system.

**The server touches the forge only on a human command.** The Ship agent writes a pull request description; a human publishes it; a human merges. A pull request with changes requested returns to Build only when a human says so, because the author may disagree with the reviewer.

## Considered options

- **User-defined stage graphs**: rejected for v1. Per-stage and per-gate settings carry the configurability.
- **Ending at pull request opened**: rejected. The workflow ends at merge, so the server must observe the forge.
- **A check stage and a pull-request review stage**: rejected. The check is a gate, and Review is a local agentic review that runs before anything is published.
- **Automatic rebuild and automatic publishing**: deferred as possible later settings.

## Consequences

- A human can force past a failing check, a Review verdict, or an exhausted limit, with each use recorded. The merge is the one condition that cannot be forced.
- Every stage starts a fresh agent session, so Artifacts are the only handoff between stages.
