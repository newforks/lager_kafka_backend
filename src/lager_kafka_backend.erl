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

-include("lager_kafka_backend.hrl").



-export([init/1, handle_call/2, handle_event/2, handle_info/2, terminate/2,
  code_change/3]).

init(Params) ->
  io:format("lager_kafka_backend init:~p~n", [Params]),
  init(Params, #state{}).

init([], State) ->
  process_flag(trap_exit, true),
  Pid = erlang:spawn_link(lager_kafka_worker, start, [State]),
  {ok, State#state{worker_pid = Pid}};
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
  case validate_loglevel(Level) of
    false ->
      {ok, {error, bad_loglevel}, State};
    Levels ->
      ?INT_LOG(notice, "Changed loglevel of ~s to ~p", [Id, Level]),
      {ok, ok, State#state{level=Levels}}
  end;
handle_call(get_loglevel, #state{level=Level, worker_pid = Pid} = State) ->
  Pid ! {reset, error, number},
  {ok, Level, State};
handle_call(_Request, State) ->
  {ok, ok, State}.

%% @private
handle_event({log, Message}, #state{level = L, formatter = Formatter, formatter_config = FormatConfig, worker_pid = Pid } = State) ->
  case lager_util:is_loggable(Message, L, ?MODULE) of
    true ->
      Msg = Formatter:format(Message, FormatConfig),
      NewMsg = unicode:characters_to_binary(Msg),
      Pid ! {log, NewMsg},
      {ok, State};
    false ->
      {ok, State}
  end;
handle_event(Event, State) ->
  io:format("lager_kafka_backend unexpected event:~p~n", [Event]),
  {ok, State}.


%% @private
handle_info({'EXIT', From, Reason}, State=#state{worker_pid = From}) ->
  io:format("lager_kafka_worker exit, Reason:~p~n", [Reason]),
  Pid = erlang:spawn_link(lager_kafka_worker, start, [State]),
  {ok, State#state{worker_pid = Pid}};
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





