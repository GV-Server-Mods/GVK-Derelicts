# Claude Code Stop hook: rebuilds and deploys the mod (MDK2 -> %AppData%\SpaceEngineers\Mods\GVK_Derelicts)
# when anything under Content/ changed since the last successful build. Prints a one-line status for the UI.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stampFile = Join-Path $root 'obj\.content-build-stamp'

$files = Get-ChildItem -Path (Join-Path $root 'Content') -Recurse -File
$stamp = '{0}|{1}' -f $files.Count, ($files | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum.Ticks

if ((Test-Path $stampFile) -and ((Get-Content $stampFile -Raw).Trim() -eq $stamp)) { exit 0 }

$out = & dotnet build (Join-Path $root 'GVK_Derelicts.csproj') -c Release -nologo -v q 2>&1
if ($LASTEXITCODE -eq 0) {
    New-Item -ItemType Directory -Force (Split-Path $stampFile) | Out-Null
    Set-Content -Path $stampFile -Value $stamp -NoNewline
    @{ systemMessage = "GVK_Derelicts built and deployed $(Get-Date -Format HH:mm) - reload the world to test." } | ConvertTo-Json -Compress
} else {
    $err = ($out | Select-String -Pattern 'error' | Select-Object -First 3) -join ' | '
    @{ systemMessage = "GVK_Derelicts build FAILED: $err" } | ConvertTo-Json -Compress
}
exit 0
