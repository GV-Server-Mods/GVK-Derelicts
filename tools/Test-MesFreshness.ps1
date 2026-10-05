# Claude Code SessionStart hook (wired up in .claude/settings.local.json).
# Warns when the local MES clone is behind upstream, or when the se-dev-mes skill's tag cache
# is behind the local MES clone. Prints one JSON systemMessage line, or nothing when both are current.
$ErrorActionPreference = 'SilentlyContinue'
$mes = Join-Path $env:APPDATA 'SpaceEngineers\Mods\Modular-Encounters-Systems'
$skill = Join-Path $HOME '.claude\skills\se-dev-mes'
$messages = @()

if (Test-Path (Join-Path $mes '.git')) {
    $job = Start-Job { git -C $using:mes fetch -q upstream 2>$null }
    if (Wait-Job $job -Timeout 15) {
        $behind = [int](git -C $mes rev-list --count 'HEAD..upstream/master' 2>$null)
        if ($behind -gt 0) { $messages += "Local MES clone is $behind commit(s) behind upstream/master." }
    }
    Remove-Job $job -Force
}

$sync = Join-Path $skill 'scripts\check_mes_sync.py'
if (Test-Path $sync) {
    & python $sync *> $null
    if ($LASTEXITCODE -eq 1) {
        $messages += "se-dev-mes tag cache is behind the local MES source; run: powershell -File `"$skill\scripts\Update-MesSkill.ps1`"."
    }
}

if ($messages) { @{ systemMessage = ($messages -join ' ') } | ConvertTo-Json -Compress }
exit 0
