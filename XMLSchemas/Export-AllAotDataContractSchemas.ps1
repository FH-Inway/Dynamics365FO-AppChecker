<#
.SYNOPSIS
    Generates XSD schemas for all D365FO Ax* DataContract types.

.DESCRIPTION
    Loads Microsoft.Dynamics.AX.Metadata.dll from the D365FO packages
    directory, exports one schema per Ax* type with XsdDataContractExporter,
    and writes the output files to a folder (default: .\AOTSchemas).

    Post-processing applied to each raw exporter output:
      - WCF serialization boilerplate (DefaultValue/GenericType appinfo) is stripped.
      - The xs:import for the WCF serialization namespace is removed when unused.

.PARAMETER MetadataBinDir
    Path to the D365FO metadata assemblies directory.
    Defaults to C:\AOSService\PackagesLocalDirectory\bin.

.PARAMETER OutputFolder
    Folder where generated schema files are written.
    Defaults to .\AOTSchemas under this script folder.

.PARAMETER TypeNamePattern
    Wildcard pattern used to select types from the metadata assembly.
    Defaults to Ax*.

.PARAMETER Raw
    Writes the extracted schema exactly as exported (no cleanup or post-processing).

.EXAMPLE
    .\Export-AllAotDataContractSchemas.ps1

.EXAMPLE
    .\Export-AllAotDataContractSchemas.ps1 -TypeNamePattern "AxTable*"

.EXAMPLE
    .\Export-AllAotDataContractSchemas.ps1 -Raw
#>
param(
    [string]$MetadataBinDir = "C:\AOSService\PackagesLocalDirectory\bin",
    [string]$OutputFolder = "$PSScriptRoot\AOTSchemas",
    [string]$TypeNamePattern = "Ax*",
    [switch]$Raw
)

$ErrorActionPreference = "Stop"

function ConvertTo-CleanSchemaDocument {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SchemaXml
    )

    $doc = New-Object System.Xml.XmlDocument
    $doc.LoadXml($SchemaXml)

    $xsNs = "http://www.w3.org/2001/XMLSchema"
    $wcfNs = "http://schemas.microsoft.com/2003/10/Serialization/"

    $nsMgr = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
    $nsMgr.AddNamespace("xs", $xsNs)
    $nsMgr.AddNamespace("wcf", $wcfNs)

    $importNodes = $doc.SelectNodes("//xs:import[@namespace='$wcfNs']", $nsMgr)
    foreach ($node in @($importNodes)) {
        $node.ParentNode.RemoveChild($node) | Out-Null
    }

    $wcfStrippableLocalNames = @('DefaultValue', 'GenericType')
    $annotationNodes = $doc.SelectNodes("//xs:annotation", $nsMgr)
    foreach ($annotation in @($annotationNodes)) {
        $appinfos = $annotation.SelectNodes("xs:appinfo", $nsMgr)
        if ($appinfos.Count -eq 0) { continue }

        $allAppinfosAreWcfOnly = $true
        foreach ($appinfo in @($appinfos)) {
            foreach ($child in @($appinfo.ChildNodes)) {
                if ($child.NodeType -eq [System.Xml.XmlNodeType]::Element) {
                    $isWcf = ($child.NamespaceURI -eq $wcfNs) -and ($wcfStrippableLocalNames -contains $child.LocalName)
                    if (-not $isWcf) {
                        $allAppinfosAreWcfOnly = $false
                        break
                    }
                }
            }
            if (-not $allAppinfosAreWcfOnly) { break }
        }

        if ($allAppinfosAreWcfOnly) {
            $annotation.ParentNode.RemoveChild($annotation) | Out-Null
        }
    }

    return $doc
}

function Save-SchemaDocument {
    param(
        [Parameter(Mandatory = $true)]
        [System.Xml.XmlDocument]$SchemaDocument,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Indent = $true
    $settings.IndentChars = "  "
    $settings.Encoding = [System.Text.Encoding]::UTF8
    $settings.OmitXmlDeclaration = $false

    $ms = New-Object System.IO.MemoryStream
    $writer = [System.Xml.XmlWriter]::Create($ms, $settings)
    $SchemaDocument.Save($writer)
    $writer.Flush()
    $writer.Close()

    [System.IO.File]::WriteAllBytes($Path, $ms.ToArray())
}

function Get-TypeOutputFilePath {
    param(
        [Parameter(Mandatory = $true)]
        [Type]$Type,
        [Parameter(Mandatory = $true)]
        [string]$BaseFolder
    )

    $fullNameBytes = [System.Text.Encoding]::UTF8.GetBytes($Type.FullName)
    $hashBytes = [System.Security.Cryptography.MD5]::Create().ComputeHash($fullNameBytes)
    $hash = ([System.BitConverter]::ToString($hashBytes)).Replace("-", "").Substring(0, 8).ToLowerInvariant()
    $fileName = "{0}-{1}-DataContract.xsd" -f $Type.Name, $hash
    return (Join-Path $BaseFolder $fileName)
}

function Invoke-TypeExport {
    param(
        [Parameter(Mandatory = $true)]
        [Type]$Type,
        [Parameter(Mandatory = $true)]
        [string]$BaseFolder,
        [switch]$RawOutput,
        [switch]$SkipCanExportCheck,
        [string]$WarningPrefix = ""
    )

    $warningLabel = if ([string]::IsNullOrWhiteSpace($WarningPrefix)) { "" } else { "$WarningPrefix " }
    $exporter = New-Object System.Runtime.Serialization.XsdDataContractExporter

    if (-not $SkipCanExportCheck) {
        $canExport = $false
        try {
            $canExport = $exporter.CanExport($Type)
        } catch {
            $reason = "CanExport error: $($_.Exception.Message)"
            Write-Warning "$($warningLabel)CanExport failed for type $($Type.FullName): $($_.Exception.Message)"
            return [PSCustomObject]@{
                Success = $false
                Type = $Type.Name
                FullName = $Type.FullName
                Reason = $reason
                File = $null
            }
        }

        if (-not $canExport) {
            $reason = "CanExport returned false"
            Write-Warning "$($warningLabel)Cannot export type: $($Type.FullName)"
            return [PSCustomObject]@{
                Success = $false
                Type = $Type.Name
                FullName = $Type.FullName
                Reason = $reason
                File = $null
            }
        }
    }

    try {
        $exporter.Export($Type)
    } catch {
        $reason = "Export error: $($_.Exception.Message)"
        Write-Warning "$($warningLabel)Export failed for type $($Type.FullName): $($_.Exception.Message)"
        return [PSCustomObject]@{
            Success = $false
            Type = $Type.Name
            FullName = $Type.FullName
            Reason = $reason
            File = $null
        }
    }

    $mainSchema = $exporter.Schemas.Schemas() |
        Where-Object {
            $_.TargetNamespace -ne "http://schemas.microsoft.com/2003/10/Serialization/" -and
            $_.TargetNamespace -ne "http://www.w3.org/2001/XMLSchema"
        } |
        Select-Object -First 1

    if (-not $mainSchema) {
        $reason = "No non-WCF schema returned by exporter"
        Write-Warning "$($warningLabel)No main schema produced for type: $($Type.FullName)"
        return [PSCustomObject]@{
            Success = $false
            Type = $Type.Name
            FullName = $Type.FullName
            Reason = $reason
            File = $null
        }
    }

    $sw = New-Object System.IO.StringWriter
    $mainSchema.Write($sw)
    [string]$xsd = $sw.ToString()

    $outputFile = Get-TypeOutputFilePath -Type $Type -BaseFolder $BaseFolder
    if ($RawOutput) {
        [System.IO.File]::WriteAllText($outputFile, $xsd, [System.Text.Encoding]::Unicode)
    } else {
        $cleanDoc = ConvertTo-CleanSchemaDocument -SchemaXml $xsd
        Save-SchemaDocument -SchemaDocument $cleanDoc -Path $outputFile
    }

    return [PSCustomObject]@{
        Success = $true
        Type = $Type.Name
        FullName = $Type.FullName
        Reason = $null
        File = $outputFile
    }
}

$metadataDll = Join-Path $MetadataBinDir "Microsoft.Dynamics.AX.Metadata.dll"
if (-not (Test-Path $metadataDll)) {
    throw "Microsoft.Dynamics.AX.Metadata.dll not found at: $metadataDll"
}

Write-Host "Loading: $metadataDll"
$asm = [System.Reflection.Assembly]::LoadFrom($metadataDll)

Add-Type -AssemblyName "System.Runtime.Serialization"

$axTypes = $asm.GetTypes() |
    Where-Object { $_.Name -like $TypeNamePattern } |
    Sort-Object -Property Name

if (-not $axTypes -or $axTypes.Count -eq 0) {
    throw "No types found matching pattern '$TypeNamePattern'."
}

if (-not (Test-Path $OutputFolder)) {
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
}

$exported = New-Object System.Collections.Generic.List[object]
$initialFailures = New-Object System.Collections.Generic.List[object]

Write-Host ("Found {0} types matching {1}" -f $axTypes.Count, $TypeNamePattern)
Write-Host ("RAW_MODE={0}" -f ([bool]$Raw))

foreach ($type in $axTypes) {
    $result = Invoke-TypeExport -Type $type -BaseFolder $OutputFolder -RawOutput:$Raw
    if ($result.Success) {
        $exported.Add([PSCustomObject]@{
                Type = $result.Type
                FullName = $result.FullName
                File = $result.File
            }) | Out-Null
    } else {
        $initialFailures.Add([PSCustomObject]@{
                Type = $result.Type
                FullName = $result.FullName
                Reason = $result.Reason
            }) | Out-Null
    }
}

$collisionFailures = @(
    $initialFailures |
        Where-Object {
            $_.Reason -match "same data contract name" -and
            $_.Reason -match "not equivalent"
        }
)

$recovered = New-Object 'System.Collections.Generic.HashSet[string]'
if ($collisionFailures.Count -gt 0) {
    $collisionTypeLookup = @{}
    foreach ($type in $axTypes) {
        $collisionTypeLookup[$type.FullName] = $type
    }

    Write-Host ("RETRY_COLLISION_FAILURES={0}" -f $collisionFailures.Count)

    foreach ($failure in $collisionFailures) {
        if (-not $collisionTypeLookup.ContainsKey($failure.FullName)) {
            continue
        }

        $retryType = $collisionTypeLookup[$failure.FullName]
        $retryResult = Invoke-TypeExport -Type $retryType -BaseFolder $OutputFolder -RawOutput:$Raw -SkipCanExportCheck -WarningPrefix "Retry:"
        if ($retryResult.Success) {
            $recovered.Add($retryResult.FullName) | Out-Null
            $exported.Add([PSCustomObject]@{
                    Type = $retryResult.Type
                    FullName = $retryResult.FullName
                    File = $retryResult.File
                }) | Out-Null
        }
    }
}

$failed = @(
    $initialFailures |
        Where-Object { -not $recovered.Contains($_.FullName) }
)

$result = if ($failed.Count -gt 0) { "PARTIAL" } else { "OK" }
Write-Host "EXPORT_RESULT=$result"
Write-Host "OUTPUT_FOLDER=$OutputFolder"
Write-Host "TOTAL_TYPES=$($axTypes.Count)"
Write-Host "EXPORTED_COUNT=$($exported.Count)"
Write-Host "FAILED_COUNT=$($failed.Count)"

if ($failed.Count -gt 0) {
    Write-Host ("FAILED_TYPES={0}" -f (($failed | Select-Object -ExpandProperty FullName) -join ","))
}
