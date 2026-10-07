<#
.SYNOPSIS
    Regenerates the data tables in README.md from the SBC files, so they can't drift.

.DESCRIPTION
    Rewrites the text between these marker pairs in README.md:
      <!-- GENERATED:sandbox-variables --> ... <!-- /GENERATED:sandbox-variables -->
      <!-- GENERATED:encounter-types -->   ... <!-- /GENERATED:encounter-types -->
      <!-- GENERATED:prefab-tags -->       ... <!-- /GENERATED:prefab-tags -->
    Everything outside the markers is left alone.

.PARAMETER Check
    Report whether README.md is out of date without writing it (exit code 1 if it is).
#>
[CmdletBinding()]
param([switch]$Check)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$readme = Join-Path $root 'README.md'
$data = Join-Path $root 'Content\Data'

# Every <Description> block in the encounter SBC files, with its profile header and file.
$profiles = foreach ($f in Get-ChildItem (Join-Path $data 'Encounters') -Recurse -Filter *.sbc) {
    $text = [IO.File]::ReadAllText($f.FullName)
    foreach ($m in [regex]::Matches($text, '(?s)<Description>(.*?)</Description>')) {
        $body = $m.Groups[1].Value
        $header = [regex]::Match($body, '\[(MES|RivalAI|Modular Encounters)[^\]:]*\]').Value
        [pscustomobject]@{ File = $f.BaseName; Header = $header; Body = $body }
    }
}

function Get-TagValues([string]$body, [string]$tagPattern) {
    foreach ($m in [regex]::Matches($body, "(?m)^\s*\[($tagPattern):([^\]]*)\]")) {
        [pscustomobject]@{ Tag = $m.Groups[1].Value; Value = ($m.Groups[2].Value -split ',')[0].Trim() }
    }
}

# --- Sandbox variables -------------------------------------------------------------
# Which tags touch sandbox (world-wide) storage depends on the profile type:
#   MES Event Condition/Action: plain boolean/counter tags are sandbox-scoped.
#   Spawn conditions / spawn groups: SandboxVariables tags.
#   RivalAI / MES AI profiles: only the *Sandbox* tags (the plain ones are grid-scoped).
$vars = @{}
function Add-Var($name, $kind, $role, $file) {
    if (-not $name -or $name -match '^\d') { return }
    if (-not $vars.ContainsKey($name)) { $vars[$name] = @{ Kind = $kind; Read = @{}; Write = @{} } }
    $vars[$name][$role][$file] = $true
}
foreach ($p in $profiles) {
    switch -Regex ($p.Header) {
        'MES Event Condition' {
            Get-TagValues $p.Body 'TrueBooleans|FalseBooleans' | ForEach-Object { Add-Var $_.Value 'bool' 'Read' $p.File }
            Get-TagValues $p.Body 'CustomCounters' | ForEach-Object { Add-Var $_.Value 'counter' 'Read' $p.File }
        }
        'MES Event Action' {
            Get-TagValues $p.Body 'SetBooleansTrue|SetBooleansFalse' | ForEach-Object { Add-Var $_.Value 'bool' 'Write' $p.File }
            Get-TagValues $p.Body 'SetCounters|ResetCounters|IncreaseCounters|DecreaseCounters' | ForEach-Object { Add-Var $_.Value 'counter' 'Write' $p.File }
        }
        'Spawn Conditions|Modular Encounters SpawnGroup' {
            Get-TagValues $p.Body 'SandboxVariables|FalseSandboxVariables' | ForEach-Object { Add-Var $_.Value 'bool' 'Read' $p.File }
            Get-TagValues $p.Body 'CustomSandboxCounters' | ForEach-Object { Add-Var $_.Value 'counter' 'Read' $p.File }
        }
        'RivalAI|MES AI' {
            Get-TagValues $p.Body 'SetSandboxBooleansTrue|SetSandboxBooleansFalse' | ForEach-Object { Add-Var $_.Value 'bool' 'Write' $p.File }
            Get-TagValues $p.Body 'IncreaseSandboxCounters|DecreaseSandboxCounters|ResetSandboxCounters|SetSandboxCounters' | ForEach-Object { Add-Var $_.Value 'counter' 'Write' $p.File }
            Get-TagValues $p.Body 'CustomSandboxCounters|CheckTrueSandboxBooleans|CheckFalseSandboxBooleans' | ForEach-Object { Add-Var $_.Value 'counter' 'Read' $p.File }
        }
    }
}
function Format-Files($set) {
    $names = @($set.Keys | Sort-Object)
    if ($names.Count -eq 0) { return '-' }
    $shown = ($names | Select-Object -First 2) -join ', '
    if ($names.Count -gt 2) { $shown += " +$($names.Count - 2)" }
    return $shown
}
$sandboxLines = @('| Variable | Kind | Read in | Written in |', '| --- | --- | --- | --- |')
foreach ($name in $vars.Keys | Sort-Object { $vars[$_].Kind }, { $_ }) {
    $v = $vars[$name]
    $note = if ($v.Write.Count -eq 0) { ' (set by admin command only)' } else { '' }
    $sandboxLines += "| ``$name`` | $($v.Kind)$note | $(Format-Files $v.Read) | $(Format-Files $v.Write) |"
}

# --- Encounter types ---------------------------------------------------------------
$types = @{}
foreach ($p in $profiles) {
    $t = [regex]::Match($p.Body, '\[CustomStrings:EncounterType,([^\]]+)\]')
    if (-not $t.Success) { continue }
    $name = $t.Groups[1].Value.Trim()
    if (-not $types.ContainsKey($name)) { $types[$name] = @{ Display = @{}; Limit = @{}; Air = $false; Count = 0 } }
    $e = $types[$name]; $e.Count++
    foreach ($d in [regex]::Matches($p.Body, '\[CustomStrings:EncounterDisplayName,([^\]]+)\]')) { $e.Display[$d.Groups[1].Value.Trim()] = $true }
    foreach ($l in [regex]::Matches($p.Body, '\[CustomCountersVariables:DefenseSpawn_Limit,(-?\d+)\]')) { $e.Limit[$l.Groups[1].Value] = $true }
    if ($p.Body -match '\[SetBooleansTrue:GVK_MobilityType_Aircraft\]') { $e.Air = $true }
}
$typeLines = @('| EncounterType | Display names | DefenseSpawn_Limit | Aircraft | Init actions |', '| --- | --- | --- | --- | --- |')
foreach ($name in $types.Keys | Sort-Object) {
    $e = $types[$name]
    $display = (@($e.Display.Keys | Sort-Object) -join ', ')
    $limit = if ($e.Limit.Count) { (@($e.Limit.Keys | Sort-Object { [int]$_ }) -join ', ') } else { '-' }
    $air = if ($e.Air) { 'some' } else { '-' }
    $typeLines += "| ``$name`` | $display | $limit | $air | $($e.Count) |"
}

# --- Prefab tags ---------------------------------------------------------------------
$meaning = [ordered]@{
    NAS = 'Alliance structure (Base, Outpost, Turret)'; NCO = 'Convoy lead'; NCS = 'Transport, Trader or Freighter'
    NDR = 'Unit (drone)'; NKO = 'KOTH Site or KOTH Camp'; NLO = 'Cache (loot drop)'; NMI = 'Mission Giver'
    NST = 'Static'; NTS = 'Trade Station'; NWL = 'Large Wreck'; NWM = 'Medium Wreck'; NWS = 'Small Wreck'
}
$prefabs = Get-ChildItem (Join-Path $data 'Prefabs') -Filter *.sbc | ForEach-Object { $_.BaseName }
$prefabLines = @('| Tag | Meaning | Prefabs | Example |', '| --- | --- | --- | --- |')
foreach ($g in $prefabs | Group-Object { ($_ -split ' ')[0] } | Sort-Object Name) {
    $m = if ($meaning.Contains($g.Name)) { $meaning[$g.Name] } else { '**not a known tag**' }
    $prefabLines += "| ``$($g.Name)`` | $m | $($g.Count) | ``$(@($g.Group)[0])`` |"
}

# --- Write -----------------------------------------------------------------------------
$text = [IO.File]::ReadAllText($readme)
$nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$sections = @{ 'sandbox-variables' = $sandboxLines; 'encounter-types' = $typeLines; 'prefab-tags' = $prefabLines }
$new = $text
foreach ($key in $sections.Keys) {
    $pattern = "(?s)(<!-- GENERATED:$key -->).*?(<!-- /GENERATED:$key -->)"
    if ($new -notmatch $pattern) { Write-Warning "README.md has no GENERATED:$key markers"; continue }
    $block = $nl + '<!-- Generated by tools/Update-DocTables.ps1 from the SBC files. Do not edit by hand. -->' + $nl + ($sections[$key] -join $nl) + $nl
    $new = [regex]::Replace($new, $pattern, { param($m) $m.Groups[1].Value + $block + $m.Groups[2].Value })
}
if ($new -ceq $text) { Write-Output 'README tables are up to date.'; exit 0 }
if ($Check) { Write-Output 'README tables are out of date.'; exit 1 }
[IO.File]::WriteAllText($readme, $new, (New-Object Text.UTF8Encoding($false)))
Write-Output 'README tables regenerated.'
