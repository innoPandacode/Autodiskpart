# 檢查 PowerShell 是否以系統管理員身份運行
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# 如果未以系統管理員身份運行，則使用管理員權限重新啟動 PowerShell 會話
if (-not $isAdmin) {
    Start-Process powershell.exe "-File $PSCommandPath" -Verb RunAs
    exit
}

Write-Host "Executing Diskpart..." -ForegroundColor Green

"list disk"| Out-File -Encoding ASCII -FilePath .\diskpart_script.txt
$output = Start-Process "diskpart.exe" -Wait -ArgumentList "/s", ".\diskpart_script.txt"

$disks = Start-Process "diskpart.exe" -Wait -ArgumentList "/s", ".\diskpart_script.txt" -NoNewWindow -PassThru | Out-String
$disksTable = $disks | Select-String "Disk [0-9]" | ForEach-Object {
    [PSCustomObject]@{
        Number = $_.Line.Substring($_.Line.IndexOf(" ")).Trim()
        Size = (($_ | Select-String -Pattern "\d+ bytes") -split " ")[0]
        Status = $_ | Select-String -Pattern "(Online|Offline)" | ForEach-Object {$_.Matches.Value}
        Manufacturer = $_ | Select-String -Pattern "Manufacturer" | ForEach-Object {$_.Line.Split(":")[1].Trim()}
    }
} | Format-Table
Write-Host $disksTable

$dnum = Read-Host "Please enter the number of the disk you want to clean "
Write-Host
Write-Host "Disk information for Disk ${dnum}:" -ForegroundColor Green
Write-Host
"select disk $dnum", "detail disk" | Out-File -Encoding ASCII -FilePath .\diskpart_script.txt
$diskDetails = Start-Process "diskpart.exe" -Wait -ArgumentList "/s", ".\diskpart_script.txt" -NoNewWindow -PassThru | Out-String
$diskDetailsTable = $diskDetails | Select-String -Pattern "Disk $dnum|Online|Size|Manufacturer" | ForEach-Object {
    [PSCustomObject]@{
        DiskInfo = $_.Line
    }
} | Format-Table


$confirmation = Read-Host "Are you sure you want to clean Disk $dnum? (Y/N)"

if ($confirmation.ToUpper() -eq "Y") {
    Write-Host "Selecting disk $dnum..." -ForegroundColor Green
    "select disk $dnum", "clean" | Out-File -Encoding ASCII -FilePath .\diskpart_script.txt
    Start-Process "diskpart.exe" -Wait -ArgumentList "/s", ".\diskpart_script.txt" > $null
    Write-Host "Disk has been cleaned." -ForegroundColor Green
    }
    $createPartition = Read-Host "Do you want to create a partition on Disk $dnum? (Y/N)"
if ($createPartition.ToUpper() -eq "Y") {
    Write-Host "Creating partition on Disk $dnum..." -ForegroundColor Green
    "select disk $dnum", "create partition primary", "format fs=ntfs quick" | Out-File -Encoding ASCII -FilePath .\diskpart_script.txt -Append
    $driveLetter = Read-Host "Enter the drive letter you want to assign to the new partition (e.g., E)"
    $driveLetter = $driveLetter.ToUpper() + ":"
    Add-Content -Path .\diskpart_script.txt -Value "assign letter=$driveLetter"
    Start-Process "diskpart.exe" -Wait -ArgumentList "/s", ".\diskpart_script.txt" > $null
    Write-Host "Partition has been created and formatted." -ForegroundColor Green
}

else {
    Write-Host "No partition has been created." -ForegroundColor Green
}

Write-Host "Deleting disk list file..." -ForegroundColor Green
Remove-Item -Path .\diskpart_script.txt -Force > $null
Write-Host "Temp file has been deleted." -ForegroundColor Green
