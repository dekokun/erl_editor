-module(message_wall_handler).
-behaviour(cowboy_websocket_handler).

-export([init/3]).
-export([websocket_init/3]).
-export([websocket_handle/3]).
-export([websocket_info/3]).
-export([websocket_terminate/3]).

-record(state, {ip, ua, room_id}).

-define(TABLE, message_wall).

init(_, _, _) ->
  {upgrade, protocol, cowboy_websocket}.

% websocket_init はwebsocket接続が開始された時に実行されます
websocket_init(_, Req, _Opts) ->
  % プロセスをgproc pubsubに登録する
  gproc_ps:subscribe(l, new_message),
  % stateを設定する
  Ip = get_ip(Req),
  {UserAgent, _Req} = cowboy_req:header(<<"user-agent">>, Req),
  State = #state{ip=Ip, ua=UserAgent, room_id=1},
  % WebSocketリクエストは長くなる可能性があるため
  % 不要なデータをReqから削除
  Req2 = cowboy_req:compact(Req),
  % 自動切断を10分に設定する（60万ミリ秒）
  {ok, Req2, State, 600000, hibernate}.

% get_markdownメッセージの場合はメッセージのリストを返します
websocket_handle({text, <<"\"get_markdown\"">>}, Req, #state{room_id=RoomId} = State) ->
  io:format("get_markdownですよ~n"),
  % 最新のメッセージを取得する
  Tuple = get_markdown(RoomId),
  % メッセージをJiffyが変換できる形式に変更
  Markdown = format_markdown(Tuple),
  io:format("dataですよ ~w~n", [Markdown]),
  % JiffyでJsonレスポンスを生成
  JsonResponse = jiffy:encode(#{
    <<"type">> => <<"all">>,
    <<"markdown">> => Markdown
  }),
  io:format("responceですよ ~s~n", [JsonResponse]),
  % JSONを返す
  {reply, {text, JsonResponse}, Req, State};

% get_markdown以外のメッセージの扱い
websocket_handle({text, Text}, Req, #state{room_id=RoomId} = State) ->
  {[{<<"set_markdown">>,RawMarkdown}, {<<"from">>,FromGuid}|_]} = jiffy:decode(Text),

  Markdown = case RawMarkdown of
    <<>> -> "";
    Data -> Data
  end,
  io:format("~w~n", [Markdown]),
  save_message(RoomId, Markdown),
  % gprocにイベントを公開し、
  % 全ての接続クライアントにwebsocket_info({gproc_ps_event, new_message, {RoomId, FromGuid}}, Req, State)を呼び出します
  gproc_ps:publish(l, new_message, {RoomId, FromGuid}),
  {ok, Req, State};


websocket_handle({binary, Data}, Req, State) ->
  {reply, {binary, Data}, Req, State};
websocket_handle(_Frame, Req, State) ->
  {ok, Req, State}.

% websocket_infoは本プロセスにErlangメッセージが届いた時に実行されます
% gprocからnew_messageメッセージの場合はそのメッセージをWebSocketに送信します
websocket_info({gproc_ps_event, new_message, {RoomId, FromGuid}}, Req, State) ->
  RawMessage = get_markdown(RoomId),
  % ETS結果をマップに変換
  io:format("~w", [RawMessage]),
  Message = format_message(RawMessage),
  JsonResponse = jiffy:encode(#{
    <<"from">> => FromGuid,
    <<"type">> => <<"all">>,
    <<"markdown">> => Message
  }),
  {reply, {text, JsonResponse}, Req, State};
websocket_info(_Info, Req, State) ->
  {ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
  ok.

% 対応するmarkdownを取得する
get_markdown(Id) ->
  case ets:lookup(?TABLE, Id) of
    [] -> {Id, <<"">>};
    [Tuple] -> Tuple
  end.

% ETS結果メッセージをJiffyが変換できる形式に変更
format_markdown({_Id, Markdown}) ->
  Markdown.

% ETS結果メッセージをJiffyが変換できる形式に変更
format_message({_Key, Markdown}) ->
  unicode:characters_to_binary(Markdown).

% IPタプルを文字列に変換
% format_ip({I1,I2,I3,I4}) ->
%   io_lib:format("~w.~w.~w.~w",[I1,I2,I3,I4]);
% format_ip(Ip) -> Ip.

% erlangのdatetimeをISO8601形式に変換
% iso8601(Time) ->
%   {{Year, Month, Day},{Hour, Minut, Second}} = calendar:now_to_universal_time(Time),
%   io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0BZ", [Year, Month, Day, Hour, Minut, Second]).

% ETSにメッセージを保存する
save_message(Key, Markdown) ->
  ets:insert(?TABLE, {Key, Markdown}).

% IP取得
get_ip(Req) ->
  % プロキシ経由対応
  case cowboy_req:header(<<"x-real-ip">>, Req) of
    {undefined, _Req} ->
      {{Ip, _Port}, _Req} = cowboy_req:peer(Req),
      Ip;
    {Ip, _Req} -> Ip
  end.
