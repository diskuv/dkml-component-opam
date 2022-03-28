[CmdletBinding()]
param ()

Import-Module Deployers # for Get-Sha256Hex16OfText

# -----------------------------------
# Magic constants

# Magic constants that will identify new and existing deployments:
# * Microsoft build numbers
# * Semver numbers

#   OCaml on Windows 32-bit requires Windows SDK 10.0.18362.0 (MSVC bug). Let's be consistent and use it for 64-bit as well.
$Windows10SdkVer = "18362"        # KEEP IN SYNC with WindowsAdministrator.rst
$Windows10SdkFullVer = "10.0.$Windows10SdkVer.0"

# Visual Studio minimum version
# Why MSBuild / Visual Studio 2015+? Because [vcpkg](https://vcpkg.io/en/getting-started.html) needs
#   Visual Studio 2015 Update 3 or newer as of July 2021.
# 14.0.25431.01 == Visual Studio 2015 Update 3 (newest patch; older is 14.0.25420.10)
$VsVerMin = "14.0.25420.10"       # KEEP IN SYNC with WindowsAdministrator.rst and reproducible-compile-opam-(1-setup|2-build).sh's OPT_MSVS_PREFERENCE
$VsDescribeVerMin = "Visual Studio 2015 Update 3 or later"

$VsSetupVer = "2.2.14-87a8a69eef"

# Version Years
# -------------
#
# We install VS 2019 although it may be better for a compatibility matrix to do VS 2015 as well.
#
# If you need an older vs_buildtools.exe installer, see either:
# * https://docs.microsoft.com/en-us/visualstudio/releases/2019/history#release-dates-and-build-numbers
# * https://github.com/jberezanski/ChocolateyPackages/commits/master/visualstudio2017buildtools/tools/ChocolateyInstall.ps1
#
# However VS 2017 + VS 2019 Build Tools can install even the 2015 compiler component;
# confer https://devblogs.microsoft.com/cppblog/announcing-visual-c-build-tools-2015-standalone-c-tools-for-build-environments/.
#
# Below the installer is
#   >> VS 2019 Build Tools 16.11.2 <<
$VsBuildToolsMajorVer = "16" # Either 16 for Visual Studio 2019 or 15 for Visual Studio 2017 Build Tools
$VsBuildToolsInstaller = "https://download.visualstudio.microsoft.com/download/pr/bacf7555-1a20-4bf4-ae4d-1003bbc25da8/e6cfafe7eb84fe7f6cfbb10ff239902951f131363231ba0cfcd1b7f0677e6398/vs_BuildTools.exe"
$VsBuildToolsInstallChannel = "https://aka.ms/vs/16/release/channel" # use 'installChannelUri' from: & "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vswhere.exe" -all -products *

# Components
# ----------
#
# The official list is at:
# https://docs.microsoft.com/en-us/visualstudio/install/workload-component-id-vs-build-tools?view=vs-2019
#
# BUT THAT LIST ISN'T COMPLETE. You can use the vs_buildtools.exe installer and "Export configuration"
# and it will produce a file like in `vsconfig.json` in this folder. That will have exact component ids to
# use, and most importantly you can pick older versions like `Microsoft.VisualStudio.Component.VC.14.26.x86.x64`
# if the version of Build Tools supports it.
# HAVING SAID THAT, it is safest to use generic component names `Microsoft.VisualStudio.Component.VC.Tools.x86.x64`
# and install the fixed-release Build Tools that corresponds to the compiler version you want.
#
# We chose the following to work around the bugs listed below:
#
# * Microsoft.VisualStudio.Component.VC.Tools.x86.x64
#   - VS 2019 C++ x64/x86 build tools (Latest)
# * Microsoft.VisualStudio.Component.Windows10SDK.18362
#   - Windows 10 SDK (10.0.18362.0)
#   - Same version in ocaml-opam Docker image as of 2021-10-10
#
# VISUAL STUDIO BUG 1
# -------------------
#     ../../ocamlopt.opt.exe -nostdlib -I ../../stdlib -I ../../otherlibs/win32unix -c -w +33..39 -warn-error A -g -bin-annot -safe-string  semaphore.ml
#     ../../ocamlopt.opt.exe -nostdlib -I ../../stdlib -I ../../otherlibs/win32unix -linkall -a -cclib -lthreadsnat  -o threads.cmxa thread.cmx mutex.cmx condition.cmx event.cmx threadUnix.cmx semaphore.cmx
#     OCAML_FLEXLINK="../../boot/ocamlrun ../../flexdll/flexlink.exe" ../../boot/ocamlrun.exe ../../tools/ocamlmklib.exe -o threadsnat st_stubs.n.obj
#     dyndll09d83a.obj : fatal error LNK1400: section 0x13 contains invalid volatile metadata
#     ** Fatal error: Error during linking
#
#     make[3]: *** [Makefile:74: libthreadsnat.lib] Error 2
#     make[3]: Leaving directory '/c/DiskuvOCaml/OpamSys/32/src/opam/bootstrap/ocaml-4.12.0/otherlibs/systhreads'
#     make[2]: *** [Makefile:35: allopt] Error 2
#     make[2]: Leaving directory '/c/DiskuvOCaml/OpamSys/32/src/opam/bootstrap/ocaml-4.12.0/otherlibs'
#     make[1]: *** [Makefile:896: otherlibrariesopt] Error 2
#     make[1]: Leaving directory '/c/DiskuvOCaml/OpamSys/32/src/opam/bootstrap/ocaml-4.12.0'
#     make: *** [Makefile:219: opt.opt] Error 2
#
# Happens with Microsoft.VisualStudio.Component.VC.Tools.x86.x64,version=16.11.31317.239 (aka
# "MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest)" as of September 2021) when compiling
# both native 32-bit (x86) and cross-compiled 64-bit host for 32-bit target (x64_x86).
#
# Does _not_ happen with Microsoft.VisualStudio.Component.VC.Tools.x86.x64,version=16.6.30013.169
# which had been installed in Microsoft.VisualStudio.Product.BuildTools,version=16.6.30309.148
# (aka version 14.26.28806 with VC\Tools\MSVC\14.26.28801 directory) of
# VisualStudio/16.6.4+30309.148 in the GitLab CI Windows container
# (https://gitlab.com/gitlab-org/ci-cd/shared-runners/images/gcp/windows-containers/-/tree/main/cookbooks/preinstalled-software)
# by:
#  visualstudio2019buildtools 16.6.5.0 (no version 16.6.4!) (https://chocolatey.org/packages/visualstudio2019buildtools)
#  visualstudio2019-workload-vctools 1.0.0 (https://chocolatey.org/packages/visualstudio2019-workload-vctools)
#
# So we either want the "Latest" VC Tools for the old VS 2019 Studio 16.6:
#   >> VS 2019 Studio (Build Tools, etc.) 16.6.* <<
#   >> Microsoft.VisualStudio.Component.VC.Tools.x86.x64 (MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest)) <<
# or the specific compiler selected:
#   >> Microsoft.VisualStudio.Component.VC.14.26.x86.x64 <<
# Either of those will give use 14.26 compiler tools.
$VcVarsVer = "14.26"
$VcVarsCompatibleVers = @( "14.25" ) # Tested with GitHub Actions at https://github.com/diskuv/diskuv-ocaml-starter-ghmirror/actions
$VcVarsCompatibleComponents = $VcVarsCompatibleVers | ForEach-Object { "Microsoft.VisualStudio.Component.VC.${_}.x86.x64" }
if ($null -eq $VcVarsCompatibleComponents) { $VcVarsCompatibleComponents = @() }
$VcStudioVcToolsMajorVer = 16
$VcStudioVcToolsMinorVer = 6
$VsComponents = @(
    # Verbatim (except variable replacement) from vsconfig.json that was "Export configuration" from the
    # correctly versioned vs_buildtools.exe installer, but removed all transitive dependencies.

    # 2021-09-23/jonahbeckford@: Since vcpkg does not allow pinning the exact $VcVarsVer, we must install
    # VC.Tools. Also vcpkg expects VC\Auxiliary\Build\vcvarsall.bat to exist (https://github.com/microsoft/vcpkg-tool/blob/baf0eecbb56ef87c4704e482a3a296ca8e40ddc4/src/vcpkg/visualstudio.cpp#L207-L213)
    # which is only available with VC.Tools.

    # 2021-09-22/jonahbeckford@:
    # We do not include "Microsoft.VisualStudio.Component.VC.(Tools|$VcVarsVer).x86.x64" because
    # we need special logic in Get-CompatibleVisualStudios to detect it.

    "Microsoft.VisualStudio.Component.Windows10SDK.$Windows10SdkVer",
    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
)
$VsSpecialComponents = @(
    # 2021-09-22/jonahbeckford@:
    # We only install this component if a viable "Microsoft.VisualStudio.Component.VC.Tools.x86.x64" not detected
    # in Get-CompatibleVisualStudios.
    "Microsoft.VisualStudio.Component.VC.$VcVarsVer.x86.x64"
)
$VsAvailableProductLangs = @(
    # https://docs.microsoft.com/en-us/visualstudio/install/use-command-line-parameters-to-install-visual-studio?view=vs-2019#list-of-language-locales
    "Cs-cz",
    "De-de",
    "En-us",
    "Es-es",
    "Fr-fr",
    "It-it",
    "Ja-jp",
    "Ko-kr",
    "Pl-pl",
    "Pt-br",
    "Ru-ru",
    "Tr-tr",
    "Zh-cn",
    "Zh-tw"
)

# Consolidate the magic constants into a single deployment id
$VsComponentsHash = Get-Sha256Hex16OfText -Text ($CygwinPackagesArch -join ',')
$MachineDeploymentId = "winsdk-$Windows10SdkVer;vsvermin-$VsVerMin;vssetup-$VsSetupVer;vscomp-$VsComponentsHash"

Export-ModuleMember -Variable MachineDeploymentId
Export-ModuleMember -Variable VsBuildToolsMajorVer
Export-ModuleMember -Variable VsBuildToolsInstaller
Export-ModuleMember -Variable VsBuildToolsInstallChannel

# Exports for when someone wants to do:
#   cmake -G "Visual Studio 16 2019" -D CMAKE_SYSTEM_VERSION=$Windows10SdkFullVer -T version=$VcVarsVer
Export-ModuleMember -Variable Windows10SdkFullVer
Export-ModuleMember -Variable VcVarsVer

# -----------------------------------

$MachineDeploymentHash = Get-Sha256Hex16OfText -Text $MachineDeploymentId
$DkmlPowerShellModules = "$env:SystemDrive\DiskuvOCaml\PowerShell\$MachineDeploymentHash\Modules"
$env:PSModulePath += "$([System.IO.Path]::PathSeparator)$DkmlPowerShellModules"

function Import-VSSetup {
    param (
        [Parameter(Mandatory = $true)]
        $TempPath
    )

    $VsSetupModules = "$DkmlPowerShellModules\VSSetup"

    if (!(Test-Path -Path $VsSetupModules\VSSetup.psm1)) {
        if (!(Test-Path -Path $TempPath)) { New-Item -Path $TempPath -ItemType Directory | Out-Null }
        Invoke-WebRequest -Uri https://github.com/microsoft/vssetup.powershell/releases/download/$VsSetupVer/VSSetup.zip -OutFile $TempPath\VSSetup.zip
        if (!(Test-Path -Path $VsSetupModules)) { New-Item -Path $VsSetupModules -ItemType Directory | Out-Null }
        Expand-Archive $TempPath\VSSetup.zip $VsSetupModules
    }

    Import-Module VSSetup
}
Export-ModuleMember -Function Import-VSSetup

function Get-VisualStudioComponents {
    [CmdletBinding()]
    param (
        [switch]
        $VcpkgCompatibility
    )

    # Figure out which languages are needed
    if ($VcpkgCompatibility) {
        if (Get-Command Get-WinSystemLocale -ErrorAction SilentlyContinue) {
            $VsProductLangs = @(
                # English is required because of https://github.com/microsoft/vcpkg-tool/blob/baf0eecbb56ef87c4704e482a3a296ca8e40ddc4/src/vcpkg/visualstudio.cpp#L286-L291
                # Confer https://github.com/microsoft/vcpkg#quick-start-windows and https://github.com/microsoft/vcpkg/issues/3842
                "en-US",

                # Use the system default (will be deduplicated in the next step, and removed if unknown in the following step).
                # This is to be user-friendly for non-English users; not strictly required since the rest of the docs are in English.
                (Get-WinSystemLocale).Name
            )
        } else {
            # May be running in `setup-userprofile.ps1 -OnlyOutputCacheKey` in a non-Windows pwsh shell
            $VsProductLangs = @( "en-US" )
        }
        $VsProductLangs = $VsProductLangs | Sort-Object -Property { $_.ToLowerInvariant() } -Unique
    } else {
        $VsProductLangs = @()
    }
    if (-not ($VsProductLangs -is [array])) { $VsProductLangs = @( $VsProductLangs ) }

    #   Only include languages which are available
    $VsProductLangs = $VsProductLangs | Where-Object { $VsAvailableProductLangs -contains $_ }
    if (-not ($VsProductLangs -is [array])) { $VsProductLangs = @( $VsProductLangs ) }

    # Troubleshooting description of what needs to be installed
    if ($VcpkgCompatibility) {
        $VsDescribeComponents = (
            "`ta) English language pack (en-US)`n" +
            "`tb) MSVC v142 - VS 2019 C++ x64/x86 build tools (v$VcVarsVer)`n" +
            "`tc) MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest)`n" +
            "`td) Windows 10 SDK ($Windows10SdkFullVer)`n")
    } else {
        $VsDescribeComponents = (
            "`ta) MSVC v142 - VS 2019 C++ x64/x86 build tools (v$VcVarsVer)`n" +
            "`tb) MSVC v142 - VS 2019 C++ x64/x86 build tools (Latest)`n" +
            "`tc) Windows 10 SDK ($Windows10SdkFullVer)`n")
    }

    $VsAddComponents =
        ($VsProductLangs | ForEach-Object { $i = 0 }{ @( "--addProductLang", $VsProductLangs[$i] ); $i++ }) +
        ($VsComponents | ForEach-Object { $i = 0 }{ @( "--add", $VsComponents[$i] ); $i++ }) +
        ($VsSpecialComponents | ForEach-Object { $i = 0 }{ @( "--add", $VsSpecialComponents[$i] ); $i++ })
    @{
        Add = $VsAddComponents;
        Describe = $VsDescribeComponents
    }
}
Export-ModuleMember -Function Get-VisualStudioComponents

function Get-VisualStudioProperties {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $VisualStudioInstallation
    )
    $MsvsPreference = ("" + $VisualStudioInstallation.InstallationVersion.Major + "." + $VisualStudioInstallation.InstallationVersion.Minor)

    # From https://cmake.org/cmake/help/v3.22/manual/cmake-generators.7.html#visual-studio-generators
    $CMakeVsYear = switch ($VisualStudioInstallation.InstallationVersion.Major)
    {
        8 {"2005"}
        9 {"2008"}
        10 {"2010"}
        11 {"2012"}
        12 {"2013"}
        14 {"2015"}
        15 {"2017"}
        16 {"2019"}
        17 {"2022"}
    }
    $CMakeGenerator = ("Visual Studio " + $VisualStudioInstallation.InstallationVersion.Major + " " + $CMakeVsYear)

    $VcVarsVerCandidates = $VisualStudioInstallation.Packages | Where-Object {
        $_.Id -eq "Microsoft.VisualStudio.Component.VC.$VcVarsVer.x86.x64" -or
        $VcVarsCompatibleComponents.Contains($_.Id)
    }
    if ($VcVarsVerCandidates.Count -eq 0) {
        $VcVarsVerCandidates = $VisualStudioInstallation.Packages | Where-Object {
            $_.Id -eq "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
        }
        if ($VcVarsVerCandidates.Count -eq 0) {
            throw "Get-CompatibleVisualStudios is not in sync with Get-VisualStudioProperties"
        }
        $VcVarsVerChoice = $VcVarsVer
    } else {
        # pick the latest compatible version
        ($VcVarsVerCandidates | Sort-Object -Property Version -Descending | Select-Object -Property Id -First 1).Id -match "Microsoft[.]VisualStudio[.]Component[.]VC[.](?<VCVersion>.*)[.]x86[.]x64"
        $VcVarsVerChoice = $Matches.VCVersion
    }

    @{
        InstallPath = $VisualStudioInstallation.InstallationPath;
        MsvsPreference = "VS$MsvsPreference";
        CMakeGenerator = "$CMakeGenerator";
        VcVarsVer = $VcVarsVerChoice;
        WinSdkVer = $Windows10SdkFullVer;
    }
}
Export-ModuleMember -Function Get-VisualStudioProperties

# Get zero or more Visual Studio installations that are compatible with Diskuv OCaml.
# The latest install date is chosen so theoretically should be zero or one installations returned,
# but for safety you should pick only the first given back (ex. Select-Object -First 1)
# and for troubleshooting you should dump what is given back (ex. Get-CompatibleVisualStudios | ConvertTo-Json -Depth 5)
function Get-CompatibleVisualStudios {
    [CmdletBinding()]
    param (
        [switch]
        $ErrorIfNotFound
    )
    # Some examples of the related `vswhere` product: https://github.com/Microsoft/vswhere/wiki/Examples
    $allinstances = Get-VSSetupInstance
    # Filter on minimum Visual Studio version and required components
    $instances = $allinstances | Select-VSSetupInstance `
        -Product * `
        -Require $VsComponents `
        -Version "[$VsVerMin,)"
    # select installations that have `VC.Tools (Latest)` -and- the exact `VC.MM.NN (vMM.NN)`,
    # -or- `VC.Tools (Latest)` if the Visual Studio Tools version matches MM.NN.
    $instances = $instances | Where-Object {
        $VCToolsMatch = $VCTools = $_.Packages | Where-Object {
            $_.Id -eq "Microsoft.VisualStudio.Component.VC.Tools.x86.x64" -and $_.Version.Major -eq $VcStudioVcToolsMajorVer -and $_.Version.Minor -eq $VcStudioVcToolsMinorVer
        }
        $VCTools = $_.Packages | Where-Object {
            $_.Id -eq "Microsoft.VisualStudio.Component.VC.Tools.x86.x64"
        };
        $VCExact = $_.Packages | Where-Object {
            $_.Id -eq "Microsoft.VisualStudio.Component.VC.$VcVarsVer.x86.x64"
        };
        $VCCompatible = $_.Packages | Where-Object {
            $VcVarsCompatibleComponents.Contains($_.Id)
        }
        ($VCToolsMatch.Count -gt 0) -or (  ($VCTools.Count -gt 0) -and (($VCExact.Count -gt 0) -or ($VCCompatible.Count -gt 0))  )
    }
    # select only installations that have the English language pack
    $instances = $instances | Where-Object {
        # Use equivalent English language pack detection
        # logic as https://github.com/microsoft/vcpkg-tool/blob/baf0eecbb56ef87c4704e482a3a296ca8e40ddc4/src/vcpkg/visualstudio.cpp#L286-L291
        $VisualStudioProps = Get-VisualStudioProperties -VisualStudioInstallation $_
        $English = Get-ChildItem -Path "$($_.InstallationPath)\VC\Tools\MSVC\$($VisualStudioProps.VcVarsVer).*" -Recurse -Include 1033 | Measure-Object
        $English.Count -gt 0
    }
    # give troubleshooting and exit if no more compatible installations remain
    if ($ErrorIfNotFound -and ($instances | Measure-Object).Count -eq 0) {
        $ErrorActionPreference = "Continue"
        Write-Warning "`n`nBEGIN Dump all incompatible Visual Studio(s)`n`n"
        if ($null -ne $allinstances) { Write-Host ($allinstances | ConvertTo-Json -Depth 5) }
        Write-Warning "`n`nEND Dump all incompatible Visual Studio(s)`n`n"
        $err = "There is no $VsDescribeVerMin with the following:`n$VsDescribeComponents"
        Write-Error $err
        # flush for GitLab CI
        [Console]::Out.Flush()
        [Console]::Error.Flush()
        exit 1
    }
    # sort by install date (newest first) and give back to caller
    $instances | Sort-Object -Property InstallDate -Descending
}
Export-ModuleMember -Function Get-CompatibleVisualStudios
