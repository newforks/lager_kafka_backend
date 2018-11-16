lager_kafka_backend
=====

An OTP application

Build
-----

    $ make


Deps
--------

    1. kafka client
    https://github.com/klarna/brod.git
    2. lager
    https://github.com/erlang-lager/lager
    

Config
------------

      {lager,
        [
          {colored, true},
          {colors,
            [
              {debug,     "\e[0;38m" },
              {info,      "\e[1;37m" },
              {notice,    "\e[1;36m" },
              {warning,   "\e[1;33m" },
              {error,     "\e[1;31m" },
              {critical,  "\e[1;35m" },
              {alert,     "\e[1;44m" },
              {emergency, "\e[1;41m" }
            ]
          },
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
    
