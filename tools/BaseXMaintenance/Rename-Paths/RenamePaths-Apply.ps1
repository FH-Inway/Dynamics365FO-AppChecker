[CmdletBinding()]
param(
    [string]$Database = "D365ApplicationExtended",
    [int]$Offset = 1,
    [int]$BatchSize = 500,
    [string]$DryRunQueryPath = (Join-Path $PSScriptRoot "rename-paths-dry-run.xq"),
    [string]$ApplyQueryPath = (Join-Path $PSScriptRoot "rename-paths-apply.xq"),
    [string]$FinalizeQueryPath = (Join-Path $PSScriptRoot "rename-paths-finalize.xq"),
    [string]$TempPrefix = "__axedt_casefix__",
    [switch]$Execute
)

$ErrorActionPreference = "Stop"

if ($Offset -lt 1) {
    throw "Offset must be >= 1."
}

if ($BatchSize -lt 1) {
    throw "BatchSize must be >= 1."
}

if (-not (Test-Path -LiteralPath $DryRunQueryPath)) {
    throw "Dry-run query file not found: $DryRunQueryPath"
}

if (-not (Test-Path -LiteralPath $ApplyQueryPath)) {
    throw "Apply query file not found: $ApplyQueryPath"
}

if (-not (Test-Path -LiteralPath $FinalizeQueryPath)) {
    throw "Finalize query file not found: $FinalizeQueryPath"
}

$dryRunCommand = "basex -bdb=$Database -boffset=$Offset -bbatch-size=$BatchSize $DryRunQueryPath"
Write-Host "Previewing batch: $dryRunCommand"

$preview = & basex "-bdb=$Database" "-boffset=$Offset" "-bbatch-size=$BatchSize" "$DryRunQueryPath" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error ($preview | Out-String)
    throw "BaseX dry-run preview failed with exit code $LASTEXITCODE."
}

$previewText = $preview | Out-String
$previewText.TrimEnd()

$batchCountLine = $preview | Where-Object { $_ -like 'BATCH_COUNT | *' } | Select-Object -First 1
$batchCount = 0
if ($batchCountLine) {
    $batchCount = [int](($batchCountLine -split '\|')[1].Trim())
}

if ($batchCount -eq 0) {
    Write-Host "No paths in this batch. Nothing to rename."
    return
}

if (-not $Execute) {
    Write-Host "Dry-run only. Re-run with -Execute to apply this batch."
    return
}

$applyCommand = "basex -bdb=$Database -boffset=$Offset -bbatch-size=$BatchSize -btemp-prefix=$TempPrefix $ApplyQueryPath"
Write-Host "Applying phase 1 rename batch: $applyCommand"

$applyOutput = & basex "-bdb=$Database" "-boffset=$Offset" "-bbatch-size=$BatchSize" "-btemp-prefix=$TempPrefix" "$ApplyQueryPath" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error ($applyOutput | Out-String)
    throw "BaseX phase 1 rename batch failed with exit code $LASTEXITCODE."
}

Write-Host "Phase 1 rename batch applied successfully."

$finalizeCommand = "basex -bdb=$Database -boffset=$Offset -bbatch-size=$BatchSize -btemp-prefix=$TempPrefix $FinalizeQueryPath"
Write-Host "Applying phase 2 rename batch: $finalizeCommand"

$finalizeOutput = & basex "-bdb=$Database" "-boffset=$Offset" "-bbatch-size=$BatchSize" "-btemp-prefix=$TempPrefix" "$FinalizeQueryPath" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error ($finalizeOutput | Out-String)
    throw "BaseX phase 2 rename batch failed with exit code $LASTEXITCODE."
}

Write-Host "Phase 2 rename batch applied successfully."

$postCheck = & basex "-bdb=$Database" "-boffset=$Offset" "-bbatch-size=$BatchSize" "$DryRunQueryPath" 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Host "Post-apply batch preview:"
    ($postCheck | Out-String).TrimEnd()
}
