# ================================
# Deployers.psm1
#
# PowerShell Module to deploy a folder. Meant for deploying an instance which
# must be completed uninstalled before re-installation, while being compatible
# with Blue Green deployers. Can be used for
# installation of executables or for self-cleaning temporary
# directories.
#
# === Deployment Identifiers ===
#
# A requirement is that deployment identifiers are idempotent
# representations of the **contents** of the deployment. That means
# using the same deployment id means deploying the same content.
#
# The following are good deployment identifiers:
# - a separator-delimited concatenation of one or more good deployment identifiers
#     like comma-separated deployment identifiers (as long as there is the separator is not in
#     the deployment identifiers)
# - a hash of one or more good deployment identifiers
# - a monotonically increasing build number
# - a semver label
# - an immutable git tag
# - a hash of the source code and build configuration of the deployment
# - a hash of the contents of the deployment (as long as there are no random or time-varying
#     values inside the deployment)
#
# === Blue Green State ===
#
# An external Deployers may initiate a blue green deployment. That deployer
# must conform to the following:
#
# The state is a triple (SLOT1, SLOT2, SLOT3) where each `SLOT<i>`
# is a record containing:
# - the UNIX epoch milliseconds of the last successful deployment,
#   or $null if no successful deployment to that slot
# - the deployment identifier of the last successful deployment
#   or $null if no successful deployment to that slot
# - a boolean where, if $true, means that this module
#   will never consider the slot for deployment
#
# State Record:
#  - id : string nullable.
#  - lastepochms : signed int64 nonnull default 0.
#  - reserved : boolean default false
#  - success : boolean default false
# We make lastepochms nonnull since it is used in sorting operations (to get
# the oldest slot)

$ErrorActionPreference = "Stop"

$DeployStateJson = "deploy-state-v1.json"
$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False

$DeploySlotInitValue = [ordered]@{ "id" = $null; "lastepochms" = 0; "reserved" = $false; "success" = $false }
$DeployStateInitValue = @( $DeploySlotInitValue )

# Initialize-BlueGreenDeploy
# --------------------------
#
# Given a $ParentPath, on exit a state object
# will be initialized if it hadn't been already
function Initialize-BlueGreenDeploy {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath
    )
    if (!(Test-Path -Path "$ParentPath\$DeployStateJson")) {
        Set-BlueGreenDeployState -ParentPath $ParentPath -DeployState $DeployStateInitValue
    }
}
Export-ModuleMember -Function Initialize-BlueGreenDeploy

# Start-BlueGreenDeploy
# ---------------------
#
# Given a $ParentPath and a deployment identifier, will give you a
# subfolder of $ParentPath which you can deploy into.
# When you are finished the deployment call `Stop-BlueGreenDeploy`.
#
# Starting a deployment may mean evicting another deployment, which
# in this simple implementation means clearing its directory of all
# of its content.
#
# -KeepOldDeploymentWhenSameDeploymentId: Use if you can do
#    an incremental deployment. This switch will stop the previous
#    deployment content from being cleaned as long as a deployment
#    is found with the same deployment id.
#
# It is **fine** if your deployment does not complete successfully
# and you can't call `Stop-BlueGreenDeploy`.
function Start-BlueGreenDeploy {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath,
        [Parameter(Mandatory = $true)]
        $DeploymentId,
        [switch]$KeepOldDeploymentWhenSameDeploymentId,
        $FixedSlotIdx,
        $LogFunction
    )

    # init state if not done already
    Initialize-BlueGreenDeploy -ParentPath $ParentPath

    # move to the next deploy slot
    $state = Get-BlueGreenDeployState -ParentPath $ParentPath | ConvertFrom-Json
    if ($null -eq $FixedSlotIdx) {
        $slotIdx = Step-BlueGreenDeploySlot -ParentPath $ParentPath -DeploymentId $DeploymentId -DeployState $state
    } else {
        $slotIdx = $FixedSlotIdx
    }

    # recreate the directory with no content but only if
    # a) the deployment id has changed or
    # b) the same deployment id was not in SUCCESS and not $KeepOldDeploymentWhenSameDeploymentId
    $DeployPath = Join-Path -Path $ParentPath -ChildPath $slotIdx
    $clean = $false
    if ($DeploymentId -ne $state[$slotIdx].id) {
        $clean = $true
    }
    elseif ((-not $state[$slotIdx].success) -and (-not $KeepOldDeploymentWhenSameDeploymentId)) {
        $clean = $true
    }

    # set the slot state, before we start modifying the slot
    $currentepochms = Get-CurrentEpochMillis
    $state[$slotIdx].id = $DeploymentId
    $state[$slotIdx].lastepochms = $currentepochms
    $state[$slotIdx].success = $false
    Set-BlueGreenDeployState -ParentPath $ParentPath -DeployState $state

    # clean if necessary
    if ($clean) {
        if ($PSBoundParameters.ContainsKey('LogFunction')) {
            Invoke-Command $LogFunction -ArgumentList @("Cleaning directory $DeployPath ...")
        } else {
            Write-Host "Cleaning directory $DeployPath ..."
        }
        New-CleanDirectory -Path $DeployPath
        if ($LogFunction) {
            Invoke-Command $LogFunction -ArgumentList @("Cleaned directory $DeployPath.")
        } else {
            Write-Host "Cleaned directory $DeployPath."
        }
    }

    # give back to caller
    Write-Output $DeployPath
}
Export-ModuleMember -Function Start-BlueGreenDeploy

# Stop-BlueGreenDeploy
#
# Will cleanup or finalize the deployment started by Start-BlueGreenDeploy.
#
# You use `-Success` to indicate that you want to finalize the deployment,
# meaning the deployment directory will live for at least one more successful
# deployment before being recycled. An exception will be thrown if the
# deployment id does not exist (ie. evicted by another deployment).
#
# You omit `-Success` to indicate that you have aborted the deployment, and
# want the deployment directory to be cleaned. No exception will be thrown
# if the deployment id does not exist  (ie. evicted by another deployment).
function Stop-BlueGreenDeploy {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath,
        [Parameter(Mandatory = $true)]
        $DeploymentId,
        [switch]$Success
    )
    $state = Get-BlueGreenDeployState -ParentPath $ParentPath | ConvertFrom-Json
    $matchSlotIdx = -1
    if ($DeploymentId -eq $state[0].id) {
        $matchSlotIdx = 0
    }

    # If and only if the caller says the deployment is success
    if ($Success) {
        if ($matchSlotIdx -lt 0) {
            throw "The deployment $DeploymentId says it finished but was not present. Other than the chance that the deployer has a bug assigning deployment ids, it is very likely that the deployment was evicted by another deployment"
        }
        # Save success and leave
        $state[$matchSlotIdx].success = $true
        Set-BlueGreenDeployState -ParentPath $ParentPath -DeployState $state
        return
    }

    # Deployment was aborted by caller.

    # is it still taking a slot?
    if ($matchSlotIdx -ge 0) {
        # recreate the directory with no content
        $DeployPath = Join-Path -Path $ParentPath -ChildPath $matchSlotIdx
        New-CleanDirectory -Path $DeployPath

        # free the slot, but protect against race condition where an external
        # package manager takes over the slot
        $state2 = Get-BlueGreenDeployState -ParentPath $ParentPath | ConvertFrom-Json
        $reserved = $state2[$matchSlotIdx].reserved
        $state[$matchSlotIdx] = $DeploySlotInitValue | ConvertTo-Json -Depth 5 | ConvertFrom-Json # clone
        $state[$matchSlotIdx].reserved = $reserved # restore 'reserved'
        Set-BlueGreenDeployState -ParentPath $ParentPath -DeployState $state
    }
}
Export-ModuleMember -Function Stop-BlueGreenDeploy

# Get-BlueGreenDeployIsFinished
#
# True if and only if the deployment id exists and is in success state.
#
# This is a pure function (no side-effects).
function Get-BlueGreenDeployIsFinished {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath,
        [Parameter(Mandatory = $true)]
        $DeploymentId
    )
    if (!(Test-Path ("$ParentPath\$DeployStateJson"))) {
        Write-Output $false
        return
    }
    $state = Get-BlueGreenDeployState -ParentPath $ParentPath | ConvertFrom-Json
    if ($DeploymentId -eq $state[0].id) {
        Write-Output $state[0].success
        return
    }
    Write-Output $false
}
Export-ModuleMember -Function Get-BlueGreenDeployIsFinished

# [Get-Sha256Hex16OfText -Text xyz] is HEX(SHA-256(xyz))[0:16]
function Get-Sha256Hex16OfText {
    param (
        $Text
    )
    $stringAsStream = [System.IO.MemoryStream]::new()
    $writer = [System.IO.StreamWriter]::new($stringAsStream)
    $writer.write($Text)
    $writer.Flush()
    $stringAsStream.Position = 0
    (Get-FileHash -Algorithm SHA256 -InputStream $stringAsStream).Hash.Substring(0,16)
}
Export-ModuleMember -Function Get-Sha256Hex16OfText

# [Get-PossibleSlotPaths -ParentPath $ParentPath [-SubPath $SubPath]] enumerates all of the paths of
# possible slots within `$ParentPath`: `$ParentPath\0`, `$ParentPath\1` and `$ParentPath\2`.
#
# Instead of the slot directory you can have this function return a slot subdirectory by
# specifying `-SubPath $SubPath`. With a `-SubPath a\b\c` the returned results will be
# `$ParentPath\0\a\b\c`, `$ParentPath\1\a\b\c` and `$ParentPath\2\a\b\c`.
function Get-PossibleSlotPaths {
    param(
        [Parameter(Mandatory = $true)]
        $ParentPath,
        $SubPath
    )
    $DeployPath = Join-Path -Path $ParentPath -ChildPath 0
    if ($SubPath) {
        Write-Output (Join-Path -Path $DeployPath -ChildPath $SubPath)
    } else {
        Write-Output $DeployPath
    }
}
Export-ModuleMember -Function Get-PossibleSlotPaths

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Private Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

# Get-BlueGreenDeployState
# ------------------------
function Get-BlueGreenDeployState {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath
    )
    $jsState = [System.IO.File]::ReadAllText("$ParentPath\$DeployStateJson", $Utf8NoBomEncoding)
    $jsState = $jsState | ConvertFrom-Json

    # fill in only valid state
    $slot = $jsState[0]

    # Type convert each field
    if ($null -eq $slot.id) {
        $id = $null
    }
    else {
        $id = [string]($slot.id)
    }
    $lastepochms = [int64]($slot.lastepochms)
    $reserved = [bool]($slot.reserved)
    $success = [bool]($slot.success)

    $state = @( @{ "id" = $id; "lastepochms" = $lastepochms; "reserved" = $reserved; "success" = $success } )

    Write-Output (ConvertTo-Json -Depth 5 $state)
}

# Set-BlueGreenDeployState
# ------------------------
function Set-BlueGreenDeployState {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath,
        [Parameter(Mandatory = $true)]
        $DeployState
    )
    if (!(Test-Path -Path "$ParentPath")) {
        New-Item -Path $ParentPath -ItemType Directory | Out-Null
    }
    if ($null -eq $DeployState.lastepochms) {
        throw "Null 'lastepochms' deploy state"
    }
    if ($null -eq $DeployState.reserved) {
        throw "Null 'reserved' deploy state"
    }
    if (Test-Path "$ParentPath\$DeployStateJson") {
        Copy-Item "$ParentPath\$DeployStateJson" -Destination "$ParentPath\$DeployStateJson.bak" -Force
    }
    $Str = $DeployState | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText("$ParentPath\$DeployStateJson.tmp", $Str, $Utf8NoBomEncoding) 
    if (Test-Path "$ParentPath\$DeployStateJson") {
        Remove-Item "$ParentPath\$DeployStateJson" -Force
    }
    Rename-Item "$ParentPath\$DeployStateJson.tmp" "$DeployStateJson" -Force
}

# Step-BlueGreenDeploySlotDryRun
#
# Do a dry-run of a move to the next deployment slot. Returns
# a PowerShell object of form:
#
#    @{
#       "chosenSlotIdx" = ...[int];
#       "stateAfterUpdate" = ...[PSCustomObject]
#    }
# or will throw an exception if there is no deployment slot.
#
# This is a pure function (no side-effects).
function Step-BlueGreenDeploySlotDryRun {
    param (
        [Parameter(Mandatory = $true)]
        $DeploymentId,
        [Parameter(Mandatory = $true)]
        $ImmutableDeployState,
        [Parameter(Mandatory = $true)]
        $CurrentEpochMs
    )
    $state = $ImmutableDeployState | ConvertTo-Json -Depth 5 | ConvertFrom-Json # clone

    # use what we picked (which is an indirect reference to $state)
    $state[0].lastepochms = $CurrentEpochMs
    $state[0].id = $DeploymentId
    $state[0].success = $false

    # give slot back to caller
    Write-Output @{ "chosenSlotIdx" = 0; "stateAfterUpdate" = $state }
}

# Step-BlueGreenDeploySlot
#
# Move to the next available deployment slot.
function Step-BlueGreenDeploySlot {
    param (
        [Parameter(Mandatory = $true)]
        $ParentPath,
        [Parameter(Mandatory = $true)]
        $DeploymentId,
        [Parameter(Mandatory = $true)]
        $DeployState
    )
    $currentepochms = Get-CurrentEpochMillis
    $next = Step-BlueGreenDeploySlotDryRun `
        -DeploymentId $DeploymentId `
        -ImmutableDeployState $DeployState `
        -CurrentEpochMs $currentepochms
    Set-BlueGreenDeployState -ParentPath $ParentPath -DeployState $next.stateAfterUpdate
    Write-Output $next.chosenSlotIdx
}

# Remove-DirectoryFully
#
# Remove a directory and all of its contents. Unlike Remove-Item -Recurse this will work in
# all versions of Windows.
# Will not fail if the path does not already exist.
function Remove-DirectoryFully {
    param( [Parameter(Mandatory = $true)] $Path )

    if (Test-Path -Path $Path) {
        # On Windows 11 Build 22478.1012 with Powershell 5.1, even though `Remove-Item -Force`
        # should delete ReadOnly files (which are typical for Opam installed executables), it
        # fails with: "You do not have sufficient access rights to perform this operation".
        # Instead we have to remove the ReadOnly attribute.
        Get-ChildItem $Path -Recurse -Force | Where-Object { $_.Attributes -band [io.fileattributes]::ReadOnly } | ForEach-Object {
            Set-ItemProperty -Path $_.FullName -Name Attributes -Value ($_.Attributes -band (-bnot [io.fileattributes]::ReadOnly))
        }

        # We want to do `Remove-Item -Path $Path -Recurse -Force`. However the docs for Remove-Item
        # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/remove-item?view=powershell-7.2#parameters
        # say:
        # > The Recurse parameter might not delete all subfolders or all child items. This is a known issue.
        # > ! Note
        # > This behavior was fixed in Windows versions 1909 and newer.
        # So we use the Command Prompt instead (with COMSPEC so that MSYS2 "cmd" does not get run).
        & "$env:COMSPEC" /c "rd /s /q `"$Path`""
    }
}
Export-ModuleMember -Function Remove-DirectoryFully

# New-CleanDirectory
#
# Clean the directory of all of its content. Make it if it doesn't already exist.
function New-CleanDirectory {
    param( [Parameter(Mandatory = $true)] $Path )

    Remove-DirectoryFully -Path $Path
    New-Item -Path $Path -ItemType Directory | Out-Null
}
Export-ModuleMember -Function New-CleanDirectory

function Get-CurrentEpochMillis {
    [long]$timestamp = [math]::Round((([datetime]::UtcNow) - (Get-Date -Date '1/1/1970')).TotalMilliseconds)
    $timestamp
}
Export-ModuleMember -Function Get-CurrentEpochMillis
