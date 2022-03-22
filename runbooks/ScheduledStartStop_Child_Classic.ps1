<#
.SYNOPSIS  
 Wrapper script for start & stop Classic VM's
.DESCRIPTION  
 Wrapper script for start & stop Classic VM's
.EXAMPLE  
.\ScheduledStartStop_Child_Classic.ps1 -VMName "Value1" -Action "Value2" -ResourceGroupName "Value3" 
Version History  
v1.0   - Initial Release  
#>
param(
[string]$VMName = $(throw "Value for VMName is missing"),
[String]$Action = $(throw "Value for Action is missing"),
[String]$ResourceGroupName = $(throw "Value for ResourceGroupName is missing")
)

#----------------------------------------------------------------------------------
#---------------------LOGIN TO AZURE AND SELECT THE SUBSCRIPTION-------------------
#----------------------------------------------------------------------------------
try
{
    Disable-AzContextAutosave -Scope Process
    $AzureContext = (Connect-AzAccount -Identity).context
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
    Write-Output "Successfully logged into Azure subscription using System assigned Managed Identity"
    Write-Output "Generating access token..."
    $context = Get-AzContext
    $SubscriptionId = $context.Subscription
    $cache = $context.TokenCache
    $cacheItem = $cache.ReadItems()
    $AccessToken=$cacheItem[$cacheItem.Count -1].AccessToken
    $headerParams = @{'Authorization'="Bearer $AccessToken"}
    Write-Output "VM action is : $($Action)"
    $ClassicVM = Search-AzGraph -Query "Resources | where type =~ 'Microsoft.ClassicCompute/virtualMachines' | where name == '$($VMName)'"
    $ResourceGroupName = $ClassicVM.resourceGroup
    if ($Action.Trim().ToLower() -eq "stop")
    {
        $uriclassicDeallocate = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ClassicCompute/virtualMachines/$VMName/shutdown?api-version=2015-10-01"
        Write-Output "API url : $($uriclassicDeallocate)"
        Write-Output "Stopping the VM : $($VMName) using API..."            
        $results=Invoke-RestMethod -Uri $uriclassicDeallocate -Headers $headerParams -Method POST
        Write-Output "Successfully stopped the VM $($VMName)"
    }
    elseif($Action.Trim().ToLower() -eq "start")
    {
        $uriclassicStart = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroupName/providers/Microsoft.ClassicCompute/virtualMachines/$VMName/start?api-version=2017-04-01"
        Write-Output "API url : $($uriclassicStart)"            
        Write-Output "Starting the VM : $($VMName) using API..."
        $results=Invoke-RestMethod -Uri $uriclassicStart -Headers $headerParams -Method POST
        Write-Output "Successfully started the VM $($VMName)"
    }
}
catch 
{
    Write-Output "Error trying to login with System assigned Managed Identity"
}