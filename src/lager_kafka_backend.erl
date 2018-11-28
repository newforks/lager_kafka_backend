%%%-------------------------------------------------------------------
%%% @author zhaoweiguo
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%       lager的kafka backend
%%% @end
%%% Created : 13. Nov 2018 4:07 PM
%%%-------------------------------------------------------------------
-module(lager_kafka_backend).
-author("zhaoweiguo").

-include_lib("lager/include/lager.hrl").

-behaviour(gen_event).

-define(DEFAULT_BROKER,           [{"localhost", 9092}]).
-define(DEFAULT_SENDMETHOD,       async).
-define(DEFAULT_FORMATTER,        lager_default_formatter).
-define(DEFAULT_FORMATTER_CONFIG, []).
-define(MAX_ERROR_LOG_NUM, 20).

-record(state, {
  id                =?MODULE                    :: tuple(),
  level             =debug                      :: integer(),
  topic             = list_to_binary(atom_to_list(?MODULE))           :: binary(),
  method            = ?DEFAULT_SENDMETHOD       :: atom(),
  formatter         = ?DEFAULT_FORMATTER        :: atom(),
  formatter_config  = ?DEFAULT_FORMATTER_CONFIG :: any(),
  broker            = ?DEFAULT_BROKER           :: any(),
  shaper            = #shaper{}
}).


-record(shaper, {
  mps = 0,
  lasttime = os:timestamp() :: erlang:timestamp()
}).

-export([init/1, handle_call/2, handle_event/2, handle_info/2, terminate/2,
  code_change/3]).


init(Params) ->
  io:format("lager_kafka_backend init:~p~n", [Params]),
  init(Params, #state{}).

init([], State=#state{broker = Broker, id = ClientId, topic = Topic}) ->
  ok = brod:start_client(Broker, ClientId, []),
  ok = brod:start_producer(ClientId, Topic, []),
  {ok, State};
init([{clientid, ClientId} | Other], State) ->
  init(Other, State#state{id=ClientId});
init([{level, Level} | Other], State) ->
  init(Other, State#state{level = validate_loglevel(Level)});
init([{broker, Broker} | Other], State) ->
  init(Other, State#state{broker = Broker});
init([{topic, Topic} | Other], State) ->
  init(Other, State#state{topic = Topic});
init([{method, Method} | Other], State) ->
  init(Other, State#state{method = Method});
init([{formatter, Formatter} | Other], State) ->
  init(Other, State#state{formatter = Formatter});
init([{formatter_config, FormatConfig} | Other], State) ->
  init(Other, State#state{formatter_config = FormatConfig});
init([_|Other], State) ->
  init(Other, State).

%% @private
handle_call({set_loglevel, Level}, #state{id=Id} = State) ->
%%  io:format("[~p:~p]set_loglevel:~p| id:~p~n", [?MODULE, ?LINE, Level, Id]),
  case validate_loglevel(Level) of
    false ->
      io:format("[~p:~p]validate_loglevel: false~n", [?MODULE, ?LINE]),
      {ok, {error, bad_loglevel}, State};
    Levels ->
      io:format("[~p:~p]validate_loglevel:~p~n", [?MODULE, ?LINE, Levels]),
      ?INT_LOG(notice, "Changed loglevel of ~s to ~p", [Id, Level]),
      {ok, ok, State#state{level=Levels}}
  end;
handle_call(get_loglevel, #state{level=Level} = State) ->
  io:format("[~p:~p]get_loglevels:~p~n", [?MODULE, ?LINE, Level]),
  {ok, Level, State};
handle_call(_Request, State) ->
  {ok, ok, State}.

%% @private
handle_event({log, Message}, #state{level = L, formatter = Formatter, formatter_config = FormatConfig } = State) ->
  case lager_util:is_loggable(Message, L, ?MODULE) of
    true ->
      Msg = Formatter:format(Message, FormatConfig),
      NewMsg = unicode:characters_to_binary(Msg),
      NewState = write_kafka(NewMsg, State),
      {ok, NewState};
    false ->
      {ok, State}
  end;
handle_event(Event, State) ->
  io:format("lager kafka event:~p~n", [Event]),
  {ok, State}.


%% @private
handle_info(_Info, State) ->
  {ok, State}.

%% @private
terminate(_Reason, State) ->
  %% leaving this function call unmatched makes dialyzer cranky
  _ = close_kafka(State),
  ok.

%% @private
code_change(_OldVsn, State, _Extra) ->
  {ok, State}.




%%====================================================================
%% Internal functions
%%====================================================================


write_kafka(Msg, #state{id = ClientId, topic = Topic, method = async, shaper = Shaper } = State) ->
  PartitionFun = fun(_Topic, Partition, _Key, _Value) ->
    {ok, crypto:rand_uniform(0, Partition)}
                 end,
%%  PartitionFun = 0,
  case brod:produce(ClientId, Topic, PartitionFun, <<"">>, Msg) of
    {ok, _CallRef} ->
      State;
    {error, Reason} ->
      % @todo send warning sms?
      Shaper2 = case check_qps(Shaper) of
        {false, _, NewShaper} ->
          NewShaper;
        {true, 0, NewShaper} ->
          io:format("error:[~p:~p]brod:produce/4 Reason = ~p; ~n", [?MODULE, ?LINE, Reason]),
          NewShaper;
        {true, Mps, NewShaper} ->
          io:format("error:[~p:~p]Number of Error Msg is = ~p; ~n", [?MODULE, ?LINE, Mps]),
          NewShaper
      end,
      State#state{shaper = Shaper2}
  end;
write_kafka(Msg, #state{id = ClientId, topic = Topic, method = sync, shaper = Shaper } = State) ->
  PartitionFun = fun(_Topic, Partition, _Key, _Value) ->
    {ok, crypto:rand_uniform(0, Partition)}
                 end,
  case brod:produce_sync(ClientId, Topic, PartitionFun, <<"">>, Msg) of
    ok ->
      State;
    {error, Reason} ->
      % @todo send warning sms?
      Shaper2 = case check_qps(Shaper) of
                  {false, _, NewShaper} ->
                    NewShaper;
                  {true, 0, NewShaper} ->
                    io:format("error:[~p:~p]brod:produce/4 Reason = ~p; ~n", [?MODULE, ?LINE, Reason]),
                    NewShaper;
                  {true, Mps, NewShaper} ->
                    io:format("error:[~p:~p]Number of Error Msg is = ~p; ~n", [?MODULE, ?LINE, Mps]),
                    NewShaper
                end,
      State#state{shaper = Shaper2}
  end.

%% 检查是否应该写日志
check_qps(#shaper{mps = Mps, lasttime = Last} = Shaper) when Mps < ?MAX_ERROR_LOG_NUM->
  {M, S, _} = Now = os:timestamp(),
  case Last of
    {M, S, _} ->
      {true, 0, Shaper#shaper{mps=Mps+1}};
    _ ->
      %different second - reset mps
      {false, Mps, Shaper#shaper{mps=0, lasttime = Now}}
  end;
check_qps(Shaper = #shaper{mps = Mps, lasttime = Last}) ->
  {M, S, _} = Now = os:timestamp(),
  case Last of
    {M, S, _} ->
      {false, 0, Shaper#shaper{mps=Mps+1}};
    _ ->
      %different second - reset mps
      {true, Mps, Shaper#shaper{mps=0, lasttime = Now}}
  end.



validate_loglevel(Level) ->
  try lager_util:config_to_mask(Level) of
    Levels ->
      Levels
  catch
    _:_ ->
      false
  end.

close_kafka(#state{id = ClientId} = _State) ->
  brod:stop_client(ClientId),
  ok.





