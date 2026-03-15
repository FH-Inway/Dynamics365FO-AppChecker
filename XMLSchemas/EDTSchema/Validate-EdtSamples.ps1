param(
    [string]$SchemaPath = ".\XMLSchemas\EDTSchema\AxEdt.xsd",
    [string[]]$SampleFiles = @(
        ".\XMLSchemas\EDTSchema\Sample-NewEdt.xml",
        ".\XMLSchemas\EDTSchema\Sample-NewEdt-Invalid.xml",
        ".\XMLSchemas\EDTSchema\Sample-NewEdt-NoType.xml",
        ".\XMLSchemas\EDTSchema\Sample-NewEdt-UnknownType.xml"
    )
)

$ErrorActionPreference = "Stop"

function Test-XmlFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlPath,
        [Parameter(Mandatory = $true)]
        [System.Xml.Schema.XmlSchemaSet]$SchemaSet
    )

    $settings = New-Object System.Xml.XmlReaderSettings
    $settings.ValidationType = [System.Xml.ValidationType]::Schema
    $settings.Schemas = $SchemaSet

    $errors = New-Object System.Collections.Generic.List[string]
    $settings.add_ValidationEventHandler({
        param($sender, $e)
        $msg = if ($e.Exception -and $e.Exception.Message) { $e.Exception.Message } else { $e.Message }
        if ([string]::IsNullOrWhiteSpace($msg)) {
            $msg = "Schema validation error (no detailed message provided by validator)."
        }
        $errors.Add($msg) | Out-Null
    })

    $reader = [System.Xml.XmlReader]::Create($XmlPath, $settings)
    try {
        while ($reader.Read()) { }
    }
    finally {
        $reader.Close()
    }

    if ($errors.Count -eq 0) {
        [PSCustomObject]@{
            File = $XmlPath
            Result = "PASS"
            Error = ""
        }
    }
    else {
        [PSCustomObject]@{
            File = $XmlPath
            Result = "FAIL"
            Error = $errors[0]
        }
    }
}

$schemaSet = New-Object System.Xml.Schema.XmlSchemaSet
$schemaSet.Add("", $SchemaPath) | Out-Null
$schemaSet.Compile()
Write-Host "SCHEMA_COMPILE=OK | $SchemaPath"

$results = foreach ($sample in $SampleFiles) {
    if (-not (Test-Path -Path $sample)) {
        [PSCustomObject]@{
            File = $sample
            Result = "MISSING"
            Error = "File not found"
        }
        continue
    }

    Test-XmlFile -XmlPath $sample -SchemaSet $schemaSet
}

$results | ForEach-Object {
    if ($_.Result -eq "PASS") {
        Write-Host ("PASS | {0}" -f $_.File)
    }
    elseif ($_.Result -eq "FAIL") {
        Write-Host ("FAIL | {0}" -f $_.File)
        Write-Host ("  {0}" -f $_.Error)
    }
    else {
        Write-Host ("MISSING | {0} | {1}" -f $_.File, $_.Error)
    }
}

$passCount = ($results | Where-Object { $_.Result -eq "PASS" }).Count
$failCount = ($results | Where-Object { $_.Result -eq "FAIL" }).Count
$missingCount = ($results | Where-Object { $_.Result -eq "MISSING" }).Count

Write-Host "SUMMARY | PASS=$passCount | FAIL=$failCount | MISSING=$missingCount"

if ($failCount -gt 0 -or $missingCount -gt 0) {
    exit 1
}

exit 0
