$params = @{
    BaseFolder        = 'C:\AOSService\PackagesLocalDirectory'
    SubFolders        = @()
    ExcludeSubFolders = @()
    Xsd10SchemaPath   = '.\XMLSchemas\EDTSchema\AxEdt.1.0.xsd'
    # SkipXsd11        = $true
    Xsd11SchemaPath   = '.\XMLSchemas\EDTSchema\AxEdt.1.1.xsd'
    # SkipXsd10         = $true
    # OutputCsvPath     = '.\XMLSchemas\EDTSchema\edt-bulk-application-suite-xsd10-20260321-retry.csv'
    # StopOnFailure     = $true
    # RetryFailuresCsvPath = '.\XMLSchemas\EDTSchema\edt-bulk-application-suite-xsd10-20260321.csv'
}

$params.SubFolders = @('ApplicationCommon')
$params.ExcludeSubFolders = @('ApplicationSuite')

.\XMLSchemas\EDTSchema\Validate-EdtBulk.ps1 @params

basex -b element=TimeMinute '.\XMLSchemas\EDTSchema\edt-element-values.xq' 2>&1
