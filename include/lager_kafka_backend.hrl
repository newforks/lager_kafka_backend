
-define(DEFAULT_BROKER,           [{"localhost", 9092}]).
-define(DEFAULT_SENDMETHOD,       async).
-define(DEFAULT_FORMATTER,        lager_default_formatter).
-define(DEFAULT_FORMATTER_CONFIG, []).
-define(MAX_ERROR_LOG_NUM, 2).

-record(shaper, {
    mps = 0,
    lasttime = os:timestamp() :: erlang:timestamp()
}).

-record(state, {
    id                =?MODULE                    :: tuple(),
    level             =debug                      :: integer(),
    topic             = list_to_binary(atom_to_list(?MODULE))           :: binary(),
    method            = ?DEFAULT_SENDMETHOD       :: atom(),
    formatter         = ?DEFAULT_FORMATTER        :: atom(),
    formatter_config  = ?DEFAULT_FORMATTER_CONFIG :: any(),
    broker            = ?DEFAULT_BROKER           :: any(),
    shaper            = #shaper{},
    errors            = 0,
    worker_alive      = false,
    worker_pid
}).


-define(undef, undefined).
-define(MAX_ERROR_NUM, 1000).

