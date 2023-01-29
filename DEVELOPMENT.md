# Development

## Prereqs

This is a prerequisite any development listed on this page:

```powershell
dkml init
opam install . --deps-only --with-test --yes
opam install ./dkml-component-offline-opamshim.opam --keep-build-dir --yes
```

## Running opamshim component

```powershell
$OpamExe=(Get-Command opam).Path
$WithDkmlExe=(Get-Command with-dkml).Path
ocamlrun _opam/share/dkml-component-offline-opamshim/staging-files/generic/install_user.bc.exe --help

ocamlrun ./_opam/share/dkml-component-offline-opamshim/staging-files/generic/install_user.bc.exe `
    --target-dir _build/shim/control `
    --with-dkml-exe "$WithDkmlExe" `
    --opam-exe "$OpamExe"
```

## Debugging opamshim component

Change the home directory (`C:\Users\you`) to reflect your own:

```powershell
ocamdebug _opam/share/dkml-component-offline-opamshim/staging-files/generic/install_user.bc.exe

(ocd) set arguments --target-dir _build/shim/control --with-dkml-exe C:\Users\you\AppData\Local\Programs\DISKUV~1\bin\with-dkml.exe --opam-exe C:\Users\you\AppData\Local\Programs\DISKUV~1\bin\opam.exe -vvv

(ocd) run
```
