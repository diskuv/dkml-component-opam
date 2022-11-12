# ======================
# PathMods.psm1

$ErrorActionPreference = "Stop"
$splitter = [System.IO.Path]::PathSeparator # should be ';' if we are running on Windows (yes, you can run Powershell on other operating systems)

if ((Get-Command New-Object).Parameters.Keys.Contains("ComObject")) {
    # Only Windows has DOS 8.3 names
    $fsobject = New-Object -ComObject Scripting.FileSystemObject
} else {
    $fsobject = $null
}

function Get-CurrentEpochMillis {
    [long]$timestamp = [math]::Round((([datetime]::UtcNow) - (Get-Date -Date '1/1/1970')).TotalMilliseconds)
    $timestamp
}
Export-ModuleMember -Function Get-CurrentEpochMillis

function Get-Dos83ShortName {
    param(
        [Parameter(Mandatory = $true)]
        $Path
    )
    if ($null -ne $fsobject -and (Test-Path -Path $Path -PathType Container)) {
        $output = $fsobject.GetFolder($Path)
        $output.ShortPath
    }
    elseif ($null -ne $fsobject -and (Test-Path -Path $Path -PathType Leaf)) {
        $output = $fsobject.GetFile($Path)
        $output.ShortPath
    }
    else {
        $Path
    }
}
Export-ModuleMember -Function Get-Dos83ShortName

# Join-EnvPathEntry
# ------------
#
# Places the path entry (-PathEntry A) into the PATH User environment variable.
#
# If a -MustBeAfterEntryIfExists B is specified, and B exists in the PATH environment
# variable, then:
# 1. Any existing path entries A in PATH are removed.
# 2. The path entry A will be placed immediately after path entry B.
#
# Otherwise:
# 1. Any existing path entries A in PATH are removed.
# 2. The path entry A is placed at the front of the PATH environment variable.
#
# Even if the path entry A already exists, it may be moved by using this
# function.
function Join-EnvPathEntry {
    param (
        [Parameter(Mandatory = $true)]
        $PathValue,
        [Parameter(Mandatory = $true)]
        $PathEntry,
        [Parameter()]
        $MustBeAfterEntryIfExists
    )

    # all of the PATH as a collection
    $pathEntries = $PathValue -split $splitter

    # Edge case: $MustBeAfterEntryIfExists is a DOS 8.3 name but $PathValue
    # contains full name
    if ($MustBeAfterEntryIfExists -and (Test-Path $MustBeAfterEntryIfExists)) {
        # Convert DOS 8.3 into a full name so that path search (Where-Object; see below)
        # can find the full name (and the DOS 8.3).
        $MustBeAfterEntryIfExists = (Get-Item -LiteralPath "$MustBeAfterEntryIfExists").FullName
    }

    # Remove any old path entry A
    if ($PathValue -eq "") {
        # Edge case: An empty PATH has no entries.
        $pathEntries = [string[]] @()
    }
    else {
        $pathEntries = $pathEntries | Where-Object { $_ -ne $PathEntry }
        # fix bug-causing PowerShell (ex. PS 5) flattening of single element
        if (-not ($pathEntries -is [array])) { $pathEntries = [string[]] @( $pathEntries ) }

        $pathEntries = $pathEntries | Where-Object { $_ -ne (Get-Dos83ShortName $PathEntry) }
        # fix bug-causing PowerShell (ex. PS 5) flattening of single element
        if (-not ($pathEntries -is [array])) { $pathEntries = [string[]] @( $pathEntries ) }
    }

    # $insertafteridx should always be ...
    # -1: insert at position 0 (before every other entry)
    #  0: insert at position 1 (after position 0)
    # +n: insert immediately after position n
    $acceptable_idxs = [int[]] @(-1)
    if ($MustBeAfterEntryIfExists) {
        # we want the last (max) entry, especially if both DOS 8.3 and full directory are in the PATH
        $insertafteridx = [array]::LastIndexOf($pathEntries, $MustBeAfterEntryIfExists)
        if ($insertafteridx -ge 0) {
            [int[]] $acceptable_idxs = $acceptable_idxs + $insertafteridx
        }
        $insertafteridx = [array]::LastIndexOf($pathEntries, (Get-Dos83ShortName $MustBeAfterEntryIfExists))
        if ($insertafteridx -ge 0) {
            [int[]] $acceptable_idxs = $acceptable_idxs + $insertafteridx
        }
    }
    $insertafteridx = ($acceptable_idxs | Measure-Object -Maximum).Maximum

    # Do the insert
    if ($insertafteridx -eq -1) {
        [string[]] $pathEntries = @( $PathEntry ) + $pathEntries
    }
    elseif ($insertafteridx -eq $pathEntries.Length - 1) {
        [string[]] $pathEntries = $pathEntries + @( $PathEntry )
    }
    else {
        $left = 0..($insertafteridx)
        $right = ($insertafteridx + 1)..($pathEntries.Length-1)
        [string[]] $pathEntries = $pathEntries[$left + @( $insertafteridx ) + $right]
        $pathEntries[$insertafteridx + 1] = $PathEntry
    }

    # Return without unwrapping of arrays. Confer: https://learn.microsoft.com/en-us/powershell/scripting/learn/deep-dives/everything-about-arrays?view=powershell-7.3#return-an-array
    Write-Output -NoEnumerate ($pathEntries -join $splitter)
}
Export-ModuleMember -Function Join-EnvPathEntry
