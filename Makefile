BASE_DIR = $(shell pwd)

SHENVERSION = 43.1

## The kernel: the community ShenOSKernel release from Shen-Language/shen-sources,
## used wholesale and pinned by checksum (see KERNEL.md).  Set
## SHEN_KERNEL_ARCHIVE=/path/to/ShenOSKernel-43.1.tar.gz to use a local copy.
KERNEL_DISTDIR = ShenOSKernel-$(SHENVERSION)
KERNEL_ARCHIVE = $(KERNEL_DISTDIR).tar.gz
KERNEL_URL = https://github.com/Shen-Language/shen-sources/releases/download/shen-$(SHENVERSION)/$(KERNEL_ARCHIVE)
KERNEL_SHA256 = 900eedef44f440af78f9395ed06e689ce1604546fc309f5bc7c8bc84cc651920

## Kernel modules compiled to BEAM.  stlib.kl (the precompiled standard
## library) is not booted.  The namespaces and type-annotations extensions are
## compiled but, like programmable pattern matching, are not booted.
KERNEL_KL = core declarations dict init load macros prolog reader sequent \
	sys t-star toplevel track types writer yacc \
	extension-expand-dynamic extension-features extension-launcher \
	extension-namespaces extension-programmable-pattern-matching \
	extension-type-annotations

INSTALL = install
INSTALL_DIR = $(INSTALL) -m755 -d
INSTALL_DATA = $(INSTALL) -m644
INSTALL_BIN = $(INSTALL) -m755

CSRCDIR = c_src

BINDIR = bin
EBINDIR = ebin
SRCDIR = src
INCDIR = include
KLSRCDIR = kl

CSRCS = $(notdir $(wildcard $(CSRCDIR)/*.c))
BINS = $(CSRCS:.c=)

ESRCS = $(notdir $(wildcard $(SRCDIR)/*.erl))
EBINS = $(ESRCS:.erl=.beam)

KL_SRCS = $(addsuffix .kl, $(KERNEL_KL))

ERLCFLAGS = -W1 +debug_info
ERLC = erlc

EXE ?= shen-erl

.PHONY: all
.DEFAULT: all
all: shen-kl

## Shen sources: ShenOSKernel, fetched and checksum-verified by
## scripts/fetch-kernel.sh (see KERNEL.md).
$(KERNEL_DISTDIR):
	KERNEL_URL='$(KERNEL_URL)' \
	KERNEL_ARCHIVE='$(KERNEL_ARCHIVE)' \
	KERNEL_SHA256='$(KERNEL_SHA256)' \
	DESTDIR='$(KERNEL_DISTDIR)' \
	SHEN_KERNEL_ARCHIVE='$(SHEN_KERNEL_ARCHIVE)' \
	sh scripts/fetch-kernel.sh

$(KLSRCDIR): $(KERNEL_DISTDIR)
	rm -rf $(KLSRCDIR)
	mkdir -p $(KLSRCDIR)
	cp $(addprefix $(KERNEL_DISTDIR)/klambda/, $(addsuffix .kl, $(KERNEL_KL))) $(KLSRCDIR)
	touch $(KLSRCDIR)

## Compile C files
$(BINDIR)/%: $(CSRCDIR)/%.c
	mkdir -p $(BINDIR)
	$(CC) -o $@ $^ -Wall -Wextra -pedantic $(CFLAGS)

## Compile .erl files
$(EBINDIR)/%.beam: $(SRCDIR)/%.erl
	@$(INSTALL_DIR) $(EBINDIR)
	$(ERLC) -I $(INCDIR) -o $(EBINDIR) $(ERLCFLAGS) $<

## Compile Erlang files using erlc
.PHONY: erlc-compile
erlc-compile: $(addprefix $(EBINDIR)/, $(EBINS)) $(addprefix $(BINDIR)/, $(BINS))

.PHONY: clean
clean:
	rm -rf $(EBINDIR)/*.beam $(BINDIR)/* erl_crash.dump test/shen test/logs

.PHONY: distclean
distclean: clean
	rm -rf $(KERNEL_DISTDIR) $(KERNEL_ARCHIVE) $(KERNEL_ARCHIVE).part
	rm -rf $(KLSRCDIR)
	rm -f $(SRCDIR)/shen_erl_kl_scan.erl $(SRCDIR)/shen_erl_kl_parse.erl
	rm -f .*.plt

## shen-erlang compile
$(EXE): erlc-compile

## Lexer & parser (generated from .xrl and .yrl)
$(SRCDIR)/shen_erl_kl_scan.erl: $(SRCDIR)/shen_erl_kl_scan.xrl
	erl -noshell -eval 'leex:file("src/shen_erl_kl_scan"), init:stop().'

$(SRCDIR)/shen_erl_kl_parse.erl: $(SRCDIR)/shen_erl_kl_parse.yrl
	erl -noshell -eval 'yecc:file("src/shen_erl_kl_parse"), init:stop().'

erlc-compile: $(SRCDIR)/shen_erl_kl_scan.erl $(SRCDIR)/shen_erl_kl_parse.erl
erlc-compile: $(EBINDIR)/shen_erl_kl_scan.beam $(EBINDIR)/shen_erl_kl_parse.beam

## Compile .kl files
.PHONY: shen-kl
shen-kl: $(EXE) $(KLSRCDIR)
	@$(INSTALL_DIR) $(EBINDIR)
	SHEN_ERL_ROOTDIR=$(BASE_DIR) $(BINDIR)/$(EXE) --kl $(addprefix $(KLSRCDIR)/, $(KL_SRCS)) --output-dir $(EBINDIR)

## Tests
test/shen: $(KERNEL_DISTDIR)
	mkdir -p test
	cp -R '$(KERNEL_DISTDIR)/tests' test/shen

.PHONY: shen-tests
shen-tests: shen-kl test/shen
	SHEN_ERL_ROOTDIR=$(BASE_DIR) $(BINDIR)/$(EXE) --script scripts/run-shen-tests.shen

ct: erlc-compile
	@$(INSTALL_DIR) test/logs
	erl -noshell -pa $(abspath $(EBINDIR)) -eval \
	  'Result = ct:run_test([{dir,"$(abspath test)"},{logdir,"$(abspath test/logs)"}]), io:format("CT_RESULT=~p~n", [Result]), case Result of {_Ok,0,_Skipped} -> halt(0); _ -> halt(1) end.'


################################################################################
## DOCKER
################################################################################

DOCKER_ERLANG_IMAGE = erlang:27.3

.PHONY: docker-test
docker-test:
	@docker run --rm \
							--volume "$(BASE_DIR)":/app \
							--volume "$(BASE_DIR)/Erlmakefile":/app/Makefile \
							--workdir /app \
							$(DOCKER_ERLANG_IMAGE) \
							/bin/bash -c "make tests"

.PHONY: docker-dialyze
docker-dialyze:
	@docker run --rm \
							--volume "$(BASE_DIR)":/app \
							--volume "$(BASE_DIR)/Erlmakefile":/app/Makefile \
							--workdir /app \
							$(DOCKER_ERLANG_IMAGE) \
							/bin/bash -c "make dialyze"
