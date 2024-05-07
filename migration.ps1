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

}


################################
# INSTALL PART
################################

$InstallerHash = "1C79E9C0B5D7CEBB189E3353698540556BBACFF7AF5BAD5139280D126A30DD03"
$InstallerPath = ".\WindowsSensor.exe"
$CIDFile = ".\cid.txt"


if ( -Not(Test-Path -Path $InstallerPath) -or -Not((Get-FileHash .\WindowsSensor.exe).Hash -eq $InstallerHash) ) {
   
    Write-Output "Downloading CrowdStrike Installer"

    DownloadWithRetry -Url "https://github.com/cyberclansoc/CS-Update/raw/main/WindowsSensor-update.exe" -OutFile $InstallerPath -Retries 3

    if ( -Not((Get-FileHash .\WindowsSensor.exe).Hash -eq $InstallerHash) ) {
       
        throw "Downloaded installer doesn't match expected SHA256 checksum."
    }
}

& $InstallerPath /passive CID=$(Get-Content -Path $CIDFile) VDI=1
