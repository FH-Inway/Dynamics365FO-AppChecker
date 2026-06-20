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
$failed = New-Object System.Collections.Generic.List[object]

Write-Host ("Found {0} types matching {1}" -f $axTypes.Count, $TypeNamePattern)
Write-Host ("RAW_MODE={0}" -f ([bool]$Raw))

foreach ($type in $axTypes) {
    $exporter = New-Object System.Runtime.Serialization.XsdDataContractExporter

    if (-not $exporter.CanExport($type)) {
        Write-Warning "Cannot export type: $($type.FullName)"
        $failed.Add([PSCustomObject]@{
                Type = $type.Name
                Reason = "CanExport returned false"
            }) | Out-Null
        continue
    }

    try {
        $exporter.Export($type)
    } catch {
        Write-Warning "Export failed for type $($type.FullName): $($_.Exception.Message)"
        $failed.Add([PSCustomObject]@{
                Type = $type.Name
                Reason = $_.Exception.Message
            }) | Out-Null
        continue
    }

    $mainSchema = $exporter.Schemas.Schemas() |
        Where-Object {
            $_.TargetNamespace -ne "http://schemas.microsoft.com/2003/10/Serialization/" -and
            $_.TargetNamespace -ne "http://www.w3.org/2001/XMLSchema"
        } |
        Select-Object -First 1

    if (-not $mainSchema) {
        Write-Warning "No main schema produced for type: $($type.FullName)"
        $failed.Add([PSCustomObject]@{
                Type = $type.Name
                Reason = "No non-WCF schema returned by exporter"
            }) | Out-Null
        continue
    }

    $sw = New-Object System.IO.StringWriter
    $mainSchema.Write($sw)
    [string]$xsd = $sw.ToString()

    $outputFile = Join-Path $OutputFolder ("{0}-DataContract.xsd" -f $type.Name)
    if ($Raw) {
        [System.IO.File]::WriteAllText($outputFile, $xsd, [System.Text.Encoding]::Unicode)
    } else {
        $cleanDoc = ConvertTo-CleanSchemaDocument -SchemaXml $xsd
        Save-SchemaDocument -SchemaDocument $cleanDoc -Path $outputFile
    }

    $exported.Add([PSCustomObject]@{
            Type = $type.Name
            File = $outputFile
        }) | Out-Null
}

$result = if ($failed.Count -gt 0) { "PARTIAL" } else { "OK" }
Write-Host "EXPORT_RESULT=$result"
Write-Host "OUTPUT_FOLDER=$OutputFolder"
Write-Host "TOTAL_TYPES=$($axTypes.Count)"
Write-Host "EXPORTED_COUNT=$($exported.Count)"
Write-Host "FAILED_COUNT=$($failed.Count)"

if ($failed.Count -gt 0) {
    Write-Host ("FAILED_TYPES={0}" -f (($failed | Select-Object -ExpandProperty Type) -join ","))
}
