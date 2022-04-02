<#
.Synopsis
    Set up all programs and data folders that are shared across
    all users on the machine.
.Description
    Installs the MSBuild component of Visual Studio.

    Interactive Terminals
    ---------------------

    If you are running from within a continuous integration (CI) scenario you may
    encounter `Exception setting "CursorPosition"`. That means a command designed
    for user interaction was run in this script; use -SkipProgress to disable
    the need for an interactive terminal.

.Parameter ParentProgressId
    The PowerShell progress identifier. Optional, defaults to -1.
    Use when embedding this script within another setup program
    that reports its own progress.
.Parameter DkmlPath
    The directory containing .dkmlroot
.Parameter TempParentPath
    Temporary directory. A subdirectory will be created within -TempParentPath.
    Defaults to $env:temp\diskuvocaml\setupmachine.

.Parameter SkipAutoInstallVsBuildTools
    Do not automatically install Visual Studio Build Tools.

    Even with this switch is selected a compatibility check is
    performed to make sure there is a version of Visual Studio
    installed that has all the components necessary for Diskuv OCaml.
.Parameter SilentInstall
    When specified no user interface should be shown.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
.Parameter AllowRunAsAdmin
    When specified you will be allowed to run this script using
    Run as Administrator.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
.Parameter VcpkgCompatibility
    Install a version of Visual Studio that is compatible with Microsoft's
    vcpkg (the C package manager).
.Parameter SkipProgress
    Do not use the progress user interface.
#>

[CmdletBinding()]
param (
    [Parameter()]
    [int]
    $ParentProgressId = -1,
    [string]
    $DkmlPath,
    [string]
    $TempParentPath,
    [switch]
    $SkipAutoInstallVsBuildTools,
    [switch]
    $SilentInstall,
    [switch]
    $AllowRunAsAdmin,
    [switch]
    $VcpkgCompatibility,
    [switch]
    $SkipProgress
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
if (!$DkmlPath) {
    $DkmlPath = $HereDir.Parent.Parent.FullName
}
if (!(Test-Path -Path $DkmlPath\.dkmlroot)) {
    throw "Could not locate the DKML scripts. Thought DkmlPath was $DkmlPath"
}

$dsc = [System.IO.Path]::DirectorySeparatorChar
$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$HereDir${dsc}SingletonInstall"
$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$HereDir${dsc}dkmldir${dsc}vendor${dsc}dkml-runtime-distribution${dsc}src${dsc}windows"
Import-Module Deployers
Import-Module Machine

# Make sure not Run as Administrator
if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ((-not $AllowRunAsAdmin) -and $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error -Category SecurityError `
            -Message "You are in an PowerShell Run as Administrator session. Please run $HereScript from a non-Administrator PowerShell session."
        exit 1
    }
}

# Older versions of PowerShell and Windows Server use SSL 3 / TLS 1.0 while our sites
# (especially gitlab assets) may require the use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ----------------------------------------------------------------
# Progress Reporting

$global:ProgressStep = 0
$global:ProgressActivity = $null
$ProgressTotalSteps = 2
$ProgressId = $ParentProgressId + 1
function Write-ProgressStep {
    if (!$SkipProgress) {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    } else {
        Write-Host -ForegroundColor DarkGreen "[$(1 + $global:ProgressStep) of $ProgressTotalSteps]: $($global:ProgressActivity)"
    }
    $global:ProgressStep += 1
}
function Write-ProgressCurrentOperation {
    param(
        $CurrentOperation
    )
    if (!$SkipProgress) {
        Write-Progress -Id $ProgressId `
            -ParentId $ParentProgressId `
            -Activity $global:ProgressActivity `
            -Status $global:ProgressStatus `
            -CurrentOperation $CurrentOperation `
            -PercentComplete (100 * ($global:ProgressStep / $ProgressTotalSteps))
    }
}

# ----------------------------------------------------------------
# QUICK EXIT if already current version already deployed


# ----------------------------------------------------------------
# BEGIN Start deployment

$global:ProgressActivity = "Starting ..."
$global:ProgressStatus = "Starting ..."

# We use "deployments" for any temporary directory we need since the
# deployment process handles an aborted setup and the necessary cleaning up of disk
# space (eventually).
if (!$TempParentPath) {
    $TempParentPath = "$Env:temp\diskuvocaml\setupmachine"
}
$TempPath = Start-BlueGreenDeploy -ParentPath $TempParentPath -DeploymentId $MachineDeploymentId -LogFunction ${function:\Write-ProgressCurrentOperation}

# END Start deployment
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Visual Studio Setup PowerShell Module
$global:ProgressActivity = "Install Visual Studio Setup PowerShell Module"
Write-ProgressStep
# only error if user said $SkipAutoInstallVsBuildTools but there was no visual studio found
Import-VSSetup -TempPath "$TempPath\vssetup"
# magic exit code = 17 needed for `network_ocamlcompiler.ml:needs_install_admin`
$CompatibleVisualStudios = Get-CompatibleVisualStudios -ErrorIfNotFound:$SkipAutoInstallVsBuildTools -ExitCodeIfNotFound:17 -VcpkgCompatibility:$VcpkgCompatibility
# END Visual Studio Setup PowerShell Module
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Visual Studio Build Tools

# MSBuild 2015+ is the command line tools of Visual Studio.
#
# > Visual Studio Code is a very different product from Visual Studio 2015+. Do not confuse
# > the products if you need to install it! They can both be installed, but for this section
# > we are talking abobut Visual Studio 2015+ (ex. Visual Studio Community 2019).
#
# > Why MSBuild / Visual Studio 2015+? Because [vcpkg](https://vcpkg.io/en/getting-started.html) needs
# > Visual Studio 2015 Update 3 or newer as of July 2021.
#
# It is generally safe to run multiple MSBuild and Visual Studio installations on the same machine.
# The one in `C:\DiskuvOCaml\BuildTools` is **reserved** for our build system as it has precise
# versions of the tools we need.
#
# You can **also** install Visual Studio 2015+ which is the full GUI.
#
# Much of this section was adapted from `C:\Dockerfile.opam` while running
# `docker run --rm -it ocaml/opam:windows-msvc`.
#
# Key modifications:
# * We do not use C:\BuildTools but $env:SystemDrive\DiskuvOCaml\BuildTools instead
#   because C:\ may not be writable and avoid "BuildTools" since it is a known directory
#   that can create conflicts with other
#   installations (confer https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019)
# * This is meant to be idempotent so we "modify" and not just install.
# * We've added/changed some components especially to get <stddef.h> C header (actually, we should inform
#   ocaml-opam so they can mimic the changes)

$global:ProgressActivity = "Install Visual Studio Build Tools"
Write-ProgressStep

if ((-not $SkipAutoInstallVsBuildTools) -and ($CompatibleVisualStudios | Measure-Object).Count -eq 0) {
    $VsInstallTempPath = "$TempPath\vsinstall"

    # wipe installation directory so previous installs don't leak into the current install
    New-CleanDirectory -Path $VsInstallTempPath

    # Get components to install
    $VsComponents = Get-VisualStudioComponents -VcpkgCompatibility:$VcpkgCompatibility

    Invoke-WebRequest -Uri https://aka.ms/vscollect.exe   -OutFile $VsInstallTempPath\collect.exe
    Invoke-WebRequest -Uri "$VsBuildToolsInstallChannel"  -OutFile $VsInstallTempPath\VisualStudio.chman
    Invoke-WebRequest -Uri "$VsBuildToolsInstaller"       -OutFile $VsInstallTempPath\vs_buildtools.exe
    Invoke-WebRequest -Uri https://raw.githubusercontent.com/MisterDA/Windows-OCaml-Docker/d3a107132f24c05140ad84f85f187e74e83e819b/Install.cmd -OutFile $VsInstallTempPath\Install.orig.cmd
    $content = Get-Content -Path $VsInstallTempPath\Install.orig.cmd -Raw
    $content = $content -replace "C:\\TEMP", "$VsInstallTempPath"
    $content = $content -replace "C:\\vslogs.zip", "$VsInstallTempPath\vslogs.zip"
    $content | Set-Content -Path $VsInstallTempPath\Install.cmd

    # Create destination directory
    if (!(Test-Path -Path $env:SystemDrive\DiskuvOCaml)) { New-Item -Path $env:SystemDrive\DiskuvOCaml -ItemType Directory | Out-Null }

    # See how to use vs_buildtools.exe at
    # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019
    # and automated installations at
    # https://docs.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2019
    #
    # Channel Uri
    # -----------
    #   --channelUri is sticky. The channel URI of the first Visual Studio on the machine is used for all next installs.
    #   That makes sense for enterprise installations where Administrators need to have control.
    #   Confer: https://github.com/MicrosoftDocs/visualstudio-docs/issues/3425
    #   Can change with https://docs.microsoft.com/en-us/visualstudio/install/update-servicing-baseline?view=vs-2019
    $CommonArgs = @(
        "--wait",
        "--nocache",
        "--norestart",
        "--installPath", "$env:SystemDrive\DiskuvOCaml\BuildTools",

        # We don't want unreproducible channel updates!
        # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019#layout-command-and-command-line-parameters
        # So always use the specific versioned installation channel for reproducibility.
        "--channelUri", "$env:SystemDrive\doesntExist.chman"
        # a) the normal release channel:                    "--channelUri", "https://aka.ms/vs/$VsBuildToolsMajorVer/release/channel"
        # b) mistaken sticky value from Diskuv OCaml 0.1.x: "--channelUri", "$VsInstallTempPath\VisualStudio.chman"
    ) + $VsComponents.Add
    if ($SilentInstall) {
        $CommonArgs += @("--quiet")
    } else {
        $CommonArgs += @("--passive")
    }
    if (Test-Path -Path $env:SystemDrive\DiskuvOCaml\BuildTools\MSBuild\Current\Bin\MSBuild.exe) {
        $proc = Start-Process -FilePath $VsInstallTempPath\Install.cmd -NoNewWindow -Wait -PassThru `
            -ArgumentList (@("$VsInstallTempPath\vs_buildtools.exe", "modify") + $CommonArgs)
    }
    else {
        $proc = Start-Process -FilePath $VsInstallTempPath\Install.cmd -NoNewWindow -Wait -PassThru `
            -ArgumentList (@("$VsInstallTempPath\vs_buildtools.exe") + $CommonArgs)
    }
    $exitCode = $proc.ExitCode
    if ($exitCode -eq 3010) {
        Write-Warning "Microsoft Visual Studio Build Tools installation succeeded but a reboot is required!"
        Start-Sleep 5
        Write-Host ''
        Write-Host 'Press any key to exit this script... You must reboot!';
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
        throw
    }
    elseif ($exitCode -ne 0) {
        # collect.exe has already collected troubleshooting logs
        $ErrorActionPreference = "Continue"
        Write-Error (
            "`n`nMicrosoft Visual Studio Build Tools installation failed! Exited with $exitCode.!`n`n" +
            "FIRST you can retry this script which can resolve intermittent network failures or (rarer) Visual Studio installer bugs.`n"+
            "SECOND you can run the following (all on one line) to manually install Visual Studio Build Tools:`n`n`t$VsInstallTempPath\vs_buildtools.exe $($VsComponents.Add)`n`n"+
            "Make sure the following components are installed:`n"+
            "$($VsComponents.Describe)`n" +
            "THIRD, if everything else failed, you can file a Bug Report at https://github.com/diskuv/dkml-installer-ocaml/issues and attach $VsInstallTempPath\vslogs.zip`n"
        )
        exit 1
    }

    # Reconfirm the install was detected
    $CompatibleVisualStudios = Get-CompatibleVisualStudios -ErrorIfNotFound:$false -VcpkgCompatibility:$VcpkgCompatibility
    if (($CompatibleVisualStudios | Measure-Object).Count -eq 0) {
        $ErrorActionPreference = "Continue"
        & $VsInstallTempPath\collect.exe "-zip:$VsInstallTempPath\vslogs.zip"
        if (-not $SkipProgress) {
            Clear-Host
        }
        Write-Error (
            "`n`nNo compatible Visual Studio installation detected after the Visual Studio installation!`n" +
            "Often this is because a reboot is required or your system has a component that needs upgrading.`n`n" +
            "FIRST you should reboot and try again.`n`n"+
            "SECOND you can run the following (all on one line) to manually install Visual Studio Build Tools:`n`n`t$VsInstallTempPath\vs_buildtools.exe $($VsComponents.Add)`n`n"+
            "Make sure the following components are installed:`n"+
            "$($VsComponents.Describe)`n" +
            "THIRD, if everything else failed, you can file a Bug Report at https://github.com/diskuv/dkml-installer-ocaml/issues and attach $VsInstallTempPath\vslogs.zip`n"
        )
        exit 1
    }
}

Write-Host -ForegroundColor White -BackgroundColor DarkGreen "`n`nBEGIN Visual Studio(s) compatible with Diskuv OCaml"
Write-Host ($CompatibleVisualStudios | ConvertTo-Json -Depth 1) # It is fine if we truncate at level 1 ... this is just meant to be a summary
Write-Host -ForegroundColor White -BackgroundColor DarkGreen "END Visual Studio(s) compatible with Diskuv OCaml`n`n"

# END Visual Studio Build Tools
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# BEGIN Stop deployment

Stop-BlueGreenDeploy -ParentPath $TempParentPath -DeploymentId $MachineDeploymentId # no -Success so always delete the temp directory

# END Stop deployment
# ----------------------------------------------------------------

if (-not $SkipProgress) { Write-Progress -Id $ProgressId -ParentId $ParentProgressId -Activity $global:ProgressActivity -Completed }
