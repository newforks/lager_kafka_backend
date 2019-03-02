%%%-------------------------------------------------------------------
%%% @author zhaoweiguo
%%% @copyright (C) 2019, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 01. Mar 2019 5:24 PM
%%%-------------------------------------------------------------------
-module(lager_kafka_worker).
-author("zhaoweiguo").

-include("lager_kafka_backend.hrl").

%% API
-export([write_kafka/2]).
-export([start/1]).
-export([restart/1]).


start(State=#state{broker = Broker, id = ClientId, topic = Topic}) ->
    try
        ok = brod:start_client(Broker, ClientId, []),
        ok = brod:start_producer(ClientId, Topic, []),
        do_write(State#state{worker_alive = true})
    catch
        Err:Exception  ->
            io:format("lager_kafka_backend brod start client fail. Err:~p, Exception:~p~n", [Err, Exception]),
            do_write(State#state{worker_alive = false})
    end.

restart(State=#state{id = ClientId}) ->
    try
        ok = brod:stop_client(ClientId)
    catch
        Err:Exception  ->
            io:format("lager_kafka_backend brod stop client fail. Err:~p, Exception:~p~n", [Err, Exception])
    end,
    start(State).


do_write(State=#state{errors = ?MAX_ERROR_NUM}) ->
    % @todo 要不要打印？
    % 打印: 数据量大时有问题
    % 不打印: 不好定位问题
    restart(State#state{errors=0});
do_write(State=#state{worker_alive = IsAlive, errors = Errors}) ->
    receive
        {log, Msg} ->
            case IsAlive of
                false ->
                    do_write(State#state{errors = Errors+1});
                true ->
                    try
                        write_kafka(Msg, State),
                        do_write(State)
                    catch
                        _Err:_Exception  ->
                            do_write(State#state{errors = Errors+1})
                    end
            end;
        {reset, error, number} ->
            io:format("error number:~p~n", [Errors]),
            do_write(State#state{errors = 0});
        _ ->
            % kafka ack ...
            do_write(State)
    end.


write_kafka(Msg, #state{id = ClientId, topic = Topic}) ->
    PartitionFun = fun(_Topic, Partition, _Key, _Value) ->
        {ok, crypto:rand_uniform(0, Partition)}
                   end,
%%  PartitionFun = 0,
    case brod:produce(ClientId, Topic, PartitionFun, <<"">>, Msg) of
        {ok, _CallRef} ->
            ok;
        {error, _Reason} ->
            % @todo 出问题时想看下什么错误
            error
    end.


%%====================================================================
%% Internal functions
%%====================================================================

