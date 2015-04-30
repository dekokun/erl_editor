-module(message_wall_app).
-behaviour(application).

-export([start/2]).
-export([stop/1]).

start(_Type, _Args) ->
  ets:new(message_wall, [set, named_table, public]),
  Dispatch = cowboy_router:compile([
    {'_', [
      % cowboy_staticはパスマッチに対して、静的ファイルを読み込む
      % index.htmlを読み込む
      {"/", cowboy_static, {file, filename:join(
        [filename:dirname(code:which(?MODULE)),
          "..", "priv", "index.html"])}},
      {"/bundle.js", cowboy_static, {file, filename:join(
        [filename:dirname(code:which(?MODULE)),
          "..", "priv", "bundle.js"])}},
      {"/flex.css", cowboy_static, {file, filename:join(
        [filename:dirname(code:which(?MODULE)),
          "..", "priv", "flex.css"])}},
      % /websocketのリクエストをws_handlerに渡す
      {"/websocket", message_wall_handler, []}
    ]}
  ]),
  {ok, _} = cowboy:start_http(http, 100,
    [{port, port()}],
    [
      {env, [{dispatch, Dispatch}]}
    ]),
  message_wall_sup:start_link().

stop(_State) ->
  ok.

port() ->
  case os:getenv("PORT") of
    false ->
      {ok, Port} = application:get_env(http_port),
      Port;
    Other ->
      list_to_integer(Other)
  end.
