<#
.SYNOPSIS
    Finds stale references in the repo's Markdown docs and broken dialogue bank wiring.

.DESCRIPTION
    Flags any TODO/FIXME comment in Content/Data/Encounters (*.sbc) or ModScripts (*.cs).
    Checks the dialogue bank rules in README note 37: every DefeatedAndAttacked behavior has a bank (Research Lab
    excepted) named GVK-<Category>-<FACTION>-<Tier>.xml that exists and matches the factions its spawn groups use, each
    -<FACTION> behavior copy matches its original apart from the bank line, and each bank has the cues its
    faction can hear.
    Checks that no COALITION behavior uses a target profile that only accepts Enemies, and that COALITION behaviors that fight
    GAALSIEN use GVK-Universal-Target-Override-COALITION for forced targets; every other behavior that can force a target uses
    GVK-Universal-Target-Override.
    Checks that every Unit on a Patrol<Name> group has GVK-Unit-All-TriggerGroup-CombatKPL unless it spawns as COALITION,
    and exactly one of GVK-Unit-All-TriggerGroup-LeashGround/-LeashAir; and that every behavior spawning Defense waves,
    air support or Elite escorts has GVK-Universal-TriggerGroup-LeashBeacon.
    Checks every tracked .md file for:
      1. Backticked profile names (GVK-*, Unit-*, RAI-*), prefab names (NWS [COAL] ...) and repo paths
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
    # Silent on purpose: small wrecks only get the blue Sensors lines. They must set GVK_NoLastWords at init, or their defeat goes unannounced.
    $noBankAllowed = 'GVK-Alliance-ResearchLab-Behavior', 'GVK-PlanetaryInstallation-Small-Behavior', 'GVK-PlanetaryInstallation-Small-Behavior-GAALSIEN'
    $hostileFactions = 'GAALSIEN', 'DERELICT'   # never neutral or friendly, so their banks skip those cues
    $bankDir = 'Content\Data\DialogueBanks'
    $checkedBanks = New-Object 'System.Collections.Generic.HashSet[string]'
    $stripBank = { param($d) ($d -replace '(?m)^\s*\[(DialogueBanks|//CopyOf):[^\]]*\]\s*$', '' -replace '(\[TargetData:[^\]]+?)-(GAALSIEN|DERELICT)\]', '$1]' -replace '\s+', ' ').Trim() }
    foreach ($name in $profiles.Keys | Sort-Object) {
        $desc = $profiles[$name]
        if ($desc -notmatch '\[RivalAI Behavior\]') { continue }
        # The shared target profiles skip COALITION and DERELICT grids; GAALSIEN (fights both) and DERELICT (also skips SOBAN and KHAANEPH) use their own copies.
        $spawnedAs = $behaviorFactions[$name]
        if ($spawnedAs -and $desc -match '\[TargetData:([^\]]+)\]') {
            $target = $Matches[1].Trim()
            $base = $target -replace '-(GAALSIEN|DERELICT)$', ''
            foreach ($f in 'GAALSIEN', 'DERELICT') {
                if ($spawnedAs.Contains($f) -and $target -ne "$base-$f" -and $profiles.ContainsKey("$base-$f")) {
                    $warnings.Add("${name}: spawns as $f but targets with $target; use $base-$f")
                }
            }
        }
        # MES reads an NPC-vs-NPC relation from the target owner's reputation with this faction, which is COALITION's StartingReputation (500, Neutral)
        # for every other NPC, so a COALITION behavior on an Enemy-only profile never picks a GAALSIEN target. It needs a faction-based profile.
        if ($spawnedAs -and $spawnedAs.Contains('COALITION') -and $desc -match '\[TargetData:([^\]]+)\]') {
            $coalTarget = $Matches[1].Trim()
            $tp = $profiles[$coalTarget]
            if ($tp -and $tp -match '\[MatchAllFilters:Relation\]' -and $tp -match '\[Relations:Enemy\]') {
                $warnings.Add("${name}: spawns as COALITION but targets with $coalTarget, which needs an Enemy relation it never gets from other NPCs; use GVK-Universal-Target-EnemyGAALSIENBeacon")
            }
            # Forced targets (attacker, turret target, a squadmate's target) use the override profile, and MES's default one is Enemy-only too.
            if ($tp -and $tp -match '\[FactionTargets:GAALSIEN\]' -and $desc -notmatch '\[OverrideTargetData:GVK-Universal-Target-Override-COALITION\]') {
                $warnings.Add("${name}: spawns as COALITION and fights GAALSIEN but lacks [OverrideTargetData:GVK-Universal-Target-Override-COALITION], so it drops every forced GAALSIEN target")
            }
        }
        # Every behavior that can force a target ([SwitchToReceivedTarget:true]) sets a GVK override profile. MES's default one would let a grid
        # that KOTH shot for breaking the rules fire back at the KOTH structures.
        $trigNames = @([regex]::Matches($desc, '\[Triggers:([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value.Trim() })
        foreach ($g in [regex]::Matches($desc, '\[TriggerGroups:([^\]]+)\]')) {
            $gd = $profiles[$g.Groups[1].Value.Trim()]
            if ($gd) { $trigNames += @([regex]::Matches($gd, '\[Triggers:([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value.Trim() }) }
        }
        $forcesTarget = $false
        foreach ($tn in $trigNames) {
            $td = $profiles[$tn]
            if (-not $td) { continue }
            foreach ($a in [regex]::Matches($td, '\[Actions:([^\]]+)\]')) {
                if ($profiles[$a.Groups[1].Value.Trim()] -match '\[SwitchToReceivedTarget:true\]') { $forcesTarget = $true }
            }
        }
        if ($forcesTarget -and $desc -notmatch '\[OverrideTargetData:GVK-Universal-Target-Override(-COALITION)?\]') {
            $warnings.Add("${name}: can force a target but lacks [OverrideTargetData:GVK-Universal-Target-Override] (or -COALITION), so it would fire back at KOTH")
        }
        # Every Unit on a Patrol<Name> group carries exactly one leash group; the leash is inert without a parent.
        if ($desc -match '\[TriggerGroups:GVK-Unit-All-TriggerGroup-Patrol\w+\]') {
            $leashes = [regex]::Matches($desc, '\[TriggerGroups:GVK-Unit-All-TriggerGroup-Leash(Ground|Air)\]').Count
            if ($leashes -ne 1) { $warnings.Add("${name}: has $leashes of GVK-Unit-All-TriggerGroup-LeashGround/-LeashAir; it needs exactly one") }
        }
        # A behavior that spawns Units of its own side (Defense waves, air support, Elite escorts) sends their leash signal.
        $spawnsUnits = $desc -match '\[TriggerGroups:GVK-Universal-TriggerGroup-SpawnDefenses\]' -or $desc -match '\[Triggers:GVK-Unit-(All|Elite)-Trigger-Spawn(AirSupport|MediumEscorts)\]'
        if ($spawnsUnits -and $desc -notmatch '\[TriggerGroups:GVK-Universal-TriggerGroup-LeashBeacon\]') { $warnings.Add("${name}: spawns Units but lacks GVK-Universal-TriggerGroup-LeashBeacon") }
        # Every Unit on a Patrol<Name> group can create KPLs on engaging (only while it has no parent), except COALITION ones (they don't target players).
        if ($spawnedAs -and $desc -match '\[TriggerGroups:GVK-Unit-All-TriggerGroup-Patrol\w+\]') {
            $hasKpl = $desc -match '\[TriggerGroups:GVK-Unit-All-TriggerGroup-CombatKPL\]'
            if ($spawnedAs.Contains('COALITION') -and $hasKpl) { $warnings.Add("${name}: spawns as COALITION but has GVK-Unit-All-TriggerGroup-CombatKPL") }
            elseif (-not $spawnedAs.Contains('COALITION') -and -not $hasKpl) { $warnings.Add("${name}: spawns as $(@($spawnedAs) -join '/') but lacks GVK-Unit-All-TriggerGroup-CombatKPL") }
        }
        # A per-faction copy ([//CopyOf:X]) must match its original apart from the bank line and a -GAALSIEN/-DERELICT target profile.
        if ($desc -match '\[//CopyOf:([^\]]+)\]') {
            $original = $Matches[1].Trim()
            if (-not $profiles.ContainsKey($original)) { $warnings.Add("${name}: [//CopyOf:$original] names a missing behavior") }
            elseif ((& $stripBank $desc) -ne (& $stripBank $profiles[$original])) {
                $warnings.Add("${name}: differs from $original beyond the [DialogueBanks:] and [TargetData:] lines; edit both copies")
            }
        }
        $banks = @([regex]::Matches($desc, '\[DialogueBanks:([^\]]+)\]') | ForEach-Object { $_.Groups[1].Value.Trim() })
        if (-not $banks.Count) {
            if ($desc -match '\[TriggerGroups:GVK-Universal-TriggerGroup-DefeatedAndAttacked\]') {
                if ($name -notin $noBankAllowed) { $warnings.Add("${name}: no [DialogueBanks:] line; it will never play attacked chatter") }
                $setsNoLastWords = [regex]::Matches($desc, '\[Triggers:([^\]]+)\]') | ForEach-Object { [regex]::Matches([string]$profiles[$_.Groups[1].Value.Trim()], '\[Actions:([^\]]+)\]') } |
                    Where-Object { [string]$profiles[$_.Groups[1].Value.Trim()] -match '\[SetBooleansTrue:GVK_NoLastWords\]' }
                if (-not $setsNoLastWords) { $warnings.Add("${name}: no bank and no [SetBooleansTrue:GVK_NoLastWords] in an init action; its defeat would go unannounced") }
            }
            continue
        }
        foreach ($bank in $banks) {
            if ($bank -cnotmatch '^GVK-(Units|Travellers|Structures|Installations)-([A-Z]+)-(Small|Medium|Large)\.xml$') {
                $warnings.Add("${name}: bank $bank does not follow GVK-<Units|Travellers|Structures|Installations>-<FACTION>-<Small|Medium|Large>.xml")
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
            if (-not ($category -eq 'Units' -and $bank -like '*-Small.xml')) { $needed += 'Defeated' }   # Small Units have no last words
            if ($bankFaction -notin $hostileFactions) { $needed += 'NeutralAttacked', 'FriendlyFire' }
            if ($category -eq 'Units') {
                $needed += 'TargetAcquired', 'NoTargets', 'TargetStructure', 'TargetAircraft', 'TargetInfantry', 'TargetFastMover', 'TargetLongRange'
            }
            foreach ($cue in $needed | Where-Object { $_ -notin $cues }) { $warnings.Add("${bank}: missing the $cue cue") }
        }
    }
    # Banks are generated from Docs/dialogue/drafts; flag drafts or behaviors that changed without a rebuild.
    if (Get-Command python -ErrorAction SilentlyContinue) {
        $build = & python (Join-Path $root 'Docs\dialogue\scripts\build_banks.py') --check 2>&1
        if ($LASTEXITCODE -ne 0) {
            $build | Where-Object { $_ -match '^(WOULD|PROBLEM)' } | ForEach-Object { $warnings.Add("dialogue banks: $_ (run Docs/dialogue/scripts/build_banks.py)") }
        }
        # Line rules: counts, length, duplicates, the same line in two factions, unit-class self-reference.
        $draftCheck = & python (Join-Path $root 'Docs\dialogue\scripts\check_drafts.py') 2>&1
        if ($LASTEXITCODE -ne 0) {
            $voice = ''
            foreach ($l in $draftCheck) {
                if ($l -match '^(\S+): \d+ lines') { $voice = $Matches[1] }
                elseif ($l -match '^\s{4}(.+)$') { $warnings.Add("dialogue draft ${voice}: $($Matches[1])") }
            }
        }
    }

    # MES only runs a [Type:DespawnMES] trigger when [DespawnTypeFromSpawner:] matches why the grid was removed; an empty type matches only
    # /MES.Debug.RemoveAllNpcs, so the trigger silently never fires (GVK-Settings#698). Use Any, which also covers the behavior's own despawn.
    foreach ($name in $profiles.Keys | Sort-Object) {
        $desc = $profiles[$name]
        if ($desc -match '\[Type:DespawnMES\]' -and $desc -notmatch '\[DespawnTypeFromSpawner:[^\]]+\]') {
            $warnings.Add("${name}: [Type:DespawnMES] without [DespawnTypeFromSpawner:] never fires; add [DespawnTypeFromSpawner:Any]")
        }
    }

    # Glossary words to avoid in prefab names, profile and spawn group IDs, and beacon text (GLOSSARY.md _Avoid_ lines).
    # "Outpost" belongs to alliance Outposts only; vanilla spawn group names are exempt.
    $avoidNames = [ordered]@{
        '(?i)turret ?station' = 'Turret Post (Coalition) or Turret (alliance)'
        '(?i)(cargo|ammo|loot) ?drop' = 'Cache'
        '(?i)outpost' = 'Outpost is only an alliance structure; KOTH Camp, Trade Station or a wreck name'
    }
    $vanillaNames = @(
        'P\d+_\w*Outpost\w*'                              # vanilla spawn group names
    )
    $names = @(Get-ChildItem 'Content\Data\Prefabs', 'Content\Data\StorePrefabs' -Filter *.sbc | ForEach-Object { $_.BaseName })
    $names += @($profiles.Keys)
    foreach ($f in Get-ChildItem 'Content\Data' -Recurse -Filter *.sbc | Where-Object { $_.FullName -notmatch '\\(Store)?Prefabs\\' }) {
        $t = [IO.File]::ReadAllText($f.FullName)
        $names += @([regex]::Matches($t, '<SpawnGroup>\s*<Id>\s*<TypeId>[^<]*</TypeId>\s*<SubtypeId>([^<]+)</SubtypeId>') | ForEach-Object { $_.Groups[1].Value })
        $names += @([regex]::Matches($t, '<BeaconText>([^<]+)</BeaconText>') | ForEach-Object { $_.Groups[1].Value })
    }
    foreach ($n in $names | Sort-Object -Unique) {
        if ($n -match 'Alliance|^NAS |^Outpost$' -or @($vanillaNames | Where-Object { $n -match "^$_$" }).Count) { continue }
        foreach ($p in $avoidNames.Keys) {
            if ($n -match $p) { $warnings.Add("name '$n' uses a word GLOSSARY.md avoids; use $($avoidNames[$p])") }
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
                if ($name -match '^(GVK|Drone|Unit|RAI)-[A-Za-z0-9-]+$') {
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
