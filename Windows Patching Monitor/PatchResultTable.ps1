$FQDNList = Get-content .\FQDNList.txt

$C = 1
$PatchingTable = foreach ($FQDN in $FQDNList)
{
    $ServerObject = New-Object PSObject
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name SL -Value $C | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name FQDN -Value $FQDN | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Available_Patches -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Patching_Progress -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Reboot_Required -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Last_Boot_Time -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Last_WindowsUpdate -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Days_SinceReboot -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name C_FreeSpace_GB -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name RoW_Updated -Value $null | Out-Null
    Add-Member -InputObject $ServerObject -MemberType NoteProperty -Name Record_LastUpdated -Value (Get-Date) | Out-Null
    $C++ | Out-Null
    $ServerObject
}
#$PatchingTable | Select-Object -Property FQDN, Available_Patches, Patching_Progress, Reboot_Required, Last_Boot_Time, Last_WindowsUpdate, Days_SinceReboot, C_FreeSpace_GB, RoW_Updated | ft

Do{
    foreach ($Row in $PatchingTable)
    {
        try
        {
            $JobStatus = (Get-Job -Name $Row.FQDN -ErrorAction Stop).State
        }
        catch
        {
            $JobStatus = "Non-Existent"
        }

        if ($JobStatus -eq "Completed")
        {
            $PatchStatusObject = Receive-Job -Name $Row.FQDN

            $Row.Available_Patches = $PatchStatusObject.Available_Patches
            $Row.C_FreeSpace_GB = $PatchStatusObject.C_FreeSpace_GB
            $Row.Days_SinceReboot = $PatchStatusObject.Days_SinceReboot
            $Row.Last_Boot_Time = $PatchStatusObject.Last_Boot_Time
            $Row.Last_WindowsUpdate = $PatchStatusObject.Last_WindowsUpdate
            $Row.Patching_Progress = $PatchStatusObject.Patching_Progress
            $Row.Reboot_Required = $PatchStatusObject.Reboot_Required
            $Row.Record_LastUpdated = (Get-Date)
            $Row.RoW_Updated = "1 Sec Ago"

            Remove-Job -Name $Row.FQDN -Force | Out-Null            
            Start-Job -Name $Row.FQDN -FilePath .\Background-CCMPatchStatus.ps1 -ArgumentList $Row.FQDN | Out-Null
        }
        elseif($JobStatus -eq "Non-Existent")
        {
            $StartTime = Get-Date
            Start-Job -Name $Row.FQDN -FilePath .\Background-CCMPatchStatus.ps1 -ArgumentList $Row.FQDN | Out-Null
            $Row.Record_LastUpdated = (Get-Date)
        }
        else
        {
            $CurrentTime = Get-Date
            $PreviousUpdateTime = $Row.Record_LastUpdated
            [int]$Sec = ($CurrentTime - $PreviousUpdateTime).TotalSeconds
            $Row.Row_Updated = "$Sec Sec Ago"
        }
    }
    Clear-Host
    $PatchingTable | Sort-Object -Property SL | Select-Object -ExcludeProperty Record_LastUpdated | Format-Table -AutoSize
    Start-Sleep -Milliseconds 501
}
While(1 -gt 0)
