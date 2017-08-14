%%% @doc Handles the cache for the Workers
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
%%% Created : 06. Mar 2017 3:51 PM
%%%
%%% @end
-module(taskeduler_cache).

-ifdef(TEST).
-compile([export_all]).
-endif.

-include("taskeduler.hrl").


%% Application callbacks
-export([start/0, stop/0]).

-export([set_ets/1, get/2, insert/2, update/3]).

-export([ cache_workers/1, cache_worker/5, worker_names/0, check_last_run/3]).


-spec start() -> ok | {error, term()}.
%%
%% @doc starts cache, prepares the ets tables
%%
start() ->
  prepare_cache().


-spec stop() -> ok | {error, term()}.
%%
%% @doc stops cache, removes the ets tables
%%
stop() ->
  delete_cache().

-spec prepare_cache() -> ok.
%%
%% @doc prepares the ets tables
%%
prepare_cache()->
  set_ets(?WORKERS_TABLE),
  set_ets(?STATUS_TABLE),
  set_ets(?PERFORMANCE),
  set_ets(elk),
  ok.

-spec delete_cache() -> ok.
%%
%% @doc deletes the ets tables
%%
delete_cache() ->
  ets:delete(?WORKERS_TABLE),
  ets:delete(?STATUS_TABLE),
  ok.

-spec set_ets(ETS :: atom()) -> tuple().
%%
%% @doc Creates an ets table by name
%% @param ETS name of the table to create
%%
set_ets(ETS) ->
  etspersist:new(ETS).

-spec get(ETS :: atom(), Key :: any()) ->  {ok, Table :: tuple(), any()}.
%%
%% @doc Gets an item from an ets
%% @equiv get(Table, ETS, Key)
%% @param ETS name of the table to get the key from
%% @param Key key name to get from the table
%%
get(ETS, Key) ->
  etspersist:call(get, [ETS, Key]).

-spec insert(ETS :: atom(), Key :: any()) ->  {ok, Table :: tuple(), any()}.
%%
%% @doc Inserts an item into an ets
%% @equiv insert(Table, ETS, Value)
%%
insert(ETS, Value) ->
  etspersist:call(insert, [ETS, Value]).

-spec update(ETS :: atom(), Position :: integer(), Value :: any()) ->  {ok, Table :: tuple(), any()}.
%%
%% @doc Updates an item in an ets
%% @equiv update(Table, ETS, Position, Value)
%%
update(ETS, Position, Value) ->
  etspersist:call(update, [ETS, Position, Value]).

-spec cache_workers({Type :: atom(), _Opts :: any(), Workers :: list()}) -> ok.
%%
%% @doc Saves all workers into a flat list in an ets
%%
%% @param Type name of the module to get workers for
%% @param Opts options of the module specified in config file
%% @param Workers workers specified in the config file
%%
cache_workers({Type, Opts, Workers}) ->
  [cache_worker(N, Type, I, IT, Opts)||{N, I, IT}<-Workers],
  ok.

-spec cache_worker(
    WorkerName :: atom(), Type :: atom(), Interval :: integer(), IntervalType :: atom(), Opts :: any()
) -> ok.
%%
%% @doc Caches a worker by name
%%
%% @param WorkerName Name of the worker to cache
%% @param Type name of the module that this worker beholds to
%% @param Interval interval of time that this worker will take, specified in config
%% @param IntervalType type of interval "days, minutes, seconds"
%% @param Opts options specified in config for the worker
%%
cache_worker(WorkerName, Type, Interval, IntervalType, Opts) ->
  WT = ?WORKERS_TABLE,
  [{taskeduler_worker_names, WorkerNames}] = get(WT, taskeduler_worker_names),
  insert(WT, {taskeduler_worker_names, lists:append(WorkerNames, [WorkerName])}),
  insert(WT, {WorkerName, Type, Opts, {Interval, IntervalType}}),
  taskeduler_stats:save_status(WorkerName),
  ok.

-spec worker_names() -> list().
%%
%% @doc Gets all the worker names specified in the config, cached in the workers table
%%
worker_names()->
  [{taskeduler_worker_names, WNames}] = get(?WORKERS_TABLE, taskeduler_worker_names),
  WNames.

-spec check_last_run(WorkerName :: atom(), Interval :: integer(), IntervalType :: atom()) -> boolean().
%%
%% @doc Determines if a worker last run time is older than the interval
%% specified in its config
%%
%% @param WorkerName Name of the worker to check against
%% @param Interval Number of (minutes,days, etc) to check
%% @param IntervalType (days, minutes, etc) to use for the time difference
%%
check_last_run(
    WorkerName, Interval, IntervalType
)->
  {_W, [_, _, {status, Status}]} = taskeduler_stats:status(WorkerName),
  LastRun = proplists:get_value(last_time_run, Status),
  has_run(LastRun, Interval, IntervalType).

has_run(null, _, _)->
  false;
has_run(Date, Interval, IntervalType)->
  TimeSinceLastRun = utils:get_time_difference(
    qdate:unixtime(), qdate:to_unixtime(Date), IntervalType
  ),
  round(TimeSinceLastRun) < Interval.