-module(shen_erl_repl_SUITE).

%% REPL end-of-input contract (shared with Shen/JIT): only the REPL's own
%% read treats EOF on the first byte of a line as the end of the session.
%% Programs evaluated at the REPL see ordinary EOF from standard input.

-export([all/0,
         t_empty_stdin_exits/1,
         t_final_line_without_newline_runs/1,
         t_two_lines_last_unterminated/1,
         t_trailing_spaces_exit/1,
         t_unterminated_form_exits/1,
         t_program_read_byte_gets_eof/1,
         t_program_read_reports_empty_stream/1,
         t_program_lineread_reports_empty_stream/1,
         t_program_catches_its_own_read/1]).

-include_lib("common_test/include/ct.hrl").

all() ->
  [t_empty_stdin_exits,
   t_final_line_without_newline_runs,
   t_two_lines_last_unterminated,
   t_trailing_spaces_exit,
   t_unterminated_form_exits,
   t_program_read_byte_gets_eof,
   t_program_read_reports_empty_stream,
   t_program_lineread_reports_empty_stream,
   t_program_catches_its_own_read].

t_empty_stdin_exits(Config) ->
  Out = repl(Config, ""),
  nomatch = string:find(Out, "empty stream").

t_final_line_without_newline_runs(Config) ->
  Out = repl(Config, "(+ 40 2)"),
  true = string:find(Out, "42") =/= nomatch,
  nomatch = string:find(Out, "empty stream").

t_two_lines_last_unterminated(Config) ->
  Out = repl(Config, "(+ 1 2)\n(* 6 7)"),
  true = string:find(Out, "42") =/= nomatch,
  nomatch = string:find(Out, "empty stream").

t_trailing_spaces_exit(Config) ->
  Out = repl(Config, "(+ 40 2)\n   "),
  true = string:find(Out, "42") =/= nomatch,
  nomatch = string:find(Out, "empty stream").

t_unterminated_form_exits(Config) ->
  repl(Config, "(+ 1").

t_program_read_byte_gets_eof(Config) ->
  Out = repl(Config, "(read-byte (stinput))\n"),
  true = string:find(Out, "-1") =/= nomatch.

t_program_read_reports_empty_stream(Config) ->
  Out = repl(Config, "(read (stinput))\n"),
  true = string:find(Out, "empty stream") =/= nomatch.

t_program_lineread_reports_empty_stream(Config) ->
  Out = repl(Config, "(lineread (stinput))\n"),
  true = string:find(Out, "empty stream") =/= nomatch.

t_program_catches_its_own_read(Config) ->
  Out = repl(Config, "(trap-error (read (stinput)) (/. E caught))\n"),
  true = string:find(Out, "caught") =/= nomatch.

%%%===================================================================
%%% Internal functions
%%%===================================================================

%% Runs bin/shen-erl with Input as standard input and returns its output,
%% requiring exit status 0 within the deadline.
repl(Config, Input) ->
  Ebin = filename:dirname(code:which(shen_erl_kl_compiler)),
  Launcher = filename:join([filename:dirname(Ebin), "bin", "shen-erl"]),
  true = filelib:is_regular(Launcher),
  InFile = filename:join(?config(priv_dir, Config), "repl-input"),
  ok = file:write_file(InFile, Input),
  Port = erlang:open_port({spawn_executable, "/bin/sh"},
                          [{args, ["-c", "exec \"$0\" < \"$1\"", Launcher, InFile]},
                           exit_status, stderr_to_stdout, binary]),
  collect(Port, []).

collect(Port, Acc) ->
  receive
    {Port, {data, Data}} -> collect(Port, [Data | Acc]);
    {Port, {exit_status, 0}} -> binary_to_list(iolist_to_binary(lists:reverse(Acc)));
    {Port, {exit_status, Status}} ->
      ct:fail({exit_status, Status, lists:reverse(Acc)})
  after 120000 ->
    erlang:port_close(Port),
    ct:fail({timeout, lists:reverse(Acc)})
  end.
