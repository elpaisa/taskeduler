%%% @doc Common sync functions for the workers
%%%
%%% Handles all the processes for the specified workers
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
%%% Created : 06. Mar 2017 3:51 PM
%%%
%%% @end
-module(taskeduler_sync).

-ifdef(TEST).
-compile([export_all]).
-endif.

-include("taskeduler.hrl").

%% main sync functions, start must be called first
-export([init/0, handle_sync/6, re_sync/4, by_date/4, do_work/4, stop/0, stop/1, stop_all/1, do_resume/3,
  resume_any/6, task_done/3]).

%% Helper functions
-export([start_scheduler/1, get_type/1, is_running/1]).
-export([start_worker/4, get_worker/1]).

%% Async functions
-export([new_process/2, heartbeat/5, heartbeat_start/2, heartbeat_stop/1]).

%%
%% @doc Sets all necessary elements for start running
%%
-spec init() -> ok.
init() ->
  taskeduler_cache:start(),
  start_scheduler(?TASKS_SCHEDULER),
  ok.

%%
%% @doc Stops the cache
%%
-spec stop() -> ok.
stop() ->
  taskeduler_cache:stop(),
  ok.

%%
%% @doc Starts the scheduler with the given configuration params in config file
%%
-spec start_scheduler(Scheduler :: atom()) -> ok.
start_scheduler(Scheduler) ->
  Client = self(),
  Nodes = taskeduler:get_env(nodes, [node()]),
  MaxWorkers = taskeduler:get_env(max_workers, 12),
  MaxRetries = taskeduler:get_env(max_retries, 12),
  gascheduler:start_link(Scheduler, Nodes, Client, MaxWorkers, MaxRetries).

%%
%% @doc This function gets an async notification message from a scheduler task
%%
-spec schedule_me(Scheduler :: atom(), M :: atom(), F :: atom(), Args :: any()) -> ok.
schedule_me(Scheduler, M, F, Args) ->
  scheduler_alive(whereis(Scheduler), Scheduler, M, F, Args).

%%
%% @doc stops a process by its name, concat(Mod, SyncType) to get PID from name
%%
-spec stop(WorkerName :: atom()) -> list().
stop(WorkerName) ->
  case is_running(WorkerName) of
    false ->
      utils:debug("No such process is running ~p", [WorkerName]),
      [{ok, nothing_to_stop}];
    Pid ->
      utils:warning("Stopping process ~p", [WorkerName]),
      taskeduler_stats:set_status(WorkerName, status, stopped),
      erlang:apply(?TASK_CONTROLLER, process_done, [WorkerName]),
      true = exit(Pid, kill),
      unregister(WorkerName),
      [{ok, service_stopped}, {process, WorkerName}]
  end.

%%
%% @doc Handle the sync task, this function is supposed to be called
%% by a scheduler task
%%
-spec handle_sync(
    WorkerName :: atom(), Task :: integer(),
    StartTime :: integer(), EndTime :: list(), Type :: atom(), _Opts :: term()
) -> {ok, Task :: integer()}.
handle_sync(WorkerName, Task, StartTime, EndTime, Type, _Opts) ->
  StartTimeUTC = qdate:to_string("c", ?TIME_ZONE, StartTime),
  EndTimeUTC = qdate:to_string("c", ?TIME_ZONE, EndTime),
  utils:debug("Syncing ~p between ~p and ~p, on ~p", [Task, StartTimeUTC, EndTimeUTC, Type]),
  schedule_me(?TASKS_SCHEDULER, Type, documents, [WorkerName, Task, StartTime, EndTime, _Opts]),
  {ok, Task}.

%%
%% @doc Actual work function that handles the tasks list and sends them
%% to the scheduler
%%
-spec do_work(WorkerName :: atom(), {Type :: atom(), Opts :: tuple()},
    {Interval :: integer(), IntervalType :: atom(), _AdditionalArgs :: list()},
    TaskList :: list()
) -> ok.
do_work(WorkerName, {Type, Opts}, {Interval, IntervalType, _AdditionalArgs}, TaskList) ->
  do_sync(WorkerName, utils:get_interval(Interval, IntervalType), qdate:unixtime(),
    {Type, Opts, _AdditionalArgs}, TaskList),
  stop(WorkerName),
  ok.

%%
%% @doc Re-syncs all tasks documents for the ttl period KEEP_INTERVAL in days,
%% specified config file
%%
-spec re_sync(
    WorkerName :: atom(), {Type :: atom(), Opts :: list(), _AdditionalArgs :: term()},
    {Interval :: integer(), IntervalType :: atom()},
    _TaskList :: list()
) -> ok.
re_sync(WorkerName, {Type, Opts}, {Interval, IntervalType, _AdditionalArgs}, _TaskList) ->
  IndexKeepTTL = proplists:get_value(re_sync_days, Opts, 7),
  %% zero indexed
  Sequential = lists:seq(0, (IndexKeepTTL - 1)),
  taskeduler_stats:set_status(WorkerName, days_to_sync, IndexKeepTTL),
  Timestamp = qdate:unixtime(),
  Tasks = get_task_list(),
  F = fun(I) ->
    DateStart = utils:get_interval(Timestamp, (I + Interval), IntervalType),
    DateEnd = utils:get_interval(Timestamp, I, IntervalType),
    utils:debug("Starting task dispatch for day ~p sync, dates: ~p to ~p ~n", [I, DateStart, DateEnd]),
    do_sync(WorkerName, DateStart, DateEnd, {Type, Opts, []}, Tasks),
    utils:debug("Dispatch for day ~p done, dates: ~p to ~p ~n", [I, DateStart, DateEnd]),
    taskeduler_stats:set_status(WorkerName, re_sync_days, I)

      end,
  [F(S) || S <- Sequential],
  stop(WorkerName),
  ok.

%%
%% @doc Starts working a task list for a specific time interval, usually 1 day
%%
-spec by_date(
    WorkerName :: atom(),
    {Type :: atom(), Opts :: list()}, term(), TaskList :: list()
) -> ok.
by_date(WorkerName, {Type, Opts}, {_, _, _AdditionalArgs}, _TaskList) ->
  [Timestamp] = _AdditionalArgs,
  Tasks = get_task_list(),
  DateStart = qdate:to_string("Y-m-d 00:00:00", Timestamp),
  DateEnd = qdate:to_string("Y-m-d 23:59:59", Timestamp),
  do_sync(WorkerName, qdate:to_unixtime(DateStart), qdate:to_unixtime(DateEnd),
    {Type, Opts, _AdditionalArgs}, Tasks),
  stop(WorkerName),
  ok.

resume_any(ResumeWorkerName, WorkerName, StartTime, EndTime, {Type, Opts, _AdditionalArgs}, TaskList) ->
  do_sync(WorkerName, StartTime, EndTime, {Type, Opts, _AdditionalArgs}, TaskList),
  stop(ResumeWorkerName).

%%
%% @doc Gets the tasks list provided in the generator module
%%
-spec get_task_list() -> list().
get_task_list() ->
  erlang:apply(?TASK_CONTROLLER, task_list, []).

%%
%% @doc Prepare task schedule
%%
-spec prepare(WorkerName :: atom(), StartTime :: integer(), EndTime :: integer(), Type :: atom(),
    Opts :: tuple()) -> ok.
prepare(WorkerName, StartTime, EndTime, Type, Opts) ->
  erlang:apply(?TASK_CONTROLLER, prepare, [WorkerName, StartTime, EndTime, Type, Opts]).

%%
%% @doc Here is where all sync magic happens.
%%
-spec do_sync(
    WorkerName :: atom(),
    StartTime :: integer(),
    EndTime :: integer(), tuple(),
    TaskList :: list()
) -> ok.
do_sync(WorkerName, StartTime, EndTime, {Type, _Opts, _AdditionalArgs}, TaskList) when length(TaskList) =:= 0 ->
  do_sync(WorkerName, StartTime, EndTime, {Type, _Opts, _AdditionalArgs}, get_task_list());
do_sync(WorkerName, StartTime, EndTime, {Type, Opts, _AdditionalArgs}, TaskList) ->
  utils:warning("Starting ~p sync, fly my pretties, fly!!!", [Type]),
  taskeduler_stats:set_status(WorkerName, total_tasks, length(TaskList)),
  taskeduler_stats:set_status(WorkerName, tasks_pending_to_run, TaskList),
  taskeduler_stats:set_status(WorkerName, status, started),
  taskeduler_stats:set_status(WorkerName, time_interval, get_worker_interval(StartTime, EndTime)),
  prepare(WorkerName, StartTime, EndTime, Type, Opts),
  F = fun(Task) ->
    utils:sleep(1, seconds),
    utils:debug("Shouting ~p to scheduler", [Task]),
    handle_sync(WorkerName, Task, StartTime, EndTime, Type, Opts)
      end,
  [F(T) || T <- TaskList],
  ok.

%%
%% @doc Attempts to resume failed tasks for a specific worker.
%%
-spec do_resume(
    WorkerName :: atom(),
    Module :: list(),
    Status :: list()
) -> ok.
do_resume(WorkerName, [{name, Type}, {options, Options}], [{name, WorkerName} | _] = Status) ->
  case proplists:get_value(tasks_in_error, Status) of
    List when is_list(List) andalso length(List) > 0 ->
      [{start_time, StartTime}, {end_time, EndTime}, _, _] = proplists:get_value(time_interval, Status),
      ResumeWorkerName = utils:atom_join([WorkerName, resume], "_"),
      Pid = new_process(
        ResumeWorkerName,
        {taskeduler_sync, resume_any,
          [ResumeWorkerName, WorkerName, StartTime, EndTime, {Type, Options, []}, List]
        }),
      utils:inf("Process Started ~p", [Pid]);
    _Any ->
      utils:inf("No tasks to resume for ~p", [WorkerName])
  end,
  ok;
do_resume(_, _, _) ->
  utils:inf("Nothing to resume"),
  ok.

%%
%% @doc Formats a human readable interval of dates.
%%
-spec get_worker_interval(
    StartTime :: integer(),
    EndTime :: integer()
) -> list().
get_worker_interval(StartTime, EndTime) ->
  [
    {start_time, StartTime}, {end_time, EndTime},
    {start_date, utils:need_binary(qdate:to_string("c", StartTime))},
    {end_date, utils:need_binary(qdate:to_string("c", EndTime))}
  ].

%%
%% @doc Spawn a process with a given name, _Args = {ModuleName, Args},
%% all functions to call must be within taskeduler_sync.
%%
-spec start_worker(
    Name :: atom(), {Type :: atom(), _Opts :: list()}, {Interval :: integer(), IntervalType :: atom(),
      SyncType :: atom(), _AdditionalArguments :: term()},
    TaskList :: list()
) -> {Name :: atom(), {Type :: atom(), _Opts :: list()}, {Interval :: integer(), IntervalType :: atom()}}.
start_worker(Name, {Type, Opts}, {Interval, IntervalType, SyncType, _AdditionalArguments}, TaskList) ->
  taskeduler_cache:cache_worker(Name, Type, Interval, IntervalType, Opts),
  new_process(Name,
    {taskeduler_sync, SyncType, [Name, {Type, Opts}, {Interval, IntervalType, _AdditionalArguments}, TaskList]}
  ),
  {Name, {Type, Opts}, {Interval, IntervalType}}.

%%
%% @doc Spawn a process with a given name, _Args = {ModuleName, Args}
%%
-spec new_process(
    ProcessName :: atom(), {Mod :: atom(), Function :: atom(), Args :: list()}
) -> pid().
new_process(ProcessName, {Mod, Func, Args}) ->
  stop(ProcessName),
  process_flag(trap_exit, true),
  Pid = spawn_link(Mod, Func, Args),
  utils:warning("Registering process ~p with Pid: ~p", [ProcessName, Pid]),
  register(ProcessName, Pid),
  Pid.

%%
%% @doc Stops all workers for a specific module
%%
-spec stop_all(Workers :: list()) -> list().
stop_all(Workers) ->
  [stop(W) || {W, _, _} <- Workers].

%%
%% @doc Gets worker config for a specific module
%%
-spec get_type(Type :: atom()) -> list() | undefined.
get_type(Type) ->
  lists:keyfind(Type, 1, taskeduler:get_env(workers)).

%%
%% @doc Gets worker info from cache
%%
-spec get_worker(WorkerName :: atom()) -> list().
get_worker(WorkerName) ->
  taskeduler_cache:get(?WORKERS_TABLE, WorkerName).

%%
%% @doc Seeks a worker and gets its Pid, if not running returns false
%%
-spec is_running(WorkerName :: atom()) -> pid() | false.
is_running(WorkerName) ->
  case whereis(WorkerName) of
    undefined ->
      false;
    Pid ->
      case process_info(Pid) of
        undefined ->
          exit(Pid, normal),
          unregister(WorkerName),
          false;
        _ -> Pid
      end
  end.

%%
%% @doc Starts a new process to execute an arbitrary function at intervals
%%
-spec heartbeat_start(HeartBeat :: atom(),
    {Mod :: atom(), Func :: atom(), Params :: list(), Interval :: integer(), Type :: atom()}
) -> ok.
heartbeat_start(HeartBeat, {Mod, Func, Params, Interval, Type}) ->
  BeatName = utils:atom_join([utils:need_atom(HeartBeat), heartbeat], "_"),
  new_process(BeatName, {taskeduler_sync, heartbeat, [Mod, Func, Params, Interval, Type]}),
  ok.

%%
%% @doc Stops the heartbeat process
%%
-spec heartbeat_stop(HeartBeat :: atom()) -> term().
heartbeat_stop(HeartBeat) ->
  BeatName = utils:atom_join([utils:need_atom(HeartBeat), heartbeat], "_"),
  utils:inf("Attempting to stop heartbeat: ~p", [BeatName]),
  stop(BeatName).

%%
%% @doc Executes a function at given intervals
%%
-spec heartbeat(
    Mod :: atom(), Func :: atom(), Params :: list(), Interval :: integer(), Type :: atom()
) -> term().
heartbeat(Mod, Func, Params, Interval, Type) ->
  ok = schedule_me(?TASKS_SCHEDULER, Mod, Func, Params),
  utils:sleep(Interval, Type),
  heartbeat(Mod, Func, Params, Interval, Type).

%%
%% @doc Executes the callback function for every task, updates the status.
%%
-spec task_done(
    Scheduler :: pid(), term(), {ok, term()} | {error, term()}
) -> ok.
task_done(Scheduler, {Mod, Function, [WorkerName, Task, StartDate, EndDate, Opts]}, {ok, Result}) ->
  taskeduler_stats:set_status(WorkerName, last_run_task, Task),
  erlang:apply(?TASK_CONTROLLER, task_end, [
    Scheduler, {Mod, Function, [WorkerName, Task, StartDate, EndDate, Opts]}, {ok, Result}
  ]),
  ok;
task_done(Scheduler, {Mod, Function, [WorkerName, Task, StartDate, EndDate, Opts]}, {error, Error}) ->
  taskeduler_stats:set_status(WorkerName, tasks_in_error, Task),
  erlang:apply(?TASK_CONTROLLER, task_end, [
    Scheduler, {Mod, Function, [WorkerName, Task, StartDate, EndDate, Opts]}, {error, Error}
  ]),
  ok.

%%
%% @doc Test if specified scheduler is alive, otherwise try to start and execute task
%%
-spec scheduler_alive(Pid :: pid(), Scheduler :: atom(), M :: atom(),
    F :: atom(), _Args :: any()
) -> ok.
scheduler_alive(undefined, Scheduler, M, F, Args)->
  utils:err("Scheduler ~p is not alive, trying to start...", [Scheduler]),
  gen_server:cast(taskeduler_srv, {start_scheduler, Scheduler}),
  utils:sleep(1, seconds),
  scheduler_alive(whereis(Scheduler), Scheduler, M, F, Args);
scheduler_alive(Pid, Scheduler, M, F, Args) when is_pid(Pid) ->
  gascheduler:execute(Scheduler, {M, F, Args}, {?MODULE, task_done});
scheduler_alive(_, Scheduler, M, _, _) ->
  utils:err("Unable to start scheduler, ~p, ~p", [Scheduler, M]),
  throw("Unable to start task scheduler").