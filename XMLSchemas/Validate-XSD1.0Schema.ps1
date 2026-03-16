<#
Validates an XML file against an XSD 1.0 schema using .NET XmlSchemaSet.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$XmlFile,

    [Parameter(Mandatory = $true)]
    [string]$XsdFile
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -Path $XmlFile)) {
    throw "XML file not found: $XmlFile"
}

if (-not (Test-Path -Path $XsdFile)) {
    throw "XSD file not found: $XsdFile"
}

$xmlPath = (Resolve-Path -Path $XmlFile).Path
$xsdPath = (Resolve-Path -Path $XsdFile).Path

<#
Write-Host "XML_FILE=$xmlPath"
Write-Host "XSD_FILE=$xsdPath"
Write-Host "Running .NET XSD 1.0 validation..."
#>

$schemaSet = New-Object System.Xml.Schema.XmlSchemaSet
$schemaSet.Add("", $xsdPath) | Out-Null
$schemaSet.Compile()
Write-Host "SCHEMA_COMPILE=OK"

$settings = New-Object System.Xml.XmlReaderSettings
$settings.ValidationType = [System.Xml.ValidationType]::Schema
$settings.Schemas = $schemaSet

$errors = New-Object System.Collections.Generic.List[string]
$settings.add_ValidationEventHandler({
    param($sender, $e)
    $msg = if ($e.Exception -and $e.Exception.Message) { $e.Exception.Message } else { $e.Message }
    if ([string]::IsNullOrWhiteSpace($msg)) {
        $msg = "Schema validation error (no detailed message provided by validator)."
    }
    $errors.Add($msg) | Out-Null
})

$reader = [System.Xml.XmlReader]::Create($xmlPath, $settings)
try {
    while ($reader.Read()) { }
}
finally {
    $reader.Close()
}

if ($errors.Count -gt 0) {
    Write-Host "VALIDATION_RESULT=FAIL"
    $errors | ForEach-Object { Write-Host $_ }
    exit 1
}

Write-Host "VALIDATION_RESULT=PASS"
exit 0
