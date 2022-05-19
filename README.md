# CrowdStrike Migration

## Introduction
This repository contains all of the files necessary for uninstalling and reinstalling the CrowdStrike Falcon agent on a Windows host, with the purpose of moving a host between portals, or just assigning a new CID value.



## Usage
1. Download the script in to a directory of your choosing.
2. Copy the new CID value into a file called `cid.txt` within the same directory.
3. Run: `.\migration.ps1`.

The executables contained within this repo will be downloaded automatically when the script runs.
