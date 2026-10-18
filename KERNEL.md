# Kernel provenance

`shen-erl` targets Shen **43.1**: the community **ShenOSKernel 43.1** release
from [`Shen-Language/shen-sources`](https://github.com/Shen-Language/shen-sources),
used wholesale and unmodified.

## Where the build gets it

`scripts/fetch-kernel.sh` (driven by the `Makefile`) downloads the release
asset and verifies its checksum before unpacking anything:

- Release: tag `shen-43.1`, commit `715824a52b55e9c81a9501df8548ff3edd8411f5`
- Asset:
  `https://github.com/Shen-Language/shen-sources/releases/download/shen-43.1/ShenOSKernel-43.1.tar.gz`
- SHA-256: `900eedef44f440af78f9395ed06e689ce1604546fc309f5bc7c8bc84cc651920`

To build offline, point `SHEN_KERNEL_ARCHIVE` at a local copy of the same
tarball:

```sh
SHEN_KERNEL_ARCHIVE=/path/to/ShenOSKernel-43.1.tar.gz make
```

The local archive must match the same SHA-256. If the download or the local
archive fails the checksum, the build stops.

## Lineage

Until this release `shen-erl` booted ShenOSKernel 42.2. This port adopts the
community ShenOSKernel 43.1 release wholesale.

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
- Public 43.1 character stream functions are exported with callable metadata.
  This port remains byte-oriented, so `char-stream?` returns `false` and the
  public character operations report a catchable unsupported-stream error;
  `read-byte` and `write-byte` retain the port's existing behavior.
- The REPL entry point is `shen.repl`. Standard input returns -1 at EOF, so
  a final line without a trailing newline is still read.

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
runs its `runme.shen`.
