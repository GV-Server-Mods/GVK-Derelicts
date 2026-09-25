<#
.SYNOPSIS
    Scans the GVK_Derelicts workspace for inline TODO/FIXME comments and aggregates them.

.DESCRIPTION
    Searches .sbc, .cs, and .md files across Content/Data/Encounters, ModScripts, and Docs.
    Supports single-line comments and multi-line XML/C# comment blocks.
    Can print to console, output markdown, or automatically synchronize with TODO.md.

.PARAMETER WorkspaceRoot
    Path to the workspace root directory. Defaults to the repository root.

.PARAMETER IncludePrefabs
    If set, also scans prefab files in Content/Data/Prefabs and Content/Data/StorePrefabs.

.PARAMETER UpdateFile
    If set, updates the auto-harvested section inside TODO.md.

.PARAMETER TodoPath
    Path to TODO.md. Defaults to <WorkspaceRoot>/TODO.md.

.PARAMETER AsMarkdown
    Outputs the harvested tasks as a Markdown task list to standard output.

.EXAMPLE
    .\tools\Get-Todos.ps1
    Scans and displays all TODOs in console.

.EXAMPLE
    .\tools\Get-Todos.ps1 -UpdateFile
    Scans and updates the auto-generated section in TODO.md.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$WorkspaceRoot = (Resolve-Path "$PSScriptRoot\..").Path,

    [switch]$IncludePrefabs,

    [switch]$UpdateFile,

    [string]$TodoPath = "",

    [switch]$AsMarkdown
)

Set-StrictMode -Off

if (-not $TodoPath) {
    $TodoPath = Join-Path $WorkspaceRoot "TODO.md"
}

# Directories to scan
$targetDirs = @(
    (Join-Path $WorkspaceRoot "Content\Data\Encounters"),
    (Join-Path $WorkspaceRoot "ModScripts"),
    (Join-Path $WorkspaceRoot "Docs")
)

if ($IncludePrefabs) {
    $targetDirs += (Join-Path $WorkspaceRoot "Content\Data\Prefabs")
    $targetDirs += (Join-Path $WorkspaceRoot "Content\Data\StorePrefabs")
}

# Collect valid existing folders
$scanPaths = $targetDirs | Where-Object { Test-Path $_ }

# Also scan root .cs and .sbc files if any exist
$rootFiles = Get-ChildItem -Path $WorkspaceRoot -File -Include *.sbc, *.cs, *.md -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "TODO.md" -and $_.Name -ne "README.md" }

$allFiles = @()
if ($scanPaths.Count -gt 0) {
    $allFiles += Get-ChildItem -Path $scanPaths -Recurse -File -Include *.sbc, *.cs, *.md -ErrorAction SilentlyContinue
}
if ($rootFiles) {
    $allFiles += $rootFiles
}

# Exclude build and internal directories
$filteredFiles = $allFiles | Where-Object {
    $_.FullName -notmatch '\\bin\\' -and
    $_.FullName -notmatch '\\obj\\' -and
    $_.FullName -notmatch '\\\.vs\\' -and
    $_.FullName -notmatch '\\\.git\\'
}

$results = @()

foreach ($file in $filteredFiles) {
    $lines = Get-Content $file.FullName
    $relPath = $file.FullName.Substring($WorkspaceRoot.Length).TrimStart('\', '/')
    $relPathFormatted = $relPath -replace '\\', '/'

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        if ($line -match '\b(TODO|FIXME|HACK)\b[:\s]*(.*)') {
            $tag = $matches[1].ToUpper()
            $inlineText = $matches[2].Trim() `
                -replace '-->', '' `
                -replace '\*/', '' `
                -replace '^<!--', '' `
                -replace '^//', '' `
                -replace '^\*', '' `
                -replace '^\s*-\s*', '' `
                -replace '^\s*\[//', '' `
                -replace '\]$', ''
            $inlineText = $inlineText.Trim()

            $collectedItems = @()
            if ($inlineText.Length -gt 0) {
                $collectedItems += $inlineText
            }

            # Check if there are following bullet lines in the same comment block
            $j = $i + 1
            while ($j -lt $lines.Count) {
                $nextLine = $lines[$j]

                # Stop conditions
                if ($nextLine -match '^\s*-->|^\s*\*/|\b(NOTE|NOTES|FIXME|TODO|HACK)\b[:\s]|^\s*<[a-zA-Z]') {
                    break
                }

                # Bullet points
                if ($nextLine -match '^\s*[-*]\s*(.+)') {
                    $itemText = $matches[1].Trim() -replace '-->', '' -replace '\*/', ''
                    if ($itemText.Length -gt 0) {
                        $collectedItems += $itemText
                    }
                    $j++
                }
                # Indented continuation of previous item
                elseif ($collectedItems.Count -gt 0 -and $nextLine -match '^\s{4,}(.+)') {
                    $contText = $matches[1].Trim() -replace '-->', '' -replace '\*/', ''
                    if ($contText.Length -gt 0) {
                        $collectedItems[$collectedItems.Count - 1] += " " + $contText
                    }
                    $j++
                }
                else {
                    break
                }
            }

            if ($collectedItems.Count -eq 0) {
                $collectedItems += "(No description provided)"
            }

            foreach ($item in $collectedItems) {
                $results += [PSCustomObject]@{
                    Tag      = $tag
                    File     = $relPathFormatted
                    Line     = $i + 1
                    Message  = $item
                }
            }
        }
    }
}

# Format markdown lines
$mdLines = @()
if ($results.Count -eq 0) {
    $mdLines += "_No inline TODOs or FIXMEs found in scanned directories._"
} else {
    $groupedByFile = $results | Group-Object File
    foreach ($group in $groupedByFile) {
        $mdLines += "### [$($group.Name)](file:///$($WorkspaceRoot -replace '\\', '/')/$($group.Name))"
        foreach ($item in $group.Group) {
            $tagBadge = switch ($item.Tag) {
                "FIXME" { "🔴 **FIXME**" }
                "HACK"  { "🟡 **HACK**" }
                default { "📝 **TODO**" }
            }
            $mdLines += "- [ ] $tagBadge (Line $($item.Line)): $($item.Message)"
        }
        $mdLines += ""
    }
}

# Handle outputs
if ($UpdateFile) {
    if (-not (Test-Path $TodoPath)) {
        Write-Error "TODO file not found at: $TodoPath. Initialize the file first."
        return
    }

    # Read/write via .NET so the file stays UTF-8 (no BOM) with CRLF line endings.
    $fullTodoPath = (Resolve-Path $TodoPath).Path
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    $content = [System.IO.File]::ReadAllText($fullTodoPath, $utf8NoBom)
    $startMarker = "<!-- AUTO-GENERATED-TODOS-START -->"
    $endMarker = "<!-- AUTO-GENERATED-TODOS-END -->"

    $newBlock = "$startMarker`n" + ($mdLines -join "`n") + "`n$endMarker"

    if ($content -match "(?s)$startMarker.*?$endMarker") {
        $updatedContent = $content -replace "(?s)$startMarker.*?$endMarker", $newBlock
        Write-Host "Updated auto-generated section in $TodoPath ($($results.Count) items found)." -ForegroundColor Green
    } else {
        Write-Warning "Markers not found in $TodoPath. Appending to bottom."
        $updatedContent = $content.TrimEnd() + "`n`n## Auto-Harvested Inline Comments`n$newBlock`n"
    }

    $updatedContent = $updatedContent -replace "\r?\n", "`r`n"
    [System.IO.File]::WriteAllText($fullTodoPath, $updatedContent, $utf8NoBom)
}
elseif ($AsMarkdown) {
    $mdLines -join "`n"
}
else {
    Write-Host "`nFound $($results.Count) inline item(s):`n" -ForegroundColor Cyan
    $results | Format-Table -Property @(
        @{ Label = "Tag"; Expression = { $_.Tag }; Width = 6 },
        @{ Label = "File"; Expression = { $_.File }; Width = 55 },
        @{ Label = "Line"; Expression = { $_.Line }; Width = 6 },
        @{ Label = "Description"; Expression = { $_.Message } }
    ) -Wrap
}

