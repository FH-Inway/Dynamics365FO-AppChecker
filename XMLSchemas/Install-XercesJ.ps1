
<#
Installs Xerces-J for XML Schema 1.1 validation.
#>
param(
    [string]$Version = "2.12.2",
    [string]$InstallRoot = "$PSScriptRoot\\.tools",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

function Invoke-Download {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,
        [Parameter(Mandatory = $true)]
        [string]$OutFile
    )

    Write-Host "Downloading: $Uri"

    $invokeParams = @{
        Uri     = $Uri
        OutFile = $OutFile
    }

    if ($PSVersionTable.PSVersion.Major -le 5) {
        $invokeParams.UseBasicParsing = $true
    }

    Invoke-WebRequest @invokeParams
}

$archiveName = "Xerces-J-bin.$Version-xml-schema-1.1.zip"
$fallbackArchiveName = "Xerces-J-bin.$Version.zip"
$downloadUrls = @(
    "https://dlcdn.apache.org/xerces/j/binaries/$archiveName",
    "https://archive.apache.org/dist/xerces/j/$archiveName",
    "https://dlcdn.apache.org/xerces/j/binaries/$fallbackArchiveName",
    "https://archive.apache.org/dist/xerces/j/$fallbackArchiveName"
)

$targetDir = Join-Path $InstallRoot "xerces-j-$Version"
$libDir = Join-Path $targetDir "lib"

$isAlreadyInstalled = (Test-Path (Join-Path $libDir "xercesImpl.jar")) -or (Test-Path (Join-Path $targetDir "xercesImpl.jar"))

if ($isAlreadyInstalled -and -not $Force) {
    Write-Host "Xerces-J already installed at: $targetDir"
    Write-Host "Use -Force to reinstall."
    exit 0
}

if (Test-Path $targetDir) {
    Remove-Item -Path $targetDir -Recurse -Force
}

New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null

$tempDir = Join-Path $env:TEMP ("xercesj-install-" + [guid]::NewGuid().ToString("N"))
$zipPath = Join-Path $tempDir $archiveName
$extractPath = Join-Path $tempDir "extract"

New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path $extractPath -Force | Out-Null

$downloaded = $false
foreach ($url in $downloadUrls) {
    try {
        Invoke-Download -Uri $url -OutFile $zipPath
        $downloaded = $true
        break
    }
    catch {
        Write-Warning "Failed download from $url"
        Write-Warning $_.Exception.Message
    }
}

if (-not $downloaded) {
    throw "Unable to download Xerces-J from all configured URLs."
}

Expand-Archive -Path $zipPath -DestinationPath $extractPath -Force

$expandedTop = Get-ChildItem -Path $extractPath -Directory | Select-Object -First 1
if (-not $expandedTop) {
    throw "Unexpected archive layout: no top-level folder found after extraction."
}

Move-Item -Path $expandedTop.FullName -Destination $targetDir

$jarBaseDir = if (Test-Path $libDir) { $libDir } else { $targetDir }

$requiredJars = @("xercesImpl.jar", "xml-apis.jar")
foreach ($jar in $requiredJars) {
    $jarPath = Join-Path $jarBaseDir $jar
    if (-not (Test-Path $jarPath)) {
        throw "Installation appears incomplete. Missing: $($jarPath)"
    }
}

Remove-Item -Path $tempDir -Recurse -Force

Write-Host "Installed Xerces-J $Version to: $targetDir"
Write-Host ""
Write-Host "Example XSD 1.1 validation command (requires Java on PATH):"
$classpathParts = @(
    (Join-Path $jarBaseDir "xercesImpl.jar"),
    (Join-Path $jarBaseDir "xml-apis.jar"),
    (Join-Path $jarBaseDir "org.eclipse.wst.xml.xpath2.processor_1.2.0.jar")
)
$exampleClasspath = $classpathParts -join ';'
Write-Host ('java -cp "{0}" your.validator.MainClass ...' -f $exampleClasspath)
