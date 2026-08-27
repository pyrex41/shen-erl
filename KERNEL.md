# Kernel provenance

`shen-erl` targets Shen **42.0**, specifically Mark Tarver's refreshed S42
distribution uploaded on 2026-08-25.

- Upstream archive: `https://www.shenlanguage.org/Download/S42.zip`
- SHA-256: `30abdc7e5a1e27b7a20109c1ed141e4712885e31f24d9710d16415fbbd4dfb23`
- Canonical mirror: `pyrex41/shen-upstream`, tag
  `s42-pristine-20260825` (annotated tag object
  `8104a3ce0e35c3405fe299b9b25de75adb308ef6`, peeled commit
  `28825a211f5b2fb952510dab17267ca8eb9594a0`)

The 15 files under the archive's `S42/KLambda` directory are the kernel proper.
This refreshed S-series kernel is a different lineage from the community
`ShenOSKernel-42.0`: it has `backend.kl`, no `dict.kl` or `init.kl`, and performs
initialisation through load-ordered top-level forms rather than a
`shen.initialise` function.

The build additionally copies the four portable `extension-*.kl` files from
the community ShenOSKernel 42.0 release. Its tarball is checksum-pinned to
`32e86f58a1f6bbc111712a777a04a592c474e5cd05c2db7be0125f25ba8f8e35`.
The launcher, features, and expand-dynamic extensions are booted; programmable
pattern matching is included as an opt-in extension. Certification tests are
copied directly from the canonical archive's `Test Programs` directory.
