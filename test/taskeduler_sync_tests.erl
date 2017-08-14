%%% @hidden
%%% @doc taskeduler_sync_tests
%%%
%%% taskeduler sync module tests
%%%
%%% @author elpaisa
%%% @copyright 2017 JOHN LEYTON DIAZ.
%%%
%%% @end
-module(taskeduler_sync_tests).

-include("taskeduler.hrl").

%%Testing functions
-export([hello/5]).

-ifdef(TEST).

-include("taskeduler_test.hrl").

-include_lib("eunit/include/eunit.hrl").


-import(taskeduler_sync, [init/0, handle_sync/6, re_sync/3, stop/0, stop/1, stop_all/1,
start_scheduler/1, get_type/1, is_running/1, start_worker/4, get_worker/1, schedule_me/4, do_sync/5,
do_work/4]).


setup() ->
  taskeduler:set_env(workers, ?TEST_WORKERS),
  taskeduler:set_env(controller_module, test_controller),
  meck:expect(taskeduler_stats, set_status, fun(_WorkerName, _Key, _Value) ->
    ok end),
  {[taskeduler_stats]}.

teardown({Apps}) ->
  meck:unload(Apps),
  ok.


all_test_() ->
  {
    setup,
    fun setup/0,
    fun teardown/1,
    [
      {"scheduler", {timeout, ?TEST_TIMEOUT, fun test_scheduler/0}},
      {"workers", {timeout, ?TEST_TIMEOUT, fun test_workers/0}},
      {"stop_all", {timeout, ?TEST_TIMEOUT, fun test_stop_all/0}},
      {"others", {timeout, ?TEST_TIMEOUT, fun test_others/0}}
    ]
  }.


test_scheduler() ->

  EndTime = qdate:unixtime(),
  StartTime = utils:get_interval(EndTime, 1, days),
  {ok, Pid} = start_scheduler(?TASKS_SCHEDULER),
  [
    ?assert(is_pid(Pid)),
    ?assertEqual(ok, schedule_me(?TASKS_SCHEDULER, taskeduler_sync_tests, hello,
      [tests_daily, {1, <<"Tasks whatever">>}, StartTime, EndTime, []]))
  ].

test_workers() ->
  taskeduler_cache:insert(?WORKERS_TABLE, {taskeduler_worker_names, []}),
  EndTime = qdate:unixtime(),
  StartTime = utils:get_interval(EndTime, 1, days),
  [
    ?assertEqual(
      {test_daily, {test_controller, ?TEST_OPTS}, {1, days}},
      start_worker(
        test_daily,
        {test_controller, ?TEST_OPTS}, {1, days, do_work, []}, []
      )
    ),
    ?assertEqual([{ok, service_stopped}, {process, test_daily}], stop(test_daily)),
    ?assertEqual({ok, 2}, handle_sync(test_daily, 2, StartTime, EndTime, test_controller, [])),
    ?assertEqual(ok, do_work(test_daily, {test_controller, ?TEST_OPTS}, {1, days, []}, task_list())),
    ?assertEqual(
      ok,
      do_sync(test_daily, StartTime, EndTime, {test_controller, ?TEST_OPTS, []}, [])
    )
  ].

test_stop_all() ->
  taskeduler_cache:insert(?WORKERS_TABLE, {taskeduler_worker_names, []}),
  utils:sleep(6, seconds),
  [
    ?assertEqual(
      [[{ok, nothing_to_stop}]],
      stop_all([{test_daily, 1, days}])
    )
  ].

test_others() ->
  [
    ?assertEqual(
      false,
      get_type(undefined)
    ),
    ?assert(
      is_tuple(get_type(test_controller))
    ),
    ?assertEqual(
      [{test_daily, test_controller, [{requires_mapping, true}, {re_sync_days, 7}, {max_test_fetch, 2000}],
        {1, days}}],
      get_worker(test_daily)
    ),
    ?assertEqual(
      [],
      get_worker(undefined)
    )
  ].

-endif.

hello(WorkerName, Task, _StartDate, _EndDate, _Opts) ->
  utils:inf("This task is working ~p, ~p", [WorkerName, Task]).

task_list() ->
  [{1, <<"Cust 1">>}, {2, <<"Cust 2">>}, {4, <<"Cust 3">>}, {5, <<"Cust 4">>}].
