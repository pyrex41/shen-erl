# Kernel provenance

`shen-erl` targets Shen **41.2**, specifically Mark Tarver's refreshed S41.2
distribution uploaded on 2026-07-11.

- Upstream archive: `https://www.shenlanguage.org/Download/S41.2.zip`
- SHA-256: `51becbfd60fa8c93c3f8ae5b20b948eaa84c4b1d14ad2f5d2a056002a53ee836`
- Canonical mirror: `pyrex41/shen-upstream`, tag
  `s41.2-pristine-20260711`, commit
  `11fc51bdf53a4dcb505adeec6ec8352754cbe50f`

The 15 files under the archive's `S41/KLambda` directory are the kernel proper.
This refreshed S-series kernel is a different lineage from the community
`ShenOSKernel-41.2`: it has `backend.kl`, no `dict.kl` or `init.kl`, and performs
initialisation through load-ordered top-level forms rather than a
`shen.initialise` function.

The build additionally copies the four portable `extension-*.kl` files from
the community ShenOSKernel 41.2 release. Its tarball is checksum-pinned to
`d2182d70453d3e93d13bc20f763efdc18cdb23b481f41afb9943f5e9a0798f61`.
The launcher, features, and expand-dynamic extensions are booted; programmable
pattern matching is included as an opt-in extension. The same community
release supplies the official certification tests used by `make shen-tests`.
