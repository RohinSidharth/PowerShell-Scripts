Param
(
    # Param1 help description
    [Parameter(Mandatory=$true,
                ValueFromPipelineByPropertyName=$true,
                Position=0)]
    $FQDN
)
$Alive = Test-Connection -ComputerName $FQDN -Count 2 -ErrorAction Stop

$PatchStatusObject = New-Object -TypeName PSObject
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name FQDN -Value $FQDN | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name Available_Patches -Value $null | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name Patching_Progress -Value $null | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name Reboot_Required -Value $null | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name Last_Boot_Time -Value $null | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name Last_WindowsUpdate -Value $null | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name Days_SinceReboot -Value $null | Out-Null
Add-Member -InputObject $PatchStatusObject -MemberType NoteProperty -Name C_FreeSpace_GB -Value $null | Out-Null


if ($Alive)
{
    try
    {
        $ErrorActionPreference = "Stop"

        #Collect Patch Information
        try{
            $CCM_All = @(Get-WmiObject -ComputerName $FQDN -Namespace "ROOT\ccm\ClientSDK" -Class CCM_SoftwareUpdate -Property "*")
            $EvalStatus = $CCM_All.EvaluationState
            $CCMUpdateStatus = $CCM_All | Where-Object -Property ComplianceState -eq 0

            #Progress
            if($EvalStatus)
            {
                #Initialize
                $A = $B = $C = $D = $E = $F = 0
                        
                foreach ($Code in $EvalStatus)
                {
                    Switch -Regex ($Code)
                    {
                        {0..3 -contains $_} {$A++}
                        {4..7 -contains $_} {$C++}
                        {8..12 -contains $_} {$D++}
                        {13  -contains $_} {$E++}
                        {14..23 -contains $Code} {$F++}
                    }
                }
                $Progress = "U=$A, I=$C, C=$D, F=$E, W=$F"
            }
            else
            {
                $Progress = "----"
            }

            if($CCMUpdateStatus.Count)
            {
                $Count = $CCMUpdateStatus.Count
                #$PatchStatus = "$FQDN`t$Count`t$Progress`t$Reboot_Required`t$LastBootTime`t$LastWU"
            }
            Else
            {
                $Count = "ZERO"
                #$PatchStatus = "$FQDN`t$Count`t$Progress`t$Reboot_Required`t$LastBootTime`t$LastWU"
            }
        }
        catch
        {
            $EvalStatus = "SCCM-ClientQueryFailed"
            $Count = "SCCM-ClientError"
            $Progress = "Unavailable"
            $CCMUpdateStatus = "QueryFailed"
        }
    
        try{    
            $LastBootTime = (Get-WmiObject -ComputerName $FQDN -Class Win32_OperatingSystem | Select-Object __SERVER,@{label='LastBootUpTime';expression={$_.ConvertToDateTime($_.LastBootupTime)}}).LastBootUpTime

            $Today = Get-Date
            $BootDate = Get-Date($LastBootTime)

            $Diff = $Today - $BootDate
            $DaysSinceLastReboot ="{0:N1}" -f $Diff.TotalDays

        }
        catch{
            $LastBootTime = "BootTimeUnavailable"
            $DaysSinceLastReboot = "InsufficientData"
        }
    
        try{
            $LastWU = (Get-HotFix -ComputerName $FQDN | Sort-Object InstalledOn -Descending | Select-Object -First 1).InstalledOn
        }
        catch{$LastWU = "LastUpdate_Unavailable"}
    

        #REBOOT REQUIRED STATUS
        try{
            $CCMClientUtil = Get-WmiObject -ComputerName $FQDN -Namespace 'ROOT\ccm\ClientSDK' -Class CCM_ClientUtilities -list
            $Reboot_Required = $CCMClientUtil.DetermineIfRebootPending().RebootPending
        }
        catch{$Reboot_Required = "Unavailable"}

        #DiskSpace
        Try
        {
            $C = (Get-WmiObject win32_logicaldisk -Computername $FQDN -ErrorAction Stop | where-object {$_.DeviceID -eq “C:”})
            $Size = "{0:N2}" -f ($C.Size/1gb)
            $FreeSpace = "{0:N2}" -f ($C.FreeSpace/1gb)
        }
        catch
        {
            $FreeSpace = "----"
        }

        #$PatchStatus = "$FQDN`t$Count`t$Progress`t$Reboot_Required`t$LastBootTime`t$LastWU`t$FreeSpace"
        $PatchStatusObject.FQDN = $FQDN
        $PatchStatusObject.Available_Patches = $Count
        $PatchStatusObject.C_FreeSpace_GB = $FreeSpace
        $PatchStatusObject.Days_SinceReboot = $DaysSinceLastReboot
        $PatchStatusObject.Last_Boot_Time = $LastBootTime
        $PatchStatusObject.Last_WindowsUpdate = $LastWU
        $PatchStatusObject.Patching_Progress = $Progress
        $PatchStatusObject.Reboot_Required = $Reboot_Required

    }
    catch
    {
        $Errormsg = $_.ErrorDetails.Message
        #$PatchStatus = "$FQDN`tACCESS_DENIED`t$Errormsg"
        $PatchStatusObject.FQDN = $FQDN
        $PatchStatusObject.Available_Patches = $Errormsg
    }
}
else
{
    #$PatchStatus = "$FQDN`tUNREACHABLE"
    $PatchStatusObject.FQDN = $FQDN
    $PatchStatusObject.Available_Patches = "UNREACHABLE"
}
$ErrorActionPreference = "Continue"
Return $PatchStatusObject
