<#
Validates an XML file against an XSD 1.1 schema using Apache Xerces-J.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$XmlFile,

    [Parameter(Mandatory = $true)]
    [string]$XsdFile,

    [string]$XercesInstallFolder = "$PSScriptRoot\.tools"
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

    $resolved = Resolve-Path -Path $InstallPath
    $basePath = $resolved.Path

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

if (-not (Get-Command java -ErrorAction SilentlyContinue)) {
    throw "Java runtime not found on PATH. Install Java before running Xerces validation."
}

$xmlPath = (Resolve-Path -Path $XmlFile).Path
$xsdPath = (Resolve-Path -Path $XsdFile).Path
$xercesHome = Resolve-XercesHome -InstallPath $XercesInstallFolder

$requiredJars = @("xercesImpl.jar", "xml-apis.jar", "xercesSamples.jar")
foreach ($jar in $requiredJars) {
    $jarPath = Join-Path $xercesHome $jar
    if (-not (Test-Path $jarPath)) {
        throw "Required Xerces jar not found: $jarPath"
    }
}

$classPathParts = @(
    (Join-Path $xercesHome "xercesImpl.jar"),
    (Join-Path $xercesHome "xml-apis.jar"),
    (Join-Path $xercesHome "xercesSamples.jar")
)

$optionalJars = @(
    "org.eclipse.wst.xml.xpath2.processor_1.2.1.jar",
    "org.eclipse.wst.xml.xpath2.processor_1.2.0.jar",
    "icu4j.jar",
    "cupv10k-runtime.jar"
)

foreach ($jar in $optionalJars) {
    $jarPath = Join-Path $xercesHome $jar
    if (Test-Path $jarPath) {
        $classPathParts += $jarPath
    }
}

$classPath = $classPathParts -join ';'

<#
Write-Host "XERCES_HOME=$xercesHome"
Write-Host "XML_FILE=$xmlPath"
Write-Host "XSD_FILE=$xsdPath"
Write-Host "Running Xerces XSD 1.1 validation..."
#>

$nativePrefSet = Test-Path Variable:PSNativeCommandUseErrorActionPreference
if ($nativePrefSet) {
    $previousNativePref = $PSNativeCommandUseErrorActionPreference
    $PSNativeCommandUseErrorActionPreference = $false
}

try {
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $output = & java -cp $classPath jaxp.SourceValidator -xsd11 -a $xsdPath -i $xmlPath 2>&1 | ForEach-Object { $_.ToString() }
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

$output | ForEach-Object { Write-Host $_ }

$hasError = $false
foreach ($line in $output) {
    if ([string]$line -match '^\[Error\]') {
        $hasError = $true
        break
    }
}

if ($hasError) {
    Write-Host "VALIDATION_RESULT=FAIL"
    exit 1
}

if ($javaExitCode -ne 0) {
    Write-Host ("VALIDATION_RESULT=FAIL | JAVA_EXIT=" + $javaExitCode)
    exit $javaExitCode
}

Write-Host "VALIDATION_RESULT=PASS"
exit 0
