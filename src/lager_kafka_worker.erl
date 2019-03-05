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


start(State=#state{broker = Broker, id = ClientId, topic = Topic}) ->
    ok = brod:start_client(Broker, ClientId, []),
    ok = brod:start_producer(ClientId, Topic, []),
    do_write(State).

do_write(State=#state{errors = Errors}) ->
    receive
        {log, Msg} ->
            case write_kafka(Msg, State) of
                ok ->
                    do_write(State);
                error ->
                    do_write(State#state{errors = Errors+1})
            end;
        {reset, error, number} ->
            io:format("write error number:~p~n", [Errors]),
            do_write(State#state{errors = 0});
        _ ->
            % kafka ack ...
            % @todo 对ack进行区别分析
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

