%%% @doc taskeduler_api
%%%
%%% API Module
%%%
%%% Has all the functions to handle the
%%% API endpoint requests.
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
%%% Created : 06. Mar 2017 3:51 PM
%%%
%%% @end
-module(taskeduler_api).

-ifdef(TEST).
-compile([export_all]).
-endif.

-include("taskeduler.hrl").

%% Global rest calls
-export([init/0, start/0, sync_by/1, sync_by/2, stop/1, stop/0, status/0, status/1,
  re_sync/0, re_sync/1, re_sync/2, is_valid_call/3, resume/1]).
-export([by_date/2, on_time/1]).

%%
%% @doc Executes init function in all modules defined as sync in erl.config
%%
-spec init() -> ok.
init() ->
  taskeduler_sync:init(),
  Types = taskeduler:get_env(workers, []),
  taskeduler_cache:insert(?WORKERS_TABLE, {taskeduler_worker_names, []}),
  F = fun({Type, Opts, Workers}) ->
    (Type):init(Opts, Workers),
    taskeduler_cache:cache_workers({Type, Opts, Workers})
      end,
  [F({Type, Opts, Workers}) || {Type, Opts, Workers} <- Types],
  ok.

%%
%% @doc Gets the worker statuses
%%
-spec status() -> list().
status() ->
  [{status, taskeduler_stats:status()}].

%%
%% @doc Gets status for an specific worker
%% @param WorkerName name of the worker to get the status for
%%
-spec status(WorkerName :: atom()) -> list().
status(WorkerName) ->
  [{status, [taskeduler_stats:status(WorkerName)]}].

%%
%% @doc Executes sync processes "regular, daily" for workers defined in erl.config
%%
-spec start() -> list().
start() ->
  Workers = taskeduler_cache:worker_names(),
  [sync_by(W) || W <- Workers],
  [{ok, all_services_started}].

%%
%% @doc Starts a re-sync process for all workers specified in config file
%%
-spec re_sync() -> term().
re_sync() ->
  Types = taskeduler:get_env(workers),
  [re_sync(utils:atom_join([Type, re_sync]), {Type, Opts, Workers}) || {Type, Opts, Workers} <- Types].

%%
%% @doc Starts a re-sync process for a specific worker using the Type "module name" and options specified in the
%% config file for the worker
%% @param WorkerName name of the worker
%% @param Type Name of the module that contains the run task logic
%% @param Opts Options for the worker
%% @param _Workers Not used
%%
-spec re_sync(WorkerName :: atom(), WorkerOptions :: {Type :: atom(), _Opts :: list(), _Workers :: list()}) ->
  {Name :: atom(), {Type :: atom(), Opts :: list()}, {Interval :: integer(), IntervalType :: atom()}}.
re_sync(WorkerName, {Type, Opts, _Workers}) ->
  taskeduler_sync:start_worker(WorkerName, {Type, Opts}, {1, days, re_sync, []}, []).


%%
%% @doc Starts a re-sync process for a specific Module "Type" and options
%% specified in the config file for the worker
%% @equiv re_sync(WorkerName, {Type, Opts, _Workers})
%% @param Type Name of the module that contains the logic for running the task, must be specified in config file
%%
-spec re_sync(Type :: atom()) ->
  [{error, module_not_found}] | {Name :: atom(), {Type :: atom(), Opts :: list()},
    {Interval :: integer(), IntervalType :: atom()}}.
re_sync(Type) ->
  case taskeduler_sync:get_type(Type) of
    false ->
      [{error, module_not_found}];
    {_Type, Opts, Workers} ->
      WorkerName = utils:atom_join([Type, re_sync], "_"),
      re_sync(WorkerName, {Type, Opts, Workers})
  end.

%%
%% @doc Starts a sync process for an specific date
%% @param Type "Module name" to start sync, must be present in the config file workers definition
%% @param DateTime os timestamp
%%
-spec by_date(Type :: atom(), DateTime :: integer()) -> tuple().
by_date(Type, DateTime) ->
  case taskeduler_sync:get_type(Type) of
    false ->
      [{error, module_not_found}];
    {_Type, Opts, _Workers} ->
      DateToAtom = qdate:to_string("Y_m_d", DateTime),
      WorkerName = utils:atom_join([Type, by_date, DateToAtom], "_"),
      taskeduler_sync:start_worker(WorkerName, {Type, Opts}, {1, days, by_date, [DateTime]}, [])
  end.

%%
%% @doc Attempts to resume failed tasks in a worker last run
%% @param WorkerName name of the worker to attempt resume
%%
-spec resume(WorkerName :: atom()) -> tuple().
resume(WorkerName) ->
  case taskeduler_stats:status(WorkerName, false) of
    [error, no_worker_info]
      -> [error, no_worker_info];
    {WorkerName,
      [{module, Module},
        _,
        {status, Status}
      ]
    } ->
      taskeduler_sync:do_resume(WorkerName, Module, Status);
    _Any ->
      utils:inf("No worker info for resume")
  end.

%%
%% @doc Starts a sync process by its name and module, Module must be in the list
%% workers in config file
%% @equiv sync_by(WorkerName, do_work)
%% @param WorkerName name of the worker to start sync
%%
-spec sync_by(WorkerName :: atom()) -> list().
sync_by(WorkerName) ->
  sync_by(WorkerName, do_work).

%%
%% @doc Starts a sync process by its name and module, Module must be in the list
%% workers in config file
%% @param WorkerName name of the worker to start sync
%% @param SyncType name of the function to execute inside the taskeduler_sync module
%%
-spec sync_by(WorkerName :: atom(), SyncType :: atom()) -> list().
sync_by(WorkerName, SyncType) when (SyncType =/= do_work) andalso (SyncType =/= re_sync) ->
  [{error, invalid_worker}, {WorkerName, SyncType}];
sync_by(WorkerName, SyncType) ->
  case taskeduler_sync:get_worker(WorkerName) of
    [] ->
      [{error, worker_not_found}];
    [Worker] ->
      {WorkerName, Type, Opts, {Interval, IntervalType}} = Worker,
      taskeduler_sync:start_worker(WorkerName, {Type, Opts}, {Interval, IntervalType, SyncType, []}, []),
      [{ok, sync_started}, {worker, WorkerName}, {options, Opts}];
    Any ->
      utils:debug("Not sure how we got here ~n", [Any]),
      [{error, Any}]
  end.

%%
%% @doc Stops all the processes by names found in workers attribute in erl.config
%%
-spec stop() -> list().
stop() ->
  Types = taskeduler:get_env(workers),
  [taskeduler_sync:stop_all(Workers) || {_, _, Workers} <- Types].

%%
%% @doc Stops a process by its name, concat(Mod, SyncType) to get PID from name, this
%% doesn't stop the already scheduled tasks, only the task scheduling process, all tasks
%% already scheduled will finish their execution.
%%
%% @param WorkerName name of the worker to stop sync
%%
-spec stop(WorkerName :: atom()) ->
  [{ok, nothing_to_stop}] | [{ok, service_stopped}].
stop(WorkerName) ->
  taskeduler_sync:stop(WorkerName).

%%
%% @doc Determines if a Module exists and the function is exported with the specified arity
%%
%% @param Mod name of the module to get info
%% @param Function name of the function inside the module to get info
%% @param Arity arity to check for
%%
-spec is_valid_call(Mod :: atom(), Function :: atom(), Arity :: integer()) -> boolean().
is_valid_call(Mod, Function, Arity) ->
  RestMod = utils:get_module_info(Mod),
  case RestMod of
    false ->
      false;
    Any ->
      Exports = proplists:get_value(exports, Any),
      is_exported(Exports, Function, Arity)
  end.

%%
%% @doc Determines if a function is exported with the specified arity
%%
%% @param Exports List of the exported functions got from module_info
%% @param Function name of the function inside the module to get info
%% @param Arity arity to check for
-spec is_exported(Exports :: list(), Function :: atom(), Arity :: integer()) -> boolean().
is_exported(Exports, Function, Arity) ->
  case proplists:get_value(Function, Exports) of
    undefined ->
      false;
    Any when Any =:= Arity ->
      true;
    _ -> false
  end.

%%
%% @doc Determines if a worker last run time is older than the interval
%% specified in its config
%%
%% @param WorkerName name of the worker to check against
%%
-spec on_time(WorkerName :: atom()) -> boolean().
on_time(WorkerName) ->
  case taskeduler_sync:get_worker(WorkerName) of
    [{Worker, _, _, {Interval, IntervalType}}] ->
      taskeduler_cache:check_last_run(
        Worker, Interval, IntervalType
      );
    _ ->
      [{error, invalid_worker}]
  end.
