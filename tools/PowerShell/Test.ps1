$src = 'C:\AOSService\PackagesLocalDirectory'
$test = 'C:\Temp\BaseXTestPackages'
$modules = @('Personnel','DirectoryUpgrade')

if (Test-Path $test) { Remove-Item $test -Recurse -Force }
New-Item -ItemType Directory -Path $test | Out-Null
foreach ($m in $modules) {
    Copy-Item -Path (Join-Path $src $m) -Destination (Join-Path $test $m) -Recurse -Force
}

.\tools\PowerShell\CreateD365ApplicationBaseXDatabaseFromPackages.ps1 `
  -PackagesLocalDirectory $test `
  -BaseXDatabaseName 'D365Application_TestResume' `
  -WorkPath 'C:\Temp\BaseXImportTest' `
  -BaseXBinPath 'C:\Program Files (x86)\BaseX\bin\' `
  -Reset

.\tools\PowerShell\CreateD365ApplicationBaseXDatabaseFromPackages.ps1 -LanguagesFilter 'en-US,de'
