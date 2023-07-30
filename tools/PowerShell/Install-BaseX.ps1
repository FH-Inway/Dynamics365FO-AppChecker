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

  # Check if the Java version is available and greater than or equal to 11
  if (-not $javaVersion -or [Version]$javaVersion -lt [Version]'11.0') {
      Write-Host "Please install Java 11 or higher before proceeding."
      return $false
  }

  return $true
}

# Check if Java is installed
if (-not (CheckJava)) {
  # Download and install Java
  Write-Host "Installing Java..."
  # choco install temurin17
  choco install temurin17
}

# Download BaseX
Write-Host "Downloading BaseX..."
$baseXReleasesUrl = "http://files.basex.org/releases/"
# Find latest version folder
$baseXLatestVersion = Invoke-WebRequest -Uri $baseXReleasesUrl | Select-Object -ExpandProperty Links | Where-Object {$_.href -match "^\d{2}.\d\/$"} | Select-Object -ExpandProperty href | Sort-Object -Descending | Select-Object -First 1
$baseXLatestVersionUrl = $baseXReleasesUrl + $baseXLatestVersion
# Download .exe file in latest version folder
$baseXWindowsInstallerExecutable = Invoke-WebRequest -Uri $baseXLatestVersionUrl | Select-Object -ExpandProperty Links | Where-Object {$_.href -like "BaseX*.exe"} | Select-Object -ExpandProperty href | Select-Object -First 1
$baseXWindowsInstallerExecutableUrl = $baseXLatestVersionUrl + $baseXWindowsInstallerExecutable
$downloadFolder = "$env:USERPROFILE\Downloads"
Invoke-WebRequest -Uri $baseXWindowsInstallerExecutableUrl -OutFile "$downloadFolder\$baseXWindowsInstallerExecutable"

# Install BaseX
Write-Host "Installing BaseX..."
Start-Process -FilePath "$downloadFolder\$baseXWindowsInstallerExecutable" -Wait

# Set environment variable BASEX_JVM = -Xmx10G
Write-Host "Setting environment variable BASEX_JVM..."
[Environment]::SetEnvironmentVariable("BASEX_JVM", "-Xmx10G", "Machine")
# Reboot
Write-Host "Rebooting..."
Restart-Computer -Force -Confirm
