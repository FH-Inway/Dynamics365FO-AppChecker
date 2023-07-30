# Make sure the Java VM for BaseX has 10 GB memory capacity, e.g. by setting a system environment variable (may require a system reboot)
# BASEX_JVM = -Xmx10G

$packagesLocalDirectory = "C:\AOSService\PackagesLocalDirectory"
$baseXDatabaseName = "D365ApplicationExtendedTimesheetMobile"
$astOutputPath = "C:\Temp\AST"
$packageFilter = "TimesheetMobile"

$stopwatch = [Diagnostics.Stopwatch]::StartNew()

# TODO Maybe folders without a Descriptor subfolder can be excluded directly?
$packageFolders = Get-ChildItem -Path $packagesLocalDirectory -Exclude bin -Directory
# Filter out folders that do not contain the packageFilter string
$packageFolders = $packageFolders | Where-Object {$_.Name -like "*$($packageFilter)*"}
$count = 1

# Compile modules and create AST content
$compilationStopWatch = [Diagnostics.Stopwatch]::StartNew()
foreach ($folder in $packageFolders)
{
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
$compilationStopWatch.Stop()
Write-Host @"
Compilation run time:
"@
$compilationStopWatch.Elapsed

#########################
# Create BaseX database #
#########################
$baseXStopWatch = [Diagnostics.Stopwatch]::StartNew()

$baseXCreationFile = New-Item -Path "$($astOutputPath)\CreateBaseXDatabase.bxs" -ItemType File -Force
Add-Content -Path $baseXCreationFile.FullName -Value "DROP DB $($baseXDatabaseName)"
Add-Content -Path $baseXCreationFile.FullName -Value "CREATE DB $($baseXDatabaseName)"
Add-Content -Path $baseXCreationFile.FullName -Value 'CLOSE'
cd "C:\Program Files (x86)\BaseX\bin\"
.\basex.bat -v $baseXCreationFile.FullName

##################################
# Add content to BaseX database. #
##################################

function Add-Folder {

    Param($folder)

    "adding folder $($folder.FullName)"
    $baseXAddFile = New-Item -Path "$($astOutputPath)\Add$($folder.Name).bxs" -ItemType File -Force
    Add-Content -Path $baseXAddFile.FullName -Value "OPEN $($baseXDatabaseName)"
    $value = 'ADD TO ' + $folder.Name + ' ' + $folder.FullName
    Add-Content -Path $baseXAddFile.FullName -Value $value
    Add-Content -Path $baseXAddFile.FullName -Value 'CLOSE'
    cd "C:\Program Files (x86)\BaseX\bin\"
    .\basex.bat -v $baseXAddFile.FullName
}

# For each folder of .xml files, the database is opened, the files are added and the database is closed again.
# This is done in a separate call to basex.bat to avoid an issue where basex seems to maximize memory and cpu consumption without ever finishing

# Add Application Suite AST content first; adding it later seems to maximize memory and cpu consumption by BaseX without ever finishing
$astFolders = Get-ChildItem -Path $astOutputPath\ApplicationSuite -Directory
foreach ($astFolder in $astFolders)
{
    Add-Folder($astFolder)
}

# Add other modules
foreach ($packageFolder in $packageFolders)
{
    # If there is a Descriptor subfolder, the module was compiled and has content for the basex database.
    if (Test-Path "$($packageFolder.FullName)\Descriptor")
    {
        # Add information of models of module
        $descriptorFolder = Get-Item -Path "$($packageFolder.FullName)\Descriptor"
        Add-Folder($descriptorFolder)
        
        # Add xml files of extended data types
        $edtFolders = Get-ChildItem -Path $packageFolder.FullName -Recurse -Filter "AxEdt" -Directory
        foreach ($edtFolder in $edtFolders)
        {
            Add-Folder($edtFolder)
        }
        
        # Is there AST content for this module?   
        if (Test-Path "$($astOutputPath)\$($packageFolder.Name)")
        {
            # AST content of ApplicationSuite has already been added
            if ($packageFolder.Name -ne "ApplicationSuite")
            {
                $astFolders = Get-ChildItem -Path $astOutputPath\$($packageFolder.Name) -Directory
                foreach ($astFolder in $astFolders)
                {
                    Add-Folder($astFolder)
                }
            }
        }
    }
}

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