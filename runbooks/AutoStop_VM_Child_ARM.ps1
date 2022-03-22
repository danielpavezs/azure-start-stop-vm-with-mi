<#
.SYNOPSIS  
 Script to stop the Azure ARM VM via AutoStop based scenario on CPU % utilization 
.DESCRIPTION  
 Script to stop the Azure ARM VM via AutoStop based scenario on CPU % utilization 
.EXAMPLE  
.\AutoStop_VM_Child_ARM.ps1 
Version History  
v1.0 - Initial Release  
#>

param
(
    [Parameter (Mandatory = $false)]
    [object] $WebHookData
)

# If runbook was called from Webhook, WebhookData will not be null.
if ($WebHookData) {

    if(-Not $WebHookData.RequestBody )
    {
        Write-Output 'No request body from test pane'
        
        $WebhookData = (ConvertFrom-JSON -InputObject $WebhookData)
        
        $rbody = (ConvertFrom-JSON -InputObject $WebhookData.RequestBody)      
    
        $context = [object]$rbody.data.context
        Write-Output "Alert Name = $($context.name)"
        Write-Output "RG Name = $($context.resourceGroupName)"
        Write-Output "VM Name = $($context.resourceName)"

        exit
    }

    # Retrieve VMs from Webhook request body
    #$WebhookData = (ConvertFrom-JSON -InputObject $WebhookData -ErrorAction SilentlyContinue)
    
    $rbody = (ConvertFrom-JSON -InputObject $WebhookData.RequestBody)      

    $context = [object]$rbody.data.context

    Write-Output "`nALERT CONTEXT DATA"
    Write-Output "==================="
    Write-Output "Subscription Id : $($context.subscriptionId)"
    Write-Output "VM alert name : $($context.name)"    
    Write-Output "VM ResourceGroup Name : $($context.resourceGroupName)"
    Write-Output "VM name : $($context.resourceName)"
    Write-Output "VM type : $($context.resourceType)"
    Write-Output "Resource Id : $($context.resourceId)"
    Write-Output "Timestamp : $($context.timestamp)"

    #----------------------------------------------------------------------------------
    #---------------------LOGIN TO AZURE AND SELECT THE SUBSCRIPTION-------------------
    #----------------------------------------------------------------------------------
    try
    {
        Disable-AzContextAutosave -Scope Process
        $AzureContext = (Connect-AzAccount -Identity).context
        $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
        Write-Output "Successfully logged into Azure subscription using System assigned Managed Identity"
        if($context.resourceType -eq "Microsoft.Compute/virtualMachines")
        {
            Write-Output "~$($context.resourceName)"
            Write-Output "Stopping VM $($context.resourceName) using Az cmdlets"
            $Status = Stop-AzVM -Name $context.resourceName -ResourceGroupName $context.resourceGroupName -Force
            if($Status -eq $null)
            {
                Write-Output "Error occured while stopping the Virtual Machine. $context.resourceName"
            }
            else
            {
                Write-Output "Successfully stopped the VM $context.resourceName"
            }
        }
    }
    catch 
    {
        Write-Output "Error trying to login with System assigned Managed Identity"
    }
}
else {
    # Error
    write-Error "This runbook is meant to be started from an Azure alert webhook only."
}