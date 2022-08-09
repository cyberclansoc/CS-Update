[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string] $DataFilePath = $(
        Join-Path -Path $(
            Get-Location -PsProvider FileSystem
        ) -ChildPath InstallerRegistration.psd1
    )
)

################################################################################

$LogDir = Split-Path -Path $DataFilePath -Parent
$LogPath = $(
    Join-Path -Path $LogDir -ChildPath $(
        [io.path]::ChangeExtension(
            $(Split-Path -Path $DataFilePath -Leaf),
            '.error.log'
        )
    )
)

$Pattern = 'CrowdStrike'

################################################################################

function Export-InstallerRegistration
{
    [CmdletBinding()]
    param ()

    if (-not (Test-Path -Path $LogDir))
    {
        $null = New-Item -ItemType Directory -Path $LogDir
    }

    Get-FormattedRegistration -Pattern $Pattern 2> $LogPath |
    Tee-Object -FilePath $DataFilePath
}

################################################################################

function Get-FormattedRegistration
{
    [CmdletBinding()] param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )

    $Registration = New-Object -TypeName System.Management.Automation.PSObject -Property (
        Get-Registration -Pattern $Pattern | Group-Object -Property ProductName -AsHashTable
    )

    foreach ($ProductName in @($Registration | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
    {
        $Registration.$ProductName = New-Object -TypeName System.Management.Automation.PSObject -Property (
            $Registration.$ProductName | Group-Object -Property EntryType -AsHashTable
        )

        foreach ($EntryType in @($Registration.$ProductName | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name))
        {
            $Registration.$ProductName.$EntryType = $($Registration.$ProductName.$EntryType)
        }
    }

    ConvertTo-PowerShellDataString -InputObject $Registration
}

################################################################################

function Get-Registration
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )

    Get-InstallProperty -Pattern $Pattern
    Get-InstallerProduct -Pattern $Pattern
    Get-MsiArpEntry -Pattern $Pattern
    Get-BundleArpEntry -Pattern $Pattern
}

function ConvertTo-PowerShellDataString
{
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline = $True)]
        $InputObject
    )

    begin
    {
        $Indent = '  '
    }

    process
    {
        if ($Null -eq $InputObject)
        {
            "''"
        }
        elseif ($InputObject -is [int16] -or
                $InputObject -is [int32] -or
                $InputObject -is [int64] -or
                $InputObject -is [double] -or
                $InputObject -is [decimal] -or
                $InputObject -is [byte])
        {
            "${InputObject}"
        }
        elseif ($InputObject -is [string])
        {
            "'{0}'" -f $InputObject.ToString().Replace("'", "''")
        }
        elseif ($InputObject -is [System.Collections.IDictionary])
        {
            "@{{`n${Indent}{0}`n}}" -f $($(
                foreach ($Key in $InputObject.Keys)
                {
                    $FormatString = $(
                        if ("${Key}" -match '^(\w+|-?\d+\.?\d*)$')
                        {
                            '{0} = {1}'
                        }
                        else
                        {
                            "'{0}' = {1}"
                        }
                    )
                    $FormatString -f $Key, (ConvertTo-PowerShellDataString -InputObject $InputObject.$Key)
                }
            ) -split "`n" -join "`n${Indent}")
        }
        elseif ($InputObject -is [System.Collections.IEnumerable])
        {
            '@({0})' -f ($(
                foreach ($Item in $InputObject)
                {
                    ConvertTo-PowerShellDataString -InputObject $Item
                }
            ) -join ',')
        }
        elseif ($InputObject -is [System.Management.Automation.PSCustomObject])
        {
            "@{{`n${Indent}{0}`n}}" -f ($(
                foreach ($Key in $InputObject | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name)
                {
                    $FormatString = $(
                        if ("${Key}" -match '^(\w+|-?\d+\.?\d*)$')
                        {
                            '{0} = {1}'
                        }
                        else
                        {
                            "'{0}' = {1}"
                        }
                    )
                    $FormatString -f $Key, (ConvertTo-PowerShellDataString -InputObject $InputObject.$Key)
                }
            ) -split "`n" -join "`n${Indent}")
        }
        else
        {
            "'{0}'" -f $InputObject.ToString().Replace("'", "''")
        }
    }
}

################################################################################

function Get-InstallProperty
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )

    $InstallProperty = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Installer\UserData\S-1-5-18\Products\*\InstallProperties'

    $InstallProperty = @(Get-ItemProperty -Path $InstallProperty -ErrorAction SilentlyContinue)

    foreach ($Entry in $InstallProperty)
    {
        if ($Entry.DisplayName -match $Pattern)
        {
            $SquishedProductCode = Split-Path -Path $Entry.PsParentPath -Leaf
            $ProductCode = ConvertFrom-SquishedGuid -Value $SquishedProductCode

            $Result = New-Object -TypeName System.Management.Automation.PSObject
            $Result = Add-Member -Name ProductName -Value $Entry.DisplayName -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductCode -Value $ProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name SquishedProductCode -Value $SquishedProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name EntryType -Value InstallPropertyEntry -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name InstallSource -Value $Entry.InstallSource -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name LocalPackage -Value $Entry.LocalPackage -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductVersion -Value $Entry.DisplayVersion -InputObject $Result -MemberType NoteProperty -PassThru

            Write-Output -InputObject $Result
        }
    }
}

function Get-InstallerProduct
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )

    $InstallerProduct = 'HKLM:\SOFTWARE\Classes\Installer\Products\*'

    $InstallerProduct = @(Get-ItemProperty -Path $InstallerProduct -ErrorAction SilentlyContinue)

    foreach ($Entry in $InstallerProduct)
    {
        if ($Entry.ProductName -match $Pattern)
        {
            $SquishedPackageCode = $Entry.PackageCode
            $PackageCode = ConvertFrom-SquishedGuid -Value $SquishedPackageCode
            $SquishedProductCode = $Entry.PsChildName
            $ProductCode = ConvertFrom-SquishedGuid -Value $SquishedProductCode

            $SourceList = Join-Path -Path $Entry.PsPath -ChildPath SourceList
            $PackageName = $(
                if (Test-Path -Path $SourceList)
                {
                    $SourceListProperty = Get-ItemProperty -Path $SourceList
                    $SourceListProperty.PackageName
                }
                else
                {
                    $Null
                }
            )

            $Result = New-Object -TypeName System.Management.Automation.PSObject
            $Result = Add-Member -Name ProductName -Value $Entry.ProductName -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductCode -Value $ProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name SquishedProductCode -Value $SquishedProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name EntryType -Value InstallerProductEntry -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name PackageName -Value $PackageName -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name PackageCode -Value $PackageCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name SquishedPackageCode -Value $SquishedPackageCode -InputObject $Result -MemberType NoteProperty -PassThru

            Write-Output -InputObject $Result
        }
    }
}

function Get-MsiArpEntry
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )

    $MsiArpEntry = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'

    $MsiArpEntry = @(Get-ItemProperty -Path $MsiArpEntry -ErrorAction SilentlyContinue)

    foreach ($Entry in $MsiArpEntry)
    {
        if (($Entry.DisplayName -match $Pattern) -and (-not $Entry.BundleCachePath))
        {
            $ProductCode = $Entry.PsChildName
            $SquishedProductCode = ConvertTo-SquishedGuid -Guid $ProductCode

            $Result = New-Object -TypeName System.Management.Automation.PSObject
            $Result = Add-Member -Name ProductName -Value $Entry.DisplayName -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductCode -Value $ProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name SquishedProductCode -Value $SquishedProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name EntryType -Value MsiArpEntry -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name InstallSource -Value $Entry.InstallSource -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductVersion -Value $Entry.DisplayVersion -InputObject $Result -MemberType NoteProperty -PassThru

            Write-Output -InputObject $Result
        }
    }
}

function Get-BundleArpEntry
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [string] $Pattern
    )

    $BundleArpEntry = $(
        if (Test-Path -Path HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall)
        {
            'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*'
        }
        else
        {
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*'
        }
    )

    $BundleArpEntry = @(Get-ItemProperty -Path $BundleArpEntry -ErrorAction SilentlyContinue)

    foreach ($Entry in $BundleArpEntry)
    {
        if (($Entry.DisplayName -match $Pattern) -and $Entry.BundleCachePath)
        {
            $ProductCode = $Entry.PsChildName
            $SquishedProductCode = ConvertTo-SquishedGuid -Guid $ProductCode
            $InstallSource = Split-Path -Path $Entry.BundleCachePath -Parent
            $PackageName = Split-Path -Path $Entry.BundleCachePath -Leaf

            $Result = New-Object -TypeName System.Management.Automation.PSObject
            $Result = Add-Member -Name ProductName -Value $Entry.DisplayName -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductCode -Value $ProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name SquishedProductCode -Value $SquishedProductCode -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name EntryType -Value BundleArpEntry -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name InstallSource -Value $InstallSource -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name PackageName -Value $PackageName -InputObject $Result -MemberType NoteProperty -PassThru
            $Result = Add-Member -Name ProductVersion -Value $Entry.DisplayVersion -InputObject $Result -MemberType NoteProperty -PassThru

            Write-Output -InputObject $Result
        }
    }
}

################################################################################

function ConvertTo-SquishedGuid
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [guid] $Guid
    )

    return Convert-SquishedGuid -Value $Guid.ToString('N')
}

function ConvertFrom-SquishedGuid
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    return ([guid](Convert-SquishedGuid -Value $Value)).ToString('B').ToUpper()
}

################################################################################

function Convert-SquishedGuid
{
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string] $Value
    )

    $CharArray = $Value.ToUpper().ToCharArray()

    return [string]::Join('', @($CharArray[7..0] +
                                $CharArray[11..8] +
                                $CharArray[15..12] +
                                $CharArray[17..16] +
                                $CharArray[19..18] +
                                $CharArray[21..20] +
                                $CharArray[23..22] +
                                $CharArray[25..24] +
                                $CharArray[27..26] +
                                $CharArray[29..28] +
                                $CharArray[31..30]))
}

################################################################################

Export-InstallerRegistration

################################################################################
