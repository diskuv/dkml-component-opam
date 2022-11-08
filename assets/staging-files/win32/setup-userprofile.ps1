<#
.Synopsis
    Install opam.
.Description
    Modifies PATH for opam.
.Parameter InstallationPrefix
    The installation directory. Defaults to
    $env:LOCALAPPDATA\Programs\opam on Windows. On macOS and Unix,
    defaults to $env:XDG_DATA_HOME/opam if XDG_DATA_HOME defined,
    otherwise $env:HOME/.local/share/opam.
.Parameter AllowRunAsAdmin
    When specified you will be allowed to run this script using
    Run as Administrator.
    We do not recommend you do this unless you are in continuous
    integration (CI) scenarios.
#>

[CmdletBinding()]
param (
    [string]
    $InstallationPrefix,
    [switch]
    $AllowRunAsAdmin
)

$ErrorActionPreference = "Stop"

$HereScript = $MyInvocation.MyCommand.Path

# Match set_dkmlparenthomedir() in crossplatform-functions.sh
if (!$InstallationPrefix) {
    if ($env:LOCALAPPDATA) {
        $InstallationPrefix = "$env:LOCALAPPDATA\Programs\opam"
    } elseif ($env:XDG_DATA_HOME) {
        $InstallationPrefix = "$env:XDG_DATA_HOME/opam"
    } elseif ($env:HOME) {
        $InstallationPrefix = "$env:HOME/.local/share/opam"
    }
}

$PSDefaultParameterValues = @{'Out-File:Encoding' = 'utf8'} # for Tee-Object. https://stackoverflow.com/a/58920518

# Make sure not Run as Administrator
if ([System.Environment]::OSVersion.Platform -eq "Win32NT") {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if ((-not $AllowRunAsAdmin) -and $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "You are in an PowerShell Run as Administrator session. Please run $HereScript from a non-Administrator PowerShell session."
        exit 1
    }
}

# Older versions of PowerShell and Windows Server use SSL 3 / TLS 1.0 while our sites
# (especially gitlab assets) may require the use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ----------------------------------------------------------------
# Functions

function Write-Error($message) {
    # https://stackoverflow.com/questions/38064704/how-can-i-display-a-naked-error-message-in-powershell-without-an-accompanying
    [Console]::ForegroundColor = 'red'
    [Console]::Error.WriteLine($message)
    [Console]::ResetColor()
}

function Get-Dos83ShortName {
    param(
        [Parameter(Mandatory=$true)]
        $Path
    )
    if ($null -ne $fsobject -and (Test-Path -Path $Path -PathType Container)) {
        $output = $fsobject.GetFolder($Path)
        $output.ShortPath
    } elseif ($null -ne $fsobject -and (Test-Path -Path $Path -PathType Leaf)) {
        $output = $fsobject.GetFile($Path)
        $output.ShortPath
    } else {
        $Path
    }
}

# ----------------------------------------------------------------
# BEGIN Start install

$ProgramPath = $InstallationPrefix

$ProgramRelEssentialBinDir = "bin"
$ProgramEssentialBinDir = "$ProgramPath\$ProgramRelEssentialBinDir"

if (!(Test-Path -Path $InstallationPrefix)) { New-Item -Path $InstallationPrefix -ItemType Directory | Out-Null }

# END Start install
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Enhanced Progress Reporting

$AuditLog = Join-Path -Path $ProgramPath -ChildPath "setup-userprofile.full.log"
if (Test-Path -Path $AuditLog) {
    # backup the original
    Rename-Item -Path $AuditLog -NewName "setup-userprofile.backup.$(Get-CurrentEpochMillis).log"
}

# From here on we need to stuff $ProgramPath with all the binaries for the distribution
# VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV

# Notes:
# * Include lots of `TestPath` existence tests to speed up incremental deployments.

$global:AdditionalDiagnostics = "`n`n"
try {
    # ----------------------------------------------------------------
    # BEGIN Modify User's environment variables

    $global:ProgressActivity = "Modify environment variables"
    $PathModified = $false

    # -----------
    # Modify PATH
    # -----------

    $splitter = [System.IO.Path]::PathSeparator # should be ';' if we are running on Windows (yes, you can run Powershell on other operating systems)

    $userpath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $userpathentries = $userpath -split $splitter # all of the User's PATH in a collection

    # Prepend bin\ to the User's PATH if it isn't already
    if (!($userpathentries -contains $ProgramEssentialBinDir)) {
        # remove any old deployments
        $possibleDir = $ProgramEssentialBinDir
        $userpathentries = $userpathentries | Where-Object {$_ -ne $possibleDir}
        $userpathentries = $userpathentries | Where-Object {$_ -ne (Get-Dos83ShortName $possibleDir)}
        # add new PATH entry
        $userpathentries = @( $ProgramEssentialBinDir ) + $userpathentries
        $PathModified = $true
    }

    if ($PathModified) {
        # modify PATH
        [Environment]::SetEnvironmentVariable("PATH", ($userpathentries -join $splitter), "User")
    }

    # END Modify User's environment variables
    # ----------------------------------------------------------------
}
catch {
    $ErrorActionPreference = 'Continue'
    Write-Error (
        "Setup did not complete because an error occurred.`n$_`n`n$($_.ScriptStackTrace)`n`n" +
        "$global:AdditionalDiagnostics`n`n" +
        "Bug Reports can be filed at https://github.com/diskuv/dkml-installer-opam/issues`n" +
        "Please copy the error message and attach the log file available at`n  $AuditLog`n")
    exit 1
}

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Setup is complete. Congratulations!"
Write-Host "Enjoy opam! Documentation can be found at https://opam.ocaml.org/. Announcements will be available at https://twitter.com/diskuv"
Write-Host ""
Write-Host ""
Write-Host ""
if ($PathModified) {
    Write-Warning "Your User PATH was modified."
    Write-Warning "You will need to log out and log back in"
    Write-Warning "-OR- (for advanced users) exit all of your Command Prompts, Windows Terminals,"
    Write-Warning "PowerShells and IDEs like Visual Studio Code"
}
