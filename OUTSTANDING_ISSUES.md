# Outstanding Issues

## PowerShell

Everything in PowerShell could have been done in OCaml.

## Components that should exist

* Git installed in `setup-userprofile.ps1` should be its own component.
* Visual Studio installed in `setup-machine.ps1` should be its own component.
* VcpkgCompatibility (or DKSDK?) should be its own component, which installs
  Ninja and CMake but also ensure Visual Studio has language pack.
* CI or Full should be different components ([+] or make some cross-installer
  UI language to expose a radio button for CI vs Full)
* Each OCaml language version should be a different component ([+] or 
  make some cross-installer UI language to expose a dropdown for version)

[+] All the combinations of different components will get numerous quickly
without a UI.
