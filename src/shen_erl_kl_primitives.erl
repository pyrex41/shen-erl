%%%-------------------------------------------------------------------
%%% @author Sebastian Borrazas
%%% @copyright (C) 2018, Sebastian Borrazas
%%%-------------------------------------------------------------------
-module(shen_erl_kl_primitives).

%% kl_extension-factorise-defun is compiled from KLambda at build time and absent during Dialyzer analysis
-dialyzer({nowarn_function, ['eval-kl'/1]}).

%% API
-export(['+'/2,
         '-'/2,
         '*'/2,
         '/'/2,
         'and'/2,
         'or'/2,
         '>'/2,
         '<'/2,
         '>='/2,
         '<='/2,
         'if'/3,
         'simple-error'/1,
         'error-to-string'/1,
         'intern'/1,
         'set'/2,
         'value'/1,
         'number?'/1,
         'string?'/1,
         'pos'/2,
         'tlstr'/1,
         'str'/1,
         'cn'/2,
         'string->n'/1,
         'n->string'/1,
         'absvector'/1,
         'address->'/3,
         '<-address'/2,
         'absvector?'/1,
         'cons?'/1,
         'cons'/2,
         'list'/1,
         'do'/2,
         'hd'/1,
         'tl'/1,
         'write-byte'/2,
         'read-byte'/1,
         'open'/2,
         'close'/1,
         '='/2,
         'eval-kl'/1,
         'get-time'/1,
         'type'/2,
         'shen.char-stinput?'/1,
         'shen.char-stoutput?'/1,
         'shen.read-unit-string'/1,
         'shen.write-string'/2]).

%%%===================================================================
%%% API
%%%===================================================================

%% +
'+'(A, B) -> A + B.

%% -
'-'(A, B) -> A - B.

%% *
'*'(A, B) -> A * B.

%% /
'/'(A, B) when is_integer(A), is_integer(B), B =/= 0, A rem B =:= 0 -> A div B;
'/'(_A, 0) -> 'simple-error'({string, "divide by zero"});
'/'(_A, 0.0) -> 'simple-error'({string, "divide by zero"});
'/'(A, B) -> A / B.

%% and
'and'(A, B) -> A and B.

%% or
'or'(A, B) -> A or B.

%% >
'>'(A, B) -> A > B.

%% <
'<'(A, B) -> A < B.

%% >=
'>='(A, B) -> A >= B.

%% <=
'<='(A, B) -> A =< B.

%% if
'if'(true, TrueVal, _FalseVal) -> TrueVal;
'if'(false, _TrueVal, FalseVal) -> FalseVal.

%% simple-error
'simple-error'({string, ErrorMsg}) -> throw({simple_error, lists:flatten(ErrorMsg)}).

%% error-to-string
'error-to-string'({simple_error, ErrorMsg}) ->
  {string, ErrorMsg};
'error-to-string'({throw, {simple_error, ErrorMsg}}) ->
  {string, ErrorMsg};
'error-to-string'({Class, Body}) ->
  {string, lists:flatten(io_lib:format("~p:~p", [Class, Body]))}.

%% intern
intern({string, SymbolStr}) -> list_to_atom(SymbolStr).

%% set
set(Name, Val) when is_atom(Name) ->
  shen_erl_global_stores:set_val(Name, Val),
  Val.

%% value
value(Key) when is_atom(Key) ->
  case shen_erl_global_stores:get_val(Key) of
    {ok, Val} -> Val;
    not_found -> 'simple-error'({string, io_lib:format("Value not found for key `~p`", [Key])})
  end.

%% number?
'number?'(Val) when is_number(Val) -> true;
'number?'(_Val) -> false.

%% string?
'string?'({string, _Str}) -> true;
'string?'(_Val) -> false.

%% pos
pos({string, Str}, Index) when Index =< length(Str) ->
  {string, string:substr(Str, Index + 1, 1)};
pos({string, _Str}, Index) ->
  'simple-error'({string, io_lib:format("Index `~B` out of bounds.", [Index])}).

%% tlstr
tlstr({string, [_H | T]}) -> {string, T};
tlstr({string, []}) -> 'simple-error'({string, "Cannot call tlstr on an empty string."}).

%% str
str(Val) when is_atom(Val) ->
  {string, atom_to_list(Val)};
str({string, Str}) ->
  {string, lists:flatten(io_lib:format("~p", [Str]))};
str(Val) when is_function(Val) ->
  {string, lists:flatten(io_lib:format("FUN: ~p", [Val]))};
str(Val) when is_number(Val) ->
  {string, lists:flatten(io_lib:format("~p", [Val]))};
str(Val) when is_pid(Val) ->
  {string, lists:flatten(io_lib:format("PID: ~p", [Val]))};
str([Car | Cdr]) ->
  {string, StrCar} = str(Car),
  {string, StrCdr} = str(Cdr),
  {string, lists:flatten(io_lib:format("(~s, ~s)", [StrCar, StrCdr]))};
str({vector, Length, Vec}) ->
  {string, lists:flatten(io_lib:format("VECTOR: ~p[~B]", [Vec, Length]))};
str({dict, Dict}) ->
  {string, lists:flatten(io_lib:format("DICTIONARY: ~p", [Dict]))};
str([]) ->
  {string, "[]"}.

%% cn
cn({string, Str1}, {string, Str2}) -> {string, Str1 ++ Str2}.

%% string->n
'string->n'({string, [Char | _RestStr]}) -> Char;
'string->n'({string, []}) ->
  'simple-error'({string, "Cannot call string->n on an empty string."}).

%% n->string
'n->string'(Char) -> {string, [Char]}.

%% absvector
absvector(Length) ->
  {vector, Length, shen_erl_global_stores:dict_new()}.

%% address->
'address->'({vector, Length, Vec}, Index, Val) -> %when Index < Length ->
  shen_erl_global_stores:dict_set(Vec, Index, Val),
  {vector, Length, Vec}.

%% <-address
'<-address'({vector, Length, Vec}, Index) when Index < Length ->
  {ok, Val} = shen_erl_global_stores:dict_get(Vec, Index),
  Val;
'<-address'({vector, _Length, _Vec}, _Index) ->
  'simple-error'({string, "Index out of bounds"}).

%% absvector?
'absvector?'({vector, _Length, _Vec}) -> true;
'absvector?'(_Val) -> false.

%% cons?
'cons?'([_H | _T]) -> true;
'cons?'(_Val) -> false.

%% cons
cons(H, T) -> [H | T].

%% list
list(A) -> [A].

%% do
'do'(_A, B) -> B.

%% hd
hd([H | _T]) -> H;
hd(_Val) -> 'simple-error'({string, "head expects a non-empty list"}).

%% tl
tl([_H | T]) -> T;
tl(_Val) -> 'simple-error'({string, "tail expects a non-empty list"}).

%% write-byte
'write-byte'(Num, Stream) ->
  io:fwrite(Stream, "~c", [Num]).

%% read-byte
'read-byte'(Stream) ->
  case io:get_chars(Stream, [], 1) of
    [Char] -> Char;
    eof -> maybe_exit_on_repl_eof(Stream)
  end.

'shen.char-stinput?'(_Stream) -> false.

'shen.char-stoutput?'(_Stream) -> false.

'shen.read-unit-string'(Stream) ->
  case io:get_chars(Stream, [], 1) of
    [Char] -> {string, [Char]};
    eof ->
      maybe_exit_on_repl_eof(Stream),
      {string, ""}
  end.

'shen.write-string'({string, String}, Stream) ->
  ok = io:put_chars(Stream, String),
  {string, String}.

%% open
open({string, FilePath}, in) ->
  {string, HomePath} = value('*home-directory*'),
  FileAbsPath = filename:absname(FilePath, HomePath),
  {ok, File} = file:open(FileAbsPath, [read]),
  File;
open({string, FilePath}, out) ->
  {string, HomePath} = value('*home-directory*'),
  FileAbsPath = filename:absname(FilePath, HomePath),
  {ok, File} = file:open(FileAbsPath, [write]),
  File.

%% close
close(Stream) ->
  file:close(Stream),
  [].

%% =
'='(Val1, Val2) ->
  Val1 =:= Val2.

%% eval-kl
'eval-kl'(KlCode) ->
  KlCode2 =
    case module_loaded('kl_extension-factorise-defun') of
      true -> 'kl_extension-factorise-defun':'shen.x.factorise-defun.factorise-defun'(KlCode);
      false -> KlCode
    end,
  shen_erl_kl_compiler:eval_kl(KlCode2).

%% get-time
'get-time'(unix) ->
  Epoch = calendar:datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}}),
  calendar:datetime_to_gregorian_seconds(calendar:universal_time()) - Epoch;
'get-time'(run) ->
  calendar:datetime_to_gregorian_seconds(calendar:universal_time()) - shen_erl_global_stores:start_time().

%% type
type(Val, _Hint) -> Val.

%%%===================================================================
%%% Internal functions
%%%===================================================================

maybe_exit_on_repl_eof(standard_io) ->
  case shen_erl_global_stores:get_val('__shen_erl_exit_on_eof') of
    {ok, true} -> erlang:halt(0);
    _ -> -1
  end;
maybe_exit_on_repl_eof(_Stream) -> -1.
