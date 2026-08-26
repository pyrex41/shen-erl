%%%-------------------------------------------------------------------
%%% @author Sebastian Borrazas
%%% @copyright (C) 2018, Sebastian Borrazas
%%%-------------------------------------------------------------------
-module(shen_erl_init).

%% API
-export([start/0]).

-define(OK_STATUS, 0).
-define(ERROR_STATUS, 1).

%%%===================================================================
%%% API
%%%===================================================================

start() ->
  init_stores(),
  Args = init:get_plain_arguments(),
  case Args of
    ["--kl" | CompileArgs] ->
      {Filenames, Opts} = parse_opts(CompileArgs),
      io:format(standard_error, "shen-erl: compiling ~p with opts ~p~n", [Filenames, Opts]),
      case shen_erl_kl_compiler:files_kl(Filenames, Opts) of
        ok ->
          io:format("Compiled successfully.~n", []),
          init:stop(?OK_STATUS);
        {error, Reason} ->
          io:format(standard_error, "Error ocurred: ~s~n", [Reason]),
          init:stop(?ERROR_STATUS)
      end;
    ["--shaken" | ModuleNames] when ModuleNames =/= [] ->
      Modules = [list_to_atom("kl_" ++ Name) || Name <- ModuleNames],
      shen_erl_kl_compiler:boot_shaken(Modules),
      init_platform(),
      shen_erl_kl_compiler:run_shaken(Modules),
      init:stop(?OK_STATUS);
    _ ->
      shen_erl_kl_compiler:boot(),
      init_platform(),
      run(Args)
  end.

%%%===================================================================
%%% Internal functions
%%%===================================================================

init_stores() ->
  shen_erl_global_stores:init(),
  shen_erl_kl_primitives:set('*stoutput*', standard_io),
  shen_erl_kl_primitives:set('*stinput*', standard_io).

init_platform() ->
  {ok, Cwd} = file:get_cwd(),
  shen_erl_kl_primitives:set('*home-directory*', {string, Cwd}),
  shen_erl_kl_primitives:set('*language*', {string, "Erlang"}),
  shen_erl_kl_primitives:set('*implementation*', {string, "Erlang OTP " ++ erlang:system_info(otp_release)}),
  shen_erl_kl_primitives:set('*os*', {string, "BEAM " ++ erlang:system_info(otp_release)}),
  case proplists:lookup(shen_erl, application:which_applications()) of
    {shen_erl, _Desc, Version} -> shen_erl_kl_primitives:set('*release*', {string, Version});
    none -> shen_erl_kl_primitives:set('*release*', {string, "0.1.0"})
  end,
  shen_erl_kl_primitives:set('*port*', {string, "shen-erl"}),
  shen_erl_kl_primitives:set('*porters*', {string, "Sebastian Borrazas and contributors"}).

run([]) ->
  shen_erl_kl_compiler:start_repl(),
  init:stop(?OK_STATUS);
run(["--eval", Code | _Args]) ->
  %% Compatibility with the dormant port's original command line.
  'kl_extension-launcher':'shen.x.launcher.main'([{string, "shen-erl"},
                                                  {string, "eval"},
                                                  {string, "-e"},
                                                  {string, Code}]),
  init:stop(?OK_STATUS);
run(["--script", Filename | _Args]) ->
  %% Compatibility with the dormant port's original command line.
  'kl_extension-launcher':'shen.x.launcher.main'([{string, "shen-erl"},
                                                  {string, "script"},
                                                  {string, Filename}]),
  init:stop(?OK_STATUS);
run(Args) ->
  ShenArgs = [{string, Arg} || Arg <- ["shen-erl" | Args]],
  'kl_extension-launcher':'shen.x.launcher.main'(ShenArgs),
  init:stop(?OK_STATUS).

parse_opts(Args) ->
  parse_opts(Args, {[], []}).

parse_opts(["--output-dir", OutputDir | Rest], {Files, Opts}) ->
  parse_opts(Rest, {Files, [{output_dir, OutputDir} | Opts]});
parse_opts([Filename | Rest], {Files, Opts}) ->
  parse_opts(Rest, {[Filename | Files], Opts});
parse_opts([], {Files, Opts}) ->
  {lists:reverse(Files), Opts}.
