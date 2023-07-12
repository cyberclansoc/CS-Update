###############################
# EU Version of the migration
# script; installers have
# different hashes
###############################

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

$InstallerHash = "05679b1f68cd43b711a24c1184794a0b490494d308ee055e970a12859c670ee1"
$InstallerPath = ".\WindowsSensor_EU.exe"
$CIDFile = ".\cid.txt"


if ( -Not(Test-Path -Path $InstallerPath) -or -Not((Get-FileHash .\WindowsSensor_EU.exe).Hash -eq $InstallerHash) ) {
   
    Write-Output "Downloading CrowdStrike Installer"

    DownloadWithRetry -Url "https://github.com/cyberclansoc/CS-Update/raw/main/WindowsSensor_EU.exe" -OutFile $InstallerPath -Retries 3

    if ( -Not((Get-FileHash .\WindowsSensor_EU.exe).Hash -eq $InstallerHash) ) {
       
        throw "Downloaded installer doesn't match expected SHA256 checksum."
    }
}

& $InstallerPath /passive CID=$(Get-Content -Path $CIDFile) VDI=1
