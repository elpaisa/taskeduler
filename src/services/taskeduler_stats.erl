%%% @doc Handles the worker statuses
%%%
%%% @author elpaisa
%%% @copyright (C) 2017, John L. Diaz
%%%
%%% Created : 23. Mar 2017 10:23 AM
%%% @end

-module(taskeduler_stats).
-author("elpaisa").

-include("taskeduler.hrl").

-ifdef(TEST).
-compile([export_all]).
-endif.

%%Public endpoints
-export([status/0, status/1, status/2, set_status/3, enabled_checks/0, health/0, workers_ok/0, lagged/0]).

-record(w_status, {
  worker,
  status = waiting,
  total_tasks = 0,
  time_interval = [],
  percent_done = 0,
  time_started,
  seconds_elapsed = 0,
  last_time_run = null,
  last_run_task = null,
  time_finished = null,
  tasks_pending_to_run = [],
  tasks_successfully_run = [],
  re_sync_days = 0,
  days_to_sync = 1,
  num_tasks_pending_to_run = 0,
  num_tasks_successful = 0,
  tasks_in_error = [],
  num_tasks_in_error = 0
}).

%% API
-export([save_status/1, push_metrics/3]).

-spec status() -> list().
%%
%% @doc Gets all the statuses of the workers specified in config file
%%
status() ->
  WS = [status(S) || S <- taskeduler_cache:worker_names()],
  [{workers, WS}].

-spec status(WorkerName :: atom()) -> list().
status(WorkerName) ->
  status(WorkerName, true).
%%
%% @doc Get cached status for a specific worker
%%
status(WorkerName, FlattenInvalid) ->
  Info = taskeduler_sync:get_worker(WorkerName),
  response_status(Info, cached(WorkerName), FlattenInvalid).

response_status([WorkerCache], Status, DoFlatten)->
  {WorkerName, Type, Opts, {Interval, IntervalType}} = WorkerCache,
  {
    WorkerName, [
    {module, [{name, Type}, {options, Opts}]},
    {worker, [{name, WorkerName}, {Interval, IntervalType}]},
    {status, format_status(WorkerName, Status, DoFlatten)}]
  };
response_status(_, _, _)->
  {error, <<"No worker info, has it run?">>}.

%%
%% @private Formats the response of API endpoint status, for
%% a valid json format
%%
-spec format_status(
    WorkerName :: atom(), Status :: term(), DoFlatten :: boolean()
) -> list().
format_status(WorkerName, Status, DoFlatten)->
  TasksToRun = Status#w_status.tasks_pending_to_run,
  RanTasks = Status#w_status.tasks_successfully_run,
  [
    {name, WorkerName},
    {status, Status#w_status.status},
    {percent_done, Status#w_status.percent_done},
    {time_interval, Status#w_status.time_interval},
    {last_time_run,  Status#w_status.last_time_run},
    {time_started, Status#w_status.time_started},
    {time_finished, Status#w_status.time_finished},
    {seconds_elapsed, Status#w_status.seconds_elapsed},
    {last_run_task, flatten(Status#w_status.last_run_task, DoFlatten)},
    {tasks_pending_to_run, flatten(lists:sort(TasksToRun), DoFlatten)},
    {tasks_successfully_run, flatten(lists:sort(RanTasks),DoFlatten)},
    {re_sync_days, Status#w_status.re_sync_days},
    {days_to_sync, Status#w_status.days_to_sync},
    {total_tasks, Status#w_status.total_tasks},
    {num_tasks_pending, Status#w_status.num_tasks_pending_to_run},
    {num_tasks_run, Status#w_status.num_tasks_successful},
    {tasks_in_error, flatten(Status#w_status.tasks_in_error, DoFlatten)},
    {num_tasks_in_error, Status#w_status.num_tasks_in_error}
  ].

-spec flatten(Invalid :: term(), DoFlatten :: atom()) -> binary().
%%
%% @doc Attempts to flatten a term to be used by the json decoder module
%% in order to be responded from an API endpoint
%%
flatten(List, true)->
  utils:need_binary(lists:flatten(io_lib:format("~p", [List])));
flatten(List, false)->
  List.

-spec set_status(WorkerName :: atom(), Key :: atom(), Status :: any()) -> ok.
%%
%% @doc Seeks a worker and gets its Pid, if not running returns false
%%
set_status(WorkerName, Key, Status) ->
  update(Key, WorkerName, cached(WorkerName), Status),
  ok.

update(status, _, Cached, S)->
  ets_update(Cached#w_status{status = S});
update(tasks_pending_to_run, _, CachedStatus, Status)->
  New = CachedStatus#w_status{
    num_tasks_pending_to_run = pending_to_run(CachedStatus, Status),
    tasks_pending_to_run = Status},
  ets_update(New);
update(tasks_in_error, _, Cache, S)->
  update_tasks_in_error(Cache, S);
update(last_run_task, W, Cache, S)->
  append_status_task(W, S, Cache);
update(time_interval, _, Cached, S)->
  ets_update(Cached#w_status{time_interval = S});
update(percent_done, _, Cached, S)->
  ets_update(Cached#w_status{percent_done = S});
update(time_started, _, Cached, S)->
  ets_update(Cached#w_status{time_started = S});
update(time_finished, _, Cached, S)->
  ets_update(Cached#w_status{time_finished = S});
update(seconds_elapsed, _, Cached, S)->
  ets_update(Cached#w_status{seconds_elapsed = S});
update(last_time_run, _, Cached, S)->
  ets_update(Cached#w_status{last_time_run = S});
update(tasks_successfully_run, _, Cached, S)->
  ets_update(Cached#w_status{tasks_successfully_run = S});
update(re_sync_days, _, Cached, S)->
  ets_update(Cached#w_status{re_sync_days = S});
update(days_to_sync, _, Cached, S)->
  ets_update(Cached#w_status{days_to_sync = S});
update(num_tasks_pending_to_run, _, Cached, S)->
  ets_update(Cached#w_status{num_tasks_pending_to_run = S});
update(num_tasks_successful, _, Cached, S)->
  ets_update( Cached#w_status{num_tasks_successful = S});
update(total_tasks, _, Cached, S)->
  ets_update(Cached#w_status{total_tasks = S});
update(num_tasks_in_error, _, Cached, S)->
  ets_update(Cached#w_status{num_tasks_in_error = S}).

-spec pending_to_run(
    WorkerStatus :: atom(),
    TasksToRun :: integer()
) -> ok.
%%
%% @doc Updates status index for tasks to run
%%
pending_to_run(Status, Task) ->
  DaysToSync = Status#w_status.days_to_sync,
  Pending = utils:rem_all_occurrences(Task, Status#w_status.tasks_pending_to_run),
  NumPending = length(Pending) * DaysToSync,
  {Pending, NumPending}.
%%
%% @doc Updates status index for tasks to run
%%
update_tasks_in_error(Status, TaskInError) ->
  NumTasksInError = Status#w_status.num_tasks_in_error,
  AllTasksInError = Status#w_status.tasks_in_error,
  NewList = lists:append(AllTasksInError, [TaskInError]),
  New = Status#w_status{
    tasks_in_error = NewList, num_tasks_in_error = (NumTasksInError + 1)
  },
  ets_update(New),
  ok.

-spec save_status(WorkerName :: atom()) -> tuple().
%%
%% @doc Set initial status for a worker name
%%
save_status(W) ->
  TS = utils:need_binary(qdate:to_string("c")),
  Default = #w_status{worker = W, time_started = TS},
  taskeduler_cache:insert(?STATUS_TABLE, {W, Default}),
  Default.

%%
%% @doc Get key position for a status value
%%
-spec append_status_task(
    WorkerName :: atom(), Task :: integer(), WorkerStatus :: tuple()
) -> ok.
append_status_task(WorkerName, Task, Status) ->
  {Pending, NumPendingToRun} = pending_to_run(Status, Task),
  Successful = lists:append(Status#w_status.tasks_successfully_run, [Task]),
  TimeStarted = qdate:to_unixtime(Status#w_status.time_started),
  TimeFinished = utils:need_binary(qdate:to_string("c")),
  NumSuccessful = length(Successful),
  DaysToSync = Status#w_status.days_to_sync,
  TookSeconds = utils:get_time_difference(TimeStarted, qdate:to_unixtime(TimeFinished)),
  PercentDone = get_percent(NumSuccessful, Status#w_status.total_tasks, DaysToSync),
  TasksInError = remove_in_error(WorkerName, Task, Status#w_status.tasks_in_error),
  DaysLeft = utils:default(DaysToSync - Status#w_status.re_sync_days, 1),
  {WStatus, Finished} = is_done(PercentDone, WorkerName, TimeFinished, TookSeconds),
  New = Status#w_status{
    status = WStatus,
    seconds_elapsed = TookSeconds,
    num_tasks_pending_to_run = NumPendingToRun,
    tasks_pending_to_run = Pending,
    percent_done = PercentDone,
    tasks_successfully_run = Successful,
    num_tasks_successful = NumSuccessful,
    last_run_task = Task,
    last_time_run = TimeFinished,
    time_finished = Finished,
    tasks_in_error = TasksInError,
    num_tasks_in_error = length(TasksInError)
  },
  utils:debug("~p TASKS DONE ~p, OF ~p, LEFT ~p, So far ~p%, Days to Sync ~p, Days Left ~p",
    [WorkerName, NumSuccessful, Status#w_status.total_tasks, NumPendingToRun, PercentDone,
      DaysToSync, DaysLeft]
  ),
  ets_update(New).

get_percent(NumSuccessful, NumPendingToRun, DaysToSync)->
  round(
    utils:division(utils:division(NumSuccessful, NumPendingToRun) * 100,
      get_days_to_sync(DaysToSync))
  ).

ets_update(V)->
  taskeduler_cache:insert(?STATUS_TABLE, {V#w_status.worker, V}).

is_done(100, W, Finished, Took)->
  push_metrics(W, seconds_elapsed, Took),
  {finished, Finished};
is_done(_, _, _, _)->
  {finished, null}.

remove_in_error(W, Task, CurrentInError) ->
  tasks_in_error(W, CurrentInError, Task).

tasks_in_error(_, [], _)->
  [];
tasks_in_error(_, InError, Task)->
  utils:rem_all_occurrences(Task, InError).

%%
%% @doc If re-sync happens, decrement by 1
%%
-spec get_days_to_sync(DaysToSync :: integer()) -> integer().
get_days_to_sync(DaysToSync) ->
  case DaysToSync of
    1 -> 1;
    Any -> (Any - 1)
  end.

%%
%% @doc Pushes metrics to specified service in controller
%%
-spec push_metrics(WorkerName :: atom(), Key :: atom(), Value :: any()) -> ok.
push_metrics(WorkerName, Key, _Value) ->
  _KeyName = utils:atom_join([WorkerName, Key], "."),
  %%TODO: set metric system by config
  ok.

cached(Worker)->
  is_cached(taskeduler_cache:get(?STATUS_TABLE, Worker)).

is_cached([{_, S}])->
  S;
is_cached([])->
  #w_status{time_started = qdate:to_string("c", os:timestamp())}.


-spec health() -> term().
%%
%% @doc Gets the workers to check for lagging from the config file
%% and checks the last_run_time from status endpoint, and if time is lower
%% than (now - Interval = ({60, minutes} * 2)):
%% {ok, message}: if all workers are ok
%% {warning, message}: if some workers are lagged less than 50%
%% {critical, message}: More than 50% of workers are lagged
%%
health()->
  Checks = enabled_checks(),
  NumLagged = length(lagged()),
  Percent = utils:percent(length(Checks), NumLagged),
  health(NumLagged, Percent).

-spec health(NumWorkersLagged :: integer(), Percent :: integer()) -> term().
%%
%% @doc Responds a tuple according to num workers lagged and percent lagged
%%
health(0, _)->
  {ok, <<"All workers are on time">>};
health(_, Percent) when Percent =< 50 ->
  {warning, <<"Some workers are lagged of execution">>};
health(_, _)->
  {critical, <<"More than the 50% of workers are lagged of execution">>}.

-spec lagged() -> list().
%%
%% @private Gets the number of lagged workers based in its last_run_time
%% and the interval of time configured in config file
%%
lagged()->
  [C || C <- enabled_checks(), on_time(C) =:= false].

-spec workers_ok() -> list().
%%
%% @doc Returns a list of workers on time
%%
workers_ok()->
  [W ||W <- enabled_checks(), on_time(W) =:= true].

-spec on_time(Worker :: term()) -> boolean().
%%
%% @private Checks if a worker is on time based in its last_run_time and
%% its interval configured in config file
%%
on_time(Worker)->
  [{W,_, _, Interval}] = al_distributed_sync:get_worker(Worker),
  {_W, [_, _, {_, Status}]} = status(W),
  is_on_time(proplists:get_value(last_time_run, Status), Interval).

-spec is_on_time(LastTimeRun :: integer(), term()) -> boolean().
%%
%% @private Checks if LastRuntTime is less Than (now - interval)
%%
is_on_time(undefined, _)->
  false;
is_on_time(null, _)->
  false;
is_on_time(LastTimeRun, {Interval, IntType})->
  DateStart = utils:get_interval(Interval * 2, IntType),
  (LastTimeRun > DateStart).

-spec enabled_checks() -> list().
%%
%% @doc Gets the workers to check for lagging from the config file
%% format: {checks, [worker_name1, worker_name2]}
%%
enabled_checks()->
  al_distributed:get_env(check, []).

