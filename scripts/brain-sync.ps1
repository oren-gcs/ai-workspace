#Requires -Version 5.1
<#
.SYNOPSIS
  Sync brain artifacts between Claude brain and Cursor brain-v2 local layer.
.DESCRIPTION
  Merges queue.json and open-loops.json without secrets.
  knowledge-graph.json: append-only pull from Claude; local appends pushed on -Direction push|both.
.PARAMETER Direction
  pull (default), push, or both
#>
param(
    [ValidateSet('pull', 'push', 'both')]
    [string]$Direction = 'pull'
)

$ErrorActionPreference = 'Stop'

$ClaudeRoot = 'C:\Users\oren\.claude\brain'
$LocalRoot  = 'F:\ai-workspace\projects\brain\local'

function Read-JsonFile($path) {
    if (-not (Test-Path $path)) { return $null }
    Get-Content -Raw -Path $path | ConvertFrom-Json
}

function Write-JsonFile($path, $obj) {
    $json = $obj | ConvertTo-Json -Depth 20
    Set-Content -Path $path -Value $json -Encoding UTF8
}

function Merge-Queue($source, $target) {
    if (-not $source) { return $target }
    if (-not $target) { return $source }

    $ids = @{}
    foreach ($item in $target.pending) { $ids[$item.id] = $true }
    foreach ($item in $source.pending) {
        if (-not $ids.ContainsKey($item.id)) {
            $target.pending += $item
        }
    }

    $histIds = @{}
    foreach ($item in $target.history) { $histIds[$item.id] = $true }
    foreach ($item in $source.history) {
        if (-not $histIds.ContainsKey($item.id)) {
            $target.history += $item
        }
    }
    return $target
}

function Merge-OpenLoops($source, $target) {
    if (-not $source) { return $target }
    if (-not $target) { return $source }

    $texts = @{}
    foreach ($loop in $target.loops) { $texts[$loop.text.Substring(0, [Math]::Min(80, $loop.text.Length))] = $true }
    foreach ($loop in $source.loops) {
        $key = $loop.text.Substring(0, [Math]::Min(80, $loop.text.Length))
        if (-not $texts.ContainsKey($key)) {
            $target.loops += $loop
        }
    }
    return $target
}

function Merge-KnowledgeGraph($sourcePath, $targetPath) {
    if (-not (Test-Path $sourcePath)) { return }
    $existing = @{}
    if (Test-Path $targetPath) {
        Get-Content $targetPath | ForEach-Object {
            if ($_.Trim()) { $existing[$_.Trim()] = $true }
        }
    }
    $newLines = @()
    Get-Content $sourcePath | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $existing.ContainsKey($line)) {
            $newLines += $line
        }
    }
    if ($newLines.Count -gt 0) {
        Add-Content -Path $targetPath -Value ($newLines -join "`n")
    }
}

Write-Host "brain-sync: Direction=$Direction"

if ($Direction -eq 'pull' -or $Direction -eq 'both') {
    Write-Host "  Pulling Claude -> local"

    # RESUME: copy with header note (Claude canonical)
    $claudeResume = Join-Path $ClaudeRoot 'RESUME.md'
    if (Test-Path $claudeResume) {
        $content = Get-Content -Raw $claudeResume
        $note = "# Synced from Claude brain $(Get-Date -Format 'yyyy-MM-dd HH:mm')`n`n"
        # Only update if local RESUME is older marker — preserve v2 header
        $localResume = Join-Path $LocalRoot 'RESUME.md'
        if (-not (Test-Path $localResume)) {
            Set-Content $localResume ($note + $content)
        }
    }

    # Queue merge
    $claudeQueue = Read-JsonFile (Join-Path $ClaudeRoot 'queue.json')
    $localQueue  = Read-JsonFile (Join-Path $LocalRoot 'queue.json')
    if ($claudeQueue) {
        $merged = Merge-Queue -source $claudeQueue -target $localQueue
        if ($merged) { Write-JsonFile (Join-Path $LocalRoot 'queue.json') $merged }
    }

    # Open loops merge
    $claudeLoops = Read-JsonFile (Join-Path $ClaudeRoot 'open-loops.json')
    $localLoops  = Read-JsonFile (Join-Path $LocalRoot 'open-loops.json')
    if ($claudeLoops) {
        $merged = Merge-OpenLoops -source $claudeLoops -target $localLoops
        if ($merged) { Write-JsonFile (Join-Path $LocalRoot 'open-loops.json') $merged }
    }

    # Knowledge graph append
    Merge-KnowledgeGraph (Join-Path $ClaudeRoot 'knowledge-graph.json') (Join-Path $LocalRoot 'knowledge-graph.json')
}

if ($Direction -eq 'push' -or $Direction -eq 'both') {
    Write-Host "  Pushing local -> Claude (queue, open-loops, graph append)"

    $claudeQueue = Read-JsonFile (Join-Path $ClaudeRoot 'queue.json')
    $localQueue  = Read-JsonFile (Join-Path $LocalRoot 'queue.json')
    if ($localQueue -and $claudeQueue) {
        $merged = Merge-Queue -source $localQueue -target $claudeQueue
        Write-JsonFile (Join-Path $ClaudeRoot 'queue.json') $merged
    }

    $claudeLoops = Read-JsonFile (Join-Path $ClaudeRoot 'open-loops.json')
    $localLoops  = Read-JsonFile (Join-Path $LocalRoot 'open-loops.json')
    if ($localLoops -and $claudeLoops) {
        $merged = Merge-OpenLoops -source $localLoops -target $claudeLoops
        Write-JsonFile (Join-Path $ClaudeRoot 'open-loops.json') $merged
    }

    Merge-KnowledgeGraph (Join-Path $LocalRoot 'knowledge-graph.json') (Join-Path $ClaudeRoot 'knowledge-graph.json')
}

Write-Host "brain-sync: done"
