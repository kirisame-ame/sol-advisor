[CmdletBinding()]
param(
    [string]$TargetDir,
    [switch]$Check
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Fail([string]$Message) {
    [Console]::Error.WriteLine("ERROR: $Message")
    exit 1
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

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$templateDir = [System.IO.Path]::GetFullPath((Join-Path $scriptDir '..\agents'))
$agentFiles = @(
    'sol-advisor-luna-implementer.toml',
    'sol-advisor-sol-reviewer.toml',
    'sol-advisor-astra-reviewer.toml'
)

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_HOME)) {
        $TargetDir = Join-Path $env:CODEX_HOME 'agents'
    } else {
        $TargetDir = Join-Path $HOME '.codex\agents'
    }
}

if (-not [System.IO.Path]::IsPathRooted($TargetDir)) {
    $TargetDir = Join-Path (Get-Location).Path $TargetDir
}
$TargetDir = [System.IO.Path]::GetFullPath($TargetDir)
$root = [System.IO.Path]::GetPathRoot($TargetDir)
if ($TargetDir.TrimEnd('\', '/') -eq $root.TrimEnd('\', '/')) {
    Fail 'refusing to use the filesystem root as an agent target directory.'
}

foreach ($agentFile in $agentFiles) {
    $template = Join-Path $templateDir $agentFile
    if (-not (Test-Path -LiteralPath $template -PathType Leaf)) {
        Fail "shipped template is missing or not a regular file: $template"
    }
}

$preflightErrors = New-Object System.Collections.Generic.List[string]
if (Test-Path -LiteralPath $TargetDir) {
    if (-not (Get-Item -LiteralPath $TargetDir).PSIsContainer) {
        $preflightErrors.Add("target directory is not a real directory: $TargetDir")
    }
} elseif ($Check) {
    $preflightErrors.Add("required installed agent directory is missing: $TargetDir")
}

foreach ($agentFile in $agentFiles) {
    $template = Join-Path $templateDir $agentFile
    $destination = Join-Path $TargetDir $agentFile
    if (Test-Path -LiteralPath $destination) {
        if (-not (Test-Path -LiteralPath $destination -PathType Leaf)) {
            $preflightErrors.Add("destination is not a regular file and will not be replaced: $destination")
        } elseif (-not (Test-ByteEqual $template $destination)) {
            $preflightErrors.Add("destination differs from the shipped template and will not be overwritten: $destination")
            $preflightErrors.Add("       Inspect $template and resolve the conflict deliberately, then rerun -Check.")
        }
    } elseif ($Check) {
        $preflightErrors.Add("required installed agent file is missing: $destination")
        $preflightErrors.Add("       Run this script without -Check after reviewing the target directory.")
    }
}

if ($preflightErrors.Count -gt 0) {
    foreach ($message in $preflightErrors) {
        [Console]::Error.WriteLine("ERROR: $message")
    }
    exit 1
}

if ($Check) {
    Write-Output "CHECK PASSED: all Sol Advisor agent files exactly match $templateDir."
    exit 0
}

if (-not (Test-Path -LiteralPath $TargetDir)) {
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
}

foreach ($agentFile in $agentFiles) {
    $template = Join-Path $templateDir $agentFile
    $destination = Join-Path $TargetDir $agentFile
    if (Test-Path -LiteralPath $destination) {
        if (Test-ByteEqual $template $destination) {
            Write-Output "ALREADY CURRENT: $destination"
            continue
        }
        Fail "destination changed after preflight and will not be overwritten: $destination"
    }

    [System.IO.File]::Copy($template, $destination, $false)
    Write-Output "INSTALLED: $destination"
}

foreach ($agentFile in $agentFiles) {
    $template = Join-Path $templateDir $agentFile
    $destination = Join-Path $TargetDir $agentFile
    if (-not (Test-ByteEqual $template $destination)) {
        Fail "post-install exactness check failed: $destination"
    }
}

Write-Output "INSTALL PASSED: all Sol Advisor agent files exactly match $templateDir."
