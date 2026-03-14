-module(shen_erl_kl_overrides_SUITE).

-export([suite/0,
         all/0,
         groups/0,
         init_per_suite/1,
         end_per_suite/1,
         init_per_testcase/2,
         end_per_testcase/2,
         t_dict_missing_key/1,
         t_cd_empty_string/1]).

-include_lib("common_test/include/ct.hrl").

%%%===================================================================
%%% Common test
%%%===================================================================

groups() ->
  [{overrides,
    [],
    [t_dict_missing_key,
     t_cd_empty_string]}].

suite() ->
  [{timetrap, {minutes, 1}}].

all() ->
  [{group, overrides}].

init_per_suite(Config) ->
  Config.

end_per_suite(_Config) ->
  ok.

init_per_testcase(_Case, Config) ->
  shen_erl_global_stores:init(),
  Config.

end_per_testcase(_Case, _Config) ->
  ok.

%%%===================================================================
%%% Test cases
%%%===================================================================

%% 'shen.<-dict' must throw a simple-error (not crash with undef) when
%% the key is absent.  Before the fix, line 69-70 of shen_erl_kl_overrides
%% called the non-existent module shen_erl_primitives instead of
%% shen_erl_kl_primitives, causing an undef crash.
t_dict_missing_key(_Config) ->
  {dict, Dict} = shen_erl_kl_overrides:'shen.dict'(10),
  try
    shen_erl_kl_overrides:'shen.<-dict'({dict, Dict}, some_key),
    ct:fail(expected_throw)
  catch
    throw:{simple_error, _Msg} -> ok
  end.

%% 'cd'({string, ""}) must delegate to the stored *home-directory* value
%% (not crash with undef).  Before the fix, line 100 of shen_erl_kl_overrides
%% called shen_erl_kl_primitives:get/1, which does not exist; the correct
%% function is shen_erl_kl_primitives:'value'/1.
t_cd_empty_string(_Config) ->
  {ok, Cwd} = file:get_cwd(),
  shen_erl_kl_primitives:set('*home-directory*', {string, Cwd}),
  ok = shen_erl_kl_overrides:'cd'({string, ""}).
