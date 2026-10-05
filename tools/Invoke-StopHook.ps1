# Claude Code Stop hook (wired up in .claude/settings.local.json).
# When Content/ changed since the last run: rebuild and deploy the mod (MDK2 -> %AppData%\SpaceEngineers\Mods\GVK_Derelicts),
# and refresh the generated README tables.
# When Content/ or any Markdown changed: run the doc checker.
# Prints one JSON systemMessage line for the UI, or nothing when there was nothing to do.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$stampDir = Join-Path $root 'obj'
New-Item -ItemType Directory -Force $stampDir | Out-Null

function Get-Stamp([System.IO.FileInfo[]]$files) {
    '{0}|{1}' -f $files.Count, ($files | Measure-Object -Property LastWriteTimeUtc -Maximum).Maximum.Ticks
}
function Test-Changed([string]$name, [string]$stamp) {
    $file = Join-Path $stampDir ".$name-stamp"
    -not ((Test-Path $file) -and ((Get-Content $file -Raw).Trim() -eq $stamp))
}
function Save-Stamp([string]$name, [string]$stamp) { Set-Content -Path (Join-Path $stampDir ".$name-stamp") -Value $stamp -NoNewline }

$messages = @()
$contentStamp = Get-Stamp (Get-ChildItem (Join-Path $root 'Content') -Recurse -File)

if (Test-Changed 'content-build' $contentStamp) {
    $out = & dotnet build (Join-Path $root 'GVK_Derelicts.csproj') -c Release -nologo -v q 2>&1
    if ($LASTEXITCODE -eq 0) {
        Save-Stamp 'content-build' $contentStamp
        $messages += "GVK_Derelicts built and deployed $(Get-Date -Format HH:mm); reload the world to test."
    } else {
        $messages += "GVK_Derelicts build FAILED: " + (($out | Select-String -Pattern 'error' | Select-Object -First 3) -join ' | ')
    }
    $tables = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Update-DocTables.ps1') 2>&1
    if ("$tables" -match 'regenerated') { $messages += 'README tables regenerated.' }
}

$docFiles = Get-ChildItem $root -Recurse -File -Filter *.md | Where-Object { $_.FullName -notmatch '\\(bin|obj|\.git)\\' }
$docStamp = (Get-Stamp $docFiles) + '|' + $contentStamp
if (Test-Changed 'doc-check' $docStamp) {
    $check = & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Test-Docs.ps1') -Hook
    if ($check) { $messages += ($check | ConvertFrom-Json).systemMessage }
    # Re-stamp after the generators above may have touched docs.
    $docFiles = Get-ChildItem $root -Recurse -File -Filter *.md | Where-Object { $_.FullName -notmatch '\\(bin|obj|\.git)\\' }
    Save-Stamp 'doc-check' ((Get-Stamp $docFiles) + '|' + $contentStamp)
}

if ($messages) { @{ systemMessage = ($messages -join ' ') } | ConvertTo-Json -Compress }
exit 0
