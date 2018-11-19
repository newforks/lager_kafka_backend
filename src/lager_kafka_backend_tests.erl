%%%-------------------------------------------------------------------
%%% @author zhaoweiguo
%%% @copyright (C) 2018, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 15. Nov 2018 5:32 PM
%%%-------------------------------------------------------------------
-module(lager_kafka_backend_tests).
-author("zhaoweiguo").

-include_lib("eunit/include/eunit.hrl").
-compile([{parse_transform, lager_transform}]).

-define(BACKEND, lager_kafka_backend).


set_loglevel_test() ->
  setup(),
  Level = error,
  lager:set_loglevel(?BACKEND, Level),
  Level=lager:get_loglevel(?BACKEND),
  clear().

write_kafka_test() ->
  setup(),
  ok=lager:log(info,  self(), "Test INFO message"),
  ok=lager:log(error,  self(), "Test INFO message"),
  clear().



setup() ->
  {ok, _} = application:ensure_all_started(brod),
  {ok, _} = application:ensure_all_started(lager),

  application:set_env(lager, handlers, [
%%    {lager_console_backend, debug},
    {lager_kafka_backend, [
      {level,                         "info"},
      {topic,                         <<"test-topic">>},
      {broker,                        [{"localhost", 9092}]},
      {send_method,                   async},
      {formatter,                     lager_default_formatter},
      {formatter_config,              [application, " ", metadata, " ", timestamp, " ", time, " ", message]}
    ]
    }
  ]),
  application:stop(lager),
  application:start(lager),

  ok.

clear() ->
  application:stop(lager),
  application:stop(brod),
  ok.