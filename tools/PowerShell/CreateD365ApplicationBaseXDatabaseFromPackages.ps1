# Make sure the Java VM for BaseX has 10 GB memory capacity, e.g. by setting a system environment variable (may require a system reboot)
# BASEX_JVM = -Xmx10G

# This runs about 1,5 hours for the whole standard application.

param(
    [string]$PackagesLocalDirectory = "C:\AOSService\PackagesLocalDirectory",
    [string]$BaseXDatabaseName = "D365Application",
    [string]$WorkPath = "C:\Temp\BaseXImport",
    [string]$GeneratedLabelXmlPath = "",
    [string]$ProgressFilePath = "",
    [string]$LanguagesFilter = "en-us",
    [string]$PackageFilter = "",
    [string]$BaseXBinPath = "C:\Program Files (x86)\BaseX\bin\",
    [switch]$Reset
)

if ([string]::IsNullOrWhiteSpace($GeneratedLabelXmlPath))
{
    $GeneratedLabelXmlPath = Join-Path $WorkPath "GeneratedLabelResources"
}

if ([string]::IsNullOrWhiteSpace($ProgressFilePath))
{
    $ProgressFilePath = Join-Path $WorkPath "ModuleImportProgress.clixml"
}

$languageCodes = @($LanguagesFilter.Split(",") | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
if (@($languageCodes).Count -eq 0)
{
    throw "LanguagesFilter is empty. Provide at least one language code, for example: en-us,de"
}

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

Read-Host -Prompt "Make sure there is at least 20 GB of free disk space and that BaseX is installed with a Java VM that has at least 10 GB memory capacity. Press Enter to continue."

function Invoke-BaseXScript {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath
    )

    Push-Location
    try
    {
        Set-Location $BaseXBinPath
        .\basex.bat -v $ScriptPath
    }
    finally
    {
        Pop-Location
    }
}

function Ensure-WorkPathExists {
    if (!(Test-Path -Path $WorkPath))
    {
        New-Item -ItemType Directory -Path $WorkPath -Force | Out-Null
    }
}

function Remove-BaseXDatabaseIfExists {
    Ensure-WorkPathExists
    $scriptName = "DropDatabaseIfExists_{0}.bxs" -f ([Guid]::NewGuid().ToString("N"))
    $scriptPath = Join-Path $WorkPath $scriptName
    $escapedDatabaseName = Escape-XQueryDoubleQuotedString -Value $BaseXDatabaseName
    $query = 'if (db:exists("{0}")) then db:drop("{0}") else ()' -f $escapedDatabaseName
    Set-Content -Path $scriptPath -Value ("XQUERY {0}" -f $query) -Encoding UTF8
    Invoke-BaseXScript -ScriptPath $scriptPath
}

function Ensure-BaseXDatabaseExists {
    Ensure-WorkPathExists
    $scriptName = "CreateDatabaseIfMissing_{0}.bxs" -f ([Guid]::NewGuid().ToString("N"))
    $scriptPath = Join-Path $WorkPath $scriptName
    $escapedDatabaseName = Escape-XQueryDoubleQuotedString -Value $BaseXDatabaseName
    $query = 'if (not(db:exists("{0}"))) then db:create("{0}") else ()' -f $escapedDatabaseName
    Set-Content -Path $scriptPath -Value ("XQUERY {0}" -f $query) -Encoding UTF8
    Invoke-BaseXScript -ScriptPath $scriptPath
}

function Escape-XQueryDoubleQuotedString {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    return $Value.Replace('"', '""')
}

function Remove-ModuleDataIfExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ModuleName
    )

    Ensure-WorkPathExists
    $scriptName = "RemoveModule_{0}.bxs" -f ([Guid]::NewGuid().ToString("N"))
    $baseXDeleteFile = New-Item -Path (Join-Path $WorkPath $scriptName) -ItemType File -Force
    $escapedDatabaseName = Escape-XQueryDoubleQuotedString -Value $BaseXDatabaseName
    $escapedModulePrefix = Escape-XQueryDoubleQuotedString -Value ("$ModuleName/")
    $deleteQuery = 'if (db:exists("{0}")) then (for $path in db:list("{0}", "{1}") return db:delete("{0}", $path)) else ()' -f $escapedDatabaseName, $escapedModulePrefix
    Add-Content -Path $baseXDeleteFile.FullName -Value ("XQUERY {0}" -f $deleteQuery)
    Invoke-BaseXScript -ScriptPath $baseXDeleteFile.FullName
}

function New-ProgressState {
    return @{
        ScriptName = "CreateD365ApplicationBaseXDatabaseFromPackages.ps1"
        CreatedUtc = (Get-Date).ToUniversalTime().ToString("o")
        LastUpdatedUtc = (Get-Date).ToUniversalTime().ToString("o")
        DatabaseName = $BaseXDatabaseName
        PackagesLocalDirectory = $PackagesLocalDirectory
        LanguagesFilter = ($languageCodes -join ",")
        PackageFilter = $PackageFilter
        Modules = @{}
    }
}

function Save-ProgressState {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ProgressState
    )

    $ProgressState.LastUpdatedUtc = (Get-Date).ToUniversalTime().ToString("o")
    $progressDirectory = Split-Path -Path $ProgressFilePath -Parent
    if (-not [string]::IsNullOrWhiteSpace($progressDirectory) -and !(Test-Path -Path $progressDirectory))
    {
        New-Item -ItemType Directory -Path $progressDirectory -Force | Out-Null
    }

    $ProgressState | Export-Clixml -Path $ProgressFilePath
}

function Load-ProgressState {
    if (Test-Path -Path $ProgressFilePath)
    {
        $loadedState = Import-Clixml -Path $ProgressFilePath
        if ($null -ne $loadedState)
        {
            if ($null -eq $loadedState.Modules)
            {
                $loadedState.Modules = @{}
            }

            if ($loadedState.DatabaseName -ne $BaseXDatabaseName -or $loadedState.PackagesLocalDirectory -ne $PackagesLocalDirectory -or $loadedState.PackageFilter -ne $PackageFilter -or $loadedState.LanguagesFilter -ne ($languageCodes -join ","))
            {
                Write-Host "Progress file settings differ from current parameters. Starting a new progress file."
                $newState = New-ProgressState
                Save-ProgressState -ProgressState $newState
                return $newState
            }

            return $loadedState
        }
    }

    $progressState = New-ProgressState
    Save-ProgressState -ProgressState $progressState
    return $progressState
}

function Set-ModuleProgress {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ProgressState,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        [Parameter(Mandatory = $true)]
        [string]$Status,
        [string]$Message = ""
    )

    $ProgressState.Modules[$ModuleName] = @{
        Status = $Status
        UpdatedUtc = (Get-Date).ToUniversalTime().ToString("o")
        Message = $Message
    }

    Save-ProgressState -ProgressState $ProgressState
}

function Add-Folder {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath,
        [Parameter(Mandatory = $true)]
        [string]$TargetRoot,
        [Parameter(Mandatory = $true)]
        [string]$ScriptNamePrefix
    )

    if (!(Test-Path -Path $FolderPath))
    {
        return
    }

    $scriptName = "{0}_{1}.bxs" -f $ScriptNamePrefix, ([Guid]::NewGuid().ToString("N"))
    $baseXAddFile = New-Item -Path (Join-Path $WorkPath $scriptName) -ItemType File -Force
    Add-Content -Path $baseXAddFile.FullName -Value "OPEN $($BaseXDatabaseName)"
    Add-Content -Path $baseXAddFile.FullName -Value ("ADD TO {0} {1}" -f $TargetRoot, $FolderPath)
    Add-Content -Path $baseXAddFile.FullName -Value "CLOSE"
    Invoke-BaseXScript -ScriptPath $baseXAddFile.FullName
}

function Add-File {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $true)]
        [string]$TargetPath,
        [Parameter(Mandatory = $true)]
        [string]$ScriptNamePrefix
    )

    if (!(Test-Path -Path $FilePath -PathType Leaf))
    {
        return
    }

    $scriptName = "{0}_{1}.bxs" -f $ScriptNamePrefix, ([Guid]::NewGuid().ToString("N"))
    $baseXAddFile = New-Item -Path (Join-Path $WorkPath $scriptName) -ItemType File -Force
    Add-Content -Path $baseXAddFile.FullName -Value "OPEN $($BaseXDatabaseName)"
    Add-Content -Path $baseXAddFile.FullName -Value ("ADD TO {0} {1}" -f $TargetPath, $FilePath)
    Add-Content -Path $baseXAddFile.FullName -Value "CLOSE"
    Invoke-BaseXScript -ScriptPath $baseXAddFile.FullName
}

function Convert-LabelFileToXml {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$LabelFile,
        [Parameter(Mandatory = $true)]
        [string]$ModuleName,
        [Parameter(Mandatory = $true)]
        [string]$LabelRootPath
    )

    $relativeFilePath = $LabelFile.FullName.Substring($LabelRootPath.Length).TrimStart('\').Replace('\', '/')
    $pathParts = $relativeFilePath.Split('/')
    $language = if ($pathParts.Length -gt 1) { $pathParts[0] } else { "" }
    $entries = New-Object System.Collections.Generic.List[Object]
    $pendingComments = New-Object System.Collections.Generic.List[string]
    $currentEntry = $null

    $lines = Get-Content -Path $LabelFile.FullName -Encoding UTF8
    foreach ($line in $lines)
    {
        if ($null -eq $line)
        {
            continue
        }

        $trimmedLine = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmedLine))
        {
            continue
        }

        if ($trimmedLine.StartsWith(";"))
        {
            $commentText = $trimmedLine.Substring(1).Trim()
            if ($null -ne $currentEntry)
            {
                if ([string]::IsNullOrEmpty($currentEntry.Comment))
                {
                    $currentEntry.Comment = $commentText
                }
                else
                {
                    $currentEntry.Comment = "$($currentEntry.Comment)`n$commentText"
                }
            }
            else
            {
                $pendingComments.Add($commentText)
            }

            continue
        }

        $delimiterIndex = $trimmedLine.IndexOf("=")
        if ($delimiterIndex -lt 0)
        {
            continue
        }

        $key = $trimmedLine.Substring(0, $delimiterIndex).Trim()
        $value = $trimmedLine.Substring($delimiterIndex + 1)
        if ([string]::IsNullOrEmpty($key))
        {
            continue
        }

        $comment = ""
        if ($pendingComments.Count -gt 0)
        {
            $comment = ($pendingComments -join "`n")
            $pendingComments.Clear()
        }

        $entry = [PSCustomObject]@{
            Key = $key
            Value = $value
            Comment = $comment
        }

        $entries.Add($entry)
        $currentEntry = $entry
    }

    # The label file id is the first dot-separated part of the filename (e.g. "DirectoryUpgrade" from "DirectoryUpgrade.en-US.label.txt")
    $labelFileId = $LabelFile.Name.Split('.')[0]

    $escapedModuleName = [System.Security.SecurityElement]::Escape($ModuleName)
    $escapedRelativeFilePath = [System.Security.SecurityElement]::Escape($relativeFilePath)
    $escapedLanguage = [System.Security.SecurityElement]::Escape($language)
    $escapedFileName = [System.Security.SecurityElement]::Escape($LabelFile.Name)
    $escapedLabelFileId = [System.Security.SecurityElement]::Escape($labelFileId)
    $builder = New-Object System.Text.StringBuilder
    [void]$builder.AppendLine("<LabelResource module=""$escapedModuleName"" relativePath=""$escapedRelativeFilePath"" language=""$escapedLanguage"" file=""$escapedFileName"" labelFileId=""$escapedLabelFileId"">")

    foreach ($entry in $entries)
    {
        $escapedValue = [System.Security.SecurityElement]::Escape($entry.Value)

        # Legacy labels already carry their own id (e.g. @SYS123); otherwise build @<labelFileId>:<key>
        $isLegacy = $entry.Key -match '^@[A-Za-z]+\d+$'
        $labelId   = if ($isLegacy) { $entry.Key } else { "@$labelFileId`:$($entry.Key)" }
        $escapedKey     = [System.Security.SecurityElement]::Escape($entry.Key)
        $escapedLabelId = [System.Security.SecurityElement]::Escape($labelId)

        [void]$builder.AppendLine("  <Label>")
        [void]$builder.AppendLine("    <Key>$escapedKey</Key>")
        [void]$builder.AppendLine("    <LabelId>$escapedLabelId</LabelId>")
        [void]$builder.AppendLine("    <Value>$escapedValue</Value>")

        if (-not [string]::IsNullOrWhiteSpace($entry.Comment))
        {
            $escapedComment = [System.Security.SecurityElement]::Escape($entry.Comment)
            [void]$builder.AppendLine("    <Comment>$escapedComment</Comment>")
        }

        [void]$builder.AppendLine("  </Label>")
    }

    [void]$builder.Append("</LabelResource>")
    return $builder.ToString()
}

if ($Reset)
{
    if (Test-Path -Path $WorkPath)
    {
        Remove-Item -Path $WorkPath -Recurse -Force
    }
    if (Test-Path -Path $ProgressFilePath)
    {
        Remove-Item -Path $ProgressFilePath -Force
    }
    Remove-BaseXDatabaseIfExists
}

if (!(Test-Path -Path $WorkPath))
{
    New-Item -ItemType Directory -Path $WorkPath | Out-Null
}

if (Test-Path -Path $GeneratedLabelXmlPath)
{
    Remove-Item -Path $GeneratedLabelXmlPath -Recurse -Force
}
New-Item -ItemType Directory -Path $GeneratedLabelXmlPath -Force | Out-Null

$packageFolders = Get-ChildItem -Path $PackagesLocalDirectory -Exclude bin -Directory
$packageFolders = $packageFolders | Where-Object {$_.Name -like "*$($PackageFilter)*"}
$packageFolders = $packageFolders | Where-Object { Test-Path "$($_.FullName)\Descriptor" }
$progressState = Load-ProgressState

#########################
# Create BaseX database #
#########################
$baseXStopWatch = [Diagnostics.Stopwatch]::StartNew()

Ensure-BaseXDatabaseExists

##################################
# Add content to BaseX database. #
##################################
$totalPackageFolderCount = @($packageFolders).Count
$processedPackageFolderCount = 0

foreach ($packageFolder in $packageFolders)
{
    $moduleName = $packageFolder.Name
    $processedPackageFolderCount++
    $modulePercentComplete = if ($totalPackageFolderCount -gt 0) { [math]::Round(($processedPackageFolderCount / $totalPackageFolderCount) * 100, 0) } else { 100 }
    Write-Progress -Id 1 -Activity "Adding module content to BaseX" -Status "Processing $moduleName ($processedPackageFolderCount/$totalPackageFolderCount)" -PercentComplete $modulePercentComplete

    $moduleProgress = $progressState.Modules[$moduleName]
    if ($null -ne $moduleProgress -and $moduleProgress.Status -eq "Completed")
    {
        Write-Host "Skipping module $moduleName because it is marked as completed in $ProgressFilePath."
        continue
    }

    try
    {
        Set-ModuleProgress -ProgressState $progressState -ModuleName $moduleName -Status "InProgress" -Message "Module import started."

        if ($null -ne $moduleProgress -and $moduleProgress.Status -ne "Completed")
        {
            Remove-ModuleDataIfExists -ModuleName $moduleName
        }

        $labelResourcesPathCandidates = @(
            (Join-Path $packageFolder.FullName "AxLabelFile\LabelResources"),
            (Join-Path $packageFolder.FullName "$moduleName\AxLabelFile\LabelResources")
        ) | Select-Object -Unique
        $labelResourcesPath = $labelResourcesPathCandidates | Where-Object { Test-Path -Path $_ } | Select-Object -First 1
        $selectedLanguageDirectories = @()
        $selectedLanguageCodesForModule = @()
        if (-not [string]::IsNullOrWhiteSpace($labelResourcesPath))
        {
            $selectedLanguageDirectories = @(Get-ChildItem -Path $labelResourcesPath -Directory -ErrorAction SilentlyContinue | Where-Object { $languageCodes -contains $_.Name.ToLowerInvariant() })
            $selectedLanguageCodesForModule = @($selectedLanguageDirectories | ForEach-Object { $_.Name.ToLowerInvariant() })
        }

        $axFolders = Get-ChildItem -Path $packageFolder.FullName -Directory -Recurse | Where-Object { $_.Name -like "Ax*" }
        $totalAxFolderCount = @($axFolders).Count
        $processedAxFolderCount = 0

        foreach ($axFolder in $axFolders)
        {
            $processedAxFolderCount++
            $axPercentComplete = if ($totalAxFolderCount -gt 0) { [math]::Round(($processedAxFolderCount / $totalAxFolderCount) * 100, 0) } else { 100 }
            Write-Progress -Id 2 -ParentId 1 -Activity "Adding XML folder $($axFolder.Name) for $moduleName" -Status "Processing $($axFolder.FullName) ($processedAxFolderCount/$totalAxFolderCount)" -PercentComplete $axPercentComplete

            if ($axFolder.Name -eq "AxLabelFile")
            {
                $axLabelXmlFiles = Get-ChildItem -Path $axFolder.FullName -File -Recurse | Where-Object {
                    if ($_.Extension -notlike ".xml" -or $_.FullName -match '\\LabelResources\\')
                    {
                        return $false
                    }

                    $fileNameWithoutExtension = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                    $separatorIndex = $fileNameWithoutExtension.LastIndexOf("_")
                    if ($separatorIndex -lt 0)
                    {
                        return $false
                    }

                    $fileLanguageCode = $fileNameWithoutExtension.Substring($separatorIndex + 1).ToLowerInvariant()
                    return $selectedLanguageCodesForModule -contains $fileLanguageCode
                }
                foreach ($axLabelXmlFile in $axLabelXmlFiles)
                {
                    $relativeAxLabelFilePath = $axLabelXmlFile.FullName.Substring($packageFolder.FullName.Length).TrimStart('\').Replace('\', '/')
                    $relativeAxLabelDirectory = Split-Path -Path $relativeAxLabelFilePath -Parent
                    $targetPath = "$moduleName/$relativeAxLabelDirectory/$($axLabelXmlFile.Name)"
                    Add-File -FilePath $axLabelXmlFile.FullName -TargetPath $targetPath -ScriptNamePrefix "AddAxLabelXmlFile"
                }
            }
            else
            {
                $relativeAxFolderPath = $axFolder.FullName.Substring($packageFolder.FullName.Length).TrimStart('\').Replace('\', '/')
                $targetRoot = "$moduleName/$relativeAxFolderPath"
                Add-Folder -FolderPath $axFolder.FullName -TargetRoot $targetRoot -ScriptNamePrefix "AddAxFolder"
            }
        }
        Write-Progress -Id 2 -Activity "Adding Ax* XML folders for $moduleName" -Completed

        if (-not [string]::IsNullOrWhiteSpace($labelResourcesPath))
        {
            $labelFiles = foreach ($languageDirectory in $selectedLanguageDirectories)
            {
                Get-ChildItem -Path $languageDirectory.FullName -Filter "*.txt" -File -Recurse
            }
            if (@($labelFiles).Count -gt 0)
            {
                $moduleGeneratedLabelPath = Join-Path $GeneratedLabelXmlPath $moduleName
                if (Test-Path -Path $moduleGeneratedLabelPath)
                {
                    Remove-Item -Path $moduleGeneratedLabelPath -Recurse -Force
                }
                New-Item -ItemType Directory -Path $moduleGeneratedLabelPath -Force | Out-Null

                $totalLabelFileCount = @($labelFiles).Count
                $processedLabelFileCount = 0
                foreach ($labelFile in $labelFiles)
                {
                    $processedLabelFileCount++
                    $labelPercentComplete = if ($totalLabelFileCount -gt 0) { [math]::Round(($processedLabelFileCount / $totalLabelFileCount) * 100, 0) } else { 100 }
                    Write-Progress -Id 3 -ParentId 1 -Activity "Converting label resources for $moduleName" -Status "Processing $($labelFile.Name) ($processedLabelFileCount/$totalLabelFileCount)" -PercentComplete $labelPercentComplete

                    $relativeLabelPath = $labelFile.FullName.Substring($labelResourcesPath.Length).TrimStart('\')
                    $relativeXmlDirectory = Split-Path $relativeLabelPath -Parent
                    $outputDirectory = if ([string]::IsNullOrWhiteSpace($relativeXmlDirectory)) { $moduleGeneratedLabelPath } else { Join-Path $moduleGeneratedLabelPath $relativeXmlDirectory }
                    New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null

                    $xmlFileName = "{0}.xml" -f [System.IO.Path]::GetFileNameWithoutExtension($labelFile.Name)
                    $xmlOutputPath = Join-Path $outputDirectory $xmlFileName
                    Convert-LabelFileToXml -LabelFile $labelFile -ModuleName $moduleName -LabelRootPath $labelResourcesPath | Set-Content -Path $xmlOutputPath -Encoding UTF8
                }
                Write-Progress -Id 3 -Activity "Converting label resources for $moduleName" -Completed

                Add-Folder -FolderPath $moduleGeneratedLabelPath -TargetRoot "$moduleName/LabelResources" -ScriptNamePrefix "AddLabelResources"
            }
        }

        Set-ModuleProgress -ProgressState $progressState -ModuleName $moduleName -Status "Completed" -Message "Module import completed."
    }
    catch
    {
        Set-ModuleProgress -ProgressState $progressState -ModuleName $moduleName -Status "Failed" -Message $_.Exception.Message
        throw
    }
}
Write-Progress -Id 1 -Activity "Adding module content to BaseX" -Completed

$baseXStopWatch.Stop()
Write-Host @"
BaseX database creation run time:
"@
$baseXStopWatch.Elapsed

$stopwatch.Stop()
Write-Host @"
Overall run time:
"@
$stopwatch.Elapsed
