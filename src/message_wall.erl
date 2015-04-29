%% @author author <author@example.com>
%% @copyright YYYY author.

%% @doc heroku_erlang_example startup code

-module(message_wall).
-author('author <author@example.com>').
-export([start/0, start_link/0, stop/0]).

%% @spec start_link() -> {ok,Pid::pid()}
%% @doc Starts the app for inclusion in a supervisor tree
start_link() ->
    application:ensure_all_started(message_wall).

%% @spec start() -> ok
%% @doc Start the heroku_erlang_example server.
start() ->
    application:ensure_all_started(message_wall).

%% @spec stop() -> ok
%% @doc Stop the heroku_erlang_example server.
stop() ->
    application:stop(message_wall).
