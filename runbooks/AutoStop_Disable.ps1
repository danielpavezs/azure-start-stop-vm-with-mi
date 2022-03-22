<#
.SYNOPSIS  
 Disable AutoSnooze feature
.DESCRIPTION  
 Disable AutoSnooze feature
.EXAMPLE  
.\AutoStop_Disable.ps1 
Version History  
v1.0   - Initial Release  
#>

# ------------------Execution Entry point ---------------------

#-----L O G I N - A U T H E N T I C A T I O N-----
try
{
    Disable-AzContextAutosave -Scope Process
    $AzureContext = (Connect-AzAccount -Identity).context
    $AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
    Write-Output "Successfully logged into Azure subscription using System assigned Managed Identity"
}
catch 
{
    Write-Output "Error trying to login with System assigned Managed Identity"
}

try
{
    Write-Output "Performing the AutoSnooze Disable..."

    Write-Output "Collecting all the schedule names for AutoSnooze..."

    #---------Read all the input variables---------------
    $SubId = Get-AutomationVariable -Name 'Internal_AzureSubscriptionId'
    $StartResourceGroupNames = Get-AutomationVariable -Name 'External_Start_ResourceGroupNames'
    $StopResourceGroupNames = Get-AutomationVariable -Name 'External_Stop_ResourceGroupNames'
    $automationAccountName = Get-AutomationVariable -Name 'Internal_AutomationAccountName'
    $aroResourceGroupName = Get-AutomationVariable -Name 'Internal_ResourceGroupName'

    #Flag for CSP subs
    $enableClassicVMs = Get-AutomationVariable -Name 'External_EnableClassicVMs'        

    $webhookUri = Get-AutomationVariable -Name 'Internal_AutoSnooze_WebhookUri'
    $scheduleNameforCreateAlert = "Schedule_AutoStop_CreateAlert_Parent"

    Write-Output "Disabling the schedules for AutoSnooze..."

    #Disable the schedule for AutoSnooze
    Set-AzAutomationSchedule -AutomationAccountName $automationAccountName -Name $scheduleNameforCreateAlert -ResourceGroupName $aroResourceGroupName -IsEnabled $false -ErrorAction SilentlyContinue

    Write-Output "Disabling the alerts on all the VM's configured as per asset variable..."

    [string[]] $VMRGList = $StopResourceGroupNames -split ","
    
    $AzureVMListTemp = $null
    $AzureVMList=@()
    ##Getting VM Details based on RG List or Subscription
    if (($VMRGList -ne $null) -and ($VMRGList -ne "*"))
    {
        foreach($Resource in $VMRGList)
        {
            Write-Output "Validating the resource group name ($($Resource.Trim()))" 
            $checkRGname = Get-AzResourceGroup  $Resource.Trim() -ev notPresent -ea 0  
            if ($checkRGname -eq $null)
            {
                Write-Warning "$($Resource) is not a valid Resource Group Name. Please verify your input."
				Write-Output "$($Resource) is not a valid Resource Group Name. Please verify your input."
            }
            else
            {                   
				#Flag check for CSP subs
                if($enableClassicVMs)
                {
                    # Get classic VM resources in group and record target state for each in table
				    $taggedClassicVMs = Get-AzResource -ResourceGroupName $Resource -ResourceType "Microsoft.ClassicCompute/virtualMachines"
				    foreach($vmResource in $taggedClassicVMs)
				    {
					    Write-Output "VM classic location $vmResource.Location"
					    if ($vmResource.ResourceGroupName -Like $Resource)
					    {
						    $AzureVMList += @{Name = $vmResource.Name; Location = $vmResource.Location; ResourceGroupName = $vmResource.ResourceGroupName; Type = "Classic"}
					    }
				    }
				}

				# Get resource manager VM resources in group and record target state for each in table
				$taggedRMVMs = Get-AzResource -ResourceGroupName $Resource -ResourceType "Microsoft.Compute/virtualMachines"
				foreach($vmResource in $taggedRMVMs)
				{
					if ($vmResource.ResourceGroupName -Like $Resource)
					{
						$AzureVMList += @{Name = $vmResource.Name; Location = $vmResource.Location; ResourceGroupName = $vmResource.ResourceGroupName; Type = "ResourceManager"}
					}
				}
            }
        }
    } 
    else
    {
        Write-Output "Getting all the VM's from the subscription..."  
       $ResourceGroups = Get-AzResourceGroup 
		foreach ($ResourceGroup in $ResourceGroups)
		{    
			#Flag check for CSP subs
            if($enableClassicVMs)
            {
                # Get classic VM resources in group 
			    $taggedClassicVMs = Get-AzResource -ResourceGroupName $ResourceGroup.ResourceGroupName -ResourceType "Microsoft.ClassicCompute/virtualMachines"
			    foreach($vmResource in $taggedClassicVMs)
			    {
				    Write-Output "RG : $vmResource.ResourceGroupName , Classic VM $($vmResource.Name)"
				    $AzureVMList += @{Name = $vmResource.Name; Location = $vmResource.Location; ResourceGroupName = $vmResource.ResourceGroupName; Type = "Classic"}
			    }
            }
			
			# Get resource manager VM resources in group and record target state for each in table
			$taggedRMVMs = Get-AzResource -ResourceGroupName $ResourceGroup.ResourceGroupName -ResourceType "Microsoft.Compute/virtualMachines"
			foreach($vmResource in $taggedRMVMs)
			{
				Write-Output "RG : $vmResource.ResourceGroupName , ARM VM $($vmResource.Name)"
				$AzureVMList += @{Name = $vmResource.Name; Location = $vmResource.Location; ResourceGroupName = $vmResource.ResourceGroupName; Type = "ResourceManager"}
			}
		}
    }

    Write-Output "Calling child runbook to disable the alert on all the VM's..."    

    foreach($VM in $AzureVMList)
    {
        try
        {
            $params = @{"VMObject"=$VM;"AlertAction"="Disable";"WebhookUri"=$webhookUri}                    
            $runbook = Start-AzAutomationRunbook -AutomationAccountName $automationAccountName -Name 'AutoStop_CreateAlert_Child' -ResourceGroupName $aroResourceGroupName –Parameters $params
        }
        catch
        {
            Write-Output "Error Occurred on Alert disable..."   
            Write-Output $_.Exception 
        }
    }

    Write-Output "AutoSnooze disable execution completed..."

}
catch
{
    Write-Output "Error Occurred on AutoSnooze Disable Wrapper..."   
    Write-Output $_.Exception
}