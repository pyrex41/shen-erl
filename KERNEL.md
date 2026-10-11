# Kernel provenance

`shen-erl` targets Shen **42.2**: the community **ShenOSKernel 42.2** release
from [`Shen-Language/shen-sources`](https://github.com/Shen-Language/shen-sources),
used wholesale and unmodified. This is the kernel that upstream shen-scheme
0.50 ships, so `shen-erl` and shen-scheme run byte-identical KLambda.

## Where the build gets it

`scripts/fetch-kernel.sh` (driven by the `Makefile`) downloads the release
asset and verifies its checksum before unpacking anything:

- Release: tag `shen-42.2`, commit `73507e069fe147aefb728d632c4ce40bc6a7b314`
- Asset:
  `https://github.com/Shen-Language/shen-sources/releases/download/shen-42.2/ShenOSKernel-42.2.tar.gz`
- SHA-256: `1d02273003654d34ec020ae67cb214ecec410dee3350419ff807d82b652678d8`
  (the checksum pinned in shen-scheme 0.50's `Makefile`)

To build offline, point `SHEN_KERNEL_ARCHIVE` at a local copy of the same
tarball:

```sh
SHEN_KERNEL_ARCHIVE=/path/to/ShenOSKernel-42.2.tar.gz make
```

The local archive must match the same SHA-256. If the download or the local
archive fails the checksum, the build stops.

## Lineage

Until this release `shen-erl` booted Mark Tarver's refreshed S42.0 upload
(mirror `pyrex41/shen-upstream`, tag `s42-pristine-20260825`). 42.1 and 42.2
are releases of the community line, which is structured differently. The
ports tracked in pyrex41/bifrost#26 chose to adopt ShenOSKernel 42.2 wholesale
rather than port its changes onto the Tarver base.

Differences that matter to this port:

- Every `.kl` file contains only `defun`s. `init.kl` defines
  `shen.initialise`, which builds the global environment. Boot loads all
  modules, then calls `(shen.initialise)`, registers the port's own
  functions, and initialises the features and expand-dynamic extensions
  (`shen_erl_kl_compiler:load_funs/0`).
- Properties live in a `dict.kl` dictionary held in `*property-vector*`.
  Arities and lambda forms are the `arity` and `shen.lambda-form` properties;
  there is no `shen.*lambdatable*`. Port functions (`erl.*`, `json.*`,
  `js.*`) are registered there so that `fn`, `arity` and partial application
  see them. The dictionary primitives are overridden by ETS-backed versions in
  `shen_erl_kl_overrides`.
- The REPL entry point is `shen.repl`. Standard input returns -1 at EOF, so
  a final line without a trailing newline is still read (42.1).

The port does not override `macroexpand`, `shen.macroexpand-h`, the reader or
`shen.try-parse`, so the 42.1 source-form handler changes need no port code.

## What is built

`kl/` receives these files from `klambda/`:

- The kernel proper: `core`, `declarations`, `dict`, `init`, `load`,
  `macros`, `prolog`, `reader`, `sequent`, `sys`, `t-star`, `toplevel`,
  `track`, `types`, `writer`, `yacc`.
- Booted extensions: `extension-features`, `extension-expand-dynamic`,
  `extension-launcher`.
- Compiled but not booted: `extension-namespaces`,
  `extension-programmable-pattern-matching`, `extension-type-annotations`.

The precompiled standard library (`klambda/stlib.kl`) is not built or booted.
Running `stlib.initialise` on every launch would add about three seconds to
start-up on BEAM. shen-scheme 0.50 does boot it, so StLib functions such as
`expt` are undefined here, and StLib's names (for example `g`) are not
protected as system functions.

`make shen-tests` copies the release's `tests/` directory to `test/shen` and
runs its `runme.shen` (143 tests).
