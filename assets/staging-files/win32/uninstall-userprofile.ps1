<#
.Synopsis
    Uninstalls opam.
.Description
    Removes the installation from the User's PATH environment variable.
.Parameter InstallationPrefix
    The installation directory. Defaults to
    $env:LOCALAPPDATA\Programs\dkml-opam on Windows. On macOS and Unix,
    defaults to $env:XDG_DATA_HOME/dkml-opam if XDG_DATA_HOME defined,
    otherwise $env:HOME/.local/share/dkml-opam.
    "dkml-opam" will not conflict with any data directories created by
    opam init in the future.
.Parameter AuditOnly
    Use when you want to see what would happen, but don't actually perform
    the commands.
#>

[CmdletBinding()]
param (
    [switch]
    $AuditOnly,
    [string]
    $InstallationPrefix
)

$ErrorActionPreference = "Stop"

# Set $InstallationPrefix (the bin/opam, etc. will be placed there) per:
#   https://specifications.freedesktop.org/basedir-spec/basedir-spec-latest.html
if (!$InstallationPrefix) {
    if ($env:LOCALAPPDATA) {
        $InstallationPrefix = "$env:LOCALAPPDATA\Programs\dkml-opam"
    } elseif ($env:XDG_DATA_HOME) {
        $InstallationPrefix = "$env:XDG_DATA_HOME/dkml-opam"
    } elseif ($env:HOME) {
        $InstallationPrefix = "$env:HOME/.local/share/dkml-opam"
    }
}

# Import PowerShell modules
$HereScript = $MyInvocation.MyCommand.Path
$HereDir = (get-item $HereScript).Directory
$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$HereDir"
Import-Module PathMods

$PSDefaultParameterValues = @{'Out-File:Encoding' = 'utf8'} # for Tee-Object. https://stackoverflow.com/a/58920518

# Older versions of PowerShell and Windows Server use SSL 3 / TLS 1.0 while our sites
# (especially gitlab assets) may require the use of TLS 1.2
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ----------------------------------------------------------------
# Progress declarations

function Write-Error($message) {
    # https://stackoverflow.com/questions/38064704/how-can-i-display-a-naked-error-message-in-powershell-without-an-accompanying
    [Console]::ForegroundColor = 'red'
    [Console]::Error.WriteLine($message)
    [Console]::ResetColor()
}

# ----------------------------------------------------------------
# BEGIN Start uninstall

$ProgramPath = $InstallationPrefix

$ProgramRelEssentialBinDir = "bin"
$ProgramEssentialBinDir = "$ProgramPath\$ProgramRelEssentialBinDir"

# END Start uninstall
# ----------------------------------------------------------------

# ----------------------------------------------------------------
# Enhanced Progress Reporting

function Get-CurrentTimestamp {
    (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
}

$AuditLog = Join-Path -Path $InstallationPrefix -ChildPath "uninstall-userprofile.full.log"
if (Test-Path -Path $AuditLog) {
    # backup the original
    Rename-Item -Path $AuditLog -NewName "uninstall-userprofile.backup.$(Get-CurrentEpochMillis).log"
} elseif (!(Test-Path -Path $InstallationPrefix)) {
    # Create the installation directory because that is where the audit log
    # will go.
    #
    # Why not exit immediately if there is no installation directory?
    # Because there are non-directory resources that may need to be uninstalled
    # like Windows registry items (ex. PATH environment variable edits).
    New-Item -Path $InstallationPrefix -ItemType Directory | Out-Null
}

function Set-UserEnvironmentVariable {
    param(
        [Parameter(Mandatory=$true)]
        $Name,
        [Parameter(Mandatory=$true)]
        $Value
    )
    $PreviousValue = [Environment]::GetEnvironmentVariable($Name, "User")
    if ($Value -ne $PreviousValue) {
        # Append what we will do into $AuditLog
        $now = Get-CurrentTimestamp
        $Command = "# Previous entry: [Environment]::SetEnvironmentVariable(`"$Name`", `"$PreviousValue`", `"User`")"
        $what = "[pwsh]$ $Command"
        Add-Content -Path $AuditLog -Value "$now $what" -Encoding UTF8

        $Command = "[Environment]::SetEnvironmentVariable(`"$Name`", `"$Value`", `"User`")"
        $what = "[pwsh]$ $Command"
        Add-Content -Path $AuditLog -Value "$now $what" -Encoding UTF8

        if (!$AuditOnly) {
            [Environment]::SetEnvironmentVariable($Name, $Value, "User")
        }
    }
}

# From here on we need to stuff $ProgramPath with all the binaries for the distribution
# VVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVV

# Notes:
# * Include lots of `TestPath` existence tests to speed up incremental deployments.

$global:AdditionalDiagnostics = "`n`n"
try {

    # ----------------------------------------------------------------
    # BEGIN Modify User's environment variables

    # -----------
    # Modify PATH
    # -----------

    $splitter = [System.IO.Path]::PathSeparator # should be ';' if we are running on Windows (yes, you can run Powershell on other operating systems)

    $userpath = [Environment]::GetEnvironmentVariable("PATH", "User")
    $userpathentries = $userpath -split $splitter # all of the User's PATH in a collection

    $PathModified = $false

    # Remove bin\ entries in the User's PATH
    if ($userpathentries -contains $ProgramEssentialBinDir) {
        # remove any old deployments
        $possibleDir = $ProgramEssentialBinDir
        $userpathentries = $userpathentries | Where-Object {$_ -ne $possibleDir}
        $userpathentries = $userpathentries | Where-Object {$_ -ne (Get-Dos83ShortName $possibleDir)}
        $PathModified = $true
    }

    if ($PathModified) {
        # modify PATH
        Set-UserEnvironmentVariable -Name "PATH" -Value ($userpathentries -join $splitter)
    }

    # END Modify User's environment variables
    # ----------------------------------------------------------------
}
catch {
    $ErrorActionPreference = 'Continue'
    Write-Error (
        "Uninstall did not complete because an error occurred.`n$_`n`n$($_.ScriptStackTrace)`n`n" +
        "$global:AdditionalDiagnostics`n`n" +
        "Bug Reports can be filed at https://github.com/diskuv/dkml-installer-opam/issues`n" +
        "Please copy the error message and attach the log file available at`n  $AuditLog`n")
    exit 1
}

Write-Host ""
Write-Host ""
Write-Host ""
Write-Host "Thanks for using opam!"
Write-Host ""
Write-Host ""
Write-Host ""
