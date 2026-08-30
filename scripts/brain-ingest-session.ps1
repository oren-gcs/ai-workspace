#Requires -Version 5.1
<#
.SYNOPSIS
  Distill recent ACTION-LOG entries into brain-v2 session-learnings.json.

.DESCRIPTION
  Parses F:\ai-workspace\ACTION-LOG.md for entries since last ingest,
  appends structured learnings to brain-v2/session-learnings.json.
  Optionally appends summary lines to Claude brain knowledge-graph.json.

.PARAMETER Days
  How many days back to scan ACTION-LOG (default 7).

.PARAMETER AppendToClaudeGraph
  Also append new learning titles to C:\Users\oren\.claude\brain\knowledge-graph.json

.EXAMPLE
  .\brain-ingest-session.ps1
  .\brain-ingest-session.ps1 -Days 3 -AppendToClaudeGraph
#>
param(
    [int]$Days = 7,
    [switch]$AppendToClaudeGraph
)

$ErrorActionPreference = 'Stop'

$ActionLog = 'F:\ai-workspace\ACTION-LOG.md'
$LearningsFile = 'F:\ai-workspace\brain-v2\session-learnings.json'
$ClaudeGraph = 'C:\Users\oren\.claude\brain\knowledge-graph.json'

if (-not (Test-Path $ActionLog)) {
    Write-Error "ACTION-LOG not found: $ActionLog"
}

if (-not (Test-Path $LearningsFile)) {
    Write-Error "session-learnings.json not found: $LearningsFile"
}

$learnings = Get-Content $LearningsFile -Raw | ConvertFrom-Json
$cutoff = (Get-Date).AddDays(-$Days).Date
$lastIngest = $null
if ($learnings.lastIngest) {
    try { $lastIngest = [datetimeoffset]::Parse($learnings.lastIngest) } catch { }
}

$logText = Get-Content $ActionLog -Raw
$entries = [regex]::Matches($logText, '(?ms)^### (\d{4}-\d{2}-\d{2}) — (.+?)\r?\n\r?\n\| Field \| Value \|\r?\n\|[-|]+\|\r?\n((?:\| \*\*[^|]+\*\* \| [^\|]+ \|\r?\n)+)')

$newLearnings = @()
$existingTitles = @($learnings.learnings | ForEach-Object { $_.title })

foreach ($m in $entries) {
    $entryDate = [datetime]::ParseExact($m.Groups[1].Value, 'yyyy-MM-dd', $null)
    if ($entryDate -lt $cutoff) { continue }
    if ($lastIngest -and $entryDate -lt $lastIngest.DateTime) { continue }

    $title = $m.Groups[2].Value.Trim()
    $fieldsBlock = $m.Groups[3].Value

    # Skip noisy auto-push entries unless they indicate a change
    if ($title -match '^Auto-push completed$') {
        if ($fieldsBlock -notmatch 'pushed \d+ commit') { continue }
    }

    $action = if ($fieldsBlock -match '\*\*Action\*\* \| (.+?) \|') { $Matches[1].Trim() } else { '' }
    $target = if ($fieldsBlock -match '\*\*Target\*\* \| (.+?) \|') { $Matches[1].Trim() } else { '' }
    $result = if ($fieldsBlock -match '\*\*Result\*\* \| (.+?) \|') { $Matches[1].Trim() } else { '' }
    $nextStep = if ($fieldsBlock -match '\*\*Next step\*\* \| (.+?) \|') { $Matches[1].Trim() } else { '' }

    $dedupeKey = "$($m.Groups[1].Value):$title"
    if ($existingTitles -contains $title) { continue }

    $category = switch -Regex ($title) {
        'git|push|auth|gh ' { 'git' }
        'credential|quarantine|security' { 'security' }
        'brain|queue|RESUME' { 'brain' }
        'device|docker|compose' { 'device' }
        'agent|team|scaffold' { 'architecture' }
        default { 'operations' }
    }

    $summary = @($action, $target, $result) -join '; ' | ForEach-Object { $_.Trim('; ') }

    $newLearnings += [ordered]@{
        date       = $m.Groups[1].Value
        category   = $category
        title      = $title
        summary    = $summary
        sources    = @('ACTION-LOG')
        actionable = if ($nextStep -and $nextStep -ne 'none') { $nextStep } else { $null }
    }
    $existingTitles += $title
}

if ($newLearnings.Count -eq 0) {
    Write-Host "No new learnings since last ingest (cutoff: $($cutoff.ToString('yyyy-MM-dd')))."
    exit 0
}

foreach ($nl in $newLearnings) {
    $learnings.learnings = @($learnings.learnings) + @([pscustomobject]$nl)
}

$learnings.lastIngest = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
$learnings | ConvertTo-Json -Depth 10 | Set-Content $LearningsFile -Encoding UTF8

Write-Host "Appended $($newLearnings.Count) learning(s) to $LearningsFile"

if ($AppendToClaudeGraph) {
    foreach ($nl in $newLearnings) {
        $entity = @{
            type         = 'entity'
            name         = "session learning: $($nl.title)"
            entityType   = 'learning'
            observations = @(
                "Ingested $($nl.date) from ACTION-LOG by brain-ingest-session.ps1",
                $nl.summary
            )
            status       = 'active'
        } | ConvertTo-Json -Compress
        Add-Content -Path $ClaudeGraph -Value $entity -Encoding UTF8
    }
    Write-Host "Appended $($newLearnings.Count) entity line(s) to Claude knowledge-graph.json"
}

# Log ingest to ACTION-LOG (brief, no secrets)
$ingestNote = @"

### $(Get-Date -Format 'yyyy-MM-dd') — Brain session ingest

| Field | Value |
|---|---|
| **Actor** | brain-ingest-session.ps1 |
| **Action** | Ingested $($newLearnings.Count) learning(s) to brain-v2/session-learnings.json |
| **Target** | F:\ai-workspace\brain-v2\session-learnings.json |
| **Result** | success |
| **Next step** | none |

"@

# Insert after "## Log entries" header
$logContent = Get-Content $ActionLog -Raw
if ($logContent -match '(## Log entries\r?\n\r?\n)') {
    $updated = $logContent -replace '(## Log entries\r?\n\r?\n)', "`$1$ingestNote"
    Set-Content $ActionLog -Value $updated -Encoding UTF8 -NoNewline
}

Write-Host "Done."
