(lang dune 2.9)

(name dkml-component-offline-opam)

; winget uses something close to semver [1] ordering to decide when a version
; is an upgrade.
; [1] = https://github.com/microsoft/winget-cli/blob/a989c11e91b78c070bcc97c6ac2c0308a97fb867/doc/specs/%23980%20-%20Apps%20and%20Features%20entries%20version%20mapping.md#solution-design
; opam uses Debian ordering with some conventions.
;
; We will translate:
;
; 2.2.0~alpha~dev -> 2.2.0-alpha0-20221231
; 2.2.0~alpha~1   -> 2.2.0-alpha1-20230601
; 2.2.0~beta2     -> 2.2.0-beta2-20240409
; 2.2.0           -> 2.2.0
;
; The dates are commit dates. They should be used until alpha and beta are over.
;
; The only thing we need to do in the opam version is to use alpha0 instead
; of alpha1.
(version 2.2.0)

(generate_opam_files true)

(source
 (github diskuv/dkml-component-opam))
(license Apache-2.0)
(authors "Diskuv, Inc. <opensource+dkml@support.diskuv.com>")
(maintainers "opensource+dkml@support.diskuv.com")

(package
 (name dkml-component-common-opam)
 (synopsis "Common code for opam DkML components")
 (description "Common code for opam DkML components")
 (depends
  (dkml-install                           (>= 0.5.1))
  (cmdliner                               (>= 1.2.0))
  (diskuvbox                              (>= 0.2.0))))

(package
 (name dkml-component-staging-opam32)
 (synopsis "DkML component for 32-bit versions of opam")
 (description "For 32-bit capable platforms, opam, opam-putenv and opam-installer will be in <share>/staging-files/<platform>.
But for any platform that does not support 32-bit, this package will install nothing (aka. be a no-op).
Consumers of the component should place both tools/opam64 and tools/opam32 into the PATH, so that whichever is available can be used.

The package version, and what [opam --version] returns, are closely associated with the Opam version from the Opam
source code. The only modifications are to ensure that the package version can be ordered using semver. In particular:

* 2.2.0~alpha~dev -> 2.2.0~alpha0~20221231
* 2.2.0~alpha~1   -> 2.2.0~alpha1~20230601
* 2.2.0           -> 2.2.0

The dates (YYYYMMDD) are the Git commit dates in the Opam source code, and simply replacing the tildes (~) with dashes (-) is
sufficient to be compatible with semver and winget version ordering.

Includes a patch to distinguish MSYS2 from Cygwin, esp. for rsync rather than symlinking which is needed on MSYS2.
")
 (depends
  (ocaml                                  (>= 4.12.1~))
  (dkml-install                           (>= 0.5.1))
  (dkml-runtime-common                    (>= 2.0.3))
  (cmdliner                               (>= 1.2.0))
  (diskuvbox                              (>= 0.2.0)))
 (depopts
  ocaml-system
  dkml-base-compiler
  ocaml-base-compiler
  ocaml-variants
  ocaml-option-32bit))

(package
 (name dkml-component-staging-opam64)
 (synopsis "DkML component for 64-bit versions of opam")
 (description "For 64-bit capable platforms, opam, opam-putenv and opam-installer will be in <share>/staging-files/<platform>.
But for any platform that does not support 64-bit, this package will install nothing (aka. be a no-op).
Consumers of the component should place both tools/opam64 and tools/opam32 into the PATH, so that whichever is available can be used.

Cross-compiling to both darwin_arm64 and darwin_x86_64 platforms are supported on macOS when you have both dkml-base-compiler and
conf-dkml-cross-toolchain installed in your switch.

The package version, and what [opam --version] returns, are closely associated with the Opam version from the Opam
source code. The only modifications are to ensure that the package version can be ordered using semver. In particular:

* 2.2.0~alpha~dev -> 2.2.0~alpha0~20221231
* 2.2.0~alpha~1   -> 2.2.0~alpha1~20230601
* 2.2.0           -> 2.2.0

The dates (YYYYMMDD) are the Git commit dates in the Opam source code, and simply replacing the tildes (~) with dashes (-) is
sufficient to be compatible with semver and winget version ordering.

Includes a patch to distinguish MSYS2 from Cygwin, esp. for rsync rather than symlinking which is needed on MSYS2.
")
 (depends
  (ocaml                                  (>= 4.12.1~))
  (dkml-install                           (>= 0.5.1))
  (dkml-runtime-common                    (>= 2.0.3))
  (cmdliner                               (>= 1.2.0))
  (diskuvbox                              (>= 0.2.0)))
 (depopts
  ocaml-system
  dkml-base-compiler
  ocaml-base-compiler
  ocaml-variants
  conf-dkml-cross-toolchain
  ocaml-option-32bit))

(package
 (name dkml-component-offline-opam)
 (synopsis "Offline install of opam")
 (description "Offline install that places opam in the installation directory.

Depending on the end-user's integer size, as reported by Sys.int_size, either 32-bit or 64-bit opam will be installed.

On macOS the end-user target ABI can be either darwin_arm64 or darwin_x86_64 when you have both dkml-base-compiler and
conf-dkml-cross-toolchain installed in your switch, regardless whether your host's ABI is darwin_arm64 or darwin_x86.64.
Otherwise on macOS the target ABI must match the host ABI.

The package version, and what [opam --version] returns, are closely associated with the Opam version from the Opam
source code. The only modifications are to ensure that the package version can be ordered using semver. In particular:

* 2.2.0~alpha~dev -> 2.2.0~alpha0~20221231
* 2.2.0~alpha~1   -> 2.2.0~alpha1~20230601
* 2.2.0           -> 2.2.0

The dates (YYYYMMDD) are the Git commit dates in the Opam source code, and simply replacing the tildes (~) with dashes (-) is
sufficient to be compatible with semver and winget version ordering.

Includes a patch to distinguish MSYS2 from Cygwin, esp. for rsync rather than symlinking which is needed on MSYS2.
")
 (depends
  (dkml-component-common-opam             (= :version))
  (dkml-component-staging-opam32          (= :version))
  (dkml-component-staging-opam64          (= :version))
  (dkml-component-staging-ocamlrun        (>= 4.12.1~))
  (dkml-install                           (>= 0.5.1))
  (diskuvbox                              (>= 0.2.0))))

(package
 (name dkml-component-offline-opamshim)
 (synopsis "Offline install of opam shim")
 (description "Offline install that places the opam shim and the real opam in the installation directory.

The opam shim updates the PATH and compiler environment variables, especially for Windows, and then delegates
to the real opam. The real opam is first checked in LOCALAPPDATA/Programs/opam/bin/opam.exe on Windows or
~/.local/bin/opam on *nix machines. If that does not exist, the real opam in the installation directory is
used. In this manner the authoritative, centrally installed opam.exe is always used.

Depending on the end-user's integer size, as reported by Sys.int_size, either 32-bit or 64-bit opam will be installed.

On macOS the end-user target ABI can be either darwin_arm64 or darwin_x86_64 when you have both dkml-base-compiler and
conf-dkml-cross-toolchain installed in your switch, regardless whether your host's ABI is darwin_arm64 or darwin_x86.64.
Otherwise on macOS the target ABI must match the host ABI.

The package version, and what [opam --version] returns, are closely associated with the Opam version from the Opam
source code. The only modifications are to ensure that the package version can be ordered using semver. In particular:

* 2.2.0~alpha~dev -> 2.2.0~alpha0~20221231
* 2.2.0~alpha~1   -> 2.2.0~alpha1~20230601
* 2.2.0           -> 2.2.0

The dates (YYYYMMDD) are the Git commit dates in the Opam source code, and simply replacing the tildes (~) with dashes (-) is
sufficient to be compatible with semver and winget version ordering.

Includes a patch to distinguish MSYS2 from Cygwin, esp. for rsync rather than symlinking which is needed on MSYS2.
")
 (depends
  (dkml-component-common-opam             (= :version))
  (dkml-component-staging-opam32          (= :version))
  (dkml-component-staging-opam64          (= :version))
  (dkml-component-staging-withdkml        (>= 0.1.0))
  (dkml-component-staging-ocamlrun        (>= 4.12.1~))
  (dkml-install                           (>= 0.5.1))
  (diskuvbox                              (>= 0.2.0))))
