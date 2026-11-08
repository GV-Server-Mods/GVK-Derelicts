<#
.SYNOPSIS
    Generates the parent leash: GVK-Universal-TriggerGroup-LeashBeacon.sbc (parent side) and
    Unit-All-TriggerGroup-Leash.sbc (Unit side, one group per leash kind).
.DESCRIPTION
    A parent (any grid whose [RivalAI Spawn] spawns Units) broadcasts one home signal per kind every 5 s with
    [MatchReceiverChild:true], so only the Units it spawned hear it. [MatchSenderReceiverOwners:false] because a DERELICT
    wreck spawns GAALSIEN Defense Units. Each signal carries the parent's position (SendWaypoint). On
    GVK-Universal-TriggerTags-Compromised it sends GVK_LeashRelease.
    A Unit carries the group for its kind (ground or air):
    - Home heard: GVK_HasParent true (CombatKPL then never creates a KPL), GVK_AwayFromHome false, patrol centre moved
      to the parent (UseCommandWaypointAsPatrolReference), restart the LeftHome timer, stop the Orphaned timer.
    - LeftHome (no signal for 15 s): GVK_AwayFromHome true (GVK-Unit-All-Condition-CanStartCombat refuses combat) and
      GVK-TriggerTags-SwitchToPatrol, so the Unit patrols back around where it last heard its parent. Starts the
      Orphaned timer.
    - Orphaned (still no signal 3 min later) or GVK_LeashRelease: the leash lets go, the patrol centre goes back to the
      spawn point (ClearCustomPatrolReference) and the Unit fights anywhere. This also covers a parent that despawned,
      or moved off with no Compromised event.
    Escort slots (GVK-Settings#764): Patrol picks up a moved centre only when it reaches a patrol point, so Units can't
    follow a parent that moves. A moving parent (Freighters) also carries GVK-Universal-TriggerGroup-LeashSlots and
    [EscortOffsets:] lines: every 5 s it offers a slot to its own children of its own faction, and Units of a kind with
    Slots = $true fly in the slot (Escort, Tertiary wing autopilot). A Unit leaves the slot when its Patrol<Name> group
    starts combat (GVK-TriggerTags-CombatStarted) and asks again once it is back on Patrol.
    The table below is the only source; change it and rerun to regenerate both files.
.EXAMPLE
    pwsh tools/New-LeashGroup.ps1
#>
param(
    [string]$EncountersDir = (Join-Path $PSScriptRoot '..\Content\Data\Encounters')
)

# Kind: group suffix and command code suffix. Radius: leash radius (m). Note: who carries it.
# Slots: takes escort slots from a moving parent. Every Unit of such a kind needs a wing autopilot in Tertiary.
$kinds = @(
    @{ Kind = 'Ground'; Radius = 3000; Slots = $false; Note = 'ground and hover Units' }
    @{ Kind = 'Air';    Radius = 5000; Slots = $true;  Note = 'aircraft (Strike Fighters, Interceptors, Bombers, flyers)' }
)
$beaconMs = 5000; $leftHomeMs = 15000; $orphanedMs = 180000
# Must reach a released Unit wherever it chased to after the leash fired; well beyond the largest radius.
$releaseRadius = 15000
# Escort slots. The radius is above the air leash so a Unit left behind by a 60 m/s Freighter after a fight can still rejoin.
# SlotNotFound must stay well under the wing autopilot's WaypointWaitTimeTrigger (AirWing 30 s), or a Unit that got a
# reply without a slot falls into MES's one-way Escort Retreat first. After SlotNotFound the Unit waits SlotRetry.
$slotOfferMs = 5000; $slotRadius = 8000; $slotTimeoutMs = 4000; $slotNotFoundMs = 5000; $slotRetryMs = 60000

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

function Command($subtype, $code, $radius, $waypoint) {
    $sendWaypoint = if ($waypoint) { "`r`n			[SendWaypoint:true]`r`n			[Waypoint:$waypoint]" } else { '' }
    Component $subtype @"
			[RivalAI Command]
			[CommandCode:$code]
			[SingleRecipient:false]
			[MatchSenderReceiverOwners:false]
			[MatchReceiverChild:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$radius]
			[CommandDelayTicks:0]$sendWaypoint
"@
}

function Write-Sbc($path, $comment, $parts) {
    $text = @"
<?xml version="1.0"?>
<Definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<EntityComponents>
		<!--
$comment
		-->
"@ + "`r`n" + ($parts -join "`r`n") + "`r`n" + @"
	</EntityComponents>
</Definitions>
"@ + "`r`n"
    $text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
    [IO.File]::WriteAllText($path, $text, (New-Object Text.UTF8Encoding($false)))
    Write-Host "Wrote $path"
}

# Parent side
$b = 'GVK-Universal-LeashBeacon'
$parts = @()
$parts += Component 'GVK-Universal-TriggerGroup-LeashBeacon' @"
			[RivalAI TriggerGroup]
			[Triggers:$b-Trigger-Broadcast]
			[Triggers:$b-Trigger-Release]
"@
$parts += Component "$b-Trigger-Broadcast" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Timer]
			[StartsReady:true]
			[MinCooldownMs:$beaconMs]
			[MaxCooldownMs:$($beaconMs + 1)]
			[MaxActions:-1]
			[Actions:$b-Action-Broadcast]
"@
$parts += Component "$b-Action-Broadcast" (@"
			[RivalAI Action]
			[BroadcastCommandProfiles:true]
"@ + "`r`n" + (($kinds | ForEach-Object { "			[CommandProfileIds:$b-Command-$($_.Kind)]" }) -join "`r`n"))
foreach ($k in $kinds) { $parts += Command "$b-Command-$($k.Kind)" "GVK_Leash$($k.Kind)" $k.Radius "$b-Waypoint-Self" }
# The parent's own position. RelativeOffset (not EntityOffset) so the waypoint turns invalid once the parent closes,
# and the child then keeps its last centre.
$parts += Component "$b-Waypoint-Self" @"
			[RivalAI Waypoint]
			[Waypoint:RelativeOffset]
			[RelativeEntity:Self]
			[Offset:{X:0 Y:0 Z:0}]
"@
$parts += Component "$b-Trigger-Release" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Manual]
			[Tags:GVK-Universal-TriggerTags-Compromised]
			[StartsReady:true]
			[MaxActions:1]
			[Actions:$b-Action-Release]
"@
$parts += Component "$b-Action-Release" @"
			[RivalAI Action]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$b-Command-Release]
"@
$parts += Command "$b-Command-Release" 'GVK_LeashRelease' $releaseRadius

# Escort slots, parent side. The offer needs the same owner and the child filter, so the enemy attackers a Freighter
# spawns never take a slot. BroadcastCommandProfiles runs before AssignEscortFromCommand inside one action (ActionSystem.cs),
# so the reply goes out even when no slot was free; its 30-tick delay lets the assignment land first, and the Unit's
# SlotNotFound timer catches a reply that came without a slot.
$s = 'GVK-Universal-LeashSlots'
$parts += Component 'GVK-Universal-TriggerGroup-LeashSlots' @"
			[RivalAI TriggerGroup]
			[Triggers:$s-Trigger-Offer]
			[Triggers:$s-Trigger-Request]
"@
$parts += Component "$s-Trigger-Offer" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Timer]
			[StartsReady:true]
			[MinCooldownMs:$slotOfferMs]
			[MaxCooldownMs:$($slotOfferMs + 1)]
			[MaxActions:-1]
			[Actions:$s-Action-Offer]
"@
$parts += Component "$s-Action-Offer" @"
			[RivalAI Action]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$s-Command-Offer]
"@
$parts += Component "$s-Command-Offer" @"
			[RivalAI Command]
			[CommandCode:GVK_LeashSlotOffer]
			[SingleRecipient:false]
			[MatchSenderReceiverOwners:true]
			[MatchReceiverChild:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$slotRadius]
			[CommandDelayTicks:0]
"@
$parts += Component "$s-Trigger-Request" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:GVK_LeashSlotRequest]
			[StartsReady:true]
			[MaxActions:-1]
			[Actions:$s-Action-Request]
"@
$parts += Component "$s-Action-Request" @"
			[RivalAI Action]
			[AssignEscortFromCommand:true]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$s-Command-Assigned]
"@
$parts += Component "$s-Command-Assigned" @"
			[RivalAI Command]
			[CommandCode:GVK_LeashSlotAssigned]
			[ReturnToSender:true]
			[MatchSenderReceiverOwners:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$slotRadius]
			[CommandDelayTicks:30]
"@
$slotKinds = ($kinds | Where-Object { $_.Slots } | ForEach-Object { "-Leash$($_.Kind)" }) -join ', '
$radii =($kinds | ForEach-Object { "$($_.Kind) $($_.Radius) m" }) -join ', '
Write-Sbc (Join-Path $EncountersDir 'GVK-Universal-TriggerGroup-LeashBeacon.sbc') @"
			GENERATED by tools/New-LeashGroup.ps1. Do not edit by hand; change the table in the script and rerun it.
			Parent side of the leash (README note 46). Add [TriggerGroups:GVK-Universal-TriggerGroup-LeashBeacon] to every
			behavior whose [RivalAI Spawn] spawns Units of its own side: Defense waves, air support, Elite escorts.
			Every $($beaconMs / 1000) s it sends one home signal per leash kind ($radii) to the Units it spawned,
			carrying its position so they patrol around it as it moves; when Compromised it sends GVK_LeashRelease.
			Needs MES with MeridiusIX/Modular-Encounters-Systems#441 (UseCommandWaypointAsPatrolReference).
			A parent that moves also adds [TriggerGroups:GVK-Universal-TriggerGroup-LeashSlots] and [EscortOffsets:] lines
			(+X right, +Y up, +Z behind its Remote Control): every $($slotOfferMs / 1000) s it offers its own-faction children
			within $slotRadius m a slot, which Units on $slotKinds take (GVK-Settings#764).
"@ $parts

# Unit side
$parts = @()
foreach ($k in $kinds) {
    $n = "GVK-Unit-All-Leash$($k.Kind)"
    $slotNames = 'SlotOffered', 'SlotTimeout', 'SlotAssigned', 'SlotFound', 'SlotNotFound', 'SlotRetry', 'SlotBreakOff', 'SlotLost', 'SlotReleased'
    $slotTriggers = if ($k.Slots) { "`r`n" + (($slotNames | ForEach-Object { "			[Triggers:$n-Trigger-$_]" }) -join "`r`n") } else { '' }
    $parts += Component "GVK-Unit-All-TriggerGroup-Leash$($k.Kind)" @"
			[RivalAI TriggerGroup]
			[Triggers:$n-Trigger-HomeHeard]
			[Triggers:$n-Trigger-LeftHome]
			[Triggers:$n-Trigger-Orphaned]
			[Triggers:$n-Trigger-Released]$slotTriggers
"@
    $parts += Component "$n-Trigger-HomeHeard" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:GVK_Leash$($k.Kind)]
			[StartsReady:true]
			[MinCooldownMs:1000]
			[MaxCooldownMs:1001]
			[MaxActions:-1]
			[Actions:$n-Action-HomeHeard]
"@
    # Reset runs before Enable inside one action, so the timer restarts from now.
    $parts += Component "$n-Action-HomeHeard" @"
			[RivalAI Action]
			[SetBooleansTrue:GVK_HasParent]
			[SetBooleansFalse:GVK_AwayFromHome]
			[UseCommandWaypointAsPatrolReference:true]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$n-Trigger-LeftHome]
			[EnableTriggers:true]
			[EnableTriggerNames:$n-Trigger-LeftHome]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-Orphaned]
"@
    $parts += Component "$n-Trigger-LeftHome" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:$leftHomeMs]
			[MaxCooldownMs:$($leftHomeMs + 1)]
			[MaxActions:-1]
			[Actions:$n-Action-LeftHome]
"@
    # The boolean is set before ManuallyActivateTrigger runs; SwitchToPatrol skips wings (GVK-Unit-All-Condition-NotEscortRole).
    $parts += Component "$n-Action-LeftHome" @"
			[RivalAI Action]
			[SetBooleansTrue:GVK_AwayFromHome]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$n-Trigger-Orphaned]
			[EnableTriggers:true]
			[EnableTriggerNames:$n-Trigger-Orphaned]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-LeftHome]
			[ManuallyActivateTrigger:true]
			[ManuallyActivatedTriggerTags:GVK-TriggerTags-SwitchToPatrol]
"@
    $parts += Component "$n-Trigger-Orphaned" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:$orphanedMs]
			[MaxCooldownMs:$($orphanedMs + 1)]
			[MaxActions:-1]
			[Actions:$n-Action-Release]
"@
    $parts += Component "$n-Trigger-Released" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:GVK_LeashRelease]
			[StartsReady:true]
			[MaxActions:-1]
			[Actions:$n-Action-Release]
"@
    $parts += Component "$n-Action-Release" @"
			[RivalAI Action]
			[SetBooleansFalse:GVK_AwayFromHome]
			[ClearCustomPatrolReference:true]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-LeftHome]
			[DisableTriggerNames:$n-Trigger-Orphaned]
"@
    if (-not $k.Slots) { continue }

    # Escort slots, Unit side. Offered: a free Unit (not a wing, not asking anywhere, not fighting) asks for the slot and
    # stays on Patrol until the parent answers.
    $parts += Component "$n-Trigger-SlotOffered" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:GVK_LeashSlotOffer]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Unit-All-Condition-CanTakeSlot]
			[Actions:$n-Action-SlotRequest]
"@
    $parts += Component "$n-Action-SlotRequest" @"
			[RivalAI Action]
			[SetBooleansTrue:GVK_Slot_Requesting]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$n-Command-SlotRequest]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$n-Trigger-SlotTimeout]
			[EnableTriggers:true]
			[EnableTriggerNames:$n-Trigger-SlotTimeout]
"@
    $parts += Component "$n-Command-SlotRequest" @"
			[RivalAI Command]
			[CommandCode:GVK_LeashSlotRequest]
			[ReturnToSender:true]
			[MatchSenderReceiverOwners:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$slotRadius]
			[RequestEscortSlot:true]
			[CommandDelayTicks:30]
"@
    $parts += Component "$n-Trigger-SlotTimeout" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:$slotTimeoutMs]
			[MaxCooldownMs:$($slotTimeoutMs + 1)]
			[MaxActions:-1]
			[Actions:$n-Action-SlotTimeout]
"@
    $parts += Component "$n-Action-SlotTimeout" @"
			[RivalAI Action]
			[SetBooleansFalse:GVK_Slot_Requesting]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-SlotTimeout]
"@
    # Assigned: switch to Escort on the wing autopilot (an Escort never flies faster than its own IdealMaxSpeed, so the
    # 40 m/s Patrol profile can't keep up with a Freighter). Escort.cs raises BehaviorTriggerA on its first tick when the
    # slot is real (SlotFound); without one SlotNotFound sends the Unit back to Patrol.
    $parts += Component "$n-Trigger-SlotAssigned" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:GVK_LeashSlotAssigned]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Unit-All-Condition-SlotIsRequesting]
			[Actions:$n-Action-SlotJoin]
"@
    $parts += Component "$n-Action-SlotJoin" @"
			[RivalAI Action]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Escort]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Tertiary]
			[SetBooleansTrue:GVK_Role_Escort]
			[SetBooleansTrue:GVK_InParentSlot]
			[SetBooleansFalse:GVK_Slot_Requesting]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$n-Trigger-SlotNotFound]
			[EnableTriggers:true]
			[EnableTriggerNames:$n-Trigger-SlotFound]
			[EnableTriggerNames:$n-Trigger-SlotNotFound]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-SlotTimeout]
"@
    $parts += Component "$n-Trigger-SlotFound" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:BehaviorTriggerA]
			[StartsReady:true]
			[MaxActions:-1]
			[Actions:$n-Action-SlotFound]
"@
    $parts += Component "$n-Action-SlotFound" @"
			[RivalAI Action]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-SlotFound]
			[DisableTriggerNames:$n-Trigger-SlotNotFound]
"@
    # Leave the slot and go back to Patrol. LeaveEscortSlot runs before the subclass change, and the LeaderDead tag runs
    # last, after GVK_Role_Escort is false, so a Unit that holds a target takes its Patrol<Name> combat switch at once,
    # the same way a peer wing that lost its leader does.
    $leave = @"
			[LeaveEscortSlot:true]
			[SetBooleansFalse:GVK_Role_Escort]
			[SetBooleansFalse:GVK_InParentSlot]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Patrol]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Primary]
			[ManuallyActivateTrigger:true]
			[ManuallyActivatedTriggerTags:GVK-TriggerTags-LeaderDead]
			[ForceManualTriggerActivation:false]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-SlotFound]
			[DisableTriggerNames:$n-Trigger-SlotNotFound]
"@
    $parts += Component "$n-Trigger-SlotNotFound" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:$slotNotFoundMs]
			[MaxCooldownMs:$($slotNotFoundMs + 1)]
			[MaxActions:-1]
			[Actions:$n-Action-SlotNotFound]
"@
    # No slot (the parent was full): leave, and stop asking for SlotRetry so a spare Unit doesn't flip to Escort every offer.
    $parts += Component "$n-Action-SlotNotFound" (@"
			[RivalAI Action]
"@ + "`r`n" + $leave + "`r`n" + @"
			[DisableTriggerNames:$n-Trigger-SlotOffered]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$n-Trigger-SlotRetry]
			[EnableTriggers:true]
			[EnableTriggerNames:$n-Trigger-SlotRetry]
"@)
    $parts += Component "$n-Trigger-SlotRetry" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:$slotRetryMs]
			[MaxCooldownMs:$($slotRetryMs + 1)]
			[MaxActions:-1]
			[Actions:$n-Action-SlotRetry]
"@
    $parts += Component "$n-Action-SlotRetry" @"
			[RivalAI Action]
			[EnableTriggers:true]
			[EnableTriggerNames:$n-Trigger-SlotOffered]
			[DisableTriggers:true]
			[DisableTriggerNames:$n-Trigger-SlotRetry]
"@
    # Break off: every Patrol<Name> TargetNear fires GVK-TriggerTags-CombatStarted at its own distance, even while its
    # combat switch refuses an escort, so a slot Unit fights at the same range as on Patrol. Not while GVK_AwayFromHome:
    # CanStartCombat would refuse it, and it would flip between Patrol and the slot every offer; it flies home first.
    $parts += Component "$n-Trigger-SlotBreakOff" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Manual]
			[Tags:GVK-TriggerTags-CombatStarted]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Unit-All-Condition-SlotCanFight]
			[Actions:$n-Action-SlotLeave]
"@
    # Lost: Escort.cs raises BehaviorTriggerB when the parent stops being valid (destroyed, crippled, despawned).
    $parts += Component "$n-Trigger-SlotLost" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:BehaviorTriggerB]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Unit-All-Condition-InParentSlot]
			[Actions:$n-Action-SlotLeave]
"@
    $parts += Component "$n-Trigger-SlotReleased" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:GVK_LeashRelease]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Unit-All-Condition-InParentSlot]
			[Actions:$n-Action-SlotLeave]
"@
    $parts += Component "$n-Action-SlotLeave" (@"
			[RivalAI Action]
"@ + "`r`n" + $leave)
}
if ($kinds | Where-Object { $_.Slots }) {
    $parts += Component 'GVK-Unit-All-Condition-CanTakeSlot' @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckFalseBooleans:true]
			[FalseBooleans:GVK_Role_Escort]
			[FalseBooleans:GVK_Peer_Requesting]
			[FalseBooleans:GVK_Slot_Requesting]
			[FalseBooleans:GVK_InCombat]
"@
    $parts += Component 'GVK-Unit-All-Condition-SlotIsRequesting' @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_Slot_Requesting]
"@
    $parts += Component 'GVK-Unit-All-Condition-InParentSlot' @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_InParentSlot]
"@
    $parts += Component 'GVK-Unit-All-Condition-SlotCanFight' @"
			[RivalAI Condition]
			[UseConditions:true]
			[MatchAnyCondition:false]
			[CheckTrueBooleans:true]
			[TrueBooleans:GVK_InParentSlot]
			[CheckFalseBooleans:true]
			[FalseBooleans:GVK_AwayFromHome]
"@
}
$groups = ($kinds | ForEach-Object { "			[TriggerGroups:GVK-Unit-All-TriggerGroup-Leash$($_.Kind)]: $($_.Note), $($_.Radius) m" }) -join "`r`n"
Write-Sbc (Join-Path $EncountersDir 'Unit\Unit-All-TriggerGroup-Leash.sbc') @"
			GENERATED by tools/New-LeashGroup.ps1. Do not edit by hand; change the table in the script and rerun it.
			Unit side of the leash (README note 46). Every Unit on a Patrol<Name> group carries exactly one of:
$groups
			A Unit that never hears a home signal (no parent) is unaffected.
			Booleans: GVK_HasParent (heard its parent at least once), GVK_AwayFromHome (no signal for $($leftHomeMs / 1000) s).
			Escort slots ($slotKinds): a parent with GVK-Universal-TriggerGroup-LeashSlots offers slots; the Unit flies
			in one on its Tertiary (wing) autopilot, leaves it when its Patrol<Name> group starts combat, and asks again
			once it is back on Patrol (GVK-Settings#764).
			Booleans: GVK_InParentSlot (holds or is joining a parent's slot; GVK_Role_Escort is true too), GVK_Slot_Requesting.
"@ $parts
