<#
.SYNOPSIS
    Generates the peer-escort trigger group for one Unit pool (see README note "Peer escort pools").
.DESCRIPTION
    Same-faction Units of one pool pair up on their own: a free peer offers to lead, another free peer asks for the
    slot and becomes its wing. Every pool uses its own command codes (GVK_Peer<Pool>_*), so pools never hear each other.
    To add a pool: run this script with a new -Pool name, include the generated group in each member's behavior
    (replace GVK-ConvoySystem-Escort-TriggerGroup) and give each member one [EscortOffsets:{X:.. Y:0 Z:..}] line.
.EXAMPLE
    pwsh tools/New-PeerEscortPool.ps1 -Pool Land -Radius 1500
#>
param(
    [Parameter(Mandatory)][ValidatePattern('^[A-Za-z]+$')][string]$Pool,
    [int]$Radius = 1500,
    [string]$OutDir = (Join-Path $PSScriptRoot '..\Content\Data\Encounters\Drone')
)

$p = $Pool
$id = "GVK-Drone-All-PeerEscort-$p"
$code = "GVK_Peer${p}"

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

$parts = @()
$parts += Component "GVK-Drone-All-TriggerGroup-PeerEscort-$p" @"
			[RivalAI TriggerGroup]
			[Triggers:$id-Trigger-Offer]
			[Triggers:$id-Trigger-Accept]
			[Triggers:$id-Trigger-ProcessRequest]
			[Triggers:$id-Trigger-Confirm]
			[Triggers:$id-Trigger-Timeout]
			[Triggers:$id-Trigger-LeaderLost]
			[Triggers:$id-Trigger-LeaderDead]
			[Triggers:$id-Trigger-WingLost]
			[Triggers:$id-ManualTrigger-Compromised]
"@

# Offer: a free peer announces it can lead
$parts += Component "$id-Trigger-Offer" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Timer]
			[Tags:GVK-TriggerTags-AvailableToEscort]
			[StartsReady:false]
			[MinCooldownMs:8000]
			[MaxCooldownMs:20000]
			[MaxActions:-1]
			[Conditions:GVK-Drone-All-Condition-PeerCanOffer]
			[ConditionCheckResetsTimer:true]
			[Actions:$id-Action-Offer]
"@
$parts += Component "$id-Action-Offer" @"
			[RivalAI Action]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$id-Command-Ready]
"@
$parts += Component "$id-Command-Ready" @"
			[RivalAI Command]
			[CommandCode:${code}_Ready]
			[MatchSenderReceiverOwners:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$Radius]
			[CommandDelayTicks:30]
"@

# Accept: a free peer hears an offer and asks for the slot. It stays in Patrol until the leader confirms.
$parts += Component "$id-Trigger-Accept" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:${code}_Ready]
			[Tags:GVK-TriggerTags-AvailableToEscort]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Drone-All-Condition-PeerCanAccept]
			[Actions:$id-Action-Accept]
"@
$parts += Component "$id-Action-Accept" @"
			[RivalAI Action]
			[SetBooleansTrue:GVK_Peer_Requesting]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$id-Command-Request]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownNames:$id-Trigger-Timeout]
			[EnableTriggers:true]
			[EnableTriggerNames:$id-Trigger-Timeout]
"@
$parts += Component "$id-Command-Request" @"
			[RivalAI Command]
			[CommandCode:${code}_Request]
			[ReturnToSender:true]
			[MatchSenderReceiverOwners:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$Radius]
			[RequestEscortSlot:true]
			[CommandDelayTicks:30]
"@

# ProcessRequest: the leader takes the slot and only then answers, so a reply always means "you have a slot"
$parts += Component "$id-Trigger-ProcessRequest" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:${code}_Request]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Drone-All-Condition-PeerCanLead]
			[Actions:$id-Action-ProcessRequest]
"@
$parts += Component "$id-Action-ProcessRequest" @"
			[RivalAI Action]
			[AssignEscortFromCommand:true]
			[SetBooleansTrue:GVK_Role_Leader]
			[SetBooleansTrue:GVK_Peer_SlotSpent]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$id-Command-Assigned]
"@
$parts += Component "$id-Command-Assigned" @"
			[RivalAI Command]
			[CommandCode:${code}_Assigned]
			[ReturnToSender:true]
			[MatchSenderReceiverOwners:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$Radius]
			[CommandDelayTicks:30]
"@

# Confirm: the slot is already assigned (ParentEscort is set), so the Escort behavior finds its leader on its first tick
$parts += Component "$id-Trigger-Confirm" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:${code}_Assigned]
			[StartsReady:true]
			[MaxActions:-1]
			[Conditions:GVK-Drone-All-Condition-PeerIsRequesting]
			[Actions:$id-Action-Confirm]
"@
$parts += Component "$id-Action-Confirm" @"
			[RivalAI Action]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Escort]
			[SetBooleansTrue:GVK_Role_Escort]
			[SetBooleansFalse:GVK_Peer_Requesting]
			[DisableTriggers:true]
			[DisableTriggerNames:$id-Trigger-Timeout]
			[ResetCooldownTimeOfTriggers:true]
			[ResetTriggerCooldownTags:GVK-TriggerTags-PeerActiveTasks]
			[EnableTriggers:true]
			[EnableTriggerTags:GVK-TriggerTags-PeerActiveTasks]
"@

# Timeout: no answer, so the peer is free to offer or accept again
$parts += Component "$id-Trigger-Timeout" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Type:Timer]
			[StartsReady:false]
			[MinCooldownMs:4000]
			[MaxCooldownMs:4001]
			[MaxActions:-1]
			[Actions:$id-Action-Timeout]
"@
$parts += Component "$id-Action-Timeout" @"
			[RivalAI Action]
			[SetBooleansFalse:GVK_Peer_Requesting]
			[DisableTriggers:true]
			[DisableTriggerNames:$id-Trigger-Timeout]
"@

# Leader gone (invalid while approaching, or told so by a LeaderDead command): back to Patrol, free to pair again
$parts += Component "$id-Trigger-LeaderLost" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Tags:GVK-TriggerTags-PeerActiveTasks]
			[Type:BehaviorTriggerB]
			[StartsReady:true]
			[MaxActions:-1]
			[Actions:$id-Action-LeaderLost]
"@
$parts += Component "$id-Trigger-LeaderDead" @"
			[RivalAI Trigger]
			[UseTrigger:false]
			[Tags:GVK-TriggerTags-PeerActiveTasks]
			[Type:CommandReceived]
			[CommandReceiveCode:${code}_LeaderDead]
			[StartsReady:true]
			[MaxActions:-1]
			[Actions:$id-Action-LeaderLost]
"@
$parts += Component "$id-Action-LeaderLost" @"
			[RivalAI Action]
			[SetBooleansFalse:GVK_Role_Escort]
			[ChangeBehaviorSubclass:true]
			[NewBehaviorSubclass:Patrol]
			[ChangeAutopilotProfile:true]
			[AutopilotProfile:Primary]
			[DisableTriggers:true]
			[DisableTriggerTags:GVK-TriggerTags-PeerActiveTasks]
			[ManuallyActivateTrigger:true]
			[ManuallyActivatedTriggerTags:GVK-TriggerTags-LeaderDead]
			[ForceManualTriggerActivation:false]
"@

# Compromised (destroyed, crippled, despawned or deleted): tell my wing, and tell my leader its slot is gone.
# Both commands use delay 0 because a delayed command from a closing grid is dropped.
$parts += Component "$id-ManualTrigger-Compromised" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:Manual]
			[Tags:GVK-Universal-TriggerTags-Compromised]
			[StartsReady:true]
			[MaxActions:1]
			[ActionExecution:All]
			[Actions:$id-Action-Compromised]
"@
$parts += Component "$id-Action-Compromised" @"
			[RivalAI Action]
			[BroadcastCommandProfiles:true]
			[CommandProfileIds:$id-Command-LeaderDead]
			[CommandProfileIds:$id-Command-WingLost]
			[SetBooleansFalse:GVK_Role_Leader]
"@
$parts += Component "$id-Command-LeaderDead" @"
			[RivalAI Command]
			[CommandCode:${code}_LeaderDead]
			[MatchSenderReceiverOwners:true]
			[MatchReceiverEscort:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$Radius]
			[CommandDelayTicks:0]
"@
$parts += Component "$id-Command-WingLost" @"
			[RivalAI Command]
			[CommandCode:${code}_WingLost]
			[MatchSenderReceiverOwners:true]
			[MatchReceiverLeader:true]
			[IgnoreAntennaRequirement:true]
			[IgnoreReceiverAntennaRequirement:true]
			[Radius:$Radius]
			[CommandDelayTicks:0]
"@
$parts += Component "$id-Trigger-WingLost" @"
			[RivalAI Trigger]
			[UseTrigger:true]
			[Type:CommandReceived]
			[CommandReceiveCode:${code}_WingLost]
			[StartsReady:true]
			[MaxActions:-1]
			[Actions:$id-Action-WingLost]
"@
$parts += Component "$id-Action-WingLost" @"
			[RivalAI Action]
			[SetBooleansFalse:GVK_Role_Leader]
"@

$header = @"
<?xml version="1.0"?>
<Definitions xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema">
	<EntityComponents>
		<!--
			GENERATED by tools/New-PeerEscortPool.ps1 -Pool $p -Radius $Radius. Do not edit by hand.
			Peer escorts for the $p pool: Units of this pool pair up with each other, never with another pool or a cruiser.
			Behavior: [TriggerGroups:GVK-Drone-All-TriggerGroup-PeerEscort-$p] and one [EscortOffsets:{X:.. Y:0 Z:..}] line.
			Needs the GV-Server-Mods MES fork (MatchReceiverEscort / MatchReceiverLeader, MeridiusIX/Modular-Encounters-Systems#384).
			Booleans: GVK_Role_Escort (wing), GVK_Role_Leader (has a live wing), GVK_Peer_Requesting (asked, no answer yet),
			GVK_Peer_SlotSpent (the single slot was used; MES never frees it, so this peer can only be a wing from then on).
		-->
"@
$footer = @"
	</EntityComponents>
</Definitions>
"@

$text = $header + "`r`n" + ($parts -join "`r`n") + "`r`n" + $footer + "`r`n"
$text = ($text -replace "`r`n", "`n") -replace "`n", "`r`n"
$out = Join-Path $OutDir "Drone-All-TriggerGroup-PeerEscort-$p.sbc"
[IO.File]::WriteAllText($out, $text, (New-Object Text.UTF8Encoding($false)))
Write-Host "Wrote $out"
