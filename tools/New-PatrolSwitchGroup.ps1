<#
.SYNOPSIS
    Generates the Patrol <-> combat switch trigger groups for Units (Unit-All-TriggerGroup-Patrol<Name>.sbc).
.DESCRIPTION
    Every group is the same template: a target inside -Near switches the Unit to its combat subclass on the Secondary
    autopilot; no target, or a target beyond -Far, switches it back to Patrol on the Primary autopilot (one TargetFar
    trigger with AllowTargetFarWithoutTarget; needs MES with PR #410, after 2.75.01).
    The groups below are the only ones; change the table and rerun to regenerate all of them.
    - GVK_InCombat is true while the Unit is on its combat subclass, so other groups can put it back in the right state.
    - Wings (GVK_Role_Escort) never switch. A Unit enters combat only while it holds a target.
    - Both switches carry GVK-TriggerTags-LeaderDead: an escort whose leader died enters combat if it holds a target,
      and a wing that paired up mid-fight returns to Patrol.
    - GVK-TriggerTags-CombatStarted (fired on TargetNear) and GVK-TriggerTags-SwitchToPatrol let optional groups hook
      in without names; GVK-Unit-All-TriggerGroup-CombatKPL uses both.
.EXAMPLE
    pwsh tools/New-PatrolSwitchGroup.ps1
.EXAMPLE
    pwsh tools/New-PatrolSwitchGroup.ps1 -Name Horsefly
#>
param(
    [string[]]$Name,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\Content\Data\Encounters\Unit')
)

# Name: group suffix. Subclass: combat behavior subclass. Near/Far: TargetNear/TargetFar distances (m); keep Far >= Near
# so a Unit at the boundary doesn't flip, and both inside the target profile's MaxDistance / MaxExistingTargetDistance.
$groups = @(
    @{ Name = 'Horsefly';          Subclass = 'Horsefly';     Near = 2000; Far = 2000; Note = 'Circles its target at the offset distance; for turret-armed Units.' }
    @{ Name = 'HorseFighter';      Subclass = 'HorseFighter'; Near = 2000; Far = 2000; Note = 'Circles, then makes gun runs; for hover Units with forward guns.' }
    @{ Name = 'Fighter';           Subclass = 'Fighter';      Near = 2000; Far = 2000; Note = 'Strafes with its nose on the target; needs thrusters on all six sides.' }
    @{ Name = 'Strike';            Subclass = 'FighterPlane'; Near = 4000; Far = 5500; Note = 'Attack runs from a line-up point; Strike Fighters (4 km target profile).' }
    @{ Name = 'FighterPlaneLarge'; Subclass = 'FighterPlane'; Near = 4800; Far = 6500; Note = 'Attack runs from a line-up point; large flyers.' }
)
if ($Name) { $groups = @($groups | Where-Object { $Name -contains $_.Name }) }

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

foreach ($g in $groups) {
    $n = $g.Name; $sub = $g.Subclass
    $id = "GVK-Unit-All-Patrol$n"
    $parts = @()
    $parts += Component "GVK-Unit-All-TriggerGroup-Patrol$n" @"
			[RivalAI TriggerGroup]
			[Triggers:$id-ManualTrigger-SwitchTo$sub]
			[Triggers:$id-ManualTrigger-SwitchToPatrol]
			[Triggers:$id-Trigger-TargetNear]
			[Triggers:$id-Trigger-TargetFar]
"@
    # The two switches toggle each other, so exactly one is enabled: SwitchTo<combat> while patrolling.
    $parts += Component "$id-ManualTrigger-SwitchTo$sub" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Manual]
			[Tags:GVK-TriggerTags-LeaderDead]
			[StartsReady:true]
			[MinCooldownMs:5000]
			[MaxCooldownMs:5001]
			[Conditions:GVK-Unit-All-Condition-CanStartCombat]
			[Actions:$id-Action-SwitchTo$sub]
			[ToggleWithTriggerProfile:$id-ManualTrigger-SwitchToPatrol]
"@
    $parts += Component "$id-Action-SwitchTo$sub" @"
			[RivalAI Action]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:$sub]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Secondary]
			[SetBooleansTrue:GVK_InCombat]
"@
    $parts += Component "$id-ManualTrigger-SwitchToPatrol" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Manual]
			[Tags:GVK-TriggerTags-LeaderDead]
			[Tags:GVK-TriggerTags-SwitchToPatrol]
			[StartsReady:true]
			[Conditions:GVK-Unit-All-Condition-NotEscortRole]
			[Actions:$id-Action-SwitchToPatrol]
			[ToggleWithTriggerProfile:$id-ManualTrigger-SwitchTo$sub]
"@
    $parts += Component "$id-Action-SwitchToPatrol" @"
			[RivalAI Action]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Patrol]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Primary]
			[SetBooleansFalse:GVK_InCombat]
"@
    $parts += Component "$id-Trigger-TargetNear" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:TargetNear]
			[StartsReady:true]
			[MinCooldownMs:5000]
			[MaxCooldownMs:5001]
			[TargetDistance:$($g.Near)]
			[Actions:$id-Action-TargetNear]
"@
    $parts += Component "$id-Action-TargetNear" @"
			[RivalAI Action]
			[ManuallyActivateTrigger:true]
			[ManuallyActivatedTriggerNames:$id-ManualTrigger-SwitchTo$sub]
			[ManuallyActivatedTriggerTags:GVK-TriggerTags-CombatStarted]
"@
    # A state check, so it can't miss the loss the way a LostTarget edge during a cooldown can (GVK-Settings#706)
    $parts += Component "$id-Trigger-TargetFar" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:TargetFar]
			[AllowTargetFarWithoutTarget:true]
			[StartsReady:true]
			[MinCooldownMs:5000]
			[MaxCooldownMs:5001]
			[TargetDistance:$($g.Far)]
			[Actions:$id-Action-ReturnToPatrol]
"@
    $parts += Component "$id-Action-ReturnToPatrol" @"
			[RivalAI Action]
			[ManuallyActivateTrigger:true]
			[ManuallyActivatedTriggerNames:$id-ManualTrigger-SwitchToPatrol]
"@

    $header = @"
<?xml version="1.0"?>
<Definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<EntityComponents>
		<!--
			GENERATED by tools/New-PatrolSwitchGroup.ps1 (group $n). Do not edit by hand; change the table in the script and rerun it.
			Patrol <-> $sub. $($g.Note)
			Behavior: [TriggerGroups:GVK-Unit-All-TriggerGroup-Patrol$n], Primary autopilot for Patrol, Secondary for $sub.
			Add [TriggerGroups:GVK-Unit-All-TriggerGroup-CombatKPL] for every faction except COALITION.
			Add [TriggerGroups:GVK-Unit-All-TriggerGroup-LeashGround] or -LeashAir (tools/New-LeashGroup.ps1) to every Unit.
			Switches at $($g.Near) m (TargetNear), back to Patrol beyond $($g.Far) m or with no target (TargetFar).
			Booleans: GVK_InCombat (on $sub).
		-->
"@
    $footer = @"
	</EntityComponents>
</Definitions>
"@
    $text = $header + "`r`n" + ($parts -join "`r`n") + "`r`n" + $footer + "`r`n"
    $text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
    $out = Join-Path $OutDir "Unit-All-TriggerGroup-Patrol$n.sbc"
    [IO.File]::WriteAllText($out, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Wrote $out"
}
