# Kernel provenance

`shen-erl` targets Shen **42.0**, specifically Mark Tarver's refreshed S42
distribution uploaded on 2026-08-25.

## Where the build gets it

The build fetches the kernel from the canonical mirror, pinned by commit and
checksum:

- Canonical mirror: `pyrex41/shen-upstream`, tag
  `s42-pristine-20260825` (annotated tag object
  `8104a3ce0e35c3405fe299b9b25de75adb308ef6`, peeled commit
  `28825a211f5b2fb952510dab17267ca8eb9594a0`)
- Fetched as
  `https://codeload.github.com/pyrex41/shen-upstream/tar.gz/28825a211f5b2fb952510dab17267ca8eb9594a0`
  (the commit, not the tag, so moving the tag cannot change the input)
- Tarball SHA-256:
  `c2e46b924b30ac3743058b75bc2a6f66c9fcfa317511fd4a96a78390830044e1`

If the mirror cannot be downloaded or fails its checksum,
`scripts/fetch-kernel.sh` falls back to Tarver's upload. It uses that upload
only when its checksum matches the pinned value. If neither source matches,
the build stops. Nothing is unpacked until a checksum has matched.

- Upstream archive (fallback): `https://www.shenlanguage.org/Download/S42.zip`
- SHA-256: `d86aff3232da5870719d7d2f6bdfe27f3d12f3a93335f5492224ce6062c0f6ff`

Upstream replaces `S42.zip` in place, without changing its version.
The original 2026-08-25 upload had SHA-256
`30abdc7e5a1e27b7a20109c1ed141e4712885e31f24d9710d16415fbbd4dfb23`. It was
replaced by the `d86aff32…` archive, which reorganizes only `Lib/LogicLab`.
Its `KLambda` and `Test Programs` directories are byte-identical to the mirror
tag. Primary fetches from the mirror keep future re-uploads from breaking or
silently changing builds. When upstream re-uploads again, compare the new
archive's `KLambda` against the mirror. If only the checksum has changed,
update `SHEN_ARCHIVE_SHA256` in the `Makefile`.

## What the kernel is

The 15 `.kl` files under the `KLambda` directory are the kernel proper.
This refreshed S-series kernel is a different lineage from the community
`ShenOSKernel-42.0`: it has `backend.kl`, no `dict.kl` or `init.kl`, and performs
initialisation through load-ordered top-level forms rather than a
`shen.initialise` function.

The build additionally copies the four portable `extension-*.kl` files from
the community ShenOSKernel 42.0 release. Its tarball is checksum-pinned to
`32e86f58a1f6bbc111712a777a04a592c474e5cd05c2db7be0125f25ba8f8e35`.
The launcher, features, and expand-dynamic extensions are booted; programmable
pattern matching is included as an opt-in extension. Certification tests are
copied directly from the kernel distribution's `Test Programs` directory.
