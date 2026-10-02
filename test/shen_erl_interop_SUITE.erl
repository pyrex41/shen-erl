-module(shen_erl_interop_SUITE).

-export([suite/0,
         all/0,
         groups/0,
         init_per_group/2,
         end_per_group/2,
         init_per_testcase/2,
         end_per_testcase/2,
         t_to_erl/1,
         t_to_shen/1,
         t_string_bytes_vs_codepoints/1,
         t_erl_apply/1,
         t_erl_apply_errors/1,
         t_erl_send_receive/1,
         t_erl_receive_timeout/1,
         t_erl_tuple/1,
         t_shen_registered/1,
         t_shen_erl_apply/1,
         t_shen_partial_application/1,
         t_shen_send_receive/1,
         t_shen_trap_error/1]).

-include_lib("common_test/include/ct.hrl").

%%%===================================================================
%%% Common test
%%%===================================================================

groups() ->
  [{conversion, [], [t_to_erl,
                     t_to_shen,
                     t_string_bytes_vs_codepoints]},
   {erlang_api, [], [t_erl_apply,
                     t_erl_apply_errors,
                     t_erl_send_receive,
                     t_erl_receive_timeout,
                     t_erl_tuple]},
   %% Evaluates Shen source against a fully booted kernel.
   {shen, [], [t_shen_registered,
               t_shen_erl_apply,
               t_shen_partial_application,
               t_shen_send_receive,
               t_shen_trap_error]}].

suite() ->
  [{timetrap, {minutes, 2}}].

all() ->
  [{group, conversion}, {group, erlang_api}, {group, shen}].

init_per_group(_Group, Config) ->
  Config.

end_per_group(_Group, _Config) ->
  ok.

%% ETS stores are owned by the test case process, so each case boots its own.
init_per_testcase(Case, Config) ->
  shen_erl_global_stores:init(),
  case lists:prefix("t_shen_", atom_to_list(Case)) of
    true -> boot_kernel();
    false -> ok
  end,
  Config.

end_per_testcase(_Case, _Config) ->
  ok.

%%%===================================================================
%%% Conversion
%%%===================================================================

t_to_erl(_Config) ->
  <<"abc">> = shen_erl_interop:to_erl({string, "abc"}),
  [<<"a">>, 1, sym, [<<"b">>]] =
    shen_erl_interop:to_erl([{string, "a"}, 1, sym, [{string, "b"}]]),
  [a | b] = shen_erl_interop:to_erl([a | b]),
  true = shen_erl_interop:to_erl(true),
  1.5 = shen_erl_interop:to_erl(1.5).

t_to_shen(_Config) ->
  {string, "abc"} = shen_erl_interop:to_shen(<<"abc">>),
  [ok, {string, "x"}] = shen_erl_interop:to_shen({ok, <<"x">>}),
  [1, [2, {string, "y"}]] = shen_erl_interop:to_shen([1, {2, <<"y">>}]),
  %% Non-UTF-8 binaries come back as byte lists.
  [255, 0] = shen_erl_interop:to_shen(<<255, 0>>),
  %% Shen's own boxed values survive untouched.
  {string, "s"} = shen_erl_interop:to_shen({string, "s"}),
  {vector, 3, tab} = shen_erl_interop:to_shen({vector, 3, tab}),
  {dict, tab} = shen_erl_interop:to_shen({dict, tab}),
  Map = #{a => 1},
  Map = shen_erl_interop:to_shen(Map),
  Pid = self(),
  Pid = shen_erl_interop:to_shen(Pid).

t_string_bytes_vs_codepoints(_Config) ->
  Utf8 = <<"caf", 16#C3, 16#A9>>,
  %% Code points (string literals) and raw UTF-8 bytes (read-file-as-string)
  %% encode to the same binary.
  Utf8 = shen_erl_interop:string_to_binary({string, [$c, $a, $f, 16#E9]}),
  Utf8 = shen_erl_interop:string_to_binary({string, binary_to_list(Utf8)}),
  <<226, 130, 172>> = shen_erl_interop:string_to_binary({string, [16#20AC]}),
  {string, [$c, $a, $f, 16#E9]} = shen_erl_interop:binary_to_string(Utf8).

%%%===================================================================
%%% Erlang-level API
%%%===================================================================

t_erl_apply(_Config) ->
  {string, "ABC"} = shen_erl_kl_extensions:'erl.apply'(string, uppercase, [{string, "abc"}]),
  [3, 2, 1] = shen_erl_kl_extensions:'erl.apply'(lists, reverse, [[1, 2, 3]]),
  3 = shen_erl_kl_extensions:'erl.apply'(erlang, length, [[a, b, c]]),
  [error, enoent] =
    shen_erl_kl_extensions:'erl.apply'(file, read_file, [{string, "/nonexistent/shen-erl"}]).

t_erl_apply_errors(_Config) ->
  {simple_error, Msg} = catch_throw(fun() ->
    shen_erl_kl_extensions:'erl.apply'(erlang, binary_to_atom, [1])
  end),
  "erl.apply: erlang:binary_to_atom/1 raised error:badarg" = Msg,
  {simple_error, _} = catch_throw(fun() ->
    shen_erl_kl_extensions:'erl.apply'(no_such_module_xyz, f, [])
  end),
  {simple_error, _} = catch_throw(fun() ->
    shen_erl_kl_extensions:'erl.apply'({string, "lists"}, reverse, [[]])
  end).

t_erl_send_receive(_Config) ->
  Msg = [hello, {string, "world"}],
  Msg = shen_erl_kl_extensions:'erl.send'(self(), Msg),
  Msg = shen_erl_kl_extensions:'erl.receive'(1000),
  %% Erlang senders' binaries and tuples are converted on receipt.
  self() ! {reply, <<"hi">>},
  [reply, {string, "hi"}] = shen_erl_kl_extensions:'erl.receive'(infinity).

t_erl_receive_timeout(_Config) ->
  timeout = shen_erl_kl_extensions:'erl.receive'(0),
  timeout = shen_erl_kl_extensions:'erl.receive'(1.4),
  {simple_error, _} = catch_throw(fun() -> shen_erl_kl_extensions:'erl.receive'(-1) end).

t_erl_tuple(_Config) ->
  {ok, <<"x">>} = shen_erl_kl_extensions:'erl.tuple'([ok, {string, "x"}]),
  {} = shen_erl_kl_extensions:'erl.tuple'([]),
  {string, "{a,1}"} = shen_erl_kl_primitives:str({a, 1}).

%%%===================================================================
%%% Booted Shen
%%%===================================================================

t_shen_registered(_Config) ->
  3 = shen("(arity erl.apply)"),
  2 = shen("(arity erl.send)"),
  1 = shen("(arity erl.receive)"),
  1 = shen("(arity erl.tuple)"),
  true = is_function(shen("(fn erl.apply)")).

t_shen_erl_apply(_Config) ->
  {string, "ABC"} = shen("(erl.apply string uppercase [\"abc\"])"),
  [c, {string, "b"}, 1] = shen("(erl.apply lists reverse [[1 \"b\" c]])"),
  true = shen("(= [error enoent] (erl.apply file read_file [\"/nonexistent/shen-erl\"]))").

t_shen_partial_application(_Config) ->
  [{string, "X"}, {string, "Y"}] =
    shen("(map (erl.apply string uppercase) [[\"x\"] [\"y\"]])"),
  [{string, "P"}] = shen("(map (/. A ((fn erl.apply) string uppercase A)) [[\"p\"]])").

t_shen_send_receive(_Config) ->
  [hello, {string, "w"}] =
    shen("(do (erl.send (erl.apply erlang self []) [hello \"w\"]) (erl.receive 1000))"),
  timeout = shen("(erl.receive 0)").

t_shen_trap_error(_Config) ->
  {string, "erl.apply: erlang:binary_to_atom/1 raised error:badarg"} =
    shen("(trap-error (erl.apply erlang binary_to_atom [1]) (/. E (error-to-string E)))").

%%%===================================================================
%%% Helpers
%%%===================================================================

boot_kernel() ->
  shen_erl_kl_primitives:set('*stoutput*', standard_io),
  shen_erl_kl_primitives:set('*stinput*', standard_io),
  shen_erl_kl_compiler:boot(),
  {ok, Cwd} = file:get_cwd(),
  shen_erl_kl_primitives:set('*home-directory*', {string, Cwd}),
  ok.

shen(Source) ->
  shen_erl_kl_compiler:eval(Source).

catch_throw(Fun) ->
  try Fun() of
    Result -> ct:fail({expected_throw, Result})
  catch
    throw:Thrown -> Thrown
  end.
