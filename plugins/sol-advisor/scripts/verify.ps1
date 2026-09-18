[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    throw "FAIL: $Message"
}

function Pass([string]$Message) {
    Write-Output "PASS: $Message"
}

function Test-ByteEqual([string]$LeftPath, [string]$RightPath) {
    if (-not (Test-Path -LiteralPath $LeftPath -PathType Leaf)) { return $false }
    if (-not (Test-Path -LiteralPath $RightPath -PathType Leaf)) { return $false }
    $left = [System.IO.File]::ReadAllBytes($LeftPath)
    $right = [System.IO.File]::ReadAllBytes($RightPath)
    if ($left.Length -ne $right.Length) { return $false }
    for ($index = 0; $index -lt $left.Length; $index++) {
        if ($left[$index] -ne $right[$index]) { return $false }
    }
    return $true
}

function Get-TomlValue([string]$Text, [string]$Key) {
    $pattern = '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*"([^"]+)"\s*$'
    $match = [regex]::Match($Text, $pattern)
    if (-not $match.Success) { return $null }
    return $match.Groups[1].Value
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$pluginDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..'))
$installer = Join-Path $scriptDir 'install-agents.ps1'
$runtimeInspector = Join-Path $scriptDir 'inspect-agent-runtime.ps1'
$manifestPath = Join-Path $pluginDir '.codex-plugin\plugin.json'
$skillPath = Join-Path $pluginDir 'skills\orchestration\SKILL.md'
$contractsPath = Join-Path $pluginDir 'skills\orchestration\references\role-contracts.md'
$templateDir = Join-Path $pluginDir 'agents'
$agentFiles = @(
    @{ File = 'sol-advisor-luna-implementer.toml'; Name = 'sol_advisor_luna_implementer'; Model = 'gpt-5.6-luna'; Effort = 'max'; Sandbox = $null },
    @{ File = 'sol-advisor-sol-reviewer.toml'; Name = 'sol_advisor_sol_reviewer'; Model = 'gpt-5.6-sol'; Effort = 'medium'; Sandbox = 'read-only' },
    @{ File = 'sol-advisor-astra-reviewer.toml'; Name = 'sol_advisor_astra_reviewer'; Model = 'gpt-6-astra'; Effort = 'low'; Sandbox = 'read-only' }
)
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('sol-advisor-verify-' + [guid]::NewGuid().ToString('N'))

try {
    foreach ($requiredPath in @($installer, $runtimeInspector, $manifestPath, $skillPath, $contractsPath)) {
        if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
            Fail "required file is missing: $requiredPath"
        }
    }
    Pass 'PowerShell verification files are present'

    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ($manifest.name -ne 'sol-advisor') { Fail 'plugin manifest name is incorrect' }
    if ([string]::IsNullOrWhiteSpace($manifest.version)) { Fail 'plugin manifest version is empty' }
    Pass 'plugin manifest JSON is valid'

    foreach ($agent in $agentFiles) {
        $path = Join-Path $templateDir $agent.File
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Fail "agent template is missing: $path" }
        $text = Get-Content -LiteralPath $path -Raw
        foreach ($field in @('name', 'description', 'developer_instructions')) {
            if ($field -eq 'developer_instructions') {
                if ($text -notmatch '(?m)^\s*developer_instructions\s*=\s*"""\s*$') {
                    Fail "$path is missing or has an empty $field"
                }
            } elseif ([string]::IsNullOrWhiteSpace((Get-TomlValue $text $field))) {
                Fail "$path is missing or has an empty $field"
            }
        }
        if ((Get-TomlValue $text 'name') -ne $agent.Name) { Fail "$path has an unexpected role name" }
        if ((Get-TomlValue $text 'model') -ne $agent.Model) { Fail "$path has an unexpected model pin" }
        if ((Get-TomlValue $text 'model_reasoning_effort') -ne $agent.Effort) { Fail "$path has an unexpected reasoning pin" }
        if ($null -eq $agent.Sandbox) {
            if ($null -ne (Get-TomlValue $text 'sandbox_mode')) { Fail "$path unexpectedly requests a sandbox mode" }
        } elseif ((Get-TomlValue $text 'sandbox_mode') -ne $agent.Sandbox) {
            Fail "$path has an unexpected sandbox mode"
        }
    }
    Pass 'custom-agent TOML validity and exact role pins'

    New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    $cleanTarget = Join-Path $tempRoot 'clean-install'
    & $installer -TargetDir $cleanTarget
    if (-not $?) { Fail 'PowerShell installer failed during clean install' }
    foreach ($agent in $agentFiles) {
        if (-not (Test-ByteEqual (Join-Path $templateDir $agent.File) (Join-Path $cleanTarget $agent.File))) {
            Fail "clean install is not byte-for-byte exact: $($agent.File)"
        }
    }
    Pass 'installer clean install and byte-for-byte final copies'

    & $installer -TargetDir $cleanTarget -Check
    if (-not $?) { Fail 'PowerShell installer -Check failed for an exact target' }
    Pass 'installer -Check exactness'

    $runtimeSessions = Join-Path $tempRoot 'runtime-sessions'
    $runtimeDay = Join-Path $runtimeSessions '2026\08\01'
    New-Item -ItemType Directory -Path $runtimeDay -Force | Out-Null
    $successId = '11111111-1111-7111-8111-111111111111'
    $rollout = Join-Path $runtimeDay "rollout-2026-08-01T00-00-00-$successId.jsonl"
    $records = @(
        (@{ type = 'response_item'; payload = @{ prompt = 'DO_NOT_LEAK_PROMPT'; token = 'DO_NOT_LEAK_TOKEN' } } | ConvertTo-Json -Compress),
        (@{ type = 'event_msg'; payload = @{ environment = @{ SECRET_ENV = 'DO_NOT_LEAK_ENV' }; config = @{ api_key = 'DO_NOT_LEAK_CONFIG' } } } | ConvertTo-Json -Compress),
        (@{ type = 'session_meta'; payload = @{ id = $successId; parent_thread_id = '00000000-0000-7000-8000-000000000000'; agent_role = 'sol_advisor_luna_implementer'; agent_path = '/root/fixture'; model_provider = 'openai'; cwd = '/fixture/cwd'; base_instructions = 'DO_NOT_LEAK_INSTRUCTIONS' } } | ConvertTo-Json -Compress),
        (@{ type = 'turn_context'; payload = @{ model = 'gpt-5.6-luna'; effort = 'max'; sandbox_policy = @{ type = 'danger-full-access'; hidden = 'DO_NOT_LEAK_SANDBOX' }; permission_profile = @{ type = 'disabled'; hidden = 'DO_NOT_LEAK_PERMISSION' }; cwd = '/fixture/cwd'; summary = 'DO_NOT_LEAK_SUMMARY' } } | ConvertTo-Json -Compress)
    )
    [System.IO.File]::WriteAllLines($rollout, $records)
    $runtimeOutput = (& $runtimeInspector -ThreadId $successId -SessionsDir $runtimeSessions | Out-String).Trim()
    if (-not $?) { Fail 'PowerShell runtime inspector failed on a valid fixture' }
    if ($runtimeOutput -match 'DO_NOT_LEAK') { Fail 'runtime inspector leaked fixture content' }
    $runtimeResult = $runtimeOutput | ConvertFrom-Json
    if ($runtimeResult.agent_role -ne 'sol_advisor_luna_implementer' -or $runtimeResult.model -ne 'gpt-5.6-luna' -or $runtimeResult.effort -ne 'max') {
        Fail 'runtime inspector returned unexpected routing metadata'
    }
    Pass 'runtime inspector safe allowlisted extraction'

    $skillText = Get-Content -LiteralPath $skillPath -Raw
    $contractsText = Get-Content -LiteralPath $contractsPath -Raw
    foreach ($document in @($skillText, $contractsText)) {
        foreach ($requiredText in @('sol_advisor_luna_implementer', 'sol_advisor_sol_reviewer', 'sol_advisor_astra_reviewer', 'fork_turns: none', 'install-agents.ps1', 'inspect-agent-runtime.ps1')) {
            if ($document -notlike "*$requiredText*") { Fail "documentation is missing required text: $requiredText" }
        }
        if ($document -match '(?i)\.sh') { Fail 'documentation still references POSIX scripts' }
        if ($document -match '(?m)^\s*(model|reasoning_effort):') { Fail 'documentation contains a per-spawn model or reasoning override' }
    }
    Pass 'PowerShell script references, role contracts, and removed-profile checks'
    Write-Output "VERIFY PASSED: Sol Advisor PowerShell checks completed in $tempRoot"
} finally {
    if (Test-Path -LiteralPath $tempRoot) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}
