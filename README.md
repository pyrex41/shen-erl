# shen-erl

`shen-erl` is an Erlang/BEAM implementation of Shen. It tracks Shen 42.0 and
boots Mark Tarver's refreshed S42 kernel (the 2026-08-25 upload), together
with the portable launcher and feature extensions shared by the other
maintained Shen ports. See [KERNEL.md](KERNEL.md) for exact provenance.

The project began as a fork of Sebastian Borrazas's original Erlang port and
retains that work as its foundation. This repository independently maintains
the current runtime, compiler integration, launcher, and Shen compatibility.

## Building

Building requires Erlang/OTP 27 or newer, a C compiler, `curl`, `unzip`, `tar`,
and `shasum`:

```sh
make
```

The build downloads checksum-pinned kernel archives, compiles the KLambda
modules to BEAM, and writes `bin/shen-erl`. The launcher locates its `ebin`
directory automatically; `SHEN_ERL_ROOTDIR` remains available as an override.

## Running

The launcher follows the standard Shen command line shared by the maintained
ports:

```sh
bin/shen-erl --version
bin/shen-erl eval -e '(+ 2 3)'
bin/shen-erl script program.shen
bin/shen-erl                 # REPL; EOF exits cleanly
```

Run `bin/shen-erl --help` for the complete launcher help.

## Erlang tests

Erlang tests can be run locally with `make ct`, or through Docker:

```sh
make docker-test
# also run dialyzer
make docker-dialyze
```

## Shen tests

```sh
make shen-tests
```

This runs the official ShenOSKernel 42.0 certification suite.
## Optional Nix environment

Nix is optional; the normal shen-erl build and launcher commands continue to work
with tools installed by any method. For a pinned development toolchain:

```sh
nix develop
```

The flake also exports `packages.toolchain` for composition by
[Bifrost](https://github.com/pyrex41/bifrost):

```sh
nix shell .#toolchain
```

If direnv is installed, `direnv allow` opts this checkout into the same dev
shell automatically. Nothing activates until that explicit authorization, and
Nix is never required at runtime.
