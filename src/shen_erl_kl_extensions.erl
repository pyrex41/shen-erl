%%%-------------------------------------------------------------------
%%% @author Sebastian Borrazas
%%% @copyright (C) 2018, Sebastian Borrazas
%%%
%%% Erlang interop for Shen code.  Every export except assert-boolean is
%%% registered as a Shen function at boot (see shen_erl_kl_compiler), so
%%% these can be called, partially applied and passed with (fn ...).
%%%
%%% Arguments and results are converted by shen_erl_interop: Shen strings
%%% become UTF-8 binaries and Shen lists Erlang lists on the way in; binaries
%%% become strings and tuples lists on the way back.
%%%-------------------------------------------------------------------
-module(shen_erl_kl_extensions).

%% API
-export(['erl.apply'/3,
         'erl.receive'/1,
         'erl.send'/2,
         'erl.tuple'/1,
         'assert-boolean'/1]).

%%%===================================================================
%%% API
%%%===================================================================

%% (erl.apply Module Function Args): call Module:Function(Args...).
%% Erlang exceptions are raised as Shen errors, so trap-error sees them.
'erl.apply'(Mod, Fun, Args) when is_atom(Mod), is_atom(Fun), is_list(Args) ->
  ErlArgs = shen_erl_interop:to_erl(Args),
  try erlang:apply(Mod, Fun, ErlArgs) of
    Result -> shen_erl_interop:to_shen(Result)
  catch
    throw:{simple_error, _} = Err ->
      throw(Err);
    Class:Reason ->
      error_msg("erl.apply: ~s:~s/~B raised ~p:~0p",
                [Mod, Fun, length(ErlArgs), Class, Reason])
  end;
'erl.apply'(Mod, Fun, Args) ->
  error_msg("erl.apply: expected (erl.apply Module Function [Arg ...]) "
            "with symbols and a list, got ~0p ~0p ~0p", [Mod, Fun, Args]).

%% (erl.receive Timeout): wait up to Timeout milliseconds (or the symbol
%% infinity) for a message; returns the symbol timeout if none arrives.
'erl.receive'(infinity) ->
  receive
    Message -> shen_erl_interop:to_shen(Message)
  end;
'erl.receive'(Timeout) when is_number(Timeout), Timeout >= 0 ->
  receive
    Message -> shen_erl_interop:to_shen(Message)
  after
    round(Timeout) -> timeout
  end;
'erl.receive'(Timeout) ->
  error_msg("erl.receive: timeout must be a non-negative number or infinity, got ~0p",
            [Timeout]).

%% (erl.send Dest Message): send Message (converted to Erlang) to a pid,
%% registered name, or tuple destination.  Returns Message.
'erl.send'(Dest, Message) ->
  try
    Dest ! shen_erl_interop:to_erl(Message),
    Message
  catch
    error:badarg -> error_msg("erl.send: invalid destination ~0p", [Dest])
  end.

%% (erl.tuple [X ...]): build an Erlang tuple, for APIs that take tuples.
'erl.tuple'(Elems) when is_list(Elems) ->
  list_to_tuple(shen_erl_interop:to_erl(Elems));
'erl.tuple'(Elems) ->
  error_msg("erl.tuple: expected a list, got ~0p", [Elems]).

'assert-boolean'(true) -> true;
'assert-boolean'(false) -> false;
'assert-boolean'(Value) ->
  ErrorMsg = io_lib:format("Expected a boolean in if/and/or/cond expression, got `~p`", [Value]),
  shen_erl_kl_primitives:'simple-error'({string, ErrorMsg}).

%%%===================================================================
%%% Internal functions
%%%===================================================================

error_msg(Fmt, Args) ->
  shen_erl_kl_primitives:'simple-error'({string, io_lib:format(Fmt, Args)}).
