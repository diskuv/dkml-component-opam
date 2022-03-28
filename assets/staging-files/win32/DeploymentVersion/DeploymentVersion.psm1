# ----------------------------------------------------------------
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
    Justification='The module is a set of variables',
    Target="AvailableOpamVersion")]
Param()

$DV_AvailableOpamVersion = "2.1.0.msys2.12" # needs to be a real Opam tag in https://github.com/diskuv/opam!
Export-ModuleMember -Variable DV_AvailableOpamVersion

# https://hub.docker.com/r/ocaml/opam/tags?page=1&ordering=last_updated&name=windows-msvc-ltsc2022-ocaml
# Q: Why use LTSC kernel? Ans:
#    1. The 2022 LTSC Windows image (https://docs.microsoft.com/en-us/windows-server/get-started/servicing-channels-comparison#long-term-servicing-channel-ltsc)
#       is available until 2027.
#    2. It is a single kernel image so it is smaller than multikernel `windows-msvc`
# Note: You must update this once every couple months because Docker Hub removes old versions.
# Note: It would be nice if we could query https://github.com/avsm/ocaml-dockerfile/blob/ac54d3550159b0450032f0f6a996c2e96d3cafd7/src-opam/dockerfile_distro.ml#L36-L47
# Image Date: Feb 28, 2022
$DV_WindowsMsvcDockerImage = "ocaml/opam:windows-msvc-ltsc2022-ocaml-4.12@sha256:a96f023f0878154170af6471a0f57d1122f7e90ea3f43c33fef2a16e168e1776"
Export-ModuleMember -Variable DV_WindowsMsvcDockerImage

$DV_MSYS2Packages = @(
    # Hints:
    #  1. Use `MSYS2\msys2_shell.cmd -here` to launch MSYS2 and then `pacman -Ss diff` to
    #     search for example for 'diff' packages.
    #     You can also browse https://packages.msys2.org
    #  2. Instead of `pacman -Ss [search term]` you can use something like `pacman -Fy && pacman -F x86_64-w64-mingw32-as.exe`
    #     to find which package installs for example the `x86_64-w64-mingw32-as.exe` file.

    # ----
    # Needed by the Local Project's `Makefile`
    # ----

    "make",
    "diffutils",
    "dos2unix",

    # ----
    # Needed by Opam
    # ----

    "patch",
    "rsync",
    # We don't use C:\WINDOWS\System32\tar.exe even if it is available in all Windows SKUs since build
    # 17063 (https://docs.microsoft.com/en-us/virtualization/community/team-blog/2017/20171219-tar-and-curl-come-to-windows)
    # because get:
    #   ocamlbuild-0.14.0/examples/07-dependent-projects/libdemo: Can't create `..long path with too many backslashes..`# tar.exe: Error exit delayed from previous errors.
    #   MSYS2 seems to be able to deal with excessive backslashes
    "tar",
    "unzip",

    # ----
    # Needed by many OCaml packages during builds
    # ----

    # ----
    # Needed by OCaml package `feather`
    # ----

    "procps", # provides `pgrep`

    # ----
    # Needed by OCaml package `conf-pkg-config`
    # ----

    #   We do not use the MSYS2 subsystem because that
    #   could produce binaries that are linked to msys-2.0.dll.
    #   But it also means that pkg-config is opt-in since
    #   /mingw64 has to be added to the PATH ... that is perfectly
    #   fine. Note: DKSDK bundles its own pkg-config (actually pkgconf)
    #   compiled from vcpkg.
    "mingw-w64-x86_64-pkg-config",

    # ----
    # Needed for our own sanity!
    # ----

    "psmisc", # process management tools: `pstree`
    "rlwrap", # command line history for executables without builtin command line history support
    "tree" # directory structure viewer
)
Export-ModuleMember -Variable DV_MSYS2Packages
if ([Environment]::Is64BitOperatingSystem) {
    $DV_MSYS2PackagesArch = $DV_MSYS2Packages + @(
        # ----
        # Needed for our own sanity!
        # ----

        "mingw-w64-x86_64-ag" # search tool called Silver Surfer
    )
} else {
    $DV_MSYS2PackagesArch = $DV_MSYS2Packages + @(
        # ----
        # Needed for our own sanity!
        # ----

        "mingw-w64-i686-ag" # search tool called Silver Surfer
    )
}
Export-ModuleMember -Variable DV_MSYS2PackagesArch
