# Development

## Prereqs

This is the Windows prerequisite for any development listed on this page:

```powershell
dkml init
opam install . --deps-only --with-test --yes
opam install ./dkml-component-offline-opamshim.opam --keep-build-dir --yes
```

On Unix:

```sh
opam switch create . --no-install --repos 'default,diskuv-2.1.0=git+https://github.com/diskuv/diskuv-opam-repository.git#2.1.0'

# You can install just what is needed for https://github.com/diskuv/dkml-installer-opam
opam install ./dkml-component-common-opam.opam ./dkml-component-staging-opam32.opam ./dkml-component-staging-opam64.opam ./dkml-component-offline-opam.opam --keep-build-dir --yes

# Or install everything
opam install . --deps-only --with-test --yes
opam install ./dkml-component-offline-opamshim.opam --keep-build-dir --yes
```

## Running opamshim component

In Windows Powershell, assuming you have already installed DkML:

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

## Running dockcross from any x86/x86_64-capable OS

> Use `dockcross/manylinux2014-x86` below for 32-bit linux.

In a POSIX compatible shell (on Windows do `with-dkml bash` to get a shell):

```sh
docker run --rm dockcross/manylinux2014-x64 > ./dockcross
chmod +x ./dockcross
./dockcross -a -it bash -l
```

You will be inside the Linux dockcross container with all the
`dkml-component-opam` source code available. Type:

```sh
bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)"
opam init --disable-sandboxing --no-setup -c 4.14.1
opam install ./dkml-component-staging-opam64.opam --keep-build-dir

# You can edit files if you install vim (etc.)
yum install vim

# You can rerun the failed steps; most likely it will be something like ...
cd /root/.opam/default/.opam-switch/build/dkml-component-staging-opam64.*/_w
share/dkml/repro/110co/vendor/component-opam/src/repro/r-c-opam-2-build-noargs.sh
```
