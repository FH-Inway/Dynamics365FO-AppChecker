# Downloads latest stable BaseX release and installs it.
# If necessary, Java 11 or higher is installed as well.

function CheckJava {
  # Execute the 'java -version' command and capture the output
  $javaVersionOutput = java -version 2>&1

  # Extract the version string from the output
  $javaVersionString = $javaVersionOutput | Select-String -Pattern 'openjdk version "(\d+\.\d+\.\d+)_\d+"'
  if ($javaVersionString) {
      $javaVersion = $javaVersionString.Matches.Groups[1].Value
  }

  # Check if the Java version is available and greater than or equal to 17
  if (-not $javaVersion -or [Version]$javaVersion -lt [Version]'17.0') {
      Write-Host "Please install Java 17 or higher before proceeding."
      return $false
  }

  return $true
}

# Check if Java is installed
if (-not (CheckJava)) {
  # Download and install Java
  Write-Host "Installing Java..."
  # choco install temurin
  choco install temurin
}

# Download BaseX
Write-Host "Downloading BaseX..."
$baseXReleasesUrl = "https://files.basex.org/releases/"

# In Windows PowerShell 5.1, IE-based parsing may be unavailable.
$invokeWebRequestParams = @{}
if ($PSVersionTable.PSVersion.Major -lt 6) {
  $invokeWebRequestParams.UseBasicParsing = $true
}

# Find latest version folder
$baseXLatestVersion = Invoke-WebRequest -Uri $baseXReleasesUrl @invokeWebRequestParams | 
  Select-Object -ExpandProperty Links | 
  Where-Object {$_.href -match "^\d{2}.\d\/$"} | 
  Select-Object -ExpandProperty href | 
  Sort-Object -Descending | 
  Select-Object -First 1
$baseXLatestVersionUrl = $baseXReleasesUrl + $baseXLatestVersion
# Download .exe file in latest version folder
$baseXWindowsInstallerExecutable = Invoke-WebRequest -Uri $baseXLatestVersionUrl @invokeWebRequestParams | 
  Select-Object -ExpandProperty Links | 
  Where-Object {$_.href -like "BaseX*.exe"} | 
  Select-Object -ExpandProperty href | 
  Select-Object -First 1
$baseXWindowsInstallerExecutableUrl = $baseXLatestVersionUrl + $baseXWindowsInstallerExecutable
$downloadFolder = "$env:USERPROFILE\Downloads"
$installerPath = "$downloadFolder\$baseXWindowsInstallerExecutable"
Invoke-WebRequest -Uri $baseXWindowsInstallerExecutableUrl -OutFile $installerPath @invokeWebRequestParams

if (-not (Test-Path -Path $installerPath -PathType Leaf)) {
  throw "BaseX installer was not downloaded successfully: $installerPath"
}

# Install BaseX
Write-Host "Installing BaseX $baseXLatestVersion..."
Start-Process -FilePath $installerPath -Wait

# Set environment variable BASEX_JVM = -Xmx10G
Write-Host "Setting environment variable BASEX_JVM..."
[Environment]::SetEnvironmentVariable("BASEX_JVM", "-Xmx10G", "Machine")
# Reboot
Write-Host "Rebooting..."
Restart-Computer -Force -Confirm
