# Reproducible: Compile Opam

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
@@BOOTSTRAPDIR_UNIX@@vendor/component-opam/src/repro/r-c-opam-0-system.sh

# Install the source code
# (Typically you can skip this step. It is only necessary if you changed any of these scripts or don't have a complete reproducible directory)
@@BOOTSTRAPDIR_UNIX@@vendor/component-opam/src/repro/r-c-opam-1-setup-noargs.sh

# Build and install Opam
@@BOOTSTRAPDIR_UNIX@@vendor/component-opam/src/repro/r-c-opam-2-build-noargs.sh

# Remove intermediate files including build files and .git folders
@@BOOTSTRAPDIR_UNIX@@vendor/component-opam/src/repro/r-c-opam-9-trim-noargs.sh
```
