#Add to Line 41 the ServerName and ShareName
function DownloadWithRetry([string] $Url, [string] $OutFile, [int] $Retries) {
    while($true) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            break
        }
        catch {
            Write-Output "Failed to downlod '$Url'."
            if ( --$Retries -gt 0 ) {
                Write-Output "Retries remaining: '$Retries'.\nWaiting a couple of seconds before retrying."
                Start-Sleep -Seconds 3
            } else {
                throw $_.Exception
            }
        }
    }
}
################################
# UNINSTALL PART
################################
$InstalledApplications=$(Get-WmiObject -Class Win32_Product | Select-String -Pattern "crowdstrike")
if ( $InstalledApplications.Length -gt 0 ) {
    Write-Output "Uninstalling CrowdStrike."
    $UninstallHash = "E127F23DDA6F2C3F48E9D2AD55A9D245B3FE6E6E607ED2572A4DD2BE819A8235"
    $UninstallTool = ".\CsUninstallTool.exe"
    if ( -Not(Test-Path -Path $UninstallTool) -or -Not((Get-FileHash $UninstallTool).Hash -eq $InstallerHash) ) {
        Write-Output "Downloading CsUninstallTool.exe"
        DownloadWithRetry -Url "https://github.com/cyberclansoc/CS-Update/raw/main/CsUninstallTool.exe" -OutFile $UninstallTool -Retries 3
    }
    & .\CsUninstallTool.exe /quiet
    # Let's wait a little....
    Write-Output "Waiting for a few seconds before continuing..."
    Start-Sleep -Seconds 10
    $CSRUNNING = Get-Service -Name "csagent"
    if ( $CSRUNNING -eq $null ){
        Write-Output "CS uninstalled successfully"
    } else {
        Write-Output "Error uninstalling, please uninstall manually, exiting script"
        #write a log file in a file share if uninstallation failed, we may need CS to clean up registry
        $deviceName = $env:COMPUTERNAME
        #$filePath = "\\ServerName\ShareName\Logs\CSIULogs.txt"
        $filePath = "C:\temp\Logs\CSIULogs.txt"
        if (Test-Path $filePath){
            Add-Content -Path $filePath -Value "Device Name: "+ $deviceName
        } else{
            New-Item $filePath -ItemType File -Value $deviceName
        }
        exit 0
    }
}
################################
# INSTALL PART
################################
$InstallerHash = "816D14BDFEB8CFE51232D885017C03DF01056D84E4C56E3A61AE1900B35DF735"
$InstallerPath = ".\WindowsSensor.exe"
$CIDFile = "79E4156939264F97BBFF5A6AB54E5A18-ED"


if ( -Not(Test-Path -Path $InstallerPath) -or -Not((Get-FileHash .\WindowsSensor.exe).Hash -eq $InstallerHash) ) {
   
    Write-Output "Downloading CrowdStrike Installer"

    DownloadWithRetry -Url "https://github.com/cyberclansoc/CS-Update/raw/main/WindowsSensor.exe" -OutFile $InstallerPath -Retries 3

    if ( -Not((Get-FileHash .\WindowsSensor.exe).Hash -eq $InstallerHash) ) {
       
        throw "Downloaded installer doesn't match expected SHA256 checksum."
    }
}

& $InstallerPath /passive CID=$CIDFile VDI=1

