param(
    [string]$Xsd10SchemaPath = ".\XMLSchemas\EDTSchema\AxEdt.1.0.xsd",
    [string]$Xsd11SchemaPath = ".\XMLSchemas\EDTSchema\AxEdt.1.1.xsd",
    [string]$Xsd10ValidationScriptPath = ".\XMLSchemas\Validate-XSD1.0Schema.ps1",
    [string]$Xsd11ValidationScriptPath = ".\XMLSchemas\Validate-XSD1.1Schema.ps1",
    [string]$XercesInstallFolder = ".\XMLSchemas\.tools",
    [string[]]$SampleFiles = @(
        ".\XMLSchemas\EDTSchema\Sample-NewEdt.xml",
        ".\XMLSchemas\EDTSchema\Sample-NewEdt-Invalid.xml",
        ".\XMLSchemas\EDTSchema\Sample-NewEdt-NoType.xml",
        ".\XMLSchemas\EDTSchema\Sample-NewEdt-UnknownType.xml"
    )
)

$ErrorActionPreference = "Stop"

function Write-ColorLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [string]$Color = "Gray"
    )

    Write-Host $Text -ForegroundColor $Color
}

function Invoke-Validator {
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlPath,
        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,
        [Parameter(Mandatory = $true)]
        [string]$ValidatorScriptPath,
        [Parameter(Mandatory = $true)]
        [ValidateSet("XSD1.0", "XSD1.1")]
        [string]$ValidatorName,
        [string]$XercesFolder
    )

    $output = @()
    $invokeArgs = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", $ValidatorScriptPath,
        "-XmlFile", $XmlPath,
        "-XsdFile", $SchemaPath
    )

    if ($ValidatorName -eq "XSD1.1") {
        $invokeArgs += @("-XercesInstallFolder", $XercesFolder)
    }

    $output = & powershell @invokeArgs 2>&1 | ForEach-Object { $_.ToString() }

    $exitCode = $LASTEXITCODE
    $result = if ($exitCode -eq 0) { "PASS" } else { "FAIL" }

    $errorLine = ""
    if ($result -eq "FAIL") {
        $errorLine = ($output | Where-Object {
                $_ -match '^\[Error\]' -or
                $_ -match 'cvc-' -or
                $_ -match 'invalid' -or
                $_ -match 'abstract' -or
                $_ -match '^The element ' -or
                $_ -match '^Cannot resolve '
            } | Select-Object -First 1)

        if ([string]::IsNullOrWhiteSpace($errorLine)) {
            $errorLine = ($output | Where-Object {
                    -not [string]::IsNullOrWhiteSpace($_) -and
                    $_ -notmatch '^XML_FILE=' -and
                    $_ -notmatch '^XSD_FILE=' -and
                    $_ -notmatch '^Running ' -and
                    $_ -notmatch '^SCHEMA_COMPILE=OK' -and
                    $_ -notmatch '^VALIDATION_RESULT='
                } | Select-Object -First 1)
        }

        if ([string]::IsNullOrWhiteSpace($errorLine) -and $output.Count -gt 0) {
            $errorLine = $output[-1]
        }

        if ([string]::IsNullOrWhiteSpace($errorLine)) {
            $errorLine = "Validator returned non-zero exit code. See validator output above."
        }
    }

    [PSCustomObject]@{
        Validator = $ValidatorName
        File      = $XmlPath
        Result    = $result
        Error     = $errorLine
    }
}

if (-not (Test-Path -Path $Xsd10ValidationScriptPath)) {
    throw "XSD 1.0 validation script not found: $Xsd10ValidationScriptPath"
}

if (-not (Test-Path -Path $Xsd11ValidationScriptPath)) {
    throw "XSD 1.1 validation script not found: $Xsd11ValidationScriptPath"
}

if (-not (Test-Path -Path $Xsd10SchemaPath)) {
    throw "XSD 1.0 schema not found: $Xsd10SchemaPath"
}

if (-not (Test-Path -Path $Xsd11SchemaPath)) {
    throw "XSD 1.1 schema not found: $Xsd11SchemaPath"
}

Write-Host "XSD1.0_SCRIPT=$Xsd10ValidationScriptPath"
Write-Host "XSD1.1_SCRIPT=$Xsd11ValidationScriptPath"
Write-Host "XSD1.0_SCHEMA=$Xsd10SchemaPath"
Write-Host "XSD1.1_SCHEMA=$Xsd11SchemaPath"
Write-Host "XERCES_INSTALL=$XercesInstallFolder"
Write-Host ""

$results = foreach ($sample in $SampleFiles) {
    if (-not (Test-Path -Path $sample)) {
        [PSCustomObject]@{ Validator = "XSD1.0"; File = $sample; Result = "MISSING"; Error = "File not found" }
        [PSCustomObject]@{ Validator = "XSD1.1"; File = $sample; Result = "MISSING"; Error = "File not found" }
        continue
    }

    $resolvedSample = (Resolve-Path -Path $sample).Path
    Invoke-Validator -XmlPath $resolvedSample -SchemaPath $Xsd10SchemaPath -ValidatorScriptPath $Xsd10ValidationScriptPath -ValidatorName "XSD1.0"
    Invoke-Validator -XmlPath $resolvedSample -SchemaPath $Xsd11SchemaPath -ValidatorScriptPath $Xsd11ValidationScriptPath -ValidatorName "XSD1.1" -XercesFolder $XercesInstallFolder
}

$groupedByFile = $results | Group-Object -Property File
foreach ($fileGroup in $groupedByFile) {
    Write-ColorLine -Text ("FILE | {0}" -f $fileGroup.Name) -Color "Cyan"

    foreach ($validator in @("XSD1.0", "XSD1.1")) {
        $entry = $fileGroup.Group | Where-Object { $_.Validator -eq $validator } | Select-Object -First 1
        if (-not $entry) {
            continue
        }

        if ($entry.Result -eq "PASS") {
            Write-ColorLine -Text ("  {0} | {1}" -f $validator, $entry.Result) -Color "Green"
        }
        elseif ($entry.Result -eq "FAIL") {
            Write-ColorLine -Text ("  {0} | {1}" -f $validator, $entry.Result) -Color "Red"
        }
        else {
            Write-ColorLine -Text ("  {0} | {1}" -f $validator, $entry.Result) -Color "Yellow"
        }

        if ($entry.Result -ne "PASS" -and -not [string]::IsNullOrWhiteSpace($entry.Error)) {
            Write-ColorLine -Text ("    {0}" -f $entry.Error) -Color "DarkYellow"
        }
    }

    Write-Host ""
}

$passCount10 = @($results | Where-Object { $_.Validator -eq "XSD1.0" -and $_.Result -eq "PASS" }).Count
$failCount10 = @($results | Where-Object { $_.Validator -eq "XSD1.0" -and $_.Result -eq "FAIL" }).Count
$missingCount10 = @($results | Where-Object { $_.Validator -eq "XSD1.0" -and $_.Result -eq "MISSING" }).Count

$passCount11 = @($results | Where-Object { $_.Validator -eq "XSD1.1" -and $_.Result -eq "PASS" }).Count
$failCount11 = @($results | Where-Object { $_.Validator -eq "XSD1.1" -and $_.Result -eq "FAIL" }).Count
$missingCount11 = @($results | Where-Object { $_.Validator -eq "XSD1.1" -and $_.Result -eq "MISSING" }).Count

$failCount = $failCount10 + $failCount11
$missingCount = $missingCount10 + $missingCount11

Write-ColorLine -Text "SUMMARY | XSD1.0 PASS=$passCount10 | FAIL=$failCount10 | MISSING=$missingCount10" -Color "White"
Write-ColorLine -Text "SUMMARY | XSD1.1 PASS=$passCount11 | FAIL=$failCount11 | MISSING=$missingCount11" -Color "White"

if ($failCount -gt 0 -or $missingCount -gt 0) {
    Write-ColorLine -Text "SUMMARY | TOTAL FAIL=$failCount | TOTAL MISSING=$missingCount" -Color "Red"
}
else {
    Write-ColorLine -Text "SUMMARY | TOTAL FAIL=$failCount | TOTAL MISSING=$missingCount" -Color "Green"
}

if ($failCount -gt 0 -or $missingCount -gt 0) {
    exit 1
}

exit 0
