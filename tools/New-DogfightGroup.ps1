<#
.SYNOPSIS
    Generates the dogfight switch trigger groups for aircraft that fight on FighterPlane (Unit-All-TriggerGroup-<Name>Dogfight.sbc).
.DESCRIPTION
    FighterPlane attack runs are built for ground targets. Against an aircraft the line-up point moves with the target, so a
    profile that lines up above its target (or holds a high minimum altitude) climbs with it, and the next run lines up
    straight ahead of the plane, so a chased plane keeps flying away from the fight. Every group is the same template:
    - ToDogfight: in combat on FighterPlane, not a wing, target more than 100 m above the surface: the Dogfight profile goes
      into the Secondary slot, the subclass becomes Strike (line-up points all around the target), GVK_Dogfight true.
    - ToStrike: target back under 60 m: the attack-run profile goes back into Secondary, subclass FighterPlane.
    - Reset: combat over (the Patrol<Name> group already set Patrol): the attack-run profile goes back, so the next fight
      starts with attack runs.
    - Chased: in a dogfight with the target behind the plane (120 degrees or more off its nose) and flying at it (within
      45 degrees): pick a new line-up point. A Strike line-up point keeps its direction from the target until it expires, so
      when the target chases the plane a point on the plane's side runs ahead of it at the target's speed and the plane flees
      until OffsetRecalculationTime. While lining up Strike ignores BehaviorSpecificEventA (it only ends a run) and MES never
      parses BehaviorSpecificEventB, so the new point comes from switching the subclass to FighterPlane and straight back to
      Strike, which restarts Strike and picks a new random direction. Checked every 10 s, so a slow plane has time to turn
      towards the new point.
    - RunStart, RunLimit, RunEnd: a run ends only within the breakaway distance of the target, so two planes on runs at each
      other at the same speed never end them and circle upward (see $runMaxSeconds below). Strike raises BehaviorTriggerB when
      a run starts: RunStart sets GVK_AttackRun and restarts the RunLimit timer, and RunLimit ends a run still going
      $runMaxSeconds s later (BehaviorSpecificEventA). RunEnd clears GVK_AttackRun when a run ends (BehaviorTriggerA).
      GVK_AttackRun keeps RunLimit from ending a new run in the tick it starts, before the timer restart: MES checks every
      trigger before it runs any action. Every action here that restarts Strike clears it too.
    - Break (groups with a Break profile only): a new point still moves with a target that follows the plane, and Strike
      starts no run with the target inside the breakaway distance. So Chased loads the Break profile instead, which starts
      the run at once and turns the plane at its chaser; BreakEnd puts the Dogfight profile back when that run ends
      (Strike raises BehaviorTriggerA). GVK_Break is true meanwhile, so Chased waits. Breaks happen at any height: RunLimit
      ends a break that never closes on its chaser (a 2500 m ceiling on Chased didn't stop the climb, since it doesn't end a
      break already going, and above it a chased plane fled; dropped, owner 2026-11-09).
    Needs MES with the OverwriteAutopilotProfile fix (MeridiusIX/Modular-Encounters-Systems#464): without it the swap undoes itself.
    The groups below are the only ones; change the table and rerun to regenerate all of them. Test-Docs checks that every
    Unit on a FighterPlane Patrol<Name> group carries the group whose Attack profile is its Secondary autopilot.
.EXAMPLE
    pwsh tools/New-DogfightGroup.ps1
.EXAMPLE
    pwsh tools/New-DogfightGroup.ps1 -Name StrikeFighter
#>
param(
    [string[]]$Name,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\Content\Data\Encounters\Unit')
)

# Name: group prefix. Attack: the behavior's Secondary (attack-run) autopilot. Dogfight: the profile swapped in against
# aircraft. Patrol: the behavior's Patrol<Name> group (its combat subclass must be FighterPlane). Break (optional): the
# profile Chased loads to turn the plane at its chaser instead of picking a new line-up point.
$groups = @(
    @{ Name = 'StrikeFighter';                Patrol = 'Strike';            Note = 'Strike Fighters (COALITION, SOBAN).'
       Attack = 'GVK-Unit-All-Autopilot-StrikeFighter-Strike';                Dogfight = 'GVK-Unit-All-Autopilot-StrikeFighter-Dogfight'
       Break = 'GVK-Unit-All-Autopilot-StrikeFighter-Break' }
    @{ Name = 'LargeFlyerFighterPlane';       Patrol = 'FighterPlaneLarge'; Note = 'Large flyers with fixed forward guns (Chad Shuttle, GR-650).'
       Attack = 'GVK-Unit-All-Autopilot-LargeFlyerFighterPlane-Strike';       Dogfight = 'GVK-Unit-All-Autopilot-LargeFlyerFighterPlane-Dogfight'
       Break = 'GVK-Unit-All-Autopilot-LargeFlyerFighterPlane-Break' }
    @{ Name = 'SmallFlyerPatrolHorseFighter'; Patrol = 'Strike';            Note = 'Small flyers with forward guns.'
       Attack = 'GVK-Unit-All-Autopilot-SmallFlyerPatrolHorseFighter-HorseFighter'; Dogfight = 'GVK-Unit-All-Autopilot-SmallFlyerPatrolHorseFighter-Dogfight'
       Break = 'GVK-Unit-All-Autopilot-SmallFlyerPatrolHorseFighter-Break' }
)
if ($Name) { $groups = @($groups | Where-Object { $Name -contains $_.Name }) }

# A target above $up m is an aircraft, under $down m a ground target; the gap stops a target near one height flipping the switch.
$up = 100; $down = 60; $checkMs = 3000
# Chased: target at least $behindAngle degrees off the nose and its velocity within $chaseAngle degrees of pointing at the plane.
$behindAngle = 120; $chaseAngle = 45; $chasedMs = 10000
# Longest dogfight or break run (s). With LimitPitchTurning a plane whose target is behind it only pitches nose-up, so a run
# at a target circling beside or behind it climbs. A Foxhound on a break run and a Strike Fighter on a dogfight run at each other stayed
# 300-600 m apart, never inside the 200 m breakaway, and climbed past 7 km (GVK-Settings#742, 2026-11-09). MES has
# [AttackRunMaxTimeTrigger:] for this but never reads the tag; once it does, that replaces these triggers (GVK-Settings#765).
$runMaxSeconds = 10

function Component($subtype, $body) {
    @"
		<EntityComponent xsi:type="MyObjectBuilder_InventoryComponentDefinition">
			<Id>
				<TypeId>Inventory</TypeId>
				<SubtypeId>$subtype</SubtypeId>
			</Id>
			<Description>
$body
			</Description>
		</EntityComponent>
"@
}

function Timer($id, $step) {
    Component "$id-Trigger-$step" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Timer]
			[StartsReady:true]
			[MinCooldownMs:$checkMs]
			[MaxCooldownMs:$($checkMs + 1)]
			[Conditions:$id-Condition-$step]
			[Actions:$id-Action-$step]
"@
}

foreach ($g in $groups) {
    $n = $g.Name
    $id = "GVK-Unit-All-${n}Dogfight"
    # Lines that only groups with a Break profile get.
    $breakTrigger = ''; $breakClear = ''; $breakSkip = ''
    # Actions that restart Strike or leave the dogfight end any run without BehaviorTriggerA, so they clear the run flag.
    $runClear = "`r`n			[SetBooleansFalse:GVK_AttackRun]"
    if ($g.Break) {
        $breakTrigger = "`r`n			[Triggers:$id-Trigger-BreakEnd]"
        $breakClear = "`r`n			[SetBooleansFalse:GVK_Break]"
        $breakSkip = "`r`n			[FalseBooleans:GVK_Break]"    }
    $parts = @()
    $parts += Component "GVK-Unit-All-TriggerGroup-${n}Dogfight" @"
			[RivalAI TriggerGroup]
			[Triggers:$id-Trigger-ToDogfight]
			[Triggers:$id-Trigger-ToStrike]
			[Triggers:$id-Trigger-Reset]
			[Triggers:$id-Trigger-Chased]$breakTrigger
			[Triggers:$id-Trigger-RunStart]
			[Triggers:$id-Trigger-RunLimit]
			[Triggers:$id-Trigger-RunEnd]
"@
    $parts += "		<!-- In combat on FighterPlane, not a wing, target more than $up m up -->"
    $parts += Timer $id 'ToDogfight'
    $parts += Component "$id-Condition-ToDogfight" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_InCombat]
			[CheckFalseBooleans:true]
			[FalseBooleans:GVK_Role_Escort]
			[BehaviorSubclassCheck:true]
			[BehaviorSubclass:FighterPlane]
			[TargetAltitudeCheck:true]
			[MinTargetAltitude:$up]
			[MaxTargetAltitude:-1]
"@
    $parts += Component "$id-Action-ToDogfight" @"
			[RivalAI Action]
			[//DebugMessage:Dogfight on]
			[OverwriteAutopilotProfile:true]
			[OverwriteAutopilotMode:Secondary]
			[OverwriteAutopilotId:$($g.Dogfight)]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Strike]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Secondary]
			[SetBooleansTrue:GVK_Dogfight]$runClear
"@
    $parts += "		<!-- In combat, not a wing, target back under $down m -->"
    $parts += Timer $id 'ToStrike'
    $parts += Component "$id-Condition-ToStrike" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_InCombat]
			[TrueBooleans:GVK_Dogfight]
			[CheckFalseBooleans:true]
			[FalseBooleans:GVK_Role_Escort]
			[TargetAltitudeCheck:true]
			[MinTargetAltitude:-1]
			[MaxTargetAltitude:$down]
"@
    $parts += Component "$id-Action-ToStrike" @"
			[RivalAI Action]
			[//DebugMessage:Dogfight off]
			[OverwriteAutopilotProfile:true]
			[OverwriteAutopilotMode:Secondary]
			[OverwriteAutopilotId:$($g.Attack)]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:FighterPlane]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Secondary]
			[SetBooleansFalse:GVK_Dogfight]$breakClear$runClear
"@
    $parts += "		<!-- Combat over (Patrol already set by the Patrol$($g.Patrol) group): put the attack-run profile back so the next fight starts with attack runs -->"
    $parts += Timer $id 'Reset'
    $parts += Component "$id-Condition-Reset" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_Dogfight]
			[CheckFalseBooleans:true]
			[FalseBooleans:GVK_InCombat]
"@
    $parts += Component "$id-Action-Reset" @"
			[RivalAI Action]
			[//DebugMessage:Dogfight reset]
			[OverwriteAutopilotProfile:true]
			[OverwriteAutopilotMode:Secondary]
			[OverwriteAutopilotId:$($g.Attack)]
			[SetBooleansFalse:GVK_Dogfight]$breakClear$runClear
"@
    $parts += "		<!-- In a dogfight with the target behind and flying at the plane: restart Strike for a new line-up point instead of fleeing -->"
    $parts += Component "$id-Trigger-Chased" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Timer]
			[StartsReady:true]
			[MinCooldownMs:$chasedMs]
			[MaxCooldownMs:$($chasedMs + 1)]
			[Conditions:$id-Condition-Chased]
			[Actions:$id-Action-ChasedLeaveStrike]
			[Actions:$id-Action-ChasedBackToStrike]
"@
    $parts += Component "$id-Condition-Chased" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_InCombat]
			[TrueBooleans:GVK_Dogfight]
			[CheckFalseBooleans:true]
			[FalseBooleans:GVK_Role_Escort]$breakSkip
			[BehaviorSubclassCheck:true]
			[BehaviorSubclass:Strike]
			[CheckTargetAngleFromForward:true]
			[MinTargetAngle:$behindAngle]
			[MaxTargetAngle:-1]
			[CheckIfTargetIsChasing:true]
			[MinTargetChaseAngle:-1]
			[MaxTargetChaseAngle:$chaseAngle]
"@
    if ($g.Break) {
        $parts += Component "$id-Action-ChasedLeaveStrike" @"
			[RivalAI Action]
			[//DebugMessage:Chased: break turn]
			[OverwriteAutopilotProfile:true]
			[OverwriteAutopilotMode:Secondary]
			[OverwriteAutopilotId:$($g.Break)]
			[SetBooleansTrue:GVK_Break]$runClear
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:FighterPlane]
"@
    } else {
        $parts += Component "$id-Action-ChasedLeaveStrike" @"
			[RivalAI Action]
			[//DebugMessage:Chased: new line-up point]$runClear
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:FighterPlane]
"@
    }
    $parts += Component "$id-Action-ChasedBackToStrike" @"
			[RivalAI Action]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Strike]
"@
    if ($g.Break) {
        $parts += "		<!-- The break turn's attack run is over (Strike raises BehaviorTriggerA when a run ends): put the Dogfight profile back -->"
        $parts += Component "$id-Trigger-BreakEnd" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:BehaviorTriggerA]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:$id-Condition-BreakEnd]
			[Actions:$id-Action-BreakEnd]
"@
        $parts += Component "$id-Condition-BreakEnd" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_Break]
"@
        $parts += Component "$id-Action-BreakEnd" @"
			[RivalAI Action]
			[//DebugMessage:Break turn over]
			[OverwriteAutopilotProfile:true]
			[OverwriteAutopilotMode:Secondary]
			[OverwriteAutopilotId:$($g.Dogfight)]
			[SetBooleansFalse:GVK_Break]
"@
    }
    $parts += "		<!-- A dogfight run started (Strike raises BehaviorTriggerB): restart the RunLimit timer -->"
    $parts += Component "$id-Trigger-RunStart" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:BehaviorTriggerB]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:$id-Condition-RunStart]
			[Actions:$id-Action-RunStart]
"@
    $parts += Component "$id-Condition-RunStart" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_Dogfight]
"@
    $parts += Component "$id-Action-RunStart" @"
			[RivalAI Action]
			[SetBooleansTrue:GVK_AttackRun]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$id-Trigger-RunLimit]
"@
    $parts += "		<!-- A run still going $runMaxSeconds s after it started: end it (two planes on runs at each other never get inside the breakaway distance) -->"
    $parts += Component "$id-Trigger-RunLimit" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:$($runMaxSeconds * 1000)]
			[MaxCooldownMs:$($runMaxSeconds * 1000 + 1)]
			[Conditions:$id-Condition-RunLimit]
			[Actions:$id-Action-RunLimit]
"@
    $parts += Component "$id-Condition-RunLimit" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_Dogfight]
			[TrueBooleans:GVK_AttackRun]
			[BehaviorModeCheck:true]
			[CurrentBehaviorMode:EngageTarget]
"@
    $parts += Component "$id-Action-RunLimit" @"
			[RivalAI Action]
			[//DebugMessage:Run time up]
			[BehaviorSpecificEventA:true]
			[SetBooleansFalse:GVK_AttackRun]
"@
    $parts += "		<!-- The run is over (Strike raises BehaviorTriggerA) -->"
    $parts += Component "$id-Trigger-RunEnd" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:BehaviorTriggerA]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:$id-Condition-RunEnd]
			[Actions:$id-Action-RunEnd]
"@
    $parts += Component "$id-Condition-RunEnd" @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_AttackRun]
"@
    $parts += Component "$id-Action-RunEnd" @"
			[RivalAI Action]
			[SetBooleansFalse:GVK_AttackRun]
"@

    $breakNote = ''; $breakBoolean = ''
    if ($g.Break) {
        $breakNote = "`r`n			Break: a new point still moves with a target that follows the plane, and Strike starts no run with the target inside the breakaway distance, so Chased loads $($g.Break) instead: it starts the run at once and turns the plane at its chaser. BreakEnd puts the Dogfight profile back when the run ends."
        $breakBoolean = ', GVK_Break (the Secondary slot holds the Break profile)'
    }
    $header = @"
<?xml version="1.0"?>
<Definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<EntityComponents>
		<!--
			GENERATED by tools/New-DogfightGroup.ps1 (group $n). Do not edit by hand; change the table in the script and rerun it.
			Dogfight switch: $($g.Note)
			Against a target more than $up m above the surface, swap $($g.Attack) in the Secondary slot for $($g.Dogfight) and FighterPlane for Strike; swap back once the target is under $down m.
			FighterPlane lines up its next run straight ahead of the plane, so a chased plane keeps flying away from the fight; Strike picks a line-up point around the target, and the Dogfight profile keeps it close and level.
			Needs MES with the OverwriteAutopilotProfile fix (MeridiusIX/Modular-Encounters-Systems#464): without it the swap undoes itself.
			Chased: a Strike line-up point keeps its direction from the target, so when the target chases the plane the point can run ahead of it at the target's speed. With the target behind and flying at it, switching to FighterPlane and back restarts Strike, which picks a new point.$breakNote
			Run limit: a run ends only within the breakaway distance, so two planes on runs at each other at the same speed circle and climb without end. RunStart (BehaviorTriggerB) sets GVK_AttackRun and restarts the RunLimit timer; RunLimit ends a run still going after $runMaxSeconds s; RunEnd (BehaviorTriggerA) clears GVK_AttackRun.
			ToDogfight checks the subclass, not GVK_Dogfight: a plane that loses its target and picks up a new one before Reset runs is back in FighterPlane with the Dogfight profile still loaded, and this puts it in Strike.
			Behavior: [TriggerGroups:GVK-Unit-All-TriggerGroup-${n}Dogfight] after GVK-Unit-All-TriggerGroup-Patrol$($g.Patrol), with [SecondaryAutopilotData:$($g.Attack)].
			Booleans: GVK_Dogfight (the Secondary slot holds the Dogfight profile)$breakBoolean, GVK_AttackRun (a dogfight run is going).
		-->
"@
    $footer = @"
	</EntityComponents>
</Definitions>
"@
    $text = $header + "`r`n" + ($parts -join "`r`n") + "`r`n" + $footer + "`r`n"
    $text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
    $out = Join-Path $OutDir "Unit-All-TriggerGroup-${n}Dogfight.sbc"
    [IO.File]::WriteAllText($out, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Wrote $out"
}
