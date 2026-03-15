# Make sure the Java VM for BaseX has 10 GB memory capacity, e.g. by setting a system environment variable (may require a system reboot)
# BASEX_JVM = -Xmx10G

$packagesLocalDirectory = "C:\AOSService\PackagesLocalDirectory"
$baseXDatabaseName = "D365ApplicationExtended"
$astOutputPath = "C:\Temp\AST"
$packageFilter = ""

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

if (!(Test-Path -Path $astOutputPath))
{
    New-Item -ItemType Directory -Path $astOutputPath
}

Read-Host -Prompt "Make sure there is at least 20 GB of free disk space and that BaseX is installed with a Java VM that has at least 10 GB memory capacity. Press Enter to continue."

# TODO Maybe folders without a Descriptor subfolder can be excluded directly?
$packageFolders = Get-ChildItem -Path $packagesLocalDirectory -Exclude bin -Directory
# Filter out folders that do not contain the packageFilter string
$packageFolders = $packageFolders | Where-Object {$_.Name -like "*$($packageFilter)*"}

#########################
# Create BaseX database #
#########################
$baseXStopWatch = [Diagnostics.Stopwatch]::StartNew()

$baseXCreationFile = New-Item -Path "$($astOutputPath)\CreateBaseXDatabase.bxs" -ItemType File -Force
Add-Content -Path $baseXCreationFile.FullName -Value "DROP DB $($baseXDatabaseName)"
Add-Content -Path $baseXCreationFile.FullName -Value "CREATE DB $($baseXDatabaseName)"
Add-Content -Path $baseXCreationFile.FullName -Value 'CLOSE'
Set-Location "C:\Program Files (x86)\BaseX\bin\"
.\basex.bat -v $baseXCreationFile.FullName

##################################
# Add content to BaseX database. #
##################################

function Add-Folder {

    Param(
        $folder,
        [string]$TargetRoot = $folder.Name
    )

    "adding folder $($folder.FullName)"
    $baseXAddFile = New-Item -Path "$($astOutputPath)\Add$($folder.Name).bxs" -ItemType File -Force
    Add-Content -Path $baseXAddFile.FullName -Value "OPEN $($baseXDatabaseName)"
    $value = 'ADD TO ' + $TargetRoot + ' ' + $folder.FullName
    Add-Content -Path $baseXAddFile.FullName -Value $value
    Add-Content -Path $baseXAddFile.FullName -Value 'CLOSE'
    Set-Location "C:\Program Files (x86)\BaseX\bin\"
    .\basex.bat -v $baseXAddFile.FullName
}

# For each folder of .xml files, the database is opened, the files are added and the database is closed again.
# This is done in a separate call to basex.bat to avoid an issue where basex seems to maximize memory and cpu consumption without ever finishing

# Add Application Suite AST content first; adding it later seems to maximize memory and cpu consumption by BaseX without ever finishing
$astFolders = Get-ChildItem -Path $astOutputPath\ApplicationSuite -Directory -ErrorAction SilentlyContinue
$totalApplicationSuiteAstFolders = @($astFolders).Count
$processedApplicationSuiteAstFolders = 0
foreach ($astFolder in $astFolders)
{
    $processedApplicationSuiteAstFolders++
    $percentComplete = if ($totalApplicationSuiteAstFolders -gt 0) { [math]::Round(($processedApplicationSuiteAstFolders / $totalApplicationSuiteAstFolders) * 100, 0) } else { 100 }
    Write-Progress -Id 1 -Activity "Adding ApplicationSuite AST folders" -Status "Processing $($astFolder.Name) ($processedApplicationSuiteAstFolders/$totalApplicationSuiteAstFolders)" -PercentComplete $percentComplete
    Add-Folder($astFolder)
}
Write-Progress -Id 1 -Activity "Adding ApplicationSuite AST folders" -Completed

# Add other modules
$totalPackageFolderCount = @($packageFolders).Count
$processedPackageFolderCount = 0
foreach ($packageFolder in $packageFolders)
{
    $processedPackageFolderCount++
    $modulePercentComplete = if ($totalPackageFolderCount -gt 0) { [math]::Round(($processedPackageFolderCount / $totalPackageFolderCount) * 100, 0) } else { 100 }
    Write-Progress -Id 2 -Activity "Adding module content to BaseX" -Status "Processing $($packageFolder.Name) ($processedPackageFolderCount/$totalPackageFolderCount)" -PercentComplete $modulePercentComplete

    # If there is a Descriptor subfolder, the module was compiled and has content for the basex database.
    if (Test-Path "$($packageFolder.FullName)\Descriptor")
    {
        # Add information of models of module
        $descriptorFolder = Get-Item -Path "$($packageFolder.FullName)\Descriptor"
        Add-Folder($descriptorFolder)
        
        # Add xml files of extended data types
        $edtFolders = Get-ChildItem -Path $packageFolder.FullName -Recurse -Filter "AxEdt" -Directory
        $totalEdtFolders = @($edtFolders).Count
        $processedEdtFolders = 0
        foreach ($edtFolder in $edtFolders)
        {
            $processedEdtFolders++
            $edtPercentComplete = if ($totalEdtFolders -gt 0) { [math]::Round(($processedEdtFolders / $totalEdtFolders) * 100, 0) } else { 100 }
            Write-Progress -Id 3 -ParentId 2 -Activity "Adding AxEDT folders for $($packageFolder.Name)" -Status "Processing $($edtFolder.FullName) ($processedEdtFolders/$totalEdtFolders)" -PercentComplete $edtPercentComplete
            Add-Folder -folder $edtFolder -TargetRoot "AxEDT"
        }
        Write-Progress -Id 3 -Activity "Adding AxEDT folders for $($packageFolder.Name)" -Completed
        
        # Is there AST content for this module?   
        if (Test-Path "$($astOutputPath)\$($packageFolder.Name)")
        {
            # AST content of ApplicationSuite has already been added
            if ($packageFolder.Name -ne "ApplicationSuite")
            {
                $astFolders = Get-ChildItem -Path $astOutputPath\$($packageFolder.Name) -Directory
                $totalAstFolders = @($astFolders).Count
                $processedAstFolders = 0
                foreach ($astFolder in $astFolders)
                {
                    $processedAstFolders++
                    $astPercentComplete = if ($totalAstFolders -gt 0) { [math]::Round(($processedAstFolders / $totalAstFolders) * 100, 0) } else { 100 }
                    Write-Progress -Id 4 -ParentId 2 -Activity "Adding AST folders for $($packageFolder.Name)" -Status "Processing $($astFolder.Name) ($processedAstFolders/$totalAstFolders)" -PercentComplete $astPercentComplete
                    Add-Folder($astFolder)
                }
                Write-Progress -Id 4 -Activity "Adding AST folders for $($packageFolder.Name)" -Completed
            }
        }
    }
}
Write-Progress -Id 2 -Activity "Adding module content to BaseX" -Completed

$baseXStopWatch.Stop()
Write-Host @"
BaseX database creation run time:
"@
$baseXStopWatch.Elapsed

$stopwatch.Stop()
# stop timer and output run time
Write-Host @"
Overall run time:
"@
$stopwatch.Elapsed