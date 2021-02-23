<# This Is Auto Test Script
#>

$DPRepoFile = "C:\Scripts\BackupGAPReport\DPBackupObjRepo.html"
$VMsWithBackupFile = "C:\Scripts\BackupGAPReport\VMsWithBackup.txt"
$VMsWithoutBackupFile = "C:\Scripts\BackupGAPReport\VMsWithoutBackup.txt"
$VCenterVMsFile = "C:\Scripts\BackupGAPReport\VCenterVMs.txt"
$DataProtectoreVMsFile = "C:\Scripts\BackupGAPReport\DataProtectoreVMs.txt"
$ExcludeVMsWithoutBackupFile = "C:\Scripts\BackupGAPReport\ExcludeVMsWithoutBackup.txt"
$ExcludeVMsWithoutBackup = Get-Content $ExcludeVMsWithoutBackupFile
$ExcludeVMCounter = 0

[string[]]$To = "Itamar <itamar@ge.com>", "Niss key <mniss@ge.com>"
[string[]]$Cc = "Sh do <iaul@ge.com>" 
$From = "MOE Backup Admin <BackupAdmin@some.domain>"
$SMTPSrv = "smtp.local"
$Subject = "Backup GAP Report."
$Body = $null

# Creating DP last 24 hours Object Report
omnirpt -html -report obj_copies -timeframe 24 24 -log $DPRepoFile

# Connecting To vCenter and Getting all VMs Names to VCArray.
Add-PSSnapin VMware.VimAutomation.Core
Connect-VIServer -Server vcenter-ip-or-name
$VMs = Get-VM
foreach ($VM in $VMs){
	$VCArray += @($VM.Name)
}

# Pulling from DP Object Report only the VMs are being backup to DPArray.
$File = Select-String $DPRepoFile -Pattern "VEAgent"
Foreach ($Row in $File){
$FixedRow = "'" + $Row + "'"
$SubRow = $FixedRow.Substring(0, $FixedRow.IndexOf('</'))
$FinalWord = $SubRow -split '/'
$Cnt = $FinalWord.count
$DPArray += @($FinalWord[$Cnt-1])
}

# Comparing between to Arrays VCArray and DPArray and finding the GAP VMs.
Foreach ($VCVM in $VCArray){
$VMExists = $False
	Foreach ($DPVM in $DPArray){
	    if ($VCVM -eq $DPVM){$VMExists = $True}
	}
    if ($VMExists){$VMsWithBackup += @($VCVM)}
    else
    {
    $VMInExcludeList = $False
    Foreach ($ExcludeVM in $ExcludeVMsWithoutBackup){
        if ($VCVM -eq $ExcludeVM){$VMInExcludeList = $True}
        }
    if ($VMInExcludeList){$ExcludeVMCounter = $ExcludeVMCounter + 1}
    else {$VMsWithoutBackup += @($VCVM)}
    }
}

$VMsWithBackup > $VMsWithBackupFile
Date >> $VMsWithBackupFile
$VMsWithoutBackup > $VMsWithoutBackupFile
Date >> $VMsWithoutBackupFile
$VCArray > $VCenterVMsFile
Date >> $VCenterVMsFile
$DPArray > $DataProtectoreVMsFile
Date >> $DataProtectoreVMsFile

$Body = "Hello All, `n`n"
$Body = $Body + "VMs in vCenter:`t" + $VCArray.Count + "`n"
$Body = $Body + "VMs in DataProtector:`t" + $DPArray.Count + "`n"
$Body = $Body + "VMs With Backup:`t" + $VMsWithBackup.Count + "`n"
$Body = $Body + "VMs Without Backup:`t" + $VMsWithoutBackup.Count + "`n"
$Body = $Body + "Excluded VMs No Backup Needed:`t" + $ExcludeVMCounter + "`n`n"
$Body = $Body + "Thanks,`nMOE Backup Admin"

Send-Mailmessage -to $To -cc $Cc -from $From -subject $Subject -SMTPserver $SMTPSrv -Attachments $VMsWithBackupFile,$VMsWithoutBackupFile,$VCenterVMsFile,$DataProtectoreVMsFile,$ExcludeVMsWithoutBackupFile -Body $Body 
