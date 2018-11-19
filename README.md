lager_kafka_backend
=====

An OTP application

Build
-----

    $ make


Code Deps
------------

    1. kafka client
    https://github.com/klarna/brod.git
    2. lager
    https://github.com/erlang-lager/lager
    
Other Deps
---------------

http://kafka.apache.org/:

    % zookeeper
    ./bin/zookeeper-server-start.sh config/zookeeper.properties
    
    % kafka server
    ./bin/kafka-server-start.sh config/server.properties
    

Config
------------

      {lager,
        [
          {handlers,
            [
              {lager_kafka_backend, [
                {level,                         info},
                {topic,                         <<"topic">>},
                {broker,                        [{"localhost", 9092}]},
                {send_method,                   async},
                {formatter,                     lager_default_formatter},
                {formatter_config,              [date, " ", time, " ", message]}
              ]
              }
            ]
          }
        ]
      }    
    
