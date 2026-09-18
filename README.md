# Sol Advisor

**Sol or Astra runs orchestration, Luna handles every implementation task, and a
matching read-only Sol or Astra review stands between the diff and done.**

Sol Advisor is a Codex-native architect workflow for capability-routed software
delivery. The primary session stays focused on requirements, architecture, specs, and
verification while native Codex custom-agent threads handle implementation and review.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

| Lane | Native agent type | Pinned profile | Use it for |
|---|---|---|---|
| Orchestrator | Primary session | GPT-5.6 Sol / Medium **or** GPT-6 Astra / Low | Requirements, architecture, decomposition, routing, and acceptance |
| Implementation | sol_advisor_luna_implementer | GPT-5.6 Luna / Max | Every delegated implementation task |
| Sol review | sol_advisor_sol_reviewer | GPT-5.6 Sol / Medium / read-only | Fresh review when the orchestrator is Sol |
| Astra review | sol_advisor_astra_reviewer | GPT-6 Astra / Low / read-only | Fresh review when the orchestrator is Astra |

Only the Luna implementation lane is shipped. The reviewer should match the
orchestrator family: Sol-medium reviews a Sol-medium orchestration, and Astra-low
reviews an Astra-low orchestration.

## Install from GitHub

Requirements:

- A current Codex CLI or ChatGPT desktop app with plugins, native subagents, and
  custom agents enabled.
- Access to GPT-5.6 Sol, GPT-6 Astra, and GPT-5.6 Luna at the required reasoning
  levels.
- Windows PowerShell 5.1 or PowerShell 7.

Add the GitHub repository as a Codex marketplace, then install the plugin:

~~~powershell
codex plugin marketplace add kirisame-ame/sol-advisor --ref main
codex plugin add sol-advisor@sol-advisor
~~~

### Install the companion custom agents

Plugin installation does **not** automatically install custom-agent files. That is
intentional: the files are user-owned role pins, and the installer must never overwrite
a different local role silently. Install the companion templates separately:

~~~powershell
$pluginInfo = (codex plugin list --json | ConvertFrom-Json).installed |
    Where-Object { $_.pluginId -eq 'sol-advisor@sol-advisor' } |
    Select-Object -First 1
$pluginDir = $pluginInfo.source.path
if ([string]::IsNullOrWhiteSpace($pluginDir) -or -not (Test-Path -LiteralPath $pluginDir -PathType Container)) {
    throw 'Installed sol-advisor plugin directory was not found.'
}
$installer = Join-Path $pluginDir 'scripts\install-agents.ps1'
& $installer
& $installer -Check
~~~

Without an explicit target, the installer uses the existing CODEX_HOME value when one is
already set, otherwise the user's default Codex agents directory. It does not invoke
Codex, edit config.toml, or overwrite a differing agent file. It only installs a
missing template and then verifies every installed copy byte-for-byte.

Start a **new Codex task** after the check passes. Native agent types are discovered at
task creation, so an existing task may not see the installed roles.

Then select either GPT-5.6 Sol with Medium reasoning or GPT-6 Astra with Low reasoning
for the primary session, and ask for implementation work normally, or invoke the
orchestration skill explicitly:

~~~text
Use $sol-advisor:orchestration to build this feature, verify it, and obtain the final matching review before reporting done.
~~~

## Check and update

Run this check whenever a route must be trusted:

~~~powershell
$pluginInfo = (codex plugin list --json | ConvertFrom-Json).installed |
    Where-Object { $_.pluginId -eq 'sol-advisor@sol-advisor' } |
    Select-Object -First 1
$pluginDir = $pluginInfo.source.path
$installer = Join-Path $pluginDir 'scripts\install-agents.ps1'
& $installer -Check
~~~

To update the marketplace plugin and then re-check its companion roles:

~~~powershell
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
$pluginInfo = (codex plugin list --json | ConvertFrom-Json).installed |
    Where-Object { $_.pluginId -eq 'sol-advisor@sol-advisor' } |
    Select-Object -First 1
$pluginDir = $pluginInfo.source.path
$installer = Join-Path $pluginDir 'scripts\install-agents.ps1'
& $installer -Check
~~~

If the new shipped template differs from an installed role, the check and installer
fail rather than overwriting it. Inspect and deliberately reconcile the reported
destination with the shipped template, then rerun the check. Do not use a substitute
agent as a shortcut. Start a fresh task after every successful install or update.

## Runtime routing evidence

Native spawn/details metadata is the primary source of routing evidence. It must show
the selected custom agent type. When it also exposes model and effort, the orchestrator
compares those values with the role pin. If Desktop omits model or effort and the local
rollout is accessible, use the companion inspector as the authoritative read-only
fallback for those omitted fields:

~~~powershell
$pluginInfo = (codex plugin list --json | ConvertFrom-Json).installed |
    Where-Object { $_.pluginId -eq 'sol-advisor@sol-advisor' } |
    Select-Object -First 1
$pluginDir = $pluginInfo.source.path
$threadId = '<native-subagent-thread-id>'
$inspector = Join-Path $pluginDir 'scripts\inspect-agent-runtime.ps1'
& $inspector -ThreadId $threadId
~~~

For a disposable fixture or a non-default local session root, pass it explicitly:

~~~powershell
& $inspector -ThreadId $threadId -SessionsDir 'C:\path\to\sessions'
~~~

The helper searches only rollout filenames ending in that exact thread id, then emits a
single compact JSON object with allowlisted routing fields. It never prints prompts,
messages, environment variables, tokens, configuration contents, or arbitrary rollout
payloads. It refuses invalid ids, zero or multiple matches, and missing or inconsistent
role/model/effort; there is no inferred fallback. If public and local evidence both
exist, they must agree.

## How routing works

The Sol or Astra orchestrator writes a five-part spec for every implementation:
objective, file ownership, interfaces, constraints, and verification. Luna is the only
implementation producer, so every implementation task uses the same pinned lane.

Before delegation and acceptance, the skill requires all of the following:

1. The installed role files pass the byte-for-byte companion check.
2. The native spawn tool exposes all three exact names in the table above.
3. Public native spawn/details metadata identifies the selected role and, when exposed,
   its expected model and effort. If model or effort is omitted, the exact-rollout local
   inspector above must provide them instead.
4. The reviewer’s observed sandbox policy type and permission profile type are captured
   and reported.

A missing, stale, conflicting, unavailable, inconsistent, or unobservable
role/model/effort stops the affected lane with an actionable error. There is no silent
model, reasoning, or agent-type fallback, and per-spawn calls do not override the role
pins.

Both reviewer TOMLs request read-only sandboxing, but the host permission profile may
broaden that request. If the observed sandbox policy type is read-only, review can
proceed with enforced isolation. If the host broadens it, review can proceed only as
behaviorally read-only when hard isolation is not required, the prompt forbids edits,
and the parent captures and verifies exact before-and-after repository/artifact state;
the broader sandbox and permission profile must be reported as residual risk. If hard
isolation is required, the sandbox cannot be observed, or any mutation occurs, stop the
review lane and do not claim enforced read-only isolation.

The orchestrator inspects every diff and reruns verification. A fresh matching reviewer
then returns ship, fix-first, or rethink. The session cannot report completion until the
reviewer returns ship. These remain native Codex subagent threads; Sol Advisor does not
launch a nested Codex CLI process or globally reroute unrelated subagents.

## Local development

Install a checkout as a local marketplace when you want Codex to use its skill:

~~~powershell
Set-Location 'C:\absolute\path\to\sol-advisor'
codex plugin marketplace add 'C:\absolute\path\to\sol-advisor'
codex plugin add sol-advisor@sol-advisor
~~~

Run the repository verifier separately. It uses only a disposable target directory and
never changes your Codex configuration:

~~~powershell
Set-Location 'C:\absolute\path\to\sol-advisor'
& '.\plugins\sol-advisor\scripts\verify.ps1'
git diff --check
~~~

To exercise the installer itself against an explicit disposable target:

~~~powershell
Set-Location 'C:\absolute\path\to\sol-advisor'
$scratchAgents = Join-Path $env:TEMP ('sol-advisor-agents-' + [guid]::NewGuid().ToString('N'))
try {
    & '.\plugins\sol-advisor\scripts\install-agents.ps1' -TargetDir $scratchAgents
    & '.\plugins\sol-advisor\scripts\install-agents.ps1' -TargetDir $scratchAgents -Check
} finally {
    if (Test-Path -LiteralPath $scratchAgents) {
        Remove-Item -LiteralPath $scratchAgents -Recurse -Force
    }
}
~~~

To install this checkout's templates for real local development, use the same
repository-relative commands without `-TargetDir`, then begin a new task:

~~~powershell
Set-Location 'C:\absolute\path\to\sol-advisor'
& '.\plugins\sol-advisor\scripts\install-agents.ps1'
& '.\plugins\sol-advisor\scripts\install-agents.ps1' -Check
~~~

After editing the plugin, validate both layers:

~~~powershell
Set-Location 'C:\absolute\path\to\sol-advisor'
$codexSkills = if ([string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
    Join-Path $HOME '.codex\skills\.system'
} else {
    Join-Path $env:CODEX_HOME 'skills\.system'
}
uv run --no-project --with pyyaml python (Join-Path $codexSkills 'skill-creator\scripts\quick_validate.py') '.\plugins\sol-advisor\skills\orchestration'
uv run --no-project --with pyyaml python (Join-Path $codexSkills 'plugin-creator\scripts\validate_plugin.py') '.\plugins\sol-advisor'
Get-Content -Raw '.\.agents\plugins\marketplace.json' | ConvertFrom-Json | Out-Null
Get-Content -Raw '.\plugins\sol-advisor\.codex-plugin\plugin.json' | ConvertFrom-Json | Out-Null
~~~

The PowerShell verifier validates JSON and TOML, role pins, installer clean/idempotent/
check and conflict behavior, runtime-inspector safe fixtures, contract references, and
the removed-profile checks. The `uv` commands supply the validators' PyYAML dependency
in a disposable environment. They do not install the marketplace or mutate Codex
configuration.

## License

MIT
