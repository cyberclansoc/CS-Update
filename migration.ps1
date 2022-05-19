################################
# UNINSTALL PART
################################

$InstalledApplications=$(Get-WmiObject -Class Win32_Product | Select-String -Pattern "crowdstrike")

if ( $InstalledApplications.Length -gt 0 ) {
   
    Write-Output "Uninstalling CrowdStrike."

    $UninstallTool = ".\CsUninstallTool.exe"
    Write-Output $UninstallTool

    if ( -Not(Test-Path -Path $UninstallTool) ) {
       
        Write-Output "Downloading CsUninstallTool.exe"

        Invoke-WebRequest -Uri "https://github.com/cyberclansoc/CS-Update/raw/main/CsUninstallTool.exe" -OutFile $UninstallTool -UseBasicParsing
    }


    & .\CsUninstallTool.exe /quiet

    # Let's wait a little....
    Write-Output "Waiting for a few seconds before continuing..."
    Start-Sleep -Seconds 10

}




################################
# INSTALL PART
################################

$InstallerHash = "F2D0AB25DE019B14601830F3FA5D4F1EB8B1F898280424B79F125691BD4D93DB"
$InstallerPath = ".\WindowsSensor.exe"
$CIDFile = ".\cid.txt"


if ( -Not(Test-Path -Path $InstallerPath) -or -Not((Get-FileHash .\WindowsSensor.exe).Hash -eq $InstallerHash) ) {
   
    Write-Output "Downloading CrowdStrike Installer"

    Invoke-WebRequest -Uri "https://github.com/cyberclansoc/CS-Update/raw/main/WindowsSensor.exe" -OutFile $InstallerPath -UseBasicParsing

    if ( -Not((Get-FileHash .\WindowsSensor.exe).Hash -eq $InstallerHash) ) {
       
        throw "Downloaded installer doesn't match expected SHA256 checksum."
    }
}

& $InstallerPath /passive CID=$(Get-Content -Path $CIDFile) VDI=1
