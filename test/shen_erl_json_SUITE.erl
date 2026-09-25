-module(shen_erl_json_SUITE).

-export([suite/0,
         all/0,
         groups/0,
         init_per_testcase/2,
         end_per_testcase/2,
         t_parse_scalars/1,
         t_parse_structures/1,
         t_parse_unicode/1,
         t_parse_errors/1,
         t_stringify/1,
         t_stringify_errors/1,
         t_round_trip/1,
         t_json_get/1,
         t_js_get/1,
         t_js_truthy/1,
         t_shen_registered/1,
         t_shen_shenscript_style/1]).

-include_lib("common_test/include/ct.hrl").

-define(J, shen_erl_kl_json).

%%%===================================================================
%%% Common test
%%%===================================================================

groups() ->
  [{json, [], [t_parse_scalars,
               t_parse_structures,
               t_parse_unicode,
               t_parse_errors,
               t_stringify,
               t_stringify_errors,
               t_round_trip,
               t_json_get,
               t_js_get,
               t_js_truthy]},
   {shen, [], [t_shen_registered,
               t_shen_shenscript_style]}].

suite() ->
  [{timetrap, {minutes, 2}}].

all() ->
  [{group, json}, {group, shen}].

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
%%% Test cases
%%%===================================================================

t_parse_scalars(_Config) ->
  1 = parse("1"),
  -2.5 = parse("-2.5"),
  true = parse("true"),
  false = parse("false"),
  null = parse("null"),
  {string, "hi"} = parse("\"hi\""),
  {string, "a\"b\n"} = parse("\"a\\\"b\\n\""),
  42 = parse("  42 \n").

t_parse_structures(_Config) ->
  [] = parse("[]"),
  ['json.object'] = parse("{}"),
  [1, {string, "x"}, [true, null]] = parse("[1, \"x\", [true, null]]"),
  ['json.object',
   [{string, "b"} | 1],
   [{string, "a"} | ['json.object', [{string, "c"} | [1, 2]]]]] =
    parse("{\"b\": 1, \"a\": {\"c\": [1, 2]}}").

t_parse_unicode(_Config) ->
  %% Code-point strings and raw UTF-8 bytes (read-file-as-string) both work.
  {string, [16#E9, 16#20AC]} = ?J:'json.parse'({string, "\"" ++ [16#E9, 16#20AC] ++ "\""}),
  {string, [16#E9]} = ?J:'json.parse'({string, binary_to_list(<<"\"", 16#C3, 16#A9, "\"">>)}),
  {string, [16#E9]} = parse("\"\\u00e9\"").

t_parse_errors(_Config) ->
  "json.parse: invalid JSON" ++ _ = error_of(fun() -> parse("{bad") end),
  "json.parse: invalid JSON" ++ _ = error_of(fun() -> parse("") end),
  "json.parse: invalid JSON (trailing_data)" = error_of(fun() -> parse("1 2") end),
  "json.parse: expected a string" ++ _ = error_of(fun() -> ?J:'json.parse'(12) end).

t_stringify(_Config) ->
  "null" = stringify(null),
  "true" = stringify(true),
  "3" = stringify(3),
  "1.5" = stringify(1.5),
  "\"a\\\"b\"" = stringify({string, "a\"b"}),
  "\"sym\"" = stringify(sym),
  "[]" = stringify([]),
  "{}" = stringify(['json.object']),
  "[1,\"x\",[null]]" = stringify([1, {string, "x"}, [null]]),
  "{\"k\":[1,2],\"s\":\"v\"}" =
    stringify(['json.object', [{string, "k"}, 1, 2], [s | {string, "v"}]]),
  "\"" ++ [16#E9] ++ "\"" = stringify({string, [16#E9]}).

t_stringify_errors(_Config) ->
  "json.stringify: cannot encode" ++ _ = error_of(fun() -> stringify(self()) end),
  "json.stringify: cannot encode" ++ _ =
    error_of(fun() -> stringify(['json.object', [1 | 2]]) end).

t_round_trip(_Config) ->
  Doc = "{\"caseId\":\"x\",\"n\":[1,2.5,-3],\"o\":{\"t\":true,\"f\":false,\"z\":null},\"e\":{},\"a\":[]}",
  Doc = stringify(parse(Doc)).

t_json_get(_Config) ->
  Obj = parse("{\"a\": 1, \"b\": [10, 20]}"),
  1 = ?J:'json.get'(Obj, {string, "a"}),
  1 = ?J:'json.get'(Obj, a),
  20 = ?J:'json.get'(?J:'json.get'(Obj, {string, "b"}), 1),
  "json.get: no" ++ _ = error_of(fun() -> ?J:'json.get'(Obj, {string, "zz"}) end),
  "json.get: no" ++ _ = error_of(fun() -> ?J:'json.get'([1], 5) end),
  true = ?J:'json.object?'(Obj),
  false = ?J:'json.object?'([1, 2]).

t_js_get(_Config) ->
  Obj = parse("{\"a\": {\"b\": false}, \"l\": [7]}"),
  false = ?J:'js.get'(?J:'js.get'(Obj, {string, "a"}), {string, "b"}),
  7 = ?J:'js.get'(?J:'js.get'(Obj, {string, "l"}), 0),
  undefined = ?J:'js.get'(Obj, {string, "missing"}),
  undefined = ?J:'js.get'(?J:'js.get'(Obj, {string, "l"}), 3),
  undefined = ?J:'js.get'(42, {string, "x"}).

t_js_truthy(_Config) ->
  [false, false, false, false, false, false] =
    [?J:'js.truthy?'(V) || V <- [false, null, undefined, 0, 0.0, {string, ""}]],
  [true, true, true, true, true] =
    [?J:'js.truthy?'(V) || V <- [true, 1, {string, "0"}, [], ['json.object']]].

t_shen_registered(_Config) ->
  1 = shen("(arity json.parse)"),
  1 = shen("(arity json.stringify)"),
  2 = shen("(arity json.get)"),
  2 = shen("(arity js.get)"),
  1 = shen("(arity js.truthy?)"),
  [true, false] = shen("(map (fn js.truthy?) [1 0])").

%% The pattern used by specs written against ShenScript.
t_shen_shenscript_style(Config) ->
  File = filename:join(?config(priv_dir, Config), "spec.json"),
  ok = file:write_file(File, <<"{\"caseId\": \"c-1\", \"artifact\": "
                               "{\"class\": \"O-5\", \"accepted\": false}}">>),
  shen_erl_kl_primitives:set('*json-file*', {string, File}),
  true = shen("(let Spec (json.parse (read-file-as-string (value *json-file*)))"
              "  (let Art (js.get Spec \"artifact\")"
              "    (and (= (js.get Spec \"caseId\") \"c-1\")"
              "         (and (= (js.get Art \"class\") \"O-5\")"
              "              (not (js.truthy? (js.get Art \"accepted\")))))))"),
  {string, "{\"caseId\":\"c-1\"}"} =
    shen("(json.stringify [json.object [\"caseId\" | \"c-1\"]])").

%%%===================================================================
%%% Helpers
%%%===================================================================

parse(Str) ->
  ?J:'json.parse'({string, Str}).

stringify(Value) ->
  {string, Str} = ?J:'json.stringify'(Value),
  Str.

error_of(Fun) ->
  try Fun() of
    Result -> ct:fail({expected_error, Result})
  catch
    throw:{simple_error, Msg} -> Msg
  end.

boot_kernel() ->
  shen_erl_kl_primitives:set('*stoutput*', standard_io),
  shen_erl_kl_primitives:set('*stinput*', standard_io),
  shen_erl_kl_compiler:boot(),
  {ok, Cwd} = file:get_cwd(),
  shen_erl_kl_primitives:set('*home-directory*', {string, Cwd}),
  ok.

shen(Source) ->
  shen_erl_kl_compiler:eval(Source).
