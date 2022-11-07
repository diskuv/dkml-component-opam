(lang dune 2.9)

(name dkml-component-offline-opam)
(version 2.2.0~alpha~20221104)

(generate_opam_files true)

(source
 (github diskuv/dkml-component-opam))
(license Apache-2.0)
(authors "Diskuv, Inc. <opensource+diskuv-ocaml@support.diskuv.com>")
(maintainers "opensource+diskuv-ocaml@support.diskuv.com")

(package
 (name dkml-component-staging-opam32)
 (synopsis "DKML component for 32-bit versions of opam")
 (description "For 32-bit capable platforms, opam, opam-putenv and opam-installer will be in <share>/staging-files/<platform>.
But for any platform that does not support 32-bit, this package will install nothing (aka. be a no-op).
Consumers of the component should place both tools/opam64 and tools/opam32 into the PATH, so that whichever is available can be used.")
 (depends
  (dkml-install                           (>= 0.2.0))
  (diskuvbox                              (>= 0.1.0)))
 (depopts
  ocaml-system
  dkml-base-compiler
  ocaml-base-compiler
  ocaml-variants
  ocaml-option-32bit))

(package
 (name dkml-component-staging-opam64)
 (synopsis "DKML component for 64-bit versions of opam")
 (description "For 64-bit capable platforms, opam, opam-putenv and opam-installer will be in <share>/staging-files/<platform>.
But for any platform that does not support 64-bit, this package will install nothing (aka. be a no-op).
Consumers of the component should place both tools/opam64 and tools/opam32 into the PATH, so that whichever is available can be used.")
 (depends
  (dkml-install                           (>= 0.2.0))
  (diskuvbox                              (>= 0.1.0)))
 (depopts
  ocaml-system
  dkml-base-compiler
  ocaml-base-compiler
  ocaml-variants
  conf-dkml-cross-toolchain
  ocaml-option-32bit))

(package
 (name dkml-component-offline-opam)
 (synopsis "Offline install of Opam")
 (description "Offline install that places opam in the installation directory. Depending on the end-user's integer size, as reported by Sys.int_size, either 32-bit or 64-bit opam will be installed")
 (depends
  (dkml-component-staging-opam32          (= :version))
  (dkml-component-staging-opam64          (= :version))
  (dkml-component-staging-ocamlrun        (>= 4.12.1~))
  (dkml-install                           (>= 0.2.0))
  (diskuvbox                              (>= 0.1.0))))
