<#
.Synopsis
    Install opam.
.Description
    Modifies PATH for opam.
.Parameter InstallationPrefix
    The installation directory. Defaults to
    $env:LOCALAPPDATA\Programs\dkml-opam on Windows. On macOS and Unix,
    defaults to $env:XDG_DATA_HOME/dkml-opam if XDG_DATA_HOME defined,
    otherwise $env:HOME/.local/share/dkml-opam.
    "dkml-opam" will not conflict with any data directories created by
    opam init in the future.
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

# Import PowerShell modules
$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$HereDir"
Import-Module PathMods

# Set $InstallationPrefix (the bin/opam, etc. will be placed there) per:
#   https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
# Set $PossibleDkmlPrefix per dkml-component-ocamlcompiler's setup-userprofile.ps1
# and assume -FixedSlotIdx 0
if ($InstallationPrefix) {
    $PossibleDkmlPrefix = Join-Path (Join-Path (Split-Path -Path $InstallationPrefix -Parent) -ChildPath "DiskuvOCaml") -ChildPath "0"
} else {
    if ($env:LOCALAPPDATA) {
        $InstallationPrefix = "$env:LOCALAPPDATA\Programs\dkml-opam"
        $PossibleDkmlPrefix = "$env:LOCALAPPDATA\Programs\DiskuvOCaml\0"
    } elseif ($env:XDG_DATA_HOME) {
        $InstallationPrefix = "$env:XDG_DATA_HOME/dkml-opam"
        $PossibleDkmlPrefix = "$env:XDG_DATA_HOME/diskuv-ocaml/0"
    } elseif ($env:HOME) {
        $InstallationPrefix = "$env:HOME/.local/share/dkml-opam"
        $PossibleDkmlPrefix = "$env:HOME/.local/share/diskuv-ocaml/0"
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

# ----------------------------------------------------------------
# BEGIN Start install

$ProgramPath = $InstallationPrefix

$ProgramRelEssentialBinDir = "bin"
$ProgramEssentialBinDir = Join-Path $ProgramPath -ChildPath $ProgramRelEssentialBinDir
$PossibleDkmlEssentialBinDir = Join-Path $PossibleDkmlPrefix -ChildPath $ProgramRelEssentialBinDir

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

    $userpath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $userpath = Join-EnvPathEntry -PathValue $userpath -PathEntry $ProgramEssentialBinDir -MustBeAfterEntryIfExists $PossibleDkmlEssentialBinDir
    [Environment]::SetEnvironmentVariable("PATH", $userpath, "User")

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
