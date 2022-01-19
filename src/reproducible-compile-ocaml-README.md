# Reproducible: Compile OCaml

Cautions:
* Windows 10 ARM (64-bit Snapdragon) does not work as a cross-compiling target. Most of the patches are done for it except `flexdll` has not yet been patched
  to handle more than `x64` or `x86`, or accept more parameters than `-x64`.

Prerequisites:
* On Windows you will need:
  * MSYS2
  * Microsoft Visual Studio 2015 Update 3 or later
  * Git

Then run the following in Bash (for Windows use `msys2_shell.cmd` in your MSYS installation folder):

```bash
if [ ! -e @@BOOTSTRAPDIR_UNIX@@README.md ]; then
    echo "You are not in a reproducible target directory" >&2
    exit 1
fi

# Install required system packages
@@BOOTSTRAPDIR_UNIX@@vendor/dkml-component-ocamlrun/src/reproducible-compile-ocaml-0-system.sh

# Install the source code
# (Typically you can skip this step. It is only necessary if you changed any of these scripts or don't have a complete reproducible directory)
@@BOOTSTRAPDIR_UNIX@@vendor/dkml-component-ocamlrun/src/reproducible-compile-ocaml-1-setup-noargs.sh

# Build and install OCaml
@@BOOTSTRAPDIR_UNIX@@vendor/dkml-component-ocamlrun/src/reproducible-compile-ocaml-2-build-noargs.sh
```
