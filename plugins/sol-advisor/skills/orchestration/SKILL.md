---
name: orchestration
description: "Codex-native architect and delegation workflow using GPT-6.2 Sol for orchestration and review at a user-selected reasoning level, and GPT-6 Luna at max reasoning for implementation. Require Fast service tier for the parent session so Luna inherits Fast mode. Use for delegated implementation, multi-task builds, feature work, bug fixes, refactors, five-part implementation specs, verification of subagent work, commitment-boundary advice, or any deliverable that must receive a final independent-context review before completion."
---

# Sol Advisor Orchestration

Act as the architect. Own the user's intent, architecture, decomposition, routing,
verification, and final acceptance. Delegate all implementation work to the Luna-max
implementation lane, then obtain a fresh profile-matched verdict before reporting a
deliverable complete. The implementation and reviewer lanes are native Codex
custom-agent threads, not a nested Codex CLI wrapper or a global default-subagent
setting.

Read [references/role-contracts.md](references/role-contracts.md) before the first
delegation in a session. It defines the required implementation spec, reports, and
review packet.

## Select the primary model and reasoning level

At the start of every skill run, before planning or delegation, ask the user:

> What reasoning level should I use for the GPT-6.2 Sol orchestrator and reviewer?
> Choose one level for both, or give separate levels. Use a level available in the
> current session: low, medium, high, xhigh, max, or ultra when available.

Do not assume a default or begin delegated work until the user answers. Run the primary
Codex session on GPT-6.2 Sol. Verify its current model and effort when the runtime
exposes them. If the active effort differs from the user's selected orchestrator level,
ask the user to select that level in the composer and wait before continuing; the skill
cannot change the primary session's model or effort itself. Pass the selected reviewer
effort explicitly when spawning the Sol reviewer. If the runtime omits the primary model
or effort, ask the user to confirm the current composer selection; never infer it.

## Preflight the companion custom agents

The two role files are user-owned native custom-agent TOML files. Installing or
updating this plugin does **not** install, overwrite, or register them automatically.
They must be installed separately and a fresh Codex task must be started so the native
spawn tool can discover the current roles. The implementation role pins GPT-6 Luna at
max. The reviewer role pins GPT-6.2 Sol but leaves its reasoning effort open for the
user's per-run selection.

Before every delegation, complete steps 1–2. After spawning a lane, complete steps
3–4 before accepting any result:

1. From the directory containing this SKILL.md, resolve
   ../../scripts/install-agents.ps1; never resolve it from the caller's current
   directory. Run its non-mutating exactness check:

   ~~~powershell
   $skillDir = '<directory-containing-this-SKILL.md>'
   $installer = Join-Path $skillDir '..\..\scripts\install-agents.ps1'
   & $installer -Check
   ~~~

   It must exit zero. That proves every installed role file is byte-for-byte identical
   to the shipped template. If it reports a missing, stale, or conflicting file, stop
   the affected lane. Give the user the installer path and its reported destination;
   install-agents.ps1 installs only missing files and intentionally refuses to replace
   a differing file. Do not work around the error by choosing another agent.

2. Inspect the native spawn tool's available agent_type entries. Both names must
   be exposed exactly before any lane may run:

   - sol_advisor_luna_implementer
   - sol_advisor_sol_reviewer
   If a name is missing or unavailable, stop the affected lane and tell the user to
   install/check the companion files, start a fresh task, and update Codex if the name
   is still not exposed. Never substitute a built-in role or a similarly named agent.

3. Treat byte-exact templates plus observed runtime routing as an acceptance gate. Use
   public native spawn/details metadata first. It must identify the selected custom
   role; compare any exposed model and effort with the required model and the user's
   selected effort for that lane.

   If public details omit model or effort and the local rollout is accessible, resolve
   ../../scripts/inspect-agent-runtime.ps1 relative to this SKILL.md and run it against
   the spawned native thread id:

   ~~~powershell
   $skillDir = '<directory-containing-this-SKILL.md>'
   $runtimeInspector = Join-Path $skillDir '..\..\scripts\inspect-agent-runtime.ps1'
   & $runtimeInspector -ThreadId '<native-subagent-thread-id>'
   ~~~

   This read-only helper locates only the exact local rollout filename for that id and
   emits an allowlisted routing object. It is the authoritative local fallback for
   omitted model and effort, not a replacement agent or an inferred guess. If both
   public details and the helper expose a value, they must agree.

   The accepted implementation value is GPT-6 Luna / max. The reviewer must use
   GPT-6.2 Sol and the user-selected reviewer effort. If the selected role, model, or
   effort is missing, inconsistent, unavailable, or unobservable after this procedure,
   stop that lane with an actionable error and do not accept its report as routed work.
   Never silently fall back to another model, effort, or agent type.

4. Always inspect and report the reviewer's observed sandbox policy type and permission
   profile type from public details, or from the local helper when public details omit
   them. The shipped reviewer file requests read-only sandboxing; a host permission
   profile can broaden that request. Do not call the review OS-enforced read-only unless
   the observed sandbox policy type is read-only.

The custom-agent files pin their models, and the Luna file pins max reasoning. Do not
add a per-spawn model override. Pass the user's selected reasoning effort when spawning
the Sol reviewer; omit the reasoning field for Luna so its max pin applies.

## Require Fast mode for implementation

Before spawning Luna, require the parent Codex session to use Fast speed. Codex custom
agents inherit the root session's service tier, and a custom-agent TOML cannot set a
separate tier. If Fast is not active or cannot be observed, ask the user to select Fast
in the composer and wait for confirmation before spawning Luna. This also puts the
orchestrator and reviewer on Fast because they share the parent session's speed.

## Keep architect work in the primary session

Keep these responsibilities in the primary session:

- Resolve requirements and material ambiguity.
- Choose architecture, interfaces, and decomposition.
- Select the implementation lane.
- Write the complete five-part spec.
- Inspect the actual diff and rerun verification.
- Judge reviewer feedback and accept the deliverable.

Do not type implementation code, tests, boilerplate, or mechanical configuration in
the primary session when a lane can do it. If a lane's result is wrong, correct the
spec and delegate the fix rather than silently repairing it yourself.

## Route implementation

### Luna: implementation lane

Use Luna for all implementation work, including routine changes and context-heavy or
higher-risk work. Its instructions require it to resolve difficult details within the
settled architecture while preserving every stated interface and constraint.

Spawn a native custom subagent thread with exactly:

~~~text
agent_type: sol_advisor_luna_implementer
fork_turns: none
~~~

Its installed agent file pins GPT-6 Luna at max reasoning. Do not include a
per-spawn model or reasoning field. Confirm the public-details-first runtime evidence,
using the local inspector only when those details omit model or effort, before
accepting any work; if it is unavailable or differs, stop the lane rather than falling
back.

<!-- All implementation, including complex work, uses the Luna lane above. -->

All implementation work, including context-heavy or higher-risk work, stays on the
Luna lane. Its prompt must encode the difficult implementation details within the
settled architecture and preserve every stated interface and constraint.

### Routing rules

- Route every implementation task to the Luna role.
- State that the worker is not alone in the codebase, must preserve other edits, and
  must adapt to concurrent changes.
- Keep shared-file edits and dependency chains serial.
- Do not silently substitute a role, model, or reasoning level. If a requested lane is
  unavailable, report the limitation and ask before changing lanes.
- Give a failed lane a corrected spec. Do not repeat an unchanged prompt.

## Verify every implementation

Treat worker reports as claims. Before accepting work:

1. Inspect the working tree and actual diff.
2. Confirm only in-scope files changed.
3. Rerun the spec's verification commands in the primary session.
4. Compare the evidence with the stated objective and interfaces.
5. Delegate corrections when evidence fails or the diff is wrong.

Do not call a task complete because a worker says it is complete.

## Consult the profile-matched reviewer at commitment boundaries

Before committing to a consequential architecture, migration, public API, or wide
refactor, spawn a fresh custom review thread with a requested read-only profile that
uses the selected reviewer reasoning level:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
reasoning_effort: <user-selected-reviewer-effort>
~~~

Use the commitment-boundary prompt from the role contracts. The installed agent file
pins GPT-6.2 Sol and requests a read-only sandbox; pass the selected reviewer reasoning
effort in the spawn call, but do not add a per-spawn model override. Observe the actual
host sandbox and permission profile using the same public-details-first procedure. Keep
the consult bounded; the primary session still makes the decision. If the mandatory
preflight or runtime observation fails, stop the consult instead of using a different
reviewer.

## Require the final profile-matched review

After implementation and primary verification, always spawn a new, fresh native
custom review thread using the user's selected reviewer reasoning effort:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
reasoning_effort: <user-selected-reviewer-effort>
~~~

Give it the final-review packet from the role-contract reference. The reviewer is
model-pinned by its installed file to GPT-6.2 Sol, uses the selected reviewer reasoning
effort, and requests read-only isolation. Instruct it to remain behaviorally read-only,
inspect the actual files and diff, then return exactly one verdict: ship, fix-first, or
rethink.

- ship: report completion with verification evidence.
- fix-first: delegate the named fixes, independently verify them, then obtain a new
  fresh review.
- rethink: return to architecture, revise the plan, and do not report completion.

Never waive the final review because the change is small. Never let the reviewer
implement its own fixes. A profile-matched review is context-clean, not
model-family-independent; describe it that way when independence matters.

Use the observed sandbox policy type to decide isolation status:

- If it is read-only, isolation is enforced and the review may proceed normally.
- If the host broadens it, the review may proceed only when the user and task do not
  require hard isolation, the review prompt explicitly forbids edits, and the parent
  captures and verifies exact before-and-after repository and artifact state. Report
  the broader observed sandbox and permission profile as residual risk.
- If hard isolation is required, the sandbox is unobservable, or any mutation occurs,
  stop the review lane. Do not claim read-only isolation and do not silently repair or
  hide the mutation.
