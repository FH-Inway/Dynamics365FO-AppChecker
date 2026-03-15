param(
    [string]$Database = "D365ApplicationExtended",
    [int]$Offset = 1,
    [int]$BatchSize = 99999,
    [string]$QueryPath = (Join-Path $PSScriptRoot "rename-paths-dry-run.xq"),
    [string]$OutputPath = ""
)

$ErrorActionPreference = "Stop"

if ($Offset -lt 1) {
    throw "Offset must be >= 1."
}

if ($BatchSize -lt 1) {
    throw "BatchSize must be >= 1."
}

if (-not (Test-Path -LiteralPath $QueryPath)) {
    throw "Query file not found: $QueryPath"
}

$commandPreview = "basex -bdb=$Database -boffset=$Offset -bbatch-size=$BatchSize $QueryPath"
Write-Host "Running dry-run command: $commandPreview"

$output = & basex "-bdb=$Database" "-boffset=$Offset" "-bbatch-size=$BatchSize" "$QueryPath" 2>&1

if ($LASTEXITCODE -ne 0) {
    Write-Error ($output | Out-String)
    throw "BaseX dry-run failed with exit code $LASTEXITCODE."
}

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    Set-Content -LiteralPath $OutputPath -Value ($output | Out-String) -Encoding UTF8
    Write-Host "Dry-run output written to: $OutputPath"
}

$output
