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

%% API

-define(DEFAULT_BROKER,           {"localhost", 9092}).
-define(DEFAULT_SENDMETHOD,       async).
-define(DEFAULT_FORMATTER,        lager_default_formatter).
-define(DEFAULT_FORMATTER_CONFIG, []).

-include_lib("eunit/include/eunit.hrl").
-compile([{parse_transform, lager_transform}]).


init_brod() ->

  {ok, _} = application:ensure_all_started(brod),
  {ok, _} = application:ensure_all_started(lager),

  application:set_env(lager, handlers, [
%%    {lager_console_backend, debug},
    {lager_kafka_backend, [
      {level,                         "info"},
      {topic,                         <<"topic">>},
      {broker,                        [{"localhost", 9092}]},
      {send_method,                   async},
      {formatter,                     lager_default_formatter},
      {formatter_config,              [date, " ", time, " ", message]}
    ]
    }
  ]),
  application:stop(lager),
  application:start(lager),

  ok.

set_loglevel_test() ->
  ok.

write_kafka_test() ->
  init_brod(),
  lager:log(info,  self(), "Test INFO message"),
  ok.


