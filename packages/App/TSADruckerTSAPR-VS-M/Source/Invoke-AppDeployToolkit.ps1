<#
.SYNOPSIS
PSAppDeployToolkit - Installs or uninstalls the network printer \\tsaps1\tsaPR-VS-M.

.DESCRIPTION
Connects (or removes) the shared network printer \\tsaps1\tsaPR-VS-M and writes a
detection marker (TSAPrinterTSAPR-VS-M.ps1.tag). Migrated from PSADT v3 to v4.

.PARAMETER DeploymentType
The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode
Specifies whether the installation should be run in Interactive, Silent, NonInteractive, or Auto mode.

.PARAMETER SuppressRebootPassThru
Suppresses the 3010 return code (requires restart) from being passed back to the parent process.

.PARAMETER TerminalServerMode
Changes to "user install mode" and back to "user execute mode" for RDSH/Citrix servers.

.PARAMETER DisableLogging
Disables logging to file for the script.

.LINK
https://psappdeploytoolkit.com
#>

[CmdletBinding()]
param
(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [System.String]$DeploymentType = 'Install',

    [Parameter(Mandatory = $false)]
    [ValidateSet('Auto', 'Interactive', 'NonInteractive', 'Silent')]
    [System.String]$DeployMode = 'Silent',

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$SuppressRebootPassThru,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$TerminalServerMode,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.SwitchParameter]$DisableLogging
)


##================================================
## MARK: Variables
##================================================

$adtSession = @{
    # App variables.
    AppVendor = 'TSA'
    AppName = 'TSA Drucker Installieren TSAPR-VS-M'
    AppVersion = '1.0.2'
    AppArch = 'x64'
    AppLang = 'DE'
    AppRevision = '01'
    AppSuccessExitCodes = @(0)
    AppRebootExitCodes = @(1641, 3010)
    AppProcessesToClose = @('iexplore', 'AcroRd32', 'Acrobat')
    AppScriptVersion = '1.0.2'
    AppScriptDate = '2025-08-18'
    AppScriptAuthor = 'j.gruber'
    RequireAdmin = $false

    # Install Titles (Only set here to override defaults set by the toolkit).
    InstallName = ''
    InstallTitle = ''

    # Script variables.
    DeployAppScriptFriendlyName = $MyInvocation.MyCommand.Name
    DeployAppScriptParameters = $PSBoundParameters
    DeployAppScriptVersion = '4.1.0'
}

function Install-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Install
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## Show Welcome Message, close processes if specified, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt.
    $saiwParams = @{
        AllowDefer = $true
        DeferTimes = 3
        CheckDiskSpace = $true
        PersistPrompt = $true
    }
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        $saiwParams.Add('CloseProcesses', $adtSession.AppProcessesToClose)
    }
    Show-ADTInstallationWelcome @saiwParams

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ##================================================
    ## MARK: Install
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Installation tasks here>
    [String]$deployAppScriptFriendlyName = 'TSA Drucker'

    # Create directory for printer installation tracking
    # Use user-specific location if running in user context
    $isUserContext = -not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
    if ($isUserContext) {
        $printerDataPath = "$($env:LOCALAPPDATA)\Printers"
    } else {
        $printerDataPath = "$($env:ProgramData)\Printers"
    }

    if (-not (Test-Path $printerDataPath))
    {
        New-Item -Path $printerDataPath -ItemType Directory -Force | Out-Null
    }

    # Start logging
    Start-Transcript "$printerDataPath\TSAPrinterInstall.log" -Append

    try {
        Write-ADTLogEntry -Message "Starting installation of network printer \\tsaps1\tsaPR-VS-M" -Source $deployAppScriptFriendlyName

        # Check if running in user context and handle accordingly
        $isUserContext = -not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
        if ($isUserContext) {
            Write-ADTLogEntry -Message "Running in user context - using user-specific printer installation" -Source $deployAppScriptFriendlyName
        }

        # Check if printer already exists
        $existingPrinter = Get-Printer -Name "\\tsaps1\tsaPR-VS-M" -ErrorAction SilentlyContinue

        if ($existingPrinter) {
            Write-ADTLogEntry -Message "Printer \\tsaps1\tsaPR-VS-M already exists. Removing existing printer..." -Source $deployAppScriptFriendlyName
            Remove-Printer -Name "\\tsaps1\tsaPR-VS-M" -ErrorAction SilentlyContinue
        }

        # Add the network printer
        Write-ADTLogEntry -Message "Adding network printer \\tsaps1\tsaPR-VS-M" -Source $deployAppScriptFriendlyName
        Add-Printer -ConnectionName "\\tsaps1\tsaPR-VS-M" -ErrorAction Stop

        # Verify printer was added successfully
        $newPrinter = Get-Printer -Name "\\tsaps1\tsaPR-VS-M" -ErrorAction SilentlyContinue
        if ($newPrinter) {
            Write-ADTLogEntry -Message "Successfully installed printer \\tsaps1\tsaPR-VS-M" -Source $deployAppScriptFriendlyName

            # Set as default printer (optional - uncomment if needed)
            # Set-Printer -Name "\\tsaps1\tsaPR-VS-M" -Default
            # Write-ADTLogEntry -Message "Set \\tsaps1\tsaPR-VS-M as default printer" -Source $deployAppScriptFriendlyName

            # Create installation marker
            Set-Content -Path "$printerDataPath\TSAPrinterTSAPR-VS-M.ps1.tag" -Value "Installed" -Force
            Write-ADTLogEntry -Message "Installation marker created successfully" -Source $deployAppScriptFriendlyName
        } else {
            throw "Printer installation verification failed"
        }
    }
    catch {
        Write-ADTLogEntry -Message "Failed to install printer \\tsaps1\tsaPR-VS-M. Error: $($_.Exception.Message)" -Severity 3 -Source $deployAppScriptFriendlyName
        throw $_
    }
    finally {
        Stop-Transcript
    }

    ##================================================
    ## MARK: Post-Install
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"

    ## Display a message at the end of the install.
    Show-ADTInstallationPrompt -Message 'Printer installation completed successfully.' -ButtonRightText 'OK' -Icon Information -NoWait
}

function Uninstall-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Uninstall
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ##================================================
    ## MARK: Uninstall
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Uninstallation tasks here>
    [String]$deployAppScriptFriendlyName = 'TSA Drucker'

    # Determine printer data path for user context
    $isUserContext = -not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
    if ($isUserContext) {
        $printerDataPath = "$($env:LOCALAPPDATA)\Printers"
    } else {
        $printerDataPath = "$($env:ProgramData)\Printers"
    }

    # Start logging
    Start-Transcript "$printerDataPath\TSAPrinterUninstall.log" -Append

    try {
        Write-ADTLogEntry -Message "Starting uninstallation of printer \\tsaps1\tsaPR-VS-M" -Source $deployAppScriptFriendlyName

        # Check if printer exists
        $existingPrinter = Get-Printer -Name "\\tsaps1\tsaPR-VS-M" -ErrorAction SilentlyContinue

        if ($existingPrinter) {
            Write-ADTLogEntry -Message "Removing printer \\tsaps1\tsaPR-VS-M" -Source $deployAppScriptFriendlyName
            Remove-Printer -Name "\\tsaps1\tsaPR-VS-M" -ErrorAction Stop
            Write-ADTLogEntry -Message "Successfully removed printer \\tsaps1\tsaPR-VS-M" -Source $deployAppScriptFriendlyName
        } else {
            Write-ADTLogEntry -Message "Printer \\tsaps1\tsaPR-VS-M not found, nothing to remove" -Source $deployAppScriptFriendlyName
        }

        # Remove installation marker
        if (Test-Path "$printerDataPath\TSAPrinterTSAPR-VS-M.ps1.tag") {
            Remove-Item -Path "$printerDataPath\TSAPrinterTSAPR-VS-M.ps1.tag" -Force
            Write-ADTLogEntry -Message "Removed installation marker" -Source $deployAppScriptFriendlyName
        }
    }
    catch {
        Write-ADTLogEntry -Message "Failed to uninstall printer tsaPR-VS-M. Error: $($_.Exception.Message)" -Severity 3 -Source $deployAppScriptFriendlyName
        throw $_
    }
    finally {
        Stop-Transcript
    }

    ##================================================
    ## MARK: Post-Uninstallation
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
}

function Repair-ADTDeployment
{
    [CmdletBinding()]
    param
    (
    )

    ##================================================
    ## MARK: Pre-Repair
    ##================================================
    $adtSession.InstallPhase = "Pre-$($adtSession.DeploymentType)"

    ## If there are processes to close, show Welcome Message with a 60 second countdown before automatically closing.
    if ($adtSession.AppProcessesToClose.Count -gt 0)
    {
        Show-ADTInstallationWelcome -CloseProcesses $adtSession.AppProcessesToClose -CloseProcessesCountdown 60
    }

    ## Show Progress Message (with the default message).
    Show-ADTInstallationProgress

    ##================================================
    ## MARK: Repair
    ##================================================
    $adtSession.InstallPhase = $adtSession.DeploymentType

    ## <Perform Repair tasks here>

    ##================================================
    ## MARK: Post-Repair
    ##================================================
    $adtSession.InstallPhase = "Post-$($adtSession.DeploymentType)"
}


##================================================
## MARK: Initialization
##================================================

# Set strict error handling across entire operation.
$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
$ProgressPreference = [System.Management.Automation.ActionPreference]::SilentlyContinue
Set-StrictMode -Version 1

# Import the module and instantiate a new session.
try
{
    # Import the module locally if available (packaged layout: module sits beside this script), otherwise from PSModulePath.
    if (Test-Path -LiteralPath "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1" -PathType Leaf)
    {
        Get-ChildItem -LiteralPath "$PSScriptRoot\PSAppDeployToolkit" -Recurse -File | Unblock-File -ErrorAction Ignore
        Import-Module -FullyQualifiedName @{ ModuleName = "$PSScriptRoot\PSAppDeployToolkit\PSAppDeployToolkit.psd1"; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.0' } -Force
    }
    else
    {
        Import-Module -FullyQualifiedName @{ ModuleName = 'PSAppDeployToolkit'; Guid = '8c3c366b-8606-4576-9f2d-4051144f7ca2'; ModuleVersion = '4.1.0' } -Force
    }

    # Open a new deployment session, replacing $adtSession with a DeploymentSession.
    $iadtParams = Get-ADTBoundParametersAndDefaultValues -Invocation $MyInvocation
    $adtSession = Remove-ADTHashtableNullOrEmptyValues -Hashtable $adtSession
    $adtSession = Open-ADTSession @adtSession @iadtParams -PassThru
}
catch
{
    $Host.UI.WriteErrorLine((Out-String -InputObject $_ -Width ([System.Int32]::MaxValue)))
    exit 60008
}


##================================================
## MARK: Invocation
##================================================

# Commence the actual deployment operation.
try
{
    # Import any found extensions before proceeding with the deployment.
    Get-ChildItem -LiteralPath $PSScriptRoot -Directory | & {
        process
        {
            if ($_.Name -match 'PSAppDeployToolkit\..+$')
            {
                Get-ChildItem -LiteralPath $_.FullName -Recurse -File | Unblock-File -ErrorAction Ignore
                Import-Module -Name $_.FullName -Force
            }
        }
    }

    # Invoke the deployment and close out the session.
    & "$($adtSession.DeploymentType)-ADTDeployment"
    Close-ADTSession
}
catch
{
    # An unhandled error has been caught.
    $mainErrorMessage = "An unhandled error within [$($MyInvocation.MyCommand.Name)] has occurred.`n$(Resolve-ADTErrorRecord -ErrorRecord $_)"
    Write-ADTLogEntry -Message $mainErrorMessage -Severity 3
    Close-ADTSession -ExitCode 60001
}
