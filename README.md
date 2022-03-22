# Azure Start/Stop VM using System Assigned Managed Identity

The solution provided by Microsoft to automate the start and stop of Virtual Machines located in Azure ([Official Documentation](https://docs.microsoft.com/en-us/azure/automation/automation-solution-vm-management)) currently works with Service Principal. With a slight change, this automation can work with a System Assigned Managed Identity authentication. Here is the code to achieve that.

## Files contained in this repo:

1. `AutoStop_CreateAlert_Child`
2. `AutoStop_CreateAlert_Parent`
3. `AutoStop_Disable`
4. `AutoStop_VM_Child`
5. `AutoStop_VM_Child_ARM`
6. `ScheduledStartStop_Base_Classic`
7. `ScheduledStartStop_Child`
8. `ScheduledStartStop_Child_Classic`
9. `ScheduledStartStop_Parent`
10. `ScheduledStartStop_Parent`