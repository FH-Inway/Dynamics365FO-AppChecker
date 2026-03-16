<#
Bulk-validates EDT XML files from AxEdt folders and exports results to CSV.

Behavior:
- Scans for folders named AxEdt (case-insensitive).
- Validates every .xml file directly inside each AxEdt folder.
- Runs both validators:
  - XSD 1.0 via .NET XmlSchemaSet
  - XSD 1.1 via Xerces-J
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseFolder = "C:\AOSService\PackagesLocalDirectory",

    [string[]]$SubFolders = @(),

    [string]$Xsd10SchemaPath = "$PSScriptRoot\AxEdt.1.0.xsd",
    [string]$Xsd11SchemaPath = "$PSScriptRoot\AxEdt.1.1.xsd",
    [string]$XercesInstallFolder = "$PSScriptRoot\..\.tools",

    [string]$OutputCsvPath = (Join-Path $PSScriptRoot ("edt-bulk-validation-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".csv"))
)

$ErrorActionPreference = "Stop"

function Resolve-XercesHome {
    param(
        [Parameter(Mandatory = $true)]
        [string]$InstallPath
    )

    if (-not (Test-Path -Path $InstallPath)) {
        throw "Xerces install path not found: $InstallPath"
    }

    $basePath = (Resolve-Path -Path $InstallPath).Path

    if (Test-Path (Join-Path $basePath "xercesImpl.jar")) {
        return $basePath
    }

    if (Test-Path (Join-Path $basePath "lib\xercesImpl.jar")) {
        return (Join-Path $basePath "lib")
    }

    $candidates = Get-ChildItem -Path $basePath -Directory -Filter "xerces-j-*" |
        Sort-Object -Property Name -Descending

    foreach ($candidate in $candidates) {
        if (Test-Path (Join-Path $candidate.FullName "xercesImpl.jar")) {
            return $candidate.FullName
        }
        if (Test-Path (Join-Path $candidate.FullName "lib\xercesImpl.jar")) {
            return (Join-Path $candidate.FullName "lib")
        }
    }

    throw "Could not locate xercesImpl.jar under: $basePath"
}

function Get-FirstNonEmptyLine {
    param(
        [string[]]$Lines,
        [string[]]$PreferredPatterns
    )

    $line = $Lines | Where-Object {
        foreach ($pattern in $PreferredPatterns) {
            if ($_ -match $pattern) { return $true }
        }
        return $false
    } | Select-Object -First 1

    if (-not [string]::IsNullOrWhiteSpace($line)) {
        return $line
    }

    return ($Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -First 1)
}

function Test-Xsd10 {
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
        param($src, $e)
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
        return [PSCustomObject]@{ Result = "PASS"; Error = "" }
    }

    return [PSCustomObject]@{ Result = "FAIL"; Error = $errors[0] }
}

function Test-Xsd11 {
    param(
        [Parameter(Mandatory = $true)]
        [string]$XmlPath,
        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,
        [Parameter(Mandatory = $true)]
        [string]$ClassPath,
        [bool]$JavaAvailable
    )

    if (-not $JavaAvailable) {
        return [PSCustomObject]@{ Result = "SKIPPED"; Error = "Java runtime not found on PATH." }
    }

    $nativePrefSet = Test-Path Variable:PSNativeCommandUseErrorActionPreference
    if ($nativePrefSet) {
        $previousNativePref = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    try {
        $previousErrorAction = $ErrorActionPreference
        $ErrorActionPreference = "Continue"
        try {
            $output = & java -cp $ClassPath jaxp.SourceValidator -xsd11 -a $SchemaPath -i $XmlPath 2>&1 | ForEach-Object { $_.ToString() }
            $javaExitCode = $LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorAction
        }
    }
    finally {
        if ($nativePrefSet) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePref
        }
    }

    $hasError = $false
    foreach ($line in $output) {
        if ([string]$line -match '^\[Error\]') {
            $hasError = $true
            break
        }
    }

    if ($hasError -or $javaExitCode -ne 0) {
        $err = Get-FirstNonEmptyLine -Lines $output -PreferredPatterns @(
            '^\[Error\]',
            'cvc-',
            'invalid',
            'abstract',
            'Assertion failed',
            'assertion-failure-mesg'
        )
        if ([string]::IsNullOrWhiteSpace($err)) {
            $err = "XSD 1.1 validator returned a non-zero exit code."
        }

        return [PSCustomObject]@{ Result = "FAIL"; Error = $err }
    }

    return [PSCustomObject]@{ Result = "PASS"; Error = "" }
}

if (-not (Test-Path -Path $BaseFolder)) {
    throw "Base folder not found: $BaseFolder"
}

if (-not (Test-Path -Path $Xsd10SchemaPath)) {
    throw "XSD 1.0 schema not found: $Xsd10SchemaPath"
}

if (-not (Test-Path -Path $Xsd11SchemaPath)) {
    throw "XSD 1.1 schema not found: $Xsd11SchemaPath"
}

$resolvedBaseFolder = (Resolve-Path -Path $BaseFolder).Path
$resolvedXsd10 = (Resolve-Path -Path $Xsd10SchemaPath).Path
$resolvedXsd11 = (Resolve-Path -Path $Xsd11SchemaPath).Path

$roots = @()
if ($SubFolders.Count -gt 0) {
    foreach ($sub in $SubFolders) {
        $candidate = Join-Path $resolvedBaseFolder $sub
        if (-not (Test-Path -Path $candidate)) {
            throw "Specified sub folder does not exist under base folder: $candidate"
        }
        $roots += (Resolve-Path -Path $candidate).Path
    }
}
else {
    $roots += $resolvedBaseFolder
}

Write-Host "BASE_FOLDER=$resolvedBaseFolder"
Write-Host ("ROOTS={0}" -f ($roots -join '; '))
Write-Host "XSD1.0=$resolvedXsd10"
Write-Host "XSD1.1=$resolvedXsd11"
Write-Host "OUTPUT_CSV=$OutputCsvPath"

$schemaSet10 = New-Object System.Xml.Schema.XmlSchemaSet
$schemaSet10.Add("", $resolvedXsd10) | Out-Null
$schemaSet10.Compile()

$javaAvailable = $null -ne (Get-Command java -ErrorAction SilentlyContinue)
$xsd11ClassPath = ""
$xsd11InitError = ""

if ($javaAvailable) {
    try {
        $xercesHome = Resolve-XercesHome -InstallPath $XercesInstallFolder
        $requiredJars = @("xercesImpl.jar", "xml-apis.jar", "xercesSamples.jar")
        foreach ($jar in $requiredJars) {
            $jarPath = Join-Path $xercesHome $jar
            if (-not (Test-Path $jarPath)) {
                throw "Required Xerces jar not found: $jarPath"
            }
        }

        $cpParts = @(
            (Join-Path $xercesHome "xercesImpl.jar"),
            (Join-Path $xercesHome "xml-apis.jar"),
            (Join-Path $xercesHome "xercesSamples.jar")
        )

        foreach ($jar in @("org.eclipse.wst.xml.xpath2.processor_1.2.1.jar", "org.eclipse.wst.xml.xpath2.processor_1.2.0.jar", "icu4j.jar", "cupv10k-runtime.jar")) {
            $jarPath = Join-Path $xercesHome $jar
            if (Test-Path $jarPath) {
                $cpParts += $jarPath
            }
        }

        $xsd11ClassPath = $cpParts -join ';'
    }
    catch {
        $xsd11InitError = $_.Exception.Message
    }
}
else {
    $xsd11InitError = "Java runtime not found on PATH."
}

$axEdtFolders = New-Object System.Collections.Generic.List[string]
foreach ($root in $roots) {
    if ((Split-Path -Leaf $root) -ieq "AxEdt") {
        $axEdtFolders.Add($root) | Out-Null
    }

    Get-ChildItem -Path $root -Directory -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ieq "AxEdt" } |
        ForEach-Object { $axEdtFolders.Add($_.FullName) | Out-Null }
}

$uniqueFolders = $axEdtFolders |
    Sort-Object -Unique

$xmlFiles = foreach ($folder in $uniqueFolders) {
    Get-ChildItem -Path $folder -Filter "*.xml" -File -ErrorAction SilentlyContinue
}

$xmlFiles = @($xmlFiles)
Write-Host ("AXEDT_FOLDERS_FOUND={0}" -f $uniqueFolders.Count)
Write-Host ("XML_FILES_FOUND={0}" -f $xmlFiles.Count)

$rows = foreach ($xml in $xmlFiles) {
    $xmlPath = $xml.FullName

    $res10 = Test-Xsd10 -XmlPath $xmlPath -SchemaSet $schemaSet10

    if ([string]::IsNullOrWhiteSpace($xsd11InitError)) {
        $res11 = Test-Xsd11 -XmlPath $xmlPath -SchemaPath $resolvedXsd11 -ClassPath $xsd11ClassPath -JavaAvailable $javaAvailable
    }
    else {
        $res11 = [PSCustomObject]@{ Result = "SKIPPED"; Error = $xsd11InitError }
    }

    [PSCustomObject]@{
        XmlFile = $xmlPath
        AxEdtFolder = $xml.DirectoryName
        XmlFileName = $xml.Name
        Xsd10Result = $res10.Result
        Xsd10Error = $res10.Error
        Xsd11Result = $res11.Result
        Xsd11Error = $res11.Error
    }
}

$rows | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8

$pass10 = @($rows | Where-Object { $_.Xsd10Result -eq "PASS" }).Count
$fail10 = @($rows | Where-Object { $_.Xsd10Result -eq "FAIL" }).Count
$pass11 = @($rows | Where-Object { $_.Xsd11Result -eq "PASS" }).Count
$fail11 = @($rows | Where-Object { $_.Xsd11Result -eq "FAIL" }).Count
$skip11 = @($rows | Where-Object { $_.Xsd11Result -eq "SKIPPED" }).Count

Write-Host ""
Write-Host "SUMMARY"
Write-Host ("XSD1.0 | PASS={0} | FAIL={1}" -f $pass10, $fail10)
Write-Host ("XSD1.1 | PASS={0} | FAIL={1} | SKIPPED={2}" -f $pass11, $fail11, $skip11)
Write-Host ("CSV={0}" -f $OutputCsvPath)

if ($fail10 -gt 0 -or $fail11 -gt 0) {
    exit 1
}

exit 0
