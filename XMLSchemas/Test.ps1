
$param = @{
    OutputFolder = 'C:\Repositories\Dynamics365FO-AppChecker\XMLSchemas\Collisions'
    TypeNamePattern = 'AxFormDataSource'
}

.\XMLSchemas\Export-AllAotDataContractSchemas.ps1 @param


# Notes

# ApplicationSuite does not seem to have been added with all models to the database.
# There seem to be new ATL modules.