Import-Module APIMUtils

$rootPath = "D:\workspace\APIM\export"

# !!!Login to your source subscription first by Select-AzureRmSubscription!!!

$sourceApimResourceGroup = 'Api-Default-West-US'
$sourceApimServiceName = 'YourSrcApimName'
$sourceApimContext = New-AzureRmApiManagementContext -ResourceGroupName $sourceApimResourceGroup -ServiceName $sourceApimServiceName

# Export all information from source APIM
Export-Apim -ApimResourceGroup $sourceApimResourceGroup -ApimServiceName $sourceApimServiceName -ExportRootPath $rootPath

# Now go ahead and change the exported APIM contents as required, and then do the import after you are done

# !!!Login to your sink subscription first by Select-AzureRmSubscription!!!

$sinkApimResourceGroup = 'Api-Default-West-US'
$sinkApimServiceName = 'YourSinkApimName'
$sinkApimContext = New-AzureRmApiManagementContext -ResourceGroupName $sinkApimResourceGroup -ServiceName $sinkApimServiceName

# Import all information to sink APIM
Import-Apim -ApimResourceGroup $sinkApimResourceGroup -ApimServiceName $sinkApimServiceName -ExportRootPath $rootPath


####################################################################################

# For advanced users, you can also try to import/export just API/Product/Policy/Groups/Mapping from APIM
Export-ApimApis -ApimContext $sourceApimContext -ExportRootPath $rootPath
Import-ApimApis -ApimContext $sinkApimResourceGroup -ExportRootPath $rootPath

