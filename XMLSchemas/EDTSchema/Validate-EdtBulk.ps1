<#
Bulk-validates EDT XML files from AxEdt folders and exports results to CSV.

Behavior:
- Scans for folders named AxEdt (case-insensitive).
- Validates every .xml file directly inside each AxEdt folder.
- Runs both validators:
  - XSD 1.0 via .NET XmlSchemaSet
  - XSD 1.1 via Xerces-J
- Either validator can be disabled with a switch parameter.
- Validation can stop on the first failure with a switch parameter.
- Takes about 7 minutes for the standard application edts.
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$BaseFolder = "C:\AOSService\PackagesLocalDirectory",

    [string[]]$SubFolders = @(),
    [string[]]$ExcludeSubFolders = @(),

    [string]$Xsd10SchemaPath = "$PSScriptRoot\AxEdt.1.0.xsd",
    [string]$Xsd11SchemaPath = "$PSScriptRoot\AxEdt.1.1.xsd",
    [string]$XercesInstallFolder = "$PSScriptRoot\..\.tools",

    [switch]$SkipXsd10,
    [switch]$SkipXsd11,
    [switch]$StopOnFailure,

    [string]$RetryFailuresCsvPath = "",

    [string]$OutputCsvPath = (Join-Path $PSScriptRoot ("edt-bulk-validation-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".csv"))
)

$ErrorActionPreference = "Stop"
$scriptStartTime = Get-Date

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

function Test-PathUnderRoots {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [string[]]$Roots = @()
    )

    if ($Roots.Count -eq 0) {
        return $false
    }

    $candidatePath = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    foreach ($root in $Roots) {
        $rootPath = [System.IO.Path]::GetFullPath($root).TrimEnd('\')
        if ($candidatePath.Equals($rootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }

        if ($candidatePath.StartsWith($rootPath + '\', [System.StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }

    return $false
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

function Split-XmlPathsIntoChunks {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$XmlPaths,
        [int]$MaxArgumentChars = 24000
    )

    $chunks = @()
    $current = @()
    $currentChars = 0

    foreach ($xmlPath in $XmlPaths) {
        $addedChars = $xmlPath.Length + 1
        if (@($current).Count -gt 0 -and ($currentChars + $addedChars) -gt $MaxArgumentChars) {
            $chunks += ,@($current)
            $current = @()
            $currentChars = 0
        }

        $current += $xmlPath
        $currentChars += $addedChars
    }

    if (@($current).Count -gt 0) {
        $chunks += ,@($current)
    }

    return ,$chunks
}

function Test-Xsd11Batch {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$XmlPaths,
        [Parameter(Mandatory = $true)]
        [string]$SchemaPath,
        [Parameter(Mandatory = $true)]
        [string]$ClassPath,
        [bool]$JavaAvailable
    )

    $results = @{}
    foreach ($xmlPath in $XmlPaths) {
        $results[$xmlPath] = [PSCustomObject]@{ Result = "PASS"; Error = "" }
    }

    if (-not $JavaAvailable) {
        foreach ($xmlPath in $XmlPaths) {
            $results[$xmlPath] = [PSCustomObject]@{ Result = "SKIPPED"; Error = "Java runtime not found on PATH." }
        }
        return $results
    }

    $nameToPaths = @{}
    foreach ($xmlPath in $XmlPaths) {
        $fileName = [System.IO.Path]::GetFileName($xmlPath).ToLowerInvariant()
        if (-not $nameToPaths.ContainsKey($fileName)) {
            $nameToPaths[$fileName] = New-Object System.Collections.Generic.List[string]
        }
        $nameToPaths[$fileName].Add($xmlPath) | Out-Null
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
            $javaArgs = @("-cp", $ClassPath, "jaxp.SourceValidator", "-xsd11", "-a", $SchemaPath, "-i") + $XmlPaths
            $output = & java @javaArgs 2>&1 | ForEach-Object { $_.ToString() }
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

    $hasAnyError = $false
    $errorByPath = @{}
    $ambiguousNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($line in $output) {
        if ([string]$line -notmatch '^\[Error\]\s+(.+?\.xml):\d+:\d+:\s*(.*)$') {
            continue
        }

        $hasAnyError = $true
        $reportedName = [System.IO.Path]::GetFileName($matches[1]).ToLowerInvariant()

        if (-not $nameToPaths.ContainsKey($reportedName)) {
            continue
        }

        $candidatePaths = $nameToPaths[$reportedName]
        if ($candidatePaths.Count -eq 1) {
            $xmlPath = $candidatePaths[0]
            if (-not $errorByPath.ContainsKey($xmlPath)) {
                $errorByPath[$xmlPath] = $line
            }
        }
        else {
            $ambiguousNames.Add($reportedName) | Out-Null
        }
    }

    foreach ($xmlPath in $errorByPath.Keys) {
        $results[$xmlPath] = [PSCustomObject]@{ Result = "FAIL"; Error = $errorByPath[$xmlPath] }
    }

    foreach ($name in $ambiguousNames) {
        foreach ($xmlPath in $nameToPaths[$name]) {
            $results[$xmlPath] = Test-Xsd11 -XmlPath $xmlPath -SchemaPath $SchemaPath -ClassPath $ClassPath -JavaAvailable $JavaAvailable
        }
    }

    if ($javaExitCode -ne 0 -and -not $hasAnyError) {
        foreach ($xmlPath in $XmlPaths) {
            if ($results[$xmlPath].Result -eq "PASS") {
                $results[$xmlPath] = [PSCustomObject]@{ Result = "FAIL"; Error = "XSD 1.1 validator returned a non-zero exit code." }
            }
        }
    }

    return $results
}

if (-not (Test-Path -Path $BaseFolder)) {
    throw "Base folder not found: $BaseFolder"
}

if ($SkipXsd10 -and $SkipXsd11) {
    throw "At least one validator must remain enabled. Do not specify both -SkipXsd10 and -SkipXsd11."
}

if (-not $SkipXsd10 -and -not (Test-Path -Path $Xsd10SchemaPath)) {
    throw "XSD 1.0 schema not found: $Xsd10SchemaPath"
}

if (-not $SkipXsd11 -and -not (Test-Path -Path $Xsd11SchemaPath)) {
    throw "XSD 1.1 schema not found: $Xsd11SchemaPath"
}

if (-not [string]::IsNullOrWhiteSpace($RetryFailuresCsvPath) -and -not (Test-Path -Path $RetryFailuresCsvPath)) {
    throw "Retry failures CSV not found: $RetryFailuresCsvPath"
}

$resolvedBaseFolder = (Resolve-Path -Path $BaseFolder).Path
$resolvedXsd10 = if ($SkipXsd10) { "DISABLED" } else { (Resolve-Path -Path $Xsd10SchemaPath).Path }
$resolvedXsd11 = if ($SkipXsd11) { "DISABLED" } else { (Resolve-Path -Path $Xsd11SchemaPath).Path }
$resolvedRetryFailuresCsv = if ([string]::IsNullOrWhiteSpace($RetryFailuresCsvPath)) { "DISABLED" } else { (Resolve-Path -Path $RetryFailuresCsvPath).Path }

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

$excludedRoots = @()
if ($ExcludeSubFolders.Count -gt 0) {
    foreach ($sub in $ExcludeSubFolders) {
        $candidate = Join-Path $resolvedBaseFolder $sub
        if (-not (Test-Path -Path $candidate)) {
            throw "Specified excluded sub folder does not exist under base folder: $candidate"
        }
        $excludedRoots += (Resolve-Path -Path $candidate).Path
    }
}

Write-Host "BASE_FOLDER=$resolvedBaseFolder"
Write-Host ("ROOTS={0}" -f ($roots -join '; '))
Write-Host ("EXCLUDED_ROOTS={0}" -f $(if ($excludedRoots.Count -gt 0) { $excludedRoots -join '; ' } else { '<none>' }))
Write-Host "XSD1.0=$resolvedXsd10"
Write-Host "XSD1.1=$resolvedXsd11"
Write-Host "RETRY_FAILURES_CSV=$resolvedRetryFailuresCsv"
Write-Host "OUTPUT_CSV=$OutputCsvPath"

$schemaSet10 = $null
if (-not $SkipXsd10) {
    $schemaSet10 = New-Object System.Xml.Schema.XmlSchemaSet
    $schemaSet10.Add("", $resolvedXsd10) | Out-Null
    $schemaSet10.Compile()
}

$javaAvailable = $false
$xsd11ClassPath = ""
$xsd11InitError = ""

if ($SkipXsd11) {
    $xsd11InitError = "XSD 1.1 validation disabled by parameter."
}
else {
    $javaAvailable = $null -ne (Get-Command java -ErrorAction SilentlyContinue)

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

if ($excludedRoots.Count -gt 0) {
    $uniqueFolders = @(
        $uniqueFolders | Where-Object {
            -not (Test-PathUnderRoots -Path $_ -Roots $excludedRoots)
        }
    )
}

$xmlFiles = @()
$folderCount = @($uniqueFolders).Count
$folderIndex = 0

foreach ($folder in $uniqueFolders) {
    $folderIndex++
    $discoverPercent = if ($folderCount -gt 0) {
        [int](($folderIndex / $folderCount) * 100)
    }
    else {
        100
    }

    Write-Progress -Activity "Collecting EDT XML files" -Status ("{0}/{1}: {2}" -f $folderIndex, $folderCount, $folder) -PercentComplete $discoverPercent

    $xmlFiles += Get-ChildItem -Path $folder -Filter "*.xml" -File -ErrorAction SilentlyContinue
}

Write-Progress -Activity "Collecting EDT XML files" -Completed

$xmlFiles = @($xmlFiles)

if (-not [string]::IsNullOrWhiteSpace($RetryFailuresCsvPath)) {
    $retryRows = Import-Csv -Path $resolvedRetryFailuresCsv

    $failedFromCsv = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($row in $retryRows) {
        if ([string]::IsNullOrWhiteSpace($row.XmlFile)) {
            continue
        }

        $isFailed10 = $row.PSObject.Properties.Name -contains "Xsd10Result" -and $row.Xsd10Result -eq "FAIL"
        $isFailed11 = $row.PSObject.Properties.Name -contains "Xsd11Result" -and $row.Xsd11Result -eq "FAIL"

        $isFailed = if (-not $SkipXsd10 -and -not $SkipXsd11) {
            $isFailed10 -or $isFailed11
        }
        elseif (-not $SkipXsd10) {
            $isFailed10
        }
        else {
            $isFailed11
        }

        if ($isFailed) {
            try {
                $normalizedFailedPath = [System.IO.Path]::GetFullPath($row.XmlFile)
                $failedFromCsv.Add($normalizedFailedPath) | Out-Null
            }
            catch {
                # Ignore malformed paths in retry CSV rows.
            }
        }
    }

    $xmlFiles = @(
        $xmlFiles | Where-Object {
            $failedFromCsv.Contains([System.IO.Path]::GetFullPath($_.FullName))
        }
    )

    Write-Host ("RETRY_FAILURES_MATCHED={0}" -f $xmlFiles.Count)
}

Write-Host ("AXEDT_FOLDERS_FOUND={0}" -f $uniqueFolders.Count)
Write-Host ("XML_FILES_FOUND={0}" -f $xmlFiles.Count)

$totalXmlFiles = $xmlFiles.Count
$processedXmlFiles = 0

$xsd11BatchResults = @{}
if ([string]::IsNullOrWhiteSpace($xsd11InitError) -and $xmlFiles.Count -gt 0) {
    $xmlPathsForXsd11 = @($xmlFiles | ForEach-Object { $_.FullName })
    $xsd11Chunks = Split-XmlPathsIntoChunks -XmlPaths $xmlPathsForXsd11
    Write-Host ("XSD1.1_BATCH_MODE=ON | CHUNKS={0}" -f $xsd11Chunks.Count)

    $chunkIndex = 0
    foreach ($chunk in $xsd11Chunks) {
        $chunkIndex++
        $chunkPercent = [int](($chunkIndex / $xsd11Chunks.Count) * 100)
        Write-Progress -Activity "Running XSD 1.1 batch validation" -Status ("chunk {0}/{1} ({2} files)" -f $chunkIndex, $xsd11Chunks.Count, $chunk.Count) -PercentComplete $chunkPercent

        $chunkResults = Test-Xsd11Batch -XmlPaths $chunk -SchemaPath $resolvedXsd11 -ClassPath $xsd11ClassPath -JavaAvailable $javaAvailable
        foreach ($xmlPath in $chunkResults.Keys) {
            $xsd11BatchResults[$xmlPath] = $chunkResults[$xmlPath]
        }
    }

    Write-Progress -Activity "Running XSD 1.1 batch validation" -Completed
}

$rows = foreach ($xml in $xmlFiles) {
    $processedXmlFiles++
    $xmlPath = $xml.FullName

    $percentComplete = if ($totalXmlFiles -gt 0) {
        [int](($processedXmlFiles / $totalXmlFiles) * 100)
    }
    else {
        100
    }

    Write-Progress -Activity "Validating EDT XML files" -Status ("{0}/{1}: {2}" -f $processedXmlFiles, $totalXmlFiles, $xml.Name) -PercentComplete $percentComplete

    if ($SkipXsd10) {
        $res10 = [PSCustomObject]@{ Result = "SKIPPED"; Error = "XSD 1.0 validation disabled by parameter." }
    }
    else {
        $res10 = Test-Xsd10 -XmlPath $xmlPath -SchemaSet $schemaSet10
    }

    if ([string]::IsNullOrWhiteSpace($xsd11InitError)) {
        if ($xsd11BatchResults.ContainsKey($xmlPath)) {
            $res11 = $xsd11BatchResults[$xmlPath]
        }
        else {
            $res11 = Test-Xsd11 -XmlPath $xmlPath -SchemaPath $resolvedXsd11 -ClassPath $xsd11ClassPath -JavaAvailable $javaAvailable
        }
    }
    else {
        $res11 = [PSCustomObject]@{ Result = "SKIPPED"; Error = $xsd11InitError }
    }

    $row = [PSCustomObject]@{
        XmlFile = $xmlPath
        AxEdtFolder = $xml.DirectoryName
        XmlFileName = $xml.Name
        Xsd10Result = $res10.Result
        Xsd10Error = $res10.Error
        Xsd11Result = $res11.Result
        Xsd11Error = $res11.Error
    }

    $row

    if ($StopOnFailure -and ($res10.Result -eq "FAIL" -or $res11.Result -eq "FAIL")) {
        Write-Host ""
        Write-Host "STOP_ON_FAILURE=TRUE"
        Write-Host ("FAILED_XML={0}" -f $xmlPath)

        if ($res10.Result -eq "FAIL") {
            Write-Host ("XSD1.0_ERROR={0}" -f $res10.Error)
        }

        if ($res11.Result -eq "FAIL") {
            Write-Host ("XSD1.1_ERROR={0}" -f $res11.Error)
        }

        break
    }
}

Write-Progress -Activity "Validating EDT XML files" -Completed

$rows | Export-Csv -Path $OutputCsvPath -NoTypeInformation -Encoding UTF8

$pass10 = @($rows | Where-Object { $_.Xsd10Result -eq "PASS" }).Count
$fail10 = @($rows | Where-Object { $_.Xsd10Result -eq "FAIL" }).Count
$skip10 = @($rows | Where-Object { $_.Xsd10Result -eq "SKIPPED" }).Count
$pass11 = @($rows | Where-Object { $_.Xsd11Result -eq "PASS" }).Count
$fail11 = @($rows | Where-Object { $_.Xsd11Result -eq "FAIL" }).Count
$skip11 = @($rows | Where-Object { $_.Xsd11Result -eq "SKIPPED" }).Count

Write-Host ""
Write-Host "SUMMARY"
Write-Host ("XSD1.0 | PASS={0} | FAIL={1} | SKIPPED={2}" -f $pass10, $fail10, $skip10)
Write-Host ("XSD1.1 | PASS={0} | FAIL={1} | SKIPPED={2}" -f $pass11, $fail11, $skip11)
Write-Host ("CSV={0}" -f $OutputCsvPath)
Write-Host ("TOTAL_RUNTIME={0}" -f ((Get-Date) - $scriptStartTime).ToString())

if ($fail10 -gt 0 -or $fail11 -gt 0) {
    exit 1
}

exit 0
