[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$ThreadId,
    [Parameter(Position = 1)]
    [string]$SessionsDir
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
}

function Get-PropertyValue($Object, [string]$Name) {
    if ($null -eq $Object) { return $null }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Get-StringValue($Object, [string]$Name) {
    $value = Get-PropertyValue $Object $Name
    if ($value -is [string]) { return $value }
    return $null
}

function Get-NestedStringValue($Object, [string]$ParentName, [string]$ChildName) {
    $parent = Get-PropertyValue $Object $ParentName
    return Get-StringValue $parent $ChildName
}

if ($ThreadId -notmatch '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$') {
    Fail 'THREAD_ID must be a lowercase UUID.'
}

if ([string]::IsNullOrWhiteSpace($SessionsDir)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $SessionsDir = Join-Path $env:CODEX_HOME 'sessions'
    } else {
        $SessionsDir = Join-Path $HOME '.codex\sessions'
    }
}

if (-not (Test-Path -LiteralPath $SessionsDir -PathType Container)) {
    Fail "sessions directory is unavailable: $SessionsDir"
}

$matches = @(Get-ChildItem -LiteralPath $SessionsDir -Recurse -File -Filter "rollout-*-$ThreadId.jsonl" | Select-Object -ExpandProperty FullName)
if ($matches.Count -eq 0) { Fail 'no rollout filename matched the requested thread id.' }
if ($matches.Count -gt 1) { Fail 'multiple rollout filenames matched the requested thread id.' }
$rolloutFile = $matches[0]

$records = @()
foreach ($line in [System.IO.File]::ReadLines($rolloutFile)) {
    if ([string]::IsNullOrWhiteSpace($line)) { continue }
    try {
        $records += ($line | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        Fail 'rollout contains invalid JSON.'
    }
}

$sessions = @($records | Where-Object { (Get-StringValue $_ 'type') -eq 'session_meta' } | ForEach-Object { Get-PropertyValue $_ 'payload' })
$turns = @($records | Where-Object { (Get-StringValue $_ 'type') -eq 'turn_context' } | ForEach-Object { Get-PropertyValue $_ 'payload' })

if ($sessions.Count -ne 1) { Fail 'missing or ambiguous session metadata.' }
if ($turns.Count -eq 0) { Fail 'missing turn context.' }

$session = $sessions[0]
$sessionThreadId = Get-StringValue $session 'id'
$parentThreadId = Get-StringValue $session 'parent_thread_id'
$agentRole = Get-StringValue $session 'agent_role'
$agentPath = Get-StringValue $session 'agent_path'
$modelProvider = Get-StringValue $session 'model_provider'

$models = @($turns | ForEach-Object { Get-StringValue $_ 'model' })
$efforts = @($turns | ForEach-Object { Get-StringValue $_ 'effort' })
$sandboxTypes = @($turns | ForEach-Object { Get-NestedStringValue $_ 'sandbox_policy' 'type' })
$permissionTypes = @($turns | ForEach-Object { Get-NestedStringValue $_ 'permission_profile' 'type' })
$cwds = @($turns | ForEach-Object { Get-StringValue $_ 'cwd' })

if ([string]::IsNullOrWhiteSpace($sessionThreadId) -or $sessionThreadId -ne $ThreadId) {
    Fail 'session metadata does not identify the requested thread.'
}
if ([string]::IsNullOrWhiteSpace($agentRole)) { Fail 'missing agent role.' }
if (@($models | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { Fail 'missing model.' }
if (@($efforts | Where-Object { [string]::IsNullOrWhiteSpace($_) }).Count -gt 0) { Fail 'missing effort.' }
if (@($models | Sort-Object -Unique).Count -ne 1) { Fail 'conflicting models.' }
if (@($efforts | Sort-Object -Unique).Count -ne 1) { Fail 'conflicting efforts.' }
if (@($sandboxTypes | Sort-Object -Unique).Count -ne 1) { Fail 'conflicting sandbox policy types.' }
if (@($permissionTypes | Sort-Object -Unique).Count -ne 1) { Fail 'conflicting permission profile types.' }
if (@($cwds | Sort-Object -Unique).Count -ne 1) { Fail 'conflicting working directories.' }

$result = [ordered]@{
    thread_id = $sessionThreadId
    parent_thread_id = $parentThreadId
    agent_role = $agentRole
    agent_path = $agentPath
    model_provider = $modelProvider
    model = $models[0]
    effort = $efforts[0]
    sandbox_policy_type = $sandboxTypes[0]
    permission_profile_type = $permissionTypes[0]
    cwd = $cwds[0]
}

$result | ConvertTo-Json -Compress
