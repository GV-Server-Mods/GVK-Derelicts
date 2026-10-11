<#
.SYNOPSIS
    Finds stale references in the repo's Markdown docs and broken dialogue bank wiring.

.DESCRIPTION
    Flags any TODO/FIXME comment in Content/Data/Encounters (*.sbc) or ModScripts (*.cs).
    Checks the dialogue bank rules in README note 37: every DefeatedAndAttacked behavior has a bank (Research Lab
    excepted) named GVK-<Category>-<FACTION>.xml that exists and matches the factions its spawn groups use, each
    -<FACTION> behavior copy matches its original apart from the bank line, and each bank has the cues its
    faction can hear.
    Checks every tracked .md file for:
      1. Backticked profile names (GVK-*, Drone-*, RAI-*), prefab names (NWS [COAL] ...) and repo paths
         that no longer exist in Content/ or the repo.
      2. Lines that call an upstream MES issue/PR open, pending or waiting while GitHub says it is
         merged or closed. GitHub results are cached in obj/ for 12 hours.

.PARAMETER Hook
    Print a one-line JSON systemMessage for a Claude Code hook instead of the full report.
#>
[CmdletBinding()]
param([switch]$Hook)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Push-Location $root
try {
    $docs = git ls-files '*.md' | Where-Object { $_ -notmatch '^(bin|obj)/' }

    # Known names: every SubtypeId, every SBC file name, every prefab file name.
    $known = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($f in Get-ChildItem 'Content' -Recurse -Filter *.sbc) {
        [void]$known.Add($f.BaseName)
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($f.FullName), '<SubtypeId>([^<]+)</SubtypeId>|SubtypeId="([^"]+)"')) {
            [void]$known.Add(($m.Groups[1].Value + $m.Groups[2].Value).Trim())
        }
    }

    # Repo and mod names that look like profile names.
    'GVK-Derelicts', 'GVK-Settings', 'GVK-Weapons-Pack' | ForEach-Object { [void]$known.Add($_) }

    $warnings = New-Object System.Collections.Generic.List[string]
    $mesRefs = @{}

    # No TODO comments in our own SBC or scripts: open a GVK-Settings issue instead. (Prefabs are skipped:
    # embedded third-party PB scripts carry their own TODOs.)
    $sources = @(Get-ChildItem 'Content\Data\Encounters' -Recurse -Filter *.sbc) + @(Get-ChildItem 'ModScripts' -Recurse -Filter *.cs -ErrorAction SilentlyContinue)
    foreach ($f in $sources) {
        $n = 0
        foreach ($line in [IO.File]::ReadAllLines($f.FullName)) {
            $n++
            $rel = $f.FullName.Substring($root.Length + 1) -replace '\\', '/'
            if ($line -match '\b(TODO|FIXME)\b') {
                $warnings.Add("${rel}:${n}: TODO comment; move it to a GVK-Settings issue")
            }
            # Hidden TODOs: workaround/idea wording with no issue reference.
            elseif ($line -match '(?i)\b(for now|until (it is |it''s )?fixed|seems broken|appears to be broken|(is|are) (just )?broken|might be worth|revisit|right now)\b' -and $line -notmatch '#\d+') {
                $warnings.Add("${rel}:${n}: workaround/idea note without an issue link; add 'GVK-Settings#<n>' or move it to an issue")
            }
        }
    }

    # Dialogue banks (README note 37). MES never reports a bad bank: the NPC just goes silent or talks in the wrong voice.
    $profiles = @{}
    $spawnGroups = New-Object System.Collections.Generic.List[string]
    foreach ($f in Get-ChildItem 'Content\Data' -Recurse -Filter *.sbc | Where-Object { $_.FullName -notmatch '\\Prefabs\\' }) {
        $text = [IO.File]::ReadAllText($f.FullName)
        foreach ($m in [regex]::Matches($text, '(?s)<SubtypeId>([^<]+)</SubtypeId>\s*</Id>\s*<Description>(.*?)</Description>')) {
            $profiles[$m.Groups[1].Value.Trim()] = $m.Groups[2].Value
        }
        foreach ($m in [regex]::Matches($text, '(?s)<SpawnGroup>(.*?)</SpawnGroup>')) { $spawnGroups.Add($m.Groups[1].Value) }
    }
    # Factions each behavior spawns as, from its spawn groups' [FactionOwner:] and spawn condition profiles.
    $behaviorFactions = @{}
    foreach ($sg in $spawnGroups) {
        $factions = @([regex]::Matches($sg, '\[FactionOwner:([A-Z]+)\]') | ForEach-Object { $_.Groups[1].Value })
        foreach ($c in [regex]::Matches($sg, '\[SpawnConditionsProfiles:([^\]]+)\]')) {
            $cond = $profiles[$c.Groups[1].Value.Trim()]
            if ($cond) { $factions += @([regex]::Matches($cond, '\[FactionOwner:([A-Z]+)\]') | ForEach-Object { $_.Groups[1].Value }) }
        }
        foreach ($b in [regex]::Matches($sg, '<Behaviour>([^<]+)</Behaviour>')) {
            $name = $b.Groups[1].Value.Trim()
            if (-not $behaviorFactions[$name]) { $behaviorFactions[$name] = New-Object 'System.Collections.Generic.HashSet[string]' }
            $factions | ForEach-Object { [void]$behaviorFactions[$name].Add($_) }
        }
    }
    $noBankAllowed = 'GVK-Alliance-ResearchLab-Behavior'
    $hostileFactions = 'GAALSIEN', 'DERELICT'   # never neutral or friendly, so their banks skip those cues
    $bankDir = 'Content\Data\DialogueBanks'
    $checkedBanks = New-Object 'System.Collections.Generic.HashSet[string]'
    $stripBank = { param($d) ($d -replace '(?m)^\s*\[(DialogueBanks|//CopyOf):[^\]]*\]\s*$', '' -replace '\s+', ' ').Trim() }
    foreach ($name in $profiles.Keys | Sort-Object) {
        $desc = $profiles[$name]
        if ($desc -notmatch '\[RivalAI Behavior\]') { continue }
        $banks = @([regex]::Matches($desc, '\[DialogueBanks:([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value.Trim() })
        if (-not $banks.Count) {
            if ($desc -match '\[TriggerGroups:GVK-Universal-TriggerGroup-DefeatedAndAttacked\]' -and $name -notin $noBankAllowed) {
                $warnings.Add("${name}: no [DialogueBanks:] line; it will never play attacked chatter")
            }
            continue
        }
        # A per-faction copy ([//CopyOf:X]) must match its original apart from the bank line.
        if ($desc -match '\[//CopyOf:([^\]]+)\]') {
            $original = $Matches[1].Trim()
            if (-not $profiles.ContainsKey($original)) { $warnings.Add("${name}: [//CopyOf:$original] names a missing behavior") }
            elseif ((& $stripBank $desc) -ne (& $stripBank $profiles[$original])) {
                $warnings.Add("${name}: differs from $original beyond the [DialogueBanks:] line; edit both copies")
            }
        }
        foreach ($bank in $banks) {
            if ($bank -cnotmatch '^GVK-(Units|Travellers|Structures|Installations)-([A-Z]+)\.xml$') {
                $warnings.Add("${name}: bank $bank does not follow GVK-<Units|Travellers|Structures|Installations>-<FACTION>.xml")
                continue
            }
            $category, $bankFaction = $Matches[1], $Matches[2]
            $path = Join-Path $bankDir $bank
            if (-not (Test-Path $path)) { $warnings.Add("${name}: bank file $bank does not exist"); continue }
            $spawnedAs = $behaviorFactions[$name]
            if ($spawnedAs -and $spawnedAs.Count -gt 1) {
                $warnings.Add("${name}: spawns as $(@($spawnedAs) -join '/'), but a bank is fixed per behavior; make a -<FACTION> copy per faction")
            }
            elseif ($spawnedAs -and -not $spawnedAs.Contains($bankFaction)) {
                $warnings.Add("${name}: spawns as $(@($spawnedAs) -join '/') but uses the $bankFaction bank $bank")
            }
            if (-not $checkedBanks.Add($bank)) { continue }
            $cues = @([regex]::Matches([IO.File]::ReadAllText((Join-Path $root $path)), '<DialogueCueId>([^<]+)</DialogueCueId>') | ForEach-Object { $_.Groups[1].Value })
            $needed = @('EnemyAttacked')
            if ($bankFaction -notin $hostileFactions) { $needed += 'NeutralAttacked', 'FriendlyFire' }
            if ($category -eq 'Units') { $needed += 'TargetAcquired', 'NoTargets' }
            foreach ($cue in $needed | Where-Object { $_ -notin $cues }) { $warnings.Add("${bank}: missing the $cue cue") }
        }
    }
    foreach ($doc in $docs) {
        $lines = [IO.File]::ReadAllLines((Join-Path $root $doc))
        $inGenerated = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            if ($line -match '<!-- GENERATED:') { $inGenerated = $true }
            if ($line -match '<!-- /GENERATED:') { $inGenerated = $false; continue }
            if ($inGenerated) { continue }
            $where = "${doc}:$($i + 1)"

            foreach ($m in [regex]::Matches($line, '`([^`]+)`')) {
                $token = $m.Groups[1].Value.Trim()
                if ($token -match '[*{}<>|$]|\.\.\.|\s=\s') { continue }   # patterns and placeholders
                $name = $token -replace '\.sbc$', ''
                if ($name -match '^(GVK|Drone|RAI)-[A-Za-z0-9-]+$') {
                    if (-not $known.Contains($name)) { $warnings.Add("${where}: unknown profile/file ``$token``") }
                }
                elseif ($name -match '^N[A-Z]{2} \[[A-Z]{4}\] .+$') {
                    if (-not $known.Contains($name)) { $warnings.Add("${where}: unknown prefab ``$token``") }
                }
                elseif ($token -match '^(Content|tools|Docs|ModScripts)/[^\s]+$') {
                    if (-not (Test-Path (Join-Path $root $token))) { $warnings.Add("${where}: missing path ``$token``") }
                }
            }

            if ($line -match '(?i)\b(open|pending|waiting|not yet|unmerged)\b') {
                foreach ($m in [regex]::Matches($line, '(?:MES (?:PR |issue )?#|Modular-Encounters-Systems#)(\d+)')) {
                    $mesRefs[$m.Groups[1].Value] += @($where)
                }
            }
        }
    }

    # Upstream state, cached.
    if ($mesRefs.Count) {
        $cacheFile = Join-Path $root 'obj\.doc-check-cache.json'
        $cache = @{}
        if ((Test-Path $cacheFile) -and ((Get-Item $cacheFile).LastWriteTime -gt (Get-Date).AddHours(-12))) {
            (Get-Content $cacheFile -Raw | ConvertFrom-Json).PSObject.Properties | ForEach-Object { $cache[$_.Name] = $_.Value }
        }
        foreach ($n in $mesRefs.Keys) {
            if (-not $cache.ContainsKey($n)) {
                $state = gh api "repos/MeridiusIX/Modular-Encounters-Systems/issues/$n" --jq 'if .pull_request.merged_at then "MERGED" else (.state | ascii_upcase) end' 2>$null
                $cache[$n] = if ($LASTEXITCODE -eq 0) { "$state".Trim() } else { 'UNKNOWN' }
            }
            if ($cache[$n] -in 'MERGED', 'CLOSED') {
                foreach ($w in $mesRefs[$n]) { $warnings.Add("${w}: says MES #$n is open/pending, but it is $($cache[$n].ToLower())") }
            }
        }
        New-Item -ItemType Directory -Force (Split-Path $cacheFile) | Out-Null
        $cache | ConvertTo-Json | Set-Content $cacheFile
    }
}
finally { Pop-Location }

if ($Hook) {
    if ($warnings.Count) {
        @{ systemMessage = "Doc check: $($warnings.Count) problem(s), e.g. $($warnings[0]). Run tools/Test-Docs.ps1 for the full list." } | ConvertTo-Json -Compress
    }
    exit 0
}
if ($warnings.Count) { $warnings | ForEach-Object { Write-Output $_ }; exit 1 }
Write-Output 'Docs OK: no stale references found.'
