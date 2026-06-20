<#
.SYNOPSIS
    Generates an XSD schema for D365FO EDT metadata by reflecting on the
    Ax* DataContract types in Microsoft.Dynamics.AX.Metadata.dll using
    XsdDataContractExporter.

.DESCRIPTION
    Loads Microsoft.Dynamics.AX.Metadata.dll from the D365FO packages
    directory, runs XsdDataContractExporter over all AxEdt* types, and
    writes the resulting schema to a file in this folder.

    The generated schema is authoritative and version-matched: enum value
    sets and element lists come directly from the DataContract definitions
    in the installed product, so they cannot drift from the serialized XML.

    Post-processing applied to the raw exporter output:
      - WCF serialization boilerplate (DefaultValue appinfo) is stripped.
      - Mangled KeyedObjectCollection type names are replaced with readable
        names (e.g. AxEdtArrayElements, AxEdtRelations, etc.).
      - The xs:import for the WCF serialization namespace is removed since
        the only content it contributed (DefaultValue annotations) is gone.

    Limitations of the generated schema vs. the hand-crafted XSD:
      - All elements are optional (minOccurs="0"); required fields like
        Name are not enforced.
      - No root element declaration; cannot validate a document root.
      - XSD 1.0 only; no xs:assert for cross-field constraints.
      - nillable="true" is retained on all elements (DataContract default).

.PARAMETER MetadataBinDir
    Path to the D365FO metadata assemblies directory.
    Defaults to C:\AOSService\PackagesLocalDirectory\bin.

.PARAMETER OutputFile
    Path of the XSD file to write.
    Defaults to AxEdt-DataContract.xsd in the same folder as this script.

.EXAMPLE
    .\Export-AxEdtDataContractSchema.ps1

.EXAMPLE
    .\Export-AxEdtDataContractSchema.ps1 -MetadataBinDir "D:\AOS\PackagesLocalDirectory\bin"
#>
param(
    [string]$MetadataBinDir = "C:\AOSService\PackagesLocalDirectory\bin",
    [string]$OutputFile = "$PSScriptRoot\AxEdt-DataContract.xsd"
)

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Load assembly
# ---------------------------------------------------------------------------

$metadataDll = Join-Path $MetadataBinDir "Microsoft.Dynamics.AX.Metadata.dll"
if (-not (Test-Path $metadataDll)) {
    throw "Microsoft.Dynamics.AX.Metadata.dll not found at: $metadataDll"
}

Write-Host "Loading: $metadataDll"
$asm = [System.Reflection.Assembly]::LoadFrom($metadataDll)

# ---------------------------------------------------------------------------
# Collect AxEdt* types
# ---------------------------------------------------------------------------

$edtTypes = $asm.GetTypes() | Where-Object { $_.Name -like "AxEdt*" }
Write-Host ("Found {0} AxEdt* types: {1}" -f $edtTypes.Count, (($edtTypes | ForEach-Object { $_.Name }) -join ", "))

# ---------------------------------------------------------------------------
# Export schemas via XsdDataContractExporter
# ---------------------------------------------------------------------------

Add-Type -AssemblyName "System.Runtime.Serialization"
$exporter = New-Object System.Runtime.Serialization.XsdDataContractExporter

foreach ($type in $edtTypes) {
    if ($exporter.CanExport($type)) {
        $exporter.Export($type)
    } else {
        Write-Warning "Cannot export type: $($type.Name)"
    }
}

# The exporter produces up to three schemas:
#   1. http://schemas.microsoft.com/2003/10/Serialization/  — WCF boilerplate
#   2. (empty namespace)                                    — the actual types
#   3. http://www.w3.org/2001/XMLSchema                     — xs: built-ins
# We only want the empty-namespace schema.

$mainSchema = $exporter.Schemas.Schemas() |
    Where-Object {
        $_.TargetNamespace -ne "http://schemas.microsoft.com/2003/10/Serialization/" -and
        $_.TargetNamespace -ne "http://www.w3.org/2001/XMLSchema"
    } |
    Select-Object -First 1

if (-not $mainSchema) {
    throw "Could not locate the main (non-WCF) schema in the exporter output."
}

$sw = New-Object System.IO.StringWriter
$mainSchema.Write($sw)
[string]$xsd = $sw.ToString()

# ---------------------------------------------------------------------------
# Post-processing via XML DOM
# ---------------------------------------------------------------------------

# Parse the schema as an XmlDocument for reliable, whitespace-agnostic edits.
$doc = New-Object System.Xml.XmlDocument
$doc.LoadXml($xsd)

$xsNs  = "http://www.w3.org/2001/XMLSchema"
$wcfNs = "http://schemas.microsoft.com/2003/10/Serialization/"

$nsMgr = New-Object System.Xml.XmlNamespaceManager($doc.NameTable)
$nsMgr.AddNamespace("xs",  $xsNs)
$nsMgr.AddNamespace("wcf", $wcfNs)

# 1. Remove xs:import for the WCF serialization namespace — it is only
#    referenced by DefaultValue appinfo annotations which we strip next.
$importNodes = $doc.SelectNodes("//xs:import[@namespace='$wcfNs']", $nsMgr)
foreach ($node in @($importNodes)) {
    $node.ParentNode.RemoveChild($node) | Out-Null
}

# 2. Strip xs:annotation elements whose xs:appinfo children contain only WCF
#    serialization hints (DefaultValue, GenericType) with no validation value.
#    EnumerationValue annotations (integer backing values for enum members) are
#    kept because they provide useful cross-reference metadata.
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

# 3. Rename mangled KeyedObjectCollection type names to readable names.
#    The mangled suffix (NcCATIYq) is a stable hash from DataContract's generic
#    type naming; it is identical across builds for the same type parameters.
$mangledRenames = [ordered]@{
    'KeyedObjectCollectionOfAxEdtArrayElementNcCATIYq'      = 'AxEdtArrayElements'
    'KeyedObjectCollectionOfAxEdtRelationNcCATIYq'          = 'AxEdtRelations'
    'KeyedObjectCollectionOfAxEdtTableReferenceNcCATIYq'    = 'AxEdtTableReferences'
    'KeyedObjectCollectionOfAxPropertyModificationNcCATIYq' = 'AxPropertyModifications'
}

# Rename in all name="..." and type="..." attributes across the document.
$allElements = $doc.SelectNodes("//*", $nsMgr)
foreach ($el in @($allElements)) {
    foreach ($attr in @($el.Attributes)) {
        foreach ($mangled in $mangledRenames.Keys) {
            if ($attr.Value -eq $mangled) {
                $attr.Value = $mangledRenames[$mangled]
            }
        }
    }
}

# ---------------------------------------------------------------------------
# Write output
# ---------------------------------------------------------------------------

$outputDir = Split-Path $OutputFile -Parent
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

# Serialize with utf-8 encoding and indentation.
$settings = New-Object System.Xml.XmlWriterSettings
$settings.Indent = $true
$settings.IndentChars = "  "
$settings.Encoding = [System.Text.Encoding]::UTF8
$settings.OmitXmlDeclaration = $false

$ms = New-Object System.IO.MemoryStream
$writer = [System.Xml.XmlWriter]::Create($ms, $settings)
$doc.Save($writer)
$writer.Flush()
$writer.Close()

[System.IO.File]::WriteAllBytes($OutputFile, $ms.ToArray())

Write-Host "EXPORT_RESULT=OK"
Write-Host "OUTPUT_FILE=$OutputFile"
