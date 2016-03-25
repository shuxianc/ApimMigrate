function Export-Apim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ApimResourceGroup,
        [string]
        $ApimServiceName,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $ApimContext = New-AzureRmApiManagementContext -ResourceGroupName $ApimResourceGroup -ServiceName $ApimServiceName
        Export-ApimProducts -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Export-ApimApis -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Export-ApimGroups -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Export-ApimPolicies -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Export-ApimMappings -ApimContext $ApimContext -ExportRootPath $ExportRootPath
    }
}

function Export-ApimProducts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $sourceApimProducts = Get-AzureRmApiManagementProduct -Context $ApimContext
        
        $productsDir = "$ExportRootPath\products"

        if (!(Test-Path -Path $productsDir)) {
            New-Item -ItemType directory -Path $productsDir
        }

        foreach ($p in $sourceApimProducts)
        {
            $fileName = $p.ProductId + "_" + $p.Title + ".xml"
            Export-Clixml -InputObject $p -Path "$productsDir\$fileName"
        }

    }
}

function Export-ApimGroups {
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $sourceApimGroups = Get-AzureRmApiManagementGroup -Context $ApimContext
        $groupsDir = "$ExportRootPath\groups"

        if (!(Test-Path -Path $groupsDir)) {
            New-Item -ItemType directory -Path $groupsDir
        }

        foreach ($g in $sourceApimGroups)
        {
            $fileName = $g.GroupId + "_" + $g.Name + ".xml"
            Export-Clixml -InputObject $g -Path "$groupsDir\$fileName"
        }
    }
}

function Export-ApimMappings {
    [cmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        Add-Type -Language CSharpVersion3 -TypeDefinition @"
        public class Mapping
        {
            public Mapping() {}
            public string ProductId { get; set; }
            public string ApiIds { get; set; }
            public string GroupIds { get; set; }
        } 
"@
        $mappings = New-Object System.Collections.Generic.List``1[Mapping]
        
        $products = Get-AzureRmApiManagementProduct -Context $ApimContext
        foreach ($p in $products)
        {
            $apis = Get-AzureRmApiManagementApi -Context $ApimContext -ProductId $p.ProductId
            $apisStr = ""
            foreach ($api in $apis)
            {
                $apisStr += $api.ApiId
                if ($api -ne $apis[-1])
                {
                    $apisStr += ","
                }
            }

            $groups = Get-AzureRmApiManagementGroup -Context $ApimContext -ProductId $p.ProductId
            $groupsStr = ""
            foreach ($g in $groups)
            {
                $groupsStr += $g.GroupId
                if ($g -ne $groups[-1])
                {
                    $groupsStr += ","
                }
            }

            $mapping = New-Object Mapping
            $mapping.ProductId = $p.ProductId
            $mapping.GroupIds = $groupsStr
            $mapping.ApiIds = $apisStr

            $mappings.Add($mapping)
        }

        $fileName = "mapping.xml"
        Export-Clixml -InputObject $mappings -Path "$ExportRootPath\$fileName"
    }
}

function Export-ApimPolicies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        
        $policiesDir = "$ExportRootPath\policies"
        if (!(Test-Path -Path $policiesDir)) {
            New-Item -ItemType directory -Path $policiesDir
        }

        # get tenant-scope policies
        $tenantDir = "$policiesDir\tenant"
        if (!(Test-Path -Path $tenantDir)) {
            New-Item -ItemType directory -Path $tenantDir
        }

        Get-AzureRmApiManagementPolicy -Context $ApimContext -SaveAs "$tenantDir\tenantpolicy.xml"
        
        # get product-scope policies
        $productDir = "$policiesDir\product"
        if (!(Test-Path -Path $productDir)) {
            New-Item -ItemType directory -Path $productDir
        }

        $products = Get-AzureRmApiManagementProduct -Context $ApimContext

        foreach ($p in $products)
        {
            $fileName = $p.ProductId + "_" + $p.Title + ".xml"
            Get-AzureRmApiManagementPolicy -Context $ApimContext -ProductId $p.ProductId -SaveAs "$productDir\$fileName"
        }

        # get api-scope policies
        $apisDir = "$policiesDir\api"
        if (!(Test-Path -Path $apisDir)) {
            New-Item -ItemType directory -Path $apisDir
        }

        $apis = Get-AzureRmApiManagementApi -Context $ApimContext

        foreach ($api in $apis)
        {
            $apiDir = $apisDir + "\" + $api.ApiId + "_" + $api.Name  # Create one directory for each api
            if (!(Test-Path -Path $apiDir)) {
                New-Item -ItemType directory -Path $apiDir
            }
            $fileName = $api.ApiId + ".xml"
            Get-AzureRmApiManagementPolicy -Context $ApimContext -ApiId $api.ApiId -SaveAs "$apiDir\$fileName"

            # get operation-scope policies
            $opsDir = "$apiDir\operations"
            if (!(Test-Path -Path $opsDir)) {
                New-Item -ItemType directory -Path $opsDir
            }

            $ops = Get-AzureRmApiManagementOperation -Context $ApimContext -ApiId $api.ApiId  
            foreach ($op in $ops)
            {
                $opName = $op.Name + ".xml"
                $opName = $opName -replace "\/","_" # A dirty fix to deal with operations containg "/"
                Get-AzureRmApiManagementPolicy -Context $ApimContext -ApiId $api.ApiId -OperationId $op.OperationId -SaveAs "$opsDir\$opName"
            }
        }
    }
}

function Export-ApimApis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $sourceApimApis = Get-AzureRmApiManagementApi -Context $ApimContext

        $apisDir = "$ExportRootPath\apis"

        if (!(Test-Path -Path $apisDir)) {
            New-Item -ItemType directory -Path $apisDir
        }

        foreach ($api in $sourceApimApis)
        {
            $apiDir = $apisDir + "\" + $api.ApiId + "_" + $api.Name  # Create one directory for each api
            if (!(Test-Path -Path $apiDir)) {
                New-Item -ItemType directory -Path $apiDir
            }

            $fileName = $api.ApiId + ".swagger.json"
            Export-AzureRmApiManagementApi -Context $ApimContext -SpecificationFormat 'Swagger' -SaveAs "$apiDir\$fileName" -ApiId $api.ApiId

            # save ServiceUrl
            $getResult = Get-AzureRmApiManagementApi -Context $ApimContext -ApiId $api.ApiId
            ($getResult.ServiceUrl.Split('/'))[2] | Out-File "$apiDir\url.txt"

            $ops = Get-AzureRmApiManagementOperation -Context $ApimContext -ApiId $api.ApiId  # save all operations under this API
        }
    }
}

function Import-ApimGroups {  # There is no need to import built-in groups Administrators/Developers/Guests
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $groupsDir = "$ExportRootPath\groups"
        $groups = Get-ChildItem "$groupsDir" -Filter "*.xml"

        foreach ($group in $groups)
        {
            $groupObj = Import-Clixml -Path $group.FullName
            if ($groupObj.Name -ne "Administrators" -and $groupObj.Name -ne "Developers" -and $groupObj.Name -ne "Guests")  # skip built in groups
            {
                $getResult = Get-AzureRmApiManagementGroup -Context $ApimContext -GroupId $groupObj.GroupId -EA SilentlyContinue

                if ($getResult)
                {
                    Set-AzureRmApiManagementGroup -Context $ApimContext -Description $groupObj.Description -Name $groupObj.Name -GroupId $groupObj.GroupId
                }
                else
                {
                    New-AzureRmApiManagementGroup -Context $ApimContext -Description $groupObj.Description -Name $groupObj.Name -GroupId $groupObj.GroupId
                }
            }
            else # replace GroupIds in mapping.xml for built in groups
            {
                $sourceGroupId = $groupObj.GroupId
                $sinkGroupObj = Get-AzureRmApiManagementGroup -Context $ApimContext -Name $groupObj.Name
                $sinkGroupId = $sinkGroupObj.GroupId
                $mappingFile = "$ExportRootPath\mapping.xml"
                $mappingContent = Get-Content $mappingFile
                $mappingContent -replace "$sourceGroupId","$sinkGroupId" | Set-Content $mappingFile  # write back
            }
        }
    }
}

function Restore-ApimMappings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $groupsDir = "$ExportRootPath\groups"
        $groups = Get-ChildItem "$groupsDir" -Filter "*.xml"

        foreach ($group in $groups)
        {
            $groupObj = Import-Clixml -Path $group.FullName
            if ($groupObj.Name -eq "Administrators" -or $groupObj.Name -eq "Developers" -or $groupObj.Name -eq "Guests")
            {
                $sourceGroupId = $groupObj.GroupId
                $sinkGroupObj = Get-AzureRmApiManagementGroup -Context $ApimContext -Name $groupObj.Name
                $sinkGroupId = $sinkGroupObj.GroupId
                $mappingFile = "$ExportRootPath\mapping.xml"
                $mappingContent = Get-Content $mappingFile
                $mappingContent -replace "$sinkGroupId","$sourceGroupId" | Set-Content $mappingFile  # write back
            }
        }
    }
}

function Import-ApimProducts { # no need to import Starter and Unlimited? These two products will not exist in the first place in our APIMs
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $productsDir = "$ExportRootPath\products"
        $products = Get-ChildItem "$productsDir" -Filter "*.xml"

        foreach ($product in $products)
        {
            $productObj = Import-Clixml -Path $product.FullName

            $getResult = Get-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -EA SilentlyContinue

            if ($getResult)
            {
                if ($productObj.SubscriptionRequired) {
                    Set-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -Title $productObj.Title -Description $productObj.Description -LegalTerms $productObj.LegalTerms -ApprovalRequired $productObj.ApprovalRequired -SubscriptionsLimit $productObj.SubscriptionsLimit -SubscriptionRequired $productObj.SubscriptionRequired
                } else {
                    Set-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -Title $productObj.Title -Description $productObj.Description -LegalTerms $productObj.LegalTerms -SubscriptionRequired $productObj.SubscriptionRequired
                }
            }
            else
            {
                if ($productObj.SubscriptionRequired) {
                    New-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -Title $productObj.Title -Description $productObj.Description -LegalTerms $productObj.LegalTerms -ApprovalRequired $productObj.ApprovalRequired -SubscriptionsLimit $productObj.SubscriptionsLimit -SubscriptionRequired $productObj.SubscriptionRequired
                } else {
                    # workaround
                    New-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -Title $productObj.Title -Description $productObj.Description -LegalTerms $productObj.LegalTerms
                    Set-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -Title $productObj.Title -Description $productObj.Description -LegalTerms $productObj.LegalTerms -SubscriptionRequired $false
                }
            }
        }
    }
}

function Import-Apim {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]
        $ApimResourceGroup,
        [string]
        $ApimServiceName,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $ApimContext = New-AzureRmApiManagementContext -ResourceGroupName $ApimResourceGroup -ServiceName $ApimServiceName
        Import-ApimApis -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Import-ApimProducts -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Import-ApimGroups -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Import-ApimMappings -ApimContext $ApimContext -ExportRootPath $ExportRootPath        
        Restore-ApimProductState -ApimContext $ApimContext -ExportRootPath $ExportRootPath        
        Import-ApimPolicies -ApimContext $ApimContext -ExportRootPath $ExportRootPath
        Restore-ApimMappings -ApimContext $ApimContext -ExportRootPath $ExportRootPath
    }
}

function Import-ApimApis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $apisDir = "$ExportRootPath\apis"
        $apiFolders = Get-ChildItem "$apisDir" | ?{ $_.PSIsContainer }

        foreach ($apiFolder in $apiFolders)
        {
            $apiId = $apiFolder.Name.Split('_')[0]
            $urlFile = $apiFolder.FullName + "\url.txt"
            $swagger = (Get-ChildItem $apiFolder.FullName -Filter "$apiId.swagger.json").FullName
            $swaggerObj = (Get-Content $swagger) -join "`n" | ConvertFrom-Json
            $newUrl = Get-Content $urlFile
            $jsonContent = Get-Content $swagger
            $jsonContent -replace "`"host`":.+","`"host`": `"$newUrl`"," | Set-Content $swagger  # write back to replace original json

            Import-AzureRmApiManagementApi -Context $ApimContext -SpecificationFormat 'Swagger' -SpecificationPath $swagger -ApiId $apiId -Path $swaggerObj.basePath
        }
    }
}

function Import-ApimMappings {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $mappings = Import-Clixml -Path "$ExportRootPath\mapping.xml"

        foreach ($mapping in $mappings)
        {
            $apis = $mapping.ApiIds.Split(',')
            $groups = $mapping.GroupIds.Split(',')
            foreach ($api in $apis)
            {
                Add-AzureRmApiManagementApiToProduct -Context $ApimContext -ProductId $mapping.ProductId -ApiId $api
            }
            foreach ($group in $groups)
            {
                Add-AzureRmApiManagementProductToGroup -Context $ApimContext -GroupId $group -ProductId $mapping.ProductId
            }
        }
    }
}

function Restore-ApimProductState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $productsDir = "$ExportRootPath\products"
        $products = Get-ChildItem "$productsDir" -Filter "*.xml"

        foreach ($product in $products)
        {
            $productObj = Import-Clixml -Path $product.FullName
            Set-AzureRmApiManagementProduct -Context $ApimContext -ProductId $productObj.ProductId -State $productObj.State
        }

    }
}

function Import-ApimPolicies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [Microsoft.Azure.Commands.ApiManagement.ServiceManagement.Models.PsApiManagementContext]
        $ApimContext,
        [Parameter(Mandatory=$true)]
        [string]
        $ExportRootPath
    )
    process {
        $policiesDir = "$ExportRootPath\policies"

        # set tenant-scope policies
        $tenantDir = "$policiesDir\tenant"
        Set-AzureRmApiManagementPolicy -Context $ApimContext -PolicyFilePath "$tenantDir\tenantpolicy.xml"

        # set product-scope policies
        $productDir = "$policiesDir\product"
        $products = Get-ChildItem "$productDir" -Filter "*.xml"

        foreach ($product in $products)
        {
            $productId = $product.Name.Split('_')[0]
            Set-AzureRmApiManagementPolicy -Context $ApimContext -ProductId $productId -PolicyFilePath $product.FullName
        }

        # set api-scope and op-scope policies
        $apisDir = "$policiesDir\api"

        $apiFolders = Get-ChildItem "$apisDir" | ?{ $_.PSIsContainer }

        foreach ($apiFolder in $apiFolders)
        {
            $apiId = $apiFolder.Name.Split('_')[0]
            $apiPolicy = (Get-ChildItem $apiFolder.FullName -Filter "$apiId.xml").FullName
            if ($apiPolicy)
            {
                Set-AzureRmApiManagementPolicy -Context $ApimContext -ApiId $apiId -PolicyFilePath $apiPolicy
            }

            $opsDir = $apiFolder.FullName + "\operations"
            $ops = Get-ChildItem $opsDir.FullName -Filter "*.xml"

            $allOps = Get-AzureRmApiManagementOperation -Context $ApimContext -ApiId $apiId
            foreach ($op in $allOps)  # iterate throught all ops to add policies for "ops with a policy"
            {
                $opName = $op.Name
                $opName = $opName -replace "\/","_" # A dirty fix to deal with operations containg "/"
                $opPath = $opsDir + "\" + $opName + ".xml"

                if (Test-Path $opPath)
                {
                    Set-AzureRmApiManagementPolicy -Context $ApimContext -ApiId $apiId -OperationId $op.OperationId -PolicyFilePath $opPath
                }
            }
        }
    }
}
