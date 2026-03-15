param(
	[string]$Database = "D365ApplicationExtended",
	[int]$SampleLimit = 200,
	[string]$QueryPath = (Join-Path $PSScriptRoot "rename-paths-collision-precheck.xq")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $QueryPath)) {
	throw "Query file not found: $QueryPath"
}

$CollisionPrecheckCommand = "basex -bdb=$Database -bsample-limit=$SampleLimit $QueryPath"
Write-Host "Running collision precheck command: $CollisionPrecheckCommand"

$output = & basex "-bdb=$Database" "-bsample-limit=$SampleLimit" "$QueryPath" 2>&1

if ($LASTEXITCODE -ne 0) {
	Write-Error ($output | Out-String)
	throw "BaseX collision precheck failed with exit code $LASTEXITCODE."
}

if ([string]::IsNullOrWhiteSpace(($output | Out-String))) {
	Write-Host "No output from collision precheck query."
}
else {
	Write-Host "Collision precheck output:"
	$output
}
