%%%-------------------------------------------------------------------
%%% @doc Value conversion between Shen data and plain Erlang terms.
%%%
%%% Used by the erl.* interop functions and the json.* library.  This module
%%% is deliberately not one of the registered port modules, so its exports
%%% do not become Shen functions.
%%%
%%% Shen -> Erlang (to_erl/1):
%%%   string            -> UTF-8 binary
%%%   list              -> list (elements converted)
%%%   everything else   -> unchanged (numbers, symbols/atoms, booleans,
%%%                        Erlang tuples built with erl.tuple, pids, ...)
%%%
%%% Erlang -> Shen (to_shen/1):
%%%   UTF-8 binary      -> string
%%%   other binary      -> list of bytes
%%%   list              -> list (elements converted)
%%%   tuple             -> list of its (converted) elements
%%%   everything else   -> unchanged (numbers, atoms, pids, refs, maps, funs)
%%%
%%% Shen's own boxed values ({string, _}, absvectors and dictionaries) pass
%%% through to_shen/1 untouched, so they survive a round trip through Erlang
%%% (for example erl.send to self followed by erl.receive).
%%%-------------------------------------------------------------------
-module(shen_erl_interop).

-export([to_erl/1,
         to_shen/1,
         string_to_binary/1,
         binary_to_string/1]).

%%%===================================================================
%%% API
%%%===================================================================

-spec to_erl(term()) -> term().
to_erl({string, Chars}) ->
  string_to_binary({string, Chars});
to_erl([H | T]) ->
  [to_erl(H) | to_erl(T)];
to_erl(Other) ->
  Other.

-spec to_shen(term()) -> term().
to_shen(Bin) when is_binary(Bin) ->
  case unicode:characters_to_list(Bin, utf8) of
    Chars when is_list(Chars) -> {string, Chars};
    _ -> binary_to_list(Bin)
  end;
to_shen([H | T]) ->
  [to_shen(H) | to_shen(T)];
to_shen(Boxed = {string, Chars}) when is_list(Chars) ->
  Boxed;
to_shen(Boxed = {vector, Len, Tab}) when is_integer(Len), is_atom(Tab) ->
  Boxed;
to_shen(Boxed = {dict, Tab}) when is_atom(Tab) ->
  Boxed;
to_shen(Tuple) when is_tuple(Tuple) ->
  [to_shen(E) || E <- tuple_to_list(Tuple)];
to_shen(Other) ->
  Other.

%% Shen strings in this port hold either Unicode code points (string
%% literals, n->string) or raw bytes (read-file-as-string reads bytes).  A
%% string whose elements are all bytes forming valid UTF-8 is taken as bytes;
%% anything else is encoded from code points.  Both readings agree on ASCII.
-spec string_to_binary({string, [non_neg_integer()]}) -> binary().
string_to_binary({string, Chars}) ->
  Flat = lists:flatten(Chars),
  case lists:all(fun(C) -> C >= 0 andalso C =< 255 end, Flat) of
    true ->
      Bytes = list_to_binary(Flat),
      case unicode:characters_to_list(Bytes, utf8) of
        L when is_list(L) -> Bytes;
        _ -> unicode:characters_to_binary(Flat, unicode, utf8)
      end;
    false ->
      unicode:characters_to_binary(Flat, unicode, utf8)
  end.

-spec binary_to_string(binary()) -> {string, [non_neg_integer()]}.
binary_to_string(Bin) ->
  case unicode:characters_to_list(Bin, utf8) of
    Chars when is_list(Chars) -> {string, Chars};
    _ -> {string, binary_to_list(Bin)}
  end.
