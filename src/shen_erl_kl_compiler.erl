%%%-------------------------------------------------------------------
%%% @author Sebastian Borrazas
%%% @copyright (C) 2018, Sebastian Borrazas
%%%-------------------------------------------------------------------
-module(shen_erl_kl_compiler).

%% API
-export([start_repl/0,
         boot/0,
         boot_shaken/1,
         run_shaken/1,
         files_kl/2,
         eval_kl/1,
         invoke/2,
         eval/1,
         load/1]).

%% kl_* modules are compiled from KLambda at build time and are absent during Dialyzer analysis
-dialyzer({nowarn_function, [load/1, eval/1, eval_kl/1, start_repl/0, load_funs/0]}).

%% Macros
%% Tarver's refreshed S42 kernel has no shen.initialise function.  Its
%% top-level initialisation forms must run in the order used by install.lsp.
%% The community launcher/features extensions remain compatible and are loaded
%% after the kernel proper, as in the other maintained ports.
-define(KL_MODS, ['kl_sys',
                  'kl_writer',
                  'kl_core',
                  'kl_reader',
                  'kl_declarations',
                  'kl_toplevel',
                  'kl_macros',
                  'kl_load',
                  'kl_prolog',
                  'kl_sequent',
                  'kl_track',
                  'kl_t-star',
                  'kl_yacc',
                  'kl_types',
                  'kl_extension-features',
                  'kl_extension-expand-dynamic',
                  'kl_extension-launcher']).

%% Types
-type opt() :: {output_dir, string()}.

-export_type([opt/0]).

%%%===================================================================
%%% API
%%%===================================================================

-spec files_kl([string()], [opt()]) -> ok | {error, binary()}.
files_kl(Filenames, Opts) ->
  case parse_files(Filenames, []) of
    {ok, FilesAsts} -> compile_kl(FilesAsts, Opts);
    {error, Reason} -> {error, Reason}
  end.

-spec eval_kl(term()) -> term().
eval_kl(KlCode) ->
  shen_erl_kl_codegen:eval(KlCode).

%% Runtime dispatch for Shen-defined functions.  Shen permits a function to be
%% redefined with a different arity, and a containing expression may have been
%% compiled before a nested (load ...) performs that redefinition.  Kernel and
%% primitive calls are statically bound by the code generator; mutable user
%% functions come through here so currying observes the live arity/MFA.
-spec invoke(atom(), [term()]) -> term().
invoke(Name, Args) ->
  case shen_erl_global_stores:get_mfa(Name) of
    {ok, {Mod, Fun, Arity}} -> invoke_mfa(Mod, Fun, Arity, Args);
    not_found -> erlang:error({undef, Name})
  end.

-spec boot() -> ok.
boot() ->
  load_funs().

%% Boot a Yggdrasil slice.  kernel.kl contains a synthesized
%% shen.initialise/0 holding the retained kernel top-level forms; user modules
%% keep their top-level program forms in kl_tle/0.
-spec boot_shaken([module()]) -> ok.
boot_shaken(Modules = [Kernel | _]) ->
  register_modules(Modules),
  Kernel:kl_tle(),
  invoke('shen.initialise', []),
  ok.

-spec run_shaken([module()]) -> ok.
run_shaken([_Kernel | Users]) ->
  [Mod:kl_tle() || Mod <- Users],
  ok.

-spec load(string()) -> ok.
load(Filename) ->
  kl_load:load({string, Filename}),
  ok.

-spec eval(string()) -> term().
eval(ShenCode) ->
  kl_sys:eval(shen_erl_kl_primitives:'hd'(kl_reader:'read-from-string'({string, ShenCode}))).

-spec start_repl() -> ok.
start_repl() ->
  shen_erl_global_stores:set_val('__shen_erl_exit_on_eof', true),
  kl_toplevel:'shen.shen'().

%%%===================================================================
%%% Internal functions
%%%===================================================================

load_funs() ->
  register_modules(?KL_MODS),
  [Mod:kl_tle() || Mod <- ?KL_MODS],
  %% The refreshed kernel cannot run the old feature extension initialiser: it
  %% refers to the removed shen.set-lambda-form-entry API.  Its stable public
  %% current/add operations only require this backing global.
  shen_erl_kl_primitives:set('shen.x.features.*features*', []),
  ok.

register_modules(Modules) ->
  [[shen_erl_global_stores:set_mfa(FunName, {Mod, FunName, Arity}) ||
     {FunName, Arity} <- Mod:module_info(exports),
     FunName =/= kl_tle, FunName =/= module_info] || Mod <- Modules],
  ok.

compile_kl([{Mod, Ast} | Rest], Opts) ->
  io:format(standard_error, "COMPILING ~p~n", [Mod]),
  case shen_erl_kl_codegen:compile(Mod, Ast, ok) of
    {ok, Mod, Bin} ->
      case write(Mod, Bin, Opts) of
        ok -> compile_kl(Rest, Opts);
        {error, Reason} -> {error, Reason}
      end;
    {error, Reason} -> {error, Reason}
  end;
compile_kl([], _Opts) ->
  ok.

parse_files([Filename | Rest], Acc) ->
  case parse_kl_file(Filename) of
    {ok, Ast} ->
      Mod = list_to_atom("kl_" ++ filename:basename(Filename, ".kl")),
      shen_erl_kl_codegen:load_defuns(Mod, Ast),
      parse_files(Rest, [{Mod, Ast} | Acc]);
    {error, Reason} -> {error, Reason}
  end;
parse_files([], Acc) -> {ok, Acc}.

invoke_mfa(Mod, Fun, Arity, Args) when length(Args) =:= Arity ->
  erlang:apply(Mod, Fun, Args);
invoke_mfa(Mod, Fun, Arity, Args) when length(Args) < Arity ->
  fun(Arg) -> invoke_mfa(Mod, Fun, Arity, Args ++ [Arg]) end;
invoke_mfa(Mod, Fun, Arity, Args) ->
  {StaticArgs, DynamicArgs} = lists:split(Arity, Args),
  invoke_result(erlang:apply(Mod, Fun, StaticArgs), DynamicArgs).

invoke_result(Result, []) -> Result;
invoke_result(Fun, [Arg | Rest]) when is_function(Fun, 1) ->
  invoke_result(Fun(Arg), Rest);
invoke_result(NotFun, _Args) ->
  erlang:error({badfun, NotFun}).

parse_kl_file(Filename) ->
  case file:open(Filename, [read]) of
    {ok, In} ->
      case io:request(In, {get_until, unicode, '', shen_erl_kl_scan, tokens, [1]}) of
        {ok, Tokens, _EndLine} ->
          shen_erl_kl_parse:parse_tree(Tokens);
        {error, Reason} -> {error, Reason}
      end;
    {error, Reason} -> {error, Reason}
  end.

write(Mod, BeamCode, Opts) ->
  {ok, CurrentDir} = file:get_cwd(),
  OutputDir = proplists:get_value(output_dir, Opts, CurrentDir),
  case file:write_file(OutputDir ++ "/" ++ atom_to_list(Mod) ++ ".beam", BeamCode) of
    ok -> ok;
    {error, Reason} -> {error, Reason}
  end.
