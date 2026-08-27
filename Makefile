BASE_DIR = $(shell pwd)

SHENVERSION = 42.0
SHEN_REFRESH = 20260825
SHEN_ARCHIVE = S$(SHENVERSION)-$(SHEN_REFRESH).zip
SHEN_ARCHIVE_URL = https://www.shenlanguage.org/Download/S42.zip
SHEN_ARCHIVE_SHA256 = 30abdc7e5a1e27b7a20109c1ed141e4712885e31f24d9710d16415fbbd4dfb23
SHEN_DISTDIR = S42

COMMUNITY_ARCHIVE = ShenOSKernel-$(SHENVERSION).tar.gz
COMMUNITY_ARCHIVE_URL = https://github.com/Shen-Language/shen-sources/releases/download/shen-$(SHENVERSION)/$(COMMUNITY_ARCHIVE)
COMMUNITY_ARCHIVE_SHA256 = 32e86f58a1f6bbc111712a777a04a592c474e5cd05c2db7be0125f25ba8f8e35
COMMUNITY_DISTDIR = ShenOSKernel-$(SHENVERSION)

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

KL_SRCS = $(notdir $(wildcard $(KLSRCDIR)/*.kl))

ERLCFLAGS = -W1 +debug_info
ERLC = erlc

EXE ?= shen-erl

.PHONY: all
.DEFAULT: all
all: shen-kl

## Shen sources.  The kernel proper is Mark Tarver's refreshed S42 upload;
## the portable launcher/features extensions and certification tests come from
## the community ShenOSKernel 42.0 release, matching the other maintained ports.
$(SHEN_ARCHIVE):
	curl -fL '$(SHEN_ARCHIVE_URL)' -o $@
	printf '%s  %s\n' '$(SHEN_ARCHIVE_SHA256)' '$@' | shasum -a 256 -c

$(SHEN_DISTDIR): $(SHEN_ARCHIVE)
	unzip -qo $(SHEN_ARCHIVE)
	touch $(SHEN_DISTDIR)

$(COMMUNITY_ARCHIVE):
	curl -fL '$(COMMUNITY_ARCHIVE_URL)' -o $@
	printf '%s  %s\n' '$(COMMUNITY_ARCHIVE_SHA256)' '$@' | shasum -a 256 -c

$(COMMUNITY_DISTDIR): $(COMMUNITY_ARCHIVE)
	tar xzf $(COMMUNITY_ARCHIVE)
	touch $(COMMUNITY_DISTDIR)

$(KLSRCDIR): $(SHEN_DISTDIR) $(COMMUNITY_DISTDIR)
	mkdir -p $(KLSRCDIR)
	cp $(SHEN_DISTDIR)/KLambda/*.kl $(KLSRCDIR)
	cp $(COMMUNITY_DISTDIR)/klambda/extension-*.kl $(KLSRCDIR)
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
	rm -rf $(SHEN_DISTDIR) $(SHEN_ARCHIVE)
	rm -rf $(COMMUNITY_DISTDIR) $(COMMUNITY_ARCHIVE)
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
test/shen: $(SHEN_DISTDIR)
	mkdir -p test
	cp -R '$(SHEN_DISTDIR)/Test Programs' test/shen

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
