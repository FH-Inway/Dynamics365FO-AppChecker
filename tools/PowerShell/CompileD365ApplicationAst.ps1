$packagesLocalDirectory = "C:\AOSService\PackagesLocalDirectory"
$astOutputPath = "C:\Temp\AST"
$packageFilter = ""

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

if (!(Test-Path -Path $astOutputPath))
{
    New-Item -ItemType Directory -Path $astOutputPath
}

# TODO Maybe folders without a Descriptor subfolder can be excluded directly?
$packageFolders = Get-ChildItem -Path $packagesLocalDirectory -Exclude bin -Directory
# Filter out folders that do not contain the packageFilter string
$packageFolders = $packageFolders | Where-Object {$_.Name -like "*$($packageFilter)*"}
$totalPackageCount = @($packageFolders).Count
$processedPackageCount = 0
$count = 1

# Compile modules and create AST content
Read-Host "Make sure there is at least 20 GB of free disk space and at least 16 GB of free memory available, then press Enter to start compiling modules and creating AST content. This process can take a while (about 30 minutes), especially for larger models like Application Suite. If you want to compile only specific models, use the -packageFilter variable to specify a filter for the package folder names (e.g. 'ApplicationSuite*' to compile only Application Suite)."
$compilationStopWatch = [Diagnostics.Stopwatch]::StartNew()
foreach ($folder in $packageFolders)
{
    $processedPackageCount++
    $percentComplete = if ($totalPackageCount -gt 0) { [math]::Round(($processedPackageCount / $totalPackageCount) * 100, 0) } else { 100 }
    Write-Progress -Activity "Compiling modules and creating AST content" -Status "Processing $($folder.Name) ($processedPackageCount/$totalPackageCount)" -PercentComplete $percentComplete

    $folder.Name
    # If there is a Descriptor subfolder, this should be a folder of a compileable module.
    if (Test-Path "$($folder.FullName)\Descriptor")
    {
        # For an unknown reason, the compilation of the ApplicationFoundation module with -includeSourceInAsts results in an error message, but the compilation completes nevertheless and the source seems to be included in the AST xml files
        C:\AOSService\PackagesLocalDirectory\bin\xppc.exe -metadata="$($packagesLocalDirectory)" -referencefolder="$($packagesLocalDirectory)" -writeAsts -astOutputPath="$($astOutputPath)" -includeSourceInAsts -modelmodule="$($folder.Name)" -output="$($folder.FullName)\bin"
        $count++
        <#
        if ($count -eq 3)
        {
            break
        }
        #>
    }
}
Write-Progress -Activity "Compiling modules and creating AST content" -Completed
$compilationStopWatch.Stop()
Write-Host @"
Compilation run time:
"@
$compilationStopWatch.Elapsed

$stopwatch.Stop()
Write-Host @"
Overall run time:
"@
$stopwatch.Elapsed
