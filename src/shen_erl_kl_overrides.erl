%%%-------------------------------------------------------------------
%%% @author Sebastian Borrazas
%%% @copyright (C) 2018, Sebastian Borrazas
%%%-------------------------------------------------------------------
-module(shen_erl_kl_overrides).

%% API
-export(['hash'/2,
         'pr'/2,
         'not'/1,
         'boolean?'/1,
         'integer?'/1,
         '@p'/2,
         'symbol?'/1,
         'shen.dict'/1,
         'shen.dict?'/1,
         'shen.dict-count'/1,
         'shen.dict->'/3,
         'shen.<-dict'/2,
         'shen.dict-rm'/2,
         'shen.dict-fold'/3,
         'shen.dict-keys'/1,
         'shen.dict-values'/1,
         'read-file-as-bytelist'/1,
         'shen.read-file-as-charlist'/1,
         'read-file-as-string'/1,
         'cd'/1]).

%%%===================================================================
%%% API
%%%===================================================================

%% *hush* suppresses terminal output, never writes to an explicitly opened
%% file stream.  This is the portable launcher/Yggdrasil contract used by the
%% maintained ports.
pr(String, standard_io) ->
  case shen_erl_global_stores:get_val('*hush*') of
    {ok, true} -> String;
    _ -> shen_erl_kl_primitives:'shen.write-string'(String, standard_io)
  end;
pr(String, Stream) ->
  shen_erl_kl_primitives:'shen.write-string'(String, Stream).

'symbol?'(Val) when is_atom(Val), Val =/= true, Val =/= false -> true;
'symbol?'(_Val) -> false.

%% Values that are = must hash equal, so integral floats hash as integers.
%% Like the kernel's hash, the result is in 1..Bound-1 (0 maps to 1).
hash(Val, Bound) ->
  case erlang:phash2(hash_key(Val), Bound) of
    0 -> 1;
    Hash -> Hash
  end.

hash_key(Val) when is_float(Val), Val == trunc(Val) -> trunc(Val);
hash_key([H | T]) -> [hash_key(H) | hash_key(T)];
hash_key(Val) -> Val.

'not'(Val) -> not Val.

'boolean?'(Val) -> is_boolean(Val).

%% Shen integrality, not the host representation: 4.0 is an integer.
'integer?'(Val) when is_integer(Val) -> true;
'integer?'(Val) when is_float(Val) -> Val == trunc(Val);
'integer?'(_Val) -> false.

'@p'(X, Y) ->
  Dict = shen_erl_global_stores:dict_new(),
  shen_erl_global_stores:dict_set(Dict, [{0, 'shen.tuple'},
                                         {1, X},
                                         {2, Y}]),
  {vector, 3, Dict}.

%% Dictionary overrides
'shen.dict'(_Size) ->
  {dict, shen_erl_global_stores:dict_new()}.

'shen.dict?'({dict, _Dict}) -> true;
'shen.dict?'(_Val) -> false.

'shen.dict-count'({dict, Dict}) ->
  shen_erl_global_stores:dict_count(Dict).

'shen.dict->'({dict, Dict}, Key, Val) ->
  shen_erl_global_stores:dict_set(Dict, Key, Val),
  Val.

'shen.<-dict'({dict, Dict}, Key) ->
  case shen_erl_global_stores:dict_get(Dict, Key) of
    {ok, Val} -> Val;
    not_found ->
      {string, KeyStr} = shen_erl_kl_primitives:str(Key),
      shen_erl_kl_primitives:'simple-error'({string, "`" ++ KeyStr ++ "` not found."})
  end.

'shen.dict-rm'({dict, Dict}, Key) ->
  shen_erl_global_stores:dict_rm(Dict, Key),
  Key.

%% (shen.dict-fold F Dict Init), with F a curried Key -> Value -> Acc
%% function, as in ShenOSKernel's dict.kl.
'shen.dict-fold'(F, {dict, Dict}, Init) ->
  shen_erl_global_stores:dict_fold(Dict,
                                   fun({Key, Val}, Acc) -> ((F(Key))(Val))(Acc) end,
                                   Init).

'shen.dict-keys'({dict, Dict}) ->
  shen_erl_global_stores:dict_keys(Dict).

'shen.dict-values'({dict, Dict}) ->
  shen_erl_global_stores:dict_values(Dict).

%% Files
'read-file-as-bytelist'({string, Filename}) ->
  {ok, Binary} = file:read_file(Filename),
  binary_to_list(Binary).

'shen.read-file-as-charlist'({string, Filename}) ->
  {ok, Binary} = file:read_file(Filename),
  binary_to_list(Binary).

'read-file-as-string'({string, Filename}) ->
  {ok, Binary} = file:read_file(Filename),
  {string, binary_to_list(Binary)}.

'cd'({string, ""}) ->
  case shen_erl_kl_primitives:value('*home-directory*') of
    {string, ""} -> ok;
    Home -> 'cd'(Home)
  end;
'cd'(DirStr = {string, Dir}) ->
  shen_erl_kl_primitives:set('*home-directory*', DirStr),
  file:set_cwd(Dir).
