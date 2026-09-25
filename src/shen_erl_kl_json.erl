%%%-------------------------------------------------------------------
%%% @doc JSON for Shen, built on OTP's json module (OTP 27+).
%%%
%%% Representation of JSON values as Shen data:
%%%
%%%   object   [json.object [Key | Value] ...]   keys are strings, in
%%%                                            document order
%%%   array    [Value ...]
%%%   string   string
%%%   number   number (integers stay integers)
%%%   true     true
%%%   false    false
%%%   null     the symbol null
%%%
%%% The json.object tag keeps {} distinct from [], and it keeps an object
%%% distinct from an array of pairs.  json.stringify also accepts symbols as
%%% object keys, and it encodes symbols other than null, true and false as
%%% strings.
%%%
%%% js.get and js.truthy? are compatibility shims.  They let specs written for
%%% ShenScript's JSON interop run unchanged.
%%%-------------------------------------------------------------------
-module(shen_erl_kl_json).

-export(['json.parse'/1,
         'json.stringify'/1,
         'json.get'/2,
         'json.object?'/1,
         'js.get'/2,
         'js.truthy?'/1]).

-define(OBJECT_TAG, 'json.object').

%%%===================================================================
%%% API
%%%===================================================================

%% (json.parse String) -> Shen data, as described above.
'json.parse'({string, _} = Str) ->
  Bin = shen_erl_interop:string_to_binary(Str),
  try decode(Bin) of
    Value -> Value
  catch
    error:Reason -> error_msg("json.parse: invalid JSON (~0p)", [Reason])
  end;
'json.parse'(Other) ->
  error_msg("json.parse: expected a string, got ~0p", [Other]).

%% (json.stringify Value) -> compact JSON string.
'json.stringify'(Value) ->
  try iolist_to_binary(json:encode(Value, fun encode/2)) of
    Bin -> shen_erl_interop:binary_to_string(Bin)
  catch
    throw:{json_unencodable, Bad} ->
      error_msg("json.stringify: cannot encode ~0p", [Bad])
  end.

%% (json.get Object Key) -> the value under Key (a string or symbol).
%% (json.get Array N)    -> the Nth element, counting from 0.
%% A missing key or index is an error.
'json.get'(Container, Key) ->
  case lookup(Container, Key) of
    {ok, Value} -> Value;
    missing -> error_msg("json.get: no ~0p in ~0p", [key_display(Key), Container])
  end.

'json.object?'([?OBJECT_TAG | Pairs]) when is_list(Pairs) -> true;
'json.object?'(_) -> false.

%% ShenScript compatibility: (js.get Obj Key) returns the symbol undefined
%% for a missing key or index, like JavaScript property access.
'js.get'(Container, Key) ->
  case lookup(Container, Key) of
    {ok, Value} -> Value;
    missing -> undefined
  end.

%% ShenScript compatibility: JavaScript truthiness.  false, null,
%% undefined, 0 and "" are falsy.  Everything else is truthy, including
%% empty arrays and objects.
'js.truthy?'(false) -> false;
'js.truthy?'(null) -> false;
'js.truthy?'(undefined) -> false;
'js.truthy?'({string, []}) -> false;
'js.truthy?'(N) when is_number(N) -> N /= 0;
'js.truthy?'(_) -> true.

%%%===================================================================
%%% Internal functions
%%%===================================================================

decode(Bin) ->
  Decoders = #{object_start => fun(_ParentAcc) -> [] end,
               object_push => fun(Key, Value, Acc) -> [[Key | Value] | Acc] end,
               object_finish => fun(Acc, ParentAcc) ->
                                    {[?OBJECT_TAG | lists:reverse(Acc)], ParentAcc}
                                end,
               string => fun shen_erl_interop:binary_to_string/1,
               null => null},
  case json:decode(Bin, ok, Decoders) of
    {Value, ok, Rest} ->
      case string:trim(Rest, leading) of
        <<>> -> Value;
        _ -> erlang:error(trailing_data)
      end
  end.

encode([?OBJECT_TAG | Pairs], Encode) when is_list(Pairs) ->
  json:encode_key_value_list([{object_key(Pair), pair_value(Pair)} || Pair <- Pairs],
                             Encode);
encode(List, Encode) when is_list(List) ->
  json:encode_list(List, Encode);
encode({string, _} = Str, _Encode) ->
  json:encode_binary(shen_erl_interop:string_to_binary(Str));
encode(Bin, _Encode) when is_binary(Bin) ->
  %% Object keys (already converted) and binaries obtained through erl.apply.
  json:encode_binary(Bin);
encode(Bool, _Encode) when is_boolean(Bool) ->
  json:encode_atom(Bool, fun json:encode_value/2);
encode(null, _Encode) ->
  <<"null">>;
encode(Sym, _Encode) when is_atom(Sym) ->
  json:encode_binary(atom_to_binary(Sym, utf8));
encode(Int, _Encode) when is_integer(Int) ->
  json:encode_integer(Int);
encode(Float, _Encode) when is_float(Float) ->
  json:encode_float(Float);
encode(Other, _Encode) ->
  throw({json_unencodable, Other}).

object_key([{string, _} = Key | _]) -> shen_erl_interop:string_to_binary(Key);
object_key([Key | _]) when is_atom(Key) -> atom_to_binary(Key, utf8);
object_key(Other) -> throw({json_unencodable, Other}).

pair_value([_Key | Value]) -> Value.

lookup([?OBJECT_TAG | Pairs], Key) when is_list(Pairs) ->
  case key_binary(Key) of
    undefined -> missing;
    KeyBin -> find_pair(Pairs, KeyBin)
  end;
lookup(List, Index) when is_list(List), is_integer(Index), Index >= 0 ->
  try lists:nth(Index + 1, List) of
    Value -> {ok, Value}
  catch
    error:_ -> missing
  end;
lookup(_Container, _Key) ->
  missing.

find_pair([[K | V] | Rest], KeyBin) ->
  case key_binary(K) of
    KeyBin -> {ok, V};
    _ -> find_pair(Rest, KeyBin)
  end;
find_pair(_, _KeyBin) ->
  missing.

key_binary({string, _} = Key) -> shen_erl_interop:string_to_binary(Key);
key_binary(Key) when is_atom(Key) -> atom_to_binary(Key, utf8);
key_binary(_Key) -> undefined.

key_display({string, Chars}) -> lists:flatten(Chars);
key_display(Key) -> Key.

error_msg(Fmt, Args) ->
  shen_erl_kl_primitives:'simple-error'({string, io_lib:format(Fmt, Args)}).
